/// Guardar un archivo que la app trae de la red: en la web es una descarga de verdad (Blob y
/// enlace con `download`); en Android e iOS se abre el menú de compartir con el archivo, para
/// guardarlo en Archivos, mandarlo por WhatsApp o abrirlo en otra app.
library;

import 'dart:typed_data';

import 'descarga_stub.dart' if (dart.library.js_interop) 'descarga_web.dart' as plataforma;

/// `true` si en esta plataforma «Descargar» baja el archivo (web); `false` si lo comparte.
bool get descargaDirecta => plataforma.descargaDirecta;

/// Entrega [bytes] como un archivo llamado [nombre] con el tipo [mime].
Future<void> guardarArchivo(Uint8List bytes, {required String nombre, required String mime}) =>
    plataforma.guardarArchivo(bytes, nombre: nombre, mime: mime);
