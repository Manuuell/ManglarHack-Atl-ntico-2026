// La foto pierde el GPS y los demás metadatos sin perder la imagen ni la orientación.
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/datos/fotos.dart';
import 'package:zanky/datos/metadatos_foto.dart';

import 'servidor_contrato_test.dart' show jpegConGps;

/// Busca [aguja] (texto latin1) en los bytes.
bool contiene(Uint8List b, String aguja) => latin1.decode(b).contains(aguja);

/// Los marcadores de segmento de un JPEG hasta el escaneo.
List<int> marcadores(Uint8List b) {
  final m = <int>[];
  var i = 2;
  while (i + 4 <= b.length && b[i] == 0xFF) {
    final t = b[i + 1];
    m.add(t);
    if (t == 0xDA) break;
    i += 2 + ((b[i + 2] << 8) | b[i + 3]);
  }
  return m;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final original = base64Decode(jpegConGps);

  group('JPEG', () {
    test('la foto de prueba sí trae GPS, modelo, comentario y basura al final', () {
      expect(contiene(original, 'TelefonoX'), isTrue);
      expect(contiene(original, 'ModeloY'), isTrue);
      expect(contiene(original, 'Hecho en el manglar'), isTrue);
      expect(contiene(original, 'BASURA-DESPUES-DEL-FIN'), isTrue);
      expect(marcadores(original), contains(0xE1));
    });

    test('sale sin EXIF de GPS ni modelo, sin comentario y sin nada después del final', () {
      final limpia = quitarMetadatos(original);
      expect(contiene(limpia, 'TelefonoX'), isFalse);
      expect(contiene(limpia, 'ModeloY'), isFalse);
      expect(contiene(limpia, 'Hecho en el manglar'), isFalse);
      expect(contiene(limpia, 'BASURA'), isFalse);
      expect(limpia.sublist(limpia.length - 2), [0xFF, 0xD9]);
      expect(marcadores(limpia), isNot(contains(0xFE)));
    });

    test('conserva la orientación (6) en un EXIF de una sola etiqueta', () {
      final limpia = quitarMetadatos(original);
      final i = latin1.decode(limpia).indexOf('Exif\x00\x00');
      expect(i, greaterThan(0));
      // Tras «Exif\0\0»: MM, 42, IFD en 8, UNA entrada, etiqueta 0x0112 SHORT con valor 6.
      expect(limpia.sublist(i + 6, i + 6 + 20), [
        0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, 0x00, 0x01, //
        0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, 0x06,
      ]);
      expect(marcadores(limpia).where((m) => m == 0xE1).length, 1);
    });

    test('los datos de la imagen quedan idénticos', () {
      final limpia = quitarMetadatos(original);
      List<int> desdeSos(Uint8List b) {
        final s = latin1.decode(b);
        final i = s.indexOf('\xFF\xDA');
        final f = s.indexOf('\xFF\xD9', i);
        return b.sublist(i, f + 2);
      }

      expect(desdeSos(limpia), desdeSos(original));
    });

    test('limpiar dos veces da lo mismo (la huella no cambia)', () {
      final una = quitarMetadatos(original);
      expect(quitarMetadatos(una), una);
      expect(Fotos.huella(quitarMetadatos(una)), Fotos.huella(una));
    });

    test('el decodificador de Flutter la sigue abriendo (y gira: 16×8 pasa a 8×16)', () async {
      final codec = await ui.instantiateImageCodec(quitarMetadatos(original));
      final img = (await codec.getNextFrame()).image;
      expect([img.width, img.height], [8, 16]);
      img.dispose();
      codec.dispose();
    });

    test('la miniatura del motor sale en PNG', () async {
      final mini = await Fotos.miniaturaConMotor(quitarMetadatos(original), 4);
      expect(mini!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('un JPEG roto o un formato desconocido no se tocan', () {
      final roto = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1, 0x00]);
      expect(quitarMetadatos(roto), roto);
      final otro = Uint8List.fromList(utf8.encode('RIFF....WEBP'));
      expect(quitarMetadatos(otro), otro);
    });
  });

  group('PNG', () {
    Uint8List fragmento(String tipo, List<int> datos) {
      final b = BytesBuilder()
        ..add([datos.length >> 24, (datos.length >> 16) & 255, (datos.length >> 8) & 255, datos.length & 255])
        ..add(latin1.encode(tipo))
        ..add(datos)
        ..add([0, 0, 0, 0]); // CRC (no se revisa)
      return b.takeBytes();
    }

    test('quita eXIf y los textos; deja la imagen', () {
      final png = (BytesBuilder()
            ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
            ..add(fragmento('IHDR', List.filled(13, 1)))
            ..add(fragmento('eXIf', latin1.encode('MM GPS 11.05')))
            ..add(fragmento('tEXt', latin1.encode('Author\x00Fulana')))
            ..add(fragmento('IDAT', [1, 2, 3]))
            ..add(fragmento('IEND', const [])))
          .takeBytes();
      final limpia = quitarMetadatos(png);
      expect(contiene(limpia, 'GPS'), isFalse);
      expect(contiene(limpia, 'Fulana'), isFalse);
      expect(contiene(limpia, 'IHDR'), isTrue);
      expect(contiene(limpia, 'IDAT'), isTrue);
      expect(contiene(limpia, 'IEND'), isTrue);
    });
  });
}
