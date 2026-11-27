import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../servidor.dart';
import '../tipos.dart';
import 'reporte_admin.dart';

/// Una sesión de Supabase Auth del equipo (correo y contraseña). Vive solo en memoria:
/// al cerrar la app hay que entrar de nuevo, para no dejar un token de moderador en un
/// teléfono o navegador prestado.
class SesionAdmin {
  SesionAdmin({required this.token, required this.refresco, required this.vence, required this.correo});
  String token;
  String refresco;
  DateTime vence;
  final String correo;

  bool porVencer(DateTime ahora) => ahora.isAfter(vence.subtract(const Duration(seconds: 90)));
}

/// Un fallo del panel, ya en palabras para la persona.
class ErrorPanel implements Exception {
  const ErrorPanel(this.mensaje, {this.deRed = false, this.sinSesion = false, this.estadoHttp});
  final String mensaje;
  final int? estadoHttp;
  final bool deRed;

  /// El token ya no vale (venció o le quitaron el rol): hay que volver a entrar.
  final bool sinSesion;
  @override
  String toString() => mensaje;

  /// Traduce lo que responde PostgREST/Auth a algo que entienda quien modera.
  static ErrorPanel deRespuesta(int estado, String cuerpo) {
    var m = '';
    try {
      final j = jsonDecode(cuerpo);
      if (j is Map) m = '${j['message'] ?? j['msg'] ?? j['error_description'] ?? j['error'] ?? ''}'.toLowerCase();
    } catch (_) {}
    if (estado == 401 || m.contains('jwt')) {
      return const ErrorPanel('La sesión venció. Vuelve a entrar.', sinSesion: true);
    }
    if (m.startsWith('sin_permiso') || m.startsWith('transicion_no_permitida') || estado == 403) {
      return const ErrorPanel('Tu rol no permite esta acción sobre este reporte.');
    }
    if (m.startsWith('descartar_requiere_nota')) return const ErrorPanel('Para rechazar hay que escribir el motivo.');
    if (m.startsWith('sin_cambio')) return const ErrorPanel('Otra persona ya lo había dejado así.');
    if (m.startsWith('reporte_no_existe')) return const ErrorPanel('El reporte ya no existe.');
    if (m.startsWith('nota_publica_demasiado_larga')) return const ErrorPanel('El mensaje pasa de 280 letras.');
    if (m.startsWith('mensaje_requerido')) return const ErrorPanel('Escribe qué datos necesitas.');
    return ErrorPanel('El servidor no aceptó el cambio (código $estado).', estadoHttp: estado);
  }
}

/// Lo que el panel necesita del servidor. Dos versiones: la real (Supabase, con la sesión
/// del equipo) y la demostración (datos locales, para ver la vista sin servidor).
abstract class RepositorioAdmin {
  bool get demostracion;

  /// Reportes recientes, con lo que ya cambió en el servidor.
  Future<List<ReporteAdmin>> listar();

  /// La foto de evidencia, o nulo si no tiene.
  Future<Uint8List?> foto(ReporteAdmin r);

  /// Deja el reporte «verificado» (pasando por «en verificación» si hace falta).
  Future<ReporteAdmin> aprobar(ReporteAdmin r);

  /// Lo descarta con un motivo; quien reportó lo lee.
  Future<ReporteAdmin> rechazar(ReporteAdmin r, String motivo);

  /// Le pide más datos a quien reportó (queda «en verificación» con el mensaje).
  Future<ReporteAdmin> pedirDatos(ReporteAdmin r, String mensaje);
}

/// Datos locales: nada sale del teléfono. Sirve para ver y probar la vista sin servidor.
class RepositorioDemo implements RepositorioAdmin {
  RepositorioDemo(DateTime Function() reloj, {List<ReporteAdmin>? semilla})
      : _reloj = reloj,
        _datos = [...(semilla ?? reportesDemo(reloj()))];

  final DateTime Function() _reloj;
  final List<ReporteAdmin> _datos;
  int _n = 100;

  @override
  bool get demostracion => true;

  @override
  Future<List<ReporteAdmin>> listar() async => List.unmodifiable(_datos);

  @override
  Future<Uint8List?> foto(ReporteAdmin r) async => null;

  ReporteAdmin _poner(ReporteAdmin r, EstadoReporte e, {String? nota}) {
    if (!r.pendiente) throw const ErrorPanel('Ese reporte ya no está pendiente.');
    final nuevo = r.conEstado(e, notaPublica: nota);
    final i = _datos.indexWhere((x) => x.id == r.id);
    if (i >= 0) _datos[i] = nuevo;
    return nuevo;
  }

  @override
  Future<ReporteAdmin> aprobar(ReporteAdmin r) async => _poner(r, EstadoReporte.verificado);

  @override
  Future<ReporteAdmin> rechazar(ReporteAdmin r, String motivo) async {
    if (motivo.trim().isEmpty) throw const ErrorPanel('Para rechazar hay que escribir el motivo.');
    return _poner(r, EstadoReporte.descartado, nota: motivo.trim());
  }

