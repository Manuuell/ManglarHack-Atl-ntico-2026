import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cuenta/permisos.dart';
import '../servidor.dart';
import 'permisos_rol.dart';

/// De dónde salió la matriz que se ve: se dice en pantalla, discreto.
enum OrigenPermisos {
  /// La tabla `permisos_rol` respondió.
  servidor,

  /// Sin señal: la última copia guardada en este teléfono.
  copia,

  /// El servidor aún no tiene `permisos_rol.sql` (o es la demostración): plantillas por defecto.
  plantillas,
}

/// La tabla no existe todavía en Supabase.
class SinTablaPermisos implements Exception {
  const SinTablaPermisos();
}

/// Un fallo ya en palabras.
class ErrorPermisos implements Exception {
  const ErrorPermisos(this.mensaje, {this.deRed = false});
  final String mensaje;
  final bool deRed;
  @override
  String toString() => mensaje;
}

/// Lo que el panel pide al servidor sobre permisos. La real va a Supabase; las pruebas usan una falsa.
abstract class FuentePermisos {
  Future<List<Map<String, dynamic>>> leer();
  Future<void> fijar(RolEquipo rol, Permiso p, bool activo);
  Future<void> asignarRol(String correo, RolEquipo rol);
}

class FuenteSupabase implements FuentePermisos {
  FuenteSupabase(this.servidor, this.token);
  final Servidor servidor;
  final Future<String?> Function() token;

  Future<Map<String, String>> _cab() async {
    final t = await token();
    if (t == null) throw const ErrorPermisos('Entra al panel con tu cuenta para cambiar permisos.');
    return {'apikey': servidor.anon, 'Authorization': 'Bearer $t', 'Content-Type': 'application/json'};
  }

