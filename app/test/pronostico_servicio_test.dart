import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/pronostico/servicio_pronostico.dart';
import 'package:zanky/datos/zonas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ahora = DateTime.utc(2026, 11, 27, 17);
  final zona = ZonaManglar(
    id: 'mallorquin',
    nombre: 'Mallorquín',
    municipio: 'Barranquilla',
    prioridadConservacion: 3,
    nota: '',
    areaHa: 1,
    poligonos: [
      const [
        LatLng(11.05, -74.85),
        LatLng(11.06, -74.85),
        LatLng(11.05, -74.84),
      ],
    ],
  );

  Map<String, dynamic> serie() {
    final base = DateTime(2026, 11, 24);
    final horas = [
      for (var i = 0; i < 6 * 24; i++) base.add(Duration(hours: i)),
    ];
    String formato(DateTime f) =>
        '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}T${f.hour.toString().padLeft(2, '0')}:00';
    return {
      'hourly': {
        'time': horas.map(formato).toList(),
        'precipitation': <num?>[for (final h in horas) h.day == 27 ? 1 : 0],
        'temperature_2m': List<num?>.filled(horas.length, 32, growable: true),
        'relative_humidity_2m': List<num?>.filled(horas.length, 60, growable: true),
        'wind_speed_10m': List<num?>.filled(horas.length, 20, growable: true),
      },
    };
  }

  test('interpreta días secos previos y alinea olas por hora', () {
    final datos = serie();
    final horas = (datos['hourly'] as Map)['time'] as List;
    final mar = {
      'hourly': {
        'time': [horas[72], horas[73]],
        'wave_height': [1.5, 2.1],
      },
    };
    final p = interpretarPronostico('mallorquin', datos, mar, ahora)!;
    expect(p.dias.length, 3);
    expect(p.dias.first.diasSecos, 3);
    expect(p.dias.first.lluvia24, 24);
    expect(p.dias.first.olaMax, 2.1);
    expect(p.dias[1].olaMax, isNull);
  });

  test('JSON raro y series incompletas devuelven null sin lanzar', () {
    expect(
      interpretarPronostico('mallorquin', {'hourly': 'raro'}, null, ahora),
      isNull,
    );
    final datos = serie();
    ((datos['hourly'] as Map)['precipitation'] as List).removeLast();
    expect(interpretarPronostico('mallorquin', datos, null, ahora), isNull);
    expect(PronosticoZona.desdeJson({'zona': 'x', 'dias': []}), isNull);
  });

  test(
    'serie con nulos no inventa lluvia y dato marino ausente queda nulo',
    () {
      final datos = serie();
      ((datos['hourly'] as Map)['precipitation'] as List)[72] = null;
      final p = interpretarPronostico('mallorquin', datos, {
        'extraño': true,
      }, ahora)!;
      expect(p.dias.first.lluvia24, isNull);
      expect(p.dias.first.olaMax, isNull);
    },
  );

  test(
    'sin historial completo o con valores imposibles no inventa nivel bajo',
    () {
      final datos = serie();
      final horario = datos['hourly'] as Map;
      (horario['time'] as List).removeRange(0, 24);
      for (final clave in [
        'precipitation',
        'temperature_2m',
        'relative_humidity_2m',
        'wind_speed_10m',
      ]) {
        (horario[clave] as List).removeRange(0, 24);
      }
      (horario['relative_humidity_2m'] as List)[48] = 180;
      final p = interpretarPronostico('mallorquin', datos, null, ahora)!;
      expect(p.dias.first.diasSecos, isNull);
      expect(p.dias.first.humedadMin, isNull);
    },
  );

  test('sin red usa copia con fecha; sin copia devuelve null', () async {
    SharedPreferences.setMockInitialValues({});
    final correcto = MockClient((request) async {
      if (request.url.host == 'api.open-meteo.com') {
        return http.Response(jsonEncode(serie()), 200);
      }
      return http.Response('{}', 200);
    });
    final primero = await ServicioPronostico(
      cliente: correcto,
      reloj: () => ahora,
    ).cargar(zona);
    expect(primero, isNotNull);
    expect(primero!.deCache, isFalse);
    final sinRed = MockClient((_) async => throw Exception('sin red'));
    final guardado = await ServicioPronostico(
      cliente: sinRed,
      reloj: () => ahora,
    ).cargar(zona);
    expect(guardado?.deCache, isTrue);
    expect(guardado?.leido, primero.leido);
    SharedPreferences.setMockInitialValues({});
    expect(
      await ServicioPronostico(
        cliente: sinRed,
        reloj: () => ahora,
      ).cargar(zona),
      isNull,
    );
  });
}
