import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../permisos/permisos_rol.dart';
import '../sensores/lecturas_sensor.dart';
import '../servidor.dart';
import 'contenido_publico.dart';

/// Lo que el equipo puede editar desde el panel. La clave es la de `ajustes_panel` en
/// `backend/supabase/contenido_editable.sql`; el permiso, el de `permisos_rol.sql`.
enum SeccionContenido {
  portada('portada', 'Portada', Permiso.editarContenido),
  jornadas('jornadas', 'Jornadas', Permiso.gestionarJornadas),
  noticias('noticias', 'Noticias', Permiso.editarContenido),
  puntosQr('puntos_qr', 'Puntos QR', Permiso.gestionarPuntos),
  umbrales('umbrales_sensores', 'Umbrales', Permiso.gestionarPuntos);

  const SeccionContenido(this.clave, this.nombre, this.permiso);
  final String clave;
  final String nombre;
  final Permiso permiso;

  static SeccionContenido? deClave(Object? c) {
    for (final s in values) {
      if (s.clave == c) return s;
    }
    return null;
  }
}

/// Textos de la portada (Inicio): mensaje destacado y aviso del día.
@immutable
class PortadaPanel {
  const PortadaPanel({this.mensaje = '', this.aviso = '', this.avisoActivo = false});
  final String mensaje;
  final String aviso;
  final bool avisoActivo;

  static const maxMensaje = 140;
  static const maxAviso = 200;

  PortadaPanel copiar({String? mensaje, String? aviso, bool? avisoActivo}) => PortadaPanel(
        mensaje: mensaje ?? this.mensaje,
        aviso: aviso ?? this.aviso,
        avisoActivo: avisoActivo ?? this.avisoActivo,
      );

  Map<String, dynamic> aJson() => {'mensaje': mensaje, 'aviso': aviso, 'aviso_activo': avisoActivo};

  factory PortadaPanel.deJson(Map<String, dynamic>? j) => PortadaPanel(
        mensaje: (j?['mensaje'] as String?) ?? '',
        aviso: (j?['aviso'] as String?) ?? '',
        avisoActivo: j?['aviso_activo'] == true,
      );

  @override
  bool operator ==(Object other) =>
      other is PortadaPanel && other.mensaje == mensaje && other.aviso == aviso && other.avisoActivo == avisoActivo;
  @override
  int get hashCode => Object.hash(mensaje, aviso, avisoActivo);
}

/// Una jornada convocada desde el panel. [cupos] nulo = «sin límite».
@immutable
class JornadaPanel {
  const JornadaPanel({
    required this.id,
    required this.titulo,
    required this.fecha,
    required this.lugar,
    this.fotoUrl = '',
    this.cupos,
    this.cerrada = false,
  });

  final String id;
  final String titulo;
  final DateTime fecha;
  final String lugar;
  final String fotoUrl;
  final int? cupos;
  final bool cerrada;

  String get textoCupos => cupos == null ? 'Sin límite de cupos' : '$cupos cupos';

  JornadaPanel copiar({String? titulo, DateTime? fecha, String? lugar, String? fotoUrl, int? cupos,
          bool sinLimite = false, bool? cerrada}) =>
      JornadaPanel(
        id: id,
        titulo: titulo ?? this.titulo,
        fecha: fecha ?? this.fecha,
        lugar: lugar ?? this.lugar,
        fotoUrl: fotoUrl ?? this.fotoUrl,
        cupos: sinLimite ? null : (cupos ?? this.cupos),
        cerrada: cerrada ?? this.cerrada,
      );

  Map<String, dynamic> aJson() => {
        'id': id,
        'titulo': titulo,
        'fecha': fecha.toUtc().toIso8601String(),
        'lugar': lugar,
        'foto_url': fotoUrl,
        'cupos': cupos,
        'cerrada': cerrada,
      };

