import '../guardian.dart';

/// Las cinco ilustraciones terminan en mangle rojo; el sexto rango de Guardián
/// conserva ese árbol y su nombre de rango en la tarjeta del perfil.
class EtapaCrecimiento {
  const EtapaCrecimiento(this.numero, this.nombre, this.desde, this.lema);

  final int numero;
  final String nombre;
  final int desde;
  final String lema;

  static const _lemas = [
    'Toda raíz empieza flotando.',
    'Ya encontraste dónde echar raíz.',
    'Tus hojas empiezan a dar sombra.',
    'Tus raíces sostienen la orilla.',
    'Ya eres parte del bosque que cuida la costa.',
  ];

  static final todas = List<EtapaCrecimiento>.unmodifiable([
    for (var i = 0; i < 5; i++)
      EtapaCrecimiento(Nivel.todos[i].numero, Nivel.todos[i].nombre,
        Nivel.todos[i].desde, _lemas[i]),
  ]);

  static EtapaCrecimiento dePuntos(int puntos) =>
      todas.lastWhere((etapa) => puntos >= etapa.desde);

  EtapaCrecimiento? get siguiente => numero < todas.length ? todas[numero] : null;
}

class AvanceCrecimiento {
  const AvanceCrecimiento._(this.etapa, this.siguiente, this.faltanPuntos, this.fraccion);

  final EtapaCrecimiento etapa;
  final EtapaCrecimiento? siguiente;
  final int faltanPuntos;
  final double fraccion;

  static AvanceCrecimiento de(int puntos) {
    final actual = EtapaCrecimiento.dePuntos(puntos < 0 ? 0 : puntos);
    final siguiente = actual.siguiente;
    if (siguiente == null) return AvanceCrecimiento._(actual, null, 0, 1);
    return AvanceCrecimiento._(
      actual,
      siguiente,
      (siguiente.desde - puntos).clamp(0, siguiente.desde).toInt(),
      ((puntos - actual.desde) / (siguiente.desde - actual.desde)).clamp(0.0, 1.0).toDouble(),
    );
  }

  /// Un reporte validado da entre 50 y 100 puntos. Se indica una estimación,
  /// nunca se promete un número exacto de reportes.
  String get faltaTexto {
    if (siguiente == null) return 'Zanky alcanzó su forma de mangle rojo.';
    final aproximados = (faltanPuntos / 50).ceil();
    return 'Faltan $faltanPuntos puntos · hasta $aproximados ${aproximados == 1 ? 'reporte validado más' : 'reportes validados más'}';
  }
}

/// La última etapa vista se guarda por guardián. La primera visita fija el
/// punto de partida sin fingir una evolución que ocurrió antes de abrirla.
class RegistroEvolucion {
  static const prefijo = 'crecimiento.etapa.v1.';

  static String clave(String? idGuardian) => '$prefijo${idGuardian ?? 'local'}';

  static bool debeEvolucionar(int? vista, int actual) =>
      vista != null && actual > vista && actual > 1;

  static int etapaAnterior(int vista, int actual) =>
      vista.clamp(1, actual - 1).toInt();
}

