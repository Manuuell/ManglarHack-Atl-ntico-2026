import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../servidor.dart';
import 'lecturas_sensor.dart';

/// De dónde salen las lecturas que se ven.
enum OrigenSensores {
  /// Recién leídas de Supabase.
  enVivo,

  /// La copia que guardó el teléfono la última vez que hubo señal.
  copia,

  /// Inventadas para el pitch: no hay servidor o no tiene ninguna lectura.
  demostracion,
}

class ResultadoSensores {
  const ResultadoSensores({
    required this.lecturas,
    required this.series,
    required this.leido,
    required this.origen,
  });

  final List<LecturaSensor> lecturas;

  /// Últimas horas por sensor (la mini gráfica).
  final Map<String, List<PuntoSerie>> series;

  /// Cuándo se leyó del servidor (en la copia: cuándo se guardó).
  final DateTime leido;
  final OrigenSensores origen;

  bool get esDemostracion => origen == OrigenSensores.demostracion;
}

/// Lee `ultimas_lecturas()` (la única puerta pública a las lecturas: `anon` no puede leer
/// `lecturas_sensor` directo) y guarda una copia en el teléfono para cuando no hay señal.
///
/// La RPC da solo la última lectura de cada sensor. La mini gráfica se arma con las lecturas
/// que este teléfono fue viendo al refrescar (se guardan las de las últimas [ventanaSerie]),
/// así no hace falta abrir el historial crudo al público.
class ServicioSensores {
  ServicioSensores({Servidor? servidor, http.Client? cliente, DateTime Function()? reloj})
      : _servidor = servidor ?? Servidor(),
        _cliente = cliente ?? http.Client(),
        _propio = cliente == null,
        _reloj = reloj ?? DateTime.now;

  final Servidor _servidor;
  final http.Client _cliente;
  final bool _propio;
  final DateTime Function() _reloj;

  static const clave = 'sensores.v1';
  static const ventanaSerie = Duration(hours: 12);
  static const maxPuntos = 96;

  /// Cada cuánto refresca la pantalla abierta (la estación manda cada 10 min).
  static const refresco = Duration(seconds: 60);

  bool get conServidor => _servidor.configurado;

  void cerrar() {
    if (_propio) _cliente.close();
  }

  /// La copia guardada, o `null` si nunca hubo lecturas.
  Future<ResultadoSensores?> copia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(clave);
      if (crudo == null) return null;
      final j = jsonDecode(crudo) as Map;
      final lecturas = interpretarLecturas(j['lecturas']);
      if (lecturas.isEmpty) return null;
      return ResultadoSensores(
        lecturas: lecturas,
        series: _seriesDesdeJson(j['series']),
        leido: DateTime.parse(j['leido'] as String),
        origen: OrigenSensores.copia,
      );
    } catch (_) {
      return null;
    }
  }

  /// Lee del servidor. Sin servidor o sin lecturas → la copia; sin copia → demostración.
  Future<ResultadoSensores> cargar() async {
    final ahora = _reloj().toUtc();
    if (_servidor.configurado) {
      try {
        final res = await _cliente
            .post(
              Uri.parse('${_servidor.base}/rest/v1/rpc/ultimas_lecturas'),
              headers: {
                'apikey': _servidor.anon,
                'Authorization': 'Bearer ${_servidor.anon}',
                'Content-Type': 'application/json',
              },
              body: '{}',
            )
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final lecturas = interpretarLecturas(jsonDecode(res.body));
          if (lecturas.any((l) => l.valor != null)) {
            final anterior = await copia();
            final series = unirSeries(anterior?.series ?? const {}, lecturas, ahora);
            final nuevo = ResultadoSensores(lecturas: lecturas, series: series, leido: ahora, origen: OrigenSensores.enVivo);
            await _guardar(nuevo);
            return nuevo;
          }
        }
      } catch (_) {
        // Sin señal o respuesta rara: se cae a la copia.
      }
    }
    final guardada = await copia();
    if (guardada != null) return guardada;
    final demo = lecturasDemostracion(ahora);
    return ResultadoSensores(lecturas: demo.lecturas, series: demo.series, leido: ahora, origen: OrigenSensores.demostracion);
  }

  Future<void> _guardar(ResultadoSensores r) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        clave,
        jsonEncode({
          'leido': r.leido.toIso8601String(),
          'lecturas': [for (final l in r.lecturas) l.toJson()],
          'series': {
            for (final e in r.series.entries)
              e.key: [for (final p in e.value) [p.en.toIso8601String(), p.valor]],
          },
        }),
      );
    } catch (_) {
      // Lo recién leído sirve aunque no se pueda guardar.
    }
  }
}

Map<String, List<PuntoSerie>> _seriesDesdeJson(Object? j) {
  final r = <String, List<PuntoSerie>>{};
  if (j is! Map) return r;
  for (final e in j.entries) {
    if (e.key is! String || e.value is! List) continue;
    final puntos = <PuntoSerie>[];
    for (final p in e.value as List) {
      if (p is List && p.length == 2 && p[0] is String && p[1] is num) {
        final t = DateTime.tryParse(p[0] as String);
        if (t != null) puntos.add(PuntoSerie(t.toUtc(), (p[1] as num).toDouble()));
      }
    }
    r[e.key as String] = puntos;
  }
  return r;
}

/// Suma la última lectura de cada sensor a su serie: sin repetir la misma hora, en orden, solo
/// las últimas [ServicioSensores.ventanaSerie] y como mucho [ServicioSensores.maxPuntos].
Map<String, List<PuntoSerie>> unirSeries(
  Map<String, List<PuntoSerie>> anteriores,
  List<LecturaSensor> lecturas,
  DateTime ahora,
) {
  final desde = ahora.subtract(ServicioSensores.ventanaSerie);
  final r = <String, List<PuntoSerie>>{};
  for (final l in lecturas) {
    final puntos = [...?anteriores[l.sensorId]];
    final v = l.valor;
    final t = l.medidoEn;
    if (v != null && t != null && !puntos.any((p) => p.en.isAtSameMomentAs(t))) puntos.add(PuntoSerie(t, v));
    puntos
      ..removeWhere((p) => p.en.isBefore(desde))
      ..sort((a, b) => a.en.compareTo(b.en));
    r[l.sensorId] = puntos.length > ServicioSensores.maxPuntos
        ? puntos.sublist(puntos.length - ServicioSensores.maxPuntos)
        : puntos;
  }
  return r;
}
