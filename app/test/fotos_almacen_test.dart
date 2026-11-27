// Fotos de los reportes pendientes en la web: almacén (IndexedDB en el navegador, en memoria
// aquí), migración desde localStorage, falta de espacio y reenvío sin duplicar.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zanky/datos/almacen_fotos.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/fotos.dart';
import 'package:zanky/datos/reporte.dart';

import 'apoyo_datos.dart';

Uint8List _bytes(int n, int v) => Uint8List.fromList(List.filled(n, v));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlmacenDePrueba prefsFalsas;
  late AlmacenFotosMemoria mem;
  late AlmacenFotos? anterior;
  final desechar = <EstadoZanky>[];

  setUp(() {
    prefsFalsas = AlmacenDePrueba();
    SharedPreferencesStorePlatform.instance = prefsFalsas;
    SharedPreferences.resetStatic();
    anterior = Fotos.almacen;
    mem = AlmacenFotosMemoria();
    Fotos.almacen = mem;
  });

  tearDown(() {
    Fotos.almacen = anterior;
    for (final e in desechar) {
      e.dispose();
    }
    desechar.clear();
  });

  EstadoZanky estadoCon(ServidorFalso s) {
    final e = EstadoZanky(servidor: s.servidor);
    desechar.add(e);
    return e;
  }

  group('Guardar, leer y borrar', () {
    test('la foto va al almacén y no a localStorage', () async {
      final ref = await Fotos.guardar('a1', _bytes(300, 1));
      expect(ref, 'foto:a1');
      expect(mem.datos.keys, ['foto:a1']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith('foto:')), isEmpty);
      expect(await Fotos.leer(ref), isNotNull);
      await Fotos.borrar(ref);
      expect(mem.datos, isEmpty);
      expect(await Fotos.leer(ref), isNull);
    });

    test('lleno: lanza ErrorAlGuardar con sinEspacio y no deja nada a medias', () async {
      mem.capacidad = 100;
      await expectLater(
        Fotos.guardar('b1', _bytes(5000, 2)),
        throwsA(isA<ErrorAlGuardar>().having((e) => e.sinEspacio, 'sinEspacio', true)),
      );
      expect(mem.datos, isEmpty);
    });

    test('un fallo cualquiera también es ErrorAlGuardar (mensaje claro)', () async {
      mem.fallarProximo = Exception('InvalidStateError');
      await expectLater(Fotos.guardar('b2', _bytes(10, 2)), throwsA(isA<ErrorAlGuardar>()));
    });

    test('lleno al guardar la foto: el reporte con su texto se puede guardar sin foto', () async {
      mem.capacidad = 10;
      await expectLater(Fotos.guardar('c1', _bytes(5000, 3)), throwsA(isA<ErrorAlGuardar>()));
      final e = estadoCon(ServidorFalso())..enLinea = false;
      final r = await e.agregar(reporteDePrueba(idDePrueba(1)), null);
      expect(r.descripcion, 'Prueba');
      expect(r.fotoRef, isNull);
      expect(e.reportes.length, 1);
    });
  });

  group('Migración desde localStorage', () {
    test('mueve todas las fotos, las deja legibles y vacía localStorage', () async {
      SharedPreferences.setMockInitialValues({
        'foto:x1': base64Encode(_bytes(2000, 7)),
        'foto:x2': base64Encode(_bytes(3000, 8)),
        'otra': 'cosa',
      });
      SharedPreferences.resetStatic();
      expect(await Fotos.migrarDeLocalStorage(), 2);
      expect((await Fotos.leer('foto:x1'))!.length, 2000);
      expect((await Fotos.leer('foto:x2'))!.first, 8);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith('foto:')), isEmpty);
      expect(prefs.getString('otra'), 'cosa');
      expect(mem.datos.keys.toSet(), {'foto:x1', 'foto:x2'});
    });

    test('si no cabe, la foto se queda en localStorage (se sigue leyendo) y no se pierde', () async {
      SharedPreferences.setMockInitialValues({'foto:y1': base64Encode(_bytes(2000, 9))});
      SharedPreferences.resetStatic();
      mem.capacidad = 10;
      expect(await Fotos.migrarDeLocalStorage(), 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('foto:y1'), isTrue);
      expect((await Fotos.leer('foto:y1'))!.length, 2000);
      mem.capacidad = null;
      expect(await Fotos.migrarDeLocalStorage(), 1);
      expect(prefs.containsKey('foto:y1'), isFalse);
      expect(mem.datos.containsKey('foto:y1'), isTrue);
    });

    test('es idempotente: una segunda pasada no hace nada', () async {
      SharedPreferences.setMockInitialValues({'foto:z1': base64Encode(_bytes(100, 1))});
      SharedPreferences.resetStatic();
      expect(await Fotos.migrarDeLocalStorage(), 1);
      expect(await Fotos.migrarDeLocalStorage(), 0);
      expect(mem.datos.length, 1);
    });
  });

  group('Reenvío al volver la señal', () {
    test('en orden, sin duplicar, y la foto sigue guardada mientras no se confirme', () async {
      final s = ServidorFalso();
      final e = estadoCon(s)..enLinea = false;
      final ids = [idDePrueba(10), idDePrueba(11), idDePrueba(12)];
      for (var i = 0; i < ids.length; i++) {
        final ref = await Fotos.guardar(ids[i], _bytes(4000 + i, 5));
        await e.agregar(reporteDePrueba(ids[i], fotoRef: ref), null);
      }
      await e.sincronizar();
      expect(s.creados, isEmpty, reason: 'sin señal no se llama');
      expect(mem.datos.length, 3);

      // Servidor caído: la foto completa sigue guardada.
      s.alCrear = (p) async => http.Response('boom', 500);
      e.enLinea = true;
      await e.sincronizar();
      for (final id in ids) {
        expect((await mem.leer('foto:$id'))!.length, greaterThan(3000));
      }
      expect(e.reportes.every((r) => r.envio != Envio.enviado), isTrue);

      // Vuelve el servidor: se envía en orden de creación, una vez cada uno.
      s
        ..alCrear = null
        ..creados.clear();
      for (final r in e.reportes) {
        r.envio = Envio.enCola;
      }
      await e.sincronizar();
      expect(s.creados, ids);
      // Cada foto subió una sola vez: la del primer intento no se repite.
      expect(s.fotos.map((f) => f.length), [4000, 4001, 4002]);
      expect(e.reportes.every((r) => r.envio == Envio.enviado), isTrue);

      await e.sincronizar();
      expect(s.creados, ids);
    });

    test('tras confirmarse, queda solo la miniatura en el almacén', () async {
      final original = Fotos.hacerMiniatura;
      Fotos.hacerMiniatura = (b, ancho) async => Uint8List.fromList([1, 2, 3]);
      addTearDown(() => Fotos.hacerMiniatura = original);
      final s = ServidorFalso();
      final e = estadoCon(s);
      final ref = await Fotos.guardar(idDePrueba(20), _bytes(9000, 6));
      final r = await e.agregar(reporteDePrueba(idDePrueba(20), fotoRef: ref), null);
      await e.sincronizar();
      expect(r.envio, Envio.enviado);
      expect(s.fotos.single.length, 9000);
      expect(r.fotoReducida, isTrue);
      expect(mem.datos['foto:${idDePrueba(20)}'], [1, 2, 3]);
    });
  });
}
