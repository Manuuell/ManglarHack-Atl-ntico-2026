// Piezas nuevas del kit: aviso, confirmar con Deshacer, estado vacío, interruptor,
// segmentado, hoja (agarre, arrastre, velo) y esqueleto. Cada una con y sin
// «reducir movimiento».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/nucleo/base/esqueleto.dart';
import 'package:zanky/nucleo/base/hoja.dart';
import 'package:zanky/nucleo/base/movimiento.dart';
import 'package:zanky/nucleo/kit/aviso.dart';
import 'package:zanky/nucleo/kit/confirmar.dart';
import 'package:zanky/nucleo/kit/estado_vacio.dart';
import 'package:zanky/nucleo/kit/interruptor.dart';
import 'package:zanky/nucleo/kit/segmentado.dart';
import 'package:zanky/nucleo/tema.dart';

Widget _app(Widget hijo, {bool reducir = false, double letra = 1}) => MaterialApp(
      theme: temaZanky(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reducir,
          textScaler: TextScaler.linear(letra),
        ),
        child: child!,
      ),
      home: Scaffold(body: Center(child: hijo)),
    );

late BuildContext _ctx;
Widget _conContexto() => Builder(builder: (c) {
      _ctx = c;
      return const SizedBox();
    });

/// Zanky respira para siempre y deja un `Future.delayed`: se desmonta y se deja
/// correr el reloj antes de terminar.
Future<void> _cerrar(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 30));
}

