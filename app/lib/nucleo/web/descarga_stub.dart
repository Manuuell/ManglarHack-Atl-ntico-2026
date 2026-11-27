import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

const bool descargaDirecta = false;

Future<void> guardarArchivo(Uint8List bytes, {required String nombre, required String mime}) async {
  await SharePlus.instance.share(
    ShareParams(files: [XFile.fromData(bytes, mimeType: mime, name: nombre)], fileNameOverrides: [nombre], subject: nombre),
  );
}
