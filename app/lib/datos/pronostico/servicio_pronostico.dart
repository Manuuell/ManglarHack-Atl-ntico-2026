import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../zonas.dart';
import 'reglas.dart';

class PronosticoZona {
  const PronosticoZona(
    this.zonaId,
    this.leido,
    this.dias, {
    this.deCache = false,
  });
  final String zonaId;
  final DateTime leido;
  final List<LecturaDia> dias;
  final bool deCache;

  Map<String, dynamic> toJson() => {
    'zona': zonaId,
    'leido': leido.toIso8601String(),
    'dias': [
      for (final d in dias)
        {
          'fecha': d.fecha.toIso8601String(),
          'lluvia24': d.lluvia24,
          'lluvia72': d.lluvia72,
          'temperatura': d.temperaturaMax,
          'humedad': d.humedadMin,
          'viento': d.vientoMax,
          'ola': d.olaMax,
          'secos': d.diasSecos,
        },
    ],
  };

  static PronosticoZona? desdeJson(Object? valor, {bool deCache = false}) {
    try {
      final j = valor as Map;
      final dias = <LecturaDia>[];
      for (final objeto in j['dias'] as List) {
        final d = objeto as Map;
        dias.add(
          LecturaDia(
            fecha: DateTime.parse(d['fecha'] as String),
            lluvia24: _enRango(d['lluvia24'], 0, 12000),
            lluvia72: _enRango(d['lluvia72'], 0, 36000),
            temperaturaMax: _enRango(d['temperatura'], -50, 60),
            humedadMin: _enRango(d['humedad'], 0, 100),
            vientoMax: _enRango(d['viento'], 0, 250),
            olaMax: _enRango(d['ola'], 0, 30),
            diasSecos: d['secos'] is int && d['secos'] >= 0 && d['secos'] <= 3
                ? d['secos'] as int
                : null,
          ),
        );
      }
      if (dias.isEmpty) return null;
      return PronosticoZona(
        j['zona'] as String,
        DateTime.parse(j['leido'] as String),
        dias,
        deCache: deCache,
      );
    } catch (_) {
      return null;
    }
  }
}

double? _numero(Object? valor) {
  if (valor is! num) return null;
  final n = valor.toDouble();
  return n.isFinite ? n : null;
}

double? _enRango(Object? valor, double minimo, double maximo) {
  final numero = _numero(valor);
  return numero != null && numero >= minimo && numero <= maximo ? numero : null;
}

/// Sigue el patrón de Clima.leer/ultimo: API pública, plazo y copia local por zona.
class ServicioPronostico {
  ServicioPronostico({http.Client? cliente, DateTime Function()? reloj})
    : _cliente = cliente ?? http.Client(),
      _propio = cliente == null,
      _reloj = reloj ?? DateTime.now;
  final http.Client _cliente;
  final bool _propio;
  final DateTime Function() _reloj;
  static const _clave = 'pronostico.v1:';

  void cerrar() {
    if (_propio) _cliente.close();
  }

