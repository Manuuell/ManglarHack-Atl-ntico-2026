import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/nucleo/kit/anuncio.dart';
import 'package:zanky/nucleo/kit/boton_estado.dart';
import 'package:zanky/nucleo/kit/celebracion.dart';
import 'package:zanky/nucleo/kit/haptica.dart';
import 'package:zanky/nucleo/kit/sacudida.dart';
import 'package:zanky/nucleo/kit/spinner.dart';

Widget _app(Widget hijo, {bool reducir = false}) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducir),
        child: child!,
      ),
      home: Scaffold(body: Center(child: hijo)),
    );

void main() {
  group('BotonEstado', () {
    testWidgets('reposo → cargando → hecho → reposo, y no se dispara dos veces', (t) async {
      var llamadas = 0;
      await t.pumpWidget(_app(BotonEstado(
        texto: 'Enviar',
        textoHecho: 'Enviado',
        alPresionar: () async {
          llamadas++;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
      )));
      expect(find.text('Enviar'), findsOneWidget);

      await t.tap(find.text('Enviar'));
      await t.pump();
      expect(find.byType(SpinnerZ), findsOneWidget);
      await t.tap(find.byType(BotonEstado), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 350));
      expect(llamadas, 1);
      expect(find.byType(CheckDibujado), findsOneWidget);

      await t.pump(const Duration(seconds: 2));
      await t.pump(const Duration(milliseconds: 500)); // termina el fundido
      expect(find.byType(CheckDibujado), findsNothing);
      expect(find.byType(SpinnerZ), findsNothing);
    });

    testWidgets('si la función lanza, muestra el error y vuelve a reposo', (t) async {
      await t.pumpWidget(_app(BotonEstado(
        texto: 'Enviar',
        textoError: 'Sin señal',
        alPresionar: () async => throw Exception('x'),
      )));
      await t.tap(find.text('Enviar'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Sin señal'), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Sin señal'), findsNothing);
      expect(find.text('Enviar'), findsOneWidget);
    });

    testWidgets('sin función queda apagado y no responde', (t) async {
      await t.pumpWidget(_app(const BotonEstado(texto: 'Enviar', alPresionar: null)));
      await t.tap(find.text('Enviar'));
      await t.pump();
      expect(find.byType(SpinnerZ), findsNothing);
    });
  });

  group('Celebración', () {
    testWidgets('celebrar pone el ✓ encima de todo y se limpia solo', (t) async {
      late BuildContext ctx;
      await t.pumpWidget(_app(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));
      final fin = celebrar(ctx, etiqueta: 'Reporte enviado');
      await t.pump();
      expect(find.byType(CheckDibujado), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      await fin;
      expect(find.byType(CheckDibujado), findsNothing);
    });

    testWidgets('con reducir movimiento no hay confeti pero sí ✓', (t) async {
      late BuildContext ctx;
      await t.pumpWidget(_app(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }), reducir: true));
      final fin = celebrar(ctx);
      await t.pump();
      expect(find.descendant(of: find.byType(Celebracion), matching: find.byType(CustomPaint)), findsNothing);
      expect(find.byType(CheckDibujado), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      await fin;
    });

    testWidgets('CheckDibujado dice su etiqueta al lector', (t) async {
      final sem = t.ensureSemantics();
      await t.pumpWidget(_app(const CheckDibujado(etiqueta: 'Hecho')));
      await t.pump(const Duration(seconds: 1));
      expect(find.bySemanticsLabel('Hecho'), findsOneWidget);
      sem.dispose();
    });
  });

  group('SpinnerZ y Sacudida', () {
    testWidgets('el spinner gira aun con reducir movimiento', (t) async {
      await t.pumpWidget(_app(const SpinnerZ(), reducir: true));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(SpinnerZ), findsOneWidget);
      expect(t.hasRunningAnimations, isTrue);
    });

    testWidgets('Sacudida solo se mueve cuando disparos sube', (t) async {
      Widget armar(int d) => _app(Sacudida(disparos: d, child: const SizedBox(key: Key('h'), width: 20, height: 20)));
      await t.pumpWidget(armar(1));
      final x0 = t.getTopLeft(find.byKey(const Key('h'))).dx;
      await t.pump(const Duration(milliseconds: 100));
      expect(t.getTopLeft(find.byKey(const Key('h'))).dx, x0);

      await t.pumpWidget(armar(2));
      await t.pump(const Duration(milliseconds: 70));
      expect(t.getTopLeft(find.byKey(const Key('h'))).dx, isNot(x0));
      await t.pump(const Duration(seconds: 1));
      expect(t.getTopLeft(find.byKey(const Key('h'))).dx, x0);
    });
  });

  group('Háptica y anuncio', () {
    testWidgets('vibrar y anunciar no lanzan (sin plataforma)', (t) async {
      late BuildContext ctx;
      await t.pumpWidget(_app(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));
      vibrarExito();
      vibrarAviso();
      vibrarError();
      anunciar(ctx, 'Hola');
      await t.pump();
    });
  });
}