  Future<dynamic> _pedir(String metodo, String ruta, {Object? cuerpo}) async {
    final cab = await _cab();
    try {
      final res = await servidor.pedir(metodo, Uri.parse('${servidor.base}$ruta'), cab,
          cuerpo: cuerpo == null ? null : jsonEncode(cuerpo));
      if (res.statusCode >= 300) {
        final b = res.body.toLowerCase();
        if (res.statusCode == 404 || b.contains('pgrst205') || b.contains('pgrst202') || b.contains('does not exist')) {
          throw const SinTablaPermisos();
        }
        if (b.contains('persona_no_existe')) throw const ErrorPermisos('Ese correo aún no tiene cuenta en Zanky.');
        if (b.contains('admin_conserva_roles')) throw const ErrorPermisos('Administración conserva siempre este permiso.');
        if (b.contains('sin_permiso') || res.statusCode == 403) {
          throw const ErrorPermisos('Tu rol no permite cambiar permisos.');
        }
        throw ErrorPermisos('El servidor no aceptó el cambio (código ${res.statusCode}).');
      }
      return res.body.isEmpty ? null : jsonDecode(res.body);
    } on SinTablaPermisos {
      rethrow;
    } on ErrorPermisos {
      rethrow;
    } catch (e) {
      if (esErrorDeRed(e)) throw const ErrorPermisos('Sin conexión con el servidor.', deRed: true);
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> leer() async {
    final d = await _pedir('GET', '/rest/v1/permisos_rol?select=rol,permiso,activo');
    if (d is! List) throw const ErrorPermisos('Respuesta inesperada del servidor.');
    return [for (final f in d) Map<String, dynamic>.from(f as Map)];
  }

  @override
  Future<void> fijar(RolEquipo rol, Permiso p, bool activo) =>
      _pedir('POST', '/rest/v1/rpc/fijar_permiso', cuerpo: {'p_rol': rol.id, 'p_permiso': p.id, 'p_activo': activo});

  @override
  Future<void> asignarRol(String correo, RolEquipo rol) =>
      _pedir('POST', '/rest/v1/rpc/asignar_rol_por_correo', cuerpo: {'p_correo': correo, 'p_rol': rol.id});
}

/// La matriz con caché y respaldo: servidor → copia del teléfono → plantillas por defecto.
/// Los cambios se ven al instante y, si el servidor no los acepta, vuelven atrás solos.
class ControladorPermisos extends ChangeNotifier {
  ControladorPermisos({this.fuente, this.rolActual, Future<SharedPreferences> Function()? preferencias})
      : _prefs = preferencias ?? SharedPreferences.getInstance;

  /// Nula en la demostración: todo se queda en memoria.
  final FuentePermisos? fuente;
  final Future<SharedPreferences> Function() _prefs;

  /// El rol de quien tiene la sesión (de `panel_roles`).
  RolEquipo? rolActual;

  static const _clave = 'permisos_rol_copia_v1';

  MatrizPermisos matriz = MatrizPermisos.porDefecto();
  OrigenPermisos origen = OrigenPermisos.plantillas;
  bool cargando = false;
  String? fallo;
  bool _desechado = false;

  bool puede(Permiso p) => matriz.puede(rolActual, p);

  /// Solo se edita contra el servidor real con la tabla cargada (o en la demostración).
  /// En la demostración (sin [fuente]) se puede jugar con la matriz: los cambios viven en memoria
  /// y se ven al instante en la bandeja (por ejemplo, quitar «Aprobar y rechazar» apaga los gestos).
  bool get editable => fuente == null || (puede(Permiso.administrarRoles) && origen == OrigenPermisos.servidor);

  Future<void> cargar() async {
    final f = fuente;
    if (f == null) return;
    cargando = true;
    _avisar();
    try {
      final filas = await f.leer();
      matriz = filas.isEmpty ? MatrizPermisos.porDefecto() : MatrizPermisos.deFilas(filas);
      origen = OrigenPermisos.servidor;
      unawaited(_guardarCopia(filas));
    } on SinTablaPermisos {
      matriz = MatrizPermisos.porDefecto();
      origen = OrigenPermisos.plantillas;
    } catch (_) {
      final copia = await _leerCopia();
      matriz = copia ?? MatrizPermisos.porDefecto();
      origen = copia == null ? OrigenPermisos.plantillas : OrigenPermisos.copia;
    } finally {
      cargando = false;
      _avisar();
    }
  }

  /// Prende o apaga un permiso. Devuelve el texto del fallo, o nulo si quedó.
  Future<String?> fijar(RolEquipo rol, Permiso p, bool activo) => _aplicar(matriz.con(rol, p, activo));

  Future<String?> aplicarPlantilla(RolEquipo rol, PlantillaRol t) => _aplicar(matriz.conPlantilla(rol, t));

  /// Vuelve a [anterior] (lo usa «Deshacer»).
  Future<String?> restaurar(MatrizPermisos anterior) => _aplicar(anterior);

  Future<String?> _aplicar(MatrizPermisos nueva) async {
    final antes = matriz;
    final cambios = antes.diferencias(nueva);
    if (cambios.isEmpty) return null;
    matriz = nueva;
    fallo = null;
    _avisar();
    final f = fuente;
    if (f == null) return null;
    try {
      for (final (r, p, a) in cambios) {
        await f.fijar(r, p, a);
      }
      unawaited(_guardarCopia(matriz.aFilas()));
      return null;
    } catch (e) {
      matriz = antes;
      fallo = e is SinTablaPermisos ? 'Falta cargar permisos_rol.sql en el servidor.' : '$e';
      _avisar();
      return fallo;
    }
  }

  Future<String?> asignarRol(String correo, RolEquipo rol) async {
    final c = correo.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(c)) return 'Escribe un correo válido.';
    final f = fuente;
    if (f == null) return null;
    try {
      await f.asignarRol(c, rol);
      return null;
    } on SinTablaPermisos {
      return 'Falta cargar permisos_rol.sql en el servidor.';
    } catch (e) {
      return '$e';
    }
  }

  Future<void> _guardarCopia(List<Map<String, dynamic>> filas) async {
    try {
      (await _prefs()).setString(_clave, jsonEncode(filas));
    } catch (_) {}
  }

  Future<MatrizPermisos?> _leerCopia() async {
    try {
      final t = (await _prefs()).getString(_clave);
      if (t == null) return null;
      return MatrizPermisos.deFilas([for (final f in jsonDecode(t) as List) Map<String, dynamic>.from(f as Map)]);
    } catch (_) {
      return null;
    }
  }

  void _avisar() {
    if (_desechado) return;
    // Solo lo que de verdad viene del servidor (o su copia) reemplaza la tabla de fábrica de la cuenta.
    if (publicarEnCuenta) {
      permisosConfigurados.value = origen == OrigenPermisos.plantillas ? null : gestionesDeMatriz(matriz);
    }
    notifyListeners();
  }

  /// Escribe la matriz en `permisosConfigurados` (lo que ve Configuración › Gestión).
  /// Apagado en la demostración para no cambiar la app real con datos de ejemplo.
  bool get publicarEnCuenta => fuente != null;

  @override
  void dispose() {
    _desechado = true;
    super.dispose();
  }
}
