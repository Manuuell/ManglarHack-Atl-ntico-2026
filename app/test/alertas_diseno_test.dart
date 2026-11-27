import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/comunidad/comunidad.dart';
import 'package:zanky/datos/comunidad/feed.dart' show cargaJornadasRespaldo;
import 'package:zanky/datos/experiencia/jornada.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/comunidad/alertas_diseno.dart';
import 'package:zanky/vistas/comunidad/comunidad_inicio.dart';

/// La respuesta real de `/alertas` guardada el 27-nov-2026.
String fixture(String nombre) => File('test/fixtures/comunidad/$nombre').readAsStringSync();

AlertaManglar alerta(String id, NivelAlerta nivel,
        {String tipo = 'riesgo_incendio', String lugar = 'Ciénaga de Mallorquín', List<String> fuentes = const ['cra']}) =>
    AlertaManglar(
      id: id,
      tipo: tipo,
      nivel: nivel,
      titulo: 'Aviso $id en $lugar',
      detalle: 'Detalle de $id.',
      recomendacion: 'Aléjate del humo y llama al 119. Después repórtalo en Zanky para que la C.R.A. lo vea.',
      lugar: lugar,
      punto: null,
      desde: DateTime.now().subtract(const Duration(hours: 2)),
      hasta: DateTime.now().add(const Duration(hours: 2)),
      medido: true,
      fuentes: fuentes,
    );

Widget app(Widget hijo, {bool reducir = false, double ancho = 390}) => MaterialApp(
      theme: temaZanky(),
      home: Builder(
        builder: (c) => MediaQuery(
          data: MediaQuery.of(c).copyWith(size: Size(ancho, 844), disableAnimations: reducir),
          child: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: hijo)),
        ),
      ),
    );

