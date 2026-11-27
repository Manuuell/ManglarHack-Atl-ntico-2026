import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/experiencia/entrada_evento.dart';
import 'package:zanky/datos/experiencia/ia_zanky.dart';
import 'package:zanky/datos/experiencia/jornada.dart';
import 'package:zanky/datos/experiencia/participacion.dart';
import 'package:zanky/datos/experiencia/preguntas_zanky.dart';
import 'package:zanky/datos/experiencia/trivia.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('entrada del evento', () {
    String? c(String url) => leerEntradaEvento(Uri.parse(url))?.codigo;

    test('lee las variantes del enlace', () {
      expect(c('https://mimanglar.sentralabs.co/app/?evento=jornada-1'), 'jornada-1');
      expect(c('https://mimanglar.sentralabs.co/app/?jornada=jornada-2'), 'jornada-2');
      expect(c('https://mimanglar.sentralabs.co/app/#/?evento=jornada-3'), 'jornada-3');
      expect(c('https://mimanglar.sentralabs.co/app/#/evento/jornada-4'), 'jornada-4');
      expect(c('https://mimanglar.sentralabs.co/app/evento/feria_x'), 'feria_x');
      expect(c('https://x.co/app/?zona=tubara&evento=Col-7&origen=qr'), 'col-7');
    });

    test('rechaza códigos inválidos y enlaces sin evento', () {
      expect(c('https://x.co/app/'), isNull);
      expect(c('https://x.co/app/?evento='), isNull);
      expect(c('https://x.co/app/?evento=a%20b'), isNull);
      expect(c('https://x.co/app/?evento=<script>'), isNull);
      expect(c('https://x.co/app/?evento=${'a' * 65}'), isNull);
      expect(c('https://x.co/app/?evento=${'a' * 64}'), 'a' * 64);
      expect(c('https://x.co/app/#/evento/%E0%A4%A'), isNull);
      expect(c('file:///C:/algo'), isNull);
    });

    test('registrar no pisa la primera entrada y el enlace sale codificado', () {
      entradaEvento.value = null;
      registrarEntradaEvento(Uri.parse('https://x.co/app/?evento=uno'));
      registrarEntradaEvento(Uri.parse('https://x.co/app/?evento=dos'));
      expect(entradaEvento.value?.codigo, 'uno');
      entradaEvento.value = null;
      expect(enlaceEvento('jornada-1'), 'https://mimanglar.sentralabs.co/app/?evento=jornada-1');
      expect(c(enlaceEvento('jornada-1')), 'jornada-1');
    });
  });

  group('jornadas', () {
    test('el asset de respaldo trae las 4 jornadas reales, sin ejemplo y con foto', () async {
      final lista = await FuenteJornadas(cliente: MockClient((_) async => throw Exception('sin red'))).cargar();
      expect(lista.length, 4);
      expect(lista.any((j) => j.esEjemplo || j.cancelada), isFalse);
      expect(lista.every((j) => j.imagen != null), isTrue);
      expect(lista.map((j) => j.id), contains('siembra-de-mangle-rojo-en-el-estuario-de-3cd559'));
      final s = lista.firstWhere((j) => j.tipo == 'siembra');
      expect(s.tipoLegible, 'Siembra');
      expect(fechaLarga(s.inicio), 'domingo 6 de diciembre');
      expect(horaCorta(s.inicio), '7:00 a. m.');
      expect(horaCorta(s.fin), '10:30 a. m.');
    });

    test('la red manda, queda en caché y la caché sirve sin red', () async {
      final cuerpo = jsonEncode({
        'jornadas': [
          {
            'id': 'real-1',
            'accion_id': 'a',
            'titulo': 'Siembra real',
            'tipo': 'siembra',
            'inicio': '2026-12-20T13:00:00Z',
            'fin': '2026-12-20T16:00:00Z',
            'punto_encuentro': 'Muelle',
            'lat': 1,
            'lon': 2,
            'cupos': 10,
            'inscritos': 3,
            'que_llevar': ['Agua'],
            'descripcion': 'Convocatoria confirmada.',
          },
        ],
      });
      final ok = FuenteJornadas(cliente: MockClient((_) async => http.Response.bytes(utf8.encode(cuerpo), 200)));
      final e = await ok.evento('real-1');
      expect(e.generico, isFalse);
      expect(e.titulo, 'Siembra real');
      expect(e.jornada!.esEjemplo, isFalse);
      expect(e.jornada!.cuposLibres, 7);
      // Sin red: sale de la caché.
      final sinRed = FuenteJornadas(cliente: MockClient((_) async => http.Response('x', 500)));
      expect((await sinRed.cargar()).single.id, 'real-1');
    });

    test('código desconocido da el evento genérico y nunca lanza', () async {
      final f = FuenteJornadas(cliente: MockClient((_) async => throw Exception('x')));
      final e = await f.evento('no-existe');
      expect(e.generico, isTrue);
      expect(e.titulo, 'Evento con Zanky');
      expect(e.codigo, 'no-existe');
      final conJson = FuenteJornadas(cliente: MockClient((_) async => http.Response('{no es json', 200)));
      expect((await conJson.evento('siembra-de-mangle-rojo-en-el-estuario-de-3cd559')).generico, isFalse); // cae al respaldo
    });

    test('una fila rota no tumba las demás', () async {
      final cuerpo = jsonEncode([
        {'id': 'rota'},
        {
          'id': 'buena',
          'accion_id': 'a',
          'titulo': 'Buena',
          'tipo': 'otro_tipo',
          'inicio': '2026-12-20T13:00:00Z',
          'fin': '2026-12-20T16:00:00Z',
          'punto_encuentro': 'P',
          'lat': 1,
          'lon': 2,
          'cupos': 0,
          'inscritos': 0,
          'que_llevar': [],
          'descripcion': '',
        },
      ]);
      final f = FuenteJornadas(cliente: MockClient((_) async => http.Response(cuerpo, 200)));
      final l = await f.cargar();
      expect(l.map((j) => j.id), ['buena']);
      expect(l.single.tipoLegible, 'Otro tipo');
      expect(l.single.llena, isFalse);
    });
  });

  group('jornadas desde la API', () {
    const idReal = 'siembra-de-mangle-rojo-en-el-estuario-de-3cd559';
    final listaJson = File('test/fixtures/api_jornadas.json').readAsStringSync();
    final unaJson = File('test/fixtures/api_jornada_siembra.json').readAsStringSync();
    http.Response ok(String t) => http.Response.bytes(utf8.encode(t), 200);

    MockClient servidor({bool cae = false, String? aviso, List<Uri>? vistas}) => MockClient((r) async {
          vistas?.add(r.url);
          if (cae) throw Exception('sin red');
          final p = r.url.path;
          if (p == '/api/jornadas/$idReal') return ok(unaJson);
          if (p == '/api/jornadas') {
            if (aviso == null) return ok(listaJson);
            final m = jsonDecode(listaJson) as Map;
            return ok(jsonEncode({...m, 'aviso': aviso}));
          }
          if (p.startsWith('/api/jornadas/')) return http.Response('{"error":"no_existe"}', 404);
          return http.Response('no', 404);
        });

    test('un id real presente en la API abre su jornada, con foto', () async {
      final vistas = <Uri>[];
      final e = await FuenteJornadas(cliente: servidor(vistas: vistas)).evento(idReal);
      expect(e.generico, isFalse);
      expect(e.jornada!.titulo, startsWith('Siembra de mangle rojo'));
      expect(e.jornada!.imagen.toString(), contains('upload.wikimedia.org'));
      expect(e.jornada!.esEjemplo, isFalse);
      expect(vistas.map((u) => u.path), contains('/api/jornadas/$idReal'));
    });

    test('la API cae pero hay caché: sale de la caché y sigue siendo real', () async {
      await FuenteJornadas(cliente: servidor()).evento(idReal); // llena la caché
      final f = FuenteJornadas(cliente: servidor(cae: true));
      expect((await f.eventoLocal(idReal)).generico, isFalse);
      final e = await f.evento(idReal);
      expect(e.generico, isFalse);
      expect(e.jornada!.id, idReal);
      expect((await f.cargar()).length, 4);
    });

    test('sin red y sin caché cae al respaldo empaquetado', () async {
      SharedPreferences.setMockInitialValues({});
      final f = FuenteJornadas(cliente: servidor(cae: true));
      final e = await f.evento(idReal);
      expect(e.generico, isFalse);
      expect(e.jornada!.imagen, isNotNull);
    });

    test('un id desconocido da el evento genérico', () async {
      final e = await FuenteJornadas(cliente: servidor()).evento('id-que-no-existe');
      expect(e.generico, isTrue);
      expect(e.codigo, 'id-que-no-existe');
      expect((await FuenteJornadas(cliente: servidor(cae: true)).evento('otro-raro')).generico, isTrue);
    });

    test('si la API de una jornada falla se usa la lista, y el aviso viaja', () async {
      final f = FuenteJornadas(cliente: MockClient((r) async {
        if (r.url.path == '/api/jornadas') {
          final m = jsonDecode(listaJson) as Map;
          return ok(jsonEncode({...m, 'aviso': 'Lluvia: llevar capa.'}));
        }
        return http.Response('x', 500);
      }));
      final e = await f.evento(idReal);
      expect(e.generico, isFalse);
      expect(e.aviso, 'Lluvia: llevar capa.');
    });

    test('ejemplo y canceladas se reconocen', () {
      Map<String, dynamic> base() => {
            ...(jsonDecode(unaJson) as Map).cast<String, dynamic>(),
          };
      final ej = Jornada.fromJson({...base(), 'ejemplo': true});
      expect(ej.esEjemplo, isTrue);
      final ca = Jornada.fromJson({...base(), 'estado': 'cancelada'});
      expect(ca.cancelada, isTrue);
      expect(Jornada.fromJson(base()).cancelada, isFalse);
      expect(Jornada.fromJson({...base(), 'imagen_url': 'javascript:alert(1)'}).imagen, isNull);
    });
  });

  group('participación y puntos', () {
    const evento = EventoZanky(codigo: 'jornada-1', titulo: 'Siembra');

    test('asistencia suma 40 una sola vez y se guarda', () async {
      final a = AlmacenParticipacion();
      expect(await a.registrarAsistencia(evento: evento, nombre: ' Ana ', grupo: ' '), isTrue);
      expect(await a.registrarAsistencia(evento: evento, nombre: 'Ana'), isFalse);
      expect(a.puntos, 40);
      expect(a.asistencia('jornada-1')!.nombre, 'Ana');
      expect(a.asistencia('jornada-1')!.grupo, isNull);
      final otro = AlmacenParticipacion();
      await otro.cargar();
      expect(otro.asistio('jornada-1'), isTrue);
      expect(otro.puntos, 40);
    });

    test('el reto solo suma si mejora', () async {
      final a = AlmacenParticipacion();
      expect(await a.guardarReto('x', 3), 30);
      expect(await a.guardarReto('x', 2), 0);
      expect(await a.guardarReto('x', 3), 0);
      expect(await a.guardarReto('x', 5), 20);
      expect(a.mejorReto('x'), 5);
      expect(a.mejorReto('otro'), 0);
      expect(a.puntos, 50);
      expect(a.eventos, 1);
      final b = AlmacenParticipacion();
      await b.cargar();
      expect(b.mejorReto('x'), 5);
    });

    test('datos ilegibles no tumban nada', () async {
      SharedPreferences.setMockInitialValues({'participacion.v1': '{roto'});
      final a = AlmacenParticipacion();
      await a.cargar();
      expect(a.puntos, 0);
    });
  });

  group('preguntas de Zanky', () {
    test('hay 25 o más, cada una con fuente y respuesta', () {
      expect(preguntasFrecuentes.length, greaterThanOrEqualTo(25));
      final ids = <String>{};
      for (final p in preguntasFrecuentes) {
        expect(ids.add(p.id), isTrue, reason: 'id repetido ${p.id}');
        expect(p.fuente, isNotEmpty);
        expect(p.respuesta.length, greaterThan(40));
      }
      for (final s in sugerenciasIniciales) {
        expect(responderSinConexion(s).encontrada, isTrue, reason: s);
      }
    });

    test('toda pregunta del banco se responde a sí misma', () {
      for (final p in preguntasFrecuentes) {
        final r = responderSinConexion(p.pregunta);
        expect(r.texto, p.respuesta, reason: p.pregunta);
        expect(r.fuente, p.fuente);
      }
    });

    test('entiende formas libres, con o sin tildes', () {
      String? t(String q) => responderSinConexion(q).texto;
      expect(t('que es el carbono azul'), contains('ecosistemas costeros'));
      expect(t('QUÉ ES CARBONO AZUL???'), contains('ecosistemas costeros'));
      expect(t('como denuncio una tala'), isNotNull);
      expect(t('puedo reportar anonimo'), contains('anónimo'));
      expect(t('que dice la ley 1581'), contains('datos personales'));
      expect(t('cuales son las especies'), contains('Rhizophora mangle'));
      expect(t('que pasa con mi reporte'), contains('CRA'));
      expect(t('como gano puntos'), contains('40 puntos'));
    });

    test('si no sabe, lo dice y sugiere', () {
      final r = responderSinConexion('¿Cuánto cuesta un iPhone?');
      expect(r.encontrada, isFalse);
      expect(r.fuente, isNull);
      expect(r.sugerencias, isNotEmpty);
      expect(r.texto, contains('no inventarte'));
      expect(responderSinConexion('   ').encontrada, isFalse);
    });

    test('sobre el evento responde con los datos de la jornada', () async {
      final ej = jsonDecode(File('test/fixtures/jornadas_ejemplo.json').readAsStringSync()) as Map;
      final j = Jornada.fromJson((ej['jornadas'] as List).first as Map);
      final e = EventoZanky(codigo: j.id, titulo: j.titulo, jornada: j);
      final r = responderSinConexion('¿Cuándo es la jornada?', evento: e);
      expect(r.texto, contains('domingo 29 de noviembre'));
      expect(r.texto, contains('Datos de ejemplo'));
      expect(responderSinConexion('¿Qué debo llevar?', evento: e).texto, contains('guantes de trabajo'));
      // Sin jornada (evento genérico) cae a la respuesta general.
      expect(responderSinConexion('¿Qué debo llevar?', evento: EventoZanky.generico('x')).texto, contains('Agua potable'));
    });

    test('la IA no está conectada sin servidor y no hace red', () async {
      final ia = IaZanky(cliente: MockClient((_) async => throw StateError('no debía llamar')));
      expect(ia.conectada, isFalse);
      expect(await ia.preguntar('hola'), isNull);
    });
  });

  group('trivia', () {
    test('el banco tiene 14 o más con una sola correcta y explicación', () {
      expect(bancoRetos.length, greaterThanOrEqualTo(14));
      for (final p in bancoRetos) {
        expect(p.opciones.toSet().length, p.opciones.length, reason: p.id);
        expect(p.correcta, inInclusiveRange(0, p.opciones.length - 1));
        expect(p.explicacion, isNotEmpty);
        expect(p.fuente, isNotEmpty);
      }
    });

    test('es determinista por código, distinto entre códigos y conserva la correcta', () {
      final a = retoPara('jornada-1');
      final b = retoPara('jornada-1');
      expect(a.map((p) => p.id), b.map((p) => p.id));
      expect(a.map((p) => p.opciones.join('|')), b.map((p) => p.opciones.join('|')));
      expect(a.length, 5);
      expect(a.map((p) => p.id).toSet().length, 5);
      final otros = {for (final c in ['a', 'b', 'c', 'd', 'e', 'f']) retoPara(c).map((p) => p.id).join(',')};
      expect(otros.length, greaterThan(1));
      for (final p in a) {
        final original = bancoRetos.firstWhere((x) => x.id == p.id);
        expect(p.respuestaCorrecta, original.respuestaCorrecta);
        expect(p.opciones.toSet(), original.opciones.toSet());
      }
      expect(retoPara('x', cuantas: 99).length, bancoRetos.length);
    });

    test('el asset del reto no sufre al cargar (sanidad de rootBundle)', () async {
      expect(await rootBundle.loadString('assets/datos/jornadas_respaldo.json'), contains('siembra-de-mangle-rojo-en-el-estuario-de-3cd559'));
    });
  });

  test('el evento sale de lo local aunque la red nunca responda (no se queda en blanco esperando)', () async {
    final colgada = MockClient((_) => Completer<http.Response>().future);   // red que nunca contesta
    final fuente = FuenteJornadas(cliente: colgada);
    final e = await fuente.eventoLocal('siembra-de-mangle-rojo-en-el-estuario-de-3cd559').timeout(const Duration(seconds: 2));
    expect(e.jornada, isNotNull, reason: 'el respaldo trae la siembra real');
    expect(e.titulo, isNot(EventoZanky.tituloGenerico));
  });
}
