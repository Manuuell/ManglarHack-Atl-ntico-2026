import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/admin/controlador_admin.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/vistas/contenido/editor_contenido.dart';
import 'package:zanky/vistas/contenido/entrada_contenido.dart';
import 'package:zanky/vistas/contenido/estudio_contenido.dart';
import 'package:zanky/vistas/contenido/modelo_contenido.dart';
import 'package:zanky/vistas/contenido/repositorio_contenido.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el estudio marca cambios sin guardar y descartar vuelve a lo guardado', () {
    final e = EstudioContenido(const DocumentoContenido(clave: 'principal', ambito: 'global',
      bloques: [Bloque(id: 'a', tipo: 'titulo', texto: 'Uno')]));
    expect(e.sucio, isFalse);
    e.cambio((b) => b.editar('a', texto: 'Dos'));
    expect(e.sucio, isTrue);
    e.descartar();
    expect(e.sucio, isFalse);
    expect(e.actual.bloques.single.texto, 'Uno');
    e.cambio((b) => b.editar('a', texto: 'Tres'));
    e.alGuardar(e.actual.copiar(version: 2));
    expect(e.sucio, isFalse);
    expect(e.guardado.version, 2);
  });

  test('ámbito válido: solo global, evento o punto con código seguro', () {
    expect(ambitoContenidoValido('global'), isTrue);
    expect(ambitoContenidoValido('evento:jornada-1'), isTrue);
    expect(ambitoContenidoValido('evento:'), isFalse);
    expect(ambitoContenidoValido('evento:a b'), isFalse);
    expect(ambitoContenidoValido("evento:x'; drop"), isFalse);
    expect(ambitoContenidoValido('otro:x'), isFalse);
  });

  test('sin sesión de editor no se puede escribir en el servidor', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = RepositorioContenido(
      servidor: Servidor(base: 'https://ejemplo.invalid', anon: 'anon'), panel: ControladorAdmin());
    await expectLater(
      repo.guardar(const DocumentoContenido(clave: 'principal', ambito: 'evento:x', bloques: []), publicar: true),
      throwsA(isA<StateError>()));
    repo.cerrar();
  });

  for (final size in [const Size(390, 844), const Size(768, 1024), const Size(1280, 800)]) {
    testWidgets('editor por pasos con barra de guardado en ${size.width.toInt()}x${size.height.toInt()}', (t) async {
      SharedPreferences.setMockInitialValues({});
      await t.binding.setSurfaceSize(size);
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(MaterialApp(home: EditorContenido(ambito: 'evento:prueba',
        repositorio: RepositorioContenido(servidor: Servidor(base: '', anon: '')))));
      await t.pumpAndSettle();
      expect(find.text('Todo guardado'), findsOneWidget);
      await t.tap(find.text('Agregar bloque'));
      await t.pumpAndSettle();
      await t.tap(find.text('título').last);
      await t.pumpAndSettle();
      expect(find.text('Tienes cambios sin guardar'), findsOneWidget);
      expect(find.text('Descartar'), findsOneWidget);
      await t.tap(find.text('Guardar borrador'));
      await t.pumpAndSettle();
      expect(find.text('Todo guardado'), findsNothing);
      expect(find.textContaining('Borrador guardado'), findsOneWidget);
      if (size.width < 900) {
        await t.tap(find.text('Seguir con Vista previa'));
        await t.pumpAndSettle();
      }
      expect(find.text('Vista previa en vivo'), findsWidgets);
      expect(t.takeException(), isNull);
    });
  }
}
