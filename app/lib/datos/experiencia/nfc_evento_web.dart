import 'dart:js_interop';

import 'nfc_evento.dart';

@JS('zankyNfcDisponible')
external JSBoolean _disponible();

@JS('zankyNfcGrabar')
external JSPromise<JSAny?> _grabar(JSString enlace);

GrabadorNfc crearGrabadorNfc() => const _NfcWeb();

class _NfcWeb implements GrabadorNfc {
  const _NfcWeb();

  @override
  bool get disponible => _disponible().toDart;

  @override
  Future<void> grabar(String enlace) async {
    await _grabar(enlace.toJS).toDart;
  }
}
