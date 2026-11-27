// El contrato con el servidor: crear_reporte, errores permanentes y pasajeros, plazo de
// la foto con cancelación real, id público y campos nuevos del reporte.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:zanky/datos/reporte.dart';
import 'package:zanky/datos/servidor.dart';

import 'apoyo_datos.dart';

void main() {
  group('Servidor.enviar', () {
    test('manda {p: aServidor()} a crear_reporte y devuelve el id público', () async {
      final s = ServidorFalso();
      final r = reporteDePrueba(idDePrueba(1));
      final pub = await s.servidor.enviar(r, null);
      expect(pub, 'pub-${r.id}');
      final req = s.pedidos.single;
      expect(req.url.path, '/rest/v1/rpc/crear_reporte');
      expect(req.method, 'POST');
      final cuerpo = jsonDecode(req.body) as Map<String, dynamic>;
      expect(cuerpo.keys, ['p']);
      expect(cuerpo['p'], jsonDecode(jsonEncode(r.aServidor())));
      expect(req.headers.keys.map((k) => k.toLowerCase()), isNot(contains('prefer')));
    });

    test('un reintento que el servidor ya tenía (nuevo: false) también es éxito', () async {
      final s = ServidorFalso(
          alCrear: (p) async => http.Response(jsonEncode({'id': p['id'], 'nuevo': false, 'id_publico': 'x'}), 200));
      expect(await s.servidor.enviar(reporteDePrueba(idDePrueba(2)), null), 'x');
    });

    test('la foto «ya existe» de un envío cortado cuenta como subida', () async {
      final s = ServidorFalso(alSubirFoto: (_) async => http.Response('{"error":"Duplicate","message":"The resource already exists"}', 409));
      final r = reporteDePrueba(idDePrueba(3));
      await s.servidor.enviar(r, Uint8List.fromList([1, 2, 3]));
      expect(r.fotoUrl, 'evidencias/${r.id}.jpg');
    });

    test('una foto de más de 5 MB es un rechazo con su motivo', () async {
      final s = ServidorFalso(alSubirFoto: (_) async => http.Response('{"message":"Payload too large"}', 413));
      final r = reporteDePrueba(idDePrueba(4));
      await expectLater(
        s.servidor.enviar(r, Uint8List.fromList([1, 2, 3])),
        throwsA(isA<ErrorServidor>()
            .having((e) => e.permanente, 'permanente', isTrue)
            .having((e) => e.motivo, 'motivo', contains('pesa demasiado'))),
      );
      expect(r.fotoUrl, isNull);
    });

    test('la foto sale sin EXIF aunque se haya guardado con él (versiones viejas)', () async {
      final s = ServidorFalso();
      await s.servidor.enviar(reporteDePrueba(idDePrueba(5)), base64Decode(jpegConGps));
      final subida = latin1.decode(s.fotos.single);
      expect(subida, isNot(contains('TelefonoX')));
      expect(subida, isNot(contains('Exif\x00\x00MM\x00*\x00\x00\x00\x08\x00\x04')));
    });
  });

  group('Errores: permanentes contra pasajeros', () {
    ErrorServidor err(int codigo, [String cuerpo = '']) => ErrorServidor('reporte $codigo', cuerpo, estadoHttp: codigo);

    test('solo los 4xx de validación son permanentes', () {
      for (final c in [400, 413, 415, 422]) {
        expect(err(c).permanente, isTrue, reason: '$c');
      }
      for (final c in [401, 403, 404, 408, 409, 429, 500, 502, 503, 200]) {
        expect(err(c).permanente, isFalse, reason: '$c');
      }
    });

    test('el motivo se dice en palabras y el texto técnico guarda el código y el mensaje', () {
      final e = err(400, '{"code":"22023","message":"punto_fuera_del_atlantico: fuera del departamento"}');
      expect(e.motivo, contains('fuera del Atlántico'));
      expect(e.toString(), contains('(reporte 400)'));
      expect(e.toString(), contains('punto_fuera_del_atlantico'));
      expect(err(400, '{"message":"algo raro"}').motivo, contains('código 400'));
    });

    test('esErrorDeRed reconoce la red y el plazo, no las respuestas', () {
      expect(esErrorDeRed(http.ClientException('x')), isTrue);
      expect(esErrorDeRed(TimeoutException('x')), isTrue);
      expect(esErrorDeRed(const SocketException('x')), isTrue);
      expect(esErrorDeRed(err(503)), isFalse);
      expect(esErrorDeRed(const FormatException('x')), isFalse);
    });
  });

  group('Plazo de la foto (mala señal)', () {
    test('crece con el tamaño y tiene tope', () {
      expect(Servidor.plazoParaFoto(0), const Duration(seconds: 20));
      expect(Servidor.plazoParaFoto(400 * 1000), const Duration(seconds: 54));
      expect(Servidor.plazoParaFoto(50 * 1000 * 1000), const Duration(minutes: 5));
    });

    test('un plazo vencido cancela de verdad la petición', () async {
      final mudo = ClienteMudo();
      final s = Servidor(base: 'https://zanky.test', anon: 'k', cliente: mudo);
      await expectLater(
        s.pedir('POST', Uri.parse('https://zanky.test/x'), const {}, plazo: const Duration(milliseconds: 30)),
        throwsA(isA<TimeoutException>()),
      );
      expect(mudo.canceladas, 1);
    });

    testWidgets('una foto de 400 KB tiene 54 s para subir, no 20', (tester) async {
      final mudo = ClienteMudo();
      final s = Servidor(base: 'https://zanky.test', anon: 'k', cliente: mudo);
      Object? error;
      final f = s.enviar(reporteDePrueba(idDePrueba(6)), Uint8List(400 * 1000)).catchError((Object e) {
        error = e;
        return null;
      });
      await tester.pump(const Duration(seconds: 50));
      expect(mudo.canceladas, 0, reason: 'a los 50 s todavía está subiendo');
      await tester.pump(const Duration(seconds: 5));
      await f;
      expect(mudo.canceladas, 1);
      expect(error, isA<TimeoutException>());
      expect(esErrorDeRed(error!), isTrue);
    });
  });

  group('Id público (hallazgo 11)', () {
    test('ReportePublico toma id_publico (y acepta la vista vieja con id)', () {
      final base = {'tipo': 'tala', 'lat': 11.05, 'lon': -74.85, 'estado': 'recibido', 'capturado_en': '2026-11-27T10:00:00Z'};
      expect(ReportePublico.fromJson({...base, 'id_publico': 'pub-1'}).id, 'pub-1');
      expect(ReportePublico.fromJson({...base, 'id': 'viejo'}).id, 'viejo');
    });

    test('EstadoRemoto trae el id público', () {
      final e = EstadoRemoto.fromJson({'id': 'a', 'estado': 'verificado', 'id_publico': 'p'});
      expect(e.idPublico, 'p');
    });

    test('la vista pública y los datos abiertos de schema.sql no sacan el id interno', () {
      final sql = File('../backend/supabase/schema.sql').readAsStringSync();
      final vista = RegExp(r'create view public\.reportes_publicos[\s\S]*?;').firstMatch(sql)!.group(0)!;
      expect(vista, contains('r.id_publico'));
      expect(vista, isNot(matches(RegExp(r'select r\.id,'))));
      expect(vista, contains("date_trunc('hour', r.capturado_en)"));
      expect(sql, isNot(contains("'id', p.id,")));
      expect(sql, isNot(contains('grant select (id) on public.reportes to anon')));
      expect(sql, contains('grant execute on function public.crear_reporte(jsonb)       to anon, authenticated;'));
    });
  });

  group('Reporte', () {
    test('lo que viaja al servidor son las 23 columnas del contrato y nada local', () {
      final r = reporteDePrueba(idDePrueba(7))
        ..idPublico = 'p'
        ..motivoRechazo = 'm'
        ..cambiadoEn = DateTime(2026);
      expect(r.aServidor().keys.toSet(), {
        'id', 'canal', 'tipo', 'descripcion', 'lat', 'lon', 'precision_m', 'metodo_ubicacion', 'capturado_en',
        'momento', 'magnitud', 'zona', 'municipio', 'dentro_poligono', 'distancia_m', 'prioridad', 'confianza',
        'foto_hash', 'foto_de_camara', 'foto_url', 'anonimo', 'reportante_id', 'sincronizado_tarde', //
      });
    });

    test('los campos nuevos se guardan y se leen', () {
      final r = reporteDePrueba(idDePrueba(8), envio: Envio.rechazado, prioridad: 4)
        ..idPublico = 'pub'
        ..motivoRechazo = 'Fuera del Atlántico'
        ..fotoReducida = true
        ..cambiadoEn = DateTime.utc(2026, 11, 27, 12);
      final b = Reporte.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(b.envio, Envio.rechazado);
      expect(b.idPublico, 'pub');
      expect(b.motivoRechazo, 'Fuera del Atlántico');
      expect(b.fotoReducida, isTrue);
      expect(b.prioridadLocal, 4);
      expect(b.cambiadoEn, r.cambiadoEn);
    });

    test('un reporte guardado por una versión vieja se lee sin los campos nuevos', () {
      final j = reporteDePrueba(idDePrueba(9)).toJson()
        ..remove('prioridad_local')
        ..remove('id_publico')
        ..remove('foto_reducida')
        ..remove('cambiado_en')
        ..['envio'] = 'algo_que_ya_no_existe';
      final b = Reporte.fromJson(j);
      expect(b.prioridadLocal, isNull);
      expect(b.prioridadAjustada, isFalse);
      expect(b.envio, Envio.enCola);
    });

    test('compararAvance: lo enviado no vuelve atrás; entre pendientes gana el último cambio', () {
      final viejo = reporteDePrueba(idDePrueba(10), envio: Envio.rechazado)..cambiadoEn = DateTime(2026, 1, 1, 10);
      final reintento = reporteDePrueba(idDePrueba(10))..cambiadoEn = DateTime(2026, 1, 1, 11);
      final enviado = reporteDePrueba(idDePrueba(10), envio: Envio.enviado)..cambiadoEn = DateTime(2026, 1, 1, 9);
      expect(Reporte.compararAvance(reintento, viejo), greaterThan(0));
      expect(Reporte.compararAvance(enviado, reintento), greaterThan(0));
      expect(Reporte.compararAvance(reintento, enviado), lessThan(0));
    });

    test('la descripción se recorta contando como Postgres (puntos de código)', () {
      const familia = '👨‍👩‍👧‍👦'; // 7 puntos de código, 1 letra visible
      final largo = familia * 200; // 200 «letras», 1400 puntos de código
      final c = recortarPuntosDeCodigo(largo);
      expect(c.runes.length, 1000);
      expect(utf8.decode(utf8.encode(c)), c, reason: 'sin pares sustitutos partidos');
      expect(recortarPuntosDeCodigo('corto'), 'corto');
    });

    test('la caja del servidor es la misma del CHECK y de crear_reporte', () {
      final sql = File('../backend/supabase/schema.sql').readAsStringSync();
      expect(sql, contains('check (lat between ${AreaServidor.latMin} and ${AreaServidor.latMax})'));
      expect(sql, contains('check (lon between ${AreaServidor.lonMin} and ${AreaServidor.lonMax})'));
      expect(sql, contains('v_lat not between ${AreaServidor.latMin} and ${AreaServidor.latMax}'));
      expect(AreaServidor.contiene(const LatLng(11.05, -74.85)), isTrue); // Mallorquín
      expect(AreaServidor.contiene(const LatLng(11.24, -74.2)), isFalse); // Santa Marta
      expect(AreaServidor.contiene(const LatLng(8.75, -75.88)), isFalse); // Montería
    });
  });
}

