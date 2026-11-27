import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../datos/zonas.dart';
import '../../nucleo/tema.dart';

/// Qué capa de la CRA muestra el mapa.
enum CapaMapa {
  manglar('Manglar'),
  prioridad('Prioridad CRA');

  const CapaMapa(this.nombre);
  final String nombre;
}

/// Nota honesta de la fuente, la misma en la hoja y en la leyenda.
const notaFuentePrioridad = 'Capa oficial de la CRA, escala 1:5.000. Recortada a la costa del '
    'manglar y simplificada para que el teléfono la dibuje sin señal.';

/// Color de relleno y de borde de cada prioridad. Salen de la escala de `Zc.prioridad` (alta =
/// el rojo del 5, media = el naranja del 4, baja = el ámbar del 3): lo que ya significa «urgente»
/// en el resto de la app. El nivel no depende solo del color: el borde engorda con la prioridad
/// y la leyenda y la hoja lo dicen con palabras.
Color colorPrioridadCra(PrioridadCRA p) => Zc.dePrioridad(p.puntos);

Color _bordePrioridad(PrioridadCRA p) => Color.lerp(colorPrioridadCra(p), Zc.raiz, 0.35)!;

double _relleno(PrioridadCRA p) => switch (p) {
      PrioridadCRA.alta => 0.46,
      PrioridadCRA.media => 0.38,
      PrioridadCRA.baja => 0.34,
    };

double _grosorBorde(PrioridadCRA p) => switch (p) {
      PrioridadCRA.alta => 1.6,
      PrioridadCRA.media => 1.2,
      PrioridadCRA.baja => 0.9,
    };

/// Un polígono de la capa: su plan (prioridad, acción, escenario…), su caja y sus anillos.
class PoligonoPrioridad {
  PoligonoPrioridad._(this.plan, this.caja, this.anillos, this.hectareas);

  final PlanCRA plan;

  /// [minLon, minLat, maxLon, maxLat].
  final Float64List caja;

  /// Anillos [lon, lat, lon, lat…]; el primero es el exterior y los demás son huecos.
  final List<Float64List> anillos;

  /// Superficie calculada por Zanky sobre el polígono original (exterior menos huecos).
  final double hectareas;

  PrioridadCRA get prioridad => plan.prioridad;

  bool contiene(double x, double y) {
    if (x < caja[0] || x > caja[2] || y < caja[1] || y > caja[3]) return false;
    if (!_dentro(x, y, anillos.first)) return false;
    for (var h = 1; h < anillos.length; h++) {
      if (_dentro(x, y, anillos[h])) return false;
    }
    return true;
  }
}

/// Los datos ya decodificados y simplificados, sin nada de Flutter: lo único que viaja de vuelta
/// del hilo aparte.
class DatosPrioridad {
  DatosPrioridad._(this.fuente, this.planes, this.indices, this.cajas, this.anillos, this.hectareas,
      this.verticesOriginales, this.verticesFinales);

  final String fuente;
  final List<PlanCRA> planes;
  final List<int> indices;
  final List<Float64List> cajas;
  final List<List<Float64List>> anillos;
  final List<double> hectareas;
  final int verticesOriginales;
  final int verticesFinales;
}

/// Tolerancia de la simplificación al cargar, en grados (≈ 3 m). Los datos ya vienen a 2,5 m:
/// esto solo quita lo que ningún zoom del mapa deja ver; flutter_map simplifica el resto por zoom.
const toleranciaGrados = 2.7e-5;

/// Decodifica `prioridades_cra.json`. Función de nivel superior para `compute`.
DatosPrioridad decodificarPrioridades(String texto) {
  final c = _ConstructorDatos(jsonDecode(texto) as Map<String, dynamic>);
  for (var i = 0; i < c.total; i++) {
    c.agregar(i);
  }
  return c.terminar();
}

/// Igual que [decodificarPrioridades] pero cediendo el hilo cada [tramoMs] ms: en la web no hay
/// isolates y `compute` correría entero en el hilo de la interfaz (decodificar + simplificar
/// 9.000 polígonos de golpe congela el mapa).
Future<DatosPrioridad> decodificarPrioridadesPorTramos(String texto, {int tramoMs = 6}) async {
  final c = _ConstructorDatos(jsonDecode(texto) as Map<String, dynamic>);
  final reloj = Stopwatch()..start();
  for (var i = 0; i < c.total; i++) {
    c.agregar(i);
    if (reloj.elapsedMilliseconds >= tramoMs) {
      await Future<void>.delayed(Duration.zero);
      reloj
        ..reset()
        ..start();
    }
  }
  return c.terminar();
}

