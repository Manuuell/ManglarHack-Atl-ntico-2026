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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/vistas/admin/contenido/seccion_contenido_admin.dart';
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

  group('Filas de jornadas con gestos', () {
    final j = JornadaPanel(id: 'j-1', titulo: 'Siembra en Bocana', fecha: DateTime(2026, 12, 5, 7), lugar: 'Kiosco', cupos: 30);

    Future<ControladorContenidoPanel> montar(WidgetTester t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      final c = ControladorContenidoPanel();
      await c.cargar();
      await c.guardar(SeccionContenido.jornadas, c.contenido.copiar(jornadas: [j]), 'prueba');
      await t.pumpWidget(MaterialApp(
        theme: temaCra(),
        home: Scaffold(body: SeccionContenidoAdmin(controlador: c, noticias: () async => const [])),
      ));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Jornadas').first);
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }
      return c;
    }

    Future<void> cerrar(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 10));
    }

    testWidgets('390: sin botones sueltos; mantener presionado da vista previa y acciones', (t) async {
      await montar(t);
      expect(find.widgetWithText(TextButton, 'Editar'), findsNothing, reason: 'en el teléfono son gestos');
      await t.longPress(find.text('Siembra en Bocana'));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('jornada-vista-previa')), findsOneWidget);
      expect(find.byKey(const Key('menu-Editar')), findsOneWidget);
      expect(find.byKey(const Key('menu-Cerrar')), findsOneWidget);
      expect(find.byKey(const Key('menu-Quitar')), findsOneWidget);
      await cerrar(t);
    });

    testWidgets('quitar desde el menú: se va al momento y «Deshacer» la devuelve', (t) async {
      final c = await montar(t);
      await t.longPress(find.text('Siembra en Bocana'));
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.byKey(const Key('menu-Quitar')));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }
      expect(c.contenido.jornadas, isEmpty);
      expect(find.text('Deshacer'), findsOneWidget);
      await t.tap(find.text('Deshacer'));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }
      expect(c.contenido.jornadas.single.id, 'j-1');
      await cerrar(t);
    });

    testWidgets('nueva jornada: tocar el mapa pone el pin y la jornada guarda el punto', (t) async {
      final c = await montar(t);
      await t.tap(find.text('Nueva jornada'));
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }
      final campos = find.byType(TextField);
      await t.enterText(campos.at(0), 'Limpieza del caño');
      await t.enterText(campos.at(1), 'Muelle de Las Flores');
      await t.pump();
      final mapa = find.byKey(const Key('mapa-punto-jornada'));
      await t.ensureVisible(mapa);
      await t.pump(const Duration(milliseconds: 300));
      await t.tapAt(t.getCenter(mapa));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Quitar el punto'), findsOneWidget);
      await t.ensureVisible(find.text('Crear jornada'));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.text('Crear jornada'));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }
      final nueva = c.contenido.jornadas.firstWhere((x) => x.titulo == 'Limpieza del caño');
      expect(nueva.tienePunto, isTrue);
      expect(nueva.lat!, closeTo(10.99, 0.2));
      await cerrar(t);
    });

    testWidgets('deslizar a la derecha revela «Cerrar»', (t) async {
      await montar(t);
      await t.drag(find.text('Siembra en Bocana'), const Offset(160, 0));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('accion-Cerrar')), findsOneWidget);
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
