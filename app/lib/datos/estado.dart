import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'clima.dart';
import 'fotos.dart';
import 'guardian.dart';
import 'reporte.dart';
import 'servidor.dart';
import 'tipos.dart';
import 'zonas.dart';

/// Todo lo que la app sabe, en un solo lugar.
///
/// Offline primero: un reporte se guarda en el teléfono ANTES de intentar enviarlo, y
/// la cola se vacía sola cuando vuelve la señal (al cambiar la conectividad, al volver
/// a la app y con espera creciente mientras quede algo pendiente). Reintentar nunca
/// duplica: el id lo pone el teléfono.
///
/// Sin señal no se intenta nada: el reporte queda «en el teléfono», no «reintentando».
/// Un fallo de la red deja el reporte en la cola sin sumar intentos y corta la vuelta
/// (los demás no gastan su plazo en balde). Un rechazo del servidor (400) no se reintenta.
///
/// En la web, dos pestañas comparten el almacenamiento: antes de escribir se relee y se
/// fusiona por id, así una pestaña no borra lo que guardó la otra.
class EstadoZanky extends ChangeNotifier with WidgetsBindingObserver {
  EstadoZanky({Servidor? servidor}) : servidor = servidor ?? Servidor();

  final Servidor servidor;
  static const _uuid = Uuid();
  static const claveReportes = 'reportes.v1';
  static const _clavePerfil = 'perfil.v1';

  late final Manglar manglar;
  Perfil? perfil;
  final List<Reporte> reportes = [];
  List<ReportePublico> publicos = const [];

  /// El tiempo en la primera zona (Mallorquín), el que muestra el inicio.
  Clima? clima;
  bool climaDeCache = false;

  /// El tiempo de las demás zonas (para el viento de un incendio en Piojó, no el de
  /// Mallorquín). Se llena en segundo plano con [cargarClima].
  final Map<String, Clima> _climaPorZona = {};

  bool listo = false;
  bool enLinea = true;
  bool sincronizando = false;
  DateTime? ultimaSincronizacion;

  StreamSubscription<List<ConnectivityResult>>? _red;
  Timer? _reintento;
  int _fallosSeguidos = 0;
  bool _desechado = false;

  // ---------------------------------------------------------------- arranque

  Future<void> iniciar() async {
    manglar = await Manglar.cargar();
    // Web: las fotos que quedaron en localStorage pasan a IndexedDB antes de leer nada.
    await Fotos.migrarDeLocalStorage();
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getString(_clavePerfil);
    if (p != null) perfil = Perfil.fromJson(jsonDecode(p) as Map<String, dynamic>);
    reportes
      ..clear()
      ..addAll(leerReportes(prefs.getStringList(claveReportes)));
    for (final r in reportes) {
      // Un envío que quedó «enviando» al cerrarse la app vuelve a la cola.
      if (r.envio == Envio.enviando) r.envio = Envio.enCola;
    }

    final c = Connectivity();
    enLinea = _hayRed(await c.checkConnectivity());
    _red = c.onConnectivityChanged.listen((r) => cambioDeRed(_hayRed(r)));
    WidgetsBinding.instance.addObserver(this);

    listo = true;
    _avisar();

    unawaited(cargarClima());
    unawaited(sincronizar());
    unawaited(_traerPrioridades());
  }

  /// Las prioridades de la CRA (1,5 MB) no frenan la primera pantalla: se traen después del primer
  /// cuadro y por tramos. Un reporte armado antes se ubica sin plan y el servidor lo recalcula.
  Future<void> _traerPrioridades() async {
    await WidgetsBinding.instance.endOfFrame;
    // En la web (sin isolates) se deja pasar la primera pantalla o el modo evento antes de
    // empezar: lo primero es que pinte e interactúe.
    if (kIsWeb) await Future<void>.delayed(const Duration(milliseconds: 800));
    if (_desechado) return;
    await manglar.cargarPrioridades();
  }

  static bool _hayRed(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);

  /// La conectividad cambió. Al volver la red, la espera vuelve a empezar y se envía YA.
  @visibleForTesting
  void cambioDeRed(bool hay) {
    final antes = enLinea;
    enLinea = hay;
    _avisar();
    if (!antes && enLinea) {
      _fallosSeguidos = 0;
      unawaited(sincronizar());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fallosSeguidos = 0;
      unawaited(sincronizar());
      unawaited(cargarClima());
    }
  }

