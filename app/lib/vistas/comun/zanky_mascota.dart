import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';

/// Cómo se siente Zanky. Cambia la cara, las cejas y los brazos.
enum Animo { feliz, curioso, preocupado, celebrando }

/// Zanky: un mangle rojo chiquito que camina sobre sus raíces en zancos (como los
/// zanqueros del Carnaval de Barranquilla), con su corona de hojas y la faja de colores.
///
/// Todo está dibujado en código: se ve nítido a cualquier tamaño, pesa nada y se anima
/// por partes (parpadeo, respiración, balanceo, hojas, mirada, salto al tocarlo).
class ZankyMascota extends StatefulWidget {
  const ZankyMascota({super.key, this.tamano = 160, this.animo = Animo.feliz, this.onTap, this.mirar});

  final double tamano;
  final Animo animo;
  final VoidCallback? onTap;

  /// Hacia dónde mira, de -1 a 1 en cada eje (null: mira al frente y a veces curiosea).
  final Offset? mirar;

  @override
  State<ZankyMascota> createState() => _ZankyMascotaState();
}

class _ZankyMascotaState extends State<ZankyMascota> with TickerProviderStateMixin {
  /// Reloj continuo para lo que respira (balanceo, hojas, agua). 6 s por vuelta.
  late final AnimationController _vida = AnimationController(vsync: this, duration: const Duration(seconds: 6))
    ..repeat();

  /// Parpadeo: 140 ms, cada 2,5-5 s al azar (un ritmo fijo se nota robótico).
  late final AnimationController _parpado = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );

  /// Salto al tocarlo: resorte con algo de rebote, se siente vivo.
  late final AnimationController _salto = AnimationController.unbounded(vsync: this);

  final _azar = math.Random();
  Offset _mirada = Offset.zero;
  Offset? _toque;

  @override
  void initState() {
    super.initState();
    _programarParpadeo();
  }

  void _programarParpadeo() {
    Future.delayed(Duration(milliseconds: 2500 + _azar.nextInt(2500)), () async {
      if (!mounted) return;
      await _parpado.forward();
      if (!mounted) return;
      await _parpado.reverse();
      // A veces parpadea dos veces seguidas, como la gente.
      if (mounted && _azar.nextDouble() < 0.18) {
        await _parpado.forward();
        if (mounted) await _parpado.reverse();
      }
      // Y de vez en cuando mira para un lado, curioso.
      if (mounted && widget.mirar == null && _toque == null) {
        setState(
          () => _mirada = _azar.nextDouble() < 0.4
              ? Offset(_azar.nextDouble() * 1.6 - 0.8, _azar.nextDouble() * 0.6 - 0.2)
              : Offset.zero,
        );
      }
      _programarParpadeo();
    });
  }

  void _saltar() {
    _salto.value = 0;
    _salto.animateWith(
      SpringSimulation(
        SpringDescription.withDampingRatio(mass: 1, stiffness: 260, ratio: 0.38),
        0,
        0,
        -9, // impulso hacia arriba
      ),
    );
  }

  @override
  void dispose() {
    _vida.dispose();
    _parpado.dispose();
    _salto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quieto = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final ancho = widget.tamano, alto = widget.tamano * 1.2;
    final dibujo = RepaintBoundary(
      child: SizedBox(
        width: ancho,
        height: alto,
        child: AnimatedBuilder(
          animation: Listenable.merge([_vida, _parpado, _salto]),
          builder: (context, _) => CustomPaint(
            // Tamaño fijo pase lo que pase con el padre.
            size: Size(ancho, alto),
            willChange: true,
            painter: _PintorZanky(
              t: quieto ? 0 : _vida.value,
              parpado: _parpado.value,
              salto: _salto.value,
              animo: widget.animo,
              mirada: _toque ?? widget.mirar ?? _mirada,
            ),
          ),
        ),
      ),
    );
    return Semantics(
      label: 'Zanky, el guardián del manglar',
      button: widget.onTap != null,
      child: Listener(
        // La mirada sigue al dedo mientras toca.
        onPointerDown: (e) => setState(() => _toque = _normalizar(e.localPosition, ancho, alto)),
        onPointerMove: (e) => setState(() => _toque = _normalizar(e.localPosition, ancho, alto)),
        onPointerUp: (_) => setState(() => _toque = null),
        onPointerCancel: (_) => setState(() => _toque = null),
        child: Presionable(
          escala: 0.94,
          vibracion: Vibracion.ligera,
          onTap: () {
            _saltar();
            widget.onTap?.call();
          },
          child: dibujo,
        ),
      ),
    );
  }

  static Offset _normalizar(Offset p, double w, double h) =>
      Offset(((p.dx / w) * 2 - 1).clamp(-1.0, 1.0), ((p.dy / h) * 2 - 1).clamp(-1.0, 1.0));
}