  static JornadaPanel? deJson(Object? o) {
    if (o is! Map) return null;
    final fecha = DateTime.tryParse('${o['fecha']}');
    final id = o['id'], titulo = o['titulo'];
    if (id is! String || titulo is! String || fecha == null) return null;
    final c = o['cupos'];
    return JornadaPanel(
      id: id,
      titulo: titulo,
      fecha: fecha.toLocal(),
      lugar: (o['lugar'] as String?) ?? '',
      fotoUrl: (o['foto_url'] as String?) ?? '',
      cupos: c is num && c > 0 ? c.toInt() : null,
      cerrada: o['cerrada'] == true,
    );
  }

  @override
  bool operator ==(Object other) => other is JornadaPanel && jsonEncode(other.aJson()) == jsonEncode(aJson());
  @override
  int get hashCode => jsonEncode(aJson()).hashCode;
}

/// Todo lo editable, inmutable: cada cambio devuelve otro.
@immutable
class ContenidoPanel {
  const ContenidoPanel({
    this.portada = const PortadaPanel(),
    this.jornadas = const [],
    this.fijadas = const {},
    this.ocultas = const {},
    this.puntosInactivos = const {},
    this.umbrales = const {},
  });

  /// Valores de fábrica: portada vacía (Inicio muestra lo suyo), sin jornadas del panel, ninguna
  /// noticia fijada ni oculta, todos los puntos activos y los umbrales de referencia.
  static const fabrica = ContenidoPanel();

  final PortadaPanel portada;
  final List<JornadaPanel> jornadas;
  final Set<int> fijadas;
  final Set<int> ocultas;
  final Set<String> puntosInactivos;

  /// Por id de [TipoSensor]. Lo que falte usa `umbralReferencia`.
  final Map<String, double> umbrales;

  double umbral(TipoSensor t) => umbrales[t.id] ?? t.umbralReferencia;

  ContenidoPanel copiar({
    PortadaPanel? portada,
    List<JornadaPanel>? jornadas,
    Set<int>? fijadas,
    Set<int>? ocultas,
    Set<String>? puntosInactivos,
    Map<String, double>? umbrales,
  }) =>
      ContenidoPanel(
        portada: portada ?? this.portada,
        jornadas: jornadas ?? this.jornadas,
        fijadas: fijadas ?? this.fijadas,
        ocultas: ocultas ?? this.ocultas,
        puntosInactivos: puntosInactivos ?? this.puntosInactivos,
        umbrales: umbrales ?? this.umbrales,
      );

  /// Lo que se guarda en `ajustes_panel.valor` para [s].
  Map<String, dynamic> valorDe(SeccionContenido s) => switch (s) {
        SeccionContenido.portada => portada.aJson(),
        SeccionContenido.jornadas => {'lista': [for (final j in jornadas) j.aJson()]},
        SeccionContenido.noticias => {'fijadas': (fijadas.toList()..sort()), 'ocultas': (ocultas.toList()..sort())},
        SeccionContenido.puntosQr => {'inactivos': (puntosInactivos.toList()..sort())},
        SeccionContenido.umbrales => {'umbrales': umbrales},
      };

  /// Pone en [s] lo que vino del servidor (o de la copia). Lo que no se entiende se ignora.
  ContenidoPanel conValor(SeccionContenido s, Map<String, dynamic> v) {
    Set<int> enteros(Object? l) => {if (l is List) for (final e in l) if (e is num) e.toInt()};
    return switch (s) {
      SeccionContenido.portada => copiar(portada: PortadaPanel.deJson(v)),
      SeccionContenido.jornadas => copiar(jornadas: [
          if (v['lista'] is List)
            for (final o in v['lista'] as List)
              ?JornadaPanel.deJson(o),
        ]),
      SeccionContenido.noticias => copiar(fijadas: enteros(v['fijadas']), ocultas: enteros(v['ocultas'])),
      SeccionContenido.puntosQr =>
        copiar(puntosInactivos: {if (v['inactivos'] is List) for (final e in v['inactivos'] as List) '$e'}),
      SeccionContenido.umbrales => copiar(umbrales: {
          if (v['umbrales'] is Map)
            for (final e in (v['umbrales'] as Map).entries)
              if (e.value is num && TipoSensor.values.any((t) => t.id == e.key)) '${e.key}': (e.value as num).toDouble(),
        }),
    };
  }

