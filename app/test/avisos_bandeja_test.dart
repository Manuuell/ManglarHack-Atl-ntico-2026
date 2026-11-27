import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/avisos/centro_avisos.dart';
import 'package:zanky/datos/avisos/reglas_avisos.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/avisos/bandeja_avisos.dart';

AvisoApp _aviso(String clave, TipoAvisoApp tipo, String titulo, {String? nivel}) => AvisoApp(
      clave: clave,
      tipo: tipo,
      titulo: titulo,
      cuerpo: 'Bocas de Ceniza. Qué hacer: no entres al agua.',
      creado: DateTime.now(),
      destino: clave,
      nivel: nivel,
    );

Future<void> _montar(WidgetTester t, Widget w, Size tam) async {
  t.view.physicalSize = tam;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(theme: temaZanky(), home: w));
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _avanzar(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _desmontar(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 10)); // píldoras y parpadeo de Zanky
}

void main() {
  final centro = CentroAvisos.compartido;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await centro.cargar();
    centro.avisos = [];
  });

  for (final tam in const [Size(360, 640), Size(390, 844), Size(768, 1024), Size(1280, 800)]) {
    testWidgets('bandeja vacía con Zanky · ${tam.width.toInt()}', (t) async {
      await _montar(t, const PantallaAvisos(), tam);
      expect(find.text('Todo tranquilo'), findsOneWidget);
      expect(t.takeException(), isNull);
      await _desmontar(t);
    });

    testWidgets('lista, borrar con Deshacer y leer todo · ${tam.width.toInt()}', (t) async {
      centro.entregar([
        _aviso('a', TipoAvisoApp.alerta, 'Alerta roja: Mar de leva', nivel: 'roja'),
        _aviso('j', TipoAvisoApp.jornada, 'Mañana: Siembra de mangle'),
      ]);
      await _montar(t, const PantallaAvisos(), tam);
      expect(find.text('NUEVOS · 2'), findsOneWidget);
      expect(find.text('Alerta roja: Mar de leva'), findsOneWidget);

      // Mantener presionado: vista previa y acciones.
      await t.longPress(find.text('Mañana: Siembra de mangle'));
      await _avanzar(t);
      expect(find.byKey(const Key('menu-Ver la jornada')), findsOneWidget);
      await t.tap(find.byKey(const Key('menu-Borrar')));
      await _avanzar(t);
      expect(centro.avisos, hasLength(1));
      expect(find.text('Aviso borrado'), findsOneWidget);
      await t.tap(find.text('Deshacer'));
      await _avanzar(t);
      expect(centro.avisos, hasLength(2));

      await t.tap(find.text('Leer todo'));
      await t.pump(const Duration(milliseconds: 400));
      expect(centro.noLeidos, 0);
      expect(find.text('ANTERIORES'), findsOneWidget);
      expect(t.takeException(), isNull);
      await _desmontar(t);
    });
  }

  testWidgets('campana con contador', (t) async {
    await _montar(t, const Scaffold(body: Center(child: CampanaAvisos())), const Size(390, 844));
    expect(find.text('1'), findsNothing);
    centro.entregar([_aviso('r', TipoAvisoApp.reporte, 'Tu reporte llegó a la CRA')]);
    await t.pump(const Duration(milliseconds: 800));
    expect(find.text('1'), findsOneWidget);
    expect(find.bySemanticsLabel('Avisos, 1 sin leer'), findsOneWidget);
    await _desmontar(t);
  });

  testWidgets('preferencias por tipo con interruptores', (t) async {
    await _montar(t, const Scaffold(body: SingleChildScrollView(child: SeccionPreferenciasAvisos())), const Size(390, 844));
    expect(find.text('Recordatorios de mis jornadas'), findsOneWidget);
    expect(centro.preferencias.jornadas, isTrue);
    centro.cambiarPreferencia(TipoAvisoApp.jornada, false);
    await t.pump(const Duration(milliseconds: 400));
    expect(centro.preferencias.jornadas, isFalse);
    centro.cambiarPreferencia(TipoAvisoApp.jornada, true);
    await _desmontar(t);
  });
}
