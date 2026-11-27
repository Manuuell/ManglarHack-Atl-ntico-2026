// El QR de un letrero (?zona=…) llega al reporte: la zona queda preseleccionada y el GPS o el mapa la reemplazan.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/reporte.dart';
import 'package:zanky/datos/tipos.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/vistas/reporte/borrador.dart';
import 'package:zanky/vistas/web/entrada_qr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Manglar manglar;
  setUpAll(() {
    manglar = Manglar.desdeJson(
        jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync()) as Map<String, dynamic>);
    // GPS apagado: el borrador se queda con la sugerencia del letrero.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/geolocator'),
        (c) async => c.method == 'isLocationServiceEnabled' ? false : null);
  });

  test('con ?zona=tubara el borrador abre en Tubará y se enviaría como «enlace»', () {
    final e = EstadoZanky()..manglar = manglar;
    final b = Borrador(e, tipo: TipoAmenaza.quema, entrada: leerEntradaQr(Uri.parse('https://x.co/?zona=tubara')));
    addTearDown(b.dispose);
    final z = manglar.zonaPorId('tubara')!;
    expect(b.zonaDelLetrero, isTrue);
    expect(b.punto, z.centro);
    expect(b.ubicacion!.zona.id, 'tubara');
    expect(b.metodo, MetodoUbicacion.gps, reason: 'el GPS todavía puede reemplazarla');
    expect(b.metodoEnviado, MetodoUbicacion.enlace);
  });

  test('marcar en el mapa reemplaza la zona del letrero', () {
    final e = EstadoZanky()..manglar = manglar;
    final b = Borrador(e, tipo: TipoAmenaza.quema, entrada: leerEntradaQr(Uri.parse('https://x.co/?zona=tubara')));
    addTearDown(b.dispose);
    final otra = manglar.zonaPorId('mallorquin')!.centro;
    b.marcarEnMapa(LatLng(otra.latitude, otra.longitude));
    expect(b.zonaDelLetrero, isFalse);
    expect(b.metodoEnviado, MetodoUbicacion.mapa);
  });

  test('sin QR o con QR genérico no hay punto sugerido', () {
    final e = EstadoZanky()..manglar = manglar;
    for (final entrada in [null, leerEntradaQr(Uri.parse('https://x.co/?origen=qr'))]) {
      final b = Borrador(e, tipo: TipoAmenaza.quema, entrada: entrada);
      expect(b.punto, isNull);
      expect(b.zonaDelLetrero, isFalse);
      b.dispose();
    }
  });
}