  /// Desde las filas de `ajustes_panel` (`clave`, `valor`).
  factory ContenidoPanel.deFilas(Iterable<Map<String, dynamic>> filas) {
    var c = fabrica;
    for (final f in filas) {
      final s = SeccionContenido.deClave(f['clave']);
      final v = f['valor'];
      if (s == null || v is! Map) continue;
      c = c.conValor(s, Map<String, dynamic>.from(v));
    }
    return c;
  }

  List<Map<String, dynamic>> aFilas() => [for (final s in SeccionContenido.values) {'clave': s.clave, 'valor': valorDe(s)}];
}

/// Una fila del historial del panel.
@immutable
class CambioPanel {
  const CambioPanel({required this.cuando, required this.quien, required this.seccion, required this.resumen});
  final DateTime cuando;
  final String quien;
  final SeccionContenido? seccion;
  final String resumen;

  static CambioPanel? deJson(Map<String, dynamic> j) {
    final cuando = DateTime.tryParse('${j['creado_en']}');
    if (cuando == null) return null;
    final correo = j['correo'] as String?;
    final rol = RolEquipo.deId(j['rol'])?.nombre;
    return CambioPanel(
      cuando: cuando.toLocal(),
      quien: [?correo, ?rol].join(' · ').ifEmpty('Alguien del equipo'),
      seccion: SeccionContenido.deClave(j['clave']),
      resumen: (j['resumen'] as String?) ?? '',
    );
  }
}

extension on String {
  String ifEmpty(String otro) => isEmpty ? otro : this;
}

/// Un punto QR tal como lo lista el panel.
@immutable
class PuntoQrPanel {
  const PuntoQrPanel({required this.codigo, required this.titulo, this.zona = '', this.ejemplo = false});
  final String codigo;
  final String titulo;
  final String zona;

  /// Solo en la demostración: se rotula «Ejemplo».
  final bool ejemplo;
}

/// De dónde salió lo que se ve.
enum OrigenContenido { servidor, copia, fabrica }

/// La tabla aún no está en el servidor.
class SinTablaContenido implements Exception {
  const SinTablaContenido();
}

class ErrorContenido implements Exception {
  const ErrorContenido(this.mensaje, {this.deRed = false});
  final String mensaje;
  final bool deRed;
  @override
  String toString() => mensaje;
}

abstract class FuenteContenidoPanel {
  Future<List<Map<String, dynamic>>> leer();
  Future<void> guardar(String clave, Map<String, dynamic> valor, String resumen);
  Future<List<Map<String, dynamic>>> historial();
  Future<List<Map<String, dynamic>>> puntos();
}

class FuenteContenidoSupabase implements FuenteContenidoPanel {
  FuenteContenidoSupabase(this.servidor, this.token);
  final Servidor servidor;
  final Future<String?> Function() token;

  Future<dynamic> _pedir(String metodo, String ruta, {Object? cuerpo}) async {
    final t = await token();
    if (t == null) throw const ErrorContenido('Entra al panel con tu cuenta para editar.');
    final cab = {'apikey': servidor.anon, 'Authorization': 'Bearer $t', 'Content-Type': 'application/json'};
    try {
      final res = await servidor.pedir(metodo, Uri.parse('${servidor.base}$ruta'), cab,
          cuerpo: cuerpo == null ? null : jsonEncode(cuerpo));
      if (res.statusCode >= 300) {
        final b = res.body.toLowerCase();
        if (res.statusCode == 404 || b.contains('pgrst205') || b.contains('pgrst202') || b.contains('does not exist')) {
          throw const SinTablaContenido();
        }
        if (b.contains('sin_permiso') || res.statusCode == 403) throw const ErrorContenido('Tu rol no tiene permiso para este cambio.');
        if (b.contains('valor_invalido')) throw const ErrorContenido('El servidor no aceptó ese contenido (muy largo o mal formado).');
        throw ErrorContenido('El servidor no aceptó el cambio (código ${res.statusCode}).');
      }
      return res.body.isEmpty ? null : jsonDecode(res.body);
    } on SinTablaContenido {
      rethrow;
    } on ErrorContenido {
      rethrow;
    } catch (e) {
      if (esErrorDeRed(e)) throw const ErrorContenido('Sin conexión con el servidor.', deRed: true);
      rethrow;
    }
  }

