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
  });

  final String id, accionId, titulo, tipo, puntoEncuentro, descripcion;
  final DateTime inicio, fin;
  final double lat, lon;
  final int cupos, inscritos;
  final List<String> queLlevar;

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
    );
  }

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
  bool get esEjemplo => descripcion.toLowerCase().contains(_marcaEjemplo);
}

/// Lo que se muestra de un evento: una jornada real o el evento genérico.
class EventoZanky {
  const EventoZanky({required this.codigo, required this.titulo, this.jornada});
  final String codigo;
  final String titulo;
  final Jornada? jornada;
  bool get generico => jornada == null;

  static const tituloGenerico = 'Evento con Zanky';
  factory EventoZanky.generico(String codigo) => EventoZanky(codigo: codigo, titulo: tituloGenerico);
}

class FuenteJornadas {
  FuenteJornadas({this._cliente, Uri? url})
      : url = url ?? Uri.parse('https://mimanglar.sentralabs.co/datos/jornadas.json');

  final http.Client? _cliente;
  final Uri url;
  static const plazo = Duration(seconds: 6);
  static const _claveCache = 'jornadas.cache.v1';
  static const assetRespaldo = 'assets/datos/jornadas_respaldo.json';

  /// Red (6 s) → caché → asset de respaldo. No lanza.
  Future<List<Jornada>> cargar() async {
    final c = _cliente ?? http.Client();
    try {
      final r = await c.get(url).timeout(plazo);
      if (r.statusCode == 200) {
        final texto = utf8.decode(r.bodyBytes);
        final lista = _leer(texto);
        if (lista.isNotEmpty) {
          try {
            (await SharedPreferences.getInstance()).setString(_claveCache, texto);
          } catch (_) {/* sin caché no pasa nada */}
          return lista;
        }
      }
    } catch (_) {
      /* sin red, plazo o JSON raro: se sigue */
    } finally {
      if (_cliente == null) c.close();
    }
    try {
      final cache = (await SharedPreferences.getInstance()).getString(_claveCache);
      if (cache != null) {
        final lista = _leer(cache);
        if (lista.isNotEmpty) return lista;
      }
    } catch (_) {}
    try {
      return _leer(await rootBundle.loadString(assetRespaldo));
    } catch (_) {
      return const [];
    }
  }

  static List<Jornada> _leer(String texto) {
    try {
      final j = jsonDecode(texto);
      final filas = j is List ? j : (j is Map ? j['jornadas'] : null);
      if (filas is! List) return const [];
      final out = <Jornada>[];
      for (final f in filas) {
        try {
          if (f is Map) out.add(Jornada.fromJson(f));
        } catch (_) {/* una fila rota no tumba las demás */}
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<EventoZanky> evento(String codigo) async {
    try {
      for (final j in await cargar()) {
        if (j.id == codigo) return EventoZanky(codigo: codigo, titulo: j.titulo, jornada: j);
      }
    } catch (_) {}
    return EventoZanky.generico(codigo);
  }
}
