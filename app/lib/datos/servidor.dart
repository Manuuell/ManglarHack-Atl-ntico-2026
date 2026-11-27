import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'metadatos_foto.dart';
import 'reporte.dart';
import 'tipos.dart';

/// Conexión con el backend común (Supabase: Postgres + PostGIS + Storage).
///
/// Se configura al compilar, nunca en el código:
///   flutter run --dart-define=ZANKY_API=https://xxxx.supabase.co --dart-define=ZANKY_ANON=CLAVE_ANON
/// La clave «anon» es pública por diseño; lo que protege los datos son las reglas
/// del servidor (ver backend/supabase/schema.sql). La service_role NUNCA va en la app.
///
/// Sin configuración, la app funciona igual y guarda todo en el teléfono, y lo dice.
class Servidor {
  Servidor({String? base, String? anon, http.Client? cliente})
      : base = base ?? const String.fromEnvironment('ZANKY_API'),
        anon = anon ?? const String.fromEnvironment('ZANKY_ANON'),
        _http = cliente ?? http.Client();

  final String base;
  final String anon;
  final http.Client _http;

  bool get configurado => base.isNotEmpty && anon.isNotEmpty;

  Map<String, String> get _cabeceras => {
        'apikey': anon,
        'Authorization': 'Bearer $anon',
        'Content-Type': 'application/json',
      };

  /// Plazo de una petición sin foto (reporte, estados, mapa).
  static const plazo = Duration(seconds: 20);

  /// Plazo para subir una foto: 20 s más 1 s por cada 12 KB (una subida lenta de 2G/EDGE),
  /// hasta 5 min. Una foto de 400 KB tiene ~54 s; con un plazo fijo de 20 s, con mala
  /// señal la foto nunca alcanzaba a subir y se reintentaba entera una y otra vez.
  static Duration plazoParaFoto(int bytes) =>
      Duration(seconds: math.min(300, 20 + (bytes / 12000).ceil()));

  /// Sube la foto y el reporte, y devuelve el id público que le dio el servidor.
  /// Idempotente de punta a punta:
  /// - la foto va a `evidencias/ID.jpg`; si ya estaba, el reintento la da por subida;
  /// - el reporte entra por la función `crear_reporte`, que no duplica el id del teléfono
  ///   (`nuevo: false` si ya había llegado).
  /// Así, si el servidor guardó y la respuesta se perdió, reintentar no duplica nada.
  ///
  /// Solo da el envío por hecho con la respuesta exacta: HTTP 200 y un JSON con el mismo
  /// id. Cualquier otra cosa lanza [ErrorServidor] (ver [ErrorServidor.permanente]); un
  /// fallo de red lanza la excepción de red tal cual (ver [esErrorDeRed]).
  Future<String?> enviar(Reporte r, Uint8List? foto) async {
    if (!configurado) throw const SinServidor();
    if (foto != null && r.fotoUrl == null) {
      // Las fotos de versiones viejas de la app se guardaron con EXIF: nunca salen con él.
      final limpia = quitarMetadatos(foto);
      final ruta = 'evidencias/${r.id}.jpg';
      final res = await pedir(
        'POST',
        Uri.parse('$base/storage/v1/object/$ruta'),
        // Sin upsert: reemplazar exigiría dejar que el anónimo lea fotos ajenas.
        {..._cabeceras, 'Content-Type': 'image/jpeg'},
        cuerpo: limpia,
        plazo: plazoParaFoto(limpia.length),
      );
      // Si la foto ya estaba (un envío anterior subió la foto y se cortó antes del
      // reporte), Storage responde «ya existe» (400/409, o 403 porque el anónimo no
      // puede leer para reemplazar): es la misma foto del mismo id, así que cuenta
      // como subida.
      final yaExiste = (res.statusCode == 400 || res.statusCode == 403 || res.statusCode == 409) &&
          res.body.toLowerCase().contains(RegExp(r'exist|duplicate|already'));
      if (res.statusCode >= 300 && !yaExiste) {
        throw ErrorServidor('foto ${res.statusCode}', res.body, estadoHttp: res.statusCode, deLaFoto: true);
      }
      // Ruta interna: la foto NO es pública; el panel la pide con permiso de moderador.
      r.fotoUrl = ruta;
    }
    final res = await pedir(
      'POST',
      Uri.parse('$base/rest/v1/rpc/crear_reporte'),
      _cabeceras,
      cuerpo: jsonEncode({'p': r.aServidor()}),
    );
    if (res.statusCode >= 300) {
      throw ErrorServidor('reporte ${res.statusCode}', res.body, estadoHttp: res.statusCode);
    }
    // Regla 60 de la vara: una respuesta que no es la esperada no es un éxito.
    Object? j;
    try {
      j = jsonDecode(res.body);
    } catch (_) {
      j = null;
    }
    if (j is! Map || j['id'] != r.id) {
      throw ErrorServidor('reporte ${res.statusCode}: respuesta inesperada', res.body, estadoHttp: res.statusCode);
    }
    return j['id_publico'] as String?;
  }

