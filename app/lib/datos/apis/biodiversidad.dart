import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../zonas.dart';

class EspecieCercana {
  const EspecieCercana({required this.nombre, required this.cientifico, required this.fuente,
    required this.urlRegistro, this.foto, this.credito, this.licencia});
  final String nombre, cientifico, fuente, urlRegistro;
  final String? foto, credito, licencia;
  Map<String, dynamic> toJson() => {'nombre': nombre, 'cientifico': cientifico, 'fuente': fuente,
    'urlRegistro': urlRegistro, 'foto': foto, 'credito': credito, 'licencia': licencia};
  factory EspecieCercana.deJson(Map j) => EspecieCercana(
    nombre: j['nombre'] as String, cientifico: j['cientifico'] as String,
    fuente: j['fuente'] as String, urlRegistro: j['urlRegistro'] as String,
    foto: j['foto'] as String?, credito: j['credito'] as String?, licencia: j['licencia'] as String?);
}

List<EspecieCercana> parsearGbif(Object? respuesta) {
  final resultados = (respuesta as Map)['results'] as List? ?? const [];
  return [for (final item in resultados) if (item is Map) ...[
    if (item['key'] != null && (item['scientificName'] ?? item['species']) != null)
      EspecieCercana(
        nombre: (item['vernacularName'] ?? item['species'] ?? item['scientificName']).toString(),
        cientifico: (item['species'] ?? item['scientificName']).toString(), fuente: 'GBIF',
        urlRegistro: 'https://www.gbif.org/occurrence/${item['key']}',
        foto: _gbifFoto(item['media']), credito: _gbifCredito(item['media']),
        licencia: _gbifLicencia(item['media']) ?? item['license']?.toString(),
      ),
  ]];
}
Map? _primeraFoto(Object? media) {
  if (media is! List) return null;
  for (final m in media) {
    if (m is Map && m['identifier'] is String &&
        Uri.tryParse(m['identifier'] as String)?.scheme == 'https') {
      return m;
    }
  }
  return null;
}
String? _gbifFoto(Object? media) => _primeraFoto(media)?['identifier'] as String?;
String? _gbifCredito(Object? media) => _primeraFoto(media)?['creator']?.toString();
String? _gbifLicencia(Object? media) => _primeraFoto(media)?['license']?.toString();

List<EspecieCercana> parsearInaturalist(Object? respuesta) {
  final resultados = (respuesta as Map)['results'] as List? ?? const [];
  return [for (final item in resultados) if (item is Map && item['taxon'] is Map) ...[
    if (item['id'] != null) _observacion(item),
  ]];
}
EspecieCercana _observacion(Map j) {
  final taxon = j['taxon'] as Map;
  final fotos = j['photos'] as List? ?? const [];
  final foto = fotos.isNotEmpty && fotos.first is Map ? fotos.first as Map : null;
  final url = foto?['url']?.toString().replaceFirst('square', 'medium');
  return EspecieCercana(
    nombre: (taxon['preferred_common_name'] ?? j['species_guess'] ?? taxon['name']).toString(),
    cientifico: taxon['name']?.toString() ?? '', fuente: 'iNaturalist',
    urlRegistro: 'https://www.inaturalist.org/observations/${j['id']}',
    foto: Uri.tryParse(url ?? '')?.scheme == 'https' ? url : null,
    credito: foto?['attribution']?.toString(), licencia: foto?['license_code']?.toString(),
  );
}

class ResultadoBiodiversidad {
  const ResultadoBiodiversidad(this.especies, {this.deCache = false, this.error});
  final List<EspecieCercana> especies;
  final bool deCache;
  final String? error;
}

class ServicioBiodiversidad {
  ServicioBiodiversidad({http.Client? cliente, DateTime Function()? reloj})
      : _cliente = cliente ?? http.Client(), _propio = cliente == null, _reloj = reloj ?? DateTime.now;
  final http.Client _cliente;
  final bool _propio;
  final DateTime Function() _reloj;
  void cerrar() { if (_propio) _cliente.close(); }
  static const _plazoCache = Duration(hours: 12);

  Future<ResultadoBiodiversidad> cargar(ZonaManglar zona) async {
    final p = await SharedPreferences.getInstance();
    final key = 'biodiversidad.v1:${zona.id}';
    final guardado = p.getString(key);
    Map? cache;
    try { if (guardado != null) cache = jsonDecode(guardado) as Map; } catch (_) {}
    ResultadoBiodiversidad respaldo([String? error]) => ResultadoBiodiversidad(
      [for (final j in cache?['especies'] as List? ?? const []) EspecieCercana.deJson(j as Map)],
      deCache: cache != null, error: error);
    final fecha = DateTime.tryParse(cache?['fecha']?.toString() ?? '');
    if (fecha != null && _reloj().difference(fecha) < _plazoCache) return respaldo();
    try {
      final lat = zona.centro.latitude, lon = zona.centro.longitude;
      // GBIF acepta un polígono WKT (lon lat) alrededor del centro.
      final x1 = (lon - 0.15).toStringAsFixed(4), x2 = (lon + 0.15).toStringAsFixed(4);
      final y1 = (lat - 0.15).toStringAsFixed(4), y2 = (lat + 0.15).toStringAsFixed(4);
      final poligono = 'POLYGON(($x1 $y1,$x2 $y1,$x2 $y2,$x1 $y2,$x1 $y1))';
      final peticiones = <Uri>[
        Uri.https('api.gbif.org', '/v1/occurrence/search', {'geometry': poligono,
          'taxonKey': '212', 'hasCoordinate': 'true', 'limit': '12'}),
        for (final genero in ['Rhizophora', 'Avicennia', 'Laguncularia'])
          Uri.https('api.gbif.org', '/v1/occurrence/search', {'geometry': poligono,
            'scientificName': genero, 'hasCoordinate': 'true', 'limit': '8'}),
        Uri.https('api.inaturalist.org', '/v1/observations', {'lat': '$lat', 'lng': '$lon',
          'radius': '20', 'quality_grade': 'research', 'photos': 'true', 'locale': 'es',
          'per_page': '30', 'order_by': 'observed_on'}),
      ];
      final listas = <EspecieCercana>[];
      for (var i = 0; i < peticiones.length; i++) {
        try {
          final r = await _cliente.get(peticiones[i]).timeout(const Duration(seconds: 8));
          if (r.statusCode != 200) continue;
          listas.addAll(i < 4 ? parsearGbif(jsonDecode(r.body)) : parsearInaturalist(jsonDecode(r.body)));
        } catch (_) { /* Una fuente caída no borra las demás. */ }
      }
      if (listas.isEmpty) throw const FormatException('Sin observaciones disponibles');
      final unicas = <String, EspecieCercana>{};
      for (final e in listas) { unicas.putIfAbsent('${e.fuente}:${e.cientifico}', () => e); }
      final especies = unicas.values.toList();
      await p.setString(key, jsonEncode({'fecha': _reloj().toIso8601String(),
        'especies': especies.map((e) => e.toJson()).toList()}));
      return ResultadoBiodiversidad(especies);
    } catch (_) { return respaldo('Sin señal o sin datos nuevos.'); }
  }
}
