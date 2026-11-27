import 'dart:convert';

const tiposBloque = ['titulo', 'texto', 'imagen_url', 'boton', 'aviso', 'lista'];

class Bloque {
  const Bloque({required this.id, required this.tipo, this.texto = '', this.url = '', this.oculto = false});
  final String id, tipo, texto, url;
  final bool oculto;

  Bloque copiar({String? texto, String? url, bool? oculto}) => Bloque(
    id: id, tipo: tipo, texto: texto ?? this.texto, url: url ?? this.url, oculto: oculto ?? this.oculto,
  );

  Map<String, dynamic> toJson() => {'id': id, 'tipo': tipo, 'texto': texto, if (url.isNotEmpty) 'url': url, 'oculto': oculto};

  static Bloque desdeJson(Object? valor) {
    final j = valor as Map;
    final tipo = j['tipo']?.toString() ?? '';
    if (!tiposBloque.contains(tipo)) throw const FormatException('Tipo de bloque inválido');
    return Bloque(
      id: j['id']?.toString() ?? '', tipo: tipo,
      texto: j['texto']?.toString() ?? '', url: j['url']?.toString() ?? '',
      oculto: j['oculto'] == true,
    );
  }
}

class DocumentoContenido {
  const DocumentoContenido({required this.clave, required this.ambito, required this.bloques,
    this.publicado = false, this.version = 0, this.editadoEn});
  final String clave, ambito;
  final List<Bloque> bloques;
  final bool publicado;
  final int version;
  final DateTime? editadoEn;

  DocumentoContenido copiar({List<Bloque>? bloques, bool? publicado, int? version}) => DocumentoContenido(
    clave: clave, ambito: ambito, bloques: bloques ?? this.bloques,
    publicado: publicado ?? this.publicado, version: version ?? this.version, editadoEn: editadoEn,
  );
  Map<String, dynamic> toJson() => {'clave': clave, 'ambito': ambito,
    'bloques': bloques.map((b) => b.toJson()).toList(), 'publicado': publicado,
    'version': version, if (editadoEn != null) 'editado_en': editadoEn!.toIso8601String()};
  static DocumentoContenido desdeJson(Object? valor) {
    final j = valor as Map;
    return DocumentoContenido(
      clave: j['clave'] as String, ambito: j['ambito'] as String,
      bloques: [for (final b in j['bloques'] as List? ?? const []) Bloque.desdeJson(b)],
      publicado: j['publicado'] == true, version: (j['version'] as num?)?.toInt() ?? 0,
      editadoEn: DateTime.tryParse(j['editado_en']?.toString() ?? ''),
    );
  }
  String codificar() => jsonEncode(toJson());
}

/// Historial de edición en memoria, independiente de las versiones guardadas.
class BorradorContenido {
  BorradorContenido(this.actual);
  DocumentoContenido actual;
  final List<DocumentoContenido> _anteriores = [];
  bool get puedeDeshacer => _anteriores.isNotEmpty;

  void cambiar(DocumentoContenido siguiente) {
    _anteriores.add(actual);
    actual = siguiente;
  }
  void agregar(Bloque bloque) => cambiar(actual.copiar(bloques: [...actual.bloques, bloque]));
  void editar(String id, {String? texto, String? url, bool? oculto}) => cambiar(actual.copiar(bloques: [
    for (final b in actual.bloques) b.id == id ? b.copiar(texto: texto, url: url, oculto: oculto) : b,
  ]));
  void reordenar(int viejo, int nuevo) {
    final bloques = [...actual.bloques];
    if (nuevo > viejo) nuevo--;
    final bloque = bloques.removeAt(viejo);
    bloques.insert(nuevo, bloque);
    cambiar(actual.copiar(bloques: bloques));
  }
  void quitar(String id) => cambiar(actual.copiar(bloques: [for (final b in actual.bloques) if (b.id != id) b]));
  void deshacer() { if (_anteriores.isNotEmpty) actual = _anteriores.removeLast(); }
  void guardado(DocumentoContenido documento) { actual = documento; _anteriores.clear(); }
}
