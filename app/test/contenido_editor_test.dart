import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/vistas/contenido/modelo_contenido.dart';

void main() {
  test('agregar, reordenar, ocultar y deshacer preservan el documento', () {
    final borrador = BorradorContenido(const DocumentoContenido(
      clave: 'principal', ambito: 'evento:prueba', bloques: [],
    ));
    borrador.agregar(const Bloque(id: 'a', tipo: 'titulo', texto: 'Uno'));
    borrador.agregar(const Bloque(id: 'b', tipo: 'texto', texto: 'Dos'));
    borrador.reordenar(0, 2);
    expect(borrador.actual.bloques.map((b) => b.id), ['b', 'a']);
    borrador.editar('a', oculto: true);
    expect(borrador.actual.bloques.last.oculto, isTrue);
    borrador.deshacer();
    expect(borrador.actual.bloques.last.oculto, isFalse);
    borrador.deshacer();
    expect(borrador.actual.bloques.map((b) => b.id), ['a', 'b']);
  });

  test('JSON fijo conserva bloques y publicación', () {
    final documento = DocumentoContenido.desdeJson({
      'clave': 'principal', 'ambito': 'global', 'publicado': true, 'version': 3,
      'bloques': [
        {'id': 'a', 'tipo': 'lista', 'texto': 'Mangle rojo\nMangle negro', 'oculto': false},
        {'id': 'b', 'tipo': 'boton', 'texto': 'Saber más', 'url': 'https://ejemplo.org'},
      ],
    });
    expect(documento.bloques.length, 2);
    expect(DocumentoContenido.desdeJson(documento.toJson()).version, 3);
    expect(documento.publicado, isTrue);
    expect(() => Bloque.desdeJson({'id': 'x', 'tipo': 'html'}), throwsFormatException);
  });
}
