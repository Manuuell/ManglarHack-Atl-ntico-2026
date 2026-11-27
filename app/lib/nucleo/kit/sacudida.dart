import 'package:flutter/material.dart';

import '../base/movimiento.dart';
import 'haptica.dart';

/// Sacude a su hijo de lado a lado (el «no» de iOS) cada vez que [disparos]
/// sube: 0 → −6 → 6 → −4 → 0 px en tramos de [AppMotion.tramoSacudida]
/// (≈0,24 s) y una vibración de error.
///
/// Anima lo que **cambia**, no lo que se monta: en el primer dibujo no se
/// mueve aunque [disparos] sea mayor que cero. Con «reducir movimiento» solo
/// vibra (sin recorrido).
///
/// ```dart
/// Sacudida(disparos: intentosFallidos, child: CampoDeTexto(...))
/// ```
/// Solo mueve (con `Transform`, sin relayout) y no reconstruye al hijo.
class Sacudida extends StatefulWidget {
  const Sacudida({super.key, required this.disparos, required this.child, this.vibrar = true});

  final int disparos;
  final Widget child;

  /// Si vibra con el error. `BotonEstado` lo pone en falso porque ya vibra él.
  final bool vibrar;

  @override
  State<Sacudida> createState() => _SacudidaState();
}

class _SacudidaState extends State<Sacudida> with SingleTickerProviderStateMixin {
  late final AnimationController _reloj =
      AnimationController(vsync: this, duration: AppMotion.tramoSacudida * 4);

  static final Animatable<double> _recorrido = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0).chain(CurveTween(curve: Curves.easeOut)), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 1),
  ]);

  @override
  void didUpdateWidget(Sacudida old) {
    super.didUpdateWidget(old);
    if (widget.disparos > old.disparos) {
      if (widget.vibrar) vibrarError();
      if (!context.animationsDisabled) _reloj.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _reloj,
      child: widget.child,
      builder: (context, hijo) => Transform.translate(offset: Offset(_recorrido.evaluate(_reloj), 0), child: hijo),
    );
  }
}
