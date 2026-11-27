import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// Prioridad de conservación del plan de la CRA (campo `Val_Priori` de su capa
/// «Prioridades de conservación»). El orden importa: de la más alta a la más baja.
enum PrioridadCRA {
  alta('Alta', 5),
  media('Media', 4),
  baja('Baja', 3);

  const PrioridadCRA(this.nombre, this.puntos);

  /// Texto para mostrar: «Alta», «Media», «Baja».
  final String nombre;

  /// Equivalente en la escala 1-5 que usaban las pantallas antes de tener la capa oficial:
  /// alta → 5, media → 4, baja → 3 (fuera de la zonificación también vale 3).
  final int puntos;

  static PrioridadCRA? desdeTexto(String? t) {
    for (final p in values) {
      if (p.name == t) return p;
    }
    return null;
  }
}

/// Plan de manejo de la CRA en un punto: lo que dice el polígono de prioridades que lo contiene.
class PlanCRA {
  const PlanCRA({
    required this.prioridad,
    required this.accion,
    required this.escenario,
    this.figura = '',
    this.areaProtegida,
    this.unidad,
  });

  final PrioridadCRA prioridad;

  /// «Preservación», «Restauración», «Recuperación» o «Rehabilitación».
  final String accion;

  /// «Escenario I», «Escenario III»…
  final String escenario;

  /// Figura legal («Áreas protegidas», «Conectividad», «Sin ninguna figura legal»…).
  final String figura;

  /// Nombre del área protegida si el polígono está en una (p. ej. «Palmar Titi»); si no, null.
  final String? areaProtegida;

  /// Unidad hidrográfica (p. ej. «Cienaga del Totumo»).
  final String? unidad;

  /// «Alta (preservación)»: la prioridad con su acción, como se muestra en los motivos.
  String get resumen => '${prioridad.nombre} (${accion.toLowerCase()})';
}

/// Una de las cuatro zonas de manglar que nombró la CRA. El `id` es el contrato común con el
/// bot y el backend (mallorquin, tubara, juan_de_acosta, piojo): no se cambia.
class ZonaManglar {
  ZonaManglar({
    required this.id,
    required this.nombre,
    required this.municipio,
    required this.prioridadConservacion,
    required this.nota,
    required this.areaHa,
    required this.poligonos,
    this.sectorCra = '',
    this.prioridadCra,
    List<List<List<LatLng>>>? huecos,
  })  : huecos = huecos ?? [for (final _ in poligonos) const []],
        cajas = poligonos.map(Caja.de).toList();

  final String id;
  final String nombre;
  final String municipio;

  /// Nombre oficial del sector en la capa de la CRA y en la web: «Mallorquín», «Balboa»,
  /// «Manatíes» o «Totumo». Vacío si el archivo no lo trae.
  final String sectorCra;

  /// Prioridad dominante de la zona (la que cubre más hectáreas de su manglar en la capa de
  /// prioridades de la CRA), o null si no se pudo calcular.
  final PrioridadCRA? prioridadCra;

  /// DERIVADO de [prioridadCra] (alta → 5, media → 4, baja → 3; sin dato → 3). Se conserva para
  /// las pantallas que aún muestran «N de 5»; la fuente de verdad es [prioridadCra].
  final int prioridadConservacion;
  final String nota;

  /// Hectáreas reales de la capa 1:5.000 de la CRA.
  final double areaHa;

  /// Anillos exteriores en [lat, lon].
  final List<List<LatLng>> poligonos;

  /// Huecos de cada polígono (mismo orden que [poligonos]); casi siempre vacíos.
  final List<List<List<LatLng>>> huecos;
  final List<Caja> cajas;

  /// «Sector Balboa (Tubará)»: el nombre de la CRA con el municipio.
  String get etiquetaSector => sectorCra.isEmpty ? nombre : 'Sector $sectorCra ($municipio)';

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

/// Resultado de ubicar un punto contra el manglar y contra las prioridades de la CRA.
class Ubicacion {
  const Ubicacion({
    required this.zona,
    required this.dentro,
    required this.distanciaM,
    this.plan,
    this.fueraZonificacion = false,
  });

  /// Zona más cercana (siempre hay una: el reporte se asigna a la más próxima).
  final ZonaManglar zona;

  /// Dentro de algún polígono del manglar 1:5.000 de la CRA.
  final bool dentro;

  /// 0 si está dentro.
  final double distanciaM;

  /// Plan de la CRA en el punto (el polígono de mayor prioridad que lo contiene), o null.
  final PlanCRA? plan;