  /// Estado actual de MIS reportes (máx. 100 ids por llamada). La función del servidor
  /// solo responde por los ids que se le dan, y esos ids no se publican en ninguna parte
  /// (la vista pública da otro id, [ReportePublico.id]): nadie puede listar reportes ajenos.
  Future<List<EstadoRemoto>> estados(List<String> ids) async {
    if (!configurado || ids.isEmpty) return const [];
    final res = await pedir(
      'POST',
      Uri.parse('$base/rest/v1/rpc/estado_de_reportes'),
      _cabeceras,
      cuerpo: jsonEncode({'ids': ids}),
    );
    if (res.statusCode >= 300) throw ErrorServidor('estados ${res.statusCode}', res.body, estadoHttp: res.statusCode);
    return [for (final j in jsonDecode(res.body) as List) EstadoRemoto.fromJson(j as Map<String, dynamic>)];
  }

  /// Reportes públicos recientes para el mapa: sin nombre, sin foto, con la coordenada
  /// redondeada (~100 m) y la hora en punto, para proteger a quien denuncia.
  Future<List<ReportePublico>> publicos({int limite = 300}) async {
    if (!configurado) return const [];
    final res = await pedir(
      'GET',
      Uri.parse('$base/rest/v1/reportes_publicos?select=*&order=capturado_en.desc&limit=$limite'),
      _cabeceras,
    );
    if (res.statusCode >= 300) throw ErrorServidor('públicos ${res.statusCode}', res.body, estadoHttp: res.statusCode);
    return [for (final j in jsonDecode(res.body) as List) ReportePublico.fromJson(j as Map<String, dynamic>)];
  }

  /// Una petición con plazo que, al vencerse, CANCELA de verdad la conexión (no solo deja
  /// de esperarla): con mala señal, una subida abandonada que sigue viva gasta datos y
  /// compite con el reintento. Al vencerse lanza [TimeoutException].
  Future<http.Response> pedir(
    String metodo,
    Uri uri,
    Map<String, String> cabeceras, {
    Object? cuerpo,
    Duration plazo = Servidor.plazo,
  }) async {
    final corte = Completer<void>();
    final reloj = Timer(plazo, () {
      if (!corte.isCompleted) corte.complete();
    });
    final req = http.AbortableRequest(metodo, uri, abortTrigger: corte.future)..headers.addAll(cabeceras);
    if (cuerpo is Uint8List) {
      req.bodyBytes = cuerpo;
    } else if (cuerpo is String) {
      req.body = cuerpo;
    }
    try {
      // Respaldo por si el cliente no sabe cancelar: igual se deja de esperar (y se avisa al
      // disparador, por si el cliente lo atiende tarde).
      final enviada = await _http.send(req).timeout(plazo + const Duration(seconds: 2));
      return await http.Response.fromStream(enviada).timeout(plazo + const Duration(seconds: 2));
    } on http.RequestAbortedException {
      throw TimeoutException('Sin respuesta del servidor en ${plazo.inSeconds} s', plazo);
    } on TimeoutException {
      if (!corte.isCompleted) corte.complete();
      rethrow;
    } finally {
      reloj.cancel();
    }
  }
}

/// ¿El fallo es de la red (sin señal, señal que no pasa datos, plazo vencido) y no una
/// respuesta del servidor? Un fallo de red no es culpa del reporte: no suma intentos.
bool esErrorDeRed(Object e) =>
    e is http.ClientException ||
    e is TimeoutException ||
    // dart:io no existe en la web; por nombre, para no importarlo aquí.
    e.runtimeType.toString() == 'SocketException' ||
    e.runtimeType.toString() == 'HandshakeException';

class SinServidor implements Exception {
  const SinServidor();
  @override
  String toString() => 'Sin servidor configurado';
}

/// El servidor respondió, pero no con lo esperado.
class ErrorServidor implements Exception {
  ErrorServidor(this.que, this.cuerpo, {this.estadoHttp, this.deLaFoto = false});
  final String que;
  final String cuerpo;
  final int? estadoHttp;
  final bool deLaFoto;

  /// ¿Es un rechazo de ESTE reporte que no se arregla reintentando? Solo los 4xx de
  /// validación: 400 (dato inválido, p. ej. punto fuera del Atlántico), 413 (foto muy
  /// pesada), 415 y 422. No lo son 401/403/404 (clave o esquema mal configurados: se
  /// arreglan en el servidor y el reporte debe salir después), 408, 409 ni 429.
  bool get permanente => estadoHttp != null && const {400, 413, 415, 422}.contains(estadoHttp);

