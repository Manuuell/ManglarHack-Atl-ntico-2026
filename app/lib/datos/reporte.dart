import 'package:latlong2/latlong.dart';

import 'tipos.dart';

/// Cómo se obtuvo la ubicación. El GPS en el sitio pesa más que un punto marcado a mano.
enum MetodoUbicacion {
  gps('gps', 'GPS del teléfono'),
  mapa('mapa', 'Marcado en el mapa'),
  enlace('enlace', 'Enlace de Google Maps');

  const MetodoUbicacion(this.slug, this.nombre);
  final String slug;
  final String nombre;
  static MetodoUbicacion deSlug(String s) => values.firstWhere((m) => m.slug == s, orElse: () => gps);
}

/// Dónde va el envío al servidor. Es del teléfono, no del contrato.
enum Envio { enCola, enviando, enviado, error }

class CambioEstado {
  const CambioEstado(this.estado, this.fecha, [this.nota]);
  final EstadoReporte estado;
  final DateTime fecha;
  final String? nota;

  Map<String, dynamic> toJson() => {'estado': estado.slug, 'fecha': fecha.toIso8601String(), 'nota': nota};
  static CambioEstado fromJson(Map<String, dynamic> j) => CambioEstado(
        EstadoReporte.deSlug(j['estado'] as String),
        DateTime.parse(j['fecha'] as String),
        j['nota'] as String?,
      );
}

class Reporte {
  Reporte({
    required this.id,
    required this.tipo,
    required this.descripcion,
    required this.punto,
    required this.precisionM,
    required this.metodo,
    required this.capturadoEn,
    required this.momento,
    required this.magnitud,
    required this.zonaId,
    required this.zonaNombre,
    required this.municipio,
    required this.dentroPoligono,
    required this.distanciaM,
    required this.prioridad,
    required this.motivosPrioridad,
    required this.confianza,
    required this.anonimo,
    required this.reportanteId,
    this.fotoRef,
    this.fotoHash,
    this.fotoDeCamara = false,
    this.fotoUrl,
    this.estado = EstadoReporte.recibido,
    List<CambioEstado>? historial,
    this.envio = Envio.enCola,
    this.intentos = 0,
    this.ultimoError,
    this.enviadoEn,
    this.capturadoSinSenal = false,
    this.canal = 'app',
  }) : historial = historial ?? [];

  /// UUID generado en el teléfono: si la respuesta del servidor se pierde y se
  /// reintenta, el servidor reconoce el mismo id y no lo duplica.
  final String id;
  final TipoAmenaza tipo;
  final String descripcion;
  final LatLng punto;
  final double? precisionM;
  final MetodoUbicacion metodo;

  /// Hora del teléfono al capturar. La de recepción la pone el servidor.
  final DateTime capturadoEn;
  final Momento momento;
  final Magnitud magnitud;

  final String zonaId;
  final String zonaNombre;
  final String municipio;
  final bool dentroPoligono;
  final double distanciaM;

  int prioridad;
  final List<String> motivosPrioridad;

  /// Solidez del reporte (0-100), calculada en el teléfono para guiar al ciudadano.
  /// El servidor la acota (máx. 80 desde el teléfono) y le suma corroboración e IA;
  /// al sincronizar, la app muestra la del servidor.
  int confianza;
  final bool anonimo;
  final String? reportanteId;

  /// Foto guardada en el teléfono (ruta o clave). No se sube al repo ni se publica.
  final String? fotoRef;

  /// SHA-256 de la foto: el servidor detecta fotos repetidas o recicladas.
  final String? fotoHash;

  /// Tomada con la cámara en el momento (pesa más que una de la galería).
  final bool fotoDeCamara;
  String? fotoUrl;

  EstadoReporte estado;
  final List<CambioEstado> historial;
  Envio envio;
  int intentos;
  String? ultimoError;
  DateTime? enviadoEn;

  /// Se capturó sin señal: el panel lo muestra como «sincronizado tarde» con su hora real.
  final bool capturadoSinSenal;

  /// Por dónde llegó: 'app' (Android) o 'web' (navegador, p. ej. el QR de un letrero).
  /// El backend acepta app, web y whatsapp.
  final String canal;

