import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/comunidad/datos_abiertos.dart';

void main() {
  Future<void> montar(WidgetTester t) async {
    t.view.physicalSize = const Size(360, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: temaZanky(),
      home: const Scaffold(body: Center(child: DatosAbiertos(base: 'https://ejemplo.test'))),
    ));
  }

  testWidgets('Descargar trae el archivo del formato y lo entrega con su nombre y tipo', (t) async {
    Uri? pedido;
    FormatoAbierto? entregado;
    traerDatoAbierto = (u) async {
      pedido = u;
      return Uint8List.fromList([1, 2, 3]);
    };
    entregarDatoAbierto = (b, f) async => entregado = f;
    await montar(t);
    expect(t.takeException(), isNull);
    await t.tap(find.byKey(const ValueKey('descargar-csv')));
    await t.pump(const Duration(milliseconds: 300));
    expect(pedido.toString(), 'https://ejemplo.test/datos-abiertos/reportes.csv');
    expect(entregado?.archivo, 'reportes-zanky.csv');
    expect(entregado?.mime, 'text/csv');
    await t.pump(const Duration(seconds: 8));
  });

  testWidgets('sin señal: avisa con salida para copiar el enlace', (t) async {
    traerDatoAbierto = (u) async => throw StateError('sin red');
    entregarDatoAbierto = (b, f) async => fail('no debía entregar');
    await montar(t);
    await t.tap(find.byKey(const ValueKey('descargar-geojson')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('no hay señal'), findsOneWidget);
    expect(find.text('Copiar enlace'), findsOneWidget);
    await t.pump(const Duration(seconds: 10));
  });
}
