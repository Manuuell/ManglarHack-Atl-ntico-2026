import 'dart:convert';
import 'dart:io' show File, Directory, FileSystemException;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'almacen_fotos.dart';
import 'metadatos_foto.dart';

/// Guarda la foto de la evidencia en el teléfono hasta que se envíe; después deja solo
/// una miniatura (lo que necesitan «Mis reportes» y el detalle) y borra la foto completa.
///
/// En Android va a un archivo en la carpeta privada de la app. En la versión web (la demo
/// y el QR para turistas) no hay archivos: va a IndexedDB (cientos de MB; antes era
/// localStorage, ~5 MB por sitio, y con 2-3 fotos se llenaba), reducida antes por
/// image_picker (lado mayor 1600 px, JPEG 78). Aun así, quedarse sin espacio es posible:
/// se avisa con [ErrorAlGuardar] y el borrador (con su texto) sigue abierto.
///
/// Lo que versiones anteriores dejaron en localStorage se sigue leyendo y se pasa a
/// IndexedDB al arrancar ([migrarDeLocalStorage]).
///
/// Toda foto se guarda sin metadatos (sin GPS ni modelo del teléfono): ver
/// [quitarMetadatos].
class Fotos {
  static const prefijoWeb = 'foto:';

  /// Dónde van las fotos en la web (IndexedDB). Null en nativo. Las pruebas ponen uno en
  /// memoria.
  static AlmacenFotos? almacen = AlmacenFotos.delSistema();

  /// Ancho de la miniatura que queda en el teléfono cuando el reporte ya llegó.
  static const anchoMiniatura = 200;

  static String huella(Uint8List bytes) => sha256.convert(bytes).toString();

