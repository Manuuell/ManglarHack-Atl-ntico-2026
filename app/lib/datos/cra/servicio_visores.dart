import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../servidor.dart';
import 'modelos_cra.dart';

/// De dónde salen los datos que se ven en un visor.
enum OrigenVisor {
  /// Recién leídos de la fuente.
  enVivo,

  /// La copia que guardó el teléfono la última vez que hubo señal.
  copia,

  /// Ni red ni copia: la pantalla muestra el estado de error.
  sinDatos,
}

class ResultadoVisor<T> {
  const ResultadoVisor({required this.datos, required this.leido, required this.origen});
  const ResultadoVisor.vacio() : datos = null, leido = null, origen = OrigenVisor.sinDatos;

  final T? datos;

  /// Cuándo se leyó de la fuente (en la copia: cuándo se guardó).
  final DateTime? leido;
  final OrigenVisor origen;
}

/// Puntos críticos con los tipos que trajo la API (para los chips con el color oficial).
class DatosRiesgo {
  const DatosRiesgo(this.tipos, this.puntos);
  final List<TipoEventoCra> tipos;

  /// Todo el Atlántico: la pantalla filtra por la franja del manglar.
  final List<PuntoCritico> puntos;
}

/// Lee los visores de la C.R.A. (su API pública), la RPC `estadisticas` de Supabase y el resumen
/// del workflow, con una copia por visor en el teléfono para cuando no hay señal. Mismo patrón que
/// `ServicioSensores`: primero la copia, luego la red; si la red falla, queda la copia con su hora.
class ServicioVisores {
  ServicioVisores({Servidor? servidor, http.Client? cliente, DateTime Function()? reloj})
    : _servidor = servidor ?? Servidor(),
      _cliente = cliente ?? http.Client(),
      _propio = cliente == null,
      _reloj = reloj ?? DateTime.now;

  final Servidor _servidor;
  final http.Client _cliente;
  final bool _propio;
  final DateTime Function() _reloj;

  static const espera = Duration(seconds: 15);

  /// El workflow cambia por versión, no por hora: core.json (1,2 MB) se baja como mucho una vez
  /// al día y el teléfono guarda solo el resumen (unos 2 KB).
  static const vigenciaWorkflow = Duration(hours: 24);

  static const claveRiesgo = 'visores.riesgo.v1';
  static const claveFocos = 'visores.focos.v1';
  static const claveAgua = 'visores.agua.v1';
  static const claveWorkflow = 'visores.workflow.v1';
  static const claveEstadisticas = 'visores.estadisticas.v1';

  bool get conServidor => _servidor.configurado;

  void cerrar() {
    if (_propio) _cliente.close();
  }

  Future<Object?> _get(String url) async {
    final r = await _cliente.get(Uri.parse(url)).timeout(espera);
    if (r.statusCode != 200) throw http.ClientException('HTTP ${r.statusCode}', Uri.parse(url));
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  // ── Copias ──

  Future<ResultadoVisor<T>?> _copia<T>(String clave, T Function(Object? j) deJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(clave);
      if (crudo == null) return null;
      final j = jsonDecode(crudo) as Map;
      return ResultadoVisor(datos: deJson(j['datos']), leido: DateTime.parse(j['leido'] as String), origen: OrigenVisor.copia);
    } catch (_) {
      return null;
    }
  }