  List<Map<String, dynamic>> _lista(Object? d) {
    if (d is! List) throw const ErrorContenido('Respuesta inesperada del servidor.');
    return [for (final f in d) Map<String, dynamic>.from(f as Map)];
  }

  @override
  Future<List<Map<String, dynamic>>> leer() async => _lista(await _pedir('GET', '/rest/v1/ajustes_panel?select=clave,valor'));

  @override
  Future<void> guardar(String clave, Map<String, dynamic> valor, String resumen) =>
      _pedir('POST', '/rest/v1/rpc/guardar_ajuste', cuerpo: {'p_clave': clave, 'p_valor': valor, 'p_resumen': resumen});

  @override
  Future<List<Map<String, dynamic>>> historial() async => _lista(await _pedir(
      'GET', '/rest/v1/historial_panel?select=creado_en,correo,rol,clave,resumen&order=creado_en.desc&limit=50'));

  @override
  Future<List<Map<String, dynamic>>> puntos() async =>
      _lista(await _pedir('GET', '/rest/v1/puntos_zanky?select=codigo,titulo,zona,activo&order=codigo'));
}

/// El contenido editable con caché y respaldo: servidor → copia del teléfono → valores de fábrica.
/// Cada cambio se ve al instante; si el servidor no lo acepta, vuelve atrás solo y se dice por qué.
class ControladorContenidoPanel extends ChangeNotifier {
  ControladorContenidoPanel({this.fuente, this.puede = _todo, Future<SharedPreferences> Function()? preferencias, DateTime Function()? reloj})
      : _prefs = preferencias ?? SharedPreferences.getInstance,
        _reloj = reloj ?? DateTime.now;

  static bool _todo(Permiso _) => true;

  /// Nula en la demostración: los cambios viven en memoria y el historial también.
  final FuenteContenidoPanel? fuente;

  /// ¿Tiene quien entró este permiso? (de la matriz de permisos).
  bool Function(Permiso) puede;
  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _reloj;

  static const _clave = 'contenido_panel_copia_v1';

  ContenidoPanel contenido = ContenidoPanel.fabrica;
  OrigenContenido origen = OrigenContenido.fabrica;
  bool cargando = false;
  bool cargado = false;

  /// Sin señal al cargar (se ve la copia o la fábrica, sin poder guardar).
  bool sinSenal = false;
  List<CambioPanel> historial = const [];
  bool cargandoHistorial = false;
  String? falloHistorial;
  List<PuntoQrPanel>? puntos;
  String? falloPuntos;
  bool _desechado = false;

  bool get demostracion => fuente == null;

  /// Se puede guardar: demostración, o servidor con la tabla cargada.
  bool get editable => demostracion || origen == OrigenContenido.servidor;

  bool puedeEditar(SeccionContenido s) => puede(s.permiso);

  Future<void> cargar() async {
    final f = fuente;
    if (f == null) {
      cargado = true;
      puntos ??= _puntosEjemplo;
      _avisar();
      return;
    }
    cargando = true;
    _avisar();
    try {
      final filas = await f.leer();
      contenido = ContenidoPanel.deFilas(filas);
      origen = OrigenContenido.servidor;
      sinSenal = false;
      contenidoPublico.value = contenido;
      unawaited(_guardarCopia());
    } on SinTablaContenido {
      contenido = ContenidoPanel.fabrica;
      origen = OrigenContenido.fabrica;
    } catch (e) {
      sinSenal = e is ErrorContenido && e.deRed;
      final copia = await _leerCopia();
      contenido = copia ?? ContenidoPanel.fabrica;
      origen = copia == null ? OrigenContenido.fabrica : OrigenContenido.copia;
    } finally {
      cargando = false;
      cargado = true;
      _avisar();
    }
  }

