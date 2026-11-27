import 'dart:js_interop';

@JS('window.open')
external JSAny? _windowOpen(JSString url, JSString destino, JSString rasgos);

/// Abre [url] en otra pestaña sin pasarle la ventana de origen (`noopener`).
void abrirEnlace(String url) => _windowOpen(url.toJS, '_blank'.toJS, 'noopener,noreferrer'.toJS);
