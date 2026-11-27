/// Cerrar una pantalla de detalle tirando hacia abajo desde arriba, como el lector
/// de noticias (`lector_noticia.dart`, de donde sale la regla): al pasar [umbral]
/// vibra una vez, una pista redonda cambia de flecha a «×», y al soltar se cierra.
/// Si vuelve por debajo del umbral antes de soltar, no pasa nada (soltar fuera cancela).
///
/// Va por encima de un `CustomScrollView` con `BouncingScrollPhysics`: escucha sus
/// notificaciones (solo profundidad 0) y no cambia el desplazamiento. Con «reducir
/// movimiento» la pista aparece sin escala y el gesto sigue funcionando.
library;

import 'package:flutter/material.dart';

import '../presionable.dart';

/// Distancia por defecto para cerrar (la misma del lector de noticias).
const double umbralCerrarTirando = 110;

class CerrarTirando extends StatefulWidget {
  const CerrarTirando({super.key, required this.child, this.umbral = umbralCerrarTirando, this.retroHaptica});

  final Widget child;
  final double umbral;

  /// Háptica al cruzar el umbral, inyectable para pruebas.
  final VoidCallback? retroHaptica;

  @override
  State<CerrarTirando> createState() => _CerrarTirandoState();
}

class _CerrarTirandoState extends State<CerrarTirando> {
  final _tiron = ValueNotifier<double>(0);
  bool _pasoUmbral = false;
  bool _cerrando = false;

  @override
  void dispose() {
    _tiron.dispose();
    super.dispose();
  }

  bool _alDesplazar(ScrollNotification s) {
    if (s.depth != 0 || _cerrando) return false;
    _tiron.value = (-s.metrics.pixels).clamp(0.0, 400.0);
    if (s is ScrollUpdateNotification) {
      if (s.dragDetails != null) {
        final paso = -s.metrics.pixels > widget.umbral;
        if (paso != _pasoUmbral) {
          _pasoUmbral = paso;
          if (paso) (widget.retroHaptica ?? () => vibrar(Vibracion.ligera))();
        }
      } else if (_pasoUmbral) {
        _cerrar();
      }
    } else if (s is ScrollEndNotification && _pasoUmbral) {
      _cerrar();
    }
    return false;
  }

  void _cerrar() {
    _cerrando = true;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    final sinMov = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(onNotification: _alDesplazar, child: widget.child),
        // Pista «suelta para cerrar» (solo opacity y transform).
        Positioned(
          top: arriba + 10,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: ValueListenableBuilder<double>(
              valueListenable: _tiron,
              builder: (_, t, _) {
                final f = (t / widget.umbral).clamp(0.0, 1.0);
                if (f == 0) return const SizedBox.shrink();
                final pista = Container(
                  key: const ValueKey('pista-cerrar-tirando'),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                  child: Icon(f >= 1 ? Icons.close_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.white),
                );
                return Opacity(
                  opacity: f,
                  child: Center(
                    child: sinMov ? pista : Transform.scale(scale: 0.8 + 0.2 * f, child: pista),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