  /// Guarda la sección [s] de [nuevo]. Devuelve el fallo en palabras, o nulo si quedó.
  Future<String?> guardar(SeccionContenido s, ContenidoPanel nuevo, String resumen) async {
    if (!puedeEditar(s)) return 'Tu rol no tiene el permiso «${s.permiso.nombre}».';
    if (!editable) {
      return origen == OrigenContenido.fabrica
          ? 'Falta cargar contenido_editable.sql en el servidor.'
          : 'Sin conexión: se ve la última copia y no se puede guardar.';
    }
    final antes = contenido;
    if (jsonEncode(antes.valorDe(s)) == jsonEncode(nuevo.valorDe(s))) return null;
    contenido = antes.conValor(s, nuevo.valorDe(s));
    _avisar();
    final f = fuente;
    if (f == null) {
      // Demostración: se ve en la app de este teléfono (Inicio, Comunidad) mientras dure la sesión.
      contenidoPublico.value = contenido;
      historial = [
        CambioPanel(cuando: _reloj(), quien: 'Demostración', seccion: s, resumen: resumen),
        ...historial,
      ];
      _avisar();
      return null;
    }
    try {
      await f.guardar(s.clave, contenido.valorDe(s), resumen);
      unawaited(_guardarCopia());
      contenidoPublico.value = contenido;
      historial = [CambioPanel(cuando: _reloj(), quien: 'Tú', seccion: s, resumen: resumen), ...historial];
      _avisar();
      return null;
    } catch (e) {
      contenido = antes;
      _avisar();
      return e is SinTablaContenido ? 'Falta cargar contenido_editable.sql en el servidor.' : '$e';
    }
  }

  Future<void> cargarHistorial() async {
    final f = fuente;
    if (f == null) return;
    cargandoHistorial = true;
    falloHistorial = null;
    _avisar();
    try {
      historial = [
        for (final j in await f.historial())
          ?CambioPanel.deJson(j),
      ];
    } on SinTablaContenido {
      falloHistorial = 'El historial empieza a guardarse cuando se carga contenido_editable.sql.';
    } catch (e) {
      falloHistorial = '$e';
    } finally {
      cargandoHistorial = false;
      _avisar();
    }
  }

  Future<void> cargarPuntos() async {
    final f = fuente;
    if (f == null) {
      puntos = _puntosEjemplo;
      _avisar();
      return;
    }
    falloPuntos = null;
    try {
      final filas = await f.puntos();
      puntos = [
        for (final p in filas)
          if (p['codigo'] is String)
            PuntoQrPanel(codigo: p['codigo'] as String, titulo: (p['titulo'] as String?) ?? '', zona: (p['zona'] as String?) ?? ''),
      ];
      // El estado real de cada punto manda si aún no hay ajuste guardado.
      if (origen != OrigenContenido.servidor || contenido.puntosInactivos.isEmpty) {
        contenido = contenido.copiar(puntosInactivos: {
          for (final p in filas)
            if (p['activo'] == false) '${p['codigo']}',
        });
      }
    } on SinTablaContenido {
      puntos = const [];
      falloPuntos = 'Aún no hay puntos: falta cargar puntos.sql en el servidor.';
    } catch (e) {
      puntos ??= const [];
      falloPuntos = '$e';
    }
    _avisar();
  }

  static const _puntosEjemplo = [
    PuntoQrPanel(codigo: 'ejemplo-estacion-1', titulo: 'Estación educativa del muelle', zona: 'Ejemplo', ejemplo: true),
    PuntoQrPanel(codigo: 'ejemplo-foto-fija', titulo: 'Foto fija del caño', zona: 'Ejemplo', ejemplo: true),
    PuntoQrPanel(codigo: 'ejemplo-jornada', titulo: 'Asistencia a la jornada', zona: 'Ejemplo', ejemplo: true),
  ];

  Future<void> _guardarCopia() async {
    try {
      (await _prefs()).setString(_clave, jsonEncode(contenido.aFilas()));
    } catch (_) {}
  }

  Future<ContenidoPanel?> _leerCopia() async {
    try {
      final t = (await _prefs()).getString(_clave);
      if (t == null) return null;
      return ContenidoPanel.deFilas([for (final f in jsonDecode(t) as List) Map<String, dynamic>.from(f as Map)]);
    } catch (_) {
      return null;
    }
  }

  void _avisar() {
    if (!_desechado) notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    super.dispose();
  }
}
