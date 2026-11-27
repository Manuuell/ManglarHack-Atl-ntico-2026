// La cuenta de Configuración: sin sesión no hay gestión; cada rol del servidor ve lo suyo;
// entrar mal da un error claro; la sesión se guarda, se restaura y se cierra. Servidor falso.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/admin/controlador_admin.dart';
import 'package:zanky/datos/cuenta/cuenta.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/guardian.dart';
import 'package:zanky/datos/roles.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/admin/piezas_admin.dart';
import 'package:zanky/vistas/configuracion/pantalla_configuracion.dart';
import 'package:zanky/vistas/configuracion/piezas_configuracion.dart';
import 'package:zanky/vistas/guardian/pantalla_guardian.dart';

import 'ayudas/fuente_lato.dart';

/// Servidor falso: clave «buena» entra; `mi_rol` responde [rol]. Anota cada llamada.
Servidor _servidor({String? rol, List<String>? llamadas}) => Servidor(
      base: 'https://falso.supabase.co',
      anon: 'anon-de-prueba',
      cliente: MockClient((req) async {
        llamadas?.add('${req.method} ${req.url.path}');
        final p = req.url.path;
        if (p == '/auth/v1/token') {
          final cuerpo = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>;
          if (cuerpo['password'] == 'buena' || cuerpo.containsKey('refresh_token')) {
            return http.Response(
                jsonEncode({'access_token': 'tok', 'refresh_token': 'ref2', 'expires_in': 3600}), 200);
          }
          return http.Response(jsonEncode({'error_code': 'invalid_credentials', 'msg': 'Invalid login credentials'}), 400);
        }
        if (p == '/rest/v1/rpc/mi_rol') return http.Response(jsonEncode(rol), 200);
        if (p == '/auth/v1/recover') return http.Response('{}', 200);
        if (p == '/auth/v1/logout') return http.Response('', 204);
        if (p == '/rest/v1/reportes') return http.Response('[]', 200);
        return http.Response('', 404);
      }),
    );

late Manglar _manglar;

EstadoZanky _estado() => EstadoZanky()
  ..manglar = _manglar
  ..listo = true
  ..perfil = Perfil(id: '123e4567-e89b-12d3-a456-426614174000', nombre: 'Ana Pérez', creado: DateTime(2026, 11, 1));