  /// true si la capa de prioridades estaba cargada y ningún polígono contiene el punto.
  /// Si la capa no está cargada, [plan] es null y esto es false (no se sabe).
  final bool fueraZonificacion;

  /// Prioridad de conservación de la CRA en el punto; null si está fuera de la zonificación.
  PrioridadCRA? get prioridadCra => plan?.prioridad;

  /// DERIVADO de [prioridadCra] en la escala 1-5: alta → 5, media → 4, baja → 3,
  /// fuera de la zonificación → 3. Sin capa cargada cae a la de la zona. Lo usa
  /// prioridad.dart hasta que lea [prioridadCra] directamente.
  int get prioridadConservacion =>
      plan?.prioridad.puntos ?? (fueraZonificacion ? 3 : zona.prioridadConservacion);

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

/// Capa «Prioridades de conservación» de la CRA: polígonos con prioridad, acción y escenario.
class CapaPrioridadesCra {
  CapaPrioridadesCra._(this.fuente, this.generado, this._planes, this._idx, this._cajas, this._anillos);

  final String fuente;
  final String generado;
  final List<PlanCRA> _planes;

  /// Por polígono: índice en [_planes], su caja [minLon, minLat, maxLon, maxLat] (4 por polígono)
  /// y sus anillos (el primero es el exterior) como Float64List [lon, lat, lon, lat…].
  final Int32List _idx;
  final Float64List _cajas;
  final List<List<Float64List>> _anillos;

  int get poligonos => _idx.length;

  static CapaPrioridadesCra desdeJson(Map<String, dynamic> j) {
    final c = _ConstructorCapa(j);
    for (var i = 0; i < c.total; i++) {
      c.agregar(i);
    }
    return c.terminar();
  }

  /// Igual que [desdeJson] pero cediendo el hilo cada [tramoMs] ms. En la web no hay isolates y
  /// `compute` corre en el hilo de la interfaz: decodificar 9.000 polígonos de golpe congela la
  /// pantalla; por tramos, cada pausa deja pintar un cuadro y atender toques.
  static Future<CapaPrioridadesCra> desdeJsonPorTramos(Map<String, dynamic> j, {int tramoMs = _tramoMs}) async {
    final c = _ConstructorCapa(j);
    final reloj = Stopwatch()..start();
    for (var i = 0; i < c.total; i++) {
      c.agregar(i);
      if (reloj.elapsedMilliseconds >= tramoMs) {
        await _cederHilo();
        reloj
          ..reset()
          ..start();
      }
    }
    return c.terminar();
  }

  /// Plan de la CRA en [p]; si lo contienen varios polígonos, el de prioridad más alta.
  /// null = fuera de la zonificación.
  PlanCRA? en(LatLng p) {
    final x = p.longitude, y = p.latitude;
    PlanCRA? mejor;
    for (var i = 0; i < _idx.length; i++) {
      final c = i * 4;
      if (x < _cajas[c] || x > _cajas[c + 2] || y < _cajas[c + 1] || y > _cajas[c + 3]) continue;
      final plan = _planes[_idx[i]];
      // El enum va de la más alta (índice 0) a la más baja: solo interesa una más alta.
      if (mejor != null && plan.prioridad.index >= mejor.prioridad.index) continue;
      final rings = _anillos[i];
      if (!_dentroPlano(x, y, rings.first)) continue;
      var enHueco = false;
      for (var h = 1; h < rings.length && !enHueco; h++) {
        enHueco = _dentroPlano(x, y, rings[h]);
      }
      if (!enHueco) mejor = plan;
    }
    return mejor;
  }

  static bool _dentroPlano(double x, double y, Float64List r) {
    var dentro = false;
    final n = r.length ~/ 2;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final xi = r[i * 2], yi = r[i * 2 + 1], xj = r[j * 2], yj = r[j * 2 + 1];
      if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) dentro = !dentro;
    }
    return dentro;
  }
}

