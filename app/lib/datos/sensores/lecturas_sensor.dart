/// Lecturas de las estaciones del manglar: lo que devuelve la RPC `ultimas_lecturas()` de
/// `backend/supabase/estadisticas.sql` (una fila por magnitud), su estado y los umbrales.
///
/// Cada fila de `sensores` es UNA magnitud (nivel, salinidad, temperatura, turbidez). La app
/// agrupa por zona: una estación es el conjunto de sondas de una misma zona.
library;

/// Las cuatro magnitudes que acepta `sensores.tipo`, con su rango físico (el mismo que valida
/// la Edge Function `lectura-sensor`) y un umbral de referencia para cuando la RPC no lo da
/// (desde `estadisticas_parche_1.sql` solo el admin recibe `umbral_alerta`).
enum TipoSensor {
  nivelAgua(
    'nivel_agua',
    'Nivel del agua',
    'm',
    decimales: 2,
    minimo: 0,
    maximo: 10,
    umbralReferencia: 1.5,
    explicacion: 'Si el agua pasa de este nivel, el caño puede desbordarse e inundar el bosque y las casas de la orilla.',
  ),
  salinidad(
    'salinidad',
    'Salinidad',
    'ppt',
    decimales: 1,
    minimo: 0,
    maximo: 60,
    umbralReferencia: 45,
    explicacion: 'El mangle aguanta sal, pero no tanta: con más sal que esta las raíces se secan y las plántulas mueren.',
  ),
  temperatura(
    'temperatura',
    'Temperatura del agua',
    '°C',
    decimales: 1,
    minimo: -5,
    maximo: 60,
    umbralReferencia: 34,
    explicacion: 'El agua más caliente que esto guarda menos oxígeno: peces, cangrejos y ostras empiezan a sufrir.',
  ),
  turbidez(
    'turbidez',
    'Turbidez',
    'NTU',
    decimales: 0,
    minimo: 0,
    maximo: 4000,
    umbralReferencia: 100,
    explicacion: 'Agua así de turbia tapa la luz; suele venir de un vertimiento, basura o un relleno cerca.',
  );

  const TipoSensor(
    this.id,
    this.nombre,
    this.unidad, {
    required this.decimales,
    required this.minimo,
    required this.maximo,
    required this.umbralReferencia,
    required this.explicacion,
  });

  final String id;
  final String nombre;
  final String unidad;
  final int decimales;
  final double minimo;
  final double maximo;
  final double umbralReferencia;

  /// Qué pasa si se pasa el umbral, en palabras de vecino.
  final String explicacion;

  static TipoSensor? desdeId(Object? id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// «1,72 m», «32,5 ppt»: coma decimal, como se lee en Colombia.
  String formatear(double valor) => '${valor.toStringAsFixed(decimales).replaceAll('.', ',')} $unidad';
}

/// Cómo está una sonda ahora. El orden importa: de lo más urgente a lo menos.
enum EstadoLectura { alerta, enLinea, vieja, sinDatos }

/// La estación manda cada 10 min (`INTERVALO_MINUTOS` del firmware): dos envíos perdidos más
/// un margen siguen siendo «en línea».
const enLineaHasta = Duration(minutes: 25);

/// Lo mismo que «vigente» en la RPC: una lectura de más de 6 h ya no dispara alerta.
const vigenciaAlerta = Duration(hours: 6);

/// Desde qué fracción del umbral se avisa «cerca del umbral» (color de atención).
const fraccionCerca = 0.85;

class LecturaSensor {
  const LecturaSensor({
    required this.sensorId,
    required this.nombre,
    required this.tipo,
    required this.zonaId,
    required this.zonaNombre,
    this.valor,
    this.medidoEn,
    this.lat,
    this.lon,
    this.umbralServidor,
    this.alertaServidor = false,
  });

  final String sensorId;
  final String nombre;
  final TipoSensor tipo;
  final String zonaId;
  final String zonaNombre;
  final double? valor;
  final DateTime? medidoEn;

