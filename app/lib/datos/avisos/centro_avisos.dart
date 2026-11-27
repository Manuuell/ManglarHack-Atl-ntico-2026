import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../admin/aviso_navegador.dart';
import '../comunidad/comunidad.dart';
import '../estado.dart';
import '../experiencia/jornada.dart';
import 'reglas_avisos.dart';

/// El centro de avisos: junta las alertas del manglar, los recordatorios de las jornadas
/// inscritas y las novedades de mis reportes en una bandeja guardada en el teléfono.
///
/// Revisa barato: al volver a primer plano (si pasaron 2 min desde la última vez) y cada
/// 10 min mientras la app está abierta. Las alertas salen de [FuenteComunidad.compartida],
/// la misma caché que usa Comunidad: sin señal se revisa lo guardado, sin pedir nada más.
///
/// En la web, si la persona lo activó desde un toque (nunca al abrir), además sale el
/// aviso del navegador. En el teléfono el aviso es la píldora de la app y la campana.
class CentroAvisos extends ChangeNotifier with WidgetsBindingObserver {
  CentroAvisos({FuenteComunidad? fuente, DateTime Function()? reloj, AvisoNavegador? navegador})
      : _fuente = fuente ?? FuenteComunidad.compartida,
        _reloj = reloj ?? DateTime.now,
        navegador = navegador ?? AvisoNavegador();

  static final compartido = CentroAvisos();

  static const _claveBandeja = 'avisos.bandeja.v1';
  static const _claveYa = 'avisos.ya.v1';
  static const _clavePrefs = 'avisos.prefs.v1';
  static const _claveInscritas = 'avisos.inscritas.v1';
  static const _claveNavegador = 'avisos.navegador.v1';

  static const cadaCuanto = Duration(minutes: 10);
  static const alVolverSiPasaron = Duration(minutes: 2);

  final FuenteComunidad _fuente;
  final DateTime Function() _reloj;
  final AvisoNavegador navegador;

  List<AvisoApp> avisos = [];
  Set<String> _ya = {};
  PreferenciasAvisos preferencias = const PreferenciasAvisos();
  final List<Jornada> _inscritas = [];

  /// Último aviso nuevo, para la píldora de dentro de la app (la escucha la campana).
  final nuevo = ValueNotifier<AvisoApp?>(null);

  EstadoZanky? _estado;
  Timer? _temporizador;
  DateTime? _ultimaRevision;
  bool _revisando = false;
  bool cargado = false;

  int get noLeidos => avisos.where((a) => !a.leido).length;
  List<Jornada> get inscritas => List.unmodifiable(_inscritas);

  /// Se llama una vez desde la raíz: carga lo guardado, escucha las novedades y arranca.
  Future<void> conectar(EstadoZanky estado) async {
    if (_estado != null) return;
    _estado = estado;
    estado.novedades.addListener(_alNovedad);
    WidgetsBinding.instance.addObserver(this);
    await cargar();
    _temporizador = Timer.periodic(cadaCuanto, (_) => unawaited(revisar()));
    // Después del primer cuadro: lo primero es que la app pinte.
    Future<void>.delayed(const Duration(seconds: 3), () => unawaited(revisar()));
  }

  @visibleForTesting
  Future<void> cargar() async {
    try {
      final p = await SharedPreferences.getInstance();
      final b = p.getString(_claveBandeja);
      if (b != null) avisos = [for (final x in jsonDecode(b) as List) ?AvisoApp.deJson(x)];
      _ya = (p.getStringList(_claveYa) ?? const []).toSet();
      final pr = p.getString(_clavePrefs);
      if (pr != null) preferencias = PreferenciasAvisos.deJson(jsonDecode(pr));
      final ins = p.getString(_claveInscritas);
      if (ins != null) {
        _inscritas
          ..clear()
          ..addAll([for (final x in jsonDecode(ins) as List) if (x is Map) Jornada.fromJson(x)]);
      }
      navegador.activo = p.getBool(_claveNavegador) == true && navegador.disponible && !navegador.bloqueado;
    } catch (_) {}
    cargado = true;
    notifyListeners();
  }

