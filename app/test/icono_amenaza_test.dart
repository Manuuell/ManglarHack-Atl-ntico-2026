import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/datos/tipos.dart';
import 'package:zanky/nucleo/kit/icono_amenaza.dart';

/// Hoja con los 8 íconos: duotono a 24 y 56 px y monocromo sobre su disco de color.
Widget _hoja() => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: RepaintBoundary(
            key: const ValueKey('hoja'),
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final t in TipoAmenaza.values)
                        Padding(padding: const EdgeInsets.all(8), child: IconoAmenaza(t, tamano: 24)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final t in TipoAmenaza.values)
                        Container(
                          margin: const EdgeInsets.all(4),
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(color: t.color.withValues(alpha: 0.13), shape: BoxShape.circle),
                          child: Center(child: IconoAmenaza(t, tamano: 56)),
                        ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final t in TipoAmenaza.values)
                        Container(
                          margin: const EdgeInsets.all(6),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: t.color, shape: BoxShape.circle),
                          child: Center(child: IconoAmenaza(t, tamano: 22, color: Colors.white)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('todos los tipos tienen su ícono propio a 24 y 56 px', (tester) async {
    tester.view.physicalSize = const Size(1000, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_hoja());
    expect(find.byType(IconoAmenaza), findsNWidgets(TipoAmenaza.values.length * 3));
    for (final t in TipoAmenaza.values) {
      expect(find.byWidgetPredicate((w) => w is IconoAmenaza && w.tipo == t), findsNWidgets(3));
    }
    for (final tam in const [24.0, 56.0]) {
      final cajas = tester.widgetList<IconoAmenaza>(find.byType(IconoAmenaza)).where((w) => w.tamano == tam);
      expect(cajas.length, TipoAmenaza.values.length);
    }
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(const ValueKey('hoja')), matchesGoldenFile('goldens/iconos_amenaza.png'));
  });

  testWidgets('el gesto corre una vez, corto, y termina en reposo', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Center(child: IconoAmenaza(TipoAmenaza.quema, tamano: 56, animado: true))));
    await tester.pump(); // cuadro siguiente: arranca el gesto de aparición
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.hasRunningAnimations, isFalse);

    // Al tocar se repite.
    await tester.tap(find.byType(IconoAmenaza));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('con «reducir movimiento» se queda quieto', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: IconoAmenaza(TipoAmenaza.tala, tamano: 56, animado: true)),
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.tap(find.byType(IconoAmenaza));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('la ficha de reporte rápido anima el ícono, vibra y responde', (tester) async {
    var tocada = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: FichaAmenaza(tipo: TipoAmenaza.fauna, alTocar: () => tocada++)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fauna'), findsOneWidget);
    expect(find.bySemanticsLabel('Reportar Fauna afectada'), findsOneWidget);
    await tester.tap(find.byType(FichaAmenaza));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tocada, 1);
  });
}
