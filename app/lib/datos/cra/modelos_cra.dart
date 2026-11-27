import 'dart:ui' show Color;

/// Datos oficiales de la C.R.A. para los visores del manglar. Portado de `web/src/lib/craApi.ts`
/// (misma API, mismos ids, mismos colores, mismo recorte a la franja del manglar) para que la app y
/// la web digan lo mismo. Aquí solo hay datos y reglas puras: sin red, sin Flutter de vistas.

/// La API pública de gestión del riesgo de la Corporación (la que alimenta sus visores).
const apiCra = 'https://api-791856053294.us-central1.run.app';

/// Visores y páginas oficiales que se citan como fuente.
const visorPuntosCriticos = 'https://www.crautonoma.gov.co/critical-points';
const visorGeovisorCra = 'https://www.crautonoma.gov.co/geovisor-ambiental/';
const paginaCalidadAgua = 'https://www.crautonoma.gov.co/ambiental/monitoreos-de-calidad-de-agua';

/// Workflow de monitoreo del manglar de la C.R.A. (copia servida por el equipo).
const urlCoreWorkflow = 'https://mimanglar.sentralabs.co/cra/data/core.json';
const fuenteWorkflow = 'Workflow de monitoreo del manglar de la C.R.A., versión 4 '
    '(Sentinel-2, radar, elevación y alta resolución)';

// Ids estables de la API (/cartography/municipalities): la ruta trae polígonos de más de 1 MB.
const municipiosCra = <int, String>{
  1: 'Barranquilla', 2: 'Puerto Colombia', 3: 'Galapa', 4: 'Soledad', 5: 'Tubará', 6: 'Malambo', 7: 'Baranoa',
  8: 'Juan de Acosta', 9: 'Polonuevo', 10: 'Sabanagrande', 11: 'Piojó', 12: 'Usiacurí', 13: 'Santo Tomás',
  14: 'Palmar de Varela', 15: 'Ponedera', 16: 'Sabanalarga', 17: 'Luruaco', 18: 'Repelón', 19: 'Manatí',
  20: 'Candelaria', 21: 'Campo de la Cruz', 22: 'Santa Lucía', 23: 'Suan',
};

// Cuerpos de agua (/water_bodies) con el nombre corregido.
const cuerposDeAgua = <int, String>{
  1: 'Río Magdalena', 2: 'Ciénaga Bartolo', 3: 'Ciénaga Las Cabezas', 4: 'Ciénaga La Viuda', 5: 'Ciénaga Caimanera',
  6: 'Ciénaga Calabacito', 7: 'Ciénaga Sábalo', 8: 'La Chacha', 9: 'Ciénaga Barba Rucia', 10: 'Ciénaga El Zabalo',
  11: 'Ciénaga de Balboa', 12: 'Ciénaga El Totumo', 13: 'Ciénaga El Salado', 14: 'Ciénaga Los Manatíes',
  15: 'Ciénaga de Mallorquín', 16: 'Ciénaga Bonga', 17: 'Ciénaga La Poza', 18: 'Ciénaga del Rosario', 19: 'Ciénaga El Uvero',
  20: 'Ciénaga de Malambo', 21: 'Ciénaga La Bahía', 22: 'Ciénaga El Convento', 23: 'Ciénaga de Zico', 24: 'Ciénaga de Sabanagrande',
  25: 'Caño Viejo', 26: 'Ciénaga Pescadero', 27: 'Ciénaga Roblá', 28: 'Ciénaga Poza de Jayo', 29: 'Embalse del Guájaro',
  30: 'Laguna de Luruaco', 31: 'Laguna San Juan de Tocagua', 32: 'La Cienaguita', 33: 'Laguna Puerto Caimán',
  34: 'Lago del Cisne', 35: 'Ciénaga de Santo Tomás', 36: 'Complejo cenagoso de Palmar de Varela',
};

/// Ciénagas rodeadas de manglar: Balboa, El Totumo, Los Manatíes, Mallorquín.
const cienagasConManglar = [11, 12, 14, 15];

/// Franja costera del manglar (`LIMITES_MANGLAR` de la web): sur-oeste y norte-este.
const _sur = 10.655, _oeste = -75.285, _norte = 11.09, _este = -74.795;
bool enFranjaManglar(double lat, double lon) => lat >= _sur && lat <= _norte && lon >= _oeste && lon <= _este;

