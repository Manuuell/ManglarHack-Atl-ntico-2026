import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../admin/controlador_admin.dart';
import '../admin/repositorio_admin.dart';
import '../servidor.dart';
import 'permisos.dart';

/// Un fallo de la cuenta, ya en palabras para la persona.
class ErrorCuenta implements Exception {
  const ErrorCuenta(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// La cuenta de Zanky en este teléfono: la MISMA de la web (Supabase Auth, correo y contraseña).
///
/// - Cualquiera puede entrar; entrar no da permisos por sí solo. Después se pide `mi_rol()` y el
///   servidor responde con el rol de `panel_roles` (admin, moderador_cra, vigia, investigador,
///   organizador, aliado) o con nada (cuenta de ciudadano). [gestiones] sale de ese rol.
/// - La sesión se guarda en el teléfono ([claveGuardada]) y se renueva sola: no hay que escribir
///   la clave cada vez. Cerrar sesión la borra del teléfono y avisa al servidor.
/// - Si el rol modera reportes, abre también el panel CRA ([panel]) con la misma sesión.
/// - Sin servidor configurado solo existe la demostración ([entrarDemo]): rol admin con datos
///   de ejemplo que no salen del teléfono.
class ControladorCuenta extends ChangeNotifier {
  ControladorCuenta({
    Servidor? servidor,
    this.panel,
    DateTime Function()? reloj,
  }) : servidor = servidor ?? Servidor(),
       reloj = reloj ?? DateTime.now {
    // Si el panel de administración cambia la tabla de permisos, las pantallas se rehacen.
    permisosConfigurados.addListener(_avisar);
  }

  static const claveGuardada = 'cuenta.sesion.v1';

  final Servidor servidor;
  final ControladorAdmin? panel;
  final DateTime Function() reloj;

  SesionAdmin? _sesion;
  String? _rol;
  bool _demo = false;
  bool _desechado = false;

  /// Verdadero mientras se restaura la sesión guardada al abrir la app.
  bool restaurando = false;

  bool get configurado => servidor.configurado;
  bool get conSesion => _sesion != null || _demo;
  bool get demostracion => _demo;
  String? get correo => _demo ? null : _sesion?.correo;
  String? get rol => conSesion ? _rol : null;
  SesionAdmin? get sesion => _sesion;
  List<Gestion> get gestiones => gestionesDe(rol);
  bool puede(Gestion g) => gestiones.contains(g);

  /// Token vigente para editores que piden uno (contenido). Nulo en demostración o sin sesión.
  Future<String?> token() async {
    final s = _sesion;
    if (s == null) return null;
    if (s.porVencer(reloj())) {
      try {
        await RepositorioRemoto.refrescar(servidor, s, reloj());
      } on ErrorPanel catch (e) {
        if (e.sinSesion) await salir();
        return null;
      }
    }
    return _sesion?.token;
  }

  // ---------------------------------------------------------------- entrar y salir

  /// Entra con correo y contraseña. Lanza [ErrorCuenta] con el motivo en palabras claras.
  Future<void> entrar(String correoIngresado, String clave) async {
    final c = correoIngresado.trim();
    if (!configurado) {
      throw const ErrorCuenta(
        'Este teléfono no está conectado al servidor. Usa la demostración.',
      );
    }
    if (!c.contains('@') || clave.isEmpty) {
      throw const ErrorCuenta('Escribe tu correo y tu contraseña.');
    }
    final j = await _auth('token?grant_type=password', {
      'email': c,
      'password': clave,
    });
    final s = _sesionDe(j, c);
    final r = await _rolDe(s);
    _poner(s, r);
  }

  /// Crea la cuenta con los mismos datos que la web (`web/src/lib/cuenta.ts`, `registrarse`):
  /// nombre, sector, celular y permiso de WhatsApp van en `user_metadata`, con la fecha del
  /// consentimiento (Ley 1581). Si Supabase deja entrar de una, queda la sesión puesta
  /// ([ResultadoCrear.sesion]); si antes hay que confirmar el correo, [ResultadoCrear.confirmar].
  Future<ResultadoCrear> crearCuenta({
    required String nombre,
    required String correo,
    required String clave,
    String? sector,
    String? telefono,
    bool whatsappOk = false,
  }) async {
    final c = correo.trim();
    final n = nombre.trim();
    if (!configurado) {
      throw const ErrorCuenta('Este teléfono no está conectado al servidor.');
    }
    if (n.length < 2) throw const ErrorCuenta('Escribe tu nombre.');
    if (!correoValido(c)) throw const ErrorCuenta('Escribe un correo válido.');
    if (clave.length < 8) throw const ErrorCuenta('Usa al menos 8 caracteres.');
    final ahora = reloj().toUtc().toIso8601String();
    final whatsapp = telefono != null && telefono.isNotEmpty && whatsappOk;
    final j = await _auth('signup', {
      'email': c,
      'password': clave,
      'data': {
        'nombre': n,
        'sector': sector,
        'consentimiento_ley_1581': ahora,
        'telefono': telefono,
        'whatsapp_ok': whatsapp,
        'whatsapp_consentimiento_en': whatsapp ? ahora : null,
      },
    });
    if (j['access_token'] is! String) return ResultadoCrear.confirmar;
    final s = _sesionDe(j, c);
    final r = await _rolDe(s);
    _poner(s, r);
    return ResultadoCrear.sesion;
  }

  /// Manda el correo para elegir una contraseña nueva. No dice si la cuenta existe.
  Future<void> recuperarClave(String correoIngresado) async {
    final c = correoIngresado.trim();
    if (!c.contains('@')) {
      throw const ErrorCuenta('Escribe el correo de tu cuenta.');
    }
    if (!configurado) {
      throw const ErrorCuenta('Este teléfono no está conectado al servidor.');
    }
    await _auth('recover', {'email': c});
  }

  /// Cierra la sesión en el teléfono (siempre) y en el servidor (si hay señal).
  Future<void> salir() async {
    final s = _sesion;
    _sesion = null;
    _rol = null;
    _demo = false;
    panel?.salir();
    _avisar();
    await _borrar();
    if (s != null && configurado) {
      try {
        await servidor
            .pedir('POST', Uri.parse('${servidor.base}/auth/v1/logout'), {
              'apikey': servidor.anon,
              'Authorization': 'Bearer ${s.token}',
              'Content-Type': 'application/json',
            });
      } catch (_) {
        // Sin señal: el teléfono ya no la tiene; el token vence solo.
      }
    }
  }

  /// Demostración sin servidor: rol admin para ver toda la gestión con datos de ejemplo.
  void entrarDemo() {
    _demo = true;
    _sesion = null;
    _rol = 'admin';
    panel?.entrarDemo(rolDemo: 'admin');
    _avisar();
  }

  /// Al abrir la app: vuelve a la sesión guardada, la renueva si hace falta y relee el rol.
  /// Sin señal se queda con lo guardado (el rol también) y lo intenta la próxima vez.
  Future<void> restaurar() async {
    if (!configurado || conSesion) return;
    Map<String, dynamic>? j;
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getString(claveGuardada);
      if (t != null) j = jsonDecode(t) as Map<String, dynamic>;
    } catch (_) {
      j = null;
    }
    if (j == null) return;
    final s = SesionAdmin(
      token: '${j['token'] ?? ''}',
      refresco: '${j['refresco'] ?? ''}',
      vence: DateTime.fromMillisecondsSinceEpoch(
        (j['vence'] as num?)?.toInt() ?? 0,
      ),
      correo: '${j['correo'] ?? ''}',
    );
    var r = j['rol'] as String?;
    restaurando = true;
    _avisar();
    try {
      if (s.porVencer(reloj())) {
        await RepositorioRemoto.refrescar(servidor, s, reloj());
      }
      r = await _rolDe(s);
    } on ErrorPanel catch (e) {
      if (e.sinSesion || !e.deRed) {
        restaurando = false;
        await _borrar();
        _avisar();
        return;
      }
    } on ErrorCuenta catch (_) {
      // Sin señal: se queda con el rol guardado.
    } catch (_) {
      // Igual que sin señal.
    }
    restaurando = false;
    _poner(s, r);
  }

  @override
  void dispose() {
    _desechado = true;
    permisosConfigurados.removeListener(_avisar);
    super.dispose();
  }

  // ---------------------------------------------------------------- por dentro

  void _poner(SesionAdmin s, String? r) {
    _sesion = s..alRenovar = () => unawaited(_guardar());
    _rol = r;
    _demo = false;
    final p = panel;
    if (p != null && r != null && rolesQueModeran.contains(r) && !p.dentro) {
      p.entrarConSesion(s, r);
    }
    _avisar();
    unawaited(_guardar());
  }

  Future<void> _guardar() async {
    final s = _sesion;
    if (s == null) return;
    try {
      final p = await SharedPreferences.getInstance();
      // Si mientras tanto se cerró (o cambió) la sesión, no se resucita en el teléfono.
      if (!identical(_sesion, s)) return;
      await p.setString(
        claveGuardada,
        jsonEncode({
          'token': s.token,
          'refresco': s.refresco,
          'vence': s.vence.millisecondsSinceEpoch,
          'correo': s.correo,
          'rol': _rol,
        }),
      );
    } catch (_) {
      // Sin almacenamiento: la sesión dura lo que la app abierta.
    }
  }

  Future<void> _borrar() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(claveGuardada);
    } catch (_) {}
  }

  void _avisar() {
    if (!_desechado) notifyListeners();
  }

  /// `mi_rol()`: nulo si la cuenta no tiene rol (o si la función aún no está en el servidor).
  Future<String?> _rolDe(SesionAdmin s) async {
    try {
      return await RepositorioRemoto.rolDe(servidor, s);
    } on ErrorPanel catch (e) {
      if (e.deRed) {
        throw const ErrorCuenta(
          'No hay conexión con el servidor. Revisa tu internet e inténtalo de nuevo.',
        );
      }
      if (e.sinSesion) rethrow;
      return null;
    }
  }

  SesionAdmin _sesionDe(Map<String, dynamic> j, String c) {
    final t = j['access_token'];
    if (t is! String) {
      throw const ErrorCuenta(
        'El servidor no devolvió una sesión. Inténtalo de nuevo.',
      );
    }
    return SesionAdmin(
      token: t,
      refresco: (j['refresh_token'] as String?) ?? '',
      vence: reloj().add(
        Duration(seconds: ((j['expires_in'] as num?) ?? 3600).toInt()),
      ),
      correo: c,
    );
  }

  Future<Map<String, dynamic>> _auth(
    String ruta,
    Map<String, dynamic> cuerpo,
  ) async {
    final http.Response res;
    try {
      res = await servidor.pedir(
        'POST',
        Uri.parse('${servidor.base}/auth/v1/$ruta'),
        {'apikey': servidor.anon, 'Content-Type': 'application/json'},
        cuerpo: jsonEncode(cuerpo),
      );
    } catch (_) {
      throw const ErrorCuenta(
        'No hay conexión con el servidor. Revisa tu internet e inténtalo de nuevo.',
      );
    }
    Map<String, dynamic> d = const {};
    try {
      final x = jsonDecode(res.body);
      if (x is Map<String, dynamic>) d = x;
    } catch (_) {}
    final estado = res.statusCode;
    if (estado >= 300) {
      final codigo = '${d['error_code'] ?? d['code'] ?? d['error'] ?? ''}';
      final mensaje =
          '${d['msg'] ?? d['error_description'] ?? d['message'] ?? ''}';
      throw ErrorCuenta(traducirErrorAuth(estado, codigo, mensaje));
    }
    return d;
  }
}

