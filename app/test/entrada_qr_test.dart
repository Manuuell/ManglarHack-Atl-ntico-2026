import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/vistas/web/entrada_qr.dart';

void main() {
  test('lee la zona del letrero antes o después del #', () {
    expect(leerEntradaQr(Uri.parse('https://x.co/?zona=tubara#/'))?.zonaId, 'tubara');
    expect(leerEntradaQr(Uri.parse('https://x.co/#/?zona=Piojo'))?.zonaId, 'piojo');
    expect(leerEntradaQr(Uri.parse('https://x.co/?zona=mallorquin'))?.canal, 'qr');
  });
  test('origen=qr sin zona, y lo desconocido se ignora', () {
    final e = leerEntradaQr(Uri.parse('https://x.co/?origen=qr'));
    expect(e?.zonaId, isNull);
    expect(e?.viaQr, isTrue);
    expect(leerEntradaQr(Uri.parse('https://x.co/?zona=marte')), isNull);
    expect(leerEntradaQr(Uri.parse('https://x.co/')), isNull);
  });
}
