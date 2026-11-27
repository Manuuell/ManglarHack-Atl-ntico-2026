import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// Una de las cuatro zonas de manglar que nombró la CRA.
class ZonaManglar {
  ZonaManglar({
    required this.id,
    required this.nombre,
    required this.municipio,
    required this.prioridadConservacion,
    required this.nota,
    required this.areaHa,
    required this.poligonos,
  }) : cajas = poligonos.map(Caja.de).toList();

  final String id;
  final String nombre;
  final String municipio;

  /// 1-5, PROVISIONAL hasta validarlo con los mentores ambientales.
  final int prioridadConservacion;
  final String nota;
  final double areaHa;

  /// Anillos exteriores en [lat, lon].
  final List<List<LatLng>> poligonos;
  final List<Caja> cajas;

  LatLng get centro {
    var lat = 0.0, lon = 0.0, n = 0;
    for (final p in poligonos) {
      for (final q in p) {
        lat += q.latitude;
        lon += q.longitude;
        n++;
      }
    }
    return LatLng(lat / n, lon / n);
  }
}

class Caja {
  Caja(this.minLat, this.maxLat, this.minLon, this.maxLon);
  final double minLat, maxLat, minLon, maxLon;

  static Caja de(List<LatLng> p) {
    var a = 90.0, b = -90.0, c = 180.0, d = -180.0;
    for (final q in p) {
      a = math.min(a, q.latitude);
      b = math.max(b, q.latitude);
      c = math.min(c, q.longitude);
      d = math.max(d, q.longitude);
    }
    return Caja(a, b, c, d);
  }

  bool contiene(LatLng q, [double margenGrados = 0]) =>
      q.latitude >= minLat - margenGrados &&
      q.latitude <= maxLat + margenGrados &&
      q.longitude >= minLon - margenGrados &&
      q.longitude <= maxLon + margenGrados;
}

/// Resultado de ubicar un punto contra el manglar.
class Ubicacion {
  const Ubicacion({required this.zona, required this.dentro, required this.distanciaM});

  /// Zona más cercana (siempre hay una: el reporte se asigna a la más próxima).
  final ZonaManglar zona;
  final bool dentro;

  /// 0 si está dentro.
  final double distanciaM;

  /// Área de influencia: un vertimiento o un caño taponado pueden estar fuera del
  /// polígono y afectarlo igual (handoff/03).
  static const influenciaM = 500.0;
  bool get enInfluencia => dentro || distanciaM <= influenciaM;

  String get resumen {
    if (dentro) return 'Dentro del manglar · ${zona.nombre}';
    if (distanciaM < 1000) return 'A ${distanciaM.round()} m del manglar · ${zona.nombre}';
    return 'A ${(distanciaM / 1000).toStringAsFixed(1)} km del manglar · ${zona.nombre}';
  }
}

/// Las zonas de manglar del Atlántico, cargadas del archivo que va dentro de la app:
/// ubicar un reporte funciona sin internet.
class Manglar {
  Manglar._(this.zonas, this.fuente, this.provisional, this.areaTotalHa);

  final List<ZonaManglar> zonas;
  final String fuente;
  final bool provisional;
  final double areaTotalHa;

  static Future<Manglar> cargar() async {
    final texto = await rootBundle.loadString('assets/datos/manglar_zonas.json');
    return desdeJson(jsonDecode(texto) as Map<String, dynamic>);
  }

  static Manglar desdeJson(Map<String, dynamic> j) {
    final zonas = [
      for (final z in j['zonas'] as List)
        ZonaManglar(
          id: z['id'] as String,
          nombre: z['nombre'] as String,
          municipio: z['municipio'] as String,
          prioridadConservacion: z['prioridadConservacion'] as int,
          nota: z['nota'] as String,
          areaHa: (z['areaHa'] as num).toDouble(),
          poligonos: [
            for (final p in z['poligonos'] as List)
              [for (final c in p as List) LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())],
          ],
        ),
    ];
    return Manglar._(
      zonas,
      j['fuente'] as String,
      j['provisional'] as bool? ?? true,
      (j['areaTotalHa'] as num).toDouble(),
    );
  }

  ZonaManglar? zonaPorId(String? id) {
    for (final z in zonas) {
      if (z.id == id) return z;
    }
    return null;
  }

  /// Ubica un punto: ¿está dentro de algún polígono?, ¿a qué distancia del borde más
  /// cercano?, ¿de qué zona? Primero filtra por caja para no recorrer los 21 000 vértices.
  Ubicacion ubicar(LatLng p) {
    // 1) ¿Dentro de algún polígono?
    for (final z in zonas) {
      for (var i = 0; i < z.poligonos.length; i++) {
        if (z.cajas[i].contiene(p) && _dentro(p, z.poligonos[i])) {
          return Ubicacion(zona: z, dentro: true, distanciaM: 0);
        }
      }
    }
    // 2) Distancia al borde más cercano. Margen de ~3 km para el filtro; si nada
    //    cae ahí, se recorre todo (es raro: alguien muy lejos de la costa).
    ZonaManglar? mejorZona;
    var mejor = double.infinity;
    for (final margen in const [0.03, 10.0]) {
      for (final z in zonas) {
        for (var i = 0; i < z.poligonos.length; i++) {
          if (!z.cajas[i].contiene(p, margen)) continue;
          final d = _distanciaAlAnillo(p, z.poligonos[i]);
          if (d < mejor) {
            mejor = d;
            mejorZona = z;
          }
        }
      }
      if (mejorZona != null) break;
    }
    return Ubicacion(zona: mejorZona ?? zonas.first, dentro: false, distanciaM: mejor);
  }

  /// Punto en polígono por cruce de rayos (el anillo en grados basta a esta escala).
  static bool _dentro(LatLng p, List<LatLng> anillo) {
    var dentro = false;
    final x = p.longitude, y = p.latitude;
    for (var i = 0, j = anillo.length - 1; i < anillo.length; j = i++) {
      final xi = anillo[i].longitude, yi = anillo[i].latitude;
      final xj = anillo[j].longitude, yj = anillo[j].latitude;
      if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) dentro = !dentro;
    }
    return dentro;
  }

  /// Distancia en metros del punto al anillo, proyectando a un plano local
  /// (equirectangular): a esta escala (pocos km) el error es de centímetros.
  static double _distanciaAlAnillo(LatLng p, List<LatLng> anillo) {
    final kx = 111320.0 * math.cos(p.latitude * math.pi / 180);
    const ky = 110574.0;
    var mejor = double.infinity;
    for (var i = 0, j = anillo.length - 1; i < anillo.length; j = i++) {
      final ax = (anillo[j].longitude - p.longitude) * kx, ay = (anillo[j].latitude - p.latitude) * ky;
      final bx = (anillo[i].longitude - p.longitude) * kx, by = (anillo[i].latitude - p.latitude) * ky;
      final dx = bx - ax, dy = by - ay;
      final largo2 = dx * dx + dy * dy;
      var t = largo2 == 0 ? 0.0 : -(ax * dx + ay * dy) / largo2;
      t = t.clamp(0.0, 1.0);
      final cx = ax + t * dx, cy = ay + t * dy;
      final d = math.sqrt(cx * cx + cy * cy);
      if (d < mejor) mejor = d;
    }
    return mejor;
  }
}

/// Punto de prueba del handoff: Ciénaga de Mallorquín.
const puntoMallorquin = LatLng(11.04, -74.86);
