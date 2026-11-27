import 'dart:js_interop';

@JS('Notification')
external JSAny? get _notificacion;

@JS('Notification.permission')
external JSString? get _permiso;

@JS('Notification.requestPermission')
external JSPromise<JSString> _pedir();

@JS('Notification')
extension type _Aviso._(JSObject _) implements JSObject {
  external factory _Aviso(String titulo, JSObject opciones);
}

bool disponible() => _notificacion != null;

String permiso() => disponible() ? (_permiso?.toDart ?? 'default') : 'unsupported';

Future<bool> pedirPermiso() async {
  if (!disponible()) return false;
  if (permiso() == 'granted') return true;
  if (permiso() == 'denied') return false;
  try {
    final r = await _pedir().toDart;
    return r.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

void mostrar(String titulo, String cuerpo) {
  if (!disponible() || permiso() != 'granted') return;
  try {
    _Aviso(titulo, {'body': cuerpo, 'tag': 'zanky-panel-cra'}.jsify() as JSObject);
  } catch (_) {
    // Un navegador que no deja crearlo (p. ej. móvil sin service worker): el aviso de la app basta.
  }
}
