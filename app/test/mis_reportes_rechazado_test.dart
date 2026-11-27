// «Mis reportes» con un reporte que el servidor no aceptó: la tarjeta con el motivo, el botón
// «Volver a intentar», la lista que lo separa, el texto honesto de la prioridad y la foto.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/reporte.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/mis_reportes/detalle_reporte.dart';
import 'package:zanky/vistas/mis_reportes/pantalla_mis_reportes.dart';

import 'apoyo_datos.dart';

late Manglar _manglar;

Future<void> _montar(WidgetTester tester, EstadoZanky estado, Widget hijo) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(Zanky(
    estado: estado,
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: temaZanky(), home: Scaffold(body: hijo)),
  ));
  for (var i = 0; i < 8; i++) {
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

  setUp(() {
    SharedPreferencesStorePlatform.instance = AlmacenDePrueba();
    SharedPreferences.resetStatic();
  });

  Reporte rechazado(String id, {String? motivo = 'El punto queda fuera del Atlántico'}) =>
      reporteDePrueba(id, envio: Envio.rechazado)..motivoRechazo = motivo;

  group('textos', () {
    test('la prioridad recalculada dice «el servidor», nunca «la CRA la ajustó»', () {
      final t = textoPrioridadRecalculada(4, 3);
      expect(t, contains('El servidor la recalculó a 4'));
      expect(t, contains('llegaban a 3'));
      expect(t, contains('no usa el viento'));
      expect(t, isNot(contains('La CRA la ajustó')));
    });

    test('la foto: completa, miniatura o ya enviada sin copia', () {
      expect(textoFotoDelReporte(reporteDePrueba(idDePrueba(1))), 'Sin foto');
      expect(textoFotoDelReporte(reporteDePrueba(idDePrueba(1), fotoRef: 'foto:x')), 'Elegida de la galería');
      final mini = reporteDePrueba(idDePrueba(1), fotoRef: 'foto:x')..fotoReducida = true;
      expect(textoFotoDelReporte(mini), 'Miniatura: la foto completa ya está en la CRA');
      final sinCopia = reporteDePrueba(idDePrueba(1))..fotoReducida = true;
      expect(textoFotoDelReporte(sinCopia), contains('ya está en la CRA'));
    });
  });

  group('detalle de un reporte no aceptado', () {
    testWidgets('muestra el motivo y «Volver a intentar» lo manda otra vez', (tester) async {
      final s = ServidorFalso();
      final e = EstadoZanky(servidor: s.servidor)
        ..manglar = _manglar
        ..enLinea = true;
      final r = rechazado(idDePrueba(21));
      e.reportes.add(r);
      await _montar(tester, e, PantallaDetalleReporte(reporte: r));

      expect(find.text('El servidor no aceptó este reporte'), findsOneWidget);
      expect(find.text('El punto queda fuera del Atlántico'), findsWidgets, reason: 'tarjeta y línea de tiempo');
      expect(find.text('Volver a intentar'), findsOneWidget);
      expect(find.text('Lo intento de nuevo solo; no se pierde.'), findsNothing);

      await tester.tap(find.text('Volver a intentar'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect(s.creados, [r.id], reason: 'reintentar(r) lo puso en cola y lo envió');
      expect(r.envio, Envio.enviado);
      expect(r.motivoRechazo, isNull);
      await _cerrar(tester);
      e.dispose();
    });

    testWidgets('sin motivo guardado dice que no aceptó, sin inventar causa', (tester) async {
      final e = EstadoZanky()..manglar = _manglar;
      final r = rechazado(idDePrueba(22), motivo: null);
      e.reportes.add(r);
      await _montar(tester, e, PantallaDetalleReporte(reporte: r));
      expect(find.text('El servidor no aceptó este reporte.'), findsWidgets);
      await _cerrar(tester);
      e.dispose();
    });

    testWidgets('un reporte normal no trae esa tarjeta', (tester) async {
      final e = EstadoZanky()..manglar = _manglar;
      final r = reporteDePrueba(idDePrueba(23), envio: Envio.enviado);
      e.reportes.add(r);
      await _montar(tester, e, PantallaDetalleReporte(reporte: r));
      expect(find.text('Volver a intentar'), findsNothing);
      await _cerrar(tester);
      e.dispose();
    });
  });

  testWidgets('la lista separa los no aceptados de los pendientes y de la CRA', (tester) async {
    final e = EstadoZanky(servidor: ServidorFalso().servidor)
      ..manglar = _manglar
      ..enLinea = false;
    e.reportes.addAll([
      reporteDePrueba(idDePrueba(31), envio: Envio.enCola),
      rechazado(idDePrueba(32)),
      reporteDePrueba(idDePrueba(33), envio: Envio.enviado),
    ]);
    await _montar(tester, e, const PantallaMisReportes());
    expect(find.text('En tu teléfono'), findsOneWidget);
    expect(find.text('No aceptados'), findsOneWidget);
    expect(find.text('En la CRA'), findsOneWidget);
    expect(find.textContaining('1 NO ACEPTADO'), findsOneWidget);
    // El aviso de «sin señal / se envían solos» ya no habla del rechazado.
    expect(find.textContaining('La CRA no pudo recibir alguno'), findsNothing);
    await _cerrar(tester);
    e.dispose();
  });
}