/// Deja correr los plazos de los avisos (Deshacer: 6 s) para no dejar relojes vivos.
Future<void> pocos(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

Future<void> vaciarAvisos(WidgetTester t) async {
  for (var i = 0; i < 16; i++) {
    await t.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AlertasOcultas.compartidas.reiniciar();
  });

  group('sistema de niveles y textos', () {
    test('cada nivel tiene color, ícono, consigna y háptica propios', () {
      final estilos = NivelAlerta.values.map(EstiloNivel.de).toList();
      expect(estilos.map((e) => e.color).toSet().length, 3);
      expect(estilos.map((e) => e.icono).toSet().length, 3);
      expect(estilos.map((e) => e.consigna), ['Atento', 'Prepárate', 'Actúa ya']);
      expect(estilos.map((e) => e.vibracion).toSet().length, 3);
      expect(colorSimulacro, isNot(anyOf(estilos.map((e) => e.color).toList())));
    });

    test('un ícono propio por tipo de amenaza (sin emojis)', () {
      const tipos = ['mar_de_leva', 'inundacion_costera', 'lluvia_fuerte', 'vendaval', 'riesgo_incendio', 'foco_calor', 'amenaza_ciudadana'];
      expect(tipos.map(iconoAmenaza).toSet().length, tipos.length);
    });

    test('«qué hacer» en un renglón corto, con verbo y «CRA» sin puntos', () {
      final r = ResultadoAlertas.deTexto(fixture('alertas.json'));
      for (final a in r.alertas) {
        final q = queHacerCorto(a.recomendacion);
        expect(q.length, lessThanOrEqualTo(73), reason: q);
        expect(q, isNot(contains('C.R.A')));
        expect(q[0], q[0].toUpperCase());
      }
      expect(queHacerCorto('No quemes basura ni maleza cerca del manglar. Si ves humo, aléjate.'),
          'No quemes basura ni maleza cerca del manglar');
      expect(limpiarCra('la C.R.A. lo ve'), 'la CRA lo ve');
    });

    test('se publica lo mismo que en la web: sin amenazas ciudadanas, máximo 6, la más grave arriba', () {
      final r = ResultadoAlertas.deTexto(fixture('alertas.json'));
      final pub = alertasPublicadas(r.alertas);
      expect(pub.where((a) => a.tipo == 'amenaza_ciudadana'), isEmpty);
      expect(pub.length, lessThanOrEqualTo(maxAlertasPublicadas));
      final g = gruposPublicados(r);
      expect(g.length, 2, reason: 'Totumo y Mallorquín');
      expect(g.first.principal.nivel, NivelAlerta.naranja);
      final lugares = g.map((x) => x.principal.lugar).toList();
      expect(lugares.toSet().length, lugares.length);
      // 7 alertas al azar del mismo lugar: nunca más de 6.
      final muchas = [for (var i = 0; i < 9; i++) alerta('m$i', NivelAlerta.amarilla, lugar: 'L$i')];
      expect(alertasPublicadas(muchas).length, 6);
    });
  });

  group('pila de Inicio', () {
    final grupos = [
      GrupoAlerta(alerta('a1', NivelAlerta.amarilla, lugar: 'Tubará'), const []),
      GrupoAlerta(alerta('r1', NivelAlerta.roja), [alerta('r2', NivelAlerta.amarilla)]),
      GrupoAlerta(alerta('n1', NivelAlerta.naranja, lugar: 'Totumo', tipo: 'mar_de_leva', fuentes: ['dimar']), const []),
    ];
    final ordenados = agruparAlertas([for (final g in grupos) ...g.todas]);

    testWidgets('la roja va arriba, late, y con «reducir movimiento» se queda quieta', (t) async {
      expect(ordenados.first.principal.id, 'r1');
      await t.pumpWidget(app(PilaAlertas(grupos: ordenados)));
      await t.pump();
      expect(find.text('1 de 3'), findsOneWidget);
      expect(find.textContaining('Actúa ya'), findsOneWidget);
      expect(find.textContaining('Qué hacer:'), findsOneWidget);
      expect(find.textContaining('Aléjate del humo y llama al 119'), findsOneWidget);
      expect(find.textContaining('hace 2 h'), findsOneWidget);
      expect(find.textContaining('CRA'), findsWidgets);
      await t.pump(const Duration(milliseconds: 100));
      expect(t.binding.hasScheduledFrame, isTrue, reason: 'el pulso de la roja corre');

      await t.pumpWidget(app(PilaAlertas(grupos: ordenados), reducir: true));
      await t.pumpAndSettle(); // sin pulso: se asienta
      expect(t.binding.hasScheduledFrame, isFalse);
      await vaciarAvisos(t);
    });

    testWidgets('«Siguiente» pasa la de arriba al fondo y el contador avanza', (t) async {
      await t.pumpWidget(app(PilaAlertas(grupos: ordenados), reducir: true));
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel('Siguiente alerta'));
      await t.pumpAndSettle();
      expect(find.text('2 de 3'), findsOneWidget);
      expect(find.textContaining('Aviso n1'), findsOneWidget);
    });

    testWidgets('deslizar oculta la alerta y «Deshacer» la devuelve', (t) async {
      await t.pumpWidget(app(PilaAlertas(grupos: ordenados), reducir: true));
      await t.pumpAndSettle();
      expect(find.textContaining('Aviso r1'), findsOneWidget);
      await t.drag(find.byKey(const ValueKey('alerta-r1')), const Offset(-600, 0));
      await pocos(t);
      expect(find.textContaining('Aviso r1'), findsNothing);
      expect(find.text('1 de 2'), findsOneWidget);
      expect(AlertasOcultas.compartidas.value, contains('r1'));
      expect(find.text('Deshacer'), findsOneWidget);
      await t.tap(find.text('Deshacer'));
      await pocos(t);
      expect(find.textContaining('Aviso r1'), findsOneWidget);
      expect(find.text('1 de 3'), findsOneWidget);
      await vaciarAvisos(t);
      expect(t.takeException(), isNull);
    });

    testWidgets('mantener presionado: vista previa con ver en el mapa, compartir, avísame y ocultar', (t) async {
      final conPunto = GrupoAlerta(
        AlertaManglar(
          id: 'p1',
          tipo: 'mar_de_leva',
          nivel: NivelAlerta.naranja,
          titulo: 'Mar de leva en Totumo',
          detalle: 'Olas de 2,9 m.',
          recomendacion: 'No entres al mar. Aleja los viveros.',
          lugar: 'Totumo',
          punto: null,
          desde: DateTime.now(),
          hasta: DateTime.now(),
          medido: false,
          fuentes: const ['dimar'],
        ),
        const [],
      );
      await t.pumpWidget(app(PilaAlertas(grupos: [conPunto]), reducir: true));
      await t.pumpAndSettle();
      await t.longPress(find.byKey(const ValueKey('alerta-p1')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('peek')), findsOneWidget);
      expect(find.byKey(const Key('menu-Ver detalle')), findsOneWidget);
      expect(find.byKey(const Key('menu-Compartir')), findsOneWidget);
      expect(find.byKey(const Key('menu-Avísame si sube')), findsOneWidget);
      expect(find.byKey(const Key('menu-Ocultar')), findsOneWidget);
      // La vista previa trae la recomendación entera.
      expect(find.textContaining('Aleja los viveros'), findsOneWidget);
      await t.tap(find.byKey(const Key('menu-Ocultar')));
      await pocos(t);
      expect(find.textContaining('Ocultaste la alerta de Totumo'), findsOneWidget);
      await vaciarAvisos(t);
    });

    testWidgets('simulacro: franja violeta y rótulo «no es real», nunca «Alertas del manglar»', (t) async {
      await t.pumpWidget(app(PilaAlertas(grupos: ordenados, simulacro: true)));
      await t.pump();
      expect(find.byKey(const Key('franja-simulacro')), findsOneWidget);
      expect(find.text('SIMULACRO · NO ES REAL'), findsNWidgets(2));
      expect(find.text('ALERTAS DEL MANGLAR'), findsNothing);
      await t.pump(const Duration(milliseconds: 100));
      expect(t.binding.hasScheduledFrame, isFalse, reason: 'el simulacro no late');
    });

    testWidgets('sin alertas: calma; cabe a 360 y 768 px sin desbordes', (t) async {
      await t.pumpWidget(app(const PilaAlertas(grupos: [])));
      await t.pump();
      expect(find.text('Sin alertas en el manglar ahora'), findsOneWidget);
      for (final ancho in [360.0, 768.0]) {
        await t.pumpWidget(app(PilaAlertas(grupos: ordenados), ancho: ancho, reducir: true));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
    });

    testWidgets('nunca dice «alertas oficiales»', (t) async {
      await t.pumpWidget(app(PilaAlertas(grupos: ordenados), reducir: true));
      await t.pumpAndSettle();
      expect(find.textContaining(RegExp('oficiales', caseSensitive: false)), findsNothing);
    });
  });

  group('sin red', () {
    setUp(() => cargaJornadasRespaldo = () async => const []);
    final sinRed = MockClient((_) async => throw const SocketException('sin red'));

    testWidgets('con copia guardada: nota «Sin señal» y la pila con lo último guardado', (t) async {
      SharedPreferences.setMockInitialValues({
        'comunidad.alertas': fixture('alertas.json'),
        'comunidad.alertas.t': DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
      });
      await t.pumpWidget(app(ComunidadInicio(
        jornadas: FuenteJornadas(cliente: sinRed),
        fuente: FuenteComunidad(cliente: sinRed),
        respaldo: const Text('RESPALDO'),
      ), reducir: true));
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 250));
      }
      expect(find.textContaining('Sin señal: lo último guardado'), findsOneWidget);
      expect(find.text('ALERTAS DEL MANGLAR'), findsOneWidget);
      expect(find.text('1 de 2'), findsOneWidget);
      expect(find.text('RESPALDO'), findsNothing);
    });
  });

  test('la respuesta de prueba se entiende (sanidad del fixture)', () {
    expect(jsonDecode(fixture('alertas.json')), isA<Map>());
    expect(http.Response('x', 200).statusCode, 200);
  });
}
