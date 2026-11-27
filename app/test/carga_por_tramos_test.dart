import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/vistas/mapa/capa_prioridad.dart';

/// El manglar (pequeño) llega primero y las prioridades (1,5 MB) después, y la decodificación por
/// tramos (la que usa la web, sin isolates) da EXACTAMENTE lo mismo que la de un solo golpe.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> jManglar;
  late Map<String, dynamic> jPrioridades;
  late String textoPrioridades;

  setUpAll(() {
    jManglar = jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync()) as Map<String, dynamic>;
    textoPrioridades = File('assets/datos/prioridades_cra.json').readAsStringSync();
    jPrioridades = jsonDecode(textoPrioridades) as Map<String, dynamic>;
  });

  test('Manglar.cargar() deja listo el manglar SIN esperar las prioridades', () async {
    final m = await Manglar.cargar();
    expect(m.zonas, isNotEmpty);
    expect(m.prioridades, isNull);
    expect(m.prioridadesListas, isFalse);
    // Sin capa se ubica igual: sin plan y sin marcar «fuera de zonificación».
    final u = m.ubicar(puntoMallorquin);
    expect(u.plan, isNull);
    expect(u.fueraZonificacion, isFalse);
    expect(u.zona.id, isNotEmpty);
  });

  test('las prioridades llegan después, una sola vez, y entonces ubicar trae el plan', () async {
    final m = await Manglar.cargar();
    final antes = m.ubicar(puntoMallorquin);
    final f1 = m.cargarPrioridades();
    final f2 = m.cargarPrioridades();
    expect(identical(f1, f2), isTrue, reason: 'idempotente: no decodifica dos veces');
    await f1;
    expect(m.prioridadesListas, isTrue);
    expect(m.prioridades!.poligonos, jPrioridades['poligonos'].length);
    final despues = m.ubicar(puntoMallorquin);
    // La zona y la distancia no cambian por llegar la capa; solo se suma el plan.
    expect(despues.zona.id, antes.zona.id);
    expect(despues.dentro, antes.dentro);
    expect(despues.distanciaM, antes.distanciaM);
    expect(despues.plan != null || despues.fueraZonificacion, isTrue);
  });

  test('el manglar por tramos es idéntico al de un solo golpe (aun con tramos de 0 ms)', () async {
    final a = Manglar.desdeJson(jManglar);
    final b = await Manglar.desdeJsonPorTramos(jManglar, tramoMs: 0);
    expect(b.zonas.map((z) => z.id), a.zonas.map((z) => z.id));
    expect(b.areaTotalHa, a.areaTotalHa);
    expect(b.fechaDatos, a.fechaDatos);
    expect(b.prioridades, isNull);
    for (var i = 0; i < a.zonas.length; i++) {
      expect(b.zonas[i].poligonos, a.zonas[i].poligonos, reason: a.zonas[i].id);
      expect(b.zonas[i].huecos, a.zonas[i].huecos, reason: a.zonas[i].id);
      expect(b.zonas[i].prioridadConservacion, a.zonas[i].prioridadConservacion);
    }
  });

  test('las prioridades por tramos responden igual que de un solo golpe', () async {
    final a = CapaPrioridadesCra.desdeJson(jPrioridades);
    final b = await CapaPrioridadesCra.desdeJsonPorTramos(jPrioridades, tramoMs: 0);
    expect(b.poligonos, a.poligonos);
    for (final p in const [puntoMallorquin, LatLng(10.9, -74.9), LatLng(10.75, -75.05), LatLng(0, 0)]) {
      expect(b.en(p)?.accion, a.en(p)?.accion, reason: '$p');
      expect(b.en(p)?.prioridad, a.en(p)?.prioridad, reason: '$p');
    }
  });

  test('la capa del mapa por tramos queda igual que la de un solo golpe', () async {
    final a = CapaPrioridadMapa.desdeTexto(textoPrioridades);
    final datos = await decodificarPrioridadesPorTramos(textoPrioridades, tramoMs: 0);
    final b = await CapaPrioridadMapa.desdeDatosPorTramos(datos, tramoMs: 0);
    expect(b.poligonos.length, a.poligonos.length);
    expect(b.verticesFinales, a.verticesFinales);
    expect(b.conteo, a.conteo);
    expect([for (final q in b.poligonos) q.hectareas], [for (final q in a.poligonos) q.hectareas]);
  });

  test('por tramos cede el hilo: otra tarea se cuela antes de terminar', () async {
    var colada = false;
    final futuro = CapaPrioridadesCra.desdeJsonPorTramos(jPrioridades, tramoMs: 0);
    Future<void>.delayed(Duration.zero).then((_) => colada = true);
    await futuro;
    expect(colada, isTrue);
  });
}
