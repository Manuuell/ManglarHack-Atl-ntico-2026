import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _marcaEjemplo = 'datos de ejemplo';

/// Hora de Colombia (UTC-5, sin horario de verano) como «reloj de pared» en un DateTime UTC.
DateTime aHoraColombia(DateTime t) => t.toUtc().subtract(const Duration(hours: 5));

const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre',
  'noviembre', 'diciembre',
];

/// «domingo 29 de noviembre» (hora de Colombia).
String fechaLarga(DateTime t) {
  final c = aHoraColombia(t);
  return '${_dias[c.weekday - 1]} ${c.day} de ${_meses[c.month - 1]}';
}

/// «7:00 a. m.»
String horaCorta(DateTime t) {
  final c = aHoraColombia(t);
  final h12 = c.hour % 12 == 0 ? 12 : c.hour % 12;
  final mm = c.minute.toString().padLeft(2, '0');
  return '$h12:$mm ${c.hour < 12 ? 'a. m.' : 'p. m.'}';
}

class Jornada {
  const Jornada({
    required this.id,
    required this.accionId,
    required this.titulo,
    required this.tipo,
    required this.inicio,
    required this.fin,
    required this.puntoEncuentro,
    required this.lat,
    required this.lon,
    required this.cupos,
    required this.inscritos,
    required this.queLlevar,
    required this.descripcion,
    this.imagenUrl = '',
    this.ejemplo = false,
    this.estado = '',
  });

  final String id, accionId, titulo, tipo, puntoEncuentro, descripcion, imagenUrl, estado;
  final DateTime inicio, fin;
  final double lat, lon;
  final int cupos, inscritos;
  final List<String> queLlevar;

  /// Marca `ejemplo: true` que manda el servidor (las jornadas de demostración).
  final bool ejemplo;

  factory Jornada.fromJson(Map<dynamic, dynamic> j) {
    String s(String k) => (j[k] ?? '').toString();
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    final inicio = DateTime.parse(s('inicio'));
    return Jornada(
      id: s('id'),
      accionId: s('accion_id'),
      titulo: s('titulo'),
      tipo: s('tipo'),
      inicio: inicio,
      fin: j['fin'] == null ? inicio.add(const Duration(hours: 3)) : DateTime.parse(s('fin')),
      puntoEncuentro: s('punto_encuentro'),
      lat: d('lat'),
      lon: d('lon'),
      cupos: n('cupos'),
      inscritos: n('inscritos'),
      queLlevar: [for (final x in (j['que_llevar'] as List? ?? const [])) x.toString()],
      descripcion: s('descripcion'),
      imagenUrl: s('imagen_url').trim(),
      ejemplo: j['ejemplo'] == true,
      estado: s('estado').trim().toLowerCase(),
    );
  }

  Map<String, dynamic> aJson() => {
        'id': id,
        'accion_id': accionId,
        'titulo': titulo,
        'tipo': tipo,
        'inicio': inicio.toUtc().toIso8601String(),
        'fin': fin.toUtc().toIso8601String(),
        'punto_encuentro': puntoEncuentro,
        'lat': lat,
        'lon': lon,
        'cupos': cupos,
        'inscritos': inscritos,
        'que_llevar': queLlevar,
        'descripcion': descripcion,
        'imagen_url': imagenUrl,
        'ejemplo': ejemplo,
        'estado': estado,
      };

  String get tipoLegible => switch (tipo) {
        'siembra' => 'Siembra',
        'limpieza' => 'Limpieza',
        'monitoreo' => 'Monitoreo',
        'recorrido_vigias' => 'Recorrido de vigías',
        final t when t.isEmpty => 'Jornada',
        final t => '${t[0].toUpperCase()}${t.substring(1).replaceAll('_', ' ')}',
      };

  bool get llena => cupos > 0 && inscritos >= cupos;
  int get cuposLibres => (cupos - inscritos).clamp(0, cupos);
  bool get esEjemplo => ejemplo || descripcion.toLowerCase().contains(_marcaEjemplo);

