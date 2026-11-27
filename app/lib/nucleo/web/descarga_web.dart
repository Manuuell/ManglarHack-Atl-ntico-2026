import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const bool descargaDirecta = true;

Future<void> guardarArchivo(Uint8List bytes, {required String nombre, required String mime}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = nombre
    ..style.display = 'none';
  web.document.body?.append(a);
  a.click();
  a.remove();
  // Se suelta después: algunos navegadores leen el Blob un instante más tarde.
  Future<void>.delayed(const Duration(seconds: 10), () => web.URL.revokeObjectURL(url));
}
