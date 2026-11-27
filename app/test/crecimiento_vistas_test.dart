import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/crecimiento/progreso_crecimiento.dart';
import 'package:zanky/datos/guardian.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/vistas/crecimiento/pantalla_mi_manglar.dart';
import 'package:zanky/vistas/crecimiento/zanky_crece.dart';

Future<void> mostrar(WidgetTester tester, Widget hijo, {
  double ancho = 390, double alto = 844, double letra = 1,
  bool reducir = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(ancho, alto);
  await tester.pumpWidget(MaterialApp(home: MediaQuery(
    data: MediaQueryData(size: Size(ancho, alto),
      textScaler: TextScaler.linear(letra), disableAnimations: reducir),
    child: hijo,
  )));
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    // Cada prueba restaura las dimensiones de la ventana con addTearDown.
  });

  testWidgets('la evolución de una etapa se muestra una sola vez', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final clave = RegistroEvolucion.clave('guardian-1');
    SharedPreferences.setMockInitialValues({clave: 1});
    var celebraciones = 0;
    Widget arbol() => Scaffold(body: SingleChildScrollView(child: ZankyCrece(
      puntos: 60, nivel: 2, idGuardian: 'guardian-1',
      alEvolucionar: (_) => celebraciones++,
    )));
    await mostrar(tester, arbol());
    await tester.pump();
    expect(celebraciones, 1);
    expect(find.byKey(const Key('hojas-evolucion')), findsOneWidget);
    await tester.pumpAndSettle();
    await mostrar(tester, const SizedBox.shrink());
    await mostrar(tester, arbol());
    await tester.pumpAndSettle();
    expect(celebraciones, 1);
    expect((await SharedPreferences.getInstance()).getInt(clave), 2);
  });

  testWidgets('reducir movimiento usa fundido sin hojas ni resorte', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({RegistroEvolucion.clave('quieto'): 1});
    await mostrar(tester, const Scaffold(body: SingleChildScrollView(
      child: ZankyCrece(puntos: 60, nivel: 2, idGuardian: 'quieto'),
    )), reducir: true);
    await tester.pump();
    expect(find.byKey(const Key('hojas-evolucion')), findsNothing);
    final transformacion = tester.widget<Transform>(find.byKey(const Key('etapa-nueva')));
    expect(transformacion.transform.getMaxScaleOnAxis(), 1);
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.text('Plántula'), findsWidgets);
  });

  for (final ancho in const [360.0, 390.0, 768.0, 1280.0]) {
    for (final letra in const [1.0, 1.3]) {
      testWidgets('Mi manglar a ${ancho.toInt()} px y texto $letra', (tester) async {
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final alto = ancho == 360 ? 800.0 : ancho == 390 ? 844.0 : 800.0;
        await mostrar(tester, PantallaMiManglar(
          progreso: Progreso.de(const []), reportes: const [],
          servidor: Servidor(base: '', anon: ''),
          hora: DateTime(2026, 11, 27, 12),
        ), ancho: ancho, alto: alto, letra: letra);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Mi manglar'), findsOneWidget);
        expect(find.textContaining('Demostración'), findsOneWidget);
      });
    }
  }
}