/// Arma [DatosPrioridad] polígono a polígono, para poder hacerlo de golpe o por tramos.
class _ConstructorDatos {
  _ConstructorDatos(this._j)
      : _unidad = (_j['unidad'] as num).toDouble(),
        _polis = _j['poligonos'] as List {
    String? vacioANulo(Object? t) => (t is String && t.isNotEmpty) ? t : null;
    _planes = [
      for (final a in _j['atributos'] as List)
        PlanCRA(
          prioridad: PrioridadCRA.desdeTexto(a['p'] as String) ?? PrioridadCRA.baja,
          accion: a['a'] as String,
          escenario: a['e'] as String,
          figura: a['f'] as String? ?? '',
          areaProtegida: vacioANulo(a['z']),
          unidad: vacioANulo(a['u']),
        ),
    ];
  }

  final Map<String, dynamic> _j;
  final double _unidad;
  final List _polis;
  late final List<PlanCRA> _planes;
  final _indices = <int>[];
  final _cajas = <Float64List>[];
  final _anillos = <List<Float64List>>[];
  final _has = <double>[];
  var _antes = 0, _despues = 0;

  int get total => _polis.length;

  void agregar(int n) {
    final p = _polis[n];
    final crudos = [for (final r in p[1] as List) _decodificar(r as List, _unidad)];
    if (crudos.isEmpty || crudos.first.length < 6) return;
    final ha = _hectareas(crudos);
    final simples = <Float64List>[];
    for (var i = 0; i < crudos.length; i++) {
      _antes += crudos[i].length ~/ 2;
      final s = _simplificarAnillo(crudos[i], toleranciaGrados);
      // Un hueco que se queda sin forma se descarta; el exterior conserva su forma original.
      if (s.length >= 6) {
        simples.add(s);
      } else if (i == 0) {
        simples.add(crudos[i]);
      }
    }
    for (final s in simples) {
      _despues += s.length ~/ 2;
    }
    final e = simples.first;
    var a = 1e9, b = 1e9, c = -1e9, d = -1e9;
    for (var k = 0; k < e.length; k += 2) {
      a = math.min(a, e[k]);
      c = math.max(c, e[k]);
      b = math.min(b, e[k + 1]);
      d = math.max(d, e[k + 1]);
    }
    _indices.add((p[0] as num).toInt());
    _cajas.add(Float64List.fromList([a, b, c, d]));
    _anillos.add(simples);
    _has.add(ha);
  }

  DatosPrioridad terminar() => DatosPrioridad._(
      _j['fuente'] as String? ?? '', _planes, _indices, _cajas, _anillos, _has, _antes, _despues);
}

/// Capa de prioridades lista para el mapa: los `Polygon` se crean UNA vez (aquí) y el mismo
/// widget se reusa en cada reconstrucción; así mover el mapa no vuelve a tocar los datos.
class CapaPrioridadMapa {
  CapaPrioridadMapa._(this.datos, this.poligonos, this.capa, this.tiempoConstruccion);

  /// Qué carga la capa. Las pruebas lo cambian para no abrir un hilo aparte.
  static Future<CapaPrioridadMapa> Function() cargador = cargar;

  final DatosPrioridad datos;

  /// Ordenados para dibujar: primero las bajas y al final las altas (las altas quedan encima).
  final List<PoligonoPrioridad> poligonos;

  /// La capa lista para poner dentro del FlutterMap.
  final Widget capa;

  /// Lo que costó construirla (decodificar y simplificar no cuenta si ocurrió en otro hilo).
  final Duration tiempoConstruccion;

  int get verticesFinales => datos.verticesFinales;

  /// Lee el archivo de los assets (sin red) y lo decodifica fuera del hilo de la interfaz.
  static Future<CapaPrioridadMapa> cargar() async {
    final texto = await rootBundle.loadString('assets/datos/prioridades_cra.json', cache: false);
    // Un cuadro para que se pinte «Cargando…» antes del trabajo pesado (en la web no hay hilos).
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (kIsWeb) {
      // Sin isolates: por tramos, cediendo el hilo, para que el mapa siga respondiendo.
      final datos = await decodificarPrioridadesPorTramos(texto);
      return desdeDatosPorTramos(datos);
    }
    final datos = await compute(decodificarPrioridades, texto);
    return desdeDatos(datos);
  }

