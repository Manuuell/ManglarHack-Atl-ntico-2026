// «Crear cuenta» de la app: mismos datos que la web (/auth/v1/signup), con sesión o con
// «revisa tu correo»; la hoja cambia de pestaña. Servidor falso, sin red.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/cuenta/cuenta.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/configuracion/cuenta_entrar.dart';

Servidor _servidor({required bool conSesion, List<Map<String, dynamic>>? cuerpos, int estado = 200}) => Servidor(
      base: 'https://falso.supabase.co',
      anon: 'anon-de-prueba',
      cliente: MockClient((req) async {
        if (req.url.path == '/auth/v1/signup') {
          cuerpos?.add(jsonDecode(req.body) as Map<String, dynamic>);
          if (estado != 200) {
            return http.Response(jsonEncode({'error_code': 'user_already_exists', 'msg': 'User already registered'}), estado);
          }
          return http.Response(
              jsonEncode(conSesion
                  ? {'access_token': 'tok', 'refresh_token': 'r', 'expires_in': 3600}
                  : {'id': 'u1', 'email': 'ana@x.co'}),
              200);
        }
        if (req.url.path == '/rest/v1/rpc/mi_rol') return http.Response('null', 200);
        return http.Response('', 404);
      }),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('normalizarCelular y correoValido como la web', () {
    expect(normalizarCelular('300 123 4567'), '573001234567');
    expect(normalizarCelular(''), isNull);
    expect(normalizarCelular('12'), celularInvalido);
    expect(correoValido('ana@x.co'), isTrue);
    expect(correoValido('ana@x'), isFalse);
  });

  test('crearCuenta manda los datos del perfil y entra si el servidor da sesión', () async {
    final cuerpos = <Map<String, dynamic>>[];
    final c = ControladorCuenta(servidor: _servidor(conSesion: true, cuerpos: cuerpos));
    final r = await c.crearCuenta(
        nombre: ' Ana ', correo: 'ana@x.co', clave: 'clave1234', sector: 'Balboa', telefono: '573001234567', whatsappOk: true);
    expect(r, ResultadoCrear.sesion);
    expect(c.conSesion, isTrue);
    final data = cuerpos.single['data'] as Map<String, dynamic>;
    expect(data['nombre'], 'Ana');
    expect(data['sector'], 'Balboa');
    expect(data['whatsapp_ok'], isTrue);
    expect(data['consentimiento_ley_1581'], isNotNull);
  });

  test('sin sesión pide confirmar el correo; correo repetido da error traducido', () async {
    final c = ControladorCuenta(servidor: _servidor(conSesion: false));
    expect(await c.crearCuenta(nombre: 'Ana', correo: 'ana@x.co', clave: 'clave1234'), ResultadoCrear.confirmar);
    expect(c.conSesion, isFalse);
    final d = ControladorCuenta(servidor: _servidor(conSesion: false, estado: 422));
    expect(
      () => d.crearCuenta(nombre: 'Ana', correo: 'ana@x.co', clave: 'clave1234'),
      throwsA(isA<ErrorCuenta>().having((e) => e.mensaje, 'mensaje', contains('Ya hay una cuenta'))),
    );
  });

  testWidgets('la hoja pasa a «Crear cuenta», valida y avisa «revisa tu correo»', (t) async {
    t.view.physicalSize = const Size(390, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = ControladorCuenta(servidor: _servidor(conSesion: false));
    await t.pumpWidget(MaterialApp(
      theme: temaZanky(),
      home: Scaffold(body: SingleChildScrollView(child: FormularioEntrar(cuenta: c))),
    ));
    await t.pumpAndSettle();
    expect(find.text('Crear mi cuenta'), findsNothing);
    await t.tap(find.text('Crear cuenta'));
    await t.pumpAndSettle();
    expect(find.text('Crear mi cuenta'), findsOneWidget);
    expect(find.text('Tu sector del manglar (opcional)'), findsOneWidget);
    final campos = find.byType(TextField);
    await t.enterText(campos.at(0), 'Ana');
    await t.enterText(campos.at(1), 'ana@x.co');
    await t.enterText(campos.at(2), 'clave1234');
    await t.pump();
    await t.tap(find.text('Crear mi cuenta'));
    await t.pumpAndSettle();
    expect(find.textContaining('aceptar el tratamiento de datos'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('casilla_acepta')));
    await t.pumpAndSettle();
    await t.tap(find.text('Crear mi cuenta'));
    await t.pumpAndSettle();
    expect(find.textContaining('Te enviamos un correo a ana@x.co'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