  /// Lugar de la sonda (a `anon` la RPC lo da redondeado a dos decimales, ~1 km).
  final double? lat;
  final double? lon;

  /// `umbral_alerta` si la RPC lo da (solo al admin); si no, se usa el de referencia.
  final double? umbralServidor;

  /// `en_alerta` de la RPC: la última lectura llegó al umbral que fijó la CRA.
  final bool alertaServidor;

  double get umbral => umbralServidor ?? tipo.umbralReferencia;
  bool get umbralEsDeReferencia => umbralServidor == null;

  bool get superaUmbral => alertaServidor || (valor != null && valor! >= umbral);
  bool get cercaDelUmbral => !superaUmbral && valor != null && valor! >= umbral * fraccionCerca;

  EstadoLectura estado(DateTime ahora) {
    final v = valor;
    final t = medidoEn;
    if (v == null || t == null) return EstadoLectura.sinDatos;
    final edad = ahora.difference(t);
    if (superaUmbral && edad <= vigenciaAlerta) return EstadoLectura.alerta;
    if (edad <= enLineaHasta) return EstadoLectura.enLinea;
    return EstadoLectura.vieja;
  }

  /// Nivel de riesgo 1–5 para pintar con `Zc.dePrioridad`: 5 alerta, 3 cerca, 1 normal.
  int riesgo(DateTime ahora) {
    final e = estado(ahora);
    if (e == EstadoLectura.alerta) return 5;
    if (e == EstadoLectura.sinDatos) return 1;
    return cercaDelUmbral ? 3 : 1;
  }

  /// Interpreta una fila de `ultimas_lecturas()`. Devuelve `null` si le falta el id, la zona o
  /// el tipo no es uno de los cuatro. Un valor fuera del rango físico se toma como sin dato:
  /// mejor «sin datos» que un número imposible en pantalla.
  static LecturaSensor? desdeJson(Object? fila) {
    if (fila is! Map) return null;
    final id = fila['sensor_id'];
    final tipo = TipoSensor.desdeId(fila['tipo']);
    if (id is! String || id.isEmpty || tipo == null) return null;
    final zona = fila['zona'] is String && (fila['zona'] as String).isNotEmpty ? fila['zona'] as String : 'sin_zona';
    final zonaNombre = fila['zona_nombre'] is String && (fila['zona_nombre'] as String).trim().isNotEmpty
        ? (fila['zona_nombre'] as String).trim()
        : 'Sin zona asignada';
    double? valor;
    final crudo = fila['valor'];
    if (crudo is num && crudo.isFinite && crudo >= tipo.minimo && crudo <= tipo.maximo) valor = crudo.toDouble();
    DateTime? medido;
    if (fila['medido_en'] is String) medido = DateTime.tryParse(fila['medido_en'] as String)?.toUtc();
    final umbral = fila['umbral_alerta'];
    final lat = fila['lat'];
    final lon = fila['lon'];
    final conLugar = lat is num && lon is num && lat >= 10.2 && lat <= 11.4 && lon >= -75.7 && lon <= -74.4;
    return LecturaSensor(
      sensorId: id,
      nombre: fila['nombre'] is String ? (fila['nombre'] as String) : tipo.nombre,
      tipo: tipo,
      zonaId: zona,
      zonaNombre: zonaNombre,
      valor: valor,
      medidoEn: valor == null ? null : medido,
      lat: conLugar ? lat.toDouble() : null,
      lon: conLugar ? lon.toDouble() : null,
      umbralServidor: umbral is num && umbral.isFinite ? umbral.toDouble() : null,
      alertaServidor: valor != null && fila['en_alerta'] == true,
    );
  }

