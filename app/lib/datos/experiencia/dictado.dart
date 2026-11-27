import 'dictado_stub.dart' if (dart.library.js_interop) 'dictado_web.dart' as plataforma;

/// Dictado por voz del navegador (Web Speech API, `es-CO`). En el teléfono y en pruebas no hay dictado.
abstract class Dictado {
  bool get disponible;

  /// Escucha una frase y devuelve el texto (null si se canceló, no se entendió o no hubo permiso).
  Future<String?> escuchar();

  void detener();
}

Dictado crearDictado() => plataforma.crearDictado();
