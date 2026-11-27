import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zanky/datos/zonas.dart';

/// Pruebas de las capas OFICIALES de la CRA (manglar 1:5.000 y prioridades de conservación).
///
/// Los valores esperados salen de un oráculo aparte en Python (ray casting propio) que lee el
/// GeoJSON y el KML ORIGINALES de la CRA, sin simplificar. Los puntos están a más de 13 m de
/// cualquier borde para que la simplificación de la app (1 m en el manglar, 2,5 m en las
/// prioridades) no los cambie.
void main() {
  late Manglar manglar;

  setUpAll(() {
    final j = jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync());
    final p = jsonDecode(File('assets/datos/prioridades_cra.json').readAsStringSync());
    manglar = Manglar.desdeJson(j as Map<String, dynamic>, p as Map<String, dynamic>);
  });

  group('El archivo de la CRA', () {
    test('trae las 4 zonas con ids estables, sector oficial y hectáreas reales', () {
      // Hectáreas = suma de area_ha de la CRA por zona (oráculo: centroide y cortes de longitud).
      const esperado = {
        'mallorquin': ('Mallorquín', 323.26),
        'tubara': ('Balboa', 154.60),
        'juan_de_acosta': ('Manatíes', 47.16),
        'piojo': ('Totumo', 124.64),
      };
      expect(manglar.zonas.map((z) => z.id), esperado.keys);
      for (final z in manglar.zonas) {
        expect(z.sectorCra, esperado[z.id]!.$1, reason: z.id);
        expect(z.areaHa, closeTo(esperado[z.id]!.$2, 0.01), reason: z.id);
      }
      expect(manglar.areaTotalHa, closeTo(649.66, 0.01));
      expect(manglar.zonas.map((z) => z.poligonos.length), [145, 390, 80, 271]);
      expect(manglar.provisional, isFalse);
      expect(manglar.fuente, contains('CRA'));
      expect(manglar.fechaDatos, isNotEmpty);
    });

    test('la etiqueta dice el sector oficial con el municipio', () {
      expect(manglar.zonaPorId('tubara')!.etiquetaSector, 'Sector Balboa (Tubará)');
      expect(manglar.zonaPorId('piojo')!.etiquetaSector, 'Sector Totumo (Piojó)');
    });

    test('la prioridad de cada zona es la que cubre más hectáreas de su manglar', () {
      // Oráculo (ha por prioridad con el centroide de cada polígono):
      // mallorquín 238 media / 14 alta; tubará 116 alta; juan de acosta 24 alta; piojó 106 alta.
      expect(manglar.zonaPorId('mallorquin')!.prioridadCra, PrioridadCRA.media);
      expect(manglar.zonaPorId('mallorquin')!.prioridadConservacion, 4);
      for (final id in ['tubara', 'juan_de_acosta', 'piojo']) {
        expect(manglar.zonaPorId(id)!.prioridadCra, PrioridadCRA.alta, reason: id);
        expect(manglar.zonaPorId(id)!.prioridadConservacion, 5, reason: id);
      }
    });

    test('la capa de prioridades se cargó entera', () {
      expect(manglar.prioridades, isNotNull);
      expect(manglar.prioridades!.poligonos, greaterThan(9000));
    });
  });

  group('Prioridad de conservación CRA en un punto', () {
    void caso(String nombre, LatLng p,
        {required String zona,
        required bool dentro,
        PrioridadCRA? prioridad,
        String? accion,
        String? escenario,
        int puntos = 3}) {
      test(nombre, () {
        final u = manglar.ubicar(p);
        expect(u.zona.id, zona);
        expect(u.dentro, dentro);
        expect(u.prioridadCra, prioridad);
        expect(u.fueraZonificacion, prioridad == null);
        expect(u.plan?.accion, accion);
        expect(u.plan?.escenario, escenario);
        expect(u.prioridadConservacion, puntos);
      });
    }

    caso('dentro del manglar de Mallorquín: Alta, preservación, escenario I',
        const LatLng(11.04466, -74.86898),
        zona: 'mallorquin', dentro: true, prioridad: PrioridadCRA.alta, accion: 'Preservación', escenario: 'Escenario I', puntos: 5);
    caso('dentro del manglar de Mallorquín en un polígono Medio',
        const LatLng(11.04131, -74.86836),
        zona: 'mallorquin', dentro: true, prioridad: PrioridadCRA.media, accion: 'Preservación', escenario: 'Escenario I', puntos: 4);
    caso('dentro del manglar de Tubará (Balboa): Alta',
        const LatLng(10.94487, -75.02494),
        zona: 'tubara', dentro: true, prioridad: PrioridadCRA.alta, accion: 'Preservación', escenario: 'Escenario I', puntos: 5);
    caso('dentro del manglar de Tubará en un polígono Bajo: rehabilitación, escenario III',
        const LatLng(10.89402, -75.05148),
        zona: 'tubara', dentro: true, prioridad: PrioridadCRA.baja, accion: 'Rehabilitación', escenario: 'Escenario III', puntos: 3);
    caso('Juan de Acosta (Manatíes): Alta', const LatLng(10.85922, -75.12523),
        zona: 'juan_de_acosta', dentro: true, prioridad: PrioridadCRA.alta, accion: 'Preservación', escenario: 'Escenario I', puntos: 5);
    caso('Piojó (Totumo): Alta, restauración', const LatLng(10.79734, -75.21273),
        zona: 'piojo', dentro: true, prioridad: PrioridadCRA.alta, accion: 'Restauración', escenario: 'Escenario I', puntos: 5);
    caso('manglar dentro, pero FUERA de la zonificación de la CRA (Mallorquín)',
        const LatLng(11.03666, -74.88738),
        zona: 'mallorquin', dentro: true);

    test('el punto de prueba del handoff está fuera del manglar (394 m) pero con prioridad Alta', () {
      final u = manglar.ubicar(puntoMallorquin);
      expect(u.dentro, isFalse);
      expect(u.distanciaM, closeTo(394.2, 6));
      expect(u.enInfluencia, isTrue);
      expect(u.prioridadCra, PrioridadCRA.alta);
      expect(u.plan!.resumen, 'Alta (preservación)');
    });

    test('en el mar, a 3,4 km del manglar: fuera de la zonificación, 3 puntos', () {
      final u = manglar.ubicar(const LatLng(11.075, -74.88));
      expect(u.zona.id, 'mallorquin');
      expect(u.dentro, isFalse);
      expect(u.distanciaM, closeTo(3357.8, 15));
      expect(u.enInfluencia, isFalse);
      expect(u.fueraZonificacion, isTrue);
      expect(u.plan, isNull);
      expect(u.prioridadCra, isNull);
      expect(u.prioridadConservacion, 3);
    });

    test('un polígono dentro de un área protegida trae su nombre', () {
      // Oráculo: reserva forestal protectora «RFP Palomar», prioridad Media, preservación.
      final plan = manglar.prioridades!.en(const LatLng(10.74726, -75.13669))!;
      expect(plan.areaProtegida, 'RFP Palomar');
      expect(plan.prioridad, PrioridadCRA.media);
      expect(plan.accion, 'Preservación');
    });

    test('sin la capa de prioridades no se inventa nada: ni plan ni «fuera»', () {
      final j = jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync());
      final solo = Manglar.desdeJson(j as Map<String, dynamic>);
      final u = solo.ubicar(const LatLng(11.04466, -74.86898));
      expect(u.dentro, isTrue);
      expect(u.plan, isNull);
      expect(u.fueraZonificacion, isFalse);
      expect(u.prioridadConservacion, solo.zonaPorId('mallorquin')!.prioridadConservacion);
    });
  });

  group('Regla «si varios polígonos, la más alta» (capa sintética)', () {
    // Cuadrados en unidades de 1e-5°: [x0, y0, dx, dy, ...]. Todo en lon -74.91..-74.87.
    Map<String, dynamic> manglarMini() => {
          'unidad': 100000,
          'fuente': 'prueba',
          'areaTotalHa': 1,
          'zonas': [
            {
              'id': 'mallorquin',
              'nombre': 'Z',
              'municipio': 'M',
              'nota': '',
              'areaHa': 1,
              'poligonos': [
                [
                  [-7490000, 1100000, 1000, 0, 0, 1000, -1000, 0],
                ],
              ],
            },
          ],
        };

    Map<String, dynamic> capa(List<List<Object>> polis) => {
          'unidad': 100000,
          'atributos': [
            {'p': 'baja', 'a': 'Recuperación', 'e': 'Escenario III', 'f': 'Conectividad', 'z': '', 'u': ''},
            {'p': 'alta', 'a': 'Preservación', 'e': 'Escenario I', 'f': '', 'z': 'Zona X', 'u': 'U'},
          ],
          'poligonos': polis,
        };

    // A (baja): lon -74.91..-74.87, lat 10.99..11.03. B (alta): -74.90..-74.89 × 11.00..11.01,
    // con un hueco en -74.897..-74.894 × 11.003..11.006.
    final a = [-7491000, 1099000, 4000, 0, 0, 4000, -4000, 0];
    final b = [-7490000, 1100000, 1000, 0, 0, 1000, -1000, 0];
    final hueco = [-7489700, 1100300, 300, 0, 0, 300, -300, 0];

    for (final alReves in [false, true]) {
      test('gana la alta aunque venga ${alReves ? 'antes' : 'después'} en el archivo', () {
        final polis = [
          [0, [a]],
          [1, [b, hueco]],
        ];
        final m = Manglar.desdeJson(manglarMini(), capa(alReves ? polis.reversed.toList() : polis));
        final enAmbas = m.ubicar(const LatLng(11.001, -74.8995));
        expect(enAmbas.prioridadCra, PrioridadCRA.alta);
        expect(enAmbas.plan!.areaProtegida, 'Zona X');
        expect(enAmbas.plan!.unidad, 'U');
        expect(enAmbas.dentro, isTrue);
        // Solo en la baja:
        expect(m.ubicar(const LatLng(11.02, -74.88)).prioridadCra, PrioridadCRA.baja);
        expect(m.ubicar(const LatLng(11.02, -74.88)).plan!.areaProtegida, isNull);
        // En el hueco de la alta: cae a la baja que lo cubre.
        expect(m.ubicar(const LatLng(11.0045, -74.8955)).prioridadCra, PrioridadCRA.baja);
        // Fuera de todo:
        final fuera = m.ubicar(const LatLng(11.5, -74.0));
        expect(fuera.fueraZonificacion, isTrue);
        expect(fuera.prioridadConservacion, 3);
      });
    }
  });
}
