import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/sensores/lecturas_sensor.dart';
import 'package:zanky/datos/sensores/servicio_sensores.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/sensores/detalle_estacion.dart';
import 'package:zanky/vistas/sensores/pantalla_sensores.dart';
import 'package:zanky/vistas/sensores/sensores_compacto.dart';

final ahora = DateTime.utc(2026, 11, 27, 19, 0);

Map<String, Object?> fila({
  String id = 's1',
  String tipo = 'nivel_agua',
  String zona = 'mallorquin',
  Object? valor = 0.8,
  Duration hace = const Duration(minutes: 5),
  Object? umbral,
  bool enAlerta = false,
}) =>
    {
      'sensor_id': id,
      'nombre': 'Sonda',
      'tipo': tipo,
      'zona': zona,
      'zona_nombre': 'Ciénaga de Mallorquín',
      'lat': 11.05,
      'lon': -74.84,
      'valor': valor,
      'unidad': 'm',
      'medido_en': ahora.subtract(hace).toIso8601String(),
      'umbral_alerta': ?umbral,
      'en_alerta': enAlerta,
      'vigente': true,
    };

class ServicioFijo extends ServicioSensores {
  ServicioFijo(this.r, {this.guardada});
  ResultadoSensores r;
  final ResultadoSensores? guardada;
  int cargas = 0;

  @override
  Future<ResultadoSensores?> copia() async => guardada;

  @override
  Future<ResultadoSensores> cargar() async {
    cargas++;
    return r;
  }

  @override
  void cerrar() {}
}

ResultadoSensores demo() {
  final d = lecturasDemostracion(ahora);
  return ResultadoSensores(lecturas: d.lecturas, series: d.series, leido: ahora, origen: OrigenSensores.demostracion);
}