  /// El «mensaje» del JSON de error de PostgREST o de Storage, si lo hay.
  String? get mensajeDelServidor {
    try {
      final j = jsonDecode(cuerpo);
      if (j is Map) {
        final m = j['message'] ?? j['error'] ?? j['msg'];
        if (m is String && m.trim().isNotEmpty) return m.trim();
      }
    } catch (_) {}
    return null;
  }

  /// Por qué no se aceptó, en palabras para la persona.
  String get motivo {
    final m = (mensajeDelServidor ?? '').toLowerCase();
    if (estadoHttp == 413 || m.contains('maximum allowed size') || m.contains('too large')) {
      return 'La foto pesa demasiado para el servidor (máximo 5 MB).';
    }
    if (deLaFoto) return 'El servidor no aceptó la foto (código $estadoHttp).';
    const motivos = {
      'punto_fuera_del_atlantico':
          'El punto quedó fuera del Atlántico. Zanky solo recibe reportes del departamento: revisa la ubicación.',
      'ubicacion_invalida': 'Al reporte le falta la ubicación.',
      'tipo_invalido': 'El tipo de reporte no es válido para el servidor.',
      'hora_invalida': 'La hora del reporte no es válida.',
      'id_invalido': 'El número interno del reporte no es válido.',
      'canal_invalido': 'El servidor no reconoce desde dónde se envió.',
      'reportante_invalido': 'El código de guardián no es válido.',
      'reporte_demasiado_grande': 'El reporte es demasiado largo para el servidor.',
    };
    for (final e in motivos.entries) {
      if (m.startsWith(e.key)) return e.value;
    }
    return 'El servidor no aceptó este reporte (código $estadoHttp).';
  }

  /// Texto corto para [Reporte.ultimoError]: el código entre paréntesis (las pantallas lo
  /// leen) y el mensaje del servidor recortado, para saber por qué.
  @override
  String toString() {
    final m = mensajeDelServidor ?? cuerpo.trim();
    final corto = m.length > 160 ? '${m.substring(0, 160)}…' : m;
    return corto.isEmpty ? 'Error del servidor ($que)' : 'Error del servidor ($que): $corto';
  }
}

class EstadoRemoto {
  const EstadoRemoto({
    required this.id,
    required this.estado,
    this.prioridad,
    this.confianza,
    this.nota,
    this.actualizado,
    this.idPublico,
  });
  final String id;
  final EstadoReporte estado;
  final int? prioridad;
  final int? confianza;
  final String? nota;
  final DateTime? actualizado;
  final String? idPublico;

  static EstadoRemoto fromJson(Map<String, dynamic> j) => EstadoRemoto(
        id: j['id'] as String,
        estado: EstadoReporte.deSlug(j['estado'] as String),
        prioridad: j['prioridad'] as int?,
        confianza: j['confianza'] as int?,
        nota: j['nota_publica'] as String?,
        actualizado: j['actualizado_en'] == null ? null : DateTime.parse(j['actualizado_en'] as String).toLocal(),
        idPublico: j['id_publico'] as String?,
      );
}

class ReportePublico {
  const ReportePublico({
    required this.id,
    required this.tipo,
    required this.punto,
    required this.prioridad,
    required this.estado,
    required this.capturadoEn,
    required this.zona,
  });

  /// El id PÚBLICO del reporte (`id_publico` de la vista), no el id interno: sirve para
  /// distinguir un punto de otro, no para consultar nada. Para saber si es uno propio se
  /// compara con [Reporte.idPublico].
  final String id;
  final TipoAmenaza tipo;
  final LatLng punto;
  final int prioridad;
  final EstadoReporte estado;

  /// Redondeada por el servidor a la hora en punto.
  final DateTime capturadoEn;
  final String zona;

  static ReportePublico fromJson(Map<String, dynamic> j) => ReportePublico(
        // `id` es de la vista vieja (antes de id_publico), por si el servidor aún no se actualizó.
        id: (j['id_publico'] ?? j['id']) as String,
        tipo: TipoAmenaza.deSlug(j['tipo'] as String),
        punto: LatLng((j['lat'] as num).toDouble(), (j['lon'] as num).toDouble()),
        prioridad: j['prioridad'] as int? ?? 3,
        estado: EstadoReporte.deSlug(j['estado'] as String? ?? 'recibido'),
        capturadoEn: DateTime.parse(j['capturado_en'] as String).toLocal(),
        zona: j['zona'] as String? ?? '',
      );
}
