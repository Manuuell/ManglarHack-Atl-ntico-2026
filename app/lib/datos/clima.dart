import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiempo actual en el manglar (Open-Meteo, sin clave). Sirve para priorizar: con
/// viento fuerte un fuego crece; tras lluvias fuertes un caño taponado inunda.
/// Se guarda la última lectura con su hora para mostrarla sin señal («hace 2 h»).
class Clima {
  const Clima({
    required this.temperatura,
    required this.vientoKmh,
    required this.vientoDireccion,
    required this.lluviaMm,
    required this.olaM,
    required this.leido,
  });

  final double temperatura;
  final double vientoKmh;
  final int vientoDireccion;
  final double lluviaMm;
  final double? olaM;
  final DateTime leido;

  String get rumbo {
    const r = ['norte', 'noreste', 'este', 'sureste', 'sur', 'suroeste', 'oeste', 'noroeste'];
    return r[((vientoDireccion % 360) / 45).round() % 8];
  }

  /// Una frase que entiende cualquiera, para la tarjeta del inicio.
  String get frase {
    if (vientoKmh >= 25) return 'Viento fuerte del $rumbo: si ves humo, repórtalo ya.';
    if (lluviaMm >= 2) return 'Está lloviendo: fíjate si algún caño está represando el agua.';
    if ((olaM ?? 0) >= 1.5) return 'Mar picado: las raíces del manglar frenan el oleaje por nosotros.';
    return 'Buen día para recorrer el manglar con los ojos abiertos.';
  }

  Map<String, dynamic> toJson() => {
        't': temperatura,
        'v': vientoKmh,
        'd': vientoDireccion,
        'l': lluviaMm,
        'o': olaM,
        'f': leido.toIso8601String(),
      };

  static Clima fromJson(Map<String, dynamic> j) => Clima(
        temperatura: (j['t'] as num).toDouble(),
        vientoKmh: (j['v'] as num).toDouble(),
        vientoDireccion: (j['d'] as num).toInt(),
        lluviaMm: (j['l'] as num).toDouble(),
        olaM: (j['o'] as num?)?.toDouble(),
        leido: DateTime.parse(j['f'] as String),
      );

  static const _clave = 'clima:';

  static Future<Clima?> ultimo(String zonaId) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('$_clave$zonaId');
    return s == null ? null : fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  /// Lee el tiempo actual. Si falla (sin señal), devuelve null y la app usa [ultimo].
  static Future<Clima?> leer(String zonaId, LatLng p) async {
    final lat = p.latitude.toStringAsFixed(3), lon = p.longitude.toStringAsFixed(3);
    try {
      final tiempo = await http
          .get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
              '&current=temperature_2m,precipitation,wind_speed_10m,wind_direction_10m&timezone=America%2FBogota'))
          .timeout(const Duration(seconds: 8));
      if (tiempo.statusCode != 200) return null;
      final c = (jsonDecode(tiempo.body) as Map<String, dynamic>)['current'] as Map<String, dynamic>;

      double? ola;
      try {
        final mar = await http
            .get(Uri.parse('https://marine-api.open-meteo.com/v1/marine?latitude=$lat&longitude=$lon'
                '&current=wave_height&timezone=America%2FBogota'))
            .timeout(const Duration(seconds: 6));
        if (mar.statusCode == 200) {
          ola = (((jsonDecode(mar.body) as Map)['current'] as Map?)?['wave_height'] as num?)?.toDouble();
        }
      } catch (_) {
        // El oleaje es un extra: sin él la tarjeta sigue.
      }

      final clima = Clima(
        temperatura: (c['temperature_2m'] as num).toDouble(),
        vientoKmh: (c['wind_speed_10m'] as num).toDouble(),
        vientoDireccion: (c['wind_direction_10m'] as num).toInt(),
        lluviaMm: (c['precipitation'] as num).toDouble(),
        olaM: ola,
        leido: DateTime.now(),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_clave$zonaId', jsonEncode(clima.toJson()));
      return clima;
    } catch (_) {
      return null;
    }
  }
}
