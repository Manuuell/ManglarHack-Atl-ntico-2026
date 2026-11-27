import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zanky/datos/gestion/repositorio_puntos.dart';
import 'package:zanky/datos/punto/punto_zanky.dart';
import 'package:zanky/vistas/gestion/entrada_gestor.dart';
import 'package:zanky/vistas/gestion/cartel_punto.dart';

void main() {
  test('valida el código que también valida SQL', () {
    expect(codigoPuntoValido(' Raices-01 '), 'raices-01');
    expect(codigoPuntoValido('ab'), isNull);
    expect(codigoPuntoValido('raices_01'), isNull);
    expect(codigoPuntoValido('área'), isNull);
    expect(codigoPuntoValido(List.filled(41, 'a').join()), isNull);
  });

  test('separa activos e inactivos', () {
    const puntos = [
      PuntoZanky(codigo: 'uno', tipo: TipoPunto.sensor, titulo: 'Uno'),
      PuntoZanky(codigo: 'dos', tipo: TipoPunto.fotoFija, titulo: 'Dos', activo: false),
    ];
    expect(filtrarPuntos(puntos, 0).length, 2);
    expect(filtrarPuntos(puntos, 1).single.codigo, 'uno');
    expect(filtrarPuntos(puntos, 2).single.codigo, 'dos');
  });

  test('el rol de gestor se limita a cuatro perfiles', () {
    for (final rol in ['admin', 'moderador_cra', 'investigador', 'organizador']) {
      expect(puedeGestionarPuntos(rol), isTrue);
    }
    expect(puedeGestionarPuntos('vigia'), isFalse);
    expect(puedeGestionarPuntos(null), isFalse);
  });

  test('la demostración guarda datos solo en su repositorio', () async {
    final repo = RepositorioPuntosDemo();
    expect(repo.demostracion, isTrue);
    const p = PuntoZanky(codigo: 'prueba', tipo: TipoPunto.estacionEducativa, titulo: 'Prueba');
    await repo.guardar(p);
    expect((await repo.listar()).single.codigo, 'prueba');
    expect((await RepositorioPuntosDemo().listar()), isEmpty);
    expect((await repo.resumen('prueba'))['total'], 0);
  });

  test('la demostración comparte los códigos de la ficha y el gestor', () {
    expect(puntosDemostracion.map((p) => p.codigo), containsAll(['demo-estacion', 'demo-foto']));
  });

  for (final tamano in [const Size(360, 800), const Size(390, 844)]) {
    testWidgets('gestor cabe en ${tamano.width}x${tamano.height}', (tester) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = RepositorioPuntosDemo([
        const PuntoZanky(codigo: 'estacion-01', tipo: TipoPunto.estacionEducativa,
          titulo: 'Estación del manglar'),
      ]);
      await tester.pumpWidget(MaterialApp(home: GestorPuntos(repositorio: repo)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('Estación del manglar'), findsOneWidget);
      expect(find.textContaining('DEMOSTRACIÓN'), findsWidgets);
    });

    testWidgets('cartel QR cabe en ${tamano.width}x${tamano.height}', (tester) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const punto = PuntoZanky(codigo: 'estacion-01', tipo: TipoPunto.estacionEducativa,
        titulo: 'Estación del manglar');
      await tester.pumpWidget(const MaterialApp(home: CartelPunto(punto: punto)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(QrImageView), findsOneWidget);
    });
  }
}