  /// Número de caso corto para decirlo por teléfono o WhatsApp: ZK-7F3A (ZK de Zanky; los 4 hex salen del id, así reintentar no cambia el número).
  String get caso => 'ZK-${id.replaceAll('-', '').substring(0, 4).toUpperCase()}';

  /// Lo que viaja al servidor (contrato común, handoff/05). Nunca la ruta local de la foto.
  Map<String, dynamic> aServidor() => {
        'id': id,
        'canal': canal,
        'tipo': tipo.slug,
        'descripcion': descripcion,
        'lat': punto.latitude,
        'lon': punto.longitude,
        'precision_m': precisionM,
        'metodo_ubicacion': metodo.slug,
        'capturado_en': capturadoEn.toUtc().toIso8601String(),
        'momento': momento.slug,
        'magnitud': magnitud.slug,
        'zona': zonaId,
        'municipio': municipio,
        'dentro_poligono': dentroPoligono,
        'distancia_m': distanciaM.isFinite ? distanciaM.round() : null,
        'prioridad': prioridad,
        'confianza': confianza,
        'foto_hash': fotoHash,
        'foto_de_camara': fotoDeCamara,
        'foto_url': fotoUrl,
        'anonimo': anonimo,
        'reportante_id': anonimo ? null : reportanteId,
        'sincronizado_tarde': capturadoSinSenal,
      };

  Map<String, dynamic> toJson() => {
        ...aServidor(),
        'zona_nombre': zonaNombre,
        'motivos_prioridad': motivosPrioridad,
        'foto_ref': fotoRef,
        'estado': estado.slug,
        'historial': historial.map((h) => h.toJson()).toList(),
        'envio': envio.name,
        'intentos': intentos,
        'ultimo_error': ultimoError,
        'enviado_en': enviadoEn?.toIso8601String(),
        'reportante_local': reportanteId,
      };

  static Reporte fromJson(Map<String, dynamic> j) => Reporte(
        id: j['id'] as String,
        tipo: TipoAmenaza.deSlug(j['tipo'] as String),
        descripcion: j['descripcion'] as String? ?? '',
        punto: LatLng((j['lat'] as num).toDouble(), (j['lon'] as num).toDouble()),
        precisionM: (j['precision_m'] as num?)?.toDouble(),
        metodo: MetodoUbicacion.deSlug(j['metodo_ubicacion'] as String? ?? 'gps'),
        capturadoEn: DateTime.parse(j['capturado_en'] as String).toLocal(),
        momento: Momento.deSlug(j['momento'] as String? ?? 'ahora'),
        magnitud: Magnitud.deSlug(j['magnitud'] as String? ?? 'pequena'),
        zonaId: j['zona'] as String? ?? '',
        zonaNombre: j['zona_nombre'] as String? ?? '',
        municipio: j['municipio'] as String? ?? '',
        dentroPoligono: j['dentro_poligono'] as bool? ?? false,
        distanciaM: (j['distancia_m'] as num?)?.toDouble() ?? double.infinity,
        prioridad: j['prioridad'] as int? ?? 3,
        motivosPrioridad: [...?(j['motivos_prioridad'] as List?)?.cast<String>()],
        confianza: j['confianza'] as int? ?? 0,
        anonimo: j['anonimo'] as bool? ?? false,
        reportanteId: j['reportante_local'] as String? ?? j['reportante_id'] as String?,
        fotoRef: j['foto_ref'] as String?,
        fotoHash: j['foto_hash'] as String?,
        fotoDeCamara: j['foto_de_camara'] as bool? ?? false,
        fotoUrl: j['foto_url'] as String?,
        estado: EstadoReporte.deSlug(j['estado'] as String? ?? 'recibido'),
        historial: [
          for (final h in (j['historial'] as List?) ?? const []) CambioEstado.fromJson(h as Map<String, dynamic>),
        ],
        envio: Envio.values.firstWhere((e) => e.name == j['envio'], orElse: () => Envio.enCola),
        intentos: j['intentos'] as int? ?? 0,
        ultimoError: j['ultimo_error'] as String?,
        enviadoEn: j['enviado_en'] == null ? null : DateTime.parse(j['enviado_en'] as String),
        capturadoSinSenal: j['sincronizado_tarde'] as bool? ?? false,
        canal: j['canal'] as String? ?? 'app',
      );
}