Color colorHex(String hex, {Color respaldo = const Color(0xFF94A3B8)}) => _colorDeHex(hex, respaldo);

Color _colorDeHex(String hex, [Color respaldo = const Color(0xFF94A3B8)]) {
  final limpio = hex.replaceFirst('#', '');
  if (limpio.length < 6) return respaldo;
  final v = int.tryParse(limpio.substring(0, 6), radix: 16); // la API manda algunos con alfa (#b600c7ff)
  return v == null ? respaldo : Color(0xFF000000 | v);
}

double? _numero(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
String _texto(Object? v) => v is String ? v.trim() : '';

// ───────────────────────────── Puntos críticos de riesgo ─────────────────────────────

class TipoEventoCra {
  const TipoEventoCra(this.id, this.nombre, this.colorHex);
  final int id;
  final String nombre;
  final String colorHex;
  Color get color => _colorDeHex(colorHex);

  /// Explicación sencilla de cada tipo (la API solo da el nombre).
  String get explicacion => switch (id) {
        1 => 'El agua sube y cubre calles, casas o el bosque: arroyos, lluvias fuertes o mar de leva.',
        2 => 'La tierra de una ladera se desliza o se cae.',
        3 => 'El mar se come la orilla y la playa retrocede: amenaza directa al manglar costero.',
        4 => 'Fuego en la vegetación; en sequía se propaga rápido.',
        5 => 'El agua lava la base de un talud, una vía o una casa y la deja hueca.',
        6 => 'El suelo se va perdiendo por el agua o el viento.',
        _ => 'Evento registrado por la Corporación.',
      };

  Map<String, Object?> toJson() => {'id': id, 'nombre': nombre, 'color': colorHex};
  static TipoEventoCra desdeJson(Map j) => TipoEventoCra(j['id'] as int, j['nombre'] as String, j['color'] as String);
}

/// Respaldo por si `/critical_points/attributes` no responde (mismos ids y colores de la API).
const tiposRespaldo = <TipoEventoCra>[
  TipoEventoCra(1, 'Inundación', '#386cb0'),
  TipoEventoCra(2, 'Remoción en masa', '#7fc97f'),
  TipoEventoCra(3, 'Erosión costera', '#dada3a'),
  TipoEventoCra(4, 'Incendio forestal', '#f0027f'),
  TipoEventoCra(5, 'Socavamiento', '#b600c7'),
  TipoEventoCra(6, 'Proceso erosivo', '#e68a00'),
];
const zonasRespaldo = <int, String>{1: 'Urbana', 2: 'Costera', 3: 'Rural'};

class PuntoCritico {
  const PuntoCritico({
    required this.id,
    required this.tipo,
    required this.zona,
    required this.municipio,
    required this.descripcion,
    required this.registradoEn,
    required this.confirmado,
    required this.lat,
    required this.lon,
  });
  final int id;
  final TipoEventoCra tipo;
  final String zona;
  final String municipio;
  final String descripcion;
  final DateTime? registradoEn;
  final bool confirmado;
  final double lat;
  final double lon;

  /// Dentro de la franja costera del manglar (el filtro de la pantalla).
  bool get enFranja => enFranjaManglar(lat, lon);

  Map<String, Object?> toJson() => {
        'id': id,
        'tipo': tipo.toJson(),
        'zona': zona,
        'municipio': municipio,
        'descripcion': descripcion,
        'registrado': registradoEn?.toIso8601String(),
        'confirmado': confirmado,
        'lat': lat,
        'lon': lon,
      };
  static PuntoCritico desdeJson(Map j) => PuntoCritico(
        id: j['id'] as int,
        tipo: TipoEventoCra.desdeJson(j['tipo'] as Map),
        zona: j['zona'] as String,
        municipio: j['municipio'] as String,
        descripcion: j['descripcion'] as String,
        registradoEn: DateTime.tryParse(j['registrado'] as String? ?? ''),
        confirmado: j['confirmado'] as bool,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
      );
}

/// Tipos de `/critical_points/attributes/event_types/items`; color sólido (sin alfa).
List<TipoEventoCra> interpretarTipos(Object? json) {
  if (json is! List) return tiposRespaldo;
  final r = <TipoEventoCra>[];
  for (final t in json) {
    if (t is Map && t['id'] is int && t['event_type'] is String) {
      final c = _texto(t['color']);
      r.add(TipoEventoCra(t['id'] as int, _texto(t['event_type']), c.length >= 7 ? c.substring(0, 7) : c));
    }
  }
  return r.isEmpty ? tiposRespaldo : r;
}

Map<int, String> interpretarZonas(Object? json) {
  if (json is! List) return zonasRespaldo;
  final r = {
    for (final z in json)
      if (z is Map && z['id'] is int && z['event_zone'] is String) z['id'] as int: _texto(z['event_zone']),
  };
  return r.isEmpty ? zonasRespaldo : r;
}

/// `/critical_points/items?format=geojson`, de lo más nuevo a lo más viejo. Con [soloFranja] (lo
/// de siempre en la web) se queda solo con la franja del manglar; sin él trae todo el Atlántico y
/// la pantalla filtra con [PuntoCritico.enFranja].
List<PuntoCritico> interpretarPuntosCriticos(Object? json, List<TipoEventoCra> tipos, Map<int, String> zonas,
    {bool soloFranja = true}) {
  final porId = {for (final t in tipos) t.id: t};
  final r = <PuntoCritico>[];
  for (final f in _rasgos(json)) {
    final c = (f['geometry'] as Map?)?['coordinates'];
    if (c is! List || c.length < 2) continue;
    final lon = _numero(c[0]), lat = _numero(c[1]);
    if (lat == null || lon == null || (soloFranja && !enFranjaManglar(lat, lon))) continue;
    final p = f['properties'] as Map? ?? const {};
    final tipoId = p['event_type_id'] is int ? p['event_type_id'] as int : 0;
    r.add(PuntoCritico(
      id: (f['id'] as num?)?.toInt() ?? 0,
      tipo: porId[tipoId] ?? TipoEventoCra(tipoId, 'Otro evento', '#94a3b8'),
      zona: zonas[p['event_zone_id']] ?? '',
      municipio: municipiosCra[p['municipality_id']] ?? '',
      descripcion: _texto(p['description']),
      registradoEn: DateTime.tryParse(_texto(p['datetime'])),
      confirmado: p['confirmed'] == 1,
      lat: lat,
      lon: lon,
    ));
  }
  r.sort((a, b) => (b.registradoEn ?? DateTime(0)).compareTo(a.registradoEn ?? DateTime(0)));
  return r;
}

Iterable<Map> _rasgos(Object? json) sync* {
  if (json is! Map || json['features'] is! List) return;
  for (final f in json['features'] as List) {
    if (f is Map) yield f;
  }
}

// ───────────────────────────── Focos de calor por satélite ─────────────────────────────

class FocoCalor {
  const FocoCalor({
    required this.id,
    required this.municipio,
    required this.desde,
    required this.hasta,
    required this.focos,
    required this.satelites,
    required this.confianza,
    required this.anillo,
    required this.lat,
    required this.lon,
  });
  final int id;
  final String municipio;
  final DateTime? desde;
  final DateTime? hasta;
  final int focos;
  final String satelites;

  /// `very_high`, `high`, `nominal`, `low`… tal como la manda la API.
  final String confianza;

  /// Borde exterior del polígono (lat, lon), para dibujarlo en el mapa.
  final List<(double, double)> anillo;
  final double lat;
  final double lon;

  String get confianzaTexto => switch (confianza) {
        'very_high' => 'muy alta',
        'high' => 'alta',
        'nominal' => 'media',
        'low' => 'baja',
        _ => confianza.isEmpty ? 'sin dato' : confianza,
      };

  Map<String, Object?> toJson() => {
        'id': id,
        'municipio': municipio,
        'desde': desde?.toIso8601String(),
        'hasta': hasta?.toIso8601String(),
        'focos': focos,
        'satelites': satelites,
        'confianza': confianza,
        'anillo': [for (final (a, o) in anillo) [a, o]],
        'lat': lat,
        'lon': lon,
      };
  static FocoCalor desdeJson(Map j) => FocoCalor(
        id: j['id'] as int,
        municipio: j['municipio'] as String,
        desde: DateTime.tryParse(j['desde'] as String? ?? ''),
        hasta: DateTime.tryParse(j['hasta'] as String? ?? ''),
        focos: j['focos'] as int,
        satelites: j['satelites'] as String,
        confianza: j['confianza'] as String,
        anillo: [for (final p in j['anillo'] as List) (((p as List)[0] as num).toDouble(), (p[1] as num).toDouble())],
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
      );
}

/// `/wildfire-clusters/items?format=geojson`: el centro (promedio del borde exterior, como la web)
/// debe caer en la franja del manglar. Del más reciente al más viejo.
List<FocoCalor> interpretarFocos(Object? json) {
  final r = <FocoCalor>[];
  for (final f in _rasgos(json)) {
    final g = f['geometry'];
    if (g is! Map) continue;
    final List? anilloCrudo = switch (g['type']) {
      'Polygon' => (g['coordinates'] as List?)?.firstOrNull as List?,
      'MultiPolygon' => ((g['coordinates'] as List?)?.firstOrNull as List?)?.firstOrNull as List?,
      _ => null,
    };
    if (anilloCrudo == null || anilloCrudo.isEmpty) continue;
    final anillo = <(double, double)>[];
    for (final p in anilloCrudo) {
      if (p is List && p.length >= 2) {
        final lon = _numero(p[0]), lat = _numero(p[1]);
        if (lat != null && lon != null) anillo.add((lat, lon));
      }
    }
    if (anillo.isEmpty) continue;
    final lat = anillo.fold<double>(0, (s, p) => s + p.$1) / anillo.length;
    final lon = anillo.fold<double>(0, (s, p) => s + p.$2) / anillo.length;
    if (!enFranjaManglar(lat, lon)) continue;
    final p = f['properties'] as Map? ?? const {};
    r.add(FocoCalor(
      id: (f['id'] as num?)?.toInt() ?? 0,
      municipio: municipiosCra[p['municipality_id']] ?? '',
      desde: DateTime.tryParse(_texto(p['oldest_acquisition'])),
      hasta: DateTime.tryParse(_texto(p['newest_acquisition'])),
      focos: (p['num_fires'] as num?)?.toInt() ?? 0,
      satelites: _texto(p['satellites']).replaceAll(',', ', '),
      confianza: _texto(p['fire_confidence']),
      anillo: anillo,
      lat: lat,
      lon: lon,
    ));
  }
  r.sort((a, b) => (b.hasta ?? DateTime(0)).compareTo(a.hasta ?? DateTime(0)));
  return r;
}

// ───────────────────────────── Calidad del agua ─────────────────────────────

class MuestraAgua {
  const MuestraAgua({
    required this.id,
    required this.codigo,
    required this.cuerpoId,
    required this.cuerpo,
    required this.lat,
    required this.lon,
    this.muestreadoEn,
    this.ica,
    this.oxigeno,
    this.ph,
    this.temperatura,
    this.coliformes,
  });
  final int id;
  final String codigo;
  final int cuerpoId;
  final String cuerpo;
  final double lat;
  final double lon;
  final DateTime? muestreadoEn;
  final double? ica;
  final double? oxigeno;
  final double? ph;
  final double? temperatura;
  final double? coliformes;

  bool get conManglar => cienagasConManglar.contains(cuerpoId);
  CategoriaIca? get categoria => categoriaIca(ica);

  Map<String, Object?> toJson() => {
        'id': id,
        'codigo': codigo,
        'cuerpo_id': cuerpoId,
        'cuerpo': cuerpo,
        'lat': lat,
        'lon': lon,
        'muestreado': muestreadoEn?.toIso8601String(),
        'ica': ica,
        'od': oxigeno,
        'ph': ph,
        'temp': temperatura,
        'coli': coliformes,
      };
  static MuestraAgua desdeJson(Map j) => MuestraAgua(
        id: j['id'] as int,
        codigo: j['codigo'] as String,
        cuerpoId: j['cuerpo_id'] as int,
        cuerpo: j['cuerpo'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        muestreadoEn: DateTime.tryParse(j['muestreado'] as String? ?? ''),
        ica: _numero(j['ica']),
        oxigeno: _numero(j['od']),
        ph: _numero(j['ph']),
        temperatura: _numero(j['temp']),
        coliformes: _numero(j['coli']),
      );
}

/// Puntos de muestreo + su medición más reciente (misma regla que la web).
List<MuestraAgua> interpretarAgua(Object? puntosJson, Object? medicionesJson) {
  final ultima = <int, Map>{};
  if (medicionesJson is List) {
    for (final m in medicionesJson) {
      if (m is! Map || m['sampling_point_id'] is! int) continue;
      final id = m['sampling_point_id'] as int;
      final previa = ultima[id];
      if (previa == null || _texto(m['sampled_at']).compareTo(_texto(previa['sampled_at'])) > 0) ultima[id] = m;
    }
  }
  final r = <MuestraAgua>[];
  for (final f in _rasgos(puntosJson)) {
    final c = (f['geometry'] as Map?)?['coordinates'];
    if (c is! List || c.length < 2) continue;
    final lon = _numero(c[0]), lat = _numero(c[1]);
    if (lat == null || lon == null || !enFranjaManglar(lat, lon)) continue;
    final id = (f['id'] as num?)?.toInt() ?? 0;
    final p = f['properties'] as Map? ?? const {};
    final cuerpoId = p['water_body_id'] is int ? p['water_body_id'] as int : 0;
    final m = ultima[id];
    r.add(MuestraAgua(
      id: id,
      codigo: _texto(p['code']),
      cuerpoId: cuerpoId,
      cuerpo: cuerposDeAgua[cuerpoId] ?? 'Cuerpo de agua',
      lat: lat,
      lon: lon,
      muestreadoEn: DateTime.tryParse(_texto(m?['sampled_at'])),
      ica: _numero(m?['ica']),
      oxigeno: _numero(m?['od_mg_l']),
      ph: _numero(m?['ph']),
      temperatura: _numero(m?['temperature_c']),
      coliformes: _numero(m?['coliforms_nmp_100ml']),
    ));
  }
  return r;
}

/// Una ciénaga con todas sus estaciones: la tarjeta del semáforo.
class CienagaAgua {
  const CienagaAgua(this.cuerpoId, this.nombre, this.muestras);
  final int cuerpoId;
  final String nombre;
  final List<MuestraAgua> muestras;

  bool get conManglar => cienagasConManglar.contains(cuerpoId);
  List<MuestraAgua> get medidas => [for (final m in muestras) if (m.muestreadoEn != null) m];
  DateTime? get ultimaFecha => medidas.map((m) => m.muestreadoEn!).fold<DateTime?>(null, (u, t) => u == null || t.isAfter(u) ? t : u);

  double? _promedio(double? Function(MuestraAgua) campo) {
    final v = [for (final m in muestras) ?campo(m)];
    return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  }

  double? get ica => _promedio((m) => m.ica);
  double? get oxigeno => _promedio((m) => m.oxigeno);
  double? get ph => _promedio((m) => m.ph);
  double? get temperatura => _promedio((m) => m.temperatura);

  /// Coliformes: el peor punto (lo que importa para bañarse o pescar).
  double? get coliformes {
    final v = [for (final m in muestras) ?m.coliformes];
    return v.isEmpty ? null : v.reduce((a, b) => a > b ? a : b);
  }
}

/// Agrupa por ciénaga; primero las rodeadas de manglar, luego por nombre.
List<CienagaAgua> agruparPorCienaga(List<MuestraAgua> muestras) {
  final grupos = <int, List<MuestraAgua>>{};
  for (final m in muestras) {
    (grupos[m.cuerpoId] ??= []).add(m);
  }
  final r = [for (final e in grupos.entries) CienagaAgua(e.key, e.value.first.cuerpo, e.value)];
  r.sort((a, b) {
    if (a.conManglar != b.conManglar) return a.conManglar ? -1 : 1;
    return a.nombre.compareTo(b.nombre);
  });
  return r;
}

/// Escala del ICA del IDEAM (0 a 1), la misma de la web (`ESCALA_ICA`).
class CategoriaIca {
  const CategoriaIca(this.etiqueta, this.colorHex, this.desde, this.explicacion);
  final String etiqueta;
  final int colorHex;
  final double desde;
  final String explicacion;
  Color get color => Color(colorHex);
}

const escalaIca = <CategoriaIca>[
  CategoriaIca('Buena', 0xFF2563EB, 0.91, 'Agua sana para la vida del manglar y la pesca.'),
  CategoriaIca('Aceptable', 0xFF16A34A, 0.71, 'En general bien; conviene seguir midiendo.'),
  CategoriaIca('Regular', 0xFFEAB308, 0.51, 'Hay señales de contaminación: peces y aves lo sienten.'),
  CategoriaIca('Mala', 0xFFF97316, 0.26, 'Contaminada: evita bañarte y no consumas lo que salga de ahí.'),
  CategoriaIca('Muy mala', 0xFFDC2626, 0, 'Muy contaminada: riesgo para la salud y para la fauna.'),
];
const colorSinDato = Color(0xFF94A3B8);

CategoriaIca? categoriaIca(double? ica) {
  if (ica == null) return null;
  for (final c in escalaIca) {
    if (ica >= c.desde) return c;
  }
  return escalaIca.last;
}

/// Semáforo de un indicador suelto.
enum Semaforo { bien, ojo, mal, sinDato }

/// Cada indicador del agua, explicado en palabras sencillas y con su semáforo. Los cortes de oxígeno,
/// pH y coliformes son los de referencia en Colombia (Decreto 1594 de 1984: oxígeno ≥ 4 mg/L para la
/// fauna; coliformes totales ≤ 1.000 para bañarse y ≤ 5.000 para contacto secundario).
class Indicador {
  const Indicador(this.nombre, this.unidad, this.explicacion, this.semaforo, this.formato);
  final String nombre;
  final String unidad;
  final String explicacion;
  final Semaforo Function(double v) semaforo;
  final String Function(double v) formato;

  Semaforo evaluar(double? v) => v == null ? Semaforo.sinDato : semaforo(v);
}

String decimal(double v, [int d = 1]) => v.toStringAsFixed(d).replaceAll('.', ',');

/// Miles con punto, como se escribe en Colombia.
String miles(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer(v < 0 ? '−' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

final indicadoresAgua = <String, Indicador>{
  'ica': Indicador(
    'Índice de calidad (ICA)',
    '',
    'Una nota de 0 a 1 que resume varias medidas. Cerca de 1, agua sana; cerca de 0, muy contaminada.',
    (v) => v >= 0.71 ? Semaforo.bien : (v >= 0.51 ? Semaforo.ojo : Semaforo.mal),
    (v) => decimal(v, 2),
  ),
  'od': Indicador(
    'Oxígeno disuelto',
    'mg/L',
    'El aire que respiran peces, jaibas y camarones. Con menos de 4 mg/L se asfixian.',
    (v) => v >= 5 ? Semaforo.bien : (v >= 4 ? Semaforo.ojo : Semaforo.mal),
    (v) => decimal(v),
  ),
  'ph': Indicador(
    'pH (acidez)',
    '',
    'Si el agua está ácida o alcalina. Entre 6,5 y 8,5 es lo normal para una ciénaga.',
    (v) => v >= 6.5 && v <= 8.5 ? Semaforo.bien : (v >= 6 && v <= 9 ? Semaforo.ojo : Semaforo.mal),
    (v) => decimal(v),
  ),
  'coli': Indicador(
    'Coliformes',
    'NMP/100 mL',
    'Bacterias que llegan con aguas negras. Más de 1.000 no es apta para bañarse; más de 5.000, ni para pescar a mano.',
    (v) => v <= 1000 ? Semaforo.bien : (v <= 5000 ? Semaforo.ojo : Semaforo.mal),
    (v) => miles(v),
  ),
  'temp': Indicador(
    'Temperatura',
    '°C',
    'El agua más caliente guarda menos oxígeno. En el Caribe suele estar entre 27 y 32 °C.',
    (v) => v <= 32 ? Semaforo.bien : (v <= 34 ? Semaforo.ojo : Semaforo.mal),
    (v) => decimal(v),
  ),
};

// ───────────────────────────── El manglar en cifras ─────────────────────────────

/// Un sector del workflow de la C.R.A. (`resumen` + `carb.sect` de core.json).
class SectorCifras {
  const SectorCifras({
    required this.zona,
    required this.nombre,
    required this.probableHa,
    required this.altaHa,
    required this.perdidaHa,
    required this.gananciaHa,
    required this.carbonoT,
    required this.alturaMedianaM,
  });
  final int zona;
  final String nombre;
  final double probableHa;
  final double altaHa;
  final double perdidaHa;
  final double gananciaHa;
  final double carbonoT;
  final double alturaMedianaM;

  /// Id del sector en la app (`zonas.dart`): 1 Mallorquín, 2 Balboa, 3 Manatíes, 4 Totumo.
  String get zonaApp => const {1: 'mallorquin', 2: 'tubara', 3: 'juan_de_acosta', 4: 'piojo'}[zona] ?? '';

  Map<String, Object?> toJson() => {
        'zona': zona,
        'nombre': nombre,
        'probable': probableHa,
        'alta': altaHa,
        'perdida': perdidaHa,
        'ganancia': gananciaHa,
        'carbono': carbonoT,
        'altura': alturaMedianaM,
      };
  static SectorCifras desdeJson(Map j) => SectorCifras(
        zona: j['zona'] as int,
        nombre: j['nombre'] as String,
        probableHa: (j['probable'] as num).toDouble(),
        altaHa: (j['alta'] as num).toDouble(),
        perdidaHa: (j['perdida'] as num).toDouble(),
        gananciaHa: (j['ganancia'] as num).toDouble(),
        carbonoT: (j['carbono'] as num).toDouble(),
        alturaMedianaM: (j['altura'] as num).toDouble(),
      );
}

class CifrasWorkflow {
  const CifrasWorkflow({
    required this.sectores,
    required this.carbonoTotalT,
    required this.carbonoPorHa,
    required this.enterramientoAnualT,
    required this.serieArea,
  });
  final List<SectorCifras> sectores;
  final double carbonoTotalT;
  final double carbonoPorHa;
  final double enterramientoAnualT;

  /// Extensión anual del manglar (año, ha).
  final List<(int, double)> serieArea;

  double get probableHa => sectores.fold(0, (s, x) => s + x.probableHa);
  double get altaHa => sectores.fold(0, (s, x) => s + x.altaHa);
  double get perdidaHa => sectores.fold(0, (s, x) => s + x.perdidaHa);
  double get gananciaHa => sectores.fold(0, (s, x) => s + x.gananciaHa);

  Map<String, Object?> toJson() => {
        'sectores': [for (final s in sectores) s.toJson()],
        'carbono': carbonoTotalT,
        'c_ha': carbonoPorHa,
        'enterramiento': enterramientoAnualT,
        'serie': [for (final (a, h) in serieArea) [a, h]],
      };
  static CifrasWorkflow desdeJson(Map j) => CifrasWorkflow(
        sectores: [for (final s in j['sectores'] as List) SectorCifras.desdeJson(s as Map)],
        carbonoTotalT: (j['carbono'] as num).toDouble(),
        carbonoPorHa: (j['c_ha'] as num).toDouble(),
        enterramientoAnualT: (j['enterramiento'] as num).toDouble(),
        serieArea: [for (final p in j['serie'] as List) (((p as List)[0] as num).toInt(), (p[1] as num).toDouble())],
      );
}

/// Lee solo lo que la app muestra de `core.json` (1,2 MB): `resumen`, `carb` y `t_area`.
CifrasWorkflow? interpretarCore(Object? json) {
  if (json is! Map || json['resumen'] is! List || json['carb'] is! Map) return null;
  final carb = json['carb'] as Map;
  final carbonoPorZona = <int, double>{
    for (final s in (carb['sect'] as List? ?? const []))
      if (s is Map && int.tryParse('${s['k']}') != null) int.parse('${s['k']}'): _numero(s['tC']) ?? 0,
  };
  final sectores = <SectorCifras>[];
  for (final s in json['resumen'] as List) {
    if (s is! Map || s['zona'] is! int) continue;
    final z = s['zona'] as int;
    sectores.add(SectorCifras(
      zona: z,
      nombre: _texto(s['sector']),
      probableHa: _numero(s['referencia_ha']) ?? 0,
      altaHa: _numero(s['segura_ha']) ?? 0,
      perdidaHa: _numero(s['perdida_ha']) ?? 0,
      gananciaHa: _numero(s['ganancia_ha']) ?? 0,
      carbonoT: carbonoPorZona[z] ?? 0,
      alturaMedianaM: _numero(s['altura_mediana_m']) ?? 0,
    ));
  }
  if (sectores.isEmpty) return null;
  final serie = <(int, double)>[
    for (final p in (json['t_area'] as List? ?? const []))
      if (p is List && p.length >= 2 && _numero(p[0]) != null && _numero(p[1]) != null)
        (_numero(p[0])!.toInt(), _numero(p[1])!),
  ];
  final ent = (_numero(carb['ent_manglar_tC']) ?? 0) + (_numero(carb['ent_cienagas_tot']) ?? 0);
  return CifrasWorkflow(
    sectores: sectores,
    carbonoTotalT: _numero(carb['reserva_tC']) ?? 0,
    carbonoPorHa: _numero(carb['c_ha']) ?? 0,
    enterramientoAnualT: ent,
    serieArea: serie,
  );
}

/// Las cifras de reportes ciudadanos (RPC `estadisticas(desde)`), solo agregados.
class EstadisticasReportes {
  const EstadisticasReportes({
    required this.total,
    required this.validados,
    required this.pendientes,
    required this.descartados,
    required this.porTipo,
    this.medianaValidacionMin,
    this.pctDentroManglar,
    this.generadoEn,
  });
  final int total;
  final int validados;
  final int pendientes;
  final int descartados;
  final Map<String, int> porTipo;
  final double? medianaValidacionMin;
  final double? pctDentroManglar;
  final DateTime? generadoEn;

  static const nombresTipo = <String, String>{
    'tala': 'Tala',
    'quema': 'Quema',
    'relleno': 'Relleno',
    'vertimiento': 'Vertimiento',
    'basuras': 'Basuras',
    'cano_taponado': 'Caño taponado',
    'fauna': 'Fauna',
    'otro': 'Otro',
  };

  Map<String, Object?> toJson() => {
        'total': total,
        'validados': validados,
        'pendientes': pendientes,
        'descartados': descartados,
        'por_tipo': porTipo,
        'mediana_validacion_min': medianaValidacionMin,
        'pct_dentro_manglar': pctDentroManglar,
        'generado_en': generadoEn?.toIso8601String(),
      };

  static EstadisticasReportes? desdeJson(Object? json) {
    if (json is! Map || json['total'] is! num) return null;
    int entero(Object? v) => v is num && v.isFinite && v >= 0 ? v.toInt() : 0;
    final tipos = json['por_tipo'];
    return EstadisticasReportes(
      total: entero(json['total']),
      validados: entero(json['validados']),
      pendientes: entero(json['pendientes']),
      descartados: entero(json['descartados']),
      porTipo: {
        if (tipos is Map)
          for (final e in tipos.entries)
            if (e.key is String) e.key as String: entero(e.value),
      },
      medianaValidacionMin: _numero(json['mediana_validacion_min']),
      pctDentroManglar: _numero(json['pct_dentro_manglar']),
      generadoEn: DateTime.tryParse(_texto(json['generado_en'])),
    );
  }
}


// ───────────────────────────── Focos cerca del manglar ─────────────────────────────

/// Lo que usa el bot para avisar: un foco cuenta si su última pasada del satélite fue en los
/// últimos [ventanaFocos] y su centro está a menos de [radioFocosM] del manglar.
const ventanaFocos = Duration(days: 7);
const radioFocosM = 2000.0;

/// Focos recientes a menos de 2 km del manglar. [distanciaM] la da `Manglar.ubicar` (0 si cae
/// dentro de un polígono); se inyecta para probar sin cargar la capa.
List<FocoCalor> focosCercaDelManglar(
  List<FocoCalor> focos,
  DateTime ahora,
  double Function(double lat, double lon) distanciaM,
) {
  final desde = ahora.subtract(ventanaFocos);
  return [
    for (final f in focos)
      if (f.hasta != null && !f.hasta!.isBefore(desde) && distanciaM(f.lat, f.lon) <= radioFocosM) f,
  ];
}

/// «27 nov 2026» (fecha corta en español, sin depender del idioma del teléfono).
String fechaCorta(DateTime? t) {
  if (t == null) return 'sin fecha';
  const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  return '${t.day} ${meses[t.month - 1]} ${t.year}';
}
