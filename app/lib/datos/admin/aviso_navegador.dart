import 'aviso_navegador_nada.dart' if (dart.library.js_interop) 'aviso_navegador_web.dart' as impl;

/// Avisos del navegador (Notification API) para el panel de la CRA en la web.
///
/// Solo funcionan si la persona los activa a mano ([pedirPermiso] se llama desde un toque,
/// que es lo que exigen los navegadores) y solo mientras la pestaña está abierta. En el
/// teléfono no hace nada: allí el aviso es el de dentro de la app. Las pruebas lo
/// reemplazan por una subclase.
class AvisoNavegador {
  AvisoNavegador();

  /// ¿Las notificaciones del navegador existen aquí? (Falso en el teléfono.)
  bool get disponible => impl.disponible();

  /// ¿El navegador las tiene bloqueadas? Si sí, no se puede volver a preguntar desde la app.
  bool get bloqueado => impl.permiso() == 'denied';

  /// El admin las encendió en esta sesión y el navegador lo permitió.
  bool activo = false;

  /// Pide permiso (muestra el cuadro del navegador). Verdadero si quedó concedido.
  Future<bool> pedirPermiso() => impl.pedirPermiso();

  void mostrar(String titulo, String cuerpo) => impl.mostrar(titulo, cuerpo);
}