  Future<void> _guardar(String clave, Object? datos, DateTime leido) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(clave, jsonEncode({'leido': leido.toIso8601String(), 'datos': datos}));
    } catch (_) {
      // Lo recién leído sirve aunque no se pueda guardar.
    }
  }

  Future<ResultadoVisor<T>> _cargar<T>({
    required String clave,
    required Future<T?> Function() leer,
    required Object? Function(T d) aJson,
    required T Function(Object? j) deJson,
    Duration? vigencia,
  }) async {
    final ahora = _reloj().toUtc();
    final guardada = await _copia(clave, deJson);
    if (vigencia != null && guardada != null && ahora.difference(guardada.leido!) < vigencia) {
      return ResultadoVisor(datos: guardada.datos, leido: guardada.leido, origen: OrigenVisor.enVivo);
    }
    try {
      final d = await leer();
      if (d != null) {
        await _guardar(clave, aJson(d), ahora);
        return ResultadoVisor(datos: d, leido: ahora, origen: OrigenVisor.enVivo);
      }
    } catch (_) {
      // Sin señal o respuesta rara: se cae a la copia.
    }
    return guardada ?? const ResultadoVisor.vacio();
  }

  // ── Copias para pintar al instante (antes de ir a la red) ──

  Future<ResultadoVisor<DatosRiesgo>?> copiaRiesgo() => _copia(claveRiesgo, _riesgoDeJson);
  Future<ResultadoVisor<List<FocoCalor>>?> copiaFocos() => _copia(claveFocos, _focosDeJson);
  Future<ResultadoVisor<List<MuestraAgua>>?> copiaAgua() => _copia(claveAgua, _aguaDeJson);

  // ── Visores ──

  Future<ResultadoVisor<DatosRiesgo>> riesgo() => _cargar(
    clave: claveRiesgo,
    leer: () async {
      final tiposJ = _get('$apiCra/critical_points/attributes/event_types/items').catchError((_) => null);
      final zonasJ = _get('$apiCra/critical_points/attributes/event_zones/items').catchError((_) => null);
      final puntosJ = _get('$apiCra/critical_points/items?format=geojson');
      final tipos = interpretarTipos(await tiposJ);
      final puntos = interpretarPuntosCriticos(await puntosJ, tipos, interpretarZonas(await zonasJ), soloFranja: false);
      return puntos.isEmpty ? null : DatosRiesgo(tipos, puntos);
    },
    aJson: (d) => {
      'tipos': [for (final t in d.tipos) t.toJson()],
      'puntos': [for (final p in d.puntos) p.toJson()],
    },
    deJson: _riesgoDeJson,
  );

  Future<ResultadoVisor<List<FocoCalor>>> focos() => _cargar(
    clave: claveFocos,
    leer: () async => interpretarFocos(await _get('$apiCra/wildfire-clusters/items?format=geojson')),
    aJson: (d) => [for (final f in d) f.toJson()],
    deJson: _focosDeJson,
  );

  Future<ResultadoVisor<List<MuestraAgua>>> agua() => _cargar(
    clave: claveAgua,
    leer: () async {
      final j = await Future.wait([
        _get('$apiCra/water_bodies/sampling_points/items?format=geojson'),
        _get('$apiCra/water_bodies/measurements/items'),
      ]);
      final r = interpretarAgua(j[0], j[1]);
      return r.isEmpty ? null : r;
    },
    aJson: (d) => [for (final m in d) m.toJson()],
    deJson: _aguaDeJson,
  );

  Future<ResultadoVisor<CifrasWorkflow>> workflow() => _cargar(
    clave: claveWorkflow,
    vigencia: vigenciaWorkflow,
    leer: () async => interpretarCore(await _get(urlCoreWorkflow)),
    aJson: (d) => d.toJson(),
    deJson: (j) => CifrasWorkflow.desdeJson(j as Map),
  );

  /// `estadisticas(desde)` de Supabase: últimos 30 días, solo agregados. Sin servidor → sin datos.
  Future<ResultadoVisor<EstadisticasReportes>> estadisticas() => _cargar(
    clave: claveEstadisticas,
    leer: () async {
      if (!_servidor.configurado) return null;
      final r = await _cliente
          .post(
            Uri.parse('${_servidor.base}/rest/v1/rpc/estadisticas'),
            headers: {'apikey': _servidor.anon, 'Authorization': 'Bearer ${_servidor.anon}', 'Content-Type': 'application/json'},
            body: '{}',
          )
          .timeout(espera);
      if (r.statusCode != 200) return null;
      return EstadisticasReportes.desdeJson(jsonDecode(utf8.decode(r.bodyBytes)));
    },
    aJson: (d) => d.toJson(),
    deJson: (j) => EstadisticasReportes.desdeJson(j)!,
  );
}

DatosRiesgo _riesgoDeJson(Object? j) {
  final m = j as Map;
  return DatosRiesgo(
    [for (final t in m['tipos'] as List) TipoEventoCra.desdeJson(t as Map)],
    [for (final p in m['puntos'] as List) PuntoCritico.desdeJson(p as Map)],
  );
}

List<FocoCalor> _focosDeJson(Object? j) => [for (final f in j as List) FocoCalor.desdeJson(f as Map)];
List<MuestraAgua> _aguaDeJson(Object? j) => [for (final m in j as List) MuestraAgua.desdeJson(m as Map)];
