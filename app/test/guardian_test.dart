import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/guardian.dart';
import 'package:zanky/vistas/bienvenida/formulario.dart';
import 'package:zanky/vistas/guardian/borrar_datos.dart';
import 'package:zanky/vistas/guardian/tarjeta_guardian.dart';

const _id = '123e4567-e89b-12d3-a456-426614174000';

Perfil _perfil({String? sal}) => Perfil(id: _id, creado: DateTime(2026, 11, 1), sal: sal);

void main() {
  group('Sal y huella de la cédula', () {
    test('cada instalación tiene una sal aleatoria de 32 bytes', () {
      final a = _perfil(), b = _perfil();
      expect(base64Decode(a.sal).length, 32);
      expect(a.sal, isNot(b.sal));
    });

    test('la misma sal da la misma huella; otra sal da otra', () {
      final a = _perfil(), b = _perfil();
      expect(a.huellaCedula('1.043.555.777'), a.huellaCedula('1043555777'));
      expect(a.huellaCedula('1043555777'), isNot(b.huellaCedula('1043555777')));
      expect(a.huellaCedula('1043555777').length, 64);
    });

    test('no es el SHA-256 con la sal fija pública de antes', () {
      final viejo = sha256.convert(utf8.encode('zanky-guardian:1043555777')).toString();
      expect(_perfil().huellaCedula('1043555777'), isNot(viejo));
    });

    test('la sal sobrevive al guardado y un perfil viejo sin sal pierde su huella débil', () {
      final p = _perfil()..cedulaHash = 'x';
      final de = Perfil.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(de.sal, p.sal);
      expect(de.cedulaHash, 'x');
      expect(de.salPendiente, isFalse);

      final viejo = p.toJson()..remove('sal');
      final v = Perfil.fromJson(viejo);
      expect(v.cedulaHash, isNull);
      expect(v.salPendiente, isTrue);
    });
  });

  group('Código público', () {
    test('no es prefijo del id (reportante_id) y es estable con la misma sal', () {
      final sal = Perfil.generarSal();
      final p = _perfil(sal: sal);
      final prefijo = _id.replaceAll('-', '').substring(0, 6).toUpperCase();
      expect(p.codigo, matches(RegExp(r'^GM-[0-9A-F]{6}$')));
      expect(p.codigo, isNot('GM-$prefijo'));
      expect(p.codigo, _perfil(sal: sal).codigo);
      expect(p.codigo, isNot(_perfil().codigo));
    });
  });

  group('Mismos límites en bienvenida y editar perfil', () {
    test('la cédula admite de 6 a 10 dígitos', () {
      expect(DatosPerfil.validarCedula(''), isNull);
      expect(DatosPerfil.validarCedula('12345'), isNotNull);
      expect(DatosPerfil.validarCedula('123456'), isNull);
      expect(DatosPerfil.validarCedula('1234567890'), isNull);
      expect(DatosPerfil.validarCedula('12345678901'), isNotNull);
    });
  });

  group('Borrar mis datos', () {
    test('pide escribir BORRAR', () {
      expect(BorradoDatos.confirma('borrar'), isTrue);
      expect(BorradoDatos.confirma('  BORRAR '), isTrue);
      expect(BorradoDatos.confirma('borra'), isFalse);
      expect(BorradoDatos.confirma(''), isFalse);
    });

    test('borra perfil, reportes, celebradas, clima y fotos web; deja lo ajeno', () async {
      SharedPreferences.setMockInitialValues({
        'perfil.v1': '{}',
        'reportes.v1': ['{}'],
        'guardian.celebradas.v1': ['primer_aviso'],
        'clima:mallorquin': '{}',
        'foto:abc': 'AAAA',
        'otra.cosa': 'queda',
      });
      // path_provider simulado: una carpeta temporal con una foto dentro.
      final raiz = Directory.systemTemp.createTempSync('zanky_borrado');
      final fotos = Directory('${raiz.path}/fotos')..createSync();
      File('${fotos.path}/r1.jpg').writeAsBytesSync([1, 2, 3]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => raiz.path,
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
        raiz.deleteSync(recursive: true);
      });

      await BorradoDatos.borrarTodo();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'otra.cosa'});
      expect(fotos.existsSync(), isFalse);
    });
  });

  group('Tarjeta del guardián', () {
    testWidgets('el QR se construye una vez, no en cada cuadro del giro', (t) async {
      final perfil = _perfil();
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 560, child: TarjetaGuardian(perfil: perfil, progreso: Progreso.de(const []))),
          ),
        ),
      ));
      await t.tap(find.byType(TarjetaGuardian));
      await t.pumpAndSettle();
      final qr = find.byType(QrImageView);
      expect(qr, findsOneWidget);
      final primero = t.widget<QrImageView>(qr);
      // Tres cuadros más del giro y del brillo: la instancia del QR es la misma.
      await t.drag(find.byType(TarjetaGuardian), const Offset(30, 10));
      await t.pump(const Duration(milliseconds: 16));
      await t.pump(const Duration(milliseconds: 16));
      expect(identical(t.widget<QrImageView>(qr), primero), isTrue);
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 30));
    });
  });
}
