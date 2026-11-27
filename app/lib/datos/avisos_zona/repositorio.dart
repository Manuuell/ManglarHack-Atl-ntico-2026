import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../servidor.dart';

class AvisoCercano {
  const AvisoCercano({required this.id, required this.zona, required this.tipo,
    required this.prioridad, required this.creadoEn, this.apoye = false});
  final String id, zona, tipo, prioridad;
  final DateTime creadoEn;
  final bool apoye;

  factory AvisoCercano.deJson(Map<String, dynamic> j) {
    final d = j['datos'] as Map<String, dynamic>? ?? const {};
    return AvisoCercano(id: j['id'] as String, zona: d['zona'] as String? ?? '',
      tipo: d['tipo'] as String? ?? '', prioridad: d['prioridad'] as String? ?? '',
      creadoEn: DateTime.parse(j['creado_en'] as String), apoye: j['apoye'] == true);
  }
}

class AltaVoluntario {
  const AltaVoluntario({required this.nombre, required this.telefono, required this.zona,
    required this.lat, required this.lon, required this.radioKm, required this.canales,
    required this.tipos, required this.consentimiento, this.silencioDesde, this.silencioHasta});
  final String nombre, telefono, zona;
  final double lat, lon, radioKm;
  final List<String> canales, tipos;
  final bool consentimiento;
  final String? silencioDesde, silencioHasta;

  Map<String, dynamic> aRpc() => {
    'p_nombre': nombre, 'p_telefono_e164': telefono, 'p_zona': zona,
    'p_lat': lat, 'p_lon': lon, 'p_radio_km': radioKm,
    'p_canales': canales, 'p_tipos_aviso': tipos,
    'p_silencio_desde': silencioDesde, 'p_silencio_hasta': silencioHasta,
    'p_consentimiento': consentimiento,
  };
}

/// Solo guarda la capacidad de acceso, nunca el número ni el nombre en preferencias.
class RepositorioAvisosZona {
  RepositorioAvisosZona({Servidor? servidor}) : servidor = servidor ?? Servidor();
  final Servidor servidor;
  static const _claveToken = 'avisos_zona.token.v1';
  static const _claveDemo = 'avisos_zona.demo.v1';
  bool get demostracion => !servidor.configurado;

  Future<String?> token() async => (await SharedPreferences.getInstance()).getString(_claveToken);
  Future<bool> inscrito() async => demostracion
      ? (await SharedPreferences.getInstance()).getBool(_claveDemo) == true
      : await token() != null;

  Future<void> inscribir(AltaVoluntario alta) async {
    if (!alta.consentimiento) throw StateError('Debes aceptar el tratamiento de datos.');
    final prefs = await SharedPreferences.getInstance();
    if (demostracion) {
      await prefs.setBool(_claveDemo, true);
      await prefs.remove('avisos_zona.apoyo_demo');
      return;
    }
    final j = await _rpc('hacerme_voluntario', alta.aRpc());
    if (j is! Map || j['telefono_id'] is! String) throw StateError('Respuesta de inscripción inválida.');
    await prefs.setString(_claveToken, j['telefono_id'] as String);
  }

  Future<void> baja() async {
    final prefs = await SharedPreferences.getInstance();
    if (demostracion) {
      await prefs.remove(_claveDemo);
      await prefs.remove('avisos_zona.apoyo_demo');
      return;
    }
    final t = prefs.getString(_claveToken);
    if (t == null) return;
    final ok = await _rpc('darme_de_baja', {'token': t});
    if (ok != true) throw StateError('No se pudo confirmar la baja.');
    await prefs.remove(_claveToken);
  }

  Future<List<AvisoCercano>> listar() async {
    if (demostracion) {
      if (!await inscrito()) return const [];
      return [AvisoCercano(id: 'demo-1', zona: 'mallorquin', tipo: 'basuras',
        prioridad: 'media', creadoEn: DateTime.now(),
        apoye: (await SharedPreferences.getInstance()).getBool('avisos_zona.apoyo_demo') == true)];
    }
    final t = await token();
    if (t == null) return const [];
    final j = await _rpc('mis_avisos', {'telefono_id': t});
    if (j is! List) throw StateError('Respuesta de avisos inválida.');
    return [for (final x in j) AvisoCercano.deJson(Map<String, dynamic>.from(x as Map))];
  }

  Future<int> ayudar(String avisoId) async {
    if (demostracion) {
      await (await SharedPreferences.getInstance()).setBool('avisos_zona.apoyo_demo', true);
      return 1;
    }
    final t = await token();
    if (t == null) throw StateError('Inscríbete primero.');
    final j = await _rpc('voy_a_ayudar', {'telefono_id': t, 'p_aviso_id': avisoId});
    if (j is! Map || j['participaciones'] is! num) throw StateError('Respuesta de apoyo inválida.');
    return (j['participaciones'] as num).toInt();
  }

  Future<dynamic> _rpc(String nombre, Map<String, dynamic> cuerpo) async {
    final r = await servidor.pedir('POST', Uri.parse('${servidor.base}/rest/v1/rpc/$nombre'),
      {'apikey': servidor.anon, 'Authorization': 'Bearer ${servidor.anon}',
       'Content-Type': 'application/json'}, cuerpo: jsonEncode(cuerpo));
    if (r.statusCode >= 300) {
      throw ErrorServidor(nombre, r.body, estadoHttp: r.statusCode);
    }
    return jsonDecode(r.body);
  }
}
