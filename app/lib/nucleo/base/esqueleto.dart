import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'tokens.dart';
import 'movimiento.dart';

/// Placeholder "shimmer" para listas/tarjetas mientras cargan — reemplaza el
/// típico spinner centrado por una previsualización de la forma del
/// contenido.
///
/// El brillo es un degradado desplazado (nunca se anima con `Opacity`: eso
/// repintaría todo el subárbol), aislado en un [RepaintBoundary], y se
/// congela con movimiento reducido (accesibilidad + batería).
class Skeleton extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const Skeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.sm)),
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: AppMotion.shimmer);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.animationsDisabled) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (context.animationsDisabled) {
      return ExcludeSemantics(
        child: RepaintBoundary(
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: widget.borderRadius,
            ),
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Banda clara que barre de izquierda a derecha. El centro se
            // mueve entre 0.25 y 0.75 para que las tres paradas queden
            // siempre dentro de [0, 1] y en orden, sin recortes.
            final centro = 0.25 + 0.5 * _controller.value;
            return Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    colors.surfaceAlt,
                    colors.border,
                    colors.surfaceAlt,
                  ],
                  stops: [centro - 0.25, centro, centro + 0.25],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Formas unificadas del esqueleto: las seis alturas repartidas hoy por las
/// pantallas (64, 84, 92, 108, 128, 148 — varias indistinguibles a ojo)
/// quedan en tres, separadas por al menos 24 puntos:
///
/// - 64 y 84 → [Esqueleto.fila] (84): filas de Tickets y Horario.
/// - 92 y 108 → [Esqueleto.tarjeta] (108): tarjetas de Noticias y Notas.
/// - 128 y 148 → [Esqueleto.cabecera] (148): saldo de Matrícula y promedio.
///
/// [Esqueleto.lista] arma una columna de [conteo] filas ya escalonada con
/// `context.staggerDelay` (60 ms, tope 6). La API de [Skeleton] se conserva
/// tal cual para no romper a las pantallas que la usan.
class Esqueleto extends StatelessWidget {
  const Esqueleto.cabecera({
    super.key,
    this.width = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.xxl)),
  })  : _forma = _FormaEsqueleto.cabecera,
        conteo = 0;

  const Esqueleto.fila({
    super.key,
    this.width = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.xl)),
  })  : _forma = _FormaEsqueleto.fila,
        conteo = 0;

  const Esqueleto.tarjeta({
    super.key,
    this.width = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.xl)),
  })  : _forma = _FormaEsqueleto.tarjeta,
        conteo = 0;

  const Esqueleto.lista(
    this.conteo, {
    super.key,
    this.width = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.xl)),
  }) : _forma = _FormaEsqueleto.lista;

  final _FormaEsqueleto _forma;

  /// Solo lo usa [Esqueleto.lista]: cuántas filas pinta.
  final int conteo;
  final double width;
  final BorderRadius borderRadius;

  static const double altoCabecera = 148;
  static const double altoFila = 84;
  static const double altoTarjeta = 108;

  @override
  Widget build(BuildContext context) {
    if (_forma == _FormaEsqueleto.lista) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < conteo; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _FilaEscalonada(indice: i, width: width, borderRadius: borderRadius),
          ],
        ],
      );
    }
    final alto = switch (_forma) {
      _FormaEsqueleto.cabecera => altoCabecera,
      _FormaEsqueleto.fila => altoFila,
      _FormaEsqueleto.tarjeta => altoTarjeta,
      _FormaEsqueleto.lista => 0.0,
    };
    return Skeleton(width: width, height: alto, borderRadius: borderRadius);
  }
}

enum _FormaEsqueleto { cabecera, fila, tarjeta, lista }

/// Una fila de la lista con entrada escalonada. Con movimiento reducido se
/// pinta la fila final, sin envolverla en nada.
class _FilaEscalonada extends StatelessWidget {
  const _FilaEscalonada({
    required this.indice,
    required this.width,
    required this.borderRadius,
  });

  final int indice;
  final double width;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final fila = Skeleton(
      width: width,
      height: Esqueleto.altoFila,
      borderRadius: borderRadius,
    );
    if (context.animationsDisabled) return fila;
    final retardo = context.staggerDelay(indice);
    return fila
        .animate()
        .fadeIn(duration: AppMotion.normal, delay: retardo, curve: AppMotion.enter)
        .slideY(
          begin: 0.04,
          end: 0,
          duration: AppMotion.normal,
          delay: retardo,
          curve: AppMotion.enter,
        );
  }
}
