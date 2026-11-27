import '../experiencia/entrada_evento.dart';

enum TipoPunto { asistenciaEvento, estacionEducativa, fotoFija, sensor }

extension TipoPuntoTexto on TipoPunto {
  String get codigo => switch (this) {
    TipoPunto.asistenciaEvento => 'asistencia_evento',
    TipoPunto.estacionEducativa => 'estacion_educativa',
    TipoPunto.fotoFija => 'foto_fija',
    TipoPunto.sensor => 'sensor',
  };
  String get nombre => switch (this) {
    TipoPunto.asistenciaEvento => 'Asistencia a jornada',
    TipoPunto.estacionEducativa => 'Estación educativa',
    TipoPunto.fotoFija => 'Fotografía fija',
    TipoPunto.sensor => 'Sensor',
  };
}

final _codigo = RegExp(r'^[a-z0-9-]{3,40}$');

String? codigoPuntoValido(String? valor) {
  final codigo = valor?.trim().toLowerCase();
  return codigo != null && _codigo.hasMatch(codigo) ? codigo : null;
}

String? leerCodigoPunto(Uri uri) {
  final directo = codigoPuntoValido(uri.queryParameters['punto']);
  if (directo != null) return directo;
  final fragmento = uri.fragment;
  final pregunta = fragmento.indexOf('?');
  if (pregunta < 0) return null;
  try {
    return codigoPuntoValido(Uri.splitQueryString(fragmento.substring(pregunta + 1))['punto']);
  } catch (_) {
    return null;
  }
}

String enlacePunto(String codigo) => '$urlAppWeb?punto=${Uri.encodeQueryComponent(codigo)}';

class PuntoZanky {
  const PuntoZanky({required this.codigo, required this.tipo, required this.titulo,
    this.descripcion = '', this.zona = '', this.lat, this.lon, this.eventoId,
    this.sensorId, this.activo = true});

  final String codigo;
  final TipoPunto tipo;
  final String titulo;
  final String descripcion;
  final String zona;
  final double? lat;
  final double? lon;
  final String? eventoId;
  final String? sensorId;
  final bool activo;

  factory PuntoZanky.deJson(Map<String, dynamic> j) => PuntoZanky(
    codigo: j['codigo'] as String,
    tipo: TipoPunto.values.firstWhere((t) => t.codigo == j['tipo']),
    titulo: j['titulo'] as String,
    descripcion: j['descripcion'] as String? ?? '',
    zona: j['zona'] as String? ?? '',
    lat: (j['lat'] as num?)?.toDouble(), lon: (j['lon'] as num?)?.toDouble(),
    eventoId: j['evento_id'] as String?, sensorId: j['sensor_id'] as String?,
    activo: j['activo'] as bool? ?? true,
  );

  Map<String, dynamic> aJson() => {
    'codigo': codigo, 'tipo': tipo.codigo, 'titulo': titulo,
    'descripcion': descripcion, 'zona': zona, 'lat': lat, 'lon': lon,
    'evento_id': eventoId, 'sensor_id': sensorId, 'activo': activo,
  };
}

/// Fichas locales para explorar la función cuando no hay servidor configurado.
const puntosDemostracion = <PuntoZanky>[
  PuntoZanky(codigo: 'demo-estacion', tipo: TipoPunto.estacionEducativa,
    titulo: 'Las raíces del manglar', zona: 'Ciénaga de Mallorquín',
    descripcion: 'Observa cómo las raíces protegen la orilla.'),
  PuntoZanky(codigo: 'demo-foto', tipo: TipoPunto.fotoFija,
    titulo: 'Fotografía de seguimiento', zona: 'Ciénaga de Mallorquín'),
];
