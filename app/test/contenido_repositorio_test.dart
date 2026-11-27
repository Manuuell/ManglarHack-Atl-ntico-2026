import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/vistas/contenido/modelo_contenido.dart';
import 'package:zanky/vistas/contenido/repositorio_contenido.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('demostración mantiene publicación mientras se guarda un borrador', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = RepositorioContenido(servidor: Servidor(base: '', anon: ''));
    final base = const DocumentoContenido(clave: 'principal', ambito: 'global',
      bloques: [Bloque(id: 'a', tipo: 'titulo', texto: 'Publicado')]);
    final publicado = await repo.guardar(base, publicar: true);
    expect((await repo.cargar('principal', 'global'))?.bloques.single.texto, 'Publicado');
    await repo.guardar(publicado.copiar(bloques: const [
      Bloque(id: 'a', tipo: 'titulo', texto: 'En edición'),
    ]), publicar: false);
    expect((await repo.cargar('principal', 'global', editor: true))?.bloques.single.texto, 'En edición');
    expect((await repo.cargar('principal', 'global'))?.bloques.single.texto, 'Publicado');
    expect((await repo.versiones('principal', 'global')).length, 2);
    repo.cerrar();
  });
}
