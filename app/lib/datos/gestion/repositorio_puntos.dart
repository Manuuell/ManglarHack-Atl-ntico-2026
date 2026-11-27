import 'dart:convert';

import '../admin/repositorio_admin.dart';
import '../punto/punto_zanky.dart';
import '../servidor.dart';

bool puedeGestionarPuntos(String? rol) => const {
  'admin', 'investigador', 'organizador',
}.contains(rol);

List<PuntoZanky> filtrarPuntos(List<PuntoZanky> puntos, int filtro) => puntos.where((p) =>
  filtro == 0 || (filtro == 1 && p.activo) || (filtro == 2 && !p.activo)).toList();

abstract class RepositorioPuntos {
  bool get demostracion;
  Future<List<PuntoZanky>> listar({String? zona});
  Future<PuntoZanky> guardar(PuntoZanky punto);
  Future<Map<String, dynamic>> resumen(String codigo);
}

class RepositorioPuntosDemo implements RepositorioPuntos {
  RepositorioPuntosDemo([List<PuntoZanky>? semilla]) : _puntos = [...?semilla];
  final List<PuntoZanky> _puntos;
  @override
  bool get demostracion => true;
  @override
  Future<List<PuntoZanky>> listar({String? zona}) async => List.unmodifiable(
    _puntos.where((p) => zona == null || p.zona == zona));
  @override
  Future<PuntoZanky> guardar(PuntoZanky punto) async {
    final i = _puntos.indexWhere((p) => p.codigo == punto.codigo);
    if (i < 0) { _puntos.add(punto); } else { _puntos[i] = punto; }
    return punto;
  }
  @override
  Future<Map<String, dynamic>> resumen(String codigo) async =>
      {'codigo': codigo, 'total': 0, 'por_dia': <dynamic>[]};
}

class RepositorioPuntosRemoto implements RepositorioPuntos {
  RepositorioPuntosRemoto(this.servidor, this.sesion);
  final Servidor servidor;
  final SesionAdmin sesion;
  @override
  bool get demostracion => false;

  Future<dynamic> _rpc(String nombre, Map<String, dynamic> datos) async {
    if (sesion.porVencer(DateTime.now())) {
      await RepositorioRemoto.refrescar(servidor, sesion, DateTime.now());
    }
    final r = await servidor.pedir('POST', Uri.parse('${servidor.base}/rest/v1/rpc/$nombre'), {
      'apikey': servidor.anon, 'Authorization': 'Bearer ${sesion.token}',
      'Content-Type': 'application/json',
    }, cuerpo: jsonEncode(datos));
    if (r.statusCode >= 300) throw ErrorPanel.deRespuesta(r.statusCode, r.body);
    return jsonDecode(r.body);
  }

  @override
  Future<List<PuntoZanky>> listar({String? zona}) async => [
    for (final j in (await _rpc('puntos_de', {'zona': zona})) as List)
      PuntoZanky.deJson(Map<String, dynamic>.from(j as Map)),
  ];
  @override
  Future<PuntoZanky> guardar(PuntoZanky punto) async => PuntoZanky.deJson(
    Map<String, dynamic>.from(await _rpc('guardar_punto', {'p': punto.aJson()}) as Map));
  @override
  Future<Map<String, dynamic>> resumen(String codigo) async =>
    Map<String, dynamic>.from(await _rpc('resumen_punto', {'codigo': codigo}) as Map);
}
