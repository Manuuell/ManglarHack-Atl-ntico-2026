import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/vistas/contenido/bloques_contenido.dart';
import 'package:zanky/vistas/contenido/editor_contenido.dart';
import 'package:zanky/vistas/contenido/modelo_contenido.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [const Size(360, 800), const Size(390, 844)]) {
    testWidgets('editor y vista previa caben en ${size.width}x${size.height}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: EditorContenido(ambito: 'global')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar bloque'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('título').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vista previa').first);
      await tester.pumpAndSettle();
      expect(find.text('Vista previa en vivo'), findsOneWidget);
      expect(find.byType(PintarBloques), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pintor público oculta bloques marcados en ${size.width}x${size.height}', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: PintarBloques(bloques: [
          Bloque(id: '1', tipo: 'titulo', texto: 'Visible'),
          Bloque(id: '2', tipo: 'aviso', texto: 'Oculto', oculto: true),
        ]),
      ))));
      expect(find.text('Visible'), findsOneWidget);
      expect(find.text('Oculto'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
