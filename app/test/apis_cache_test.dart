import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/apis/biodiversidad.dart';
import 'package:zanky/datos/apis/mareas.dart';
import 'package:zanky/datos/zonas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ahora = DateTime.utc(2026, 11, 27, 12);
  final zona = ZonaManglar(id: 'prueba', nombre: 'Prueba', municipio: 'Atlántico',
    prioridadConservacion: 3, nota: '', areaHa: 1,
    poligonos: [const [LatLng(11.05, -74.85), LatLng(11.06, -74.85), LatLng(11.05, -74.84)]]);

  test('biodiversidad usa caché fresco y respaldo sin señal', () async {
    SharedPreferences.setMockInitialValues({});
    var consultas = 0;
    final cliente = MockClient((request) async {
      consultas++;
      if (request.url.host == 'api.inaturalist.org') {
        return http.Response(jsonEncode({'results': [{
          'id': 4, 'taxon': {'name': 'Rhizophora mangle',
            'preferred_common_name': 'Mangle rojo'}, 'photos': [],
        }]}), 200);
      }
      return http.Response('{"results":[]}', 200);
    });
    final servicio = ServicioBiodiversidad(cliente: cliente, reloj: () => ahora);
    final primero = await servicio.cargar(zona);
    expect(primero.especies.single.nombre, 'Mangle rojo');
    final cantidad = consultas;
    expect((await servicio.cargar(zona)).deCache, isTrue);
    expect(consultas, cantidad);
    final sinRed = ServicioBiodiversidad(cliente: MockClient((_) async {
      throw Exception('sin red');
    }), reloj: () => ahora.add(const Duration(days: 1)));
    final respaldo = await sinRed.cargar(zona);
    expect(respaldo.deCache, isTrue);
    expect(respaldo.especies.single.nombre, 'Mangle rojo');
  });

  test('Open-Meteo conserva lectura para uso sin red', () async {
    SharedPreferences.setMockInitialValues({});
    final servicio = ServicioMareas(reloj: () => ahora, cliente: MockClient((request) async {
      expect(request.url.queryParameters['cell_selection'], 'sea');
      return http.Response('{"hourly":{"time":["2026-11-27T12:00"],"sea_level_height_msl":[0.42]}}', 200);
    }));
    expect((await servicio.cargar(zona))?.metros, 0.42);
    final sinRed = ServicioMareas(reloj: () => ahora.add(const Duration(hours: 3)),
      cliente: MockClient((_) async => http.Response('sin datos', 503)));
    final respaldo = await sinRed.cargar(zona);
    expect(respaldo?.deCache, isTrue);
    expect(respaldo?.metros, 0.42);
  });
}