  Future<void> _guardar() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_claveBandeja, jsonEncode([for (final a in avisos) a.aJson()]));
      await p.setStringList(_claveYa, recortarClaves(_ya).toList());
      await p.setString(_clavePrefs, jsonEncode(preferencias.aJson()));
      await p.setString(_claveInscritas, jsonEncode([for (final j in _inscritas) j.aJson()]));
      await p.setBool(_claveNavegador, navegador.activo);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final u = _ultimaRevision;
    if (u == null || _reloj().difference(u) >= alVolverSiPasaron) unawaited(revisar());
  }

  /// Revisa alertas y recordatorios. Nunca dos a la vez.
  Future<void> revisar() async {
    if (_revisando) return;
    _revisando = true;
    try {
      _ultimaRevision = _reloj();
      final nuevos = <AvisoApp>[];
      if (preferencias.alertas) {
        final lote = await _fuente.alertas();
        nuevos.addAll(avisosDeAlertas(lote.datos.alertas, _ya, _reloj()));
      }
      if (preferencias.jornadas) nuevos.addAll(recordatoriosJornadas(_inscritas, _ya, _reloj()));
      // Las jornadas que ya pasaron no se recuerdan más.
      _inscritas.removeWhere((j) => j.fin.isBefore(_reloj()));
      _entregar(nuevos);
    } catch (_) {
    } finally {
      _revisando = false;
    }
  }

  void _alNovedad() {
    final e = _estado;
    if (e == null || !preferencias.reportes) return;
    final a = avisoDeNovedad(e.novedades.value, e.novedadReporteId, _ya, _reloj());
    if (a != null) _entregar([a]);
  }

  /// Agrega a la bandeja, recuerda las claves y avisa (navegador y píldora).
  @visibleForTesting
  void entregar(List<AvisoApp> nuevos) => _entregar(nuevos);

  void _entregar(List<AvisoApp> nuevos) {
    final permitidos = nuevos.where((a) => preferencias.permite(a.tipo)).toList();
    if (permitidos.isEmpty) return;
    _ya.addAll(permitidos.map((a) => a.clave));
    avisos = unirBandeja(avisos, permitidos);
    // El más grave primero: una alerta roja gana a un recordatorio.
    final primero = permitidos.firstWhere((a) => a.nivel == 'roja', orElse: () => permitidos.first);
    if (navegador.activo) {
      for (final a in permitidos.take(3)) {
        navegador.mostrar(a.titulo, a.cuerpo);
      }
    }
    nuevo.value = primero;
    notifyListeners();
    unawaited(_guardar());
  }

  // ---------------------------------------------------------------- inscripciones

  /// La hoja de inscripción la llama al quedar inscrito: desde ahí se recuerda la jornada.
  Future<void> recordarJornada(Jornada j) async {
    _inscritas
      ..removeWhere((x) => x.id == j.id)
      ..add(j);
    await _guardar();
    unawaited(revisar());
  }

  // ---------------------------------------------------------------- bandeja

  void marcarLeido(AvisoApp a, [bool leido = true]) {
    if (a.leido == leido) return;
    a.leido = leido;
    notifyListeners();
    unawaited(_guardar());
  }

  void marcarTodoLeido() {
    for (final a in avisos) {
      a.leido = true;
    }
    notifyListeners();
    unawaited(_guardar());
  }

  /// Quita un aviso y devuelve su posición para [restaurar] (Deshacer).
  int borrar(AvisoApp a) {
    final i = avisos.indexOf(a);
    if (i < 0) return -1;
    avisos = [...avisos]..removeAt(i);
    notifyListeners();
    unawaited(_guardar());
    return i;
  }

  void restaurar(AvisoApp a, int i) {
    if (i < 0 || avisos.contains(a)) return;
    avisos = [...avisos]..insert(i.clamp(0, avisos.length), a);
    notifyListeners();
    unawaited(_guardar());
  }

  void cambiarPreferencia(TipoAvisoApp t, bool v) {
    preferencias = preferencias.con(t, v);
    notifyListeners();
    unawaited(_guardar());
  }

  /// Avisos del navegador (solo web). Se pide permiso desde el toque de la persona.
  Future<bool> activarNavegador(bool encender) async {
    if (!encender) {
      navegador.activo = false;
    } else {
      navegador.activo = await navegador.pedirPermiso();
    }
    notifyListeners();
    unawaited(_guardar());
    return navegador.activo;
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _estado?.novedades.removeListener(_alNovedad);
    if (_estado != null) WidgetsBinding.instance.removeObserver(this);
    nuevo.dispose();
    super.dispose();
  }
}
