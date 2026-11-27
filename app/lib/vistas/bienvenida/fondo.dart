import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../nucleo/base/movimiento.dart';
import '../../nucleo/tema.dart';

/// Fondo de la bienvenida: un degradado suave (hoja clara arriba, arena abajo), un
/// resplandor de sol en una esquina y, al pie, tres capas de agua de la ciénaga que se
/// mueven despacio. Todo el movimiento vive en un solo [CustomPainter] dentro de un
/// [RepaintBoundary]: el resto de la pantalla no se repinta por culpa de las ondas.
///
/// Con «reducir movimiento» las ondas quedan quietas en una forma bonita.
class FondoBienvenida extends StatefulWidget {
  const FondoBienvenida({super.key});

  @override
  State<FondoBienvenida> createState() => _FondoBienvenidaState();
}

class _FondoBienvenidaState extends State<FondoBienvenida> with SingleTickerProviderStateMixin {
  /// Una vuelta completa: 16 s. Cada capa da 1 o 2 vueltas enteras por ciclo, así el
  /// bucle no se nota en ningún punto.
  late final AnimationController _reloj = AnimationController(vsync: this, duration: const Duration(seconds: 16));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.animationsDisabled) {
      _reloj
        ..stop()
        ..value = 0.18;
    } else if (!_reloj.isAnimating) {
      _reloj.repeat();
    }
  }

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Zc.hojaClara, Zc.arena],
                stops: [0.0, 0.62],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.95, -0.92),
                radius: 0.85,
                colors: [Color(0x99FDEED6), Color(0x00FDEED6)],
              ),
            ),
          ),
          RepaintBoundary(
            child: SizedBox.expand(child: CustomPaint(painter: _PintorOndas(_reloj))),
          ),
        ],
      ),
    );
  }
}

class _Capa {
  const _Capa(this.altura, this.amplitud, this.largo, this.vueltas, this.desfase, this.color);

  /// Qué fracción del alto de la pantalla ocupa desde abajo.
  final double altura;
  final double amplitud;

  /// Longitud de onda como fracción del ancho.
  final double largo;

  /// Vueltas enteras por ciclo (negativa: va hacia el otro lado).
  final int vueltas;
  final double desfase;
  final Color color;
}

class _PintorOndas extends CustomPainter {
  _PintorOndas(this.reloj) : super(repaint: reloj);

  final Animation<double> reloj;

  static final _capas = [
    _Capa(0.165, 9, 1.15, 1, 0.0, Zc.cienaga.withValues(alpha: 0.09)),
    _Capa(0.125, 12, 0.8, -1, 2.1, Zc.cienaga.withValues(alpha: 0.13)),
    _Capa(0.085, 10, 1.45, 2, 4.0, Zc.cienaga.withValues(alpha: 0.17)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    for (var i = 0; i < _capas.length; i++) {
      final c = _capas[i];
      final fase = 2 * math.pi * reloj.value * c.vueltas + c.desfase;
      final base = h * (1 - c.altura);
      double y(double x) => base + c.amplitud * math.sin(2 * math.pi * x / (w * c.largo) + fase);

      final cresta = Path()..moveTo(0, y(0));
      for (var x = 8.0; x < w; x += 8) {
        cresta.lineTo(x, y(x));
      }
      cresta.lineTo(w, y(w));

      final relleno = Path.from(cresta)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(relleno, Paint()..color = c.color);
      if (i == 1) {
        canvas.drawPath(
          cresta,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = Colors.white.withValues(alpha: 0.5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PintorOndas old) => old.reloj != reloj;
}
