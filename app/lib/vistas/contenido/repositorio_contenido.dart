import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../datos/admin/controlador_admin.dart';
import '../../datos/servidor.dart';
import 'modelo_contenido.dart';

class RepositorioContenido {
  RepositorioContenido({Servidor? servidor, this.panel, this.tokenEditor, http.Client? cliente})
      : servidor = servidor ?? Servidor(), _cliente = cliente ?? http.Client(), _propio = cliente == null;
  final Servidor servidor;
  final ControladorAdmin? panel;
  /// Para una sesión autenticada de organizador ajena al panel de moderación.
  final Future<String?> Function()? tokenEditor;
  final http.Client _cliente;
  final bool _propio;
  bool get demostracion => !servidor.configurado;
  void cerrar() { if (_propio) _cliente.close(); }

  String _clave(String clave, String ambito, {bool publicado = false}) =>
      'contenido.${publicado ? 'publicado' : 'edicion'}.v1:$ambito:$clave';
  Future<DocumentoContenido?> local(String clave, String ambito, {bool publicado = false}) async {
    final p = await SharedPreferences.getInstance();
    final texto = p.getString(_clave(clave, ambito, publicado: publicado));
    if (texto == null) return null;
    try { return DocumentoContenido.desdeJson(jsonDecode(texto)); } catch (_) { return null; }
  }
  Future<void> _guardarLocal(DocumentoContenido d, {bool publicado = false}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_clave(d.clave, d.ambito, publicado: publicado), d.codificar());
  }

  Future<Map<String, String>> _cabeceras({bool editar = false}) async {
    final token = editar ? await (tokenEditor?.call() ?? panel?.tokenParaContenido()) : null;
    if (editar && token == null) throw StateError('Entra al panel con un rol autorizado.');
    return {'apikey': servidor.anon, 'Authorization': 'Bearer ${token ?? servidor.anon}',
      'Content-Type': 'application/json'};
  }

  /// Última copia local inmediatamente; red cuando hay señal. Un borrador nunca se pinta en público.
  Future<DocumentoContenido?> cargar(String clave, String ambito, {bool editor = false}) async {
    final copia = await local(clave, ambito, publicado: !editor);
    if (demostracion) return copia;
    try {
      final tabla = editor ? 'contenido_app' : 'contenido_publicado';
      final uri = Uri.parse('${servidor.base}/rest/v1/$tabla').replace(queryParameters: {
        'select': '*', 'clave': 'eq.$clave', 'ambito': 'eq.$ambito', 'limit': '1',
      });
      final r = await _cliente.get(uri, headers: await _cabeceras(editar: editor))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) throw StateError('Contenido ${r.statusCode}');
      final filas = jsonDecode(r.body) as List;
      if (filas.isEmpty) return editor ? copia : null;
      final d = DocumentoContenido.desdeJson(filas.first);
      await _guardarLocal(d, publicado: !editor);
      return editor || d.publicado ? d : null;
    } catch (_) { return editor || copia?.publicado == true ? copia : null; }
  }

  Future<DocumentoContenido> guardar(DocumentoContenido d, {required bool publicar}) async {
    if (demostracion) {
      final nuevo = d.copiar(publicado: publicar, version: d.version + 1);
      await _guardarLocal(nuevo);
      if (publicar) await _guardarLocal(nuevo, publicado: true);
      final p = await SharedPreferences.getInstance();
      final key = 'contenido.versiones.v1:${d.ambito}:${d.clave}';
      final historial = p.getStringList(key) ?? [];
      await p.setStringList(key, [...historial, nuevo.codificar()]);
      return nuevo;
    }
    final r = await _cliente.post(Uri.parse('${servidor.base}/rest/v1/rpc/guardar_contenido'),
      headers: await _cabeceras(editar: true), body: jsonEncode({
        'p_clave': d.clave, 'p_ambito': d.ambito,
        'p_bloques': d.bloques.map((b) => b.toJson()).toList(),
        'p_publicado': publicar, 'p_version_esperada': d.version,
      })).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw StateError(r.statusCode == 409
        ? 'Otra persona guardó una versión. Recarga antes de publicar.'
        : 'No se pudo guardar (${r.statusCode}).');
    }
    final nuevo = DocumentoContenido.desdeJson(jsonDecode(r.body));
    await _guardarLocal(nuevo);
    if (publicar) await _guardarLocal(nuevo, publicado: true);
    return nuevo;
  }

  Future<List<DocumentoContenido>> versiones(String clave, String ambito) async {
    if (demostracion) {
      final p = await SharedPreferences.getInstance();
      return [for (final s in p.getStringList('contenido.versiones.v1:$ambito:$clave') ?? <String>[])
        DocumentoContenido.desdeJson(jsonDecode(s))].reversed.toList();
    }
    final uri = Uri.parse('${servidor.base}/rest/v1/contenido_versiones').replace(queryParameters: {
      'select': '*', 'clave': 'eq.$clave', 'ambito': 'eq.$ambito', 'order': 'version.desc', 'limit': '30',
    });
    final r = await _cliente.get(uri, headers: await _cabeceras(editar: true))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) throw StateError('No se pudo leer el historial (${r.statusCode}).');
    return [for (final x in jsonDecode(r.body) as List) DocumentoContenido.desdeJson(x)];
  }
}