  /// Versión sin hilos, para las pruebas.
  static CapaPrioridadMapa desdeTexto(String texto) => desdeDatos(decodificarPrioridades(texto));

  static CapaPrioridadMapa desdeDatos(DatosPrioridad d) {
    final reloj = Stopwatch()..start();
    final polis = _poligonosDe(d);
    final ordenados = _ordenar(polis);
    final poligonos = <Polygon>[for (final p in ordenados) _poligonoMapa(p)];
    return _armar(d, ordenados, poligonos, reloj);
  }

  /// Igual que [desdeDatos] pero cediendo el hilo cada [tramoMs] ms (para la web).
  static Future<CapaPrioridadMapa> desdeDatosPorTramos(DatosPrioridad d, {int tramoMs = 6}) async {
    final reloj = Stopwatch()..start();
    final polis = _poligonosDe(d);
    final ordenados = _ordenar(polis);
    final poligonos = <Polygon>[];
    final tramo = Stopwatch()..start();
    for (final p in ordenados) {
      poligonos.add(_poligonoMapa(p));
      if (tramo.elapsedMilliseconds >= tramoMs) {
        await Future<void>.delayed(Duration.zero);
        tramo
          ..reset()
          ..start();
      }
    }
    return _armar(d, ordenados, poligonos, reloj);
  }

  static List<PoligonoPrioridad> _poligonosDe(DatosPrioridad d) => [
        for (var i = 0; i < d.indices.length; i++)
          PoligonoPrioridad._(d.planes[d.indices[i]], d.cajas[i], d.anillos[i], d.hectareas[i]),
      ];

  /// Estable: dentro de un mismo nivel se conserva el orden del archivo.
  static List<PoligonoPrioridad> _ordenar(List<PoligonoPrioridad> polis) {
    final orden = [for (var i = 0; i < polis.length; i++) i]..sort((a, b) {
        final c = polis[b].prioridad.index.compareTo(polis[a].prioridad.index);
        return c != 0 ? c : a.compareTo(b);
      });
    return [for (final i in orden) polis[i]];
  }

  static Polygon _poligonoMapa(PoligonoPrioridad p) => Polygon(
        points: _aLatLng(p.anillos.first),
        holePointsList: p.anillos.length > 1 ? [for (var h = 1; h < p.anillos.length; h++) _aLatLng(p.anillos[h])] : null,
        color: colorPrioridadCra(p.prioridad).withValues(alpha: _relleno(p.prioridad)),
        borderColor: _bordePrioridad(p.prioridad),
        borderStrokeWidth: _grosorBorde(p.prioridad),
      );

  static CapaPrioridadMapa _armar(
      DatosPrioridad d, List<PoligonoPrioridad> ordenados, List<Polygon> poligonos, Stopwatch reloj) {
    final capa = PolygonLayer(
      polygons: poligonos,
      polygonCulling: true,
      // Un píxel y medio: más gruesa que el valor por defecto, imperceptible y mucho más liviana.
      simplificationTolerance: 1.5,
    );
    reloj.stop();
    return CapaPrioridadMapa._(d, ordenados, capa, reloj.elapsed);
  }


  /// El polígono de mayor prioridad que contiene [p] (si hay varios, el más pequeño); null si
  /// ninguno. Primero descarta por caja; solo los que pasan se prueban con punto-en-polígono.
  PoligonoPrioridad? en(LatLng p) {
    final x = p.longitude, y = p.latitude;
    PoligonoPrioridad? mejor;
    for (final q in poligonos) {
      final c = q.caja;
      if (x < c[0] || x > c[2] || y < c[1] || y > c[3]) continue;
      if (mejor != null) {
        final d = q.prioridad.index - mejor.prioridad.index;
        if (d > 0) continue;
        if (d == 0 && q.hectareas >= mejor.hectareas) continue;
      }
      if (q.contiene(x, y)) mejor = q;
    }
    return mejor;
  }

  /// Cuántos polígonos hay de cada prioridad.
  Map<PrioridadCRA, int> get conteo => {
        for (final n in PrioridadCRA.values) n: poligonos.where((p) => p.prioridad == n).length,
      };
}