/// Anillo codificado [x0, y0, dx1, dy1, …] en unidades de 1/[unidad] grados → [lon, lat, …].
Float64List _decodificarPlano(List r, double unidad) {
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

List<LatLng> _decodificarAnillo(List r, double unidad) {
  final f = _decodificarPlano(r, unidad);
  return [for (var i = 0; i < f.length; i += 2) LatLng(f[i + 1], f[i])];
}

/// Cuánto trabaja cada tramo antes de ceder el hilo (menos de un cuadro a 60 Hz).
const _tramoMs = 6;

/// Cede el hilo a la interfaz: en la web deja que el navegador pinte y atienda toques.
Future<void> _cederHilo() => Future<void>.delayed(Duration.zero);

/// Arma [CapaPrioridadesCra] polígono a polígono, para poder hacerlo de golpe o por tramos.
class _ConstructorCapa {
  _ConstructorCapa(this._j)
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
    _idx = Int32List(_polis.length);
    _cajas = Float64List(_polis.length * 4);
  }

  final Map<String, dynamic> _j;
  final double _unidad;
  final List _polis;
  late final List<PlanCRA> _planes;
  late final Int32List _idx;
  late final Float64List _cajas;
  final List<List<Float64List>> _anillos = [];

  int get total => _polis.length;

  /// Decodifica el polígono [i] (hay que llamarlo en orden: 0, 1, 2…).
  void agregar(int i) {
    final p = _polis[i] as List;
    _idx[i] = (p[0] as num).toInt();
    final rings = [for (final r in p[1] as List) _decodificarPlano(r as List, _unidad)];
    _anillos.add(rings);
    final e = rings.first;
    var a = 1e9, b = 1e9, c = -1e9, d = -1e9;
    for (var k = 0; k < e.length; k += 2) {
      a = math.min(a, e[k]);
      c = math.max(c, e[k]);
      b = math.min(b, e[k + 1]);
      d = math.max(d, e[k + 1]);
    }
    _cajas[i * 4] = a;
    _cajas[i * 4 + 1] = b;
    _cajas[i * 4 + 2] = c;
    _cajas[i * 4 + 3] = d;
  }

  CapaPrioridadesCra terminar() => CapaPrioridadesCra._(
        _j['fuente'] as String? ?? '',
        _j['generado'] as String? ?? '',
        _planes,
        _idx,
        _cajas,
        _anillos,
      );
}

/// Para `compute`: decodifica el manglar fuera del hilo de la interfaz (solo donde hay isolates).
Manglar _decodificarManglar(String texto) => Manglar.desdeJson(jsonDecode(texto) as Map<String, dynamic>);

/// Para `compute`: decodifica la capa de prioridades.
CapaPrioridadesCra _decodificarCapaCra(String texto) =>
    CapaPrioridadesCra.desdeJson(jsonDecode(texto) as Map<String, dynamic>);

/// Las zonas de manglar del Atlántico y las prioridades de la CRA, cargadas de los archivos que
/// van dentro de la app: ubicar un reporte funciona sin internet.
class Manglar {
  Manglar._(this.zonas, this.fuente, this.provisional, this.areaTotalHa, this._prioridades,
      {this.fechaDatos = ''});

  final List<ZonaManglar> zonas;
  final String fuente;

  /// Rango de fechas de las imágenes de la capa de manglar.
  final String fechaDatos;
  final bool provisional;
  final double areaTotalHa;

  CapaPrioridadesCra? _prioridades;
  Future<void>? _cargaPrioridades;

  /// Capa de prioridades de la CRA. null mientras no llegó (o en pruebas que solo usan el
  /// manglar): [ubicar] funciona igual, solo que sin plan; el servidor recalcula la prioridad.
  CapaPrioridadesCra? get prioridades => _prioridades;

  /// ¿Ya llegó la capa de prioridades?
  bool get prioridadesListas => _prioridades != null;

  /// Lee `manglar_zonas.json` (manglar 1:5.000 de la CRA, 357 KB): lo único que necesita la
  /// primera pantalla. Las prioridades (1,5 MB) NO se esperan: [cargarPrioridades] las trae
  /// después del primer cuadro.
  static Future<Manglar> cargar() async {
    final texto = await rootBundle.loadString('assets/datos/manglar_zonas.json', cache: false);
    if (kIsWeb) {
      // Sin isolates: decodificar por tramos para no congelar la pantalla.
      return desdeJsonPorTramos(jsonDecode(texto) as Map<String, dynamic>);
    }
    return compute(_decodificarManglar, texto);
  }

  /// Lee `prioridades_cra.json` y la deja en [prioridades]. Idempotente (llamarla otra vez
  /// espera la misma carga) y no lanza: sin la capa la app sigue con la regla de siempre.
  Future<void> cargarPrioridades() => _cargaPrioridades ??= _traerPrioridades();

