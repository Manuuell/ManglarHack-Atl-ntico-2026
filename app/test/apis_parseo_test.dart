import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/datos/apis/biodiversidad.dart';
import 'package:zanky/datos/apis/mareas.dart';

void main() {
  test('GBIF conserva identificación, foto, autor y licencia', () {
    final especies = parsearGbif({'results': [{
      'key': 123, 'species': 'Rhizophora mangle', 'vernacularName': 'Mangle rojo',
      'media': [{'identifier': 'https://img.ejemplo.org/mangle.jpg',
        'creator': 'Autora', 'license': 'CC BY 4.0'}],
    }]});
    expect(especies.single.nombre, 'Mangle rojo');
    expect(especies.single.credito, 'Autora');
    expect(especies.single.licencia, 'CC BY 4.0');
    expect(especies.single.urlRegistro, 'https://www.gbif.org/occurrence/123');
  });

  test('iNaturalist toma nombre común, foto y atribución', () {
    final especies = parsearInaturalist({'results': [{
      'id': 7, 'taxon': {'name': 'Avicennia germinans',
        'preferred_common_name': 'Mangle negro'},
      'photos': [{'url': 'https://img.ejemplo.org/square.jpg',
        'attribution': '© Observador', 'license_code': 'cc-by'}],
    }]});
    expect(especies.single.nombre, 'Mangle negro');
    expect(especies.single.foto, 'https://img.ejemplo.org/medium.jpg');
    expect(especies.single.credito, '© Observador');
  });

  test('nivel del mar tolera huecos y usa la hora UTC más cercana', () {
    final ahora = DateTime.utc(2026, 11, 27, 12);
    final nivel = parsearNivelMar({'hourly': {
      'time': ['2026-11-27T11:00', '2026-11-27T12:00', '2026-11-27T13:00'],
      'sea_level_height_msl': [null, 0.31, 0.6],
    }}, ahora);
    expect(nivel?.metros, 0.31);
    expect(nivel?.hora.isUtc, isTrue);
    expect(parsearNivelMar({'hourly': {'time': [], 'sea_level_height_msl': [1]}}, ahora), isNull);
  });
}
