/// Transición de página con deslizar desde el borde para volver, en todas las
/// plataformas (el gesto de iOS también con ratón en la web y el escritorio).
///
/// Se apoya en `CupertinoPageRoute`, que ya trae el arrastre desde el borde
/// izquierdo con seguimiento del dedo y el paralaje de la página de atrás. Lo
/// añadido: con «reducir movimiento» la transición dura un instante (sin
/// deslizar) y el gesto sigue funcionando. Idea de `page-transition.tsx` de
/// FastFood (entrada corta, sin reanimar al volver); siempre queda el botón
/// «Volver» de cada pantalla como alternativa.
library;

import 'package:flutter/cupertino.dart';

class RutaBorde<T> extends CupertinoPageRoute<T> {
  RutaBorde({required super.builder, super.settings, this.sinMovimiento = false});

  final bool sinMovimiento;

  @override
  Duration get transitionDuration => sinMovimiento ? const Duration(milliseconds: 1) : const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => sinMovimiento ? const Duration(milliseconds: 1) : const Duration(milliseconds: 360);
}

/// Abre [builder] con deslizar-desde-el-borde para volver.
Future<T?> abrirConBorde<T>(BuildContext context, WidgetBuilder builder, {RouteSettings? settings}) {
  return Navigator.of(context).push<T>(
    RutaBorde<T>(
      builder: builder,
      settings: settings,
      sinMovimiento: MediaQuery.disableAnimationsOf(context),
    ),
  );
}