  @override
  void dispose() {
    _desechado = true;
    _red?.cancel();
    _reintento?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _avisar() {
    if (!_desechado) notifyListeners();
  }

  // ---------------------------------------------------------------- perfil

  /// Primero a disco, después a memoria: si guardar falla, la app no cree que ya
  /// hay consentimiento (y no salta a la pantalla principal sin él).
  Future<void> guardarPerfil(Perfil p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clavePerfil, jsonEncode(p.toJson()));
    perfil = p;
    _avisar();
  }

  Perfil perfilNuevo() => Perfil(id: _uuid.v4(), creado: DateTime.now());

  Progreso get progreso => Progreso.de(reportes);

  /// Deja la memoria como una instalación nueva. Se llama DESPUÉS de borrar el disco
  /// (BorradoDatos.borrarTodo). Un guardado que estuviera en camino ya no escribe.
  void olvidarTodo() {
    _epoca++;
    _reintento?.cancel();
    perfil = null;
    reportes.clear();
    _quitados.clear();
    publicos = const [];
    clima = null;
    climaDeCache = false;
    _climaPorZona.clear();
    ultimaSincronizacion = null;
    _fallosSeguidos = 0;
    _avisar();
  }

  // ---------------------------------------------------------------- reportes

  String nuevoId() => _uuid.v4();

  /// Los que esperan salir (en cola, enviándose o con error pasajero). Los rechazados no:
  /// no van a salir, y la pantalla los cuenta aparte con [rechazados].
  int get pendientes => reportes.where(_porEnviar).length;

  /// Los que el servidor rechazó (no se reintentan solos).
  int get rechazados => reportes.where((r) => r.envio == Envio.rechazado).length;

  static bool _porEnviar(Reporte r) => r.envio != Envio.enviado && r.envio != Envio.rechazado;

  /// Guarda primero (en el teléfono) y después intenta enviar.
  ///
  /// Primero a disco y después a memoria: si guardar falla (p. ej. sin espacio en el
  /// navegador) lanza [ErrorAlGuardar] y el reporte NO aparece en la app como guardado.
  /// Un id que ya está (doble toque en «Enviar») no se duplica: devuelve el que ya había.
  Future<Reporte> agregar(Reporte r, Uint8List? foto) async {
    final ya = reportes.where((x) => x.id == r.id).firstOrNull;
    if (ya != null) return ya;
    if (r.historial.isEmpty) {
      r.historial.add(CambioEstado(EstadoReporte.recibido, r.capturadoEn, 'Creado en el teléfono'));
    }
    r.cambiadoEn ??= DateTime.now();
    try {
      await _guardar(nuevo: r);
    } catch (e) {
      throw ErrorAlGuardar.de(e);
    }
    _avisar();
    unawaited(sincronizar());
    return reportes.firstWhere((x) => x.id == r.id, orElse: () => r);
  }

  /// Ids que la persona quitó de este teléfono: la fusión con el disco no los trae de vuelta.
  final Set<String> _quitados = {};

  /// ¿Se puede quitar de este teléfono? Solo lo que no llegó a la CRA ni va en camino:
  /// un reporte enviado ya no es solo del teléfono.
  static bool sePuedeQuitar(Reporte r) => r.envio != Envio.enviado && r.envio != Envio.enviando;

  /// Quita del teléfono un reporte que no salió (con [restaurarReporte] se recupera
  /// mientras la pantalla conserve el objeto). Primero memoria y después disco.
  Future<void> quitarReporte(Reporte r) async {
    if (!sePuedeQuitar(r)) return;
    _quitados.add(r.id);
    reportes.removeWhere((x) => x.id == r.id);
    _avisar();
    await _guardarSinRomper();
  }

  /// Devuelve un reporte quitado con [quitarReporte] (el «Deshacer»).
  Future<void> restaurarReporte(Reporte r) async {
    _quitados.remove(r.id);
    if (reportes.any((x) => x.id == r.id)) return;
    reportes.add(r);
    reportes.sort((a, b) => b.capturadoEn.compareTo(a.capturadoEn));
    _avisar();
    await _guardarSinRomper();
  }

