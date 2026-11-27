import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un conjunto de ids que se guarda en el teléfono y avisa al cambiar: las jornadas en las que me
/// inscribí, las noticias que guardé y las que oculté. Se lee una sola vez (perezoso) y cada cambio
/// se escribe al momento, así la marca sobrevive a cerrar la app sin pedir nada al servidor.
class MarcasGuardadas extends ValueNotifier<Set<String>> {
  MarcasGuardadas(this.clave) : super(const {});

  final String clave;
  bool _leido = false;

  /// Lee lo guardado (una vez). Seguro de llamar desde cualquier `initState`.
  Future<void> cargar() async {
    if (_leido) return;
    _leido = true;
    try {
      final l = (await SharedPreferences.getInstance()).getStringList(clave);
      if (l != null && l.isNotEmpty) value = {...value, ...l};
    } catch (_) {}
  }

  bool tiene(String id) => value.contains(id);

  void poner(String id, bool si) {
    if (tiene(id) == si) return;
    value = si ? {...value, id} : ({...value}..remove(id));
    _escribir();
  }

  /// Invierte la marca y devuelve cómo quedó.
  bool alternar(String id) {
    final nuevo = !tiene(id);
    poner(id, nuevo);
    return nuevo;
  }

  Future<void> _escribir() async {
    try {
      await (await SharedPreferences.getInstance()).setStringList(clave, value.toList());
    } catch (_) {}
  }

  /// Para pruebas: vuelve a empezar sin leer el disco.
  @visibleForTesting
  void reiniciar() {
    _leido = true;
    value = const {};
  }
}

/// Jornadas en las que me inscribí desde este teléfono.
final jornadasInscritas = MarcasGuardadas('zanky.comunidad.inscritas');

/// Noticias guardadas para leer después.
final noticiasGuardadas = MarcasGuardadas('zanky.comunidad.noticias_guardadas');

/// Noticias que oculté (no vuelven a salir en Inicio ni en Comunidad).
final noticiasOcultas = MarcasGuardadas('zanky.comunidad.noticias_ocultas');
