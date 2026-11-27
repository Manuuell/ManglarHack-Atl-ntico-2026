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
///
/// - [enCola]: guardado en el teléfono; sale solo cuando hay señal. También vuelve aquí
///   si el intento falló por la red (sin señal, señal que no pasa datos, plazo vencido):
///   eso no es un error del reporte y no suma intentos.
/// - [enviando]: un intento en curso.
/// - [enviado]: el servidor respondió con su id. Solo entonces.
/// - [error]: el servidor respondió con un fallo pasajero (5xx, 429, 401/403 de
///   configuración, respuesta inesperada). Se reintenta solo, con espera creciente.
/// - [rechazado]: el servidor dijo que NO a ese reporte (400: p. ej. punto fuera del
///   Atlántico). Reintentar no sirve: no se reintenta, no cuenta como pendiente y
///   [Reporte.motivoRechazo] dice por qué, en palabras para la persona.
enum Envio { enCola, enviando, enviado, error, rechazado }

/// Límites que exige el servidor para la ubicación (CHECK de backend/supabase/schema.sql y
/// crear_reporte). Un punto fuera de esta caja nunca se aceptará: la app no lo deja enviar.
abstract final class AreaServidor {
  static const latMin = 10.2, latMax = 11.4, lonMin = -75.7, lonMax = -74.4;

  static bool contiene(LatLng p) =>
      p.latitude >= latMin && p.latitude <= latMax && p.longitude >= lonMin && p.longitude <= lonMax;
}

/// Largo máximo de la descripción en el servidor, contado como Postgres (puntos de código,
/// no letras visibles: un emoji de familia son 7).
const maxDescripcionServidor = 1000;