class _PintorZanky extends CustomPainter {
  _PintorZanky({
    required this.t,
    required this.parpado,
    required this.salto,
    required this.animo,
    required this.mirada,
  });

  final double t; // 0..1 vuelta de vida
  final double parpado; // 0 abierto .. 1 cerrado
  final double salto; // desplazamiento del resorte (negativo = arriba)
  final Animo animo;
  final Offset mirada;

  static const _tronco = Color(0xFF8B3A2B); // corteza del mangle rojo (paleta de handoff/08)
  static const _troncoOscuro = Color(0xFF632519);
  static const _raiz = Color(0xFF6D3B2A);
  // Cintas del Carnaval de Barranquilla enrolladas en las raíces: amarillo, rojo y verde.
  static const _carnaval = [Color(0xFFF9C80E), Color(0xFFE63946), Color(0xFF2A9D8F)];

  @override
  void paint(Canvas canvas, Size size) {
    // Lienzo de diseño 200 × 240, escalado para CABER en la caja (no solo por el ancho:
    // si un padre lo estira, Zanky no se sale de su espacio) y centrado en ella.
    final s = math.min(size.width / 200, size.height / 240);
    canvas.translate((size.width - 200 * s) / 2, (size.height - 240 * s) / 2);
    canvas.scale(s);
    final w = 2 * math.pi * t;
    final celebra = animo == Animo.celebrando;

    // Respirar y balancearse (más vivo si celebra).
    final respira = math.sin(w * 2) * (celebra ? 0.03 : 0.014);
    final balanceo = math.sin(w) * (celebra ? 0.07 : 0.035);
    final dy = salto * 4.2; // el resorte ya trae el rebote

    _agua(canvas, w, dy);

    canvas.save();
    canvas.translate(100, 214 + dy * 0.25);
    canvas.rotate(balanceo * 0.4);
    canvas.translate(-100, -214);
    _raices(canvas, w);

    canvas.translate(100, 150 + dy);
    canvas.rotate(balanceo);
    canvas.scale(1 - respira * 0.5, 1 + respira);
    canvas.translate(-100, -150);

    _brazos(canvas, w);
    _cuerpo(canvas);
    _corona(canvas, w);
    _cara(canvas, w);
    canvas.restore();
  }

