import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'dictado.dart';

class _DictadoWeb implements Dictado {
  JSObject? _activo;

  JSFunction? get _clase {
    final g = globalContext;
    final c = g['SpeechRecognition'] ?? g['webkitSpeechRecognition'];
    return c.isA<JSFunction>() ? c as JSFunction : null;
  }

  @override
  bool get disponible => _clase != null;

  @override
  Future<String?> escuchar() {
    final clase = _clase;
    if (clase == null) return Future.value(null);
    final listo = Completer<String?>();
    void fin(String? t) {
      if (!listo.isCompleted) listo.complete(t);
    }

    try {
      final r = clase.callAsConstructor<JSObject>();
      _activo = r;
      r['lang'] = 'es-CO'.toJS;
      r['interimResults'] = false.toJS;
      r['maxAlternatives'] = 1.toJS;
      r['onresult'] = ((JSObject e) {
        try {
          final res = (e['results'] as JSObject)['0'] as JSObject;
          final alt = res['0'] as JSObject;
          final t = (alt['transcript'] as JSString?)?.toDart.trim();
          fin(t == null || t.isEmpty ? null : t);
        } catch (_) {
          fin(null);
        }
      }).toJS;
      r['onerror'] = ((JSObject _) => fin(null)).toJS;
      r['onend'] = ((JSObject _) => fin(null)).toJS;
      r.callMethod('start'.toJS);
    } catch (_) {
      fin(null);
    }
    return listo.future.whenComplete(() => _activo = null);
  }

  @override
  void detener() {
    try {
      _activo?.callMethod('stop'.toJS);
    } catch (_) {}
  }
}

Dictado crearDictado() => _DictadoWeb();
