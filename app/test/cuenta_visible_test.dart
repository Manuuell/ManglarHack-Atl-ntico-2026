// La cuenta a la vista: tarjeta arriba de Guardián (sin sesión «Entra», con sesión correo y rol),
// Configuración como sección de Guardián y el avatar de Inicio que abre la hoja de entrar.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/cuenta/cuenta.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/guardian.dart';
import 'package:zanky/datos/roles.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/configuracion/cuenta_entrar.dart';
import 'package:zanky/vistas/configuracion/piezas_configuracion.dart';
import 'package:zanky/vistas/guardian/pantalla_guardian.dart';

import 'ayudas/fuente_lato.dart';

/// Servidor falso: la clave «buena» entra; `mi_rol` responde [rol].
Servidor _servidor({String? rol}) => Servidor(
      base: 'https://falso.supabase.co',
      anon: 'anon-de-prueba',
      cliente: MockClient((req) async {
        final p = req.url.path;
        if (p == '/auth/v1/token') {
          final cuerpo = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>;
          if (cuerpo['password'] == 'buena') {
            return http.Response(jsonEncode({'access_token': 'tok', 'refresh_token': 'r', 'expires_in': 3600}), 200);
          }
          return http.Response(jsonEncode({'error_code': 'invalid_credentials', 'msg': 'Invalid login credentials'}), 400);
        }
        if (p == '/rest/v1/rpc/mi_rol') return http.Response(jsonEncode(rol), 200);
        if (p == '/auth/v1/logout') return http.Response('', 204);
        return http.Response('[]', 200);
      }),
    );

late Manglar _manglar;

EstadoZanky _estado() => EstadoZanky()
  ..manglar = _manglar
  ..listo = true
  ..perfil = Perfil(id: '123e4567-e89b-12d3-a456-426614174000', nombre: 'Ana Pérez', creado: DateTime(2026, 11, 1));

Future<void> _montar(WidgetTester t, Widget hijo, ControladorCuenta cuenta, {Size tam = const Size(390, 844)}) async {
  t.view.physicalSize = tam;
  t.view.devicePixelRatio = 1;
  addTearDown(() {
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  // Como en la app: la cuenta va DEBAJO del navegador, así que las hojas no la heredan.
  await t.pumpWidget(Zanky(
    estado: _estado(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaZanky(),
      home: CuentaScope(cuenta: cuenta, child: Scaffold(body: hijo)),
    ),
  ));
  await _avanzar(t);
}

Future<void> _avanzar(WidgetTester t, {int veces = 6}) async {
  for (var i = 0; i < veces; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _desmontar(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 5));
}

void main() {
  setUpAll(() async {
    await cargarLato();
    _manglar = Manglar.desdeJson(
        jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync()) as Map<String, dynamic>);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('iniciales a partir del correo', () {
    expect(inicialesDeCorreo('ana.perez@cra.gov.co'), 'AP');
    expect(inicialesDeCorreo('manuel@ejemplo.co'), 'MA');
    expect(inicialesDeCorreo('x@y.co'), 'X');
    expect(inicialesDeCorreo(null), 'Z');
  });

  for (final tam in const [Size(360, 740), Size(390, 844), Size(1280, 800)]) {
    final tn = '${tam.width.toInt()}x${tam.height.toInt()}';

    testWidgets('Guardián sin sesión muestra «Entra» y la hoja entra; error claro y luego éxito · $tn', (t) async {
      final c = ControladorCuenta(servidor: _servidor(rol: 'organizador'));
      await _montar(t, const PantallaGuardian(), c, tam: tam);
      expect(find.text('Entra con tu cuenta de Zanky'), findsOneWidget);
      expect(find.byKey(const ValueKey('cuenta_entrar')), findsOneWidget);
      // Configuración ya vive aquí, debajo de la cuenta.
      expect(find.text('CUENTA'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('cuenta_entrar')));
      await _avanzar(t);
      final campos = find.byType(TextField);
      expect(campos, findsNWidgets(2));
      await t.enterText(campos.at(0), 'org@ejemplo.co');
      await t.enterText(campos.at(1), 'mala');
      await t.pump();
      await t.tap(find.text('Entrar'));
      await _avanzar(t, veces: 10);
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
      expect(c.conSesion, isFalse);

      await t.enterText(find.byType(TextField).at(1), 'buena');
      await t.pump();
      await t.tap(find.text('Entrar'));
      await _avanzar(t, veces: 12);
      expect(c.conSesion, isTrue);
      expect(find.byType(TextField), findsNothing, reason: 'la hoja se cierra sola');
      expect(find.text('org@ejemplo.co'), findsWidgets);
      expect(t.takeException(), isNull);
      await _desmontar(t);
    });

    testWidgets('Guardián con sesión muestra correo, sello del rol, panel y cerrar sesión · $tn', (t) async {
      final c = ControladorCuenta(servidor: _servidor(rol: 'organizador'));
      await c.entrar('org@ejemplo.co', 'buena');
      await _montar(t, const PantallaGuardian(), c, tam: tam);
      expect(find.text('org@ejemplo.co'), findsOneWidget);
      expect(find.text(RolPanel.etiqueta('organizador')), findsOneWidget);
      expect(find.byKey(const ValueKey('cuenta_abrir_panel')), findsOneWidget);
      expect(find.text('Entra con tu cuenta de Zanky'), findsNothing);

      await t.tap(find.byKey(const ValueKey('cuenta_cerrar_sesion')));
      await _avanzar(t);
      await t.tap(find.text('Cerrar sesión').last);
      await _avanzar(t, veces: 10);
      expect(c.conSesion, isFalse);
      expect(find.text('Entra con tu cuenta de Zanky'), findsOneWidget);
      expect(t.takeException(), isNull);
      await _desmontar(t);
    });
  }

  testWidgets('Ciudadano sin rol: sello «Ciudadano» y sin «Abrir panel»', (t) async {
    final c = ControladorCuenta(servidor: _servidor());
    await c.entrar('ana.perez@ejemplo.co', 'buena');
    await _montar(t, const PantallaGuardian(), c);
    expect(find.text('Ciudadano'), findsOneWidget);
    expect(find.byKey(const ValueKey('cuenta_abrir_panel')), findsNothing);
    await _desmontar(t);
  });

  testWidgets('El avatar de Inicio sin sesión abre la hoja de entrar', (t) async {
    final c = ControladorCuenta(servidor: _servidor());
    await _montar(t, const Align(alignment: Alignment.topRight, child: AvatarCuenta()), c);
    await t.tap(find.byKey(const ValueKey('avatar_cuenta')));
    await _avanzar(t);
    expect(find.text('Entra con tu cuenta de Zanky'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    await _desmontar(t);
  });

  testWidgets('El avatar con rol muestra iniciales y el punto dorado; abre la cuenta', (t) async {
    final c = ControladorCuenta(servidor: _servidor(rol: 'admin'));
    await c.entrar('ana.perez@ejemplo.co', 'buena');
    await _montar(t, const Align(alignment: Alignment.topRight, child: AvatarCuenta()), c);
    expect(find.text('AP'), findsOneWidget);
    expect(find.byKey(const ValueKey('punto_rol')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('avatar_cuenta')));
    await _avanzar(t);
    expect(find.text('ana.perez@ejemplo.co'), findsOneWidget);
    expect(find.text('Administración'), findsOneWidget);
    await _desmontar(t);
  });
}
