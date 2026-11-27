import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'jornada.dart';

class Asistencia {
  const Asistencia({required this.codigo, required this.titulo, required this.nombre, this.grupo, required this.en});
  final String codigo, titulo, nombre;
  final String? grupo;
  final DateTime en;

  Map<String, dynamic> toJson() =>
      {'codigo': codigo, 'titulo': titulo, 'nombre': nombre, 'grupo': grupo, 'en': en.toIso8601String()};
  factory Asistencia.fromJson(Map<dynamic, dynamic> j) => Asistencia(
        codigo: j['codigo'] as String,
        titulo: j['titulo'] as String? ?? EventoZanky.tituloGenerico,
        nombre: j['nombre'] as String? ?? '',
        grupo: j['grupo'] as String?,
        en: DateTime.parse(j['en'] as String),
      );
}

/// Puntos de participación en eventos (aparte de los de reportes). Todo se guarda solo en el teléfono.
class AlmacenParticipacion extends ChangeNotifier {
  AlmacenParticipacion();
  static final AlmacenParticipacion instancia = AlmacenParticipacion();

  static const puntosAsistencia = 40;
  static const puntosPorAcierto = 10;
  static const _clave = 'participacion.v1';

  final Map<String, Asistencia> _asistencias = {};
  final Map<String, int> _retos = {};
  Future<void>? _carga;

  /// Idempotente.
  Future<void> cargar() => _carga ??= _leer();

  Future<void> _leer() async {
    try {
      final txt = (await SharedPreferences.getInstance()).getString(_clave);
      if (txt == null) return;
      final j = jsonDecode(txt) as Map<String, dynamic>;
      for (final a in (j['asistencias'] as List? ?? const [])) {
        final x = Asistencia.fromJson(a as Map);
        _asistencias[x.codigo] = x;
      }
      (j['retos'] as Map? ?? const {}).forEach((k, v) => _retos[k as String] = (v as num).toInt());
      notifyListeners();
    } catch (_) {/* datos ilegibles: se empieza de cero */}
  }

  Future<void> _guardar() async {
    try {
      await (await SharedPreferences.getInstance()).setString(
          _clave, jsonEncode({'asistencias': [for (final a in _asistencias.values) a.toJson()], 'retos': _retos}));
    } catch (_) {}
  }

  bool asistio(String codigo) => _asistencias.containsKey(codigo);
  Asistencia? asistencia(String codigo) => _asistencias[codigo];

  /// false si ya estaba registrada (no suma dos veces).
  Future<bool> registrarAsistencia({required EventoZanky evento, required String nombre, String? grupo}) async {
    await cargar();
    if (asistio(evento.codigo)) return false;
    final g = grupo?.trim();
    _asistencias[evento.codigo] = Asistencia(
      codigo: evento.codigo,
      titulo: evento.titulo,
      nombre: nombre.trim(),
      grupo: g == null || g.isEmpty ? null : g,
      en: DateTime.now(),
    );
    await _guardar();
    notifyListeners();
    return true;
  }

  int mejorReto(String codigo) => _retos[codigo] ?? 0;

  /// Devuelve los puntos NUEVOS: solo cuenta lo que mejora el mejor resultado anterior.
  Future<int> guardarReto(String codigo, int aciertos) async {
    await cargar();
    final previo = mejorReto(codigo);
    if (aciertos <= previo) return 0;
    _retos[codigo] = aciertos;
    await _guardar();
    notifyListeners();
    return (aciertos - previo) * puntosPorAcierto;
  }

  int get puntos =>
      _asistencias.length * puntosAsistencia + _retos.values.fold(0, (a, b) => a + b) * puntosPorAcierto;
  int get eventos => {..._asistencias.keys, ..._retos.keys}.length;
  List<Asistencia> get asistencias => _asistencias.values.toList()..sort((a, b) => b.en.compareTo(a.en));
}