Future<void> _pasar(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('Aviso', () {
    for (final reducir in [false, true]) {
      testWidgets('aparece, se va solo (reducir=$reducir)', (t) async {
        await t.pumpWidget(_app(_conContexto(), reducir: reducir));
        avisar(_ctx, 'Reporte guardado');
        await t.pump();
        await _pasar(t, 400);
        expect(find.text('Reporte guardado'), findsOneWidget);
        await _pasar(t, 3500);
        expect(find.text('Reporte guardado'), findsNothing);
      });
    }

    testWidgets('baja desde arriba con resorte hasta su sitio', (t) async {
      await t.pumpWidget(_app(_conContexto()));
      avisar(_ctx, 'Hola');
      await t.pump();
      await t.pump(const Duration(milliseconds: 16));
      final yInicio = t.getTopLeft(find.text('Hola')).dy;
      await _pasar(t, 500);
      final yFinal = t.getTopLeft(find.text('Hola')).dy;
      expect(yInicio, lessThan(yFinal));
      await _pasar(t, 4000);
    });

    testWidgets('se apilan hasta 3: el cuarto saca al más viejo', (t) async {
      await t.pumpWidget(_app(_conContexto()));
      for (final n in ['uno', 'dos', 'tres', 'cuatro']) {
        avisar(_ctx, n);
        await t.pump(const Duration(milliseconds: 20));
      }
      await _pasar(t, 500);
      expect(find.text('uno'), findsNothing);
      expect(find.text('dos'), findsOneWidget);
      expect(find.text('tres'), findsOneWidget);
      expect(find.text('cuatro'), findsOneWidget);
      await _pasar(t, 8000);
      expect(find.text('cuatro'), findsNothing);
    });

    testWidgets('se descarta deslizando', (t) async {
      await t.pumpWidget(_app(_conContexto()));
      avisar(_ctx, 'Desliza', vida: const Duration(seconds: 30));
      await _pasar(t, 500);
      await t.fling(find.text('Desliza'), const Offset(300, 0), 1200);
      await _pasar(t, 500);
      expect(find.text('Desliza'), findsNothing);
    });

    testWidgets('la acción Deshacer se llama y cierra el aviso', (t) async {
      var deshecho = 0;
      await t.pumpWidget(_app(_conContexto()));
      avisar(_ctx, 'Quitaste el reporte', accion: AccionAviso('Deshacer', () => deshecho++));
      await _pasar(t, 500);
      await t.tap(find.text('Deshacer'));
      await _pasar(t, 500);
      expect(deshecho, 1);
      expect(find.text('Quitaste el reporte'), findsNothing);
    });

    testWidgets('con acción vive el plazo del Deshacer (6 s) y no menos', (t) async {
      await t.pumpWidget(_app(_conContexto()));
      avisar(_ctx, 'Ok', accion: AccionAviso('Deshacer', () {}));
      await _pasar(t, 5000);
      expect(find.text('Ok'), findsOneWidget);
      await _pasar(t, 2000);
      expect(find.text('Ok'), findsNothing);
    });
  });

  group('Confirmar', () {
    testWidgets('confirmarEnHoja devuelve true al confirmar y false al cancelar', (t) async {
      await t.pumpWidget(_app(_conContexto()));
      bool? r;
      confirmarEnHoja(_ctx, titulo: '¿Quitar?', texto: 'Se quita.', textoConfirmar: 'Quitar', destructivo: true)
          .then((v) => r = v);
      await _pasar(t, 700);
      expect(find.text('¿Quitar?'), findsOneWidget);
      await t.tap(find.text('Quitar'));
      await _pasar(t, 700);
      expect(r, isTrue);

      confirmarEnHoja(_ctx, titulo: '¿Quitar?', texto: 'Se quita.', textoConfirmar: 'Quitar').then((v) => r = v);
      await _pasar(t, 700);
      await t.tap(find.text('Cancelar'));
      await _pasar(t, 700);
      expect(r, isFalse);
      await _cerrar(t);
    });

    testWidgets('accionConDeshacer: confirma, hace, avisa y deshace', (t) async {
      await t.pumpWidget(_app(_conContexto(), reducir: true));
      final pasos = <String>[];
      accionConDeshacer(
        _ctx,
        titulo: '¿Quitar?',
        texto: 'Se quita.',
        textoConfirmar: 'Quitar',
        avisoHecho: 'Reporte quitado',
        hacer: () async => pasos.add('hecho'),
        deshacer: () async => pasos.add('deshecho'),
      );
      await _pasar(t, 300);
      await t.tap(find.text('Quitar'));
      await _pasar(t, 500);
      expect(pasos, ['hecho']);
      expect(find.text('Reporte quitado'), findsOneWidget);
      await t.tap(find.text('Deshacer'));
      await _pasar(t, 300);
      expect(pasos, ['hecho', 'deshecho']);
      await _pasar(t, 1000);
      await _cerrar(t);
    });

    testWidgets('si se cancela no se hace nada', (t) async {
      await t.pumpWidget(_app(_conContexto()));
      var hecho = false;
      accionConDeshacer(
        _ctx,
        titulo: 'x',
        texto: 'y',
        textoConfirmar: 'Sí',
        avisoHecho: 'z',
        hacer: () async => hecho = true,
        deshacer: () async {},
      );
      await _pasar(t, 600);
      await t.tap(find.text('Cancelar'));
      await _pasar(t, 600);
      expect(hecho, isFalse);
      expect(find.text('z'), findsNothing);
      await _cerrar(t);
    });
  });

  group('EstadoVacio', () {
    for (final reducir in [false, true]) {
      testWidgets('muestra Zanky, título, texto y acción (reducir=$reducir)', (t) async {
        var toques = 0;
        await t.pumpWidget(_app(
          EstadoVacio(titulo: 'Nada aquí', texto: 'Todavía no hay nada.', textoAccion: 'Empezar', alAccion: () => toques++),
          reducir: reducir,
        ));
        await _pasar(t, 800);
        expect(find.text('Nada aquí'), findsOneWidget);
        expect(find.text('Todavía no hay nada.'), findsOneWidget);
        await t.tap(find.text('Empezar'));
        expect(toques, 1);
        await _cerrar(t);
      });
    }

    testWidgets('cabe a 360x640 con letra x1,3 sin desbordar', (t) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(
        const SizedBox(
          height: 500,
          child: EstadoVacio(titulo: 'Aún no has reportado nada', texto: 'Cuando veas algo raro en el manglar, tócame.', textoAccion: 'Hacer mi primer reporte'),
        ),
        letra: 1.3,
      ));
      await _pasar(t, 800);
      expect(t.takeException(), isNull);
      await _cerrar(t);
    });
  });

  group('InterruptorIos', () {
    for (final reducir in [false, true]) {
      testWidgets('un toque lo cambia (reducir=$reducir)', (t) async {
        var valor = false;
        await t.pumpWidget(_app(
          StatefulBuilder(builder: (c, set) => InterruptorIos(valor: valor, etiqueta: 'Anónimo', alCambiar: (v) => set(() => valor = v))),
          reducir: reducir,
        ));
        await t.tap(find.byType(InterruptorIos));
        await _pasar(t, 500);
        expect(valor, isTrue);
        await t.tap(find.byType(InterruptorIos));
        await _pasar(t, 500);
        expect(valor, isFalse);
      });
    }

    testWidgets('se arrastra de un lado al otro', (t) async {
      var valor = false;
      await t.pumpWidget(_app(
        StatefulBuilder(builder: (c, set) => InterruptorIos(valor: valor, alCambiar: (v) => set(() => valor = v))),
      ));
      await t.drag(find.byType(InterruptorIos), const Offset(40, 0));
      await _pasar(t, 500);
      expect(valor, isTrue);
    });

    testWidgets('sin función queda apagado y no responde', (t) async {
      await t.pumpWidget(_app(const InterruptorIos(valor: false, alCambiar: null)));
      await t.tap(find.byType(InterruptorIos));
      await _pasar(t, 200);
      expect(find.byType(InterruptorIos), findsOneWidget);
    });

    testWidgets('dice su estado al lector', (t) async {
      final sem = t.ensureSemantics();
      await t.pumpWidget(_app(InterruptorIos(valor: true, etiqueta: 'Anónimo', alCambiar: (_) {})));
      expect(
        t.getSemantics(find.byType(InterruptorIos)),
        matchesSemantics(label: 'Anónimo', hasToggledState: true, isToggled: true, hasEnabledState: true, isEnabled: true, hasTapAction: true),
      );
      sem.dispose();
    });
  });

  group('SegmentadoZ', () {
    for (final reducir in [false, true]) {
      testWidgets('tocar un segmento lo elige (reducir=$reducir)', (t) async {
        var i = 0;
        await t.pumpWidget(_app(
          StatefulBuilder(builder: (c, set) => SegmentadoZ(valor: i, etiquetas: const ['Todos', 'Pendientes', 'Validados'], alCambiar: (n) => set(() => i = n))),
          reducir: reducir,
        ));
        await t.tap(find.text('Validados'));
        await _pasar(t, 500);
        expect(i, 2);
      });
    }

    testWidgets('arrastrar la píldora cambia de segmento', (t) async {
      var i = 0;
      await t.pumpWidget(_app(
        SizedBox(
          width: 330,
          child: StatefulBuilder(builder: (c, set) => SegmentadoZ(valor: i, etiquetas: const ['Todos', 'Pendientes', 'Validados'], alCambiar: (n) => set(() => i = n))),
        ),
      ));
      await t.drag(find.text('Todos'), const Offset(120, 0));
      await _pasar(t, 500);
      expect(i, 1);
    });
  });

  group('Hoja', () {
    Future<void> abrir(WidgetTester t) async {
      mostrarHojaZ<void>(_ctx, contenido: (_) => const SizedBox(height: 120, child: Text('Contenido de la hoja')));
      await _pasar(t, 700);
    }

    for (final reducir in [false, true]) {
      testWidgets('abre con agarre y cierra por velocidad (reducir=$reducir)', (t) async {
        await t.pumpWidget(_app(_conContexto(), reducir: reducir));
        await abrir(t);
        expect(find.text('Contenido de la hoja'), findsOneWidget);
        await t.fling(find.text('Contenido de la hoja'), const Offset(0, 120), 1500);
        await _pasar(t, 700);
        expect(find.text('Contenido de la hoja'), findsNothing);
      });
    }

    testWidgets('un arrastre corto y lento vuelve a su sitio con resorte', (t) async {
      await t.pumpWidget(_app(_conContexto()));
      await abrir(t);
      final y0 = t.getTopLeft(find.text('Contenido de la hoja')).dy;
      final g = await t.startGesture(t.getCenter(find.text('Contenido de la hoja')));
      await g.moveBy(const Offset(0, 40));
      await t.pump(const Duration(milliseconds: 16));
      expect(t.getTopLeft(find.text('Contenido de la hoja')).dy, greaterThan(y0));
      await g.up();
      await _pasar(t, 800);
      expect(t.getTopLeft(find.text('Contenido de la hoja')).dy, closeTo(y0, 0.5));
    });

    testWidgets('el velo se aclara mientras se arrastra', (t) async {
      await t.pumpWidget(_app(_conContexto()));
      await abrir(t);
      Color velo() => t.widgetList<ColoredBox>(find.byType(ColoredBox)).map((c) => c.color).firstWhere((c) => c.a > 0 && c.a < 1 && c.b < 0.3, orElse: () => const Color(0x00000000));
      final antes = velo().a;
      final g = await t.startGesture(t.getCenter(find.text('Contenido de la hoja')));
      await g.moveBy(const Offset(0, 160));
      await t.pump(const Duration(milliseconds: 16));
      final durante = velo().a;
      expect(antes, greaterThan(0));
      expect(durante, lessThan(antes));
      await g.up();
      await _pasar(t, 800);
    });

    testWidgets('con el teclado arriba no se pasa del espacio libre', (t) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1;
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(_conContexto()));
      mostrarHojaZ<void>(_ctx, contenido: (_) => const SizedBox(height: 900, child: Text('Larga')));
      await _pasar(t, 700);
      expect(t.takeException(), isNull);
      expect(t.getBottomLeft(find.byType(SingleChildScrollView)).dy, lessThanOrEqualTo(640 - 300 + 0.5));
      expect(t.getTopLeft(find.byType(SingleChildScrollView)).dy, greaterThanOrEqualTo(0));
    });
  });

  group('Esqueleto', () {
    testWidgets('el brillo se traslada (transform) y no cambia el tamaño', (t) async {
      await t.pumpWidget(_app(const SizedBox(width: 200, child: Skeleton(height: 40))));
      final tam = t.getSize(find.byType(Skeleton));
      await t.pump(const Duration(milliseconds: 200));
      final a = t.getTopLeft(find.byType(DecoratedBox).last).dx;
      await t.pump(const Duration(milliseconds: 300));
      final b = t.getTopLeft(find.byType(DecoratedBox).last).dx;
      expect(b, isNot(a));
      expect(t.getSize(find.byType(Skeleton)), tam);
    });

    testWidgets('con reducir movimiento queda quieto', (t) async {
      await t.pumpWidget(_app(const SizedBox(width: 200, child: Skeleton(height: 40)), reducir: true));
      expect(t.hasRunningAnimations, isFalse);
    });
  });

  test('los tokens del kit existen', () {
    expect(AppMotion.plazoDeshacer, const Duration(seconds: 6));
    expect(AvisoZ.maximo, 3);
  });
}
