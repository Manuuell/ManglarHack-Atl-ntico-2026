// Los gestos del kit (deslizar, mantener con vista previa, tirar para actualizar, bandeja de
// acciones y volver desde el borde) con dedo, con ratón, con teclado, con «reducir movimiento»
// y por el camino sin gesto (acciones del lector de pantalla y botones). Más los gestos de las
// pantallas: panel (deslizar, atajos j/k/a/r, botones a 1280x800) y Mis reportes.
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/admin/controlador_admin.dart';
import 'package:zanky/datos/admin/reporte_admin.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/nucleo/kit/accion_gesto.dart';
import 'package:zanky/nucleo/kit/bandeja_acciones.dart';
import 'package:zanky/nucleo/kit/fila_deslizable.dart';
import 'package:zanky/nucleo/kit/menu_mantenido.dart';
import 'package:zanky/nucleo/kit/ruta_borde.dart';
import 'package:zanky/nucleo/kit/tirar_actualizar.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/admin/bandeja_admin.dart';
import 'package:zanky/vistas/admin/piezas_admin.dart';

Future<void> _montar(WidgetTester t, Widget hijo, {bool reducir = false, Size tam = const Size(390, 844)}) async {
  t.view.physicalSize = tam;
  t.view.devicePixelRatio = 1;
  addTearDown(() {
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  await t.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: temaZanky(),
    builder: (context, child) =>
        MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reducir), child: child!),
    home: Scaffold(body: hijo),
  ));
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> _avanzar(WidgetTester t, [int veces = 8, int ms = 100]) async {
  for (var i = 0; i < veces; i++) {
    await t.pump(Duration(milliseconds: ms));
  }
}

Future<void> _cerrar(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 30));
}

void _accionDeLector(WidgetTester t, Finder f, String etiqueta) {
  final nodo = t.getSemantics(f);
  final ids = nodo.getSemanticsData().customSemanticsActionIds ?? const [];
  final id = ids.firstWhere((i) => CustomSemanticsAction.getAction(i)!.label == etiqueta);
  RendererBinding.instance.rootPipelineOwner.semanticsOwner!.performAction(nodo.id, SemanticsAction.customAction, id);
}

