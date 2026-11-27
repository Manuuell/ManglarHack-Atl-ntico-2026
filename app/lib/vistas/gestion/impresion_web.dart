import 'dart:js_interop';

@JS('window.open')
external JSAny? _abrirVentana(JSString url, JSString destino);

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSString> partes, JSObject opciones);
}

@JS('URL.createObjectURL')
external JSString _crearUrl(_Blob blob);

@JS('URL.revokeObjectURL')
external void _revocarUrl(JSString url);

bool get puedeImprimirCartel => true;

String _escapar(String texto) => texto.replaceAll('&', '&amp;').replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;').replaceAll('"', '&quot;');

void imprimirCartel(String titulo, String codigo, String imagenBase64) {
  final contenido = '''<!doctype html><html lang="es"><meta charset="utf-8">
<title>Cartel Punto Zanky</title><style>
@page{size:A4;margin:18mm}body{font-family:Arial,sans-serif;text-align:center;color:#123b35}
h1{font-size:36pt;margin:18mm 0 10mm}img{width:125mm;height:125mm;object-fit:contain}
p{font-size:18pt}small{font-size:12pt}
</style><body onload="window.print()"><h1>${_escapar(titulo)}</h1>
<img alt="Código QR del punto" src="data:image/png;base64,$imagenBase64">
<p>Escanea y descubre este punto del manglar</p><small>${_escapar(codigo)}</small></body></html>''';
  final opciones = {'type': 'text/html;charset=utf-8'}.jsify()! as JSObject;
  final url = _crearUrl(_Blob([contenido.toJS].toJS, opciones));
  _abrirVentana(url, '_blank'.toJS);
  Future<void>.delayed(const Duration(minutes: 1), () => _revocarUrl(url));
}
