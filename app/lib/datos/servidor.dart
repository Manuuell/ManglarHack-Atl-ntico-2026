import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'reporte.dart';
import 'tipos.dart';

/// Conexión con el backend común (Supabase: Postgres + PostGIS + Storage).
///
/// Se configura al compilar, nunca en el código:
///   flutter run --dart-define=ZANQUI_API=https://xxxx.supabase.co --dart-define=ZANQUI_ANON=CLAVE_ANON
/// La clave «anon» es pública por diseño; lo que protege los datos son las reglas
/// del servidor (ver backend/supabase/schema.sql). La service_role NUNCA va en la app.
///
/// Sin configuración, la app funciona igual y guarda todo en el teléfono, y lo dice.
class Servidor {
  Servidor({String? base, String? anon, http.Client? cliente})
      : base = base ?? const String.fromEnvironment('ZANQUI_API'),
        anon = anon ?? const String.fromEnvironment('ZANQUI_ANON'),
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

  static const _plazo = Duration(seconds: 20);

  /// Sube la foto y el reporte. Idempotente de punta a punta:
  /// - la foto va a `evidencias/ID.jpg`; si ya estaba, el reintento la da por subida;
  /// - el reporte se inserta con `ignore-duplicates` sobre el id del teléfono.
  /// Así, si el servidor guardó y la respuesta se perdió, reintentar no duplica nada.
  Future<void> enviar(Reporte r, Uint8List? foto) async {
    if (!configurado) throw const SinServidor();
    if (foto != null && r.fotoUrl == null) {
      final ruta = 'evidencias/${r.id}.jpg';
      final res = await _http
          .post(
            Uri.parse('$base/storage/v1/object/$ruta'),
            // Sin upsert: reemplazar exigiría dejar que el anónimo lea fotos ajenas.
            headers: {..._cabeceras, 'Content-Type': 'image/jpeg'},
            body: foto,
          )
          .timeout(_plazo);
      // Si la foto ya estaba (un envío anterior subió la foto y se cortó antes del
      // reporte), Storage responde «ya existe» (400/409, o 403 porque el anónimo no
      // puede leer para reemplazar): es la misma foto del mismo id, así que cuenta
      // como subida. Cualquier otro error sí se reintenta.
      final yaExiste = (res.statusCode == 400 || res.statusCode == 403 || res.statusCode == 409) &&
          res.body.toLowerCase().contains(RegExp(r'exist|duplicate|already'));
      if (res.statusCode >= 300 && !yaExiste) throw ErrorServidor('foto ${res.statusCode}', res.body);
      // Ruta interna: la foto NO es pública; el panel la pide con permiso de moderador.
      r.fotoUrl = ruta;
    }
    final res = await _http
        .post(
          Uri.parse('$base/rest/v1/reportes'),
          headers: {..._cabeceras, 'Prefer': 'resolution=ignore-duplicates,return=minimal'},
          body: jsonEncode(r.aServidor()),
        )
        .timeout(_plazo);
    if (res.statusCode >= 300) throw ErrorServidor('reporte ${res.statusCode}', res.body);
  }

  /// Estado actual de MIS reportes. La función del servidor solo responde por los
  /// ids que se le dan (UUID imposibles de adivinar): nadie puede listar reportes ajenos.
  Future<List<EstadoRemoto>> estados(List<String> ids) async {
    if (!configurado || ids.isEmpty) return const [];
    final res = await _http
        .post(
          Uri.parse('$base/rest/v1/rpc/estado_de_reportes'),
          headers: _cabeceras,
          body: jsonEncode({'ids': ids}),
        )
        .timeout(_plazo);
    if (res.statusCode >= 300) throw ErrorServidor('estados ${res.statusCode}', res.body);
    return [for (final j in jsonDecode(res.body) as List) EstadoRemoto.fromJson(j as Map<String, dynamic>)];
  }

  /// Reportes públicos recientes para el mapa: sin nombre, sin foto y con la
  /// coordenada redondeada (~100 m) para proteger a quien denuncia.
  Future<List<ReportePublico>> publicos({int limite = 300}) async {
    if (!configurado) return const [];
    final res = await _http
        .get(
          Uri.parse('$base/rest/v1/reportes_publicos?select=*&order=capturado_en.desc&limit=$limite'),
          headers: _cabeceras,
        )
        .timeout(_plazo);
    if (res.statusCode >= 300) throw ErrorServidor('públicos ${res.statusCode}', res.body);
    return [for (final j in jsonDecode(res.body) as List) ReportePublico.fromJson(j as Map<String, dynamic>)];
  }
}

class SinServidor implements Exception {
  const SinServidor();
  @override
  String toString() => 'Sin servidor configurado';
}

class ErrorServidor implements Exception {
  ErrorServidor(this.que, this.cuerpo);
  final String que;
  final String cuerpo;
  @override
  String toString() => 'Error del servidor ($que)';
}

class EstadoRemoto {
  const EstadoRemoto({
    required this.id,
    required this.estado,
    this.prioridad,
    this.confianza,
    this.nota,
    this.actualizado,
  });
  final String id;
  final EstadoReporte estado;
  final int? prioridad;
  final int? confianza;
  final String? nota;
  final DateTime? actualizado;

  static EstadoRemoto fromJson(Map<String, dynamic> j) => EstadoRemoto(
        id: j['id'] as String,
        estado: EstadoReporte.deSlug(j['estado'] as String),
        prioridad: j['prioridad'] as int?,
        confianza: j['confianza'] as int?,
        nota: j['nota_publica'] as String?,
        actualizado: j['actualizado_en'] == null ? null : DateTime.parse(j['actualizado_en'] as String).toLocal(),
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
  final String id;
  final TipoAmenaza tipo;
  final LatLng punto;
  final int prioridad;
  final EstadoReporte estado;
  final DateTime capturadoEn;
  final String zona;

  static ReportePublico fromJson(Map<String, dynamic> j) => ReportePublico(
        id: j['id'] as String,
        tipo: TipoAmenaza.deSlug(j['tipo'] as String),
        punto: LatLng((j['lat'] as num).toDouble(), (j['lon'] as num).toDouble()),
        prioridad: j['prioridad'] as int? ?? 3,
        estado: EstadoReporte.deSlug(j['estado'] as String? ?? 'recibido'),
        capturadoEn: DateTime.parse(j['capturado_en'] as String).toLocal(),
        zona: j['zona'] as String? ?? '',
      );
}
