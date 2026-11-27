import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../zonas.dart';

class NivelMar {
  const NivelMar(this.hora, this.metros, {this.deCache = false});
  final DateTime hora;
  final double metros;
  final bool deCache;
  Map<String, dynamic> toJson() => {'hora': hora.toIso8601String(), 'metros': metros};
  static NivelMar? desdeJson(Object? valor, {bool deCache = false}) {
    try { final j = valor as Map; final n = (j['metros'] as num).toDouble();
      if (!n.isFinite || n.abs() > 20) return null;
      return NivelMar(DateTime.parse(j['hora'] as String), n, deCache: deCache);
    } catch (_) { return null; }
  }
}

NivelMar? parsearNivelMar(Object? respuesta, DateTime ahora) {
  try {
    final h = (respuesta as Map)['hourly'] as Map;
    final horas = h['time'] as List, niveles = h['sea_level_height_msl'] as List;
    if (horas.length != niveles.length) return null;
    NivelMar? elegido;
    var distancia = const Duration(days: 1000);
    for (var i = 0; i < horas.length; i++) {
      // Open-Meteo entrega horas sin sufijo aunque timezone=UTC.
      final cruda = horas[i].toString();
      final t = DateTime.tryParse(cruda.endsWith('Z') ? cruda : '${cruda}Z');
      final n = niveles[i];
      if (t == null || n is! num || !n.toDouble().isFinite) continue;
      final d = t.difference(ahora).abs();
      if (d < distancia) { distancia = d; elegido = NivelMar(t, n.toDouble()); }
    }
    return elegido;
  } catch (_) { return null; }
}

class ServicioMareas {
  ServicioMareas({http.Client? cliente, DateTime Function()? reloj})
      : _cliente = cliente ?? http.Client(), _propio = cliente == null, _reloj = reloj ?? DateTime.now;
  final http.Client _cliente;
  final bool _propio;
  final DateTime Function() _reloj;
  void cerrar() { if (_propio) _cliente.close(); }
  Future<NivelMar?> cargar(ZonaManglar zona) async {
    final p = await SharedPreferences.getInstance();
    final key = 'mar.v1:${zona.id}';
    NivelMar? copia;
    try { copia = NivelMar.desdeJson(jsonDecode(p.getString(key) ?? ''), deCache: true); } catch (_) {}
    if (copia != null && _reloj().difference(copia.hora).abs() < const Duration(minutes: 45)) return copia;
    try {
      final uri = Uri.https('marine-api.open-meteo.com', '/v1/marine', {
        'latitude': '${zona.centro.latitude}', 'longitude': '${zona.centro.longitude}',
        'hourly': 'sea_level_height_msl', 'forecast_days': '2', 'timezone': 'UTC',
        'cell_selection': 'sea',
      });
      final r = await _cliente.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return copia;
      final nivel = parsearNivelMar(jsonDecode(r.body), _reloj().toUtc());
      if (nivel == null) return copia;
      await p.setString(key, jsonEncode(nivel.toJson()));
      return nivel;
    } catch (_) { return copia; }
  }
}
