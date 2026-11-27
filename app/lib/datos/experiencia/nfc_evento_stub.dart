import 'nfc_evento.dart';

GrabadorNfc crearGrabadorNfc() => const _SinNfc();

class _SinNfc implements GrabadorNfc {
  const _SinNfc();

  @override
  bool get disponible => false;

  @override
  Future<void> grabar(String enlace) =>
      Future.error(UnsupportedError('Este dispositivo no puede grabar NFC.'));
}