/// Cómo terminó «Crear cuenta»: ya dentro, o falta confirmar el correo.
enum ResultadoCrear { sesion, confirmar }

/// Los sectores del manglar que ofrece la cuenta (los mismos de la web).
const sectoresCuenta = ['Mallorquín', 'Balboa', 'Manatíes', 'Totumo'];

/// El mismo filtro de correo que la web.
bool correoValido(String c) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(c.trim());

/// Celular en dígitos con indicativo (300 123 4567 → 573001234567), nulo si está vacío y
/// [celularInvalido] si no parece un número. Igual que `normalizarCelular` de la web.
String? normalizarCelular(String texto) {
  final d = texto.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return null;
  final n = d.length == 10 && d.startsWith('3') ? '57$d' : d;
  return n.length >= 10 && n.length <= 15 ? n : celularInvalido;
}

const celularInvalido = 'invalido';

/// Lo que responde Supabase Auth, en palabras de la persona (mismos textos que la web).
String traducirErrorAuth(int estado, String codigo, String mensaje) {
  final m = mensaje.toLowerCase();
  if (codigo == 'invalid_credentials' ||
      m.contains('invalid login credentials') ||
      codigo == 'invalid_grant') {
    return 'Correo o contraseña incorrectos.';
  }
  if (codigo == 'email_not_confirmed' || m.contains('email not confirmed')) {
    return 'Falta confirmar tu correo: abre el enlace que te enviamos y vuelve a entrar.';
  }
  if (codigo == 'user_already_exists' || m.contains('already registered')) {
    return 'Ya hay una cuenta con ese correo. Inicia sesión.';
  }
  if (codigo == 'weak_password' || m.contains('password should')) {
    return 'La contraseña es muy débil: usa al menos 8 caracteres, con letras y números.';
  }
  if (codigo == 'email_address_not_authorized') {
    return 'El servidor todavía no puede enviar correos a esa dirección (falta configurar su correo '
        'de salida). Inténtalo más tarde.';
  }
  if (codigo == 'signup_disabled' || m.contains('signups not allowed')) {
    return 'Por ahora no se pueden crear cuentas nuevas.';
  }
  if (codigo == 'email_address_invalid' ||
      m.contains('invalid format') ||
      m.contains('unable to validate email')) {
    return 'Revisa el correo: no parece válido.';
  }
  if (estado == 429 || codigo.startsWith('over_')) {
    return 'Demasiados intentos seguidos. Espera unos minutos e inténtalo de nuevo.';
  }
  if (estado == 400) return 'Correo o contraseña incorrectos.';
  if (estado == 401 || estado == 403) {
    return 'Tu sesión venció. Vuelve a iniciar sesión.';
  }
  return 'El servidor respondió con un error ($estado). Inténtalo de nuevo.';
}
