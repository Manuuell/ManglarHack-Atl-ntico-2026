import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/comunidad/comunidad.dart';
import 'package:zanky/datos/comunidad/feed.dart' show puntoPedidoMapa;
import 'package:zanky/datos/cra/servicio_visores.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/comunidad/alertas_diseno.dart';
import 'package:zanky/vistas/mapa/pantalla_mapa.dart';
import 'package:zanky/vistas/visores/pantalla_visores.dart' show crearServicioVisores;

import 'ayudas/fuente_lato.dart';
import 'visores_test.dart' show clienteFijo, pedidos;

/// El mapa y las alertas: la misma regla de publicación que Inicio y Comunidad, «Ver en el mapa»
/// centra en la alerta y la capa «Riesgos CRA» (sin pedir dos veces).
AlertaManglar alerta(String id, String lugar, {String tipo = 'mar_de_leva', int horas = 2}) => AlertaManglar(
      id: id,
      tipo: tipo,
      nivel: NivelAlerta.amarilla,
      titulo: 'Aviso $id',
      detalle: '',
      recomendacion: 'Aléjate de la orilla.',
      lugar: lugar,
      punto: const LatLng(10.9, -75.0),
      desde: DateTime.now().subtract(Duration(hours: horas)),
      hasta: DateTime.now().add(const Duration(hours: 2)),
      medido: true,
      fuentes: const ['dimar'],
    );

ResultadoAlertas resultado(List<AlertaManglar> a, {bool simulacro = false}) =>
    ResultadoAlertas(generado: null, alertas: a, ahora: const [], fuentes: const [], nota: '', simulacro: simulacro);

void main() {
  group('Una sola regla para Inicio, Comunidad y el mapa', () {
    test('las ciudadanas y las más viejas que las 6 recientes no salen (el caso de Tubará)', () {
      final r = resultado([
        for (var i = 0; i < 6; i++) alerta('r$i', 'Lugar $i', horas: i + 1),
        alerta('vieja', 'Tubará', horas: 30),
        alerta('ciudadana', 'Puerto Colombia', tipo: 'amenaza_ciudadana', horas: 0),
      ]);
      final g = gruposPublicados(r);
      final lugares = g.map((x) => x.principal.lugar).toSet();
      expect(lugares, isNot(contains('Tubará')));
      expect(lugares, isNot(contains('Puerto Colombia')));
      // Lo que cuenta cada grupo suma lo publicado, y coincide con la regla de los datos.
      expect(g.fold<int>(0, (s, x) => s + x.todas.length), 6);
      expect(alertasPublicadas(r.alertas).map((a) => a.id), r.publicadas.take(6).map((a) => a.id));
    });

    test('el conteo del grupo es el de todas las del lugar', () {
      final g = gruposPublicados(resultado([alerta('a', 'Mallorquín'), alerta('b', 'Mallorquín', horas: 3)]));
      expect(g, hasLength(1));
      expect(g.first.todas.length, 2);
    });
  });

  testWidgets('«Ver en el mapa» pide el punto de la alerta y vuelve a la raíz', (t) async {
    puntoPedidoMapa.value = null;
    late BuildContext interior;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (c2) {
            interior = c2;
            return const Scaffold(body: Text('detalle'));
          })),
          child: const Text('abrir'),
        ),
      ),
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(find.text('detalle'), findsOneWidget);
    const punto = LatLng(10.98, -74.95);
    verEnElMapa(interior, punto);
    await t.pumpAndSettle();
    expect(puntoPedidoMapa.value, punto);
    expect(find.text('detalle'), findsNothing);
    puntoPedidoMapa.value = null;
  });

  group('Capa «Riesgos CRA» en el mapa', () {
    late EstadoZanky estado;

    setUpAll(() async {
      await cargarLato();
      final j = jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync());
      estado = EstadoZanky()
        ..manglar = Manglar.desdeJson(j as Map<String, dynamic>, null)
        ..listo = true;
    });

    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() => crearServicioVisores =
        (context) => ServicioVisores(servidor: Zanky.leer(context).servidor));

    Future<void> montar(WidgetTester t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(Zanky(
        estado: estado,
        child: MaterialApp(theme: temaZanky(), home: const Scaffold(body: PantallaMapa())),
      ));
      await avanzar(t);
    }

    Future<void> cerrar(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 30));
    }

    ServicioVisores fijo({bool caido = false}) => ServicioVisores(
          cliente: clienteFijo(caido: caido),
          servidor: Servidor(base: 'https://ejemplo.supabase.co', anon: 'anon'),
        );

    testWidgets('encender trae la capa una vez, la resume y apagar/encender no vuelve a pedir', (t) async {
      crearServicioVisores = (_) => fijo();
      await montar(t);
      final boton = find.byKey(const ValueKey('boton-riesgos'));
      expect(boton, findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Riesgos CRA: ver puntos críticos')), findsOneWidget);

      await t.tap(boton);
      await avanzar(t);
      expect(find.textContaining(RegExp('Riesgos de la CRA en el manglar|La CRA no reporta')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Riesgos CRA, capa encendida')), findsOneWidget);
      final hechos = pedidos;
      expect(hechos, greaterThan(0));

      await t.tap(boton); // apagar
      await avanzar(t);
      expect(find.bySemanticsLabel(RegExp('Riesgos CRA: ver puntos críticos')), findsOneWidget);
      await t.tap(boton); // encender otra vez: de memoria
      await avanzar(t);
      expect(find.bySemanticsLabel(RegExp('Riesgos CRA, capa encendida')), findsOneWidget);
      expect(pedidos, hechos, reason: 'la capa no se vuelve a pedir');
      await cerrar(t);
    });

    testWidgets('sin señal y sin copia avisa, deja reintentar y no queda encendida', (t) async {
      crearServicioVisores = (_) => fijo(caido: true);
      await montar(t);
      await t.tap(find.byKey(const ValueKey('boton-riesgos')));
      await avanzar(t);
      expect(find.textContaining('No pude traer los riesgos de la CRA'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Riesgos CRA: ver puntos críticos')), findsOneWidget);
      await cerrar(t);
    });
  });
}

Future<void> avanzar(WidgetTester t, {int veces = 6}) async {
  for (var i = 0; i < veces; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}