  @override
  Future<ReporteAdmin> pedirDatos(ReporteAdmin r, String mensaje) async {
    if (mensaje.trim().isEmpty) throw const ErrorPanel('Escribe qué datos necesitas.');
    return _poner(r, EstadoReporte.enVerificacion, nota: mensaje.trim());
  }

  /// Hace llegar un reporte nuevo, como si lo hubiera mandado alguien (solo demostración).
  ReporteAdmin simularLlegada() {
    _n++;
    const tipos = TipoAmenaza.values;
    final t = tipos[_n % tipos.length];
    final r = ReporteAdmin(
      id: 'demo-$_n',
      tipo: t,
      punto: LatLng(11.0531 - (_n % 7) * 0.001, -74.8509 + (_n % 5) * 0.001),
      zona: 'Ciénaga de Mallorquín',
      municipio: 'Barranquilla',
      prioridad: t.gravedad,
      confianza: 55 + _n % 30,
      estado: EstadoReporte.recibido,
      capturadoEn: _reloj(),
      recibidoEn: _reloj(),
      descripcion: 'Reporte de demostración recién llegado.',
      distanciaM: 0,
      dentroPoligono: true,
    );
    _datos.add(r);
    return r;
  }
}

/// El servidor real: Supabase con la sesión del equipo. Todo lo protege el servidor
/// (RLS y comprobación de rol dentro de cada función); la app solo lo pide.
class RepositorioRemoto implements RepositorioAdmin {
  RepositorioRemoto(this.servidor, this.sesion);
  final Servidor servidor;
  final SesionAdmin sesion;

  static const _columnas = 'id,tipo,descripcion,lat,lon,zona,municipio,prioridad,confianza,distancia_m,'
      'dentro_poligono,estado,capturado_en,recibido_en,foto_url,nota_publica,magnitud,momento,'
      'corroboraciones,ia_motivo,expediente';

  @override
  bool get demostracion => false;

  Map<String, String> get _cab => {
        'apikey': servidor.anon,
        'Authorization': 'Bearer ${sesion.token}',
        'Content-Type': 'application/json',
      };

