import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zanky/datos/comunidad/comunidad.dart';
import 'package:zanky/datos/comunidad/feed.dart';
import 'package:zanky/datos/experiencia/jornada.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/datos/tipos.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/comunidad/feed_y_eventos.dart';

List<Jornada> jornadasDe(String ruta) {
  final j = jsonDecode(File(ruta).readAsStringSync());
  return [for (final f in (j is Map ? j['jornadas'] : j) as List) Jornada.fromJson(f as Map)];
}

void main() {
  final textoSim = File('assets/datos/reportes_simulados.json').readAsStringSync();
  final ahora = DateTime(2026, 11, 27, 15);
  final todas = jornadasDe('test/fixtures/api_jornadas.json');

  group('datos simulados', () {
    test('25 reportes en las 4 zonas reales, varios tipos y estados, recientes y todos rotulados', () {
      final s = simuladosDeTexto(textoSim, ahora: ahora);
      expect(s, hasLength(25));
      expect(s.every((r) => r.simulado), isTrue);
      expect(s.map((r) => r.publico.zona).toSet(), {'mallorquin', 'piojo', 'tubara', 'juan_de_acosta'});
      expect(s.map((r) => r.publico.tipo).toSet().length, greaterThanOrEqualTo(5));
      expect(s.map((r) => r.publico.estado).toSet().length, greaterThanOrEqualTo(4));
      expect(s.any((r) => r.porWhatsapp), isTrue);
      for (final r in s) {
        expect(ahora.difference(r.publico.capturadoEn).inDays, lessThan(4));
        expect(enFranjaManglar(r.publico.punto.latitude, r.publico.punto.longitude), isTrue, reason: r.publico.id);
        expect(r.publico.id, startsWith('SIM-'));
      }
    });

    test('el feed deja fuera los de prueba y los descartados', () {
      ReportePublico r(String id, EstadoReporte e) => ReportePublico(
          id: id, tipo: TipoAmenaza.otro, punto: const LatLng(11, -74.9), prioridad: 3, estado: e, capturadoEn: ahora, zona: 'tubara');
      final feed = unirFeed(supabase: [r('a', EstadoReporte.recibido), r('b', EstadoReporte.descartado), r('ZK-0A6B', EstadoReporte.recibido)]);
      expect(feed.map((x) => x.publico.id), ['a']);
    });

    test('no se suman a las cifras reales y no pisan a un real', () {
      final real = ReportePublico(
        id: 'ZK-1',
        tipo: TipoAmenaza.tala,
        punto: const LatLng(11.03, -74.87),
        prioridad: 1,
        estado: EstadoReporte.recibido,
        capturadoEn: ahora,
        zona: 'mallorquin',
      );
      final feed = unirFeed(
        abiertos: [ReporteComunidad(real, 'whatsapp')],
        supabase: [real],
        simulados: simuladosDeTexto(textoSim, ahora: ahora),
      );
      expect(feed, hasLength(26));
      expect(contarReales(feed), 1);
      expect(feed.where((r) => r.publico.id == 'ZK-1').single.porWhatsapp, isTrue);
      for (var i = 1; i < feed.length; i++) {
        expect(feed[i - 1].publico.capturadoEn.isBefore(feed[i].publico.capturadoEn), isFalse);
      }
    });
  });

  group('cartelera de eventos', () {
    final antes = DateTime.utc(2026, 11, 27);

    test('con 2 del servidor se completa con el respaldo rotulado, sin repetir', () {
      final servidor = todas.take(2).toList();
      final c = completarCartelera(servidor, todas, ahora: antes);
      expect(c.where((e) => !e.respaldo), hasLength(2));
      expect(c.where((e) => e.respaldo), isNotEmpty);
      expect(c.map((e) => e.jornada.id).toSet().length, c.length);
      expect(c.first.jornada.inicio.isAfter(c.last.jornada.inicio), isFalse);
    });

    test('sin cupo definido: «sin límite de cupos», nunca bloquea', () {
      final j = Jornada.fromJson({...todas.first.aJson(), 'cupos': 0, 'inscritos': 1});
      expect(textoCupos(j), '1 inscrito · sin límite de cupos');
      final llena = Jornada.fromJson({...todas.first.aJson(), 'cupos': 2, 'inscritos': 2});
      expect(textoCupos(llena), contains('igual puedes apuntarte'));
    });

    test('con suficientes del servidor no se agrega respaldo; las pasadas no salen', () {
      expect(completarCartelera(todas, todas, ahora: antes).any((e) => e.respaldo), isFalse);
      expect(completarCartelera(todas, todas, ahora: DateTime.utc(2027)), isEmpty);
    });
  });

  group('vistas', () {
    Widget app(Widget hijo, double ancho) => MaterialApp(
          theme: temaZanky(),
          home: MediaQuery(
            data: MediaQueryData(size: Size(ancho, 844)),
            child: Scaffold(body: SingleChildScrollView(child: hijo)),
          ),
        );

    for (final ancho in [390.0, 1280.0]) {
      testWidgets('feed a $ancho px: cifra real aparte y «Simulado» en cada simulado', (t) async {
        final feed = unirFeed(simulados: simuladosDeTexto(textoSim));
        await t.pumpWidget(app(SeccionFeed(feed: feed, origen: OrigenDato.red, cuando: null, maximo: 5), ancho));
        await t.pump();
        expect(find.text('Aún sin reportes reales recientes'), findsOneWidget);
        expect(find.text('+ 25 simulados, no cuentan'), findsOneWidget);
        expect(find.text('Simulado'), findsNWidgets(5));
        expect(t.takeException(), isNull);
      });

      testWidgets('evento a $ancho px con foto, fecha, lugar, cupos y rótulo de respaldo', (t) async {
        final e = EventoCartelera(todas.first, respaldo: true);
        await t.pumpWidget(app(SeccionEventos(eventos: [e, EventoCartelera(todas[1])], alInscribirse: (_) {}), ancho));
        await t.pump();
        expect(find.text('Respaldo · por confirmar'), findsOneWidget);
        expect(find.textContaining('inscrit'), findsNWidgets(2));
        expect(find.text('Inscribirme'), findsWidgets);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('sin reportes: estado vacío; cargando: esqueleto', (t) async {
      await t.pumpWidget(app(const SeccionFeed(feed: [], origen: OrigenDato.cache, cuando: null), 390));
      await t.pump();
      expect(find.text('Aún no hay reportes públicos'), findsOneWidget);
      expect(find.textContaining('Sin señal'), findsOneWidget);
      await t.pumpWidget(app(const SeccionFeed(feed: null, origen: null, cuando: null), 390));
      expect(find.text('Aún no hay reportes públicos'), findsNothing);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 30));
    });

    testWidgets('tocar un reporte abre su ficha con el aviso de simulado', (t) async {
      final r = simuladosDeTexto(textoSim).first;
      await t.pumpWidget(app(Padding(padding: const EdgeInsets.all(20), child: TarjetaReporte(r: r)), 390));
      await t.tap(find.byType(TarjetaReporte));
      await t.pumpAndSettle();
      expect(find.textContaining('reporte de demostración'), findsOneWidget);
      expect(find.text('Ver en el mapa'), findsOneWidget);
    });
  });
}