  /// Pone otra vez en la cola un reporte rechazado o con error (por ejemplo, si el
  /// servidor se corrigió) y sincroniza.
  Future<void> reintentar(Reporte r) async {
    if (r.envio != Envio.rechazado && r.envio != Envio.error) return;
    r
      ..envio = Envio.enCola
      ..motivoRechazo = null
      ..cambiadoEn = DateTime.now();
    _fallaronRecien.remove(r.id);
    await _guardarSinRomper();
    _fallosSeguidos = 0;
    _avisar();
    await sincronizar();
  }

  /// Lee la lista guardada. Un registro dañado se descarta solo; un id repetido (de una
  /// versión vieja que podía duplicar) queda una vez, con la copia más avanzada.
  @visibleForTesting
  static List<Reporte> leerReportes(List<String>? guardados) {
    final porId = <String, Reporte>{};
    for (final s in guardados ?? const <String>[]) {
      try {
        final r = Reporte.fromJson(jsonDecode(s) as Map<String, dynamic>);
        final otro = porId[r.id];
        if (otro == null || Reporte.compararAvance(r, otro) > 0) porId[r.id] = r;
      } catch (_) {
        // Un registro dañado no tumba la app; se descarta solo ese.
      }
    }
    return porId.values.toList()..sort((a, b) => b.capturadoEn.compareTo(a.capturadoEn));
  }

  /// Fusiona en [memoria] lo que hay en [disco] (lo que escribió otra pestaña): agrega los
  /// reportes que no conoce y, para un mismo id, se queda con la copia más avanzada
  /// (copiándola en el objeto que ya tienen las pantallas). Devuelve si cambió algo.
  @visibleForTesting
  static bool fusionarReportes(List<Reporte> memoria, Iterable<Reporte> disco) {
    final porId = {for (final r in memoria) r.id: r};
    var cambio = false;
    var nuevos = false;
    for (final d in disco) {
      final m = porId[d.id];
      if (m == null) {
        if (d.envio == Envio.enviando) d.envio = Envio.enCola;
        memoria.add(d);
        porId[d.id] = d;
        cambio = nuevos = true;
      } else if (!identical(m, d) && Reporte.compararAvance(d, m) > 0) {
        // La copia que se está enviando AQUÍ no se pisa con otra que tampoco ha llegado.
        if (!(m.envio == Envio.enviando && d.envio != Envio.enviado)) {
          m.adoptarDe(d);
          cambio = true;
        }
      }
    }
    if (nuevos) memoria.sort((a, b) => b.capturadoEn.compareTo(a.capturadoEn));
    return cambio;
  }

  // Las escrituras van de una en una: dos a la vez (la vuelta de envío y un reporte nuevo)
  // partirían de la misma lista y la segunda borraría lo de la primera.
  Future<void> _ultimaEscritura = Future.value();
  int _epoca = 0;

  Future<void> _enSerie(Future<void> Function() f) {
    final hecho = _ultimaEscritura.then((_) => f());
    _ultimaEscritura = hecho.then((_) {}, onError: (Object _) {});
    return hecho;
  }

  /// Escribe la lista. Antes relee el disco y fusiona (otra pestaña pudo escribir) y,
  /// si viene [nuevo], lo agrega; solo si la escritura sale bien la memoria cambia.
  ///
  /// [epoca] es la época en que empezó quien llama (una vuelta de sincronización): si
  /// se borró todo desde entonces, no escribe nada (ni siquiera una lista vacía).
  Future<void> _guardar({Reporte? nuevo, int? epoca}) => _enSerie(() async {
        final desde = epoca ?? _epoca;
        if (desde != _epoca) return;
        final prefs = await SharedPreferences.getInstance();
        var disco = const <Reporte>[];
        try {
          await prefs.reload();
          disco = leerReportes(prefs.getStringList(claveReportes));
        } catch (_) {
          // Sin poder releer, se escribe lo que hay en memoria (como antes).
        }
        if (desde != _epoca) return; // se borró todo mientras tanto
        final trabajo = [?nuevo, ...reportes];
        fusionarReportes(trabajo, disco);
        // Lo que la persona quitó no vuelve del disco (otra pestaña, una copia vieja).
        trabajo.removeWhere((r) => _quitados.contains(r.id));
        try {
          final ok = await prefs.setStringList(claveReportes, [for (final r in trabajo) jsonEncode(r.toJson())]);
          if (!ok) throw const ErrorAlGuardar('El almacenamiento no aceptó el cambio.');
        } catch (e) {
          // shared_preferences ya puso la lista nueva en su caché aunque el disco no la
          // tenga: se relee para no creer guardado lo que no lo está.
          try {
            await prefs.reload();
          } catch (_) {}
          rethrow;
        }
        reportes
          ..clear()
          ..addAll(trabajo);
      });

