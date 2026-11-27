import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool _llamar(String f) {
  try {
    final r = globalContext.callMethod<JSAny?>(f.toJS);
    return r.isA<JSBoolean>() && (r as JSBoolean).toDart;
  } catch (_) {
    return false;
  }
}

bool appInstalada() => _llamar('zankyInstalada');
bool puedeInstalarApp() => _llamar('zankyPuedeInstalar');

Future<bool> instalarApp() async {
  try {
    final p = globalContext.callMethod<JSPromise<JSString>>('zankyInstalar'.toJS);
    return (await p.toDart).toDart == 'si';
  } catch (_) {
    return false;
  }
}
