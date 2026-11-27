import 'dart:convert';
import 'dart:io' show File, Directory;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda la foto de la evidencia en el teléfono hasta que se envíe.
///
/// En Android va a un archivo en la carpeta privada de la app (nadie más la ve).
/// En la versión web (la demo y el QR para turistas) no hay archivos: va en el
/// almacenamiento del navegador, reducida antes por image_picker.
class Fotos {
  static const _prefijoWeb = 'foto:';

  static String huella(Uint8List bytes) => sha256.convert(bytes).toString();

  static Future<String> guardar(String reporteId, Uint8List bytes) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefijoWeb$reporteId', base64Encode(bytes));
      return '$_prefijoWeb$reporteId';
    }
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/fotos');
    await dir.create(recursive: true);
    final f = File('${dir.path}/$reporteId.jpg');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  static Future<Uint8List?> leer(String? ref) async {
    if (ref == null) return null;
    try {
      if (ref.startsWith(_prefijoWeb)) {
        final prefs = await SharedPreferences.getInstance();
        final b = prefs.getString(ref);
        return b == null ? null : base64Decode(b);
      }
      if (kIsWeb) return null;
      final f = File(ref);
      return await f.exists() ? await f.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }
}
