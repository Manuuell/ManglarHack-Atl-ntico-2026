import 'nfc_evento_stub.dart'
    if (dart.library.js_interop) 'nfc_evento_web.dart'
    as plataforma;

/// Permite sustituir el lector real por uno simulado en pruebas.
abstract class GrabadorNfc {
  bool get disponible;
  Future<void> grabar(String enlace);
}

GrabadorNfc crearGrabadorNfc() => plataforma.crearGrabadorNfc();