  Future<void> _traerPrioridades() async {
    try {
      final texto = await rootBundle.loadString('assets/datos/prioridades_cra.json', cache: false);
      if (kIsWeb) {
        _prioridades = await CapaPrioridadesCra.desdeJsonPorTramos(jsonDecode(texto) as Map<String, dynamic>);
      } else {
        _prioridades = await compute(_decodificarCapaCra, texto);
      }
    } catch (e) {
      debugPrint('Prioridades CRA no cargadas: $e');
    }
  }

  /// Igual que [desdeJson] pero cediendo el hilo entre polígonos (para la web).
  static Future<Manglar> desdeJsonPorTramos(Map<String, dynamic> j, {int tramoMs = _tramoMs}) async {
    final unidad = (j['unidad'] as num).toDouble();
    final reloj = Stopwatch()..start();
    final zonas = <ZonaManglar>[];
    for (final z in j['zonas'] as List) {
      final m = z as Map<String, dynamic>;
      final anillos = <List<LatLng>>[];
      final huecos = <List<List<LatLng>>>[];
      for (final p in m['poligonos'] as List) {
        final polis = p as List;
        anillos.add(_decodificarAnillo(polis.first as List, unidad));
        huecos.add([for (final h in polis.skip(1)) _decodificarAnillo(h as List, unidad)]);
        if (reloj.elapsedMilliseconds >= tramoMs) {
          await _cederHilo();
          reloj
            ..reset()
            ..start();
        }
      }
      zonas.add(_zona(m, anillos, huecos));
    }
    return Manglar._(
      zonas,
      j['fuente'] as String,
      j['provisional'] as bool? ?? false,
      (j['areaTotalHa'] as num).toDouble(),
      null,
      fechaDatos: j['fechaDatos'] as String? ?? '',
    );
  }

  static ZonaManglar _zona(Map<String, dynamic> z, List<List<LatLng>> anillos, List<List<List<LatLng>>> huecos) {
    final prCra = PrioridadCRA.desdeTexto(z['prioridadCra'] as String?);
    return ZonaManglar(
      id: z['id'] as String,
      nombre: z['nombre'] as String,
      municipio: z['municipio'] as String,
      sectorCra: z['sectorCra'] as String? ?? '',
      prioridadCra: prCra,
      prioridadConservacion: (z['prioridadConservacion'] as num?)?.toInt() ?? prCra?.puntos ?? 3,
      nota: z['nota'] as String,
      areaHa: (z['areaHa'] as num).toDouble(),
      poligonos: anillos,
      huecos: huecos,
    );
  }

  static Manglar desdeJson(Map<String, dynamic> j, [Map<String, dynamic>? prioridades]) {
    final unidad = (j['unidad'] as num).toDouble();
    ZonaManglar zona(Map<String, dynamic> z) {
      final polis = [for (final p in z['poligonos'] as List) p as List];
      return _zona(
        z,
        [for (final p in polis) _decodificarAnillo(p.first as List, unidad)],
        [
          for (final p in polis) [for (final h in p.skip(1)) _decodificarAnillo(h as List, unidad)],
        ],
      );
    }

    return Manglar._(
      [for (final z in j['zonas'] as List) zona(z as Map<String, dynamic>)],
      j['fuente'] as String,
      j['provisional'] as bool? ?? false,
      (j['areaTotalHa'] as num).toDouble(),
      prioridades == null ? null : CapaPrioridadesCra.desdeJson(prioridades),
      fechaDatos: j['fechaDatos'] as String? ?? '',
    );
  }

  ZonaManglar? zonaPorId(String? id) {
    for (final z in zonas) {
      if (z.id == id) return z;
    }
    return null;
  }

  /// Ubica un punto: ¿está dentro de algún polígono?, ¿a qué distancia del borde más
  /// cercano?, ¿de qué zona?, ¿qué prioridad de conservación le da la CRA? Primero filtra por
  /// caja para no recorrer todos los vértices.
  Ubicacion ubicar(LatLng p) {
    final capa = prioridades;
    final plan = capa?.en(p);
    final fuera = capa != null && plan == null;
    // 1) ¿Dentro de algún polígono (y no en un hueco)?
    for (final z in zonas) {
      for (var i = 0; i < z.poligonos.length; i++) {
        if (z.cajas[i].contiene(p) &&
            _dentro(p, z.poligonos[i]) &&
            !z.huecos[i].any((h) => _dentro(p, h))) {
          return Ubicacion(zona: z, dentro: true, distanciaM: 0, plan: plan, fueraZonificacion: fuera);
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
    return Ubicacion(
      zona: mejorZona ?? zonas.first,
      dentro: false,
      distanciaM: mejor,
      plan: plan,
      fueraZonificacion: fuera,
    );
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
