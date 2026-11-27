import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'almacen_fotos.dart';

AlmacenFotos? crearAlmacen() => _AlmacenIndexedDb();

/// Fotos en IndexedDB (base «zanky-fotos», almacén «fotos»: clave → bytes).
class _AlmacenIndexedDb implements AlmacenFotos {
  static const _base = 'zanky-fotos';
  static const _almacen = 'fotos';

  web.IDBDatabase? _abierta;

  Future<web.IDBDatabase> _abrir() {
    final c = Completer<web.IDBDatabase>();
    final req = web.window.indexedDB.open(_base, 1);
    req.onupgradeneeded = ((web.Event _) {
      final db = req.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_almacen)) db.createObjectStore(_almacen);
    }).toJS;
    req.onsuccess = ((web.Event _) => c.complete(req.result as web.IDBDatabase)).toJS;
    req.onerror = ((web.Event _) => c.completeError(_error(req.error, 'abrir IndexedDB'))).toJS;
    req.onblocked = ((web.Event _) => c.completeError(Exception('IndexedDB bloqueada por otra pestaña'))).toJS;
    return c.future;
  }

  Object _error(web.DOMException? e, String que) => Exception('${e?.name ?? 'Error'}: ${e?.message ?? que}');

  /// Corre [accion] en una transacción y espera a que termine (commit), no solo la petición:
  /// una escritura fuera de cuota falla recién al cerrar la transacción.
  Future<JSAny?> _transaccion(String modo, web.IDBRequest Function(web.IDBObjectStore) accion) async {
    final db = _abierta ??= await _abrir();
    final tx = db.transaction(_almacen.toJS, modo);
    final listo = Completer<void>();
    tx.oncomplete = ((web.Event _) {
      if (!listo.isCompleted) listo.complete();
    }).toJS;
    tx.onerror = ((web.Event _) {
      if (!listo.isCompleted) listo.completeError(_error(tx.error, 'transacción'));
    }).toJS;
    tx.onabort = ((web.Event _) {
      if (!listo.isCompleted) listo.completeError(_error(tx.error, 'transacción cancelada'));
    }).toJS;
    final req = accion(tx.objectStore(_almacen));
    await listo.future;
    return req.result;
  }

  @override
  Future<void> guardar(String clave, Uint8List bytes) async {
    await _transaccion('readwrite', (s) => s.put(bytes.toJS, clave.toJS));
  }

  @override
  Future<Uint8List?> leer(String clave) async {
    final r = await _transaccion('readonly', (s) => s.get(clave.toJS));
    return r == null ? null : (r as JSUint8Array).toDart;
  }

  @override
  Future<void> borrar(String clave) async {
    await _transaccion('readwrite', (s) => s.delete(clave.toJS));
  }

  @override
  Future<List<String>> claves() async {
    final r = await _transaccion('readonly', (s) => s.getAllKeys());
    return r == null ? [] : [for (final k in (r as JSArray<JSString>).toDart) k.toDart];
  }
}
