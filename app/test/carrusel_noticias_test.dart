import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/comunidad/comunidad.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/comunidad/carrusel_noticias.dart';
import 'package:zanky/vistas/comunidad/lector_noticia.dart';

/// Noticias de ejemplo para las pruebas (no se muestran en la app).
List<NoticiaManglar> ejemplos(int n) => [
      for (var i = 0; i < n; i++)
        NoticiaManglar(
          id: 100 + i,
          fecha: DateTime(2026, 10, 29 - i),
          titulo: 'Titular de prueba $i sobre el manglar',
          resumen: 'Resumen $i',
          parrafos: ['Párrafo uno de la noticia $i. ' * 30, 'Párrafo dos.'],
          enlace: 'https://www.crautonoma.gov.co/prensa/$i',
          imagen: 'https://ejemplo.invalido/foto$i.jpg',
        ),
    ];

Widget app(Widget hijo, {double ancho = 390, bool sinMovimiento = false}) => MaterialApp(
      theme: temaZanky(),
      home: MediaQuery(
        data: MediaQueryData(size: Size(ancho, 844), disableAnimations: sinMovimiento),
        child: Scaffold(body: ListView(children: [hijo])),
      ),
    );

Future<void> asentar(WidgetTester t) async {
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CarruselNoticias.pasoAutomaticoForzado = null;
  });

  testWidgets('sin red: muestra la foto local de respaldo, sin ícono gris ni errores', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(app(CarruselNoticias(noticias: ejemplos(4))));
    await asentar(t);
    expect(t.takeException(), isNull);
    expect(find.text('Titular de prueba 0 sobre el manglar'), findsOneWidget);
    expect(find.byIcon(Icons.newspaper_rounded), findsNothing);
    final assets = find.byWidgetPredicate((w) => w is Image && w.image is AssetImage);
    expect(assets, findsWidgets);
    expect(find.text('CRA · PRENSA · 29 OCT'), findsOneWidget);
  });

  testWidgets('deslizar pasa a la siguiente con encaje magnético', (t) async {
    await t.pumpWidget(app(CarruselNoticias(noticias: ejemplos(4))));
    await asentar(t);
    final estado = t.state<CarruselNoticiasState>(find.byType(CarruselNoticias));
    expect(estado.pagina, 0);
    await t.fling(find.byKey(const ValueKey('carrusel-noticias')), const Offset(-250, 0), 1200);
    await asentar(t);
    expect(estado.pagina, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('tocar abre el lector con la noticia y «Siguiente noticia» al final', (t) async {
    await t.pumpWidget(app(CarruselNoticias(noticias: ejemplos(3))));
    await asentar(t);
    await t.tap(find.text('Titular de prueba 0 sobre el manglar'));
    await asentar(t);
    expect(find.byType(LectorNoticia), findsOneWidget);
    await t.scrollUntilVisible(find.text('SIGUIENTE NOTICIA'), 400, scrollable: find.byType(Scrollable).last);
    await t.tap(find.text('SIGUIENTE NOTICIA'));
    await asentar(t);
    expect(find.text('Titular de prueba 1 sobre el manglar'), findsWidgets);
    expect(t.takeException(), isNull);
  });

  testWidgets('mantener presionado muestra la vista previa con sus acciones', (t) async {
    await t.pumpWidget(app(CarruselNoticias(noticias: ejemplos(3))));
    await asentar(t);
    await t.longPress(find.text('Titular de prueba 0 sobre el manglar'));
    await asentar(t);
    expect(find.text('Leer'), findsOneWidget);
    expect(find.text('Compartir'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.text('Copiar enlace de la fuente'), findsOneWidget);
    expect(find.byType(VistaPreviaNoticia), findsOneWidget);
  });

  testWidgets('en 1280 px caben varias tarjetas a la vez', (t) async {
    t.view.physicalSize = const Size(1280, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(app(CarruselNoticias(noticias: ejemplos(5)), ancho: 1280));
    await asentar(t);
    expect(t.takeException(), isNull);
    var visibles = 0;
    for (var i = 0; i < 5; i++) {
      final f = find.text('Titular de prueba $i sobre el manglar');
      if (f.evaluate().isNotEmpty && t.getRect(f).right <= 1280) visibles++;
    }
    expect(visibles, greaterThanOrEqualTo(2));
  });

  testWidgets('pase automático avanza solo y no corre con «reducir movimiento»', (t) async {
    CarruselNoticias.pasoAutomaticoForzado = true;
    await t.pumpWidget(app(CarruselNoticias(noticias: ejemplos(3), intervalo: const Duration(seconds: 2))));
    final estado = t.state<CarruselNoticiasState>(find.byType(CarruselNoticias));
    await t.pump(const Duration(seconds: 2));
    await asentar(t);
    expect(estado.pagina, 1);

    await t.pumpWidget(app(CarruselNoticias(key: const ValueKey('quieto'), noticias: ejemplos(3), intervalo: const Duration(seconds: 2)),
        sinMovimiento: true));
    final quieto = t.state<CarruselNoticiasState>(find.byType(CarruselNoticias));
    await t.pump(const Duration(seconds: 5));
    await asentar(t);
    expect(quieto.pagina, 0);
    CarruselNoticias.pasoAutomaticoForzado = null;
  });

  test('rótulo, tiempo de lectura y categoría', () {
    final n = ejemplos(1).first;
    expect(rotuloNoticia(n, hoy: DateTime(2026, 11, 27)), 'CRA · Prensa · 29 oct');
    expect(minutosLectura(n), greaterThanOrEqualTo(1));
    expect(categoriaDe(n).nombre, 'Manglar');
  });
}
