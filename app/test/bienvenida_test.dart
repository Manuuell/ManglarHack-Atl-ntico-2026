// Bienvenida con fotos del manglar: recorrido completo a 360x800, 390x844 y 1280x800 con letra
// x1 y x1,3, sin página de rol, consentimiento visible al llegar y el botón apagado que lleva a la
// casilla. También mide el contraste del velo en el peor caso (pixel blanco detrás) y que las
// fotos empaquetadas existan, pesen poco y tengan su crédito.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/nucleo/base/movimiento.dart';
import 'package:zanky/nucleo/identidad.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/bienvenida/bienvenida.dart';
import 'package:zanky/vistas/bienvenida/fotos.dart';

import 'ayudas/fuente_lato.dart';

const _tamanos = <(String, Size)>[('360x800', Size(360, 800)), ('390x844', Size(390, 844)), ('768x1024', Size(768, 1024)), ('1280x800', Size(1280, 800))];
const _letras = [1.0, 1.3];
const _fotos = [FotoManglar.raices, FotoManglar.garza, FotoManglar.sendero, FotoManglar.cano];

late Manglar _manglar;

EstadoZanky _estado() => EstadoZanky()
  ..manglar = _manglar
  ..listo = true;

Future<void> _avanzar(WidgetTester t, {int veces = 6}) async {
  for (var i = 0; i < veces; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _montar(WidgetTester t, EstadoZanky estado, Size tam, double letra, {bool sinMovimiento = false}) async {
  t.view.physicalSize = tam;
  t.view.devicePixelRatio = 1;
  addTearDown(() {
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  await t.pumpWidget(Zanky(
    estado: estado,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaZanky(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(letra), disableAnimations: sinMovimiento),
        child: child!,
      ),
      home: const Bienvenida(),
    ),
  ));
  await _avanzar(t);
}

Future<void> _cerrar(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 30));
}

/// Corre [cuerpo] recogiendo TODAS las excepciones del marco (un desborde incluido).
Future<void> _sinErrores(WidgetTester t, Future<void> Function() cuerpo) async {
  final errores = <String>[];
  final previo = FlutterError.onError;
  FlutterError.onError = (d) => errores.add(d.exceptionAsString());
  try {
    await cuerpo();
  } finally {
    FlutterError.onError = previo;
  }
  expect(errores, isEmpty, reason: errores.join('\n'));
}

