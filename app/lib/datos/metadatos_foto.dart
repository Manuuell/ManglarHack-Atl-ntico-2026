import 'dart:typed_data';

/// Quita los metadatos de una foto (EXIF con GPS, XMP, IPTC, comentarios, imágenes extra
/// pegadas al final) sin volver a comprimirla: copia los mismos bytes de la imagen y deja
/// fuera solo los bloques de metadatos.
///
/// Por qué hace falta aunque image_picker reduzca la foto: en Android, al reducirla,
/// image_picker COPIA el EXIF original a la foto nueva, GPS incluido (ExifDataCopier de
/// image_picker_android). En la web el lienzo lo pierde, salvo que la reducción falle y
/// devuelva el archivo original. La foto va a un bucket y la revisa una IA: no debe llevar
/// el punto exacto ni el modelo del teléfono de quien denuncia.
///
/// La orientación es lo único que se conserva (en un EXIF mínimo, solo con esa etiqueta):
/// sin ella, una foto vertical de Android se vería acostada.
///
/// JPEG y PNG se limpian; cualquier otro formato se devuelve tal cual.
Uint8List quitarMetadatos(Uint8List b) {
  if (_esJpeg(b)) return _limpiarJpeg(b) ?? b;
  if (_esPng(b)) return _limpiarPng(b) ?? b;
  return b;
}

// ------------------------------------------------------------------------------- JPEG

bool _esJpeg(Uint8List b) => b.length > 4 && b[0] == 0xFF && b[1] == 0xD8;

/// Devuelve null si la estructura no se entiende (y entonces no se toca la foto).
Uint8List? _limpiarJpeg(Uint8List b) {
  final salida = BytesBuilder(copy: false);
  salida.add(const [0xFF, 0xD8]);
  var orientacion = 1;
  var i = 2;
  var exifPuesto = false;

  void ponerExifMinimo() {
    if (exifPuesto) return;
    exifPuesto = true;
    if (orientacion != 1) salida.add(_exifSoloOrientacion(orientacion));
  }

  while (i < b.length) {
    if (b[i] != 0xFF) return null;
    // Bytes de relleno 0xFF entre segmentos.
    while (i < b.length && b[i] == 0xFF) {
      i++;
    }
    if (i >= b.length) return null;
    final m = b[i];
    final inicio = i - 1;
    i++;
    if (m == 0xD9) {
      // Fin de la imagen sin escaneo: raro, pero válido. Se corta aquí.
      salida.add(const [0xFF, 0xD9]);
      return salida.takeBytes();
    }
    if ((m >= 0xD0 && m <= 0xD7) || m == 0x01) {
      salida.add(b.sublist(inicio, i));
      continue;
    }
    if (i + 1 >= b.length) return null;
    final largo = (b[i] << 8) | b[i + 1];
    if (largo < 2 || i + largo > b.length) return null;
    final fin = i + largo;
    if (m == 0xDA) {
      // Inicio del escaneo: desde aquí son los datos de la imagen hasta el primer FF D9
      // (en los datos, un FF real va seguido de 00 o de un RSTn). Lo que venga después
      // de FF D9 (fotos extra de «Multi-Picture», mapas de profundidad) se descarta.
      ponerExifMinimo();
      var j = fin;
      while (j + 1 < b.length && !(b[j] == 0xFF && b[j + 1] == 0xD9)) {
        j++;
      }
      if (j + 1 >= b.length) return null;
      salida.add(b.sublist(inicio, j + 2));
      return salida.takeBytes();
    }
    final datos = b.sublist(i + 2, fin);
    final conservar = switch (m) {
      0xE0 => true, // APP0 JFIF
      0xE2 => _empiezaCon(datos, 'ICC_PROFILE\x00'), // perfil de color sí; MPF/FlashPix no
      0xEE => true, // APP14 Adobe (dice cómo leer los colores)
      0xE1 => false, // APP1: EXIF (GPS, modelo, hora) y XMP
      0xFE => false, // comentario
      >= 0xE3 && <= 0xEF => false, // APP3..APP15: IPTC, Photoshop, Ducky, etc.
      _ => true, // tablas, cuadro, Huffman: la imagen en sí
    };
    if (m == 0xE1 && _empiezaCon(datos, 'Exif\x00\x00')) {
      orientacion = _leerOrientacion(datos, 6) ?? orientacion;
    }
    if (conservar) {
      // El EXIF mínimo va justo después de JFIF/Adobe y antes de las tablas de la imagen.
      if (m != 0xE0 && m != 0xEE && m != 0xE2) ponerExifMinimo();
      salida.add(b.sublist(inicio, fin));
    }
    i = fin;
  }
  return null;
}