/// JPEG real de 16×8 hecho con Pillow: EXIF con Orientation=6, marca, modelo y GPS
/// (11°3'11.5" N, 74°51'3.4" O), un comentario y bytes pegados después del final.
const jpegConGps =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/4QC+RXhpZgAATU0AKgAAAAgABAEPAAIAAAAKAAAAPgEQAAIAAAAIAAAASAESAAMAAAABAAYAAIglAAQAAAABAAAAUAAAAABUZWxlZm9ub1gATW9kZWxvWQAABAABAAIAAAACTgAAAAACAAUAAAADAAAAhgADAAIAAAACVwAAAAAEAAUAAAADAAAAngAAAAAAAAALAAAAAQAAAAMAAAABAAAAFwAAAAIAAABKAAAAAQAAADMAAAABAAAAEQAAAAX//gAVSGVjaG8gZW4gZWwgbWFuZ2xhcv/bAEMAAwICAwICAwMDAwQDAwQFCAUFBAQFCgcHBggMCgwMCwoLCw0OEhANDhEOCwsQFhARExQVFRUMDxcYFhQYEhQVFP/bAEMBAwQEBQQFCQUFCRQNCw0UFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFP/AABEIAAgAEAMBIgACEQEDEQH/xAAfAAABBQEBAQEBAQAAAAAAAAAAAQIDBAUGBwgJCgv/xAC1EAACAQMDAgQDBQUEBAAAAX0BAgMABBEFEiExQQYTUWEHInEUMoGRoQgjQrHBFVLR8CQzYnKCCQoWFxgZGiUmJygpKjQ1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4eLj5OXm5+jp6vHy8/T19vf4+fr/xAAfAQADAQEBAQEBAQEBAAAAAAAAAQIDBAUGBwgJCgv/xAC1EQACAQIEBAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJIzNS8BVictEKFiQ04SXxFxgZGiYnKCkqNTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqCg4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2dri4+Tl5ufo6ery8/T19vf4+fr/2gAMAwEAAhEDEQA/APHPC37L/wBz/RP/AB2vYPC37L/3P9E/8dooryM34kzLX94fJ+HfF2b+5+9/r7z/2UJBU1VSQS1ERVNQVUVTLURFTC1GSU4=';
