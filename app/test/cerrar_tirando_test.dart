import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/nucleo/kit/cerrar_tirando.dart';

Widget _app(void Function() haptica) => MaterialApp(
  home: Builder(
    builder: (c) => TextButton(
      onPressed: () => Navigator.of(c).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: CerrarTirando(
              retroHaptica: haptica,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [SliverToBoxAdapter(child: SizedBox(height: 2000, child: Text('detalle')))],
              ),
            ),
          ),
        ),
      ),
      child: const Text('abrir'),
    ),
  ),
);

void main() {
  testWidgets('tirar poco y soltar no cierra ni vibra', (t) async {
    var golpes = 0;
    await t.pumpWidget(_app(() => golpes++));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    await t.dragFrom(const Offset(400, 200), const Offset(0, 60));
    await t.pumpAndSettle();
    expect(find.text('detalle'), findsOneWidget);
    expect(golpes, 0);
  });

  testWidgets('tirar más del umbral vibra una vez y al soltar cierra', (t) async {
    var golpes = 0;
    await t.pumpWidget(_app(() => golpes++));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    final g = await t.startGesture(const Offset(400, 200));
    for (var i = 0; i < 20; i++) {
      await g.moveBy(const Offset(0, 30));
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await t.pumpAndSettle();
    expect(golpes, 1);
    expect(find.text('detalle'), findsNothing);
  });
}
