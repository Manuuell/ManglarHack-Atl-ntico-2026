// Pruebas del flujo de reporte: textos de confirmación honestos, capa de polígonos
// estable, mapa centrado en la zona pedida, sin rueda eterna sin GPS y aviso amable
// si el guardado falla.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/reporte.dart';
import 'package:zanky/datos/tipos.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/reporte/borrador.dart';
import 'package:zanky/vistas/reporte/enviado.dart';
import 'package:zanky/vistas/reporte/flujo_reporte.dart';
import 'package:zanky/vistas/reporte/paso_ubicacion.dart';

late Manglar _manglar;

/// Un estado que falla al guardar tantas veces como se le pida (disco lleno).
class _EstadoQueFalla extends EstadoZanky {
  int fallos = 1;
  int llamadas = 0;

  @override
  Future<Reporte> agregar(Reporte r, Uint8List? foto) async {
    llamadas++;
    if (fallos > 0) {
      fallos--;
      throw const FileSystemException('No space left on device');
    }
    return super.agregar(r, foto);
  }
}

Reporte _reporte(Envio envio, {String? error}) => Reporte(
      id: 'aaaa0001-0000-0000-0000-000000000001',
      tipo: TipoAmenaza.tala,
      descripcion: '',
      punto: const LatLng(11.05316, -74.85094),
      precisionM: 8,
      metodo: MetodoUbicacion.gps,
      capturadoEn: DateTime(2026, 11, 20),
      momento: Momento.ahora,
      magnitud: Magnitud.mediana,
      zonaId: 'mallorquin',
      zonaNombre: 'Ciénaga de Mallorquín',
      municipio: 'Barranquilla',
      dentroPoligono: true,
      distanciaM: 0,
      prioridad: 3,
      motivosPrioridad: const [],
      confianza: 60,
      anonimo: false,
      reportanteId: null,
      envio: envio,
      ultimoError: error,
    );

Future<void> _montar(WidgetTester tester, EstadoZanky estado, Widget hijo) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(Zanky(
    estado: estado,
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: temaZanky(), home: hijo),
  ));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _cerrar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final j = jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync());
    _manglar = Manglar.desdeJson(j as Map<String, dynamic>);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('textoEnvio dice la verdad', () {
    String detalle(Envio e, {bool conf = true, bool linea = true, String? error}) =>
        textoEnvio(r: _reporte(e, error: error), servidorConfigurado: conf, enLinea: linea).$2;

    test('sin red: sí habla de señal', () {
      expect(detalle(Envio.enCola, linea: false), contains('No hay señal'));
      expect(detalle(Envio.error, linea: false), contains('No hay señal'));
    });

    test('con red nunca dice «No hay señal»', () {
      for (final e in [Envio.enCola, Envio.error]) {
        expect(detalle(e), isNot(contains('señal ahora')));
      }
      expect(detalle(Envio.enCola), contains('se envía en un momento'));
    });

    test('error del servidor y rechazo se distinguen', () {
      expect(detalle(Envio.error, error: 'Error del servidor (reporte 503)'), contains('El servidor falló'));
      expect(detalle(Envio.error, error: 'Error del servidor (reporte 422)'), contains('no aceptó'));
      expect(detalle(Envio.error, error: 'TimeoutException'), contains('No se pudo enviar todavía'));
    });

    test('demostración y enviado', () {
      expect(detalle(Envio.enCola, conf: false), contains('Modo demostración'));
      final enviado = detalle(Envio.enviado);
      expect(enviado, contains('Mis reportes'));
      expect(enviado.toLowerCase(), isNot(contains('te aviso')));
    });
  });

  group('PasoUbicacion', () {
    testWidgets('la capa de polígonos es la misma instancia tras muchas notificaciones', (tester) async {
      final e = EstadoZanky()..manglar = _manglar;
      final b = Borrador(e, tipo: TipoAmenaza.quema);
      addTearDown(b.dispose);
      await _montar(tester, e, Scaffold(body: PasoUbicacion(borrador: b)));
      final antes = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
      final antesTeselas = tester.widget<TileLayer>(find.byType(TileLayer));
      for (var i = 0; i < 5; i++) {
        b.cambiar(() => b.descripcion = 'x$i');
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(identical(tester.widget<PolygonLayer>(find.byType(PolygonLayer)), antes), isTrue);
      expect(identical(tester.widget<TileLayer>(find.byType(TileLayer)), antesTeselas), isTrue);
      await _cerrar(tester);
    });

    testWidgets('sin GPS no queda la rueda de carga girando', (tester) async {
      final e = EstadoZanky()..manglar = _manglar;
      // GPS apagado: el plugin responde que el servicio de ubicación está desactivado.
      const canal = MethodChannel('flutter.baseflow.com/geolocator');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          canal, (c) async => c.method == 'isLocationServiceEnabled' ? false : null);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, null));
      final b = Borrador(e, tipo: TipoAmenaza.quema);
      addTearDown(b.dispose);
      await _montar(tester, e, Scaffold(body: PasoUbicacion(borrador: b)));
      expect(b.punto, isNull);
      expect(b.gps, EstadoGps.apagado);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await _cerrar(tester);
    });

    testWidgets('con zonaId y sin GPS el mapa arranca centrado en esa zona', (tester) async {
      final e = EstadoZanky()..manglar = _manglar;
      final zona = _manglar.zonas.last;
      expect(zona.id, isNot(_manglar.zonas.first.id));
      final b = Borrador(e, tipo: TipoAmenaza.quema);
      addTearDown(b.dispose);
      await _montar(tester, e, Scaffold(body: PasoUbicacion(borrador: b, zonaId: zona.id)));
      final mapa = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(mapa.options.initialCenter, zona.centro);
      await _cerrar(tester);
    });

    testWidgets('sin zonaId arranca en la primera zona', (tester) async {
      final e = EstadoZanky()..manglar = _manglar;
      final b = Borrador(e, tipo: TipoAmenaza.quema);
      addTearDown(b.dispose);
      await _montar(tester, e, Scaffold(body: PasoUbicacion(borrador: b)));
      final mapa = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(mapa.options.initialCenter, _manglar.zonas.first.centro);
      await _cerrar(tester);
    });
  });

  testWidgets('si el guardado falla, avisa con amabilidad y deja reintentar', (tester) async {
    final e = _EstadoQueFalla()..manglar = _manglar;
    // Se prueba el flujo real: el borrador propio del flujo recibe el punto con un toque.
    await _montar(tester, e, FlujoReporte(estado: e, tipo: TipoAmenaza.quema));
    final mapa = find.byType(FlutterMap);
    await tester.tapAt(tester.getCenter(mapa));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Usar este punto'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Seguir sin foto'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.textContaining('Guardar reporte'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('No pude guardar tu reporte'), findsOneWidget);
    expect(e.llamadas, 1);

    await tester.tap(find.text('Reintentar'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(e.llamadas, 2);
    expect(find.text('No pude guardar tu reporte'), findsNothing);
    expect(find.byType(ReporteEnviado), findsOneWidget);
    await _cerrar(tester);
  });
}