/// Recorta [texto] a [maximo] puntos de código sin partir un par sustituto.
String recortarPuntosDeCodigo(String texto, [int maximo = maxDescripcionServidor]) {
  final r = texto.runes;
  if (r.length <= maximo) return texto;
  return String.fromCharCodes(r.take(maximo));
}

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
    this.prioridadLocal,
    this.idPublico,
    this.motivoRechazo,
    this.fotoReducida = false,
    this.cambiadoEn,
  }) : historial = historial ?? [];

  /// UUID generado en el teléfono: si la respuesta del servidor se pierde y se
  /// reintenta, el servidor reconoce el mismo id y no lo duplica.
  final String id;
  final TipoAmenaza tipo;
  final String descripcion;
  final LatLng punto;
  final double? precisionM;
  final MetodoUbicacion metodo;

  /// Hora del teléfono al guardar el reporte (al tocar «Enviar»), no al abrir el formulario:
  /// así el servidor no marca «sincronizado tarde» a quien tardó en llenarlo con señal, y la
  /// demora que mide es solo la de la cola. Cuándo pasó lo dice [momento]. La hora de
  /// recepción la pone el servidor.
  final DateTime capturadoEn;
  final Momento momento;
  final Magnitud magnitud;

  final String zonaId;
  final String zonaNombre;
  final String municipio;
  final bool dentroPoligono;
  final double distanciaM;

  /// La que se muestra: la del teléfono hasta que el servidor responde; después, la del
  /// servidor (que no usa el viento y cuenta la corroboración con todos los reportes).
  int prioridad;

  /// Por qué el teléfono calculó [prioridadLocal]. Si el servidor la cambió, estos motivos
  /// ya no suman [prioridad]: la pantalla debe decirlo.
  final List<String> motivosPrioridad;

  /// La prioridad que calculó el teléfono al crear el reporte (la que suman
  /// [motivosPrioridad]). Null en reportes guardados antes de existir este campo.
  final int? prioridadLocal;

  /// ¿El servidor recalculó la prioridad y quedó distinta de la del teléfono?
  bool get prioridadAjustada => prioridadLocal != null && envio == Envio.enviado && prioridadLocal != prioridad;

  /// Solidez del reporte (0-100), calculada en el teléfono para guiar al ciudadano.
  /// El servidor la acota (máx. 80 desde el teléfono) y le suma corroboración e IA;
  /// al sincronizar, la app muestra la del servidor.
  int confianza;
  final bool anonimo;
  final String? reportanteId;

  /// Foto guardada en el teléfono (ruta o clave). No se sube al repo ni se publica.
  /// Cuando el reporte llega, la foto completa se cambia por una miniatura ([fotoReducida]);
  /// si no se pudo reducir, se borra y queda en null.
  String? fotoRef;

  /// La foto local ya es solo una miniatura (la completa está en la CRA).
  bool fotoReducida;

  /// SHA-256 de la foto: el servidor detecta fotos repetidas o recicladas.
  final String? fotoHash;

  /// Tomada con la cámara en el momento (pesa más que una de la galería).
  final bool fotoDeCamara;
  String? fotoUrl;

  EstadoReporte estado;
  final List<CambioEstado> historial;
  Envio envio;

  /// Intentos que el servidor respondió con error (los fallos de red no cuentan).
  int intentos;

  /// Último fallo, en texto técnico corto (para soporte). Para la persona: [motivoRechazo].
  String? ultimoError;

  /// Por qué el servidor rechazó el reporte, en palabras para la persona. Solo con
  /// [Envio.rechazado].
  String? motivoRechazo;
  DateTime? enviadoEn;

  /// Id con que el reporte sale en el mapa público y en los datos abiertos. Lo da el
  /// servidor al recibirlo; sirve para no mostrar dos veces los reportes propios. No es
  /// el [id] (ese nunca se publica: con él se consulta el estado).
  String? idPublico;

  /// Cuándo cambió por última vez en este teléfono (envío, estado, foto, reintento a mano).
  /// Con dos pestañas abiertas, gana la copia que cambió después.
  DateTime? cambiadoEn;

  /// Se capturó sin señal: el panel lo muestra como «sincronizado tarde» con su hora real.
  final bool capturadoSinSenal;

  /// Por dónde llegó: 'app' (Android) o 'web' (navegador, p. ej. el QR de un letrero).
  /// El backend acepta app, web y whatsapp.
  final String canal;

  /// ¿Cuál de dos copias del mismo reporte va más adelante? (Dos pestañas del navegador
  /// guardan cada una su copia.) Positivo si [a] va más adelante que [b].
  ///
  /// Lo enviado nunca vuelve atrás (el servidor ya lo tiene). Entre dos que no se han
  /// enviado, o dos enviados, gana la que cambió después: así un «reintentar» a mano sobre
  /// un rechazado no lo pisa la copia vieja del disco.
  static int compararAvance(Reporte a, Reporte b) {
    final ea = a.envio == Envio.enviado, eb = b.envio == Envio.enviado;
    if (ea != eb) return ea ? 1 : -1;
    DateTime marca(Reporte r) => r.cambiadoEn ?? r.enviadoEn ?? r.capturadoEn;
    final c = [
      marca(a).compareTo(marca(b)),
      a.historial.length - b.historial.length,
      (a.idPublico != null ? 1 : 0) - (b.idPublico != null ? 1 : 0),
      (a.fotoUrl != null ? 1 : 0) - (b.fotoUrl != null ? 1 : 0),
      a.intentos - b.intentos,
      (a.fotoReducida ? 1 : 0) - (b.fotoReducida ? 1 : 0),
    ];
    return c.firstWhere((x) => x != 0, orElse: () => 0);
  }

  /// Copia de [otro] (el mismo reporte, más avanzado) todo lo que cambia después de crearlo.
  /// Se copia en este objeto, sin reemplazarlo, porque las pantallas guardan la referencia.
  void adoptarDe(Reporte otro) {
    assert(otro.id == id);
    prioridad = otro.prioridad;
    confianza = otro.confianza;
    fotoRef = otro.fotoRef;
    fotoReducida = otro.fotoReducida;
    fotoUrl = otro.fotoUrl;
    estado = otro.estado;
    historial
      ..clear()
      ..addAll(otro.historial);
    envio = otro.envio == Envio.enviando ? Envio.enCola : otro.envio;
    intentos = otro.intentos;
    ultimoError = otro.ultimoError;
    motivoRechazo = otro.motivoRechazo;
    enviadoEn = otro.enviadoEn;
    idPublico = otro.idPublico;
    cambiadoEn = otro.cambiadoEn;
  }

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
        'prioridad_local': prioridadLocal,
        'id_publico': idPublico,
        'motivo_rechazo': motivoRechazo,
        'foto_reducida': fotoReducida,
        'cambiado_en': cambiadoEn?.toIso8601String(),
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
        prioridadLocal: j['prioridad_local'] as int?,
        idPublico: j['id_publico'] as String?,
        motivoRechazo: j['motivo_rechazo'] as String?,
        fotoReducida: j['foto_reducida'] as bool? ?? false,
        cambiadoEn: j['cambiado_en'] == null ? null : DateTime.parse(j['cambiado_en'] as String),
      );
}