double _lum(Color c) {
  double canal(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
}

double _contraste(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  setUpAll(() async {
    await cargarLato();
    final j = jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync());
    _manglar = Manglar.desdeJson(j as Map<String, dynamic>);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Contraste del velo (peor caso: pixel blanco detrás)', () {
    final texto = Color.alphaBlend(Cra.hero.withValues(alpha: VeloFoto.alfaTexto), Colors.white);
    final pildora = Color.alphaBlend(Cra.hero.withValues(alpha: VeloFoto.alfaPildora), Colors.white);
    test('blanco, textoSuave, textoTenue y dorado pasan AA (4,5:1)', () {
      expect(_contraste(Cra.blanco, texto), greaterThanOrEqualTo(4.5));
      expect(_contraste(Cra.textoSuave, texto), greaterThanOrEqualTo(4.5));
      expect(_contraste(Cra.textoTenue, texto), greaterThanOrEqualTo(4.5));
      expect(_contraste(Cra.dorado, texto), greaterThanOrEqualTo(4.5));
      expect(_contraste(Cra.blanco, pildora), greaterThanOrEqualTo(4.5));
    });
  });

  group('Fotos empaquetadas', () {
    test('se decodifican al ancho que se pinta, en escalones y nunca más de 1400 px', () {
      expect(FotoManglar.anchoDecodificado(const Size(360, 800), 1), 1400);
      expect(FotoManglar.anchoDecodificado(const Size(300, 200), 1), 480);
      expect(FotoManglar.anchoDecodificado(const Size(720, 400), 1), 800);
      expect(FotoManglar.anchoDecodificado(const Size(1280, 800), 3), 1400);
      // La precarga y la pantalla usan la misma clave de caché: no se decodifica dos veces.
      expect(FotoManglar.raices.proveedor(const Size(720, 400), 2),
          FotoManglar.raices.proveedor(const Size(720, 400), 2));
    });

    test('existen, son WebP de menos de 180 KB y tienen crédito', () {
      final creditos = File('assets/fotos/CREDITOS.md').readAsStringSync();
      for (final f in _fotos) {
        final archivo = File(f.ruta);
        expect(archivo.existsSync(), isTrue, reason: f.ruta);
        expect(archivo.lengthSync(), lessThan(180 * 1024), reason: f.ruta);
        final b = archivo.readAsBytesSync();
        expect(ascii.decode(b.sublist(8, 12)), 'WEBP', reason: f.ruta);
        expect(creditos, contains(f.ruta.split('/').last));
        expect(creditos, contains(f.autor));
        expect(f.licencia, startsWith('CC BY-SA'));
      }
    });
  });

  for (final (nombre, tam) in _tamanos) {
    for (final letra in _letras) {
      testWidgets('recorrido completo $nombre letra x$letra: sin rol, consentimiento visible y guardado', (t) async {
        await _sinErrores(t, () async {
          final estado = _estado();
          await _montar(t, estado, tam, letra);
          // Primera página: foto, eyebrow en mayúsculas, logo CRA y crédito de la foto.
          expect(find.text('MANGLAR DEL ATLÁNTICO'), findsOneWidget);
          expect(find.byType(InsigniaCra), findsOneWidget);
          expect(find.text(FotoManglar.raices.credito), findsOneWidget);
          for (var i = 0; i < 4; i++) {
            expect(find.text('¿Cómo participas?'), findsNothing);
            await t.tap(find.text(i == 3 ? 'Casi listo' : 'Siguiente'));
            await _avanzar(t, veces: 8);
          }
          expect(find.text('Estudiante'), findsNothing);
          // El consentimiento se ve al llegar, sin desplazar.
          final casilla = find.textContaining('Acepto el tratamiento');
          expect(casilla, findsOneWidget);
          final caja = t.getRect(casilla);
          expect(caja.bottom, lessThan(tam.height), reason: 'la casilla debe verse sin buscarla');
          // Botón apagado: no guarda y resalta la casilla.
          await t.tap(find.textContaining('Empezar a cuidar'));
          await _avanzar(t, veces: 3);
          expect(estado.perfil?.consentimiento, isNull);
          expect(find.text('Marca esta casilla para empezar.'), findsOneWidget);
          await t.tap(casilla);
          await _avanzar(t, veces: 3);
          expect(find.text('Marca esta casilla para empezar.'), findsNothing);
          await t.tap(find.textContaining('Empezar a cuidar'));
          await _avanzar(t, veces: 10);
          expect(estado.perfil?.consentimiento, isNotNull);
          await _cerrar(t);
        });
      });
    }
  }

  testWidgets('el primer cuadro sale sin esperar las fotos (precarga después)', (t) async {
    await _sinErrores(t, () async {
      final estado = _estado();
      t.view.physicalSize = _tamanos[1].$2;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(Zanky(estado: estado, child: MaterialApp(theme: temaZanky(), home: const Bienvenida())));
      // Un solo pump: el texto ya está aunque ninguna foto haya terminado de decodificarse.
      expect(find.text('Lo que pasa en el manglar, ahora.'), findsOneWidget);
      await _cerrar(t);
    });
  });

  testWidgets('«Saltar» lleva al consentimiento', (t) async {
    await _sinErrores(t, () async {
      await _montar(t, _estado(), _tamanos[0].$2, 1.0);
      await t.tap(find.text('Saltar'));
      await _avanzar(t, veces: 8);
      expect(find.text('Tus datos, en claro'), findsOneWidget);
      await _cerrar(t);
    });
  });

  testWidgets('en 1280 van dos columnas: la foto a la izquierda y el texto a la derecha', (t) async {
    await _sinErrores(t, () async {
      await _montar(t, _estado(), _tamanos[3].$2, 1.0);
      final titulo = t.getRect(find.text('Lo que pasa en el manglar, ahora.'));
      final foto = t.getRect(find.byType(FotosConParalaje));
      expect(foto.left, 0);
      expect(foto.right, lessThanOrEqualTo(titulo.left));
      await _cerrar(t);
    });
  });

  testWidgets('con reducir movimiento la foto no se desplaza al pasar de página', (t) async {
    await _sinErrores(t, () async {
      await _montar(t, _estado(), _tamanos[1].$2, 1.0, sinMovimiento: true);
      final contexto = t.element(find.byType(Bienvenida));
      expect(contexto.animationsDisabled, isTrue);
      await t.drag(find.byType(PageView), const Offset(-150, 0));
      await t.pump();
      for (final tr in t.widgetList<Transform>(
          find.descendant(of: find.byType(FotosConParalaje), matching: find.byType(Transform)))) {
        expect(tr.transform.getTranslation().x, 0);
      }
      await _avanzar(t, veces: 6);
      await _cerrar(t);
    });
  });
}
