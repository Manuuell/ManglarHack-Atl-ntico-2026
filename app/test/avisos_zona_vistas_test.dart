import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/avisos_zona/repositorio.dart';
import 'package:zanky/datos/admin/controlador_admin.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/nucleo/kit/boton_estado.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/avisos_zona/entrada_voluntario.dart';
import 'package:zanky/vistas/avisos_zona/pantalla_avisos_zona.dart';
import 'package:zanky/vistas/avisos_zona/avisos_encargado.dart';
import 'package:zanky/vistas/mapa/hojas.dart';

void main() {
  final manglar = Manglar.desdeJson(jsonDecode(
    File('assets/datos/manglar_zonas.json').readAsStringSync()) as Map<String, dynamic>);
  for (final tam in const [Size(360, 800), Size(390, 844), Size(1280, 800)]) {
    testWidgets('entrada y bandeja demo en ${tam.width.toInt()}x${tam.height.toInt()}', (tester) async {
      SharedPreferences.setMockInitialValues({'avisos_zona.demo.v1': true});
      tester.view.physicalSize = tam;
      tester.view.devicePixelRatio = 1;
      addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
      await tester.pumpWidget(MaterialApp(theme: temaZanky(), home: Scaffold(
        body: const EntradaVoluntario(),
      )));
      expect(find.text('Sé voluntario de tu zona'), findsOneWidget);
      await tester.tap(find.text('Sé voluntario de tu zona'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Demostración sin servidor'), findsOneWidget);
      expect(find.text('Avisos cerca de ti'), findsWidgets);
      expect(find.text('Voy a ayudar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hoja muestra consentimiento en ${tam.width.toInt()}x${tam.height.toInt()}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = tam;
      tester.view.devicePixelRatio = 1;
      addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
      final repo = RepositorioAvisosZona(servidor: Servidor(base: '', anon: ''));
      await tester.pumpWidget(MaterialApp(theme: temaZanky(),
        home: PantallaAvisosZona(repositorio: repo, manglar: manglar)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sé voluntario de tu zona'));
      await tester.pumpAndSettle();
      // El alta exige consentimiento explícito: texto de privacidad visible,
      // casilla desmarcada y botón apagado hasta aceptar.
      final ley = find.textContaining('Ley 1581');
      expect(ley, findsOneWidget);
      expect(find.textContaining('darme de baja'), findsWidgets);
      final casilla = find.byType(CheckboxListTile);
      expect(casilla, findsOneWidget);
      expect(tester.widget<CheckboxListTile>(casilla).value, isFalse);
      final boton = find.widgetWithText(BotonEstado, 'Inscribirme');
      expect(tester.widget<BotonEstado>(boton).alPresionar, isNull);
      await tester.ensureVisible(casilla);
      await tester.tap(casilla);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(casilla).value, isTrue);
      expect(tester.widget<BotonEstado>(boton).alPresionar, isNotNull);
      // Retirar la autorización vuelve a apagar el alta.
      await tester.tap(casilla);
      await tester.pumpAndSettle();
      expect(tester.widget<BotonEstado>(boton).alPresionar, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bandeja del encargado en ${tam.width.toInt()}x${tam.height.toInt()}', (tester) async {
      tester.view.physicalSize = tam;
      tester.view.devicePixelRatio = 1;
      addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
      final c = ControladorAdmin(servidor: Servidor(base: '', anon: ''));
      addTearDown(c.dispose);
      await tester.pumpWidget(MaterialApp(theme: temaZanky(),
        home: AvisosEncargado(controlador: c)));
      await tester.pumpAndSettle();
      expect(find.text('Avisos de mi zona'), findsOneWidget);
      expect(find.text('Todavía no hay avisos de tu zona.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('desde la hoja de una zona se llega a «Avisarme de esta zona» con la zona elegida', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    final zona = manglar.zonas.last;
    await tester.pumpWidget(MaterialApp(theme: temaZanky(), home: Builder(builder: (c) => Scaffold(
      body: TextButton(onPressed: () => abrirHojaZona(c, zona: zona, reportes: 0, ultimas24h: 0,
        mios: 0, alReportar: () {}), child: const Text('abrir'))))));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    final boton = find.text('Avisarme de esta zona');
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(find.text('Avisos cerca de ti'), findsWidgets);
    expect(tester.widget<PantallaAvisosZona>(find.byType(PantallaAvisosZona)).zonaInicial, zona.id);
  });
}
