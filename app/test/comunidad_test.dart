import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/comunidad/comunidad.dart';
import 'package:zanky/datos/tipos.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/comunidad/comunidad_inicio.dart';
import 'package:zanky/vistas/comunidad/piezas_comunidad.dart';

/// Respuestas REALES guardadas el 27-nov-2026 (GET de solo lectura):
/// `zanqui.sentralabs.co/alertas`, `/datos-abiertos/reportes.geojson` y el wp-json de la C.R.A.
String fixture(String nombre) => File('test/fixtures/comunidad/$nombre').readAsStringSync();

http.Response utf(String cuerpo, [int estado = 200]) =>
    http.Response.bytes(utf8.encode(cuerpo), estado, headers: {'content-type': 'application/json; charset=utf-8'});

/// Cliente que responde con las respuestas guardadas según la ruta.
MockClient clienteReal() => MockClient((req) async {
      final u = req.url.toString();
      if (u.endsWith('/alertas')) return utf(fixture('alertas.json'));
      if (u.contains('reportes.geojson')) return utf(fixture('reportes.geojson'));
      if (u.contains('crautonoma.gov.co')) return utf(fixture('noticias.json'));
      return http.Response('no', 404);
    });

final sinRed = MockClient((_) async => throw const SocketException('sin red'));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('alertas oficiales (/alertas)', () {
    test('lee la respuesta real y deja una alerta por lugar, la más alta primero', () {
      final r = ResultadoAlertas.deTexto(fixture('alertas.json'));
      expect(r.alertas.length, 7);
      expect(r.nivelMaximo, NivelAlerta.naranja);
      final grupos = r.porLugar;
      final lugares = grupos.map((g) => g.$1.lugar).toList();
      expect(lugares.toSet().length, lugares.length, reason: 'nunca dos niveles para el mismo sitio');
      expect(lugares.length, 3);
      expect(grupos.first.$1.nivel, NivelAlerta.naranja);
      // Mallorquín tiene 4 alertas: se ve la naranja y se cuentan 3 más.
      final m = grupos.firstWhere((g) => g.$1.lugar.contains('Mallorqu'));
      expect(m.$1.nivel, NivelAlerta.naranja);
      expect(m.$2, 3);
      expect(m.$1.punto, isNotNull);
      expect(m.$1.fuentesTexto, isNotEmpty);
    });

    test('las cifras de «Ahora» son las oficiales: viento, lluvia, ola y pleamar', () {
      final r = ResultadoAlertas.deTexto(fixture('alertas.json'));
      final titulos = r.ahora.map((c) => c.titulo).toList();
      expect(titulos, containsAll(['Viento ahora', 'Lluvia en 24 h', 'Ola más alta (3 días)', 'Próxima pleamar']));
      final ola = r.ahora.firstWhere((c) => c.titulo.startsWith('Ola'));
      final j = jsonDecode(fixture('alertas.json')) as Map;
      final esperada = ((j['ahora'] as Map)['ola_max_m'] as num).toStringAsFixed(1).replaceAll('.', ',');
      expect(ola.valor, startsWith(esperada.replaceFirst(RegExp(r',0$'), '')));
      expect(r.fuentes.map((f) => f.nombre), isNotEmpty);
    });

    test('una respuesta rota no se acepta', () {
      expect(() => ResultadoAlertas.deTexto('{"hola":1}'), throwsFormatException);
    });

    test('con red guarda; sin red devuelve lo guardado rotulado; sin copia, nada', () async {
      final vacia = await FuenteComunidad(cliente: sinRed).alertas();
      expect(vacia.origen, OrigenDato.nada);
      expect(vacia.datos.alertas, isEmpty);

      final conRed = await FuenteComunidad(cliente: clienteReal()).alertas();
      expect(conRed.origen, OrigenDato.red);
      expect(conRed.datos.alertas, hasLength(7));

      final sinSenal = await FuenteComunidad(cliente: sinRed).alertas();
      expect(sinSenal.origen, OrigenDato.cache);
      expect(sinSenal.sinSenal, isTrue);
      expect(sinSenal.cuando, isNotNull);
      expect(sinSenal.datos.alertas, hasLength(7));
    });

    test('un 500 tampoco borra la copia buena', () async {
      await FuenteComunidad(cliente: clienteReal()).alertas();
      final r = await FuenteComunidad(cliente: MockClient((_) async => http.Response('caído', 500))).alertas();
      expect(r.origen, OrigenDato.cache);
      expect(r.datos.alertas, hasLength(7));
    });
  });

  group('reportes de la comunidad (datos abiertos)', () {
    test('lee el GeoJSON real con su canal', () {
      final r = reportesDeGeoJson(fixture('reportes.geojson'));
      expect(r, isNotEmpty);
      final zk = r.firstWhere((x) => x.publico.id == 'ZK-16D1');
      expect(zk.canal, 'whatsapp');
      expect(zk.publico.tipo, TipoAmenaza.basuras);
      expect(zk.publico.punto.latitude, closeTo(11.028, 1e-6));
      expect(zk.publico.punto.longitude, closeTo(-74.862, 1e-6));
    });

    test('suma sin repetir por id', () {
      final r = reportesDeGeoJson(fixture('reportes.geojson')).map((x) => x.publico).toList();
      final suma = sumarSinDuplicar(r, r);
      expect(suma.length, r.length);
    });
  });

  group('noticias de la C.R.A.', () {
    test('lee la respuesta real: título limpio, fecha, párrafos y solo enlaces de la C.R.A.', () {
      final n = noticiasDeTexto(fixture('noticias.json'));
      expect(n, hasLength(2));
      expect(n.first.fecha.isAfter(n.last.fecha) || n.first.fecha == n.last.fecha, isTrue);
      for (final x in n) {
        expect(x.titulo, isNot(contains('<')));
        expect(x.titulo, isNot(contains('&#')));
        expect(x.parrafos, isNotEmpty);
        expect(x.enlace, startsWith('https://www.crautonoma.gov.co/'));
        if (x.imagen != null) expect(x.imagen, startsWith('https://www.crautonoma.gov.co/'));
        expect(x.fuente, contains('C.R.A.'));
      }
    });

    test('una imagen o enlace de otro sitio no pasa', () {
      final falsa = jsonEncode([
        {
          'id': 1,
          'date': '2026-11-20T10:00:00',
          'title': {'rendered': 'Siembra &amp; limpieza'},
          'excerpt': {'rendered': '<p>Resumen</p>'},
          'content': {'rendered': '<p>Uno</p><script>alert(1)</script><p>Dos</p>'},
          'link': 'https://otro.example/x',
          '_embedded': {
            'wp:featuredmedia': [
              {
                'media_details': {
                  'sizes': {'medium': {'source_url': 'https://otro.example/foto.jpg'}},
                },
              },
            ],
          },
        },
      ]);
      final n = noticiasDeTexto(falsa).single;
      expect(n.titulo, 'Siembra & limpieza');
      expect(n.parrafos, ['Uno', 'Dos']);
      expect(n.imagen, isNull);
      expect(n.enlace, 'https://www.crautonoma.gov.co/prensa/noticias');
    });

    test('sin red usa lo guardado', () async {
      final a = await FuenteComunidad(cliente: clienteReal()).noticias();
      expect(a.origen, OrigenDato.red);
      expect(a.datos, isNotEmpty);
      final b = await FuenteComunidad(cliente: sinRed).noticias();
      expect(b.origen, OrigenDato.cache);
      expect(b.datos.map((x) => x.id), a.datos.map((x) => x.id));
    });
  });

  group('inscripción a jornadas (con un doble: nunca se envía una inscripción real)', () {
    test('sin consentimiento no se manda nada', () async {
      var llamadas = 0;
      final f = FuenteComunidad(cliente: MockClient((_) async {
        llamadas++;
        return http.Response('{}', 201);
      }));
      final r = await f.inscribirse('j1', nombre: 'Ana', aceptaDatos: false);
      expect(r.ok, isFalse);
      expect(llamadas, 0);
    });

    test('manda el mismo contrato que la web y lee los inscritos', () async {
      late http.Request pedido;
      final f = FuenteComunidad(cliente: MockClient((req) async {
        pedido = req;
        return utf('{"ok":true,"inscritos":12}', 201);
      }));
      final r = await f.inscribirse('siembra 1', nombre: '  Ana  ', telefono: '3001234567', aceptaDatos: true, aceptaWhatsapp: true);
      expect(r.ok, isTrue);
      expect(r.inscritos, 12);
      expect(pedido.method, 'POST');
      expect(pedido.url.toString(), 'https://zanqui.sentralabs.co/api/jornadas/siembra%201/inscripciones');
      final cuerpo = jsonDecode(pedido.body) as Map;
      expect(cuerpo, {'nombre': 'Ana', 'telefono': '3001234567', 'acepta_datos': true, 'acepta_whatsapp': true});
    });

    test('sin cupos o sin red lo dice en palabras', () async {
      final llena = await FuenteComunidad(cliente: MockClient((_) async => utf('{}', 409)))
          .inscribirse('j', nombre: 'Ana', aceptaDatos: true);
      expect(llena.ok, isFalse);
      expect(llena.mensaje, contains('cupos'));
      final caida = await FuenteComunidad(cliente: sinRed).inscribirse('j', nombre: 'Ana', aceptaDatos: true);
      expect(caida.mensaje, contains('conexión'));
    });
  });

  group('vistas', () {
    Widget app(Widget hijo, {double ancho = 390}) => MaterialApp(
          theme: temaZanky(),
          home: MediaQuery(
            data: MediaQueryData(size: Size(ancho, 844)),
            child: Scaffold(body: SingleChildScrollView(child: hijo)),
          ),
        );

    testWidgets('Inicio muestra la alerta oficial más alta, su recomendación y las cifras oficiales', (t) async {
      await t.pumpWidget(app(ComunidadInicio(
        fuente: FuenteComunidad(cliente: clienteReal()),
        respaldo: const Text('RESPALDO'),
      )));
      await t.pumpAndSettle();
      expect(find.text('ALERTAS OFICIALES'), findsOneWidget);
      expect(find.text('Alerta naranja'), findsWidgets);
      expect(find.textContaining('Qué hacer:'), findsOneWidget);
      expect(find.textContaining('lugares más'), findsOneWidget);
      expect(find.text('Viento ahora'), findsNothing); // va con el ícono delante
      expect(find.textContaining('Viento ahora'), findsOneWidget);
      expect(find.text('RESPALDO'), findsNothing, reason: 'con alertas oficiales no se muestran las reglas locales');
      expect(find.text('DESDE LA C.R.A.'), findsOneWidget);
    });

    testWidgets('sin red y sin copia: solo entonces el respaldo local, rotulado', (t) async {
      await t.pumpWidget(app(ComunidadInicio(fuente: FuenteComunidad(cliente: sinRed), respaldo: const Text('RESPALDO'))));
      await t.pumpAndSettle();
      expect(find.text('RESPALDO'), findsOneWidget);
      expect(find.textContaining('No son alertas oficiales'), findsOneWidget);
      expect(find.text('ALERTAS OFICIALES'), findsNothing);
    });

    testWidgets('la tarjeta de alerta cabe a 360 px sin desbordes', (t) async {
      final grupos = ResultadoAlertas.deTexto(fixture('alertas.json')).porLugar;
      for (final ancho in [360.0, 768.0]) {
        await t.pumpWidget(app(
          Padding(
            padding: const EdgeInsets.all(20),
            child: TarjetaAlertaInicio(grupos: grupos, alTocar: () {}, generado: DateTime.now()),
          ),
          ancho: ancho,
        ));
        await t.pump();
        expect(t.takeException(), isNull);
      }
      expect(find.byType(EtiquetaNivel), findsOneWidget);
    });
  });
}