  Future<PronosticoZona?> ultimo(String zonaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString('$_clave$zonaId');
      return guardado == null
          ? null
          : PronosticoZona.desdeJson(jsonDecode(guardado), deCache: true);
    } catch (_) {
      return null;
    }
  }

  Future<PronosticoZona?> cargar(ZonaManglar zona) async {
    final lat = zona.centro.latitude.toStringAsFixed(3);
    final lon = zona.centro.longitude.toStringAsFixed(3);
    try {
      final tiempo = await _cliente
          .get(
            Uri.parse(
              'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
              '&hourly=precipitation,temperature_2m,relative_humidity_2m,wind_speed_10m'
              '&past_days=3&forecast_days=3&timezone=America%2FBogota',
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (tiempo.statusCode != 200) {
        throw const FormatException('Tiempo no disponible');
      }
      Object? mar;
      try {
        final respuesta = await _cliente
            .get(
              Uri.parse(
                'https://marine-api.open-meteo.com/v1/marine?latitude=$lat&longitude=$lon'
                '&hourly=wave_height&forecast_days=3&timezone=America%2FBogota',
              ),
            )
            .timeout(const Duration(seconds: 6));
        if (respuesta.statusCode == 200) mar = jsonDecode(respuesta.body);
      } catch (_) {
        // El dato marino puede faltar en celdas próximas a la costa.
      }
      final nuevo = interpretarPronostico(
        zona.id,
        jsonDecode(tiempo.body),
        mar,
        _reloj(),
      );
      if (nuevo == null) {
        throw const FormatException('Serie horaria incompleta');
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_clave${zona.id}', jsonEncode(nuevo.toJson()));
      } catch (_) {
        // El pronóstico recién leído sigue siendo útil si el almacenamiento falla.
      }
      return nuevo;
    } catch (_) {
      return ultimo(zona.id);
    }
  }
}

/// Horas de Open-Meteo expresadas en America/Bogota, sin depender de la zona del teléfono.
PronosticoZona? interpretarPronostico(
  String zonaId,
  Object? tiempo,
  Object? mar,
  DateTime ahora,
) {
  try {
    final horas = (tiempo as Map)['hourly'] as Map;
    final fechas = horas['time'] as List;
    final lluvias = horas['precipitation'] as List;
    final temperaturas = horas['temperature_2m'] as List;
    final humedades = horas['relative_humidity_2m'] as List;
    final vientos = horas['wind_speed_10m'] as List;
    if ([
      lluvias,
      temperaturas,
      humedades,
      vientos,
    ].any((a) => a.length != fechas.length)) {
      return null;
    }
    final serie = <String, List<int>>{};
    for (var i = 0; i < fechas.length; i++) {
      final fecha = fechas[i];
      if (fecha is! String ||
          fecha.length < 13 ||
          DateTime.tryParse(fecha) == null) {
        return null;
      }
      serie.putIfAbsent(fecha.substring(0, 10), () => []).add(i);
    }
    if (serie.isEmpty) return null;
    final marPorHora = <String, double>{};
    try {
      final horario = (mar as Map)['hourly'] as Map;
      final tiemposMar = horario['time'] as List;
      final olas = horario['wave_height'] as List;
      for (var i = 0; i < tiemposMar.length && i < olas.length; i++) {
        final n = _enRango(olas[i], 0, 30);
        if (tiemposMar[i] is String && n != null) {
          marPorHora[tiemposMar[i] as String] = n;
        }
      }
    } catch (_) {
      // Se conserva el resto del pronóstico y oleaje queda sin dato.
    }
    final hoy = ahora.toUtc().subtract(const Duration(hours: 5));
    final inicio = DateTime.utc(hoy.year, hoy.month, hoy.day);
    final dias = <LecturaDia>[];
    var hayHorasFuturas = false;
    double? suma(List<int> indices) {
      if (indices.isEmpty ||
          indices.any((i) => _enRango(lluvias[i], 0, 500) == null)) {
        return null;
      }
      return indices.fold<double>(
        0,
        (a, i) => a + _enRango(lluvias[i], 0, 500)!,
      );
    }

    double? extremo(
      List<int> indices,
      List valores, {
      required bool maximo,
      required double minimo,
      required double tope,
    }) {
      final numeros = [
        for (final i in indices) ?_enRango(valores[i], minimo, tope),
      ];
      if (numeros.isEmpty || numeros.length != indices.length) return null;
      return numeros.reduce(
        (a, b) => maximo ? (a > b ? a : b) : (a < b ? a : b),
      );
    }

    String clave(DateTime fecha) =>
        '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
    for (var dia = 0; dia < 3; dia++) {
      final fecha = inicio.add(Duration(days: dia));
      final indices = serie[clave(fecha)] ?? [];
      if (indices.isNotEmpty) hayHorasFuturas = true;
      final siguientes = <int>[
        for (var i = dia; i < 3; i++)
          ...?serie[clave(inicio.add(Duration(days: i)))],
      ];
      var secos = 0;
      var sequedadConocida = true;
      for (var i = 1; i <= 3; i++) {
        final anterior = serie[clave(fecha.subtract(Duration(days: i)))];
        if (anterior == null || anterior.length != 24) {
          sequedadConocida = false;
          break;
        }
        final lluvia = suma(anterior);
        if (lluvia == null) {
          sequedadConocida = false;
          break;
        }
        if (lluvia >= 1) break;
        secos++;
      }
      final olas = [for (final i in indices) ?marPorHora[fechas[i]]];
      dias.add(
        LecturaDia(
          fecha: fecha,
          lluvia24: suma(indices),
          lluvia72: suma(siguientes),
          temperaturaMax: extremo(
            indices,
            temperaturas,
            maximo: true,
            minimo: -50,
            tope: 60,
          ),
          humedadMin: extremo(
            indices,
            humedades,
            maximo: false,
            minimo: 0,
            tope: 100,
          ),
          vientoMax: extremo(
            indices,
            vientos,
            maximo: true,
            minimo: 0,
            tope: 250,
          ),
          olaMax: olas.isEmpty ? null : olas.reduce((a, b) => a > b ? a : b),
          diasSecos: sequedadConocida ? secos : null,
        ),
      );
    }
    return hayHorasFuturas ? PronosticoZona(zonaId, ahora, dias) : null;
  } catch (_) {
    return null;
  }
}
