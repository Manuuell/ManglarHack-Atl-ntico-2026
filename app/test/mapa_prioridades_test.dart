import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/mapa/capa_prioridad.dart';
import 'package:zanky/vistas/mapa/pantalla_mapa.dart';

/// La capa oficial de prioridades de conservación de la CRA en el mapa: datos, rendimiento,
/// alternar capa, leyenda y la hoja de un polígono.
void main() {
  late String textoPrioridades;
  late Map<String, dynamic> jsonPrioridades;
  late Manglar manglar;
  late CapaPrioridadMapa capa;
  var msDecodificar = 0;
  var msPoligonos = 0;

  setUpAll(() async {
    final inter = FontLoader('Inter');
    for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final bytes = File('google_fonts/Inter-$f.ttf').readAsBytesSync();
      inter.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await inter.load();
    textoPrioridades = File('assets/datos/prioridades_cra.json').readAsStringSync();
    jsonPrioridades = jsonDecode(textoPrioridades) as Map<String, dynamic>;
    final j = jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync());
    manglar = Manglar.desdeJson(j as Map<String, dynamic>, jsonPrioridades);

    final reloj = Stopwatch()..start();
    final datos = decodificarPrioridades(textoPrioridades);
    msDecodificar = reloj.elapsedMilliseconds;
    reloj.reset();
    capa = CapaPrioridadMapa.desdeDatos(datos);
    msPoligonos = reloj.elapsedMilliseconds;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Un punto de adentro del polígono (el promedio de sus vértices, si cae dentro).
  LatLng? puntoInterior(PoligonoPrioridad q) {
    final r = q.anillos.first;
    var x = 0.0, y = 0.0;
    final n = r.length ~/ 2;
    for (var i = 0; i < n; i++) {
      x += r[i * 2];
      y += r[i * 2 + 1];
    }
    x /= n;
    y /= n;
    return q.contiene(x, y) ? LatLng(y, x) : null;
  }

  group('Datos de la capa', () {
    test('trae todos los polígonos y mide cuánto cuesta prepararlos', () {
      final esperado = (jsonPrioridades['poligonos'] as List).length;
      expect(capa.poligonos.length, esperado);
      final d = capa.datos;
      // ignore: avoid_print
      print('PRIORIDAD CRA · ${capa.poligonos.length} polígonos · vértices ${d.verticesOriginales} → '
          '${d.verticesFinales} (${(100 * d.verticesFinales / d.verticesOriginales).toStringAsFixed(0)} %) · '
          'decodificar+simplificar $msDecodificar ms · crear Polygon+capa $msPoligonos ms');
      expect(d.verticesFinales, lessThan(d.verticesOriginales));
      expect(msPoligonos, lessThan(2000));
    });

    test('el conteo por prioridad es el del archivo y se dibuja la alta encima', () {
      final atributos = jsonPrioridades['atributos'] as List;
      final porNivel = <PrioridadCRA, int>{for (final p in PrioridadCRA.values) p: 0};
      for (final p in jsonPrioridades['poligonos'] as List) {
        final n = PrioridadCRA.desdeTexto(atributos[(p[0] as num).toInt()]['p'] as String)!;
        porNivel[n] = porNivel[n]! + 1;
      }
      expect(capa.conteo, porNivel);
      // Orden de dibujo: bajas, medias, altas.
      final indices = capa.poligonos.map((p) => p.prioridad.index).toList();
      for (var i = 1; i < indices.length; i++) {
        expect(indices[i] <= indices[i - 1], isTrue, reason: 'el polígono $i rompe el orden de dibujo');
      }
    });

    test('tocar un punto da la misma prioridad que el modelo de la CRA (caja y luego punto-en-polígono)', () {
      final oraculo = manglar.prioridades!;
      var comparados = 0, iguales = 0;
      for (var i = 0; i < capa.poligonos.length; i += 7) {
        final p = puntoInterior(capa.poligonos[i]);
        if (p == null) continue;
        comparados++;
        final mio = capa.en(p);
        final suyo = oraculo.en(p);
        expect(mio, isNotNull);
        if (suyo != null && mio!.prioridad == suyo.prioridad) iguales++;
      }
      expect(comparados, greaterThan(500));
      // La simplificación (≈ 3 m) puede mover un punto pegado al borde: se pide ≥ 98 %.
      expect(iguales / comparados, greaterThan(0.98));
    });

    test('fuera de la zonificación no hay polígono, y la búsqueda es rápida', () {
      expect(capa.en(const LatLng(4.6, -74.08)), isNull);
      final azar = math.Random(7);
      final reloj = Stopwatch()..start();
      const n = 2000;
      var aciertos = 0;
      for (var i = 0; i < n; i++) {
        final p = LatLng(10.66 + azar.nextDouble() * 0.43, -75.27 + azar.nextDouble() * 0.47);
        if (capa.en(p) != null) aciertos++;
      }
      final usPorToque = reloj.elapsedMicroseconds / n;
      // ignore: avoid_print
      print('PRIORIDAD CRA · hit-test: ${usPorToque.toStringAsFixed(0)} µs por toque ($aciertos de $n sobre un polígono)');
      expect(usPorToque, lessThan(5000));
    });

    test('las hectáreas salen del polígono y son plausibles', () {
      final todas = capa.poligonos.map((p) => p.hectareas).toList();
      expect(todas.every((h) => h >= 0 && h.isFinite), isTrue);
      expect(todas.reduce((a, b) => a + b), greaterThan(1000));
    });
  });

  group('En el mapa', () {
    late EstadoZanky estado;

    setUp(() {
      estado = EstadoZanky()
        ..manglar = manglar
        ..listo = true;
      CapaPrioridadMapa.cargador = () async => capa;
    });
    tearDown(() => CapaPrioridadMapa.cargador = CapaPrioridadMapa.cargar);

    Future<void> montar(WidgetTester t, {Size tam = const Size(390, 844), double letra = 1}) async {
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
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(letra)),
            child: child!,
          ),
          home: const Scaffold(body: PantallaMapa()),
        ),
      ));
      await avanzar(t);
    }

    Future<void> cerrar(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 30));
    }

    testWidgets('por defecto es el manglar, sin leyenda de la CRA; alterna y vuelve', (t) async {
      await montar(t);
      expect(find.text('Manglar'), findsOneWidget);
      expect(find.text('Prioridad CRA'), findsOneWidget);
      expect(find.text('Media'), findsNothing);
      expect(find.bySemanticsLabel('Manglar, capa activa'), findsOneWidget);

      await t.tap(find.text('Prioridad CRA'));
      await avanzar(t);
      // La leyenda compacta: los tres niveles y la invitación a tocar.
      expect(find.text('Alta'), findsOneWidget);
      expect(find.text('Media'), findsOneWidget);
      expect(find.text('Baja'), findsOneWidget);
      expect(find.textContaining('Toca una zona'), findsOneWidget);
      expect(find.bySemanticsLabel('Prioridad CRA, capa activa'), findsOneWidget);
      // La capa de prioridades se dibuja (un PolygonLayer más que con el manglar solo).
      expect(find.byType(PolygonLayer), findsWidgets);

      await t.tap(find.text('Manglar'));
      await avanzar(t);
      expect(find.text('Media'), findsNothing);
      await cerrar(t);
    });

    testWidgets('tocar un polígono abre la hoja con nivel, acción, escenario, sector, ha y la fuente', (t) async {
      await montar(t);
      await t.tap(find.text('Prioridad CRA'));
      await avanzar(t);

      final camara = MapCamera.of(t.element(find.byType(PolygonLayer).first));
      // El mayor polígono cuyo punto interior cae en la parte libre de la pantalla.
      final etiquetas = [for (final z in manglar.zonas) camara.getOffsetFromOrigin(z.centro)];
      PoligonoPrioridad? elegido;
      Offset? donde;
      for (final q in capa.poligonos) {
        final p = puntoInterior(q);
        if (p == null || capa.en(p) != q) continue;
        final o = camara.getOffsetFromOrigin(p);
        if (o.dx < 30 || o.dx > 360 || o.dy < 190 || o.dy > 420) continue;
        // Las etiquetas de zona (44 px) se tocan primero que el polígono: se evitan.
        if (etiquetas.any((e) => (e - o).distance < 40)) continue;
        if (elegido == null || q.hectareas > elegido.hectareas) {
          elegido = q;
          donde = o;
        }
      }
      expect(elegido, isNotNull, reason: 'ningún polígono visible en la parte libre del mapa');

      await t.tapAt(donde!);
      await avanzar(t, veces: 8);

      final plan = elegido!.plan;
      expect(find.text('Prioridad ${plan.prioridad.nombre.toLowerCase()}'), findsOneWidget);
      expect(find.text(plan.accion), findsOneWidget);
      expect(find.text(plan.escenario), findsOneWidget);
      final sector = plan.areaProtegida ?? plan.unidad;
      if (sector != null) expect(find.text(sector), findsOneWidget);
      expect(find.textContaining('≈ ${elegido.hectareas.toStringAsFixed(1).replaceAll('.', ',')} ha'), findsOneWidget);
      expect(find.textContaining('Capa oficial de la CRA, escala 1:5.000'), findsOneWidget);

      // Se cierra (arrastrando la hoja) y el mapa sigue ahí.
      await t.tapAt(const Offset(195, 40));
      await avanzar(t, veces: 8);
      await cerrar(t);
    });

    testWidgets('mover el mapa con la capa activa no se traba (tiempo por cuadro)', (t) async {
      await montar(t);
      await t.tap(find.text('Prioridad CRA'));
      await avanzar(t);
      final camara = MapCamera.of(t.element(find.byType(PolygonLayer).first));
      final centro = camara.getOffsetFromOrigin(camara.center);
      final reloj = Stopwatch()..start();
      const pasos = 20;
      final g = await t.startGesture(centro);
      for (var i = 0; i < pasos; i++) {
        await g.moveBy(const Offset(6, 3));
        await t.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      final msCuadro = reloj.elapsedMilliseconds / pasos;
      // ignore: avoid_print
      print('PRIORIDAD CRA · mover el mapa (${capa.poligonos.length} polígonos): '
          '${msCuadro.toStringAsFixed(1)} ms por cuadro (pump + pintura, sin rasterizar)');
      expect(msCuadro, lessThan(250));
      await cerrar(t);
    });

    for (final (nombre, tam) in const [('360x640', Size(360, 640)), ('390x844', Size(390, 844)), ('768x1024', Size(768, 1024))]) {
      for (final letra in const [1.0, 2.0]) {
        testWidgets('con la capa activa aguanta $nombre y letra x$letra', (t) async {
          final errores = <String>[];
          final previo = FlutterError.onError;
          FlutterError.onError = (d) => errores.add(d.exceptionAsString().split('\n').first);
          try {
            await montar(t, tam: tam, letra: letra);
            await t.tap(find.text('Prioridad CRA'));
            await avanzar(t);
            expect(find.text('Baja'), findsOneWidget);
            await cerrar(t);
          } finally {
            FlutterError.onError = previo;
          }
          expect(errores, isEmpty);
        });
      }
    }

    testWidgets('si la lectura falla, avisa y deja reintentar', (t) async {
      var intentos = 0;
      CapaPrioridadMapa.cargador = () async {
        intentos++;
        if (intentos == 1) throw StateError('sin archivo');
        return capa;
      };
      await montar(t);
      await t.tap(find.text('Prioridad CRA'));
      await avanzar(t);
      expect(find.textContaining('No pude leer la capa'), findsOneWidget);
      await t.tap(find.text('Reintentar'));
      await avanzar(t);
      expect(find.text('Media'), findsOneWidget);
      expect(intentos, 2);
      await cerrar(t);
    });
  });

  test('la carga real lee los assets y decodifica en otro hilo', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final reloj = Stopwatch()..start();
    final c = await CapaPrioridadMapa.cargar();
    // ignore: avoid_print
    print('PRIORIDAD CRA · carga real (assets + hilo aparte + Polygon): ${reloj.elapsedMilliseconds} ms');
    expect(c.poligonos.length, capa.poligonos.length);
  });
}

Future<void> avanzar(WidgetTester t, {int veces = 6}) async {
  for (var i = 0; i < veces; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}
