import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../base/movimiento.dart';

/// Spinner propio: un arco de 270° que gira una vuelta cada 0,7 s
/// ([AppMotion.giroSpinner]). Sin `CircularProgressIndicator` (Material).
///
/// Es un indicador que **informa** («estoy trabajando»): por eso sigue
/// girando con «reducir movimiento»; un spinner quieto parece colgado (regla
/// 14 de la guía de la casa).
///
/// ```dart
/// const SpinnerZ(tamano: 22, color: Colors.white)
/// ```
///
/// Barato: un controlador y un `CustomPainter` con `repaint`; no reconstruye
/// widgets por cuadro.
class SpinnerZ extends StatefulWidget {
  const SpinnerZ({super.key, this.tamano = 22, this.grosor = 2.6, this.color = Colors.white});

  final double tamano;
  final double grosor;
  final Color color;

  @override
  State<SpinnerZ> createState() => _SpinnerZState();
}

class _SpinnerZState extends State<SpinnerZ> with SingleTickerProviderStateMixin {
  late final AnimationController _giro =
      AnimationController(vsync: this, duration: AppMotion.giroSpinner)..repeat();

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.tamano,
          child: CustomPaint(painter: _PintorSpinner(_giro, widget.color, widget.grosor)),
        ),
      ),
    );
  }
}

class _PintorSpinner extends CustomPainter {
  _PintorSpinner(this.giro, this.color, this.grosor) : super(repaint: giro);

  final Animation<double> giro;
  final Color color;
  final double grosor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(grosor / 2);
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = grosor
      ..color = color;
    canvas.drawArc(rect, giro.value * 2 * math.pi, math.pi * 1.5, false, pincel);
  }

  @override
  bool shouldRepaint(_PintorSpinner old) => old.color != color || old.grosor != grosor;
}
