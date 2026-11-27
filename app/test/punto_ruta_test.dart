import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/punto/punto_zanky.dart';
import 'package:zanky/datos/punto/servicio_punto.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/vistas/punto/pantalla_punto.dart';

class _ServicioDePrueba extends ServicioPunto {
  _ServicioDePrueba(this.punto);
  final PuntoZanky punto;
  @override
  Future<PuntoZanky?> cargar(String codigo) async => punto;
  @override
  Future<bool> registrar(String codigo) async => false;
  @override
  Future<List<Map<String, dynamic>>> lecturas() async => [];
}

class _ServicioSinSenal extends ServicioPunto {
  _ServicioSinSenal() : super(servidor: Servidor(base: 'https://sin-senal.invalid', anon: 'clave-publica'));
  @override
  Future<PuntoZanky?> cargar(String codigo) async => throw StateError('Sin señal');
}

void main() {
  testWidgets('el primer escaneo sin señal conserva la visita', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(home: PantallaPunto(
      codigo: 'raices-01', servicio: _ServicioSinSenal())));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Visita guardada'), findsOneWidget);
    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getStringList('puntos_visitas_pendientes'), contains('raices-01'));
    await tester.pumpWidget(const SizedBox.shrink()); // suelta la mascota y su parpadeo
    await tester.pump(const Duration(seconds: 6)); // vence el parpadeo pendiente
  });

  test('lee ?punto= con base href /app/ y fragmento de ruta', () {
    expect(leerCodigoPunto(Uri.parse('https://mimanglar.sentralabs.co/app/?punto=raices-01')), 'raices-01');
    expect(leerCodigoPunto(Uri.parse('https://mimanglar.sentralabs.co/app/#/?punto=raices-01')), 'raices-01');
    expect(leerCodigoPunto(Uri.parse('https://mimanglar.sentralabs.co/app/?punto=x')), isNull);
    expect(enlacePunto('raices-01'), 'https://mimanglar.sentralabs.co/app/?punto=raices-01');
  });

  for (final tamano in [const Size(360, 800), const Size(390, 844)]) {
    testWidgets('ficha de punto cabe en ${tamano.width}x${tamano.height}', (tester) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const punto = PuntoZanky(codigo: 'foto-01', tipo: TipoPunto.fotoFija,
        titulo: 'Fotografía de seguimiento', descripcion: 'Observa el horizonte.');
      await tester.pumpWidget(MaterialApp(home: PantallaPunto(
        codigo: punto.codigo, servicio: _ServicioDePrueba(punto))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('Fotografía de seguimiento'), findsOneWidget);
      expect(find.textContaining('DEMOSTRACIÓN'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink()); // suelta la mascota y su parpadeo
    await tester.pump(const Duration(seconds: 6)); // vence el parpadeo pendiente
    });
  }
}