  Map<String, Object?> toJson() => {
        'sensor_id': sensorId,
        'nombre': nombre,
        'tipo': tipo.id,
        'zona': zonaId,
        'zona_nombre': zonaNombre,
        'valor': valor,
        'medido_en': medidoEn?.toUtc().toIso8601String(),
        'lat': lat,
        'lon': lon,
        'umbral_alerta': umbralServidor,
        'en_alerta': alertaServidor,
      };
}

/// Lista de filas de la RPC: descarta las que no se entienden en vez de fallar entera.
List<LecturaSensor> interpretarLecturas(Object? cuerpo) {
  if (cuerpo is! List) return const [];
  return [for (final f in cuerpo) ?LecturaSensor.desdeJson(f)];
}

/// Un punto de la mini gráfica.
class PuntoSerie {
  const PuntoSerie(this.en, this.valor);
  final DateTime en;
  final double valor;
}

/// Las sondas de una misma zona.
class Estacion {
  Estacion(this.zonaId, this.zonaNombre, List<LecturaSensor> lecturas)
      : lecturas = List.unmodifiable([...lecturas]..sort((a, b) => a.tipo.index.compareTo(b.tipo.index)));

  final String zonaId;
  final String zonaNombre;
  final List<LecturaSensor> lecturas;

  /// La sonda más urgente decide el estado de la estación.
  EstadoLectura estado(DateTime ahora) {
    var mejor = EstadoLectura.sinDatos;
    for (final l in lecturas) {
      final e = l.estado(ahora);
      if (e.index < mejor.index) mejor = e;
    }
    return mejor;
  }

  int riesgo(DateTime ahora) => lecturas.fold(1, (m, l) => l.riesgo(ahora) > m ? l.riesgo(ahora) : m);

  DateTime? get ultimaLectura {
    DateTime? u;
    for (final l in lecturas) {
      final t = l.medidoEn;
      if (t != null && (u == null || t.isAfter(u))) u = t;
    }
    return u;
  }

  /// El centro de sus sondas con lugar, o `null` si ninguna lo tiene.
  (double, double)? get punto {
    final con = [for (final l in lecturas) if (l.lat != null && l.lon != null) l];
    if (con.isEmpty) return null;
    return (
      con.fold(0.0, (a, l) => a + l.lat!) / con.length,
      con.fold(0.0, (a, l) => a + l.lon!) / con.length,
    );
  }

