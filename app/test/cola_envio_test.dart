// La cola de envío (EstadoZanky): sin señal, red caída, rechazos, vueltas que se piden
// durante otra, estados por tandas, varias pestañas y falta de espacio.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/fotos.dart';
import 'package:zanky/datos/reporte.dart';
import 'package:zanky/datos/tipos.dart';

import 'apoyo_datos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlmacenDePrueba almacen;
  final desechar = <EstadoZanky>[];

  setUp(() {
    almacen = AlmacenDePrueba();
    SharedPreferencesStorePlatform.instance = almacen;
    SharedPreferences.resetStatic();
  });

  tearDown(() {
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

  Future<List<Reporte>> enDisco() async =>
      EstadoZanky.leerReportes(await almacen.leerLista(EstadoZanky.claveReportes));

  group('Sin señal (hallazgo 16)', () {
    test('un reporte nuevo queda «en el teléfono», sin intentos ni llamadas', () async {
      final s = ServidorFalso();
      final e = estadoCon(s)..enLinea = false;
      final r = await e.agregar(reporteDePrueba(idDePrueba(1)), null);
      await e.sincronizar();
      expect(r.envio, Envio.enCola);
      expect(r.intentos, 0);
      expect(s.pedidos, isEmpty);
      expect(e.fallosSeguidos, 0);
    });

    test('al volver la red se envía ya, sin esperar el reintento', () async {
      final s = ServidorFalso();
      final e = estadoCon(s)..enLinea = false;
      final r = await e.agregar(reporteDePrueba(idDePrueba(1)), null);
      e.cambioDeRed(true);
      await e.sincronizar(); // espera la vuelta que lanzó el cambio de red
      expect(r.envio, Envio.enviado);
      expect(s.creados, [r.id]);
    });

    test('un fallo de red deja el reporte en cola, sin sumar intentos, y corta la vuelta (hallazgo 15)', () async {
      final s = ServidorFalso(alCrear: (_) async => throw http.ClientException('Failed host lookup'));
      final e = estadoCon(s);
      e.reportes.addAll([
        reporteDePrueba(idDePrueba(1), capturado: DateTime(2026, 11, 27, 9)),
        reporteDePrueba(idDePrueba(2), capturado: DateTime(2026, 11, 27, 10)),
        reporteDePrueba(idDePrueba(3), capturado: DateTime(2026, 11, 27, 11)),
      ]);
      await e.sincronizar();
      expect(s.creados.length, 1, reason: 'tras el primer fallo de red no se intentan los demás');
      for (final r in e.reportes) {
        expect(r.envio, Envio.enCola);
        expect(r.intentos, 0);
      }
      expect(s.tandasDeEstados, isEmpty);
      expect(s.publicosPedidos, 0);
      expect(e.fallosSeguidos, 1);
    });

    test('un plazo vencido también cuenta como red, no como error del reporte', () async {
      final s = ServidorFalso(alCrear: (_) async => throw TimeoutException('lento'));
      final e = estadoCon(s);
      final r = await e.agregar(reporteDePrueba(idDePrueba(1)), null);
      await e.sincronizar();
      expect(r.envio, Envio.enCola);
      expect(r.intentos, 0);
    });
  });

  group('Respuestas del servidor (hallazgos 1, 3 y 17)', () {
    test('éxito: llega por crear_reporte, sin «ignore-duplicates», y guarda el id público', () async {
      final s = ServidorFalso();
      final e = estadoCon(s);
      final r = await e.agregar(reporteDePrueba(idDePrueba(7)), null);
      await e.sincronizar();
      expect(r.envio, Envio.enviado);
      expect(r.idPublico, 'pub-${r.id}');
      final pedido = s.pedidos.firstWhere((p) => p.url.path.endsWith('/rpc/crear_reporte'));
      expect(pedido.headers.keys.map((k) => k.toLowerCase()), isNot(contains('prefer')));
      expect((await enDisco()).single.envio, Envio.enviado);
    });

    test('un 400 (punto fuera del Atlántico) se rechaza, se explica y no se reintenta', () async {
      final s = ServidorFalso(
        alCrear: (_) async => http.Response(
            jsonEncode({
              'code': '22023',
              'message': 'punto_fuera_del_atlantico: el punto queda fuera del departamento del Atlántico',
            }),
            400),
      );
      final e = estadoCon(s);
      final r = await e.agregar(reporteDePrueba(idDePrueba(3)), null);
      await e.sincronizar();
      expect(r.envio, Envio.rechazado);
      expect(r.motivoRechazo, contains('fuera del Atlántico'));
      expect(r.ultimoError, contains('400'));
      expect(r.intentos, 0);
      expect(e.pendientes, 0, reason: 'un rechazado no espera salir');
      expect(e.rechazados, 1);
      expect(e.fallosSeguidos, 0, reason: 'un rechazo no retrasa los reintentos de los demás');

      await e.sincronizar();
      expect(s.creados.length, 1, reason: 'reintentar no sirve: no se vuelve a mandar');
      final guardado = (await enDisco()).single;
      expect(guardado.envio, Envio.rechazado);
      expect(guardado.motivoRechazo, r.motivoRechazo);
    });

    test('un 503 es pasajero: error, suma un intento y la espera crece', () async {
      final s = ServidorFalso(alCrear: (_) async => http.Response('{"message":"servicio caído"}', 503));
      final e = estadoCon(s);
      final r = await e.agregar(reporteDePrueba(idDePrueba(4)), null);
      await e.sincronizar();
      expect(r.envio, Envio.error);
      expect(r.intentos, 1);
      expect(r.ultimoError, contains('503'));
      expect(e.pendientes, 1);
      expect(e.fallosSeguidos, 1);
    });

    test('un 429 (límite por hora) se reintenta más tarde, no se rechaza', () async {
      final s = ServidorFalso(alCrear: (_) async => http.Response('{"message":"limite_de_reportes"}', 429));
      final e = estadoCon(s);
      final r = await e.agregar(reporteDePrueba(idDePrueba(4)), null);
      await e.sincronizar();
      expect(r.envio, Envio.error);
    });

    test('un 200 que no trae el mismo id no es un éxito (regla 60)', () async {
      final s = ServidorFalso(alCrear: (_) async => http.Response('<html>Inicia sesión en el wifi</html>', 200));
      final e = estadoCon(s);
      final r = await e.agregar(reporteDePrueba(idDePrueba(5)), null);
      await e.sincronizar();
      expect(r.envio, Envio.error);
      expect(r.intentos, 1);
    });

    test('un rechazado se puede volver a poner en cola a mano', () async {
      var aceptar = false;
      final s = ServidorFalso(
        alCrear: (p) async => aceptar
            ? http.Response(jsonEncode({'id': p['id'], 'nuevo': true, 'id_publico': 'x'}), 200)
            : http.Response('{"message":"tipo_invalido: no existe"}', 400),
      );
      final e = estadoCon(s);
      final r = await e.agregar(reporteDePrueba(idDePrueba(6)), null);
      await e.sincronizar();
      expect(r.envio, Envio.rechazado);
      aceptar = true;
      await e.reintentar(r);
      expect(r.envio, Envio.enviado);
      expect(r.motivoRechazo, isNull);
    });
  });

  group('Vueltas pedidas durante otra (hallazgo 15b)', () {
    test('un reporte creado mientras se sube otro sale al terminar esa vuelta, no en 45 s', () async {
      final puerta = Completer<void>();
      final idA = idDePrueba(10), idB = idDePrueba(11);
      final s = ServidorFalso(alCrear: (p) async {
        if (p['id'] == idA) await puerta.future;
        return http.Response(jsonEncode({'id': p['id'], 'nuevo': true, 'id_publico': 'p'}), 200);
      });
      final e = estadoCon(s);
      final a = await e.agregar(reporteDePrueba(idA, capturado: DateTime(2026, 11, 27, 9)), null);
      await pumpEventQueue();
      expect(a.envio, Envio.enviando);
      final b = await e.agregar(reporteDePrueba(idB, capturado: DateTime(2026, 11, 27, 10)), null);
      final listo = e.sincronizar();
      puerta.complete();
      await listo;
      expect(a.envio, Envio.enviado);
      expect(b.envio, Envio.enviado);
      expect(s.creados, [idA, idB]);
    });
  });

  group('Estados del servidor (hallazgos 34 y 35)', () {
    test('se consultan en tandas de 100 todos los enviados abiertos, no solo los 100 más nuevos', () async {
      final s = ServidorFalso();
      final e = estadoCon(s);
      for (var i = 0; i < 250; i++) {
        final cerrado = i < 10;
        e.reportes.add(reporteDePrueba(
          idDePrueba(1000 + i),
          envio: Envio.enviado,
          estado: cerrado ? EstadoReporte.cerrado : EstadoReporte.recibido,
          idPublico: 'pub$i',
          capturado: DateTime(2026, 1, 1).add(Duration(hours: i)),
        ));
      }
      await e.sincronizar();
      expect(s.tandasDeEstados.map((t) => t.length), [100, 100, 40]);
      final consultados = s.tandasDeEstados.expand((t) => t).toSet();
      expect(consultados.length, 240);
      expect(consultados, isNot(contains(idDePrueba(1000))), reason: 'un cerrado con id público ya no cambia');
      expect(consultados, contains(idDePrueba(1010)), reason: 'el más viejo de los abiertos también se consulta');
    });

    test('la prioridad, la confianza y el id público del servidor quedan en disco', () async {
      final id = idDePrueba(20);
      final s = ServidorFalso(
        alEstados: (ids) async => http.Response(
            jsonEncode([
              {
                'id': id,
                'estado': 'recibido',
                'prioridad': 4,
                'confianza': 80,
                'nota_publica': null,
                'actualizado_en': '2026-11-27T15:00:00Z',
                'id_publico': 'publico-20',
              }
            ]),
            200),
      );
      final e = estadoCon(s);
      e.reportes.add(reporteDePrueba(id, envio: Envio.enviado, prioridad: 5, confianza: 92));
      await e.sincronizar();
      final r = (await enDisco()).single;
      expect(r.prioridad, 4);
      expect(r.confianza, 80);
      expect(r.idPublico, 'publico-20');
      expect(r.prioridadLocal, 5, reason: 'la del teléfono se conserva para explicar el ajuste');
      expect(r.prioridadAjustada, isTrue);
    });

    test('los públicos que son míos no se repiten en la lista pública', () async {
      final s = ServidorFalso()
        ..publicos = [
          {'id_publico': 'pub-mio', 'tipo': 'tala', 'lat': 11.05, 'lon': -74.85, 'prioridad': 4,
           'estado': 'recibido', 'capturado_en': '2026-11-27T10:00:00Z', 'zona': 'mallorquin'},
          {'id_publico': 'pub-ajeno', 'tipo': 'quema', 'lat': 11.05, 'lon': -74.85, 'prioridad': 4,
           'estado': 'recibido', 'capturado_en': '2026-11-27T10:00:00Z', 'zona': 'mallorquin'},
        ];
      final e = estadoCon(s);
      e.reportes.add(reporteDePrueba(idDePrueba(30), envio: Envio.enviado, idPublico: 'pub-mio'));
      await e.sincronizar();
      expect(e.publicos.map((p) => p.id), ['pub-ajeno']);
    });
  });

  group('Disco: primero guardar, sin duplicar, varias pestañas (hallazgos 2 y 14)', () {
    test('si el navegador no tiene espacio, el reporte no entra en memoria y el error se puede mostrar', () async {
      final e = estadoCon(ServidorFalso())..enLinea = false;
      almacen.fallarCon = 'flutter.${EstadoZanky.claveReportes}';
      final id = idDePrueba(40);
      await expectLater(
        e.agregar(reporteDePrueba(id), null),
        throwsA(isA<ErrorAlGuardar>().having((x) => x.sinEspacio, 'sinEspacio', isTrue)),
      );
      expect(e.reportes, isEmpty);
      expect(await enDisco(), isEmpty);

      almacen.fallarCon = null;
      await e.agregar(reporteDePrueba(id), null); // «Reintentar» con el mismo borrador
      await e.agregar(reporteDePrueba(id), null); // y un doble toque
      expect(e.reportes.where((r) => r.id == id).length, 1);
      expect((await enDisco()).length, 1);
    });

    test('lo que escribió otra pestaña no se borra al guardar aquí', () async {
      final e = estadoCon(ServidorFalso())..enLinea = false;
      await e.agregar(reporteDePrueba(idDePrueba(50)), null);
      // La otra pestaña, que cargó antes, agrega el suyo y marca el 50 como enviado.
      final otraPestana = [
        jsonEncode((reporteDePrueba(idDePrueba(50), envio: Envio.enviado)..idPublico = 'p50').toJson()),
        jsonEncode(reporteDePrueba(idDePrueba(51)).toJson()),
      ];
      await almacen.escribirDesdeOtraPestana(EstadoZanky.claveReportes, otraPestana);

      await e.agregar(reporteDePrueba(idDePrueba(52)), null);
      final disco = {for (final r in await enDisco()) r.id: r};
      expect(disco.keys, containsAll([idDePrueba(50), idDePrueba(51), idDePrueba(52)]));
      expect(disco[idDePrueba(50)]!.envio, Envio.enviado, reason: 'no vuelve atrás lo que la otra ya envió');
      final enMemoria = {for (final r in e.reportes) r.id: r};
      expect(enMemoria.keys, containsAll([idDePrueba(51), idDePrueba(52)]));
      expect(enMemoria[idDePrueba(50)]!.envio, Envio.enviado);
    });

    test('una vuelta no reenvía lo que otra pestaña ya envió', () async {
      final s = ServidorFalso();
      final e = estadoCon(s)..enLinea = false;
      final r = await e.agregar(reporteDePrueba(idDePrueba(60)), null);
      await almacen.escribirDesdeOtraPestana(EstadoZanky.claveReportes, [
        jsonEncode(reporteDePrueba(idDePrueba(60), envio: Envio.enviado).toJson()),
      ]);
      e.enLinea = true;
      await e.sincronizar();
      expect(r.envio, Envio.enviado);
      expect(s.creados, isEmpty);
    });

    test('si guardar falla en medio de la vuelta, la vuelta sigue (estados y mapa)', () async {
      final s = ServidorFalso();
      final e = estadoCon(s)..enLinea = false;
      final r = await e.agregar(reporteDePrueba(idDePrueba(70)), null);
      almacen.fallarCon = 'flutter.${EstadoZanky.claveReportes}';
      e.enLinea = true;
      await e.sincronizar();
      expect(r.envio, Envio.enviado);
      expect(s.publicosPedidos, greaterThan(0));
    });

    test('al leer, un id repetido (versión vieja) queda una vez, con la copia más avanzada', () {
      final lista = EstadoZanky.leerReportes([
        jsonEncode(reporteDePrueba(idDePrueba(80)).toJson()),
        jsonEncode(reporteDePrueba(idDePrueba(80), envio: Envio.enviado).toJson()),
        '{dañado',
      ]);
      expect(lista.length, 1);
      expect(lista.single.envio, Envio.enviado);
    });
  });

  group('Foto después del envío (hallazgo 13)', () {
    late Directory tmp;
    late Future<Uint8List?> Function(Uint8List, int) original;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('zanky_fotos_');
      original = Fotos.hacerMiniatura;
      Fotos.hacerMiniatura = (b, ancho) async => Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, ancho]);
    });
    tearDown(() {
      Fotos.hacerMiniatura = original;
      tmp.deleteSync(recursive: true);
    });

    test('al llegar, la foto completa se cambia por una miniatura y la original se borra', () async {
      final ruta = '${tmp.path}/${idDePrueba(90)}.jpg';
      File(ruta).writeAsBytesSync(List.filled(5000, 7));
      final s = ServidorFalso();
      final e = estadoCon(s);
      final r = await e.agregar(reporteDePrueba(idDePrueba(90), fotoRef: ruta), null);
      await e.sincronizar();
      expect(r.envio, Envio.enviado);
      expect(s.fotos.single.length, 5000, reason: 'se subió la completa');
      expect(File(ruta).existsSync(), isFalse);
      expect(r.fotoReducida, isTrue);
      expect(r.fotoRef, endsWith('.min.png'));
      expect(File(r.fotoRef!).readAsBytesSync(), [0x89, 0x50, 0x4E, 0x47, Fotos.anchoMiniatura]);
      final guardado = (await enDisco()).single;
      expect(guardado.fotoRef, r.fotoRef);
      expect(guardado.fotoReducida, isTrue);
    });

    test('lo que no ha llegado conserva la foto completa', () async {
      final ruta = '${tmp.path}/${idDePrueba(91)}.jpg';
      File(ruta).writeAsBytesSync(List.filled(100, 7));
      final e = estadoCon(ServidorFalso())..enLinea = false;
      final r = await e.agregar(reporteDePrueba(idDePrueba(91), fotoRef: ruta), null);
      await e.sincronizar();
      expect(File(ruta).existsSync(), isTrue);
      expect(r.fotoReducida, isFalse);
    });

    test('si la miniatura no se puede hacer, la foto se borra igual (ya está en la CRA)', () async {
      Fotos.hacerMiniatura = (b, a) async => throw const FormatException('no es imagen');
      final ruta = '${tmp.path}/${idDePrueba(92)}.jpg';
      File(ruta).writeAsBytesSync(List.filled(100, 7));
      final e = estadoCon(ServidorFalso());
      final r = await e.agregar(reporteDePrueba(idDePrueba(92), fotoRef: ruta), null);
      await e.sincronizar();
      expect(File(ruta).existsSync(), isFalse);
      expect(r.fotoRef, isNull);
      expect(r.fotoReducida, isTrue);
    });
  });

  test('olvidarTodo deja la memoria vacía', () async {
    final e = estadoCon(ServidorFalso())..enLinea = false;
    await e.agregar(reporteDePrueba(idDePrueba(95)), null);
    e.olvidarTodo();
    expect(e.reportes, isEmpty);
    expect(e.perfil, isNull);
    expect(e.publicos, isEmpty);
  });

  test('un envío en vuelo durante el borrado NO vuelve a escribir reportes.v1', () async {
    final puerta = Completer<void>();
    final s = ServidorFalso(alCrear: (p) async {
      await puerta.future; // el envío sigue en el aire mientras se borra
      return http.Response(jsonEncode({'id': p['id'], 'nuevo': true, 'id_publico': 'pub-${p['id']}'}), 200);
    });
    final e = estadoCon(s)..enLinea = true;
    await e.agregar(reporteDePrueba(idDePrueba(96)), null);
    final vuelta = e.sincronizar();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(s.creados, isNotEmpty);

    // Lo que hace «Borrar mis datos»: primero el disco, luego la memoria.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(EstadoZanky.claveReportes);
    e.olvidarTodo();

    puerta.complete();
    await vuelta;
    await e.sincronizar();
    expect(await almacen.leerLista(EstadoZanky.claveReportes), isEmpty, reason: 'no debe reaparecer ni la clave');
    expect((await almacen.getAll()).keys, isNot(contains('flutter.${EstadoZanky.claveReportes}')));
    expect(e.reportes, isEmpty);
  });
}
