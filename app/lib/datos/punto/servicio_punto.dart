import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../servidor.dart';
import 'punto_zanky.dart';

/// La visita queda local hasta recibir confirmación. El servidor deduplica por teléfono y día.
class ServicioPunto {
  ServicioPunto({Servidor? servidor}) : servidor = servidor ?? Servidor();
  final Servidor servidor;
  static const _claveTelefono = 'puntos_telefono_id';
  static const _claveCola = 'puntos_visitas_pendientes';
  static const _claveFotos = 'puntos_fotos_pendientes';

  Future<PuntoZanky?> cargar(String codigo) async {
    final preferencias = await SharedPreferences.getInstance();
    final guardado = preferencias.getString('punto_cache_$codigo');
    if (!servidor.configurado) {
      for (final punto in puntosDemostracion) {
        if (punto.codigo == codigo) return punto;
      }
      return null;
    }
    try {
      final r = await servidor.pedir('GET', Uri.parse('${servidor.base}/rest/v1/puntos_publicos?codigo=eq.${Uri.encodeComponent(codigo)}&select=*&limit=1'),
        {'apikey': servidor.anon, 'Authorization': 'Bearer ${servidor.anon}'});
      if (r.statusCode >= 300) throw ErrorServidor('punto', r.body, estadoHttp: r.statusCode);
      final lista = jsonDecode(r.body) as List;
      if (lista.isEmpty) { await preferencias.remove('punto_cache_$codigo'); return null; }
      final p = PuntoZanky.deJson(Map<String, dynamic>.from(lista.first as Map));
      await preferencias.setString('punto_cache_$codigo', jsonEncode(p.aJson()));
      return p;
    } catch (_) {
      if (guardado == null) rethrow;
      return PuntoZanky.deJson(jsonDecode(guardado) as Map<String, dynamic>);
    }
  }

  Future<bool> registrar(String codigo) async {
    await guardarPendiente(codigo);
    return sincronizar();
  }

  /// Guarda el código del QR antes de intentar cualquier petición de red.
  Future<void> guardarPendiente(String codigo) async {
    final preferencias = await SharedPreferences.getInstance();
    final telefono = preferencias.getString(_claveTelefono) ?? const Uuid().v4();
    await preferencias.setString(_claveTelefono, telefono);
    final cola = preferencias.getStringList(_claveCola) ?? <String>[];
    if (!cola.contains(codigo)) cola.add(codigo);
    await preferencias.setStringList(_claveCola, cola);
  }

  Future<bool> sincronizar() async {
    if (!servidor.configurado) return false;
    final preferencias = await SharedPreferences.getInstance();
    final telefono = preferencias.getString(_claveTelefono);
    if (telefono == null) return sincronizarFotos();
    final cola = preferencias.getStringList(_claveCola) ?? <String>[];
    for (final codigo in List<String>.from(cola)) {
      try {
        final r = await servidor.pedir('POST', Uri.parse('${servidor.base}/rest/v1/rpc/registrar_visita'), {
          'apikey': servidor.anon, 'Authorization': 'Bearer ${servidor.anon}',
          'Content-Type': 'application/json',
        }, cuerpo: jsonEncode({'codigo': codigo, 'telefono_id': telefono}));
        // Solo un punto retirado es definitivo. Un límite diario o un despliegue
        // todavía sin la RPC se reintenta después sin perder la visita guardada.
        if (r.statusCode == 404 && r.body.contains('punto_no_existe')) {
          cola.remove(codigo);
          await preferencias.setStringList(_claveCola, cola);
          continue;
        }
        if (r.statusCode >= 300) return false;
        cola.remove(codigo);
        await preferencias.setStringList(_claveCola, cola);
      } catch (_) {
        return false;
      }
    }
    await sincronizarFotos();
    return true;
  }

  Future<bool> vincularFoto(String codigo, String reporteId) async {
    final preferencias = await SharedPreferences.getInstance();
    final cola = preferencias.getStringList(_claveFotos) ?? <String>[];
    final entrada = '$codigo|$reporteId';
    if (!cola.contains(entrada)) cola.add(entrada);
    await preferencias.setStringList(_claveFotos, cola);
    return sincronizarFotos();
  }

  Future<bool> sincronizarFotos() async {
    if (!servidor.configurado) return false;
    final preferencias = await SharedPreferences.getInstance();
    final cola = preferencias.getStringList(_claveFotos) ?? <String>[];
    for (final entrada in List<String>.from(cola)) {
      final partes = entrada.split('|');
      if (partes.length != 2) { cola.remove(entrada); continue; }
      try {
        final r = await servidor.pedir('POST', Uri.parse('${servidor.base}/rest/v1/rpc/vincular_foto_punto'), {
          'apikey': servidor.anon, 'Authorization': 'Bearer ${servidor.anon}',
          'Content-Type': 'application/json',
        }, cuerpo: jsonEncode({'codigo': partes[0], 'reporte_id': partes[1]}));
        if (r.statusCode >= 300) return false;
        cola.remove(entrada);
        await preferencias.setStringList(_claveFotos, cola);
      } catch (_) { return false; }
    }
    await preferencias.setStringList(_claveFotos, cola);
    return true;
  }

  Future<List<Map<String, dynamic>>> lecturas() async {
    if (!servidor.configurado) return [];
    final r = await servidor.pedir('POST', Uri.parse('${servidor.base}/rest/v1/rpc/ultimas_lecturas'), {
      'apikey': servidor.anon, 'Authorization': 'Bearer ${servidor.anon}',
      'Content-Type': 'application/json',
    }, cuerpo: '{}');
    if (r.statusCode >= 300) throw ErrorServidor('lecturas', r.body, estadoHttp: r.statusCode);
    return [for (final dato in jsonDecode(r.body) as List) Map<String, dynamic>.from(dato as Map)];
  }
}