List<LatLng> _aLatLng(Float64List r) => [for (var i = 0; i < r.length; i += 2) LatLng(r[i + 1], r[i])];

/// Anillo codificado [x0, y0, dx1, dy1, …] en unidades de 1/[unidad] grados → [lon, lat, …].
Float64List _decodificar(List r, double unidad) {
  final n = r.length ~/ 2;
  final o = Float64List(n * 2);
  var x = 0, y = 0;
  for (var i = 0; i < n; i++) {
    x += (r[i * 2] as num).toInt();
    y += (r[i * 2 + 1] as num).toInt();
    o[i * 2] = x / unidad;
    o[i * 2 + 1] = y / unidad;
  }
  return o;
}

bool _dentro(double x, double y, Float64List r) {
  var dentro = false;
  final n = r.length ~/ 2;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final xi = r[i * 2], yi = r[i * 2 + 1], xj = r[j * 2], yj = r[j * 2 + 1];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) dentro = !dentro;
  }
  return dentro;
}

/// Hectáreas del exterior menos las de los huecos, con proyección plana local (sobra para
/// polígonos de la costa).
double _hectareas(List<Float64List> anillos) {
  double area(Float64List r) {
    final n = r.length ~/ 2;
    final lat0 = r[1] * math.pi / 180;
    final kx = 111320.0 * math.cos(lat0), ky = 110574.0;
    var s = 0.0;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      s += (r[j * 2] * kx) * (r[i * 2 + 1] * ky) - (r[i * 2] * kx) * (r[j * 2 + 1] * ky);
    }
    return s.abs() / 2;
  }

  var m2 = area(anillos.first);
  for (var h = 1; h < anillos.length; h++) {
    m2 -= area(anillos[h]);
  }
  return math.max(m2, 0) / 10000;
}

/// Douglas-Peucker sobre un anillo abierto (sin repetir el primer punto): parte el anillo por
/// el vértice más lejano del primero y simplifica cada mitad.
Float64List _simplificarAnillo(Float64List r, double tol) {
  final n = r.length ~/ 2;
  if (n <= 4) return r;
  var lejos = 0;
  var mayor = -1.0;
  for (var i = 1; i < n; i++) {
    final dx = r[i * 2] - r[0], dy = r[i * 2 + 1] - r[1];
    final d = dx * dx + dy * dy;
    if (d > mayor) {
      mayor = d;
      lejos = i;
    }
  }
  final guardar = List<bool>.filled(n, false);
  guardar[0] = true;
  guardar[lejos] = true;
  _dp(r, 0, lejos, tol, guardar, n);
  _dp(r, lejos, n, tol, guardar, n); // la segunda mitad cierra en el vértice 0
  var cuantos = 0;
  for (final g in guardar) {
    if (g) cuantos++;
  }
  final o = Float64List(cuantos * 2);
  var k = 0;
  for (var i = 0; i < n; i++) {
    if (guardar[i]) {
      o[k++] = r[i * 2];
      o[k++] = r[i * 2 + 1];
    }
  }
  return o;
}

void _dp(Float64List r, int a, int b, double tol, List<bool> guardar, int n) {
  // Pila explícita: sin recursión profunda en anillos largos.
  final pila = <int>[a, b];
  final t2 = tol * tol;
  while (pila.isNotEmpty) {
    final fin = pila.removeLast();
    final ini = pila.removeLast();
    if (fin - ini < 2) continue;
    final ax = r[ini * 2], ay = r[ini * 2 + 1];
    final fi = fin % n;
    final bx = r[fi * 2], by = r[fi * 2 + 1];
    final dx = bx - ax, dy = by - ay;
    final largo2 = dx * dx + dy * dy;
    var mayor = -1.0;
    var idx = -1;
    for (var i = ini + 1; i < fin; i++) {
      final px = r[i * 2] - ax, py = r[i * 2 + 1] - ay;
      double d2;
      if (largo2 == 0) {
        d2 = px * px + py * py;
      } else {
        final t = ((px * dx + py * dy) / largo2).clamp(0.0, 1.0);
        final ex = px - t * dx, ey = py - t * dy;
        d2 = ex * ex + ey * ey;
      }
      if (d2 > mayor) {
        mayor = d2;
        idx = i;
      }
    }
    if (mayor > t2 && idx > 0) {
      guardar[idx] = true;
      pila..add(ini)..add(idx)..add(idx)..add(fin);
    }
  }
}