bool _empiezaCon(Uint8List d, String s) {
  if (d.length < s.length) return false;
  for (var k = 0; k < s.length; k++) {
    if (d[k] != s.codeUnitAt(k)) return false;
  }
  return true;
}

/// Lee la etiqueta Orientation (0x0112) del IFD0 de un bloque TIFF que empieza en [base].
int? _leerOrientacion(Uint8List d, int base) {
  if (d.length < base + 8) return null;
  final bool little;
  if (d[base] == 0x49 && d[base + 1] == 0x49) {
    little = true;
  } else if (d[base] == 0x4D && d[base + 1] == 0x4D) {
    little = false;
  } else {
    return null;
  }
  int u16(int o) => little ? d[o] | (d[o + 1] << 8) : (d[o] << 8) | d[o + 1];
  int u32(int o) => little
      ? d[o] | (d[o + 1] << 8) | (d[o + 2] << 16) | (d[o + 3] << 24)
      : (d[o] << 24) | (d[o + 1] << 16) | (d[o + 2] << 8) | d[o + 3];
  final ifd = base + u32(base + 4);
  if (ifd + 2 > d.length) return null;
  final n = u16(ifd);
  for (var k = 0; k < n; k++) {
    final e = ifd + 2 + k * 12;
    if (e + 12 > d.length) return null;
    if (u16(e) == 0x0112) {
      final v = u16(e + 8);
      return v >= 1 && v <= 8 ? v : null;
    }
  }
  return null;
}

/// Un APP1 EXIF con una sola etiqueta: Orientation.
Uint8List _exifSoloOrientacion(int o) => Uint8List.fromList([
      0xFF, 0xE1, 0x00, 0x22, // marcador y largo (34)
      0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // «Exif\0\0»
      0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, // TIFF big-endian, IFD0 en 8
      0x00, 0x01, // una entrada
      0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, o, 0x00, 0x00, // Orientation SHORT = o
      0x00, 0x00, 0x00, 0x00, // sin más IFD
    ]);

// ------------------------------------------------------------------------------- PNG

const _firmaPng = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

bool _esPng(Uint8List b) {
  if (b.length < 8) return false;
  for (var k = 0; k < 8; k++) {
    if (b[k] != _firmaPng[k]) return false;
  }
  return true;
}

/// Fragmentos de PNG que solo llevan metadatos (EXIF, textos, hora).
const _fragmentosFuera = {'eXIf', 'tEXt', 'zTXt', 'iTXt', 'tIME'};

Uint8List? _limpiarPng(Uint8List b) {
  final salida = BytesBuilder(copy: false)..add(b.sublist(0, 8));
  var i = 8;
  while (i + 12 <= b.length) {
    final largo = (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
    final fin = i + 12 + largo;
    if (largo < 0 || fin > b.length) return null;
    final tipo = String.fromCharCodes(b.sublist(i + 4, i + 8));
    if (!_fragmentosFuera.contains(tipo)) salida.add(b.sublist(i, fin));
    i = fin;
    if (tipo == 'IEND') return salida.takeBytes();
  }
  return null;
}
