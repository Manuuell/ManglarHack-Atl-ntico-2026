import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zanqui/datos/guardian.dart';
import 'package:zanqui/datos/prioridad.dart';
import 'package:zanqui/datos/reporte.dart';
import 'package:zanqui/datos/tipos.dart';
import 'package:zanqui/datos/zonas.dart';

void main() {
  late Manglar manglar;

  setUpAll(() {
    final j = jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync());
    manglar = Manglar.desdeJson(j as Map<String, dynamic>);
  });

  group('Ubicar un punto contra el manglar', () {
    // Puntos hallados con un programa aparte (Python, rayo propio), no con este código.
    const dentro = {
      'mallorquin': LatLng(11.05316, -74.85094),
      'tubara': LatLng(10.9501, -75.02677),
      'juan_de_acosta': LatLng(10.85258, -75.13677),
      'piojo': LatLng(10.8162, -75.2035),
    };

    for (final e in dentro.entries) {
      test('un punto dentro de ${e.key} cae en su zona', () {
        final u = manglar.ubicar(e.value);
        expect(u.dentro, isTrue);
        expect(u.zona.id, e.key);
        expect(u.distanciaM, 0);
      });
    }

    test('el centro de Barranquilla queda fuera, a varios km, y se asigna a Mallorquín', () {
      final u = manglar.ubicar(const LatLng(10.9878, -74.7889));
      expect(u.dentro, isFalse);
      expect(u.zona.id, 'mallorquin');
      expect(u.distanciaM, greaterThan(3000));
      expect(u.enInfluencia, isFalse);
    });

    test('un punto a ~200 m de un polígono está en el área de influencia', () {
      // 0,0018° de latitud ≈ 200 m al norte del punto dentro de Mallorquín; el
      // borde puede quedar más cerca, nunca más lejos.
      final u = manglar.ubicar(const LatLng(11.05316 + 0.0018, -74.85094));
      expect(u.distanciaM, lessThanOrEqualTo(210));
      expect(u.enInfluencia, isTrue);
    });

    test('el área total y las cuatro zonas coinciden con la capa', () {
      expect(manglar.zonas.map((z) => z.id), ['mallorquin', 'tubara', 'juan_de_acosta', 'piojo']);
      expect(manglar.areaTotalHa, closeTo(533, 1));
    });
  });

  group('Prioridad (casos escritos a mano, no con la fórmula)', () {
    Ubicacion en(String zona, {bool dentro = true, double distancia = 0}) => Ubicacion(
          zona: manglar.zonaPorId(zona)!,
          dentro: dentro,
          distanciaM: distancia,
        );

    test('tala ahora dentro de Mallorquín es crítica (5) y dice por qué', () {
      final p = Prioridad.calcular(
          tipo: TipoAmenaza.tala, ubicacion: en('mallorquin'), momento: Momento.ahora, magnitud: Magnitud.pequena);
      expect(p.valor, 5);
      expect(p.nombre, 'Crítica');
      expect(p.motivos.join(' '), contains('conservación prioritaria'));
    });

    test('basuras vistas antes y lejos del manglar es baja (1)', () {
      final p = Prioridad.calcular(
          tipo: TipoAmenaza.basuras,
          ubicacion: en('tubara', dentro: false, distancia: 4000),
          momento: Momento.antes,
          magnitud: Magnitud.pequena);
      expect(p.valor, 1);
    });

    test('un caño taponado a 300 m (influencia) hoy queda en 4', () {
      final p = Prioridad.calcular(
          tipo: TipoAmenaza.canoTaponado,
          ubicacion: en('juan_de_acosta', dentro: false, distancia: 300),
          momento: Momento.hoy,
          magnitud: Magnitud.pequena);
      expect(p.valor, 4);
    });

    test('basuras en Tubará suben con un área grande y con otro reporte cerca', () {
      final solo = Prioridad.calcular(
          tipo: TipoAmenaza.basuras, ubicacion: en('tubara'), momento: Momento.ahora, magnitud: Magnitud.pequena);
      final grande = Prioridad.calcular(
          tipo: TipoAmenaza.basuras,
          ubicacion: en('tubara'),
          momento: Momento.ahora,
          magnitud: Magnitud.grande,
          corroboraciones: 2);
      expect(solo.valor, 2);
      expect(grande.valor, 4);
      expect(grande.motivos.last, contains('2 reportes parecidos'));
    });

    test('el viento fuerte solo pesa en un incendio', () {
      Prioridad con(TipoAmenaza t) => Prioridad.calcular(
          tipo: t,
          ubicacion: en('piojo', dentro: false, distancia: 2000),
          momento: Momento.ahora,
          magnitud: Magnitud.pequena,
          vientoKmh: 32);
      expect(con(TipoAmenaza.quema).valor, 5); // 5 − 1 (lejos) + 1 (viento)
      expect(con(TipoAmenaza.relleno).valor, 3); // 4 − 1, el viento no cuenta
    });
  });

  group('Reporte', () {
    Reporte ejemplo({bool anonimo = false}) => Reporte(
          id: '7f3a9c10-1111-4222-8333-444455556666',
          tipo: TipoAmenaza.quema,
          descripcion: 'Humo cerca del caño',
          punto: const LatLng(11.05, -74.85),
          precisionM: 12,
          metodo: MetodoUbicacion.gps,
          capturadoEn: DateTime.utc(2026, 11, 27, 14, 30),
          momento: Momento.ahora,
          magnitud: Magnitud.mediana,
          zonaId: 'mallorquin',
          zonaNombre: 'Ciénaga de Mallorquín',
          municipio: 'Barranquilla – Puerto Colombia',
          dentroPoligono: true,
          distanciaM: 0,
          prioridad: 5,
          motivosPrioridad: const ['x'],
          confianza: 80,
          anonimo: anonimo,
          reportanteId: 'guardian-1',
          fotoRef: '/ruta/privada.jpg',
        );

    test('el número de caso son los 4 primeros hex del id', () {
      expect(ejemplo().caso, 'ZQ-7F3A');
    });

    test('lo que viaja al servidor nunca lleva la ruta local de la foto', () {
      final s = ejemplo().aServidor();
      expect(s.containsKey('foto_ref'), isFalse);
      expect(jsonEncode(s), isNot(contains('/ruta/privada.jpg')));
      expect(s['canal'], 'app');
    });

    test('un reporte anónimo no manda quién lo hizo, pero el teléfono lo recuerda', () {
      final r = ejemplo(anonimo: true);
      expect(r.aServidor()['reportante_id'], isNull);
      expect(Reporte.fromJson(r.toJson()).reportanteId, 'guardian-1');
    });

    test('guardar y leer devuelve el mismo reporte', () {
      final r = ejemplo()..envio = Envio.error;
      final b = Reporte.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(b.id, r.id);
      expect(b.capturadoEn.toUtc(), r.capturadoEn);
      expect(b.envio, Envio.error);
      expect(b.fotoRef, r.fotoRef);
      expect(b.tipo, TipoAmenaza.quema);
    });
  });

  group('Guardián', () {
    test('la cédula nunca queda en claro y la misma cédula da la misma huella', () {
      final a = Perfil.huellaCedula('1.043.555.777');
      expect(a, isNot(contains('1043555777')));
      expect(a, Perfil.huellaCedula('1043555777'));
      expect(a.length, 64);
    });

    test('reportar mucho sin validar no sube de nivel', () {
      final muchos = [
        for (var i = 0; i < 20; i++)
          Reporte(
            id: '0000000$i-0000-4000-8000-000000000000'.substring(0, 36),
            tipo: TipoAmenaza.basuras,
            descripcion: '',
            punto: const LatLng(11, -74.8),
            precisionM: 10,
            metodo: MetodoUbicacion.gps,
            capturadoEn: DateTime(2026, 11, 27, 10),
            momento: Momento.ahora,
            magnitud: Magnitud.pequena,
            zonaId: 'mallorquin',
            zonaNombre: '',
            municipio: '',
            dentroPoligono: true,
            distanciaM: 0,
            prioridad: 2,
            motivosPrioridad: const [],
            confianza: 50,
            anonimo: false,
            reportanteId: 'g',
            envio: Envio.enviado,
          ),
      ];
      final p = Progreso.de(muchos);
      expect(p.puntos, 0);
      expect(p.nivel.nombre, 'Propágulo');
      expect(p.pendientes, greaterThan(0));
      expect(p.insignias, contains('primer_aviso'));
    });
  });
}