void main() {
  group('FilaDeslizable', () {
    for (final reducir in [false, true]) {
      testWidgets('arrastrar pasa el umbral, vibra una vez y revela la acción (reducir=$reducir)', (t) async {
        var quitar = 0, vibro = 0;
        await _montar(
          t,
          FilaDeslizable(
            retroHaptica: () => vibro++,
            accionesFin: [AccionGesto(etiqueta: 'Quitar', icono: Icons.delete, destructiva: true, alEjecutar: () => quitar++)],
            accionesInicio: [AccionGesto(etiqueta: 'Compartir', icono: Icons.share, alEjecutar: () {})],
            hijo: const SizedBox(height: 80, width: double.infinity, child: Text('contenido')),
          ),
          reducir: reducir,
        );
        expect(find.byKey(const Key('accion-Quitar')), findsNothing);
        final g = await t.startGesture(t.getCenter(find.text('contenido')));
        await g.moveBy(const Offset(-30, 0));
        await g.moveBy(const Offset(-30, 0));
        await g.moveBy(const Offset(-30, 0));
        await g.moveBy(const Offset(-60, 0)); // cruza y sigue: sigue siendo una sola vibración
        expect(vibro, 1);
        await g.up();
        await _avanzar(t);
        expect(find.byKey(const Key('accion-Quitar')), findsOneWidget);
        final caja = t.getSize(find.byKey(const Key('accion-Quitar')));
        expect(caja.width, greaterThanOrEqualTo(44));
        expect(caja.height, greaterThanOrEqualTo(44));
        await t.tap(find.byKey(const Key('accion-Quitar')));
        await _avanzar(t);
        expect(quitar, 1);
        expect(find.byKey(const Key('accion-Quitar')), findsNothing, reason: 'vuelve a cerrarse');
      });
    }

    testWidgets('un arrastre corto vuelve a cerrarse sin vibrar', (t) async {
      var vibro = 0;
      await _montar(
        t,
        FilaDeslizable(
          retroHaptica: () => vibro++,
          accionesFin: [AccionGesto(etiqueta: 'Quitar', icono: Icons.delete, alEjecutar: () {})],
          hijo: const SizedBox(height: 80, width: double.infinity, child: Text('contenido')),
        ),
      );
      await t.drag(find.text('contenido'), const Offset(-20, 0));
      await _avanzar(t);
      expect(vibro, 0);
      expect(find.byKey(const Key('accion-Quitar')), findsNothing);
    });

    testWidgets('la resistencia cede más allá del tope y nunca se corta en seco', (t) async {
      expect(FilaDeslizable.aplicarResistencia(50, 76), 50);
      final a = FilaDeslizable.aplicarResistencia(150, 76);
      final b = FilaDeslizable.aplicarResistencia(300, 76);
      expect(a, lessThan(150));
      expect(a, greaterThan(76));
      expect(b, greaterThan(a));
      expect(b - a, lessThan(150));
      expect(FilaDeslizable.aplicarResistencia(-150, 76), -a);
    });

    testWidgets('sin gesto: la acción sale en el lector de pantalla', (t) async {
      final h = t.ensureSemantics();
      var hecho = 0;
      await _montar(
        t,
        FilaDeslizable(
          etiquetaSemantica: 'Fila de prueba',
          accionesInicio: [AccionGesto(etiqueta: 'Compartir', icono: Icons.share, alEjecutar: () => hecho++)],
          hijo: const SizedBox(height: 80, width: double.infinity, child: Text('contenido')),
        ),
      );
      _accionDeLector(t, find.byType(FilaDeslizable), 'Compartir');
      await _avanzar(t);
      expect(hecho, 1);
      h.dispose();
    });
  });

  group('MenuMantenido', () {
    Widget menu({List<String>? hechas, WidgetBuilder? peek}) => Center(
          child: MenuMantenido(
            etiqueta: 'Tarjeta',
            vistaPrevia: peek,
            acciones: [
              AccionGesto(etiqueta: 'Compartir', icono: Icons.share, alEjecutar: () => hechas?.add('compartir')),
              AccionGesto(etiqueta: 'Borrar', icono: Icons.delete, destructiva: true, alEjecutar: () => hechas?.add('borrar')),
              AccionGesto(etiqueta: 'Abrir', icono: Icons.open_in_new, alEjecutar: () => hechas?.add('abrir')),
            ],
            child: Container(width: 200, height: 80, color: Colors.white, alignment: Alignment.center, child: const Text('tarjeta')),
          ),
        );

    for (final reducir in [false, true]) {
      testWidgets('mantener abre el menú, elegir ejecuta y cierra; lo destructivo va al final (reducir=$reducir)', (t) async {
        final hechas = <String>[];
        await _montar(t, menu(hechas: hechas), reducir: reducir);
        await t.longPress(find.text('tarjeta'));
        await _avanzar(t);
        expect(find.byKey(const Key('menu-Compartir')), findsOneWidget);
        final ys = [for (final k in ['Compartir', 'Abrir', 'Borrar']) t.getTopLeft(find.byKey(Key('menu-$k'))).dy];
        expect(ys, orderedEquals([...ys]..sort()), reason: 'Borrar queda debajo de las demás');
        for (final k in ['Compartir', 'Abrir', 'Borrar']) {
          expect(t.getSize(find.byKey(Key('menu-$k'))).height, greaterThanOrEqualTo(44));
        }
        await t.tap(find.byKey(const Key('menu-Compartir')));
        await _avanzar(t);
        expect(hechas, ['compartir']);
        expect(find.byKey(const Key('menu-Compartir')), findsNothing);
      });
    }

    testWidgets('Esc cierra y tocar fuera cierra, sin ejecutar nada', (t) async {
      final hechas = <String>[];
      await _montar(t, menu(hechas: hechas));
      await t.longPress(find.text('tarjeta'));
      await _avanzar(t);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await _avanzar(t);
      expect(find.byKey(const Key('menu-Compartir')), findsNothing);
      await t.longPress(find.text('tarjeta'));
      await _avanzar(t);
      await t.tapAt(const Offset(10, 10));
      await _avanzar(t);
      expect(find.byKey(const Key('menu-Compartir')), findsNothing);
      expect(hechas, isEmpty);
    });

    testWidgets('teclado: flechas y Intro eligen', (t) async {
      final hechas = <String>[];
      await _montar(t, menu(hechas: hechas));
      await t.longPress(find.text('tarjeta'));
      await _avanzar(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await _avanzar(t);
      expect(hechas, ['abrir']);
    });

    testWidgets('clic derecho (ratón) abre el menú', (t) async {
      await _montar(t, menu());
      final g = await t.startGesture(t.getCenter(find.text('tarjeta')), kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await g.up();
      await _avanzar(t);
      expect(find.byKey(const Key('menu-Compartir')), findsOneWidget);
    });

    testWidgets('se elige sin levantar el dedo: deslizar sobre la fila y soltar', (t) async {
      final hechas = <String>[];
      await _montar(t, menu(hechas: hechas));
      final g = await t.startGesture(t.getCenter(find.text('tarjeta')));
      await t.pump(const Duration(milliseconds: 500));
      await _avanzar(t, 6);
      expect(find.byKey(const Key('menu-Abrir')), findsOneWidget);
      await g.moveTo(t.getCenter(find.byKey(const Key('menu-Abrir'))) - const Offset(0, 60));
      await g.moveTo(t.getCenter(find.byKey(const Key('menu-Abrir'))));
      await g.up();
      await _avanzar(t);
      expect(hechas, ['abrir']);
    });

    testWidgets('con vista previa: se muestra el peek y el menú debajo', (t) async {
      await _montar(t, menu(peek: (_) => const SizedBox(height: 120, child: Text('vista previa'))));
      await t.longPress(find.text('tarjeta'));
      await _avanzar(t);
      expect(find.byKey(const Key('peek')), findsOneWidget);
      expect(find.text('vista previa'), findsOneWidget);
      expect(t.getTopLeft(find.byKey(const Key('menu-Compartir'))).dy, greaterThan(t.getBottomLeft(find.byKey(const Key('peek'))).dy));
    });

    testWidgets('sin gesto: acciones del lector de pantalla', (t) async {
      final h = t.ensureSemantics();
      final hechas = <String>[];
      await _montar(t, menu(hechas: hechas));
      _accionDeLector(t, find.byType(MenuMantenido), 'Abrir');
      await _avanzar(t);
      expect(hechas, ['abrir']);
      h.dispose();
    });

    test('la pista de mantener solo se pone si cabe entera', () {
      expect(colocarPista(debajo: 100, arribaAncla: 60, alto: 30, limite: 400, minimo: 20), 100);
      expect(colocarPista(debajo: 390, arribaAncla: 200, alto: 30, limite: 400, minimo: 20), 166);
      expect(colocarPista(debajo: 390, arribaAncla: 30, alto: 30, limite: 400, minimo: 20), isNull);
    });
  });

  group('TirarActualizar', () {
    Widget lista(void Function() cuenta) => TirarActualizar(
          alActualizar: () async => cuenta(),
          child: ListView(children: [for (var i = 0; i < 4; i++) SizedBox(height: 80, child: Text('fila $i'))]),
        );

    for (final reducir in [false, true]) {
      testWidgets('tirar más allá del umbral actualiza una vez (reducir=$reducir)', (t) async {
        var n = 0;
        await _montar(t, lista(() => n++), reducir: reducir);
        await t.drag(find.text('fila 0'), const Offset(0, 320));
        await _avanzar(t, 12);
        expect(n, 1);
        await _cerrar(t);
      });
    }

    testWidgets('un tirón corto no actualiza', (t) async {
      var n = 0;
      await _montar(t, lista(() => n++));
      await t.drag(find.text('fila 0'), const Offset(0, 40));
      await _avanzar(t, 12);
      expect(n, 0);
      await _cerrar(t);
    });

    testWidgets('sin gesto: «Actualizar» en el lector de pantalla', (t) async {
      final h = t.ensureSemantics();
      var n = 0;
      await _montar(t, lista(() => n++));
      _accionDeLector(t, find.byType(TirarActualizar), 'Actualizar');
      await _avanzar(t);
      expect(n, 1);
      await _cerrar(t);
      h.dispose();
    });
  });

  testWidgets('BandejaAcciones: botones de ≥ 44 px que hacen lo mismo que el gesto', (t) async {
    var a = 0, r = 0;
    await _montar(
      t,
      BandejaAcciones(acciones: [
        AccionGesto(etiqueta: 'Aprobar', icono: Icons.check, alEjecutar: () => a++),
        AccionGesto(etiqueta: 'Rechazar', icono: Icons.close, destructiva: true, alEjecutar: () => r++),
      ]),
      tam: const Size(360, 800),
    );
    expect(t.getSize(find.byKey(const Key('bandeja-Aprobar'))).height, greaterThanOrEqualTo(44));
    await t.tap(find.byKey(const Key('bandeja-Aprobar')));
    await t.tap(find.byKey(const Key('bandeja-Rechazar')));
    expect(a, 1);
    expect(r, 1);
  });

  for (final reducir in [false, true]) {
    testWidgets('RutaBorde: se vuelve deslizando desde el borde izquierdo (reducir=$reducir)', (t) async {
      await t.pumpWidget(MaterialApp(
        theme: temaZanky(),
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reducir), child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => abrirConBorde<void>(context, (_) => const Scaffold(body: Center(child: Text('segunda')))),
                child: const Text('ir'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('ir'));
      await _avanzar(t, 8, 100);
      expect(find.text('segunda'), findsOneWidget);
      await t.dragFrom(const Offset(4, 300), const Offset(500, 0));
      await _avanzar(t, 10, 100);
      expect(find.text('segunda'), findsNothing);
      expect(find.text('ir'), findsOneWidget);
    });
  }

  group('Panel CRA', () {
    ControladorAdmin controlador() {
      final c = ControladorAdmin(servidor: Servidor(base: '', anon: ''), cada: Duration.zero);
      c.entrarDemo(semilla: reportesDemo(DateTime.now()));
      return c;
    }

    Future<ControladorAdmin> montar(WidgetTester t, Size tam, {bool reducir = false}) async {
      SharedPreferences.setMockInitialValues({});
      final c = controlador();
      await _montar(t, AdminScope(controlador: c, child: BandejaAdmin(controlador: c)), tam: tam, reducir: reducir);
      await _avanzar(t, 6, 250);
      return c;
    }

    for (final reducir in [false, true]) {
      testWidgets('deslizar a la derecha aprueba y deja Deshacer (reducir=$reducir)', (t) async {
        final c = await montar(t, const Size(390, 844), reducir: reducir);
        final tarjeta = find.byType(TarjetaAdmin).first;
        await t.drag(tarjeta, const Offset(220, 0));
        await _avanzar(t);
        await t.tap(find.byKey(const Key('accion-Aprobar')).first);
        await _avanzar(t);
        expect(c.pendiente?.accion, AccionAdmin.aprobar);
        c.deshacer();
        expect(c.pendiente, isNull);
        c.salir();
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 30));
      });
    }

    testWidgets('atajos: j mueve, a aprueba; en 1280x800 hay botones a la vista', (t) async {
      final c = await montar(t, const Size(1280, 800));
      expect(find.text('Atajos: J / K moverse · A aprobar · R rechazar'), findsOneWidget);
      expect(find.byKey(const Key('bandeja-Aprobar')), findsWidgets, reason: 'nada depende solo del gesto');
      await t.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await _avanzar(t, 3);
      await t.sendKeyEvent(LogicalKeyboardKey.keyA);
      await _avanzar(t, 3);
      expect(c.pendiente?.accion, AccionAdmin.aprobar);
      c.salir();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 30));
    });

    testWidgets('en 360x800 no se pintan botones (el gesto y el menú los reemplazan) y el menú sale al mantener', (t) async {
      final c = await montar(t, const Size(360, 800));
      expect(find.byKey(const Key('bandeja-Aprobar')), findsNothing);
      await t.longPress(find.byType(TarjetaAdmin).first);
      await _avanzar(t);
      expect(find.byKey(const Key('menu-Aprobar')), findsOneWidget);
      expect(find.byKey(const Key('menu-Rechazar')), findsOneWidget);
      expect(find.byKey(const Key('peek')), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await _avanzar(t);
      c.salir();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 30));
    });
  });
}