  void _agua(Canvas canvas, double w, double dy) {
    // Sombra que se achica cuando salta.
    final alto = (-dy).clamp(0.0, 40.0) / 40;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 226), width: 120 * (1 - alto * 0.35), height: 14 * (1 - alto * 0.3)),
      Paint()..color = const Color(0xFF0B2E24).withValues(alpha: 0.16 * (1 - alto * 0.5)),
    );
    // Dos ondas en el agua, desfasadas.
    final onda = Paint()
      ..color = Zc.cienaga.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final fase = (t + i * 0.5) % 1;
      final r = 40 + fase * 40;
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(100, 226), width: r * 2, height: r * 0.34),
        math.pi * 0.08,
        math.pi * 0.84,
        false,
        onda..color = Zc.cienaga.withValues(alpha: 0.32 * (1 - fase)),
      );
    }
  }

  void _raices(Canvas canvas, double w) {
    final p = Paint()
      ..color = _raiz
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Cuatro zancos en arco, del cuerpo al agua. Se mecen un pelo, cada uno a su ritmo.
    const pies = [44.0, 76.0, 124.0, 156.0];
    for (var i = 0; i < pies.length; i++) {
      final x = pies[i];
      final mece = math.sin(w + i) * 1.5;
      final salida = 100 + (x - 100) * 0.32;
      final path = Path()
        ..moveTo(salida, 170)
        ..cubicTo(salida + (x - 100) * 0.5, 176, x + mece, 192, x + mece, 222);
      final grosor = (i == 0 || i == 3) ? 7.0 : 8.5;
      canvas.drawPath(path, p..strokeWidth = grosor);
      // Cintas: franjas cortas en diagonal que recorren el zanco, alternando colores.
      final metrica = path.computeMetrics().first;
      var k = i;
      for (var d = metrica.length * 0.18; d < metrica.length * 0.86; d += 7.5) {
        final t = metrica.getTangentForOffset(d)!;
        final normal = Offset(-t.vector.dy, t.vector.dx);
        final c = t.position;
        final a = c + normal * (grosor * 0.55) + t.vector * 2.2;
        final b = c - normal * (grosor * 0.55) - t.vector * 2.2;
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = _carnaval[k++ % _carnaval.length]
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round,
        );
      }
      // Puntica que entra al fango.
      canvas.drawCircle(Offset(x + mece, 222), 3.6, Paint()..color = _troncoOscuro);
    }
  }

  void _cuerpo(Canvas canvas) {
    final cuerpo = RRect.fromRectAndCorners(
      const Rect.fromLTWH(56, 70, 88, 108),
      topLeft: const Radius.circular(46),
      topRight: const Radius.circular(46),
      bottomLeft: const Radius.circular(34),
      bottomRight: const Radius.circular(34),
    );
    canvas.drawRRect(
      cuerpo,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB8653F), _tronco, _troncoOscuro],
          stops: [0, 0.55, 1],
        ).createShader(cuerpo.outerRect),
    );
    // Barriga más clara: le da volumen y deja leer la cara.
    canvas.drawOval(
      const Rect.fromLTWH(70, 96, 60, 70),
      Paint()..color = const Color(0xFFE9B48E).withValues(alpha: 0.5),
    );
    // Vetas de la corteza.
    final veta = Paint()
      ..color = _troncoOscuro.withValues(alpha: 0.35)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(64, 120), const Offset(66, 146), veta);
    canvas.drawLine(const Offset(136, 116), const Offset(134, 140), veta);
  }

  void _brazos(Canvas canvas, double w) {
    final arriba = animo == Animo.celebrando;
    final p = Paint()
      ..color = _tronco
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    for (final lado in const [-1.0, 1.0]) {
      final saluda = arriba ? math.sin(w * 6 + (lado > 0 ? 0 : math.pi)) * 0.25 : math.sin(w * 2) * 0.05;
      canvas.save();
      canvas.translate(100 + lado * 40, 128);
      canvas.rotate(lado * (arriba ? -1.9 : -0.5) + saluda * lado);
      final brazo = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(lado * 14, 10, lado * 26, 6);
      canvas.drawPath(brazo, p);
      // Mano de hojita.
      canvas.save();
      canvas.translate(lado * 28, 5);
      canvas.rotate(lado * 0.6);
      _hoja(canvas, 11, 6.5, Zc.hoja);
      canvas.restore();
      canvas.restore();
    }
  }

  void _corona(Canvas canvas, double w) {
    // Cinco hojas en abanico + un propágulo que cuelga: así se reconoce el mangle rojo.
    const angulos = [-1.05, -0.52, 0.0, 0.52, 1.05];
    const colores = [Color(0xFF2E7D32), Color(0xFF43A047), Color(0xFF4CAF50), Color(0xFF43A047), Color(0xFF2E7D32)];
    for (var i = 0; i < angulos.length; i++) {
      final susurro = math.sin(w * 2 + i * 0.9) * 0.06;
      canvas.save();
      canvas.translate(100, 78);
      canvas.rotate(angulos[i] + susurro);
      canvas.translate(0, -26);
      _hoja(canvas, 34, 17, colores[i]);
      canvas.restore();
    }
    // Propágulo: la semilla larga que flota y echa raíz donde llega.
    final mece = math.sin(w * 2) * 2.2;
    final pr = Paint()
      ..color = const Color(0xFF6E8B3D)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(136, 82), Offset(146 + mece, 108), pr);
    canvas.drawCircle(Offset(146 + mece, 109), 2.6, Paint()..color = const Color(0xFF4F6A2A));
  }

  void _hoja(Canvas canvas, double largo, double ancho, Color color) {
    final hoja = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(ancho, -largo * 0.45, 0, -largo)
      ..quadraticBezierTo(-ancho, -largo * 0.45, 0, 0)
      ..close();
    canvas.drawPath(hoja, Paint()..color = color);
    canvas.drawLine(
      Offset.zero,
      Offset(0, -largo * 0.82),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..strokeWidth = 1.2,
    );
  }

  void _cara(Canvas canvas, double w) {
    final ojoY = 112.0;
    final mx = mirada.dx * 3.4, my = mirada.dy * 2.6;
    final feliz = animo == Animo.celebrando;

    // Mejillas.
    final mejilla = Paint()..color = const Color(0xFFF2A33A).withValues(alpha: 0.42);
    canvas.drawOval(Rect.fromCenter(center: const Offset(74, 132), width: 16, height: 9), mejilla);
    canvas.drawOval(Rect.fromCenter(center: const Offset(126, 132), width: 16, height: 9), mejilla);

    for (final x in const [82.0, 118.0]) {
      if (feliz) {
        // Ojos felices «^ ^».
        final arco = Path()
          ..moveTo(x - 8, ojoY + 3)
          ..quadraticBezierTo(x, ojoY - 8, x + 8, ojoY + 3);
        canvas.drawPath(
          arco,
          Paint()
            ..color = Zc.raiz
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.6
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }
      final abierto = 1 - parpado;
      final ojo = Rect.fromCenter(center: Offset(x, ojoY), width: 19, height: 23 * math.max(abierto, 0.08));
      canvas.drawOval(ojo, Paint()..color = Colors.white);
      if (abierto > 0.25) {
        canvas.save();
        canvas.clipPath(Path()..addOval(ojo));
        canvas.drawCircle(Offset(x + mx, ojoY + my + 1), 6.4, Paint()..color = Zc.raiz);
        canvas.drawCircle(Offset(x + mx + 2.2, ojoY + my - 1.8), 2.1, Paint()..color = Colors.white);
        canvas.restore();
      } else {
        canvas.drawLine(
          Offset(x - 8, ojoY),
          Offset(x + 8, ojoY),
          Paint()
            ..color = Zc.raiz
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Cejas: dicen el ánimo antes que la boca.
    final ceja = Paint()
      ..color = _troncoOscuro
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final inclinacion = switch (animo) {
      Animo.preocupado => 4.0,
      Animo.curioso => -2.0,
      _ => 0.0,
    };
    final sube = animo == Animo.curioso ? -3.0 : 0.0;
    canvas.drawLine(Offset(74, 95 - inclinacion + sube), Offset(89, 95 + inclinacion * 0.3), ceja);
    canvas.drawLine(
      Offset(111, 95 + inclinacion * 0.3 + (animo == Animo.curioso ? 0 : 0)),
      Offset(126, 95 - inclinacion),
      ceja,
    );

    // Boca.
    final boca = Paint()
      ..color = Zc.raiz
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    switch (animo) {
      case Animo.feliz:
        canvas.drawPath(
          Path()
            ..moveTo(90, 136)
            ..quadraticBezierTo(100, 145, 110, 136),
          boca,
        );
      case Animo.celebrando:
        final b = Path()
          ..moveTo(86, 133)
          ..quadraticBezierTo(100, 152, 114, 133)
          ..close();
        canvas.drawPath(b, Paint()..color = Zc.raiz);
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(100, 143), width: 12, height: 5),
          Paint()..color = const Color(0xFFE06B6B),
        );
      case Animo.curioso:
        canvas.drawOval(Rect.fromCenter(center: const Offset(102, 139), width: 9, height: 10), boca);
      case Animo.preocupado:
        canvas.drawPath(
          Path()
            ..moveTo(91, 142)
            ..quadraticBezierTo(100, 135, 109, 142),
          boca,
        );
    }
  }

  @override
  bool shouldRepaint(_PintorZanky o) =>
      o.t != t || o.parpado != parpado || o.salto != salto || o.animo != animo || o.mirada != mirada;
}
