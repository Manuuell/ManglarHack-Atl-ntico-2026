import 'dart:typed_data';

import 'almacen_fotos_nativo.dart' if (dart.library.js_interop) 'almacen_fotos_web.dart' as plataforma;

/// Dónde se guardan las fotos de los reportes pendientes en la web: un almacén de clave →
/// bytes. En el navegador es IndexedDB (cientos de MB; localStorage solo da ~5 MB por sitio y
/// con 2-3 fotos se llenaba). Las pruebas usan [AlmacenFotosMemoria].
abstract class AlmacenFotos {
  /// El almacén de esta plataforma: IndexedDB en la web, null en nativo (ahí van archivos).
  static AlmacenFotos? delSistema() => plataforma.crearAlmacen();

  /// Guarda [bytes] bajo [clave]. Si no hay espacio o el navegador lo niega, lanza el error
  /// (sin dejar nada a medias).
  Future<void> guardar(String clave, Uint8List bytes);

  Future<Uint8List?> leer(String clave);

  Future<void> borrar(String clave);

  Future<List<String>> claves();
}

/// Almacén en memoria: doble de pruebas, con un tope opcional para simular «lleno».
class AlmacenFotosMemoria implements AlmacenFotos {
  AlmacenFotosMemoria({this.capacidad});

  /// Bytes máximos en total (null = sin tope).
  int? capacidad;
  final Map<String, Uint8List> datos = {};

  /// Pruebas: hace que la próxima escritura falle con este error.
  Object? fallarProximo;

  int get usados => datos.values.fold(0, (a, b) => a + b.length);

  @override
  Future<void> guardar(String clave, Uint8List bytes) async {
    final f = fallarProximo;
    if (f != null) {
      fallarProximo = null;
      throw f;
    }
    final otros = usados - (datos[clave]?.length ?? 0);
    if (capacidad != null && otros + bytes.length > capacidad!) {
      throw Exception('QuotaExceededError: el almacén está lleno');
    }
    datos[clave] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List?> leer(String clave) async => datos[clave];

  @override
  Future<void> borrar(String clave) async => datos.remove(clave);

  @override
  Future<List<String>> claves() async => datos.keys.toList();
}