  /// El servidor la dio de baja (`estado: cancelada`).
  bool get cancelada => estado.startsWith('cancel');

  /// Dirección de la foto, solo si es http(s) (nada de rutas raras).
  Uri? get imagen {
    final u = Uri.tryParse(imagenUrl);
    return u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.isNotEmpty ? u : null;
  }
}

/// Lo que se muestra de un evento: una jornada real o el evento genérico.
class EventoZanky {
  const EventoZanky({required this.codigo, required this.titulo, this.jornada, this.aviso = ''});
  final String codigo;
  final String titulo;
  final Jornada? jornada;

  /// Aviso general del servidor (vacío si no hay).
  final String aviso;
  bool get generico => jornada == null;

  static const tituloGenerico = 'Evento con Zanky';
  factory EventoZanky.generico(String codigo) => EventoZanky(codigo: codigo, titulo: tituloGenerico);
}

/// Jornadas y aviso, tal como los manda el servidor.
class _Lote {
  const _Lote(this.jornadas, this.aviso);
  final List<Jornada> jornadas;
  final String aviso;
  static const vacio = _Lote([], '');
}

/// De dónde salen las jornadas. Orden: caché local → `/api/jornadas/:id` (3 s) → `/api/jornadas` (3 s) →
/// `/datos/jornadas.json` (3 s) → respaldo empaquetado → evento genérico. Nunca lanza.
class FuenteJornadas {
  FuenteJornadas({this._cliente, Uri? url, Uri? api})
      : url = url ?? Uri.parse('https://mimanglar.sentralabs.co/datos/jornadas.json'),
        api = api ?? Uri.parse('https://zanqui.sentralabs.co/api/jornadas');

  final http.Client? _cliente;

  /// `/datos/jornadas.json` (puede traer solo las de ejemplo).
  final Uri url;

  /// `/api/jornadas`; la de una jornada es `<api>/<id>`.
  final Uri api;
  static const plazo = Duration(seconds: 3);
  static const _claveCache = 'jornadas.cache.v2';
  static const assetRespaldo = 'assets/datos/jornadas_respaldo.json';

  Uri _urlDe(String id) => api.replace(pathSegments: [...api.pathSegments.where((p) => p.isNotEmpty), id]);

  Future<String?> _pedir(Uri u) async {
    final c = _cliente ?? http.Client();
    try {
      final r = await c.get(u).timeout(plazo);
      if (r.statusCode == 200) return utf8.decode(r.bodyBytes);
    } catch (_) {
      /* sin red, plazo o error: se sigue con la siguiente fuente */
    } finally {
      if (_cliente == null) c.close();
    }
    return null;
  }

  Future<_Lote> _cache() async {
    try {
      final t = (await SharedPreferences.getInstance()).getString(_claveCache);
      if (t != null) return _leer(t);
    } catch (_) {}
    return _Lote.vacio;
  }

  Future<void> _guardar(_Lote l) async {
    if (l.jornadas.isEmpty) return;
    try {
      await (await SharedPreferences.getInstance()).setString(
        _claveCache,
        jsonEncode({'aviso': l.aviso, 'jornadas': [for (final j in l.jornadas) j.aJson()]}),
      );
    } catch (_) {/* sin caché no pasa nada */}
  }

  Future<_Lote> _respaldo() async {
    try {
      return _leer(await rootBundle.loadString(assetRespaldo));
    } catch (_) {
      return _Lote.vacio;
    }
  }

  /// Sin red: caché y, si no hay, el asset de respaldo. Es inmediato. No lanza.
  Future<List<Jornada>> cargarLocal() async {
    final c = await _cache();
    if (c.jornadas.isNotEmpty) return c.jornadas;
    return (await _respaldo()).jornadas;
  }

