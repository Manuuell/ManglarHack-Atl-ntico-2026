import 'dictado.dart';

class _SinDictado implements Dictado {
  @override
  bool get disponible => false;
  @override
  Future<String?> escuchar() async => null;
  @override
  void detener() {}
}

Dictado crearDictado() => _SinDictado();