Future<void> _montar(WidgetTester t, Widget hijo, Size tam, ControladorCuenta cuenta, {ControladorAdmin? admin}) async {
  t.view.physicalSize = tam;
  t.view.devicePixelRatio = 1;
  addTearDown(() {
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  Widget app = MaterialApp(debugShowCheckedModeBanner: false, theme: temaZanky(), home: Scaffold(body: hijo));
  if (admin != null) app = AdminScope(controlador: admin, child: app);
  app = CuentaScope(cuenta: cuenta, child: app);
  await t.pumpWidget(Zanky(estado: _estado(), child: app));
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _avanzar(WidgetTester t, {int veces = 6}) async {
  for (var i = 0; i < veces; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

const _tamanos = <(String, Size)>[('390x844', Size(390, 844)), ('1280x800', Size(1280, 800))];

void main() {
  setUpAll(() async {
    await cargarLato();
    _manglar = Manglar.desdeJson(
        jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync()) as Map<String, dynamic>);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Permisos por rol', () {
    test('sin sesión o sin rol no hay gestión', () {
      expect(gestionesDe(null), isEmpty);
      expect(gestionesDe('ciudadano'), isEmpty);
      final c = ControladorCuenta(servidor: _servidor());
      expect(c.conSesion, isFalse);
      expect(c.gestiones, isEmpty);
    });

    test('cada rol ve lo suyo y solo lo suyo', () {
      expect(gestionesDe('admin'), Gestion.values);
      expect(gestionesDe('moderador_cra'), [Gestion.panelCra, Gestion.sensores]);
      expect(gestionesDe('vigia'), [Gestion.panelCra, Gestion.sensores]);
      expect(gestionesDe('investigador'), [Gestion.puntos, Gestion.sensores]);
      expect(gestionesDe('organizador'), [Gestion.jornadas, Gestion.puntos, Gestion.contenido]);
      expect(gestionesDe('aliado'), [Gestion.sensores]);
      for (final r in ['investigador', 'organizador', 'aliado']) {
        expect(gestionesDe(r), isNot(contains(Gestion.panelCra)), reason: r);
      }
    });
  });

  test('la tabla de permisos del panel reemplaza la de fábrica y avisa a la cuenta', () async {
    final c = ControladorCuenta(servidor: _servidor(rol: 'organizador'));
    await c.entrar('org@ejemplo.co', 'buena');
    var avisos = 0;
    c.addListener(() => avisos++);
    permisosConfigurados.value = {'organizador': [Gestion.contenido, Gestion.jornadas]};
    addTearDown(() => permisosConfigurados.value = null);
    expect(avisos, greaterThan(0));
    expect(c.gestiones, [Gestion.jornadas, Gestion.contenido]);
    expect(RolPanel.puede('organizador', Gestion.puntos), isFalse);
    expect(RolPanel.puede('admin', Gestion.puntos), isTrue, reason: 'un rol fuera del mapa usa el de fábrica');
    permisosConfigurados.value = null;
    expect(c.gestiones, permisosPorDefecto('organizador'));
    c.dispose();
  });

  group('Sesión', () {
    test('contraseña mala: error claro y sin sesión', () async {
      final c = ControladorCuenta(servidor: _servidor(rol: 'admin'));
      await expectLater(
        c.entrar('ana@ejemplo.co', 'mala'),
        throwsA(isA<ErrorCuenta>().having((e) => e.mensaje, 'mensaje', 'Correo o contraseña incorrectos.')),
      );
      expect(c.conSesion, isFalse);
      expect(c.gestiones, isEmpty);
    });

    test('sin red: lo dice, no inventa', () async {
      final c = ControladorCuenta(
          servidor: Servidor(
              base: 'https://falso.supabase.co',
              anon: 'a',
              cliente: MockClient((_) async => throw const SocketException('sin red'))));
      await expectLater(c.entrar('ana@ejemplo.co', 'x'),
          throwsA(isA<ErrorCuenta>().having((e) => e.mensaje, 'm', contains('No hay conexión'))));
    });

    test('entra, lee el rol del servidor, guarda la sesión y otra app la restaura', () async {
      final c = ControladorCuenta(servidor: _servidor(rol: 'investigador'));
      await c.entrar(' ana@ejemplo.co ', 'buena');
      expect(c.conSesion, isTrue);
      expect(c.correo, 'ana@ejemplo.co');
      expect(c.rol, 'investigador');
      expect(c.gestiones, [Gestion.puntos, Gestion.sensores]);
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ControladorCuenta.claveGuardada), contains('ref2'));

      final otra = ControladorCuenta(servidor: _servidor(rol: 'investigador'));
      await otra.restaurar();
      expect(otra.conSesion, isTrue);
      expect(otra.rol, 'investigador');
    });

    test('una cuenta sin rol entra, pero sin gestión', () async {
      final c = ControladorCuenta(servidor: _servidor());
      await c.entrar('vecina@ejemplo.co', 'buena');
      expect(c.conSesion, isTrue);
      expect(c.rol, isNull);
      expect(c.gestiones, isEmpty);
    });

    test('un rol que modera abre el panel CRA con la misma sesión; cerrar sesión lo cierra y borra todo', () async {
      final llamadas = <String>[];
      final s = _servidor(rol: 'moderador_cra', llamadas: llamadas);
      final panel = ControladorAdmin(servidor: s, cada: Duration.zero);
      final c = ControladorCuenta(servidor: s, panel: panel);
      await c.entrar('mod@ejemplo.co', 'buena');
      expect(panel.dentro, isTrue);
      expect(panel.rol, 'moderador_cra');
      await c.salir();
      expect(c.conSesion, isFalse);
      expect(c.gestiones, isEmpty);
      expect(panel.dentro, isFalse);
      expect(llamadas, contains('POST /auth/v1/logout'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ControladorCuenta.claveGuardada), isNull);
      panel.dispose();
    });

    test('recuperar contraseña pide un correo y llama al servidor', () async {
      final llamadas = <String>[];
      final c = ControladorCuenta(servidor: _servidor(llamadas: llamadas));
      await expectLater(c.recuperarClave('sin-arroba'), throwsA(isA<ErrorCuenta>()));
      await c.recuperarClave('ana@ejemplo.co');
      expect(llamadas, contains('POST /auth/v1/recover'));
    });
  });

  group('Pantallas', () {
    for (final (tn, tam) in _tamanos) {
      testWidgets('Configuración sin sesión: formulario y nada de gestión · $tn', (t) async {
        final c = ControladorCuenta(servidor: _servidor(rol: 'admin'));
        await _montar(t, const PantallaConfiguracion(), tam, c);
        expect(find.text('ENTRAR CON TU CUENTA'), findsOneWidget);
        expect(find.textContaining('GESTIÓN'), findsNothing);
        expect(find.text('Panel CRA'), findsNothing);
        expect(find.text('Reportar en anónimo'), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('Inicio de sesión fallido muestra el motivo · $tn', (t) async {
        final c = ControladorCuenta(servidor: _servidor(rol: 'admin'));
        await _montar(t, const PantallaConfiguracion(), tam, c);
        await t.enterText(find.byType(TextField).at(0), 'ana@ejemplo.co');
        await t.enterText(find.byType(TextField).at(1), 'mala');
        await t.pump();
        await t.tap(find.text('Entrar'));
        await _avanzar(t, veces: 10);
        expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
        expect(find.textContaining('GESTIÓN'), findsNothing);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 5));
      });

      testWidgets('Entrar como organizador desbloquea solo lo suyo; cerrar sesión lo quita · $tn', (t) async {
        final c = ControladorCuenta(servidor: _servidor(rol: 'organizador'));
        await _montar(t, const PantallaConfiguracion(), tam, c);
        await t.enterText(find.byType(TextField).at(0), 'org@ejemplo.co');
        await t.enterText(find.byType(TextField).at(1), 'buena');
        await t.pump();
        await t.tap(find.text('Entrar'));
        await _avanzar(t, veces: 10);
        expect(find.text('GESTIÓN · ORGANIZACIÓN DE JORNADAS'), findsOneWidget);
        expect(find.text('Jornadas'), findsOneWidget);
        expect(find.text('Puntos Zanky'), findsOneWidget);
        expect(find.text('Contenido de la app'), findsOneWidget);
        expect(find.text('Panel CRA'), findsNothing);
        expect(find.text('Sensores del manglar'), findsNothing);

        await t.ensureVisible(find.byKey(const ValueKey('cerrar_sesion')));
        await t.tap(find.byKey(const ValueKey('cerrar_sesion')));
        await _avanzar(t, veces: 6);
        await t.tap(find.text('Cerrar sesión').last);
        await _avanzar(t, veces: 10);
        expect(c.conSesion, isFalse);
        expect(find.textContaining('GESTIÓN'), findsNothing);
        expect(find.text('ENTRAR CON TU CUENTA'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 5));
      });

      testWidgets('Guardián: sin sesión no hay gestión; con admin aparece toda · $tn', (t) async {
        final admin = ControladorAdmin(servidor: Servidor(base: '', anon: ''), cada: Duration.zero);
        final c = ControladorCuenta(servidor: Servidor(base: '', anon: ''), panel: admin);
        await _montar(t, const PantallaGuardian(), tam, c, admin: admin);
        expect(find.text('Panel CRA'), findsNothing);
        expect(find.textContaining('GESTIÓN'), findsNothing);
        c.entrarDemo();
        await _avanzar(t);
        await t.scrollUntilVisible(find.text('GESTIÓN · ADMINISTRACIÓN'), 200,
            scrollable: find.byType(Scrollable).first);
        expect(find.text('GESTIÓN · ADMINISTRACIÓN'), findsOneWidget);
        for (final g in Gestion.values) {
          await t.scrollUntilVisible(find.byKey(ValueKey('gestion_${g.name}')), 200,
              scrollable: find.byType(Scrollable).first);
        }
        expect(admin.dentro, isTrue);
        await c.salir();
        await _avanzar(t);
        expect(find.textContaining('GESTIÓN'), findsNothing);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 30));
        admin.dispose();
      });
    }
  });
}