  /// Igual que [_guardar], pero un fallo no corta lo que viene después (la vuelta de
  /// sincronización sigue: lo enviado ya está en el servidor, y el próximo guardado lo
  /// vuelve a intentar).
  Future<void> _guardarSinRomper({int? epoca}) async {
    try {
      await _guardar(epoca: epoca);
    } catch (e) {
      debugPrint('Zanky: no pude guardar la lista de reportes: $e');
    }
  }

  /// Relee el disco por si otra pestaña cambió algo (envió, creó o actualizó reportes).
  Future<void> _recargarDeDisco() => _enSerie(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.reload();
          final cambio = fusionarReportes(reportes, leerReportes(prefs.getStringList(claveReportes)));
          reportes.removeWhere((r) => _quitados.contains(r.id));
          if (cambio) _avisar();
        } catch (_) {}
      });

  /// Si falta espacio en el navegador: borra las fotos que ningún reporte usa (las de los
  /// enviados ya se redujeron a miniatura al llegar). [conservar] es el id del borrador
  /// que se está guardando. Devuelve cuántas borró.
  Future<int> liberarEspacio({String? conservar}) async {
    await _recargarDeDisco();
    return Fotos.borrarHuerfanasWeb({
      for (final r in reportes)
        if (r.fotoRef != null) r.fotoRef!,
      if (conservar != null) '${Fotos.prefijoWeb}$conservar',
    });
  }

  bool _corriendo = false;
  Completer<void>? _otraVuelta;

  /// Los que el servidor acaba de responder con error en la vuelta anterior: la vuelta
  /// encadenada (la que se pide durante otra) no los repite enseguida; esperan su turno.
  final Set<String> _fallaronRecien = {};

  /// Vacía la cola y trae el estado de lo enviado.
  ///
  /// Si ya hay una vuelta en curso no lanza otra a la vez (enviarían dos veces), pero
  /// tampoco se pierde el pedido: al terminar esa vuelta se hace otra enseguida (un reporte
  /// creado mientras se subía otro sale ya, no en 45 s). El futuro que devuelve termina con
  /// la vuelta que atiende este pedido. Nunca lanza.
  Future<void> sincronizar() {
    if (_corriendo) return (_otraVuelta ??= Completer<void>()).future;
    _fallaronRecien.clear();
    return _vuelta();
  }

  Future<void> _vuelta({bool encadenada = false}) async {
    _corriendo = true;
    sincronizando = true;
    _avisar();
    try {
      await _unaVuelta(encadenada: encadenada);
    } catch (e) {
      debugPrint('Zanky: la sincronización falló: $e');
    } finally {
      sincronizando = false;
      _corriendo = false;
      final otra = _otraVuelta;
      _otraVuelta = null;
      if (otra != null && !_desechado) {
        unawaited(_vuelta(encadenada: true).whenComplete(otra.complete));
      } else {
        otra?.complete();
        _programarReintento();
      }
      _avisar();
    }
  }

  Future<void> _unaVuelta({required bool encadenada}) async {
    if (!servidor.configurado) return;
    final epoca = _epoca;
    await _recargarDeDisco();
    if (epoca != _epoca) return; // se borró todo mientras se releía el disco
    // Sin señal no se intenta: los reportes quedan «en el teléfono», sin sumar intentos.
    if (!enLinea) return;

    var falloDelServidor = false;
    var cortoLaRed = false;
    // Del más viejo al más nuevo. Los que lleguen durante la vuelta los toma la siguiente.
    final saltados = {
      if (encadenada)
        for (final r in reportes)
          if (_porEnviar(r) && _fallaronRecien.contains(r.id)) r.id,
    };
    final cola = [
      for (final r in reportes.reversed)
        if (_porEnviar(r) && !saltados.contains(r.id)) r,
    ];
    _fallaronRecien
      ..clear()
      ..addAll(saltados);
    for (final r in cola) {
      if (_desechado) return;
      if (!_porEnviar(r)) continue; // otra pestaña lo envió mientras tanto
      r.envio = Envio.enviando;
      _avisar();
      try {
        final idPublico = await servidor.enviar(r, await Fotos.leer(r.fotoRef));
        r
          ..envio = Envio.enviado
          ..enviadoEn = DateTime.now()
          ..ultimoError = null
          ..motivoRechazo = null
          ..idPublico = idPublico ?? r.idPublico;
      } on ErrorServidor catch (e) {
        if (e.permanente) {
          r
            ..envio = Envio.rechazado
            ..motivoRechazo = e.motivo
            ..ultimoError = e.toString();
        } else {
          r
            ..envio = Envio.error
            ..intentos += 1
            ..ultimoError = e.toString();
          falloDelServidor = true;
        }
        debugPrint('Zanky: el servidor no aceptó ${r.caso}: $e');
      } catch (e) {
        if (esErrorDeRed(e)) {
          // La red no pasa datos: el reporte vuelve a la cola tal cual (no es su culpa) y
          // se corta la vuelta, sin gastar el plazo de cada uno de los que siguen.
          r
            ..envio = Envio.enCola
            ..ultimoError = 'Sin conexión con el servidor';
          cortoLaRed = true;
        } else {
          r
            ..envio = Envio.error
            ..intentos += 1
            ..ultimoError = e.toString();
          falloDelServidor = true;
          debugPrint('Zanky: falló el envío de ${r.caso}: $e');
        }
      }
      if (epoca != _epoca) return; // «Borrar mis datos» llegó con el envío en el aire
      r.cambiadoEn = DateTime.now();
      if (r.envio == Envio.error) _fallaronRecien.add(r.id);
      await _guardarSinRomper(epoca: epoca);
      _avisar();
      if (cortoLaRed) break;
    }

    if (!cortoLaRed) {
      await _traerEstados(epoca);
      if (epoca != _epoca) return;
      try {
        final propios = {
          for (final r in reportes) ...[r.id, ?r.idPublico],
        };
        // Los propios no se repiten como «públicos»: el mapa y la corroboración ya los tienen.
        final lista = await servidor.publicos();
        if (epoca != _epoca) return;
        publicos = [
          for (final p in lista)
            if (!propios.contains(p.id)) p,
        ];
      } catch (_) {
        // El mapa público es un extra: sin él la app sigue.
      }
      ultimaSincronizacion = DateTime.now();
    }
    if (epoca != _epoca) return;
    await _reducirFotosEnviadas(epoca);
    // Una vuelta encadenada que dejó esperando a los que fallaron no cuenta como «todo bien».
    _fallosSeguidos = (falloDelServidor || cortoLaRed)
        ? _fallosSeguidos + 1
        : (saltados.isNotEmpty ? _fallosSeguidos : 0);
  }

  /// Trae el estado, la prioridad y la confianza que fijó el servidor, en tandas de 100,
  /// de TODOS los enviados que aún pueden cambiar (todos menos los cerrados: un
  /// descartado se puede reabrir) y de los que aún no tienen su id público.
  Future<void> _traerEstados(int epoca) async {
    final ids = [
      for (final r in reportes)
        if (r.envio == Envio.enviado && (r.estado != EstadoReporte.cerrado || r.idPublico == null)) r.id,
    ];
    if (ids.isEmpty) return;
    final remotos = <EstadoRemoto>[];
    for (var i = 0; i < ids.length; i += 100) {
      try {
        remotos.addAll(await servidor.estados(ids.sublist(i, math.min(i + 100, ids.length))));
      } catch (e) {
        // Sin red no tiene caso seguir con las demás tandas; con un error del servidor sí.
        if (esErrorDeRed(e)) break;
      }
    }
    if (epoca != _epoca) return;
    final porId = {for (final r in reportes) r.id: r};
    var cambio = false;
    for (final e in remotos) {
      final r = porId[e.id];
      if (r == null) continue;
      var este = false;
      // Todo lo que corrige el servidor queda en disco: sin señal, al reabrir la app, se
      // sigue viendo la prioridad y la confianza del servidor, no las del teléfono.
      if (e.prioridad != null && e.prioridad != r.prioridad) {
        r.prioridad = e.prioridad!;
        este = true;
      }
      if (e.confianza != null && e.confianza != r.confianza) {
        r.confianza = e.confianza!;
        este = true;
      }
      if (e.idPublico != null && e.idPublico != r.idPublico) {
        r.idPublico = e.idPublico;
        este = true;
      }
      if (r.estado != e.estado) {
        r.estado = e.estado;
        r.historial.add(CambioEstado(e.estado, e.actualizado ?? DateTime.now(), e.nota));
        este = true;
      }
      if (este) {
        r.cambiadoEn = DateTime.now();
        cambio = true;
      }
    }
    if (cambio) {
      await _guardarSinRomper(epoca: epoca);
      _avisar();
    }
  }

  /// Lo que ya llegó a la CRA no necesita la foto completa en el teléfono (ni en el
  /// navegador, que puede ser prestado): queda una miniatura sin metadatos.
  Future<void> _reducirFotosEnviadas(int epoca) async {
    var cambio = false;
    for (final r in reportes.toList()) {
      if (r.envio != Envio.enviado || r.fotoRef == null || r.fotoReducida) continue;
      r
        ..fotoRef = await Fotos.reducir(r.fotoRef!)
        ..fotoReducida = true
        ..cambiadoEn = DateTime.now();
      cambio = true;
    }
    if (cambio) {
      await _guardarSinRomper(epoca: epoca);
      _avisar();
    }
  }

  /// Con algo pendiente, reintenta con espera creciente (45 s, 90 s… hasta 5 min).
  void _programarReintento() {
    _reintento?.cancel();
    if (_desechado || pendientes == 0 || !servidor.configurado) return;
    final s = math.min(300, 45 * math.pow(2, math.min(_fallosSeguidos, 3)).toInt());
    _reintento = Timer(Duration(seconds: s), sincronizar);
  }

  /// Vueltas seguidas con fallos (para pruebas).
  @visibleForTesting
  int get fallosSeguidos => _fallosSeguidos;

  // ---------------------------------------------------------------- clima

  /// El tiempo de una zona, si se conoce. El de la primera zona es [clima].
  Clima? climaDe(String zonaId) => _climaPorZona[zonaId] ?? (zonaId == manglar.zonas.first.id ? clima : null);

  Future<void> cargarClima() async {
    final z = manglar.zonas.first; // Mallorquín: la prioridad del equipo
    final nuevo = await Clima.leer(z.id, z.centro);
    if (nuevo != null) {
      clima = nuevo;
      climaDeCache = false;
    } else {
      clima ??= await Clima.ultimo(z.id);
      climaDeCache = clima != null;
    }
    if (clima != null) _climaPorZona[z.id] = clima!;
    _avisar();
    // Las demás zonas, en segundo plano y como mucho cada 30 min: su viento solo pesa en
    // la prioridad de un incendio.
    for (final otra in manglar.zonas.skip(1)) {
      final antes = _climaPorZona[otra.id];
      if (antes != null && DateTime.now().difference(antes.leido) < const Duration(minutes: 30)) continue;
      unawaited(() async {
        final c = await Clima.leer(otra.id, otra.centro) ?? await Clima.ultimo(otra.id);
        if (c != null) _climaPorZona[otra.id] = c;
      }());
    }
  }
}

/// Publica el estado al árbol de widgets sin dependencias extra.
class Zanky extends InheritedNotifier<EstadoZanky> {
  const Zanky({super.key, required EstadoZanky estado, required super.child}) : super(notifier: estado);

  static EstadoZanky de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Zanky>()!.notifier!;

  static EstadoZanky leer(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<Zanky>()!.widget as Zanky).notifier!;
}