  /// Lista completa: `/api/jornadas` → `/datos/jornadas.json` → caché → respaldo. Lo que llega de la API
  /// queda en caché. No lanza.
  Future<List<Jornada>> cargar() async {
    final t = await _pedir(api);
    if (t != null) {
      final l = _leer(t);
      if (l.jornadas.isNotEmpty) {
        await _guardar(l);
        return l.jornadas;
      }
    }
    final d = await _pedir(url);
    if (d != null) {
      final l = _leer(d);
      if (l.jornadas.isNotEmpty) return l.jornadas;
    }
    return cargarLocal();
  }

  static _Lote _leer(String texto) {
    try {
      final j = jsonDecode(texto);
      final filas = j is List ? j : (j is Map ? j['jornadas'] : null);
      if (filas is! List) return _Lote.vacio;
      final out = <Jornada>[];
      for (final f in filas) {
        try {
          if (f is Map) out.add(Jornada.fromJson(f));
        } catch (_) {/* una fila rota no tumba las demás */}
      }
      return _Lote(out, j is Map ? (j['aviso'] ?? '').toString().trim() : '');
    } catch (_) {
      return _Lote.vacio;
    }
  }

  static Jornada? _una(String texto) {
    try {
      final j = jsonDecode(texto);
      if (j is! Map) return null;
      return Jornada.fromJson(j['jornada'] is Map ? j['jornada'] as Map : j);
    } catch (_) {
      return null;
    }
  }

  static EventoZanky _evento(Jornada j, String aviso) =>
      EventoZanky(codigo: j.id, titulo: j.titulo, jornada: j, aviso: aviso);

  /// El evento con lo que ya está en el teléfono (caché y luego respaldo), sin esperar la red.
  Future<EventoZanky> eventoLocal(String codigo) async {
    try {
      final c = await _cache();
      for (final j in c.jornadas) {
        if (j.id == codigo) return _evento(j, c.aviso);
      }
      final r = await _respaldo();
      for (final j in r.jornadas) {
        if (j.id == codigo) return _evento(j, c.aviso);
      }
      return EventoZanky(codigo: codigo, titulo: EventoZanky.tituloGenerico, aviso: c.aviso);
    } catch (_) {
      return EventoZanky.generico(codigo);
    }
  }

  /// El evento con la mejor fuente disponible (ver el orden arriba).
  Future<EventoZanky> evento(String codigo) async {
    try {
      final c0 = await _cache();
      var aviso = c0.aviso;
      // Las dos peticiones salen a la vez: la jornada sola (rápida) y la lista (trae el aviso y refresca la caché).
      final unoF = _pedir(_urlDe(codigo));
      final listaF = _pedir(api);
      final uno = await unoF;
      final j1 = uno == null ? null : _una(uno);
      final lista = await listaF;
      final l = lista == null ? _Lote.vacio : _leer(lista);
      if (l.jornadas.isNotEmpty) aviso = l.aviso;
      if (j1 != null && j1.id == codigo) {
        // Se suma a la caché: reemplaza la misma jornada y conserva las otras.
        final base = l.jornadas.isNotEmpty ? l.jornadas : c0.jornadas;
        await _guardar(_Lote([j1, for (final x in base) if (x.id != codigo) x], aviso));
        return _evento(j1, aviso);
      }
      if (l.jornadas.isNotEmpty) {
        await _guardar(l);
        for (final j in l.jornadas) {
          if (j.id == codigo) return _evento(j, aviso);
        }
      }
      final d = await _pedir(url);
      if (d != null) {
        for (final j in _leer(d).jornadas) {
          if (j.id == codigo) return _evento(j, aviso);
        }
      }
      for (final j in [...c0.jornadas, ...(await _respaldo()).jornadas]) {
        if (j.id == codigo) return _evento(j, aviso);
      }
      return EventoZanky(codigo: codigo, titulo: EventoZanky.tituloGenerico, aviso: aviso);
    } catch (_) {
      return EventoZanky.generico(codigo);
    }
  }
}