  List<LecturaSensor> enAlerta(DateTime ahora) => [for (final l in lecturas) if (l.estado(ahora) == EstadoLectura.alerta) l];
}

/// Agrupa por zona y ordena: primero las estaciones en alerta, luego por nombre.
List<Estacion> agruparEstaciones(List<LecturaSensor> lecturas, DateTime ahora) {
  final porZona = <String, List<LecturaSensor>>{};
  for (final l in lecturas) {
    porZona.putIfAbsent(l.zonaId, () => []).add(l);
  }
  final estaciones = [for (final e in porZona.entries) Estacion(e.key, e.value.first.zonaNombre, e.value)];
  estaciones.sort((a, b) {
    final c = a.estado(ahora).index.compareTo(b.estado(ahora).index);
    return c != 0 ? c : a.zonaNombre.compareTo(b.zonaNombre);
  });
  return estaciones;
}

/// «ahora mismo», «hace 4 min», «hace 2 h», «hace 3 días».
String haceCuanto(DateTime? en, DateTime ahora) {
  if (en == null) return 'sin lecturas';
  final d = ahora.difference(en);
  if (d.inMinutes < 1) return 'ahora mismo';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  final dias = d.inDays;
  return dias == 1 ? 'hace 1 día' : 'hace $dias días';
}

/// «14:05» en hora de Colombia (UTC−5), sin depender de la zona del teléfono.
String horaColombia(DateTime en) {
  final b = en.toUtc().subtract(const Duration(hours: 5));
  return '${b.hour.toString().padLeft(2, '0')}:${b.minute.toString().padLeft(2, '0')}';
}

String textoEstado(EstadoLectura e, DateTime? en, DateTime ahora) => switch (e) {
      EstadoLectura.alerta => 'Pasó el umbral · ${haceCuanto(en, ahora)}',
      EstadoLectura.enLinea => 'En línea · ${haceCuanto(en, ahora)}',
      EstadoLectura.vieja => 'Sin datos ${haceCuanto(en, ahora)}',
      EstadoLectura.sinDatos => 'Aún sin lecturas',
    };

// ---------------------------------------------------------------------------------------------
// DEMOSTRACIÓN: lecturas inventadas, con los mismos UUID y zonas que seed_sensores_demo.sql y el
// lote de tools/simular_sensor.mjs (Mallorquín sube de 0,82 a 1,72 m). Nunca son mediciones.
// ---------------------------------------------------------------------------------------------

class Demostracion {
  const Demostracion(this.lecturas, this.series);
  final List<LecturaSensor> lecturas;
  final Map<String, List<PuntoSerie>> series;
}

Demostracion lecturasDemostracion(DateTime ahora) {
  final t = ahora.toUtc();
  final lecturas = <LecturaSensor>[];
  final series = <String, List<PuntoSerie>>{};

  const lugares = {
    'mallorquin': (11.0562, -74.8405),
    'tubara': (10.9527, -75.0241),
    'juan_de_acosta': (10.8590, -75.1257),
    'piojo': (10.7125, -75.2162),
  };
  void sonda(String id, TipoSensor tipo, String zona, String zonaNombre, List<double> valores,
      {Duration ultima = const Duration(minutes: 4)}) {
    final fin = t.subtract(ultima);
    final puntos = [
      for (var i = 0; i < valores.length; i++)
        PuntoSerie(fin.subtract(Duration(minutes: 30 * (valores.length - 1 - i))), valores[i]),
    ];
    series[id] = puntos;
    lecturas.add(LecturaSensor(
      sensorId: id,
      nombre: '[DEMO] ${tipo.nombre} · $zonaNombre',
      tipo: tipo,
      zonaId: zona,
      zonaNombre: zonaNombre,
      valor: valores.isEmpty ? null : valores.last,
      medidoEn: valores.isEmpty ? null : fin,
      lat: lugares[zona]?.$1,
      lon: lugares[zona]?.$2,
    ));
  }

  const m = 'Ciénaga de Mallorquín';
  sonda('5e500000-0000-4000-8000-000000000001', TipoSensor.nivelAgua, 'mallorquin', m,
      [0.82, 0.84, 0.86, 0.9, 0.97, 1.08, 1.21, 1.36, 1.52, 1.72]);
  sonda('5e500000-0000-4000-8000-000000000011', TipoSensor.salinidad, 'mallorquin', m,
      [24.1, 24.4, 24.0, 23.6, 23.1, 22.4, 21.8, 21.0, 20.6, 20.2]);
  sonda('5e500000-0000-4000-8000-000000000021', TipoSensor.temperatura, 'mallorquin', m,
      [29.4, 29.6, 29.9, 30.2, 30.5, 30.4, 30.1, 29.8, 29.7, 29.6]);
  const tu = 'Costa de Tubará';
  sonda('5e500000-0000-4000-8000-000000000002', TipoSensor.salinidad, 'tubara', tu,
      [36.2, 36.8, 37.5, 38.1, 38.6, 39.4, 40.0, 40.3, 40.9, 41.2], ultima: const Duration(minutes: 7));
  sonda('5e500000-0000-4000-8000-000000000012', TipoSensor.nivelAgua, 'tubara', tu,
      [0.61, 0.62, 0.6, 0.58, 0.57, 0.57, 0.59, 0.6, 0.62, 0.63], ultima: const Duration(minutes: 7));
  const ja = 'Costa de Juan de Acosta';
  sonda('5e500000-0000-4000-8000-000000000003', TipoSensor.temperatura, 'juan_de_acosta', ja,
      [30.1, 30.3, 30.6, 30.8, 31.0, 31.1], ultima: const Duration(hours: 2, minutes: 10));
  sonda('5e500000-0000-4000-8000-000000000004', TipoSensor.turbidez, 'piojo', 'Ciénaga del Totumo', const []);
  return Demostracion(lecturas, series);
}
