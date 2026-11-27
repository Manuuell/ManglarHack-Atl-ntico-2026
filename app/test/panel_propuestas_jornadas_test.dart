import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:zanky/datos/admin/contenido_panel.dart';
import 'package:zanky/datos/admin/contenido_publico.dart';
import 'package:zanky/datos/comunidad/comunidad.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/nucleo/identidad.dart';
import 'package:zanky/vistas/admin/propuestas_admin.dart';

PropuestaWhatsapp _propuesta(String codigo, {String tipo = 'siembra', String proponente = 'comunidad'}) => PropuestaWhatsapp(
      id: 'id-$codigo',
      codigo: codigo,
      tipo: tipo,
      tipoAccion: 'siembra',
      proponente: proponente,
      tipoActor: 'comunidad',
      descripcion: 'Sembrar 200 plántulas de mangle rojo en la orilla norte.',
      punto: const LatLng(10.98, -74.93),
      zona: 'mallorquin',
      zonaNombre: 'Ciénaga de Mallorquín',
      dentroManglar: true,
      creadaEn: DateTime(2026, 11, 26, 9, 30),
    );

void main() {
  group('Propuestas por WhatsApp en el panel', () {
    Future<void> montar(WidgetTester t, CargarPropuestas cargar, {Size tam = const Size(390, 844)}) async {
      t.view.physicalSize = tam;
      t.view.devicePixelRatio = 1;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      await t.pumpWidget(MaterialApp(theme: temaCra(), home: Scaffold(body: PropuestasAdmin(cargar: cargar))));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> cerrar(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 6));
    }

    for (final tam in const [Size(360, 740), Size(768, 1024), Size(1280, 800)]) {
      testWidgets('lista: quién propone, qué, zona y fecha (${tam.width.toInt()} px)', (t) async {
        await montar(t, () async => Lote([_propuesta('PROP-1A2B'), _propuesta('PROP-9Z', tipo: 'limpieza', proponente: 'empresa')],
            OrigenDato.red, DateTime.now()), tam: tam);
        expect(find.text('Siembra propuesta por WhatsApp · PROP-1A2B'), findsOneWidget);
        expect(find.text('Limpieza propuesta por WhatsApp · PROP-9Z'), findsOneWidget);
        expect(find.text('Propone: Comunidad'), findsOneWidget);
        expect(find.text('Propone: Empresa'), findsOneWidget);
        expect(find.text('Ciénaga de Mallorquín'), findsNWidgets(2));
        expect(find.text('2 propuestas'), findsOneWidget);
        expect(find.byKey(const Key('propuestas-sin-senal')), findsNothing);
        expect(t.takeException(), isNull);
        await cerrar(t);
      });
    }

    testWidgets('mantener presionado abre la vista previa con la propuesta entera', (t) async {
      await montar(t, () async => Lote([_propuesta('PROP-1A2B')], OrigenDato.red, DateTime.now()));
      await t.longPress(find.text('Siembra propuesta por WhatsApp · PROP-1A2B'));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('propuesta-vista-previa')), findsOneWidget);
      expect(find.byKey(const Key('menu-Copiar código')), findsOneWidget);
      expect(find.byKey(const Key('menu-Ver completa')), findsOneWidget);
      await cerrar(t);
    });

    testWidgets('vacío: Zanky dice que aún no hay propuestas', (t) async {
      await montar(t, () async => Lote(const <PropuestaWhatsapp>[], OrigenDato.red, DateTime.now()));
      expect(find.text('Aún no hay propuestas por WhatsApp'), findsOneWidget);
      await cerrar(t);
    });

    testWidgets('sin señal: muestra la copia y lo dice', (t) async {
      await montar(t, () async => Lote([_propuesta('PROP-1A2B')], OrigenDato.cache, DateTime(2026, 11, 26, 8)));
      expect(find.byKey(const Key('propuestas-sin-senal')), findsOneWidget);
      expect(find.text('Siembra propuesta por WhatsApp · PROP-1A2B'), findsOneWidget);
      await cerrar(t);
    });

    testWidgets('sin señal y sin copia: error con Reintentar, que vuelve a pedir', (t) async {
      var pedidas = 0;
      await montar(t, () async {
        pedidas++;
        return pedidas == 1
            ? Lote(const <PropuestaWhatsapp>[], OrigenDato.nada, null)
            : Lote([_propuesta('PROP-1A2B')], OrigenDato.red, DateTime.now());
      });
      expect(find.text('Reintentar'), findsOneWidget);
      await t.tap(find.text('Reintentar'));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(pedidas, 2);
      expect(find.text('Siembra propuesta por WhatsApp · PROP-1A2B'), findsOneWidget);
      await cerrar(t);
    });
  });

  group('Jornadas del panel: punto en el mapa e inscripción', () {
    final base = JornadaPanel(id: 'j-1', titulo: 'Siembra en Bocana', fecha: DateTime(2026, 12, 5, 7), lugar: 'Kiosco', cupos: 30);

    test('el punto viaja en el JSON y vuelve; uno fuera de rango se descarta', () {
      final con = base.copiar(lat: 10.99, lon: -74.95);
      final vuelta = JornadaPanel.deJson(jsonDecode(jsonEncode(con.aJson())));
      expect(vuelta!.lat, 10.99);
      expect(vuelta.lon, -74.95);
      expect(base.aJson().containsKey('lat'), isFalse, reason: 'las viejas guardan el mismo JSON');
      expect(JornadaPanel.deJson({...base.aJson(), 'lat': 120, 'lon': -74.9})!.tienePunto, isFalse);
      final enCartelera = jornadasDelPanel(ContenidoPanel.fabrica.copiar(jornadas: [con])).single;
      expect(enCartelera.lat, 10.99);
      expect(enCartelera.lon, -74.95);
    });

    test('inscribirse va a inscripciones_panel con el consentimiento, sin el prefijo', () async {
      late http.Request pedido;
      final s = Servidor(
        base: 'https://x.supabase.co',
        anon: 'anon-de-prueba',
        cliente: MockClient((r) async {
          pedido = r;
          return http.Response('', 201);
        }),
      );
      final r = await inscribirseEnJornadaDelPanel('panel-j-1',
          nombre: ' Ana ', telefono: '300 123 4567', aceptaDatos: true, aceptaWhatsapp: true, servidor: s);
      expect(r.ok, isTrue);
      expect(pedido.method, 'POST');
      expect(pedido.url.path, '/rest/v1/inscripciones_panel');
      final cuerpo = jsonDecode(pedido.body) as Map;
      expect(cuerpo, {'jornada_id': 'j-1', 'nombre': 'Ana', 'telefono': '3001234567', 'acepta_datos': true, 'acepta_whatsapp': true});
    });

    test('sin consentimiento no se envía; 404 (sin tabla o jornada cerrada) y 409 se explican', () async {
      var llamadas = 0;
      Servidor con(int estado) => Servidor(
          base: 'https://x.supabase.co',
          anon: 'a',
          cliente: MockClient((_) async {
            llamadas++;
            return http.Response('{}', estado);
          }));
      final sin = await inscribirseEnJornadaDelPanel('panel-j-1', nombre: 'Ana', aceptaDatos: false, servidor: con(201));
      expect(sin.ok, isFalse);
      expect(llamadas, 0);
      final r404 = await inscribirseEnJornadaDelPanel('panel-j-1', nombre: 'Ana', aceptaDatos: true, servidor: con(404));
      expect(r404.mensaje, contains('punto de encuentro'));
      final r409 = await inscribirseEnJornadaDelPanel('panel-j-1', nombre: 'Ana', aceptaDatos: true, servidor: con(409));
      expect(r409.mensaje, contains('Ya estás inscrito'));
    });
  });
}