Future<void> montar(WidgetTester t, Widget w, Size tam) async {
  t.view.physicalSize = tam;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(theme: temaZanky(), home: w));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    relojSensores = () => ahora;
  });

  group('parseo de ultimas_lecturas()', () {
    test('lee una fila completa y usa el umbral del servidor', () {
      final l = LecturaSensor.desdeJson(fila(valor: 1.2, umbral: 1.0, enAlerta: true))!;
      expect(l.tipo, TipoSensor.nivelAgua);
      expect(l.valor, 1.2);
      expect(l.medidoEn, ahora.subtract(const Duration(minutes: 5)));
      expect(l.umbral, 1.0);
      expect(l.umbralEsDeReferencia, isFalse);
      expect(l.superaUmbral, isTrue);
    });

    test('sin umbral_alerta (vista pública) usa el de referencia', () {
      final l = LecturaSensor.desdeJson(fila(valor: 1.6))!;
      expect(l.umbralEsDeReferencia, isTrue);
      expect(l.umbral, TipoSensor.nivelAgua.umbralReferencia);
      expect(l.superaUmbral, isTrue);
    });

    test('descarta tipos desconocidos y filas sin id; valor imposible es sin dato', () {
      expect(LecturaSensor.desdeJson(fila(tipo: 'ph')), isNull);
      expect(LecturaSensor.desdeJson({'tipo': 'salinidad'}), isNull);
      expect(LecturaSensor.desdeJson('basura'), isNull);
      final imposible = LecturaSensor.desdeJson(fila(valor: 99))!;
      expect(imposible.valor, isNull);
      expect(imposible.estado(ahora), EstadoLectura.sinDatos);
      expect(LecturaSensor.desdeJson(fila(valor: double.nan))!.valor, isNull);
    });

    test('lugar: dentro del Atlántico o nada', () {
      expect(LecturaSensor.desdeJson(fila())!.lat, 11.05);
      final fuera = LecturaSensor.desdeJson({...fila(), 'lat': 4.6, 'lon': -74.1})!;
      expect(fuera.lat, isNull);
      expect(Estacion('z', 'Z', [fuera]).punto, isNull);
    });

    test('una lista con filas malas conserva las buenas', () {
      final ls = interpretarLecturas([fila(), 'x', fila(id: 's2', tipo: 'salinidad', valor: 30)]);
      expect(ls.map((l) => l.sensorId), ['s1', 's2']);
      expect(interpretarLecturas({'no': 'lista'}), isEmpty);
    });

    test('formatea con coma decimal y la unidad', () {
      expect(TipoSensor.nivelAgua.formatear(1.724), '1,72 m');
      expect(TipoSensor.salinidad.formatear(32.5), '32,5 ppt');
      expect(TipoSensor.turbidez.formatear(120.4), '120 NTU');
    });
  });

  group('estados', () {
    LecturaSensor l({Object? valor = 0.8, Duration hace = const Duration(minutes: 5)}) =>
        LecturaSensor.desdeJson(fila(valor: valor, hace: hace))!;

    test('en línea, vieja, sin datos y alerta', () {
      expect(l().estado(ahora), EstadoLectura.enLinea);
      expect(l(hace: const Duration(minutes: 40)).estado(ahora), EstadoLectura.vieja);
      expect(l(valor: null).estado(ahora), EstadoLectura.sinDatos);
      expect(l(valor: 1.72).estado(ahora), EstadoLectura.alerta);
      // Una alerta de hace más de 6 h ya no es alerta: es una lectura vieja.
      expect(l(valor: 1.72, hace: const Duration(hours: 7)).estado(ahora), EstadoLectura.vieja);
    });

    test('riesgo: 5 alerta, 3 cerca del umbral, 1 normal', () {
      expect(l(valor: 1.72).riesgo(ahora), 5);
      expect(l(valor: 1.35).riesgo(ahora), 3);
      expect(l(valor: 0.6).riesgo(ahora), 1);
    });

    test('textos de estado', () {
      expect(textoEstado(EstadoLectura.vieja, ahora.subtract(const Duration(minutes: 42)), ahora), 'Sin datos hace 42 min');
      expect(textoEstado(EstadoLectura.enLinea, ahora, ahora), 'En línea · ahora mismo');
      expect(haceCuanto(ahora.subtract(const Duration(hours: 3)), ahora), 'hace 3 h');
      expect(horaColombia(ahora), '14:00');
    });

    test('agrupa por zona y pone primero la estación en alerta', () {
      final es = agruparEstaciones(
        interpretarLecturas([
          fila(id: 'a', zona: 'tubara', valor: 0.5),
          fila(id: 'b', zona: 'mallorquin', valor: 1.8),
          fila(id: 'c', zona: 'mallorquin', tipo: 'salinidad', valor: 20),
        ]),
        ahora,
      );
      expect(es.map((e) => e.zonaId), ['mallorquin', 'tubara']);
      expect(es.first.estado(ahora), EstadoLectura.alerta);
      expect(es.first.lecturas.first.tipo, TipoSensor.nivelAgua);
      expect(es.first.enAlerta(ahora).single.sensorId, 'b');
    });

    test('la demostración trae una alerta, una vieja y una sin datos', () {
      final es = agruparEstaciones(lecturasDemostracion(ahora).lecturas, ahora);
      final estados = es.map((e) => e.estado(ahora)).toSet();
      expect(estados, containsAll(EstadoLectura.values));
      expect(es.first.zonaId, 'mallorquin');
      expect(lecturasDemostracion(ahora).lecturas.every((l) => l.nombre.startsWith('[DEMO]')), isTrue);
    });
  });

  group('servicio', () {
    test('une la serie sin repetir horas y corta a 12 h', () {
      final l = LecturaSensor.desdeJson(fila(valor: 1.0))!;
      final viejo = PuntoSerie(ahora.subtract(const Duration(hours: 13)), 0.5);
      final s = unirSeries({'s1': [viejo, PuntoSerie(l.medidoEn!, 1.0)]}, [l], ahora);
      expect(s['s1']!.length, 1);
    });

    test('sin servidor configurado: demostración', () async {
      final r = await ServicioSensores(servidor: Servidor(base: '', anon: '')).cargar();
      expect(r.origen, OrigenSensores.demostracion);
    });

    test('con servidor: en vivo y guarda copia; sin señal después: la copia', () async {
      var caida = false;
      final cliente = MockClient((req) async {
        if (caida) throw http.ClientException('sin señal');
        expect(req.url.path, '/rest/v1/rpc/ultimas_lecturas');
        return http.Response(jsonEncode([fila(valor: 0.9)]), 200);
      });
      final s = ServicioSensores(
        servidor: Servidor(base: 'https://x.supabase.co', anon: 'anon'),
        cliente: cliente,
        reloj: () => ahora,
      );
      final vivo = await s.cargar();
      expect(vivo.origen, OrigenSensores.enVivo);
      expect(vivo.series['s1']!.single.valor, 0.9);
      caida = true;
      final copia = await s.cargar();
      expect(copia.origen, OrigenSensores.copia);
      expect(copia.lecturas.single.valor, 0.9);
      expect(copia.leido, ahora);
    });

    test('servidor sin ninguna lectura: demostración, no pantalla vacía', () async {
      final s = ServicioSensores(
        servidor: Servidor(base: 'https://x.supabase.co', anon: 'anon'),
        cliente: MockClient((_) async => http.Response(jsonEncode([fila(valor: null)]), 200)),
        reloj: () => ahora,
      );
      expect((await s.cargar()).origen, OrigenSensores.demostracion);
    });
  });

  for (final tam in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('pantalla de sensores en demostración ${tam.width.toInt()}x${tam.height.toInt()}', (t) async {
      final servicio = ServicioFijo(demo());
      await montar(t, PantallaSensores(servicio: servicio), tam);
      expect(t.takeException(), isNull);
      expect(find.text('Sensores del manglar'), findsOneWidget);
      expect(find.text('DEMOSTRACIÓN · datos de ejemplo'), findsOneWidget);
      expect(find.byKey(const ValueKey('alerta-5e500000-0000-4000-8000-000000000001')), findsOneWidget);
      expect(find.textContaining('Alerta: nivel del agua en Ciénaga de Mallorquín'), findsOneWidget);
      expect(find.byKey(const ValueKey('estacion-mallorquin')), findsOneWidget);
      expect(find.textContaining('Sin datos hace 2 h'), findsWidgets);
      expect(find.text('Aún sin lecturas'), findsWidgets);

      expect(find.byKey(const ValueKey('punto-mallorquin')), findsOneWidget);
      expect(find.byKey(const ValueKey('punto-piojo')), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('estacion-mallorquin')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('estacion-mallorquin')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(DetalleEstacion), findsOneWidget);
      expect(find.text('1,72 m'), findsOneWidget);
      expect(find.textContaining('Pasó el umbral.'), findsOneWidget);
    });
  }

  testWidgets('360x800 con letra 1,3 no desborda y el punto del mapa abre el detalle', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await montar(t, PantallaSensores(servicio: ServicioFijo(demo())), const Size(360, 800));
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.byKey(const ValueKey('punto-mallorquin')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('punto-mallorquin')));
    await t.pumpAndSettle();
    expect(find.byType(DetalleEstacion), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('sin señal muestra la copia con su hora', (t) async {
    final d = lecturasDemostracion(ahora);
    final copia = ResultadoSensores(
      lecturas: d.lecturas,
      series: d.series,
      leido: ahora.subtract(const Duration(minutes: 30)),
      origen: OrigenSensores.copia,
    );
    await montar(t, PantallaSensores(servicio: ServicioFijo(copia, guardada: copia)), const Size(390, 844));
    expect(find.text('Sin señal: última copia'), findsOneWidget);
    expect(find.textContaining('guardadas a las 13:30'), findsOneWidget);
    expect(find.text('DEMOSTRACIÓN · datos de ejemplo'), findsNothing);
  });

  testWidgets('refresca solo cada minuto', (t) async {
    final servicio = ServicioFijo(demo());
    await montar(t, PantallaSensores(servicio: servicio), const Size(390, 844));
    final antes = servicio.cargas;
    await t.pump(ServicioSensores.refresco);
    expect(servicio.cargas, antes + 1);
  });

  testWidgets('tarjeta de Inicio: alerta visible y abre la pantalla', (t) async {
    final servicio = ServicioFijo(demo());
    await montar(t, Scaffold(body: SensoresCompacto(servicio: servicio)), const Size(390, 844));
    expect(find.textContaining('Alerta: nivel del agua en Ciénaga de Mallorquín'), findsOneWidget);
    expect(find.textContaining('DEMOSTRACIÓN'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('sensores-compacto')));
    await t.pumpAndSettle();
    expect(find.byType(PantallaSensores), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