  Future<dynamic> _rpc(String nombre, Map<String, dynamic> cuerpo) async {
    final res = await _llamar('POST', '${servidor.base}/rest/v1/rpc/$nombre', cuerpo: jsonEncode(cuerpo));
    if (res.statusCode >= 300) throw ErrorPanel.deRespuesta(res.statusCode, res.body);
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  Future<http.Response> _llamar(String metodo, String url, {String? cuerpo}) async {
    try {
      return await servidor.pedir(metodo, Uri.parse(url), _cab, cuerpo: cuerpo);
    } catch (e) {
      if (esErrorDeRed(e)) throw const ErrorPanel('Sin conexión con el servidor.', deRed: true);
      rethrow;
    }
  }

  @override
  Future<List<ReporteAdmin>> listar() async {
    final res = await _llamar(
      'GET',
      '${servidor.base}/rest/v1/reportes?select=$_columnas&order=capturado_en.desc&limit=400',
    );
    if (res.statusCode >= 300) throw ErrorPanel.deRespuesta(res.statusCode, res.body);
    return [for (final j in jsonDecode(res.body) as List) ReporteAdmin.fromJson(j as Map<String, dynamic>)];
  }

  /// Foto privada en dos pasos que el servidor deja auditados: `url_foto` (rol + rastro) y la
  /// URL firmada de Storage (60 s).
  @override
  Future<Uint8List?> foto(ReporteAdmin r) async {
    if (!r.tieneFoto) return null;
    final ruta = await _rpc('url_foto', {'p_id': r.id});
    final objeto = (ruta is Map ? ruta['objeto'] : null) as String?;
    if (objeto == null) return null;
    final firmar = await _llamar(
      'POST',
      '${servidor.base}/storage/v1/object/sign/evidencias/$objeto',
      cuerpo: jsonEncode({'expiresIn': 60}),
    );
    if (firmar.statusCode >= 300) throw ErrorPanel.deRespuesta(firmar.statusCode, firmar.body);
    final firmada = (jsonDecode(firmar.body) as Map)['signedURL'] as String?;
    if (firmada == null) return null;
    // «signedURL» viene relativa a /storage/v1.
    final destino = firmada.startsWith('http')
        ? firmada
        : '${servidor.base}/storage/v1${firmada.startsWith('/') ? '' : '/'}$firmada';
    final img = await _llamar('GET', destino);
    if (img.statusCode >= 300) throw ErrorPanel.deRespuesta(img.statusCode, img.body);
    return img.bodyBytes;
  }

  /// ¿La función aún no está cargada en el servidor? (PostgREST: 404 / PGRST202).
  static bool _noExiste(ErrorPanel e) => e.estadoHttp == 404;

  ReporteAdmin _con(ReporteAdmin r, EstadoReporte e, {String? nota}) => r.conEstado(e, notaPublica: nota);

  @override
  Future<ReporteAdmin> aprobar(ReporteAdmin r) async {
    try {
      await _rpc('panel_aprobar', {'p_id': r.id});
    } on ErrorPanel catch (e) {
      if (!_noExiste(e)) rethrow;
      // Sin admin_app.sql: el esquema base avanza de un estado a la vez.
      if (r.estado == EstadoReporte.recibido) await _cambiar(r.id, 'en_verificacion');
      await _cambiar(r.id, 'verificado');
    }
    return _con(r, EstadoReporte.verificado);
  }

  Future<void> _cambiar(String id, String estado, {String? nota, String? notaPublica}) =>
      _rpc('cambiar_estado', {'p_id': id, 'p_estado': estado, 'p_nota': nota, 'p_nota_publica': notaPublica});

  @override
  Future<ReporteAdmin> rechazar(ReporteAdmin r, String motivo) async {
    final m = motivo.trim();
    if (m.isEmpty) throw const ErrorPanel('Para rechazar hay que escribir el motivo.');
    await _cambiar(r.id, 'descartado', nota: m, notaPublica: m.length > 280 ? m.substring(0, 280) : m);
    return _con(r, EstadoReporte.descartado, nota: m);
  }

  @override
  Future<ReporteAdmin> pedirDatos(ReporteAdmin r, String mensaje) async {
    final m = mensaje.trim();
    if (m.isEmpty) throw const ErrorPanel('Escribe qué datos necesitas.');
    try {
      await _rpc('panel_pedir_datos', {'p_id': r.id, 'p_mensaje': m});
    } on ErrorPanel catch (e) {
      if (!_noExiste(e)) rethrow;
      // Sin admin_app.sql solo se puede si aún está «recibido» (el esquema no repite estados).
      if (r.estado != EstadoReporte.recibido) {
        throw const ErrorPanel('Falta cargar admin_app.sql en el servidor para pedir datos de un reporte ya en verificación.');
      }
      await _cambiar(r.id, 'en_verificacion', nota: 'Se pidieron más datos: $m', notaPublica: m);
    }
    return _con(r, EstadoReporte.enVerificacion, nota: m);
  }

  // ---------------------------------------------------------------- acceso

  /// Entra con correo y contraseña (Supabase Auth) y confirma que la cuenta tiene un rol
  /// del panel. Devuelve la sesión y el rol.
  static Future<(SesionAdmin, String)> entrar(Servidor s, String correo, String clave, DateTime ahora) async {
    final res = await _auth(s, 'password', {'email': correo.trim(), 'password': clave});
    final sesion = _sesionDe(res, correo.trim(), ahora);
    final rol = await rolDe(s, sesion);
    if (rol == null) {
      throw const ErrorPanel('Esta cuenta no tiene permiso de moderación. Pídele el acceso a la persona que administra Zanky.');
    }
    return (sesion, rol);
  }

  /// Renueva el token antes de que venza.
  static Future<void> refrescar(Servidor s, SesionAdmin sesion, DateTime ahora) async {
    final res = await _auth(s, 'refresh_token', {'refresh_token': sesion.refresco});
    final nueva = _sesionDe(res, sesion.correo, ahora);
    sesion
      ..token = nueva.token
      ..refresco = nueva.refresco
      ..vence = nueva.vence;
  }

  /// El rol que el servidor confirma en `panel_roles` (nulo si no tiene o se lo quitaron).
  static Future<String?> rolDe(Servidor s, SesionAdmin sesion) async {
    final r = await RepositorioRemoto(s, sesion)._rpc('mi_rol', {});
    return r is String && r.isNotEmpty ? r : null;
  }

  static Future<Map<String, dynamic>> _auth(Servidor s, String tipo, Map<String, dynamic> cuerpo) async {
    try {
      final res = await s.pedir(
        'POST',
        Uri.parse('${s.base}/auth/v1/token?grant_type=$tipo'),
        {'apikey': s.anon, 'Content-Type': 'application/json'},
        cuerpo: jsonEncode(cuerpo),
      );
      if (res.statusCode == 400 || res.statusCode == 401) {
        throw ErrorPanel(tipo == 'password' ? 'Correo o contraseña incorrectos.' : 'La sesión venció. Vuelve a entrar.',
            sinSesion: tipo != 'password');
      }
      if (res.statusCode >= 300) throw ErrorPanel.deRespuesta(res.statusCode, res.body);
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on ErrorPanel {
      rethrow;
    } catch (e) {
      if (esErrorDeRed(e)) throw const ErrorPanel('Sin conexión con el servidor.', deRed: true);
      rethrow;
    }
  }

  static SesionAdmin _sesionDe(Map<String, dynamic> j, String correo, DateTime ahora) {
    final token = j['access_token'] as String?;
    if (token == null) throw const ErrorPanel('El servidor no devolvió una sesión.');
    return SesionAdmin(
      token: token,
      refresco: (j['refresh_token'] as String?) ?? '',
      vence: ahora.add(Duration(seconds: ((j['expires_in'] as num?) ?? 3600).toInt())),
      correo: correo,
    );
  }
}