  /// Guarda la foto (ya sin metadatos) y devuelve la referencia local. Si no hay espacio
  /// lanza [ErrorAlGuardar] con `sinEspacio: true` y no deja nada a medias.
  static Future<String> guardar(String reporteId, Uint8List bytes) async {
    final limpia = quitarMetadatos(bytes);
    final clave = '$prefijoWeb$reporteId';
    final alm = almacen;
    if (alm != null) {
      try {
        await alm.guardar(clave, limpia);
      } catch (e) {
        try {
          await alm.borrar(clave);
        } catch (_) {}
        throw ErrorAlGuardar.de(e, conFoto: true);
      }
      return clave;
    }
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      try {
        final ok = await prefs.setString(clave, base64Encode(limpia));
        if (!ok) throw const ErrorAlGuardar('El navegador no guardó la foto.');
      } catch (e) {
        // shared_preferences ya dejó la foto en su caché aunque el navegador no la guardó:
        // se quita para que nadie la lea como si estuviera.
        try {
          await prefs.remove(clave);
        } catch (_) {}
        throw ErrorAlGuardar.de(e, conFoto: true);
      }
      return clave;
    }
    final f = File('${(await _carpeta()).path}/$reporteId.jpg');
    try {
      await f.parent.create(recursive: true);
      await f.writeAsBytes(limpia, flush: true);
    } catch (e) {
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
      throw ErrorAlGuardar.de(e, conFoto: true);
    }
    return f.path;
  }

  static Future<Directory> _carpeta() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/fotos');

  static Future<Uint8List?> leer(String? ref) async {
    if (ref == null) return null;
    try {
      if (ref.startsWith(prefijoWeb)) {
        final alm = almacen;
        if (alm != null) {
          final b = await alm.leer(ref);
          if (b != null) return b;
        }
        // Foto que aún quedó en localStorage (de una versión anterior o sin migrar).
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

  /// Borra la foto local. Nunca lanza: lo peor es que quede un archivo de más.
  static Future<void> borrar(String? ref) async {
    if (ref == null) return;
    try {
      if (ref.startsWith(prefijoWeb)) {
        try {
          await almacen?.borrar(ref);
        } catch (_) {}
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(ref);
        return;
      }
      if (kIsWeb) return;
      final f = File(ref);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Cambia la foto completa por una miniatura de [anchoMiniatura] px (PNG, sin metadatos)
  /// y devuelve la referencia nueva, o null si no quedó nada (la foto ya no estaba o no
  /// se pudo reducir: en ese caso se borra igual, porque la completa ya está en la CRA).
  static Future<String?> reducir(String ref) async {
    final bytes = await leer(ref);
    Uint8List? mini;
    if (bytes != null) {
      try {
        mini = await hacerMiniatura(bytes, anchoMiniatura);
      } catch (_) {
        mini = null;
      }
    }
    if (mini == null) {
      await borrar(ref);
      return null;
    }
    try {
      if (ref.startsWith(prefijoWeb)) {
        final alm = almacen;
        if (alm != null) {
          await alm.guardar(ref, mini);
          // Si la foto completa seguía en localStorage, ya no hace falta.
          final prefs = await SharedPreferences.getInstance();
          if (prefs.containsKey(ref)) await prefs.remove(ref);
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(ref, base64Encode(mini));
        }
        return ref;
      }
      if (kIsWeb) return null;
      final nuevo = '${ref.replaceFirst(RegExp(r'\.jpg$'), '')}.min.png';
      await File(nuevo).writeAsBytes(mini, flush: true);
      if (nuevo != ref) await File(ref).delete();
      return nuevo;
    } catch (_) {
      await borrar(ref);
      return null;
    }
  }

  /// Cómo se hace la miniatura. Por defecto, con el decodificador del motor de Flutter
  /// (Dart no trae codificador JPEG, así que sale en PNG; a 200 px pesa unas decenas de KB).
  /// Las pruebas la cambian para no depender del motor.
  @visibleForTesting
  static Future<Uint8List?> Function(Uint8List bytes, int ancho) hacerMiniatura = miniaturaConMotor;

  /// La miniatura hecha por el motor de Flutter (PNG de [ancho] px de ancho).
  static Future<Uint8List?> miniaturaConMotor(Uint8List bytes, int ancho) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: ancho);
    try {
      final cuadro = await codec.getNextFrame();
      final img = cuadro.image;
      try {
        final datos = await img.toByteData(format: ui.ImageByteFormat.png);
        return datos?.buffer.asUint8List();
      } finally {
        img.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  /// Web: pasa a IndexedDB las fotos que versiones anteriores dejaron en localStorage, sin
  /// perder ninguna: cada una se copia, se comprueba que quedó igual y solo entonces se
  /// quita de localStorage. Si una no cabe o falla, se queda donde estaba (y se lee de ahí)
  /// y se reintenta en el próximo arranque. Nunca lanza. Devuelve cuántas movió.
  static Future<int> migrarDeLocalStorage() async {
    final alm = almacen;
    if (alm == null) return 0;
    var movidas = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().toList()) {
        if (!k.startsWith(prefijoWeb)) continue;
        try {
          final texto = prefs.getString(k);
          if (texto == null) continue;
          final bytes = base64Decode(texto);
          await alm.guardar(k, bytes);
          final vuelta = await alm.leer(k);
          if (vuelta == null || vuelta.length != bytes.length) {
            await alm.borrar(k);
            continue;
          }
          await prefs.remove(k);
          movidas++;
        } catch (e) {
          debugPrint('Zanky: no pude mover la foto $k a IndexedDB: $e');
        }
      }
    } catch (_) {}
    return movidas;
  }

  /// Web: borra las fotos guardadas que ningún reporte usa (quedan cuando un guardado
  /// falló a medias, o de versiones viejas de la app). Se llama solo cuando falta espacio,
  /// porque otra pestaña podría estar guardando una en ese mismo instante. Devuelve cuántas
  /// borró.
  static Future<int> borrarHuerfanasWeb(Set<String> enUso) async {
    if (!kIsWeb && almacen == null) return 0;
    var n = 0;
    try {
      final alm = almacen;
      if (alm != null) {
        for (final k in await alm.claves()) {
          if (k.startsWith(prefijoWeb) && !enUso.contains(k)) {
            await alm.borrar(k);
            n++;
          }
        }
      }
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().toList()) {
        if (k.startsWith(prefijoWeb) && !enUso.contains(k)) {
          await prefs.remove(k);
          n++;
        }
      }
    } catch (_) {}
    return n;
  }
}

/// No se pudo guardar en el teléfono o en el navegador. [mensaje] se le puede mostrar a la
/// persona tal cual. Nada quedó a medias: el borrador sigue abierto y se puede reintentar.
class ErrorAlGuardar implements Exception {
  const ErrorAlGuardar(this.mensaje, {this.sinEspacio = false, this.causa});

  /// Arma el error a partir de lo que lanzó el sistema, reconociendo la falta de espacio.
  factory ErrorAlGuardar.de(Object e, {bool conFoto = false}) {
    if (e is ErrorAlGuardar) return e;
    final donde = kIsWeb ? 'este navegador' : 'el teléfono';
    if (esFaltaDeEspacio(e)) {
      return ErrorAlGuardar(
        conFoto
            ? 'No queda espacio en $donde para guardar la foto. Puedes guardar el reporte sin foto, '
                'o enviar o borrar reportes pendientes y reintentar.'
            : 'No queda espacio en $donde para guardar el reporte. Envía o borra reportes pendientes y reintenta.',
        sinEspacio: true,
        causa: e,
      );
    }
    return ErrorAlGuardar('No pude guardar el reporte en $donde. No se perdió nada: puedes reintentar.', causa: e);
  }

  final String mensaje;
  final bool sinEspacio;
  final Object? causa;

  @override
  String toString() => mensaje;
}

/// ¿El error es por falta de espacio? (QuotaExceededError del navegador, o disco lleno.)
bool esFaltaDeEspacio(Object e) {
  if (e is FileSystemException && (e.osError?.errorCode == 28 || e.osError?.errorCode == 112)) return true;
  final t = e.toString().toLowerCase();
  return t.contains('quota') || t.contains('no space left') || t.contains('enospc') || t.contains('disk full');
}
