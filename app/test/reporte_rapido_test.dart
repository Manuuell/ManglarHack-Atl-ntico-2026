import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/datos/tipos.dart';
import 'package:zanky/vistas/inicio/reporte_rapido.dart';

/// Opacidad de la tarjeta [i] (la entrada es un `FadeTransition` con su clave).
double _opacidad(WidgetTester tester, int i) {
  final w = tester.widget(find.byKey(ReporteRapido.claveTarjeta(i)));
  return w is FadeTransition ? w.opacity.value : 1.0;
}

Widget _app({bool quieto = false, void Function(TipoAmenaza)? alElegir}) => MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: quieto, size: const Size(1280, 800)),
          child: Scaffold(body: ReporteRapido(alElegir: alElegir ?? (_) {})),
        ),
      ),
    );

void main() {
  testWidgets('las tarjetas entran una tras otra, desfasadas 70 ms con un solo reloj', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());

    // A los 100 ms: la primera ya se ve, la segunda empezó (sale a los 70) y la tercera no (sale a los 140).
    await tester.pump(const Duration(milliseconds: 100));
    final a = _opacidad(tester, 0), b = _opacidad(tester, 1), c = _opacidad(tester, 2);
    expect(a, greaterThan(b));
    expect(b, greaterThan(0));
    expect(c, 0);

    // Cada una va detrás de la anterior.
    await tester.pump(const Duration(milliseconds: 150));
    for (var i = 1; i < ReporteRapido.tiposRapidos.length; i++) {
      expect(_opacidad(tester, i - 1), greaterThanOrEqualTo(_opacidad(tester, i)));
    }

    // Termina todo visible y sin nada animándose (no deja relojes vivos).
    await tester.pumpAndSettle();
    for (var i = 0; i < ReporteRapido.tiposRapidos.length; i++) {
      expect(_opacidad(tester, i), 1);
    }
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('con «reducir movimiento» todo aparece quieto desde el primer cuadro', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(quieto: true));
    await tester.pump();

    for (var i = 0; i < ReporteRapido.tiposRapidos.length; i++) {
      expect(find.byKey(ReporteRapido.claveTarjeta(i)), findsOneWidget);
      expect(_opacidad(tester, i), 1);
    }
    expect(find.byType(FadeTransition).evaluate().where((e) => e.widget.key is ValueKey<String>), isEmpty);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('tocar una tarjeta elige su tipo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    TipoAmenaza? elegido;
    await tester.pumpWidget(_app(quieto: true, alElegir: (t) => elegido = t));
    await tester.tap(find.text(TipoAmenaza.quema.corto));
    await tester.pumpAndSettle();
    expect(elegido, TipoAmenaza.quema);
  });
}
