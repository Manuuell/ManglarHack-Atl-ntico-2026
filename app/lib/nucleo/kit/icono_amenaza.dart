import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../datos/tipos.dart';
import '../identidad.dart';
import '../presionable.dart';
import '../tema.dart';

// ============================================================================
// Íconos propios de las amenazas al manglar
// ============================================================================
//
// Ocho dibujos hechos a mano con `CustomPainter` (sin paquetes ni SVG), en una
// rejilla de 24 × 24 que se escala a cualquier tamaño. Todos comparten gramática:
//
// - Duotono: trazo oscuro (el color del tipo mezclado con el azul CRA), relleno en
//   el color del tipo o en su versión clara, y el dorado CRA como único acento.
// - Mismo peso óptico: trazo de 1,7 con puntas y uniones redondeadas, y casi todos
//   apoyados en la misma línea de agua, que es lo que los hace «del manglar».
// - Monocromo opcional ([IconoAmenaza.color]) para ir encima de un disco de color
//   (marcadores del mapa, encabezados).
//
// La microanimación dura 560 ms, corre una sola vez al aparecer y al tocar, y
// termina siempre en la pose de reposo. Con «reducir movimiento» no se mueve.

/// Ícono dibujado de un [TipoAmenaza].
///
/// - [animado]: rebota con resorte y hace su gesto (la llama titila, la gota cae,
///   el hacha golpea…) al aparecer y al tocarlo.
/// - [disparo]: si cambia entre dos construcciones, el gesto se repite (sirve
///   cuando el toque lo recibe un ancestro, p. ej. al elegir una tarjeta).
/// - [color]: dibuja todo en un solo color.
class IconoAmenaza extends StatefulWidget {
  const IconoAmenaza(
    this.tipo, {
    super.key,
    this.tamano = 24,
    this.animado = false,
    this.disparo,
    this.color,
    this.etiqueta,
  });

  final TipoAmenaza tipo;
  final double tamano;
  final bool animado;
  final Object? disparo;
  final Color? color;

  /// Texto para el lector de pantalla. Sin él, el ícono es decorativo.
  final String? etiqueta;

  /// Lo que dura el gesto completo (rebote incluido).
  static const duracion = Duration(milliseconds: 560);

  @override
  State<IconoAmenaza> createState() => IconoAmenazaEstado();
}

class IconoAmenazaEstado extends State<IconoAmenaza> with SingleTickerProviderStateMixin {
  // Solo los íconos animados piden un reloj (los marcadores del mapa no gastan).
  // En reposo vale 1: el pintor dibuja la pose final.
  AnimationController? _t;

  AnimationController _reloj() =>
      _t ??= AnimationController(vsync: this, duration: IconoAmenaza.duracion, value: 1);

  bool get _quieto => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    if (widget.animado) {
      _reloj();
      WidgetsBinding.instance.addPostFrameCallback((_) => reproducir());
    }
  }

  @override
  void didUpdateWidget(IconoAmenaza oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animado) _reloj();
    if (widget.animado && oldWidget.disparo != widget.disparo) reproducir();
  }

  @override
  void dispose() {
    _t?.dispose();
    super.dispose();
  }

  /// Corre el gesto una vez (si el sistema no pide reducir movimiento).
  void reproducir() {
    final t = _t;
    if (!mounted || t == null) return;
    if (_quieto) {
      t.value = 1;
      return;
    }
    t.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final tintas = _Tintas.de(widget.tipo, widget.color);
    Widget dibujo = CustomPaint(
      size: Size.square(widget.tamano),
      painter: _PintorAmenaza(widget.tipo, tintas, _t ?? const AlwaysStoppedAnimation(1.0)),
    );
    if (widget.animado) {
      // Listener no entra en la arena de gestos: el toque sigue llegando al botón
      // que envuelve al ícono.
      dibujo = Listener(onPointerDown: (_) => reproducir(), child: RepaintBoundary(child: dibujo));
    }
    final etiqueta = widget.etiqueta;
    return etiqueta == null
        ? ExcludeSemantics(child: dibujo)
        : Semantics(label: etiqueta, image: true, excludeSemantics: true, child: dibujo);
  }
}

/// Ficha del «Reporte rápido»: fondo suave del color del tipo, ícono animado y
/// etiqueta. Se hunde con resorte al presionar y vibra suave.
class FichaAmenaza extends StatefulWidget {
  const FichaAmenaza({super.key, required this.tipo, required this.alTocar, this.ancho = 86});

  final TipoAmenaza tipo;
  final VoidCallback alTocar;
  final double ancho;

  @override
  State<FichaAmenaza> createState() => _FichaAmenazaState();
}

class _FichaAmenazaState extends State<FichaAmenaza> {
  final _icono = GlobalKey<IconoAmenazaEstado>();

  @override
  Widget build(BuildContext context) {
    final t = widget.tipo;
    final tt = Theme.of(context).textTheme;
    return Listener(
      onPointerDown: (_) => _icono.currentState?.reproducir(),
      child: Presionable(
        escala: 0.93,
        vibracion: Vibracion.ligera,
        etiqueta: 'Reportar ${t.nombre}',
        onTap: widget.alTocar,
        child: Container(
          width: widget.ancho,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: Color.lerp(Colors.white, t.color, 0.06),
            borderRadius: BorderRadius.circular(Zr.m),
            border: Border.all(color: t.color.withValues(alpha: 0.20)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: t.color.withValues(alpha: 0.13), shape: BoxShape.circle),
                child: Center(child: IconoAmenaza(t, key: _icono, tamano: 32, animado: true)),
              ),
              const SizedBox(height: 6),
              Text(
                t.corto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pintura
// ---------------------------------------------------------------------------

@immutable
class _Tintas {
  const _Tintas(this.trazo, this.lleno, this.claro, this.acento, this.agua);

  /// Duotono: color del tipo + azul CRA para el trazo, dorado CRA de acento.
  /// Monocromo: todo en [mono], con el relleno claro translúcido.
  factory _Tintas.de(TipoAmenaza tipo, Color? mono) {
    if (mono != null) {
      final suave = mono.withValues(alpha: mono.a * 0.38);
      return _Tintas(mono, mono, suave, mono, mono);
    }
    return _Tintas(
      Color.lerp(tipo.color, Cra.azul, 0.45)!,
      tipo.color,
      Color.lerp(tipo.color, Colors.white, 0.66)!,
      Cra.dorado,
      Zc.cienaga,
    );
  }

  final Color trazo;
  final Color lleno;
  final Color claro;
  final Color acento;
  final Color agua;

  @override
  bool operator ==(Object o) =>
      o is _Tintas && o.trazo == trazo && o.lleno == lleno && o.claro == claro && o.acento == acento && o.agua == agua;

  @override
  int get hashCode => Object.hash(trazo, lleno, claro, acento, agua);
}

/// Pinta un tipo en la rejilla de 24 × 24. [t] va de 0 a 1 durante el gesto y
/// vale 1 en reposo.
class _PintorAmenaza extends CustomPainter {
  _PintorAmenaza(this.tipo, this._k, this.t) : super(repaint: t);

  final TipoAmenaza tipo;
  final _Tintas _k;
  final Animation<double> t;

  static const _grosor = 1.7;

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value.clamp(0.0, 1.0);
    final lado = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - lado) / 2, (size.height - lado) / 2);
    canvas.scale(lado / 24);
    // Rebote con física de resorte amortiguado: 0,82 → 1,07 → 1.
    if (v < 1) {
      final s = 1 - 0.18 * math.exp(-6 * v) * math.cos(14 * v);
      canvas.translate(12, 13);
      canvas.scale(s);
      canvas.translate(-12, -13);
    }
    switch (tipo) {
      case TipoAmenaza.tala:
        _tala(canvas, v);
      case TipoAmenaza.quema:
        _quema(canvas, v);
      case TipoAmenaza.relleno:
        _tierra(canvas, v);
      case TipoAmenaza.vertimiento:
        _vertimiento(canvas, v);
      case TipoAmenaza.canoTaponado:
        _cano(canvas, v);
      case TipoAmenaza.fauna:
        _garza(canvas, v);
      case TipoAmenaza.basuras:
        _basura(canvas, v);
      case TipoAmenaza.otro:
        _otro(canvas, v);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorAmenaza old) => old.tipo != tipo || old._k != _k || old.t != t;

  // --- utilidades -----------------------------------------------------------

  Paint _linea(Color c, [double w = _grosor]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = c;

  Paint _pintura(Color c) => Paint()..color = c;

  /// Figura con relleno y contorno.
  void _figura(Canvas c, Path p, Color relleno, [double w = _grosor]) {
    c.drawPath(p, _pintura(relleno));
    c.drawPath(p, _linea(_k.trazo, w));
  }

  /// Línea de agua ondulada: el suelo común de la familia.
  static Path _ola(double x0, double x1, double y, {double a = 0.85, double paso = 4}) {
    final p = Path()..moveTo(x0, y);
    var x = x0;
    var arriba = true;
    while (x < x1 - 0.01) {
      final nx = math.min(x + paso / 2, x1);
      p.quadraticBezierTo((x + nx) / 2, y + (arriba ? -a : a), nx, y);
      x = nx;
      arriba = !arriba;
    }
    return p;
  }

  static Path _gota(double cx, double cy, double r) => Path()
    ..moveTo(cx, cy - 1.45 * r)
    ..cubicTo(cx + 0.5 * r, cy - 0.7 * r, cx + r, cy - 0.15 * r, cx + r, cy + 0.45 * r)
    ..cubicTo(cx + r, cy + 1.05 * r, cx + 0.55 * r, cy + 1.45 * r, cx, cy + 1.45 * r)
    ..cubicTo(cx - 0.55 * r, cy + 1.45 * r, cx - r, cy + 1.05 * r, cx - r, cy + 0.45 * r)
    ..cubicTo(cx - r, cy - 0.15 * r, cx - 0.5 * r, cy - 0.7 * r, cx, cy - 1.45 * r)
    ..close();

  /// Oscilación que se apaga: 0 al empezar y al terminar.
  static double _vaiven(double v, double vueltas) => math.sin(v * math.pi * vueltas) * (1 - v);

  // --- tala: tocón con anillos y hacha que golpea ----------------------------

  void _tala(Canvas c, double v) {
    c.drawPath(_ola(1.5, 22.5, 21.2), _linea(_k.agua, 1.5));
    final tronco = Path()
      ..moveTo(4.5, 11)
      ..lineTo(4.5, 17)
      ..quadraticBezierTo(4.4, 19.1, 2.6, 20)
      ..lineTo(14.4, 20)
      ..quadraticBezierTo(12.6, 19.1, 12.5, 17)
      ..lineTo(12.5, 11)
      ..close();
    _figura(c, tronco, _k.lleno);
    // Raíz central del mangle.
    c.drawLine(const Offset(8.5, 16.6), const Offset(8.5, 19.6), _linea(_k.claro, 1.2));
    final tapa = Rect.fromCenter(center: const Offset(8.5, 11), width: 8, height: 3.4);
    _figura(c, Path()..addOval(tapa), _k.claro);
    c.drawOval(Rect.fromCenter(center: const Offset(8.5, 11), width: 3.6, height: 1.4), _linea(_k.trazo, 1.1));

    // Hacha: gira sobre el extremo del mango. Atrás, golpe, rebote corto.
    double giro;
    if (v < 0.3) {
      giro = 0.55 * Curves.easeOut.transform(v / 0.3);
    } else if (v < 0.42) {
      final u = (v - 0.3) / 0.12;
      giro = 0.55 * (1 - u * u);
    } else {
      final u = (v - 0.42) / 0.58;
      giro = -0.07 * math.sin(u * math.pi * 3) * (1 - u);
    }
    // Astillas al golpear.
    if (v > 0.42 && v < 0.9) {
      final u = (v - 0.42) / 0.48;
      final a = _pintura(_k.acento.withValues(alpha: _k.acento.a * (1 - u)));
      const base = Offset(12.6, 10.2);
      for (final d in const [Offset(-1.5, -4.2), Offset(1.6, -4.6), Offset(-4, -2.2)]) {
        c.drawCircle(base + d * Curves.easeOut.transform(u), 0.75, a);
      }
    }
    c.save();
    c.translate(19.6, 19.6);
    c.rotate(-0.47 + giro);
    c.drawLine(Offset.zero, const Offset(0, -10.4), _linea(_k.trazo, 1.9));
    final hoja = Path()
      ..moveTo(0.7, -11.4)
      ..lineTo(-2.6, -12.2)
      ..quadraticBezierTo(-4.3, -9.9, -2.8, -7.4)
      ..lineTo(0.7, -8.4)
      ..close();
    _figura(c, hoja, _k.acento, 1.4);
    c.restore();
  }

  // --- fuego: llama sobre raíces de mangle -----------------------------------

  void _quema(Canvas c, double v) {
    final raices = _linea(_k.trazo, 1.6);
    c.drawPath(
      Path()
        ..moveTo(12, 17.6)
        ..quadraticBezierTo(7.6, 18, 5.6, 21.6)
        ..moveTo(12, 17.6)
        ..quadraticBezierTo(16.4, 18, 18.4, 21.6)
        ..moveTo(12, 17.6)
        ..lineTo(12, 21.6),
      raices,
    );
    c.drawPath(_ola(2, 22, 21.8, a: 0.6), _linea(_k.agua, 1.3));

    final sy = 1 + 0.15 * _vaiven(v, 5);
    final sx = 1 - 0.07 * _vaiven(v, 5);
    c.save();
    c.translate(12, 18);
    c.scale(sx, sy);
    c.translate(-12, -18);
    final llama = Path()
      ..moveTo(12, 2.6)
      ..cubicTo(14.6, 6, 18, 8.6, 18, 12.6)
      ..cubicTo(18, 15.9, 15.3, 18, 12, 18)
      ..cubicTo(8.7, 18, 6, 15.9, 6, 12.6)
      ..cubicTo(6, 10.2, 7.3, 8.6, 8.5, 7.3)
      ..cubicTo(8.8, 9, 9.6, 10, 10.6, 10.4)
      ..cubicTo(10.2, 7.6, 11, 4.9, 12, 2.6)
      ..close();
    _figura(c, llama, _k.lleno);
    final dx = 0.8 * _vaiven(v, 4);
    final nucleo = Path()
      ..moveTo(12 + dx, 9.6)
      ..cubicTo(13.6 + dx, 11.4, 15, 12.6, 15, 14.6)
      ..cubicTo(15, 16.4, 13.6, 17.4, 12, 17.4)
      ..cubicTo(10.4, 17.4, 9, 16.4, 9, 14.6)
      ..cubicTo(9, 12.8, 10.6, 11.8, 12 + dx, 9.6)
      ..close();
    c.drawPath(nucleo, _pintura(_k.acento));
    c.restore();
  }

  // --- relleno: montículo de tierra sobre el agua y pala --------------------

  void _tierra(Canvas c, double v) {
    // Terrones que caen y el montículo que crece al recibirlos.
    var crece = 1.0;
    if (v < 0.45) {
      final u = v / 0.45;
      final y = 1.5 + 8.5 * u * u;
      final a = _pintura(_k.lleno);
      c.drawCircle(Offset(8, y), 1.1, a);
      c.drawCircle(Offset(11.6, y - 2.2), 0.9, a);
    } else if (v < 0.8) {
      crece = 1 + 0.09 * math.sin(math.pi * (v - 0.45) / 0.35);
    }
    c.save();
    c.translate(10, 18.4);
    c.scale(1, crece);
    c.translate(-10, -18.4);
    final monte = Path()
      ..moveTo(2.2, 18.4)
      ..quadraticBezierTo(4.8, 10.4, 10, 9.9)
      ..quadraticBezierTo(15.2, 10.4, 17.8, 18.4)
      ..close();
    _figura(c, monte, _k.lleno);
    final esc = _pintura(_k.claro);
    c.drawCircle(const Offset(7, 15.4), 1, esc);
    c.drawCircle(const Offset(11, 13.4), 0.85, esc);
    c.drawCircle(const Offset(12.8, 16.2), 1, esc);
    c.restore();
    c.drawPath(_ola(1.5, 22.5, 19.8), _linea(_k.agua, 1.5));

    // Pala clavada.
    c.drawLine(const Offset(20.6, 3.4), const Offset(15.8, 12.2), _linea(_k.trazo, 1.9));
    c.drawLine(const Offset(19.4, 2.8), const Offset(21.8, 4.1), _linea(_k.trazo, 1.9));
    final hoja = Path()
      ..moveTo(17.5, 13.2)
      ..lineTo(14.2, 11.4)
      ..quadraticBezierTo(13.1, 13.9, 13.8, 15.9)
      ..quadraticBezierTo(16, 15.6, 17.5, 13.2)
      ..close();
    _figura(c, hoja, _k.acento, 1.4);
  }

  // --- vertimiento: tubo que descarga en el agua ----------------------------

  void _vertimiento(Canvas c, double v) {
    c.drawPath(_ola(1.5, 22.5, 19.6), _linea(_k.agua, 1.5));
    // Mancha en el agua (anillo que se abre cuando cae la gota).
    final anillo = _linea(_k.lleno, 1.2);
    c.drawOval(Rect.fromCenter(center: const Offset(16, 21.4), width: 6, height: 1.6), anillo);
    if (v > 0.5) {
      final u = (v - 0.5) / 0.5;
      c.drawOval(
        Rect.fromCenter(center: const Offset(16, 21.4), width: 6 + 8 * u, height: 1.6 + 1.6 * u),
        _linea(_k.lleno.withValues(alpha: _k.lleno.a * (1 - u)), 1.2),
      );
    }
    final tubo = RRect.fromLTRBR(1.4, 5.4, 11, 10.2, const Radius.circular(1));
    _figura(c, Path()..addRRect(tubo), _k.claro);
    final boca = RRect.fromLTRBR(10.4, 4.4, 13.2, 11.2, const Radius.circular(1));
    _figura(c, Path()..addRRect(boca), _k.lleno);
    // Chorro que sale de la boca y se curva hacia abajo.
    final chorro = Path()
      ..moveTo(13.2, 6.4)
      ..quadraticBezierTo(16.8, 6.8, 17, 11.6)
      ..lineTo(15, 11.6)
      ..quadraticBezierTo(14.9, 9.2, 13.2, 9.2)
      ..close();
    _figura(c, chorro, _k.lleno, 1.3);
    // La gota: cae, desaparece en el agua y vuelve a formarse.
    if (v < 0.5) {
      final u = v / 0.5;
      _figura(c, _gota(16, 13.6 + 5.2 * u * u, 1.45), _k.lleno, 1.3);
    } else if (v > 0.72) {
      final u = Curves.easeOutBack.transform((v - 0.72) / 0.28);
      _figura(c, _gota(16, 15.4, 1.45 * u.clamp(0.0, 1.2)), _k.lleno, 1.3);
    }
  }

  // --- caño taponado: agua que se represa contra el sedimento ---------------

  void _cano(Canvas c, double v) {
    final orilla = _linea(_k.trazo, 1.7);
    c.drawPath(
      Path()
        ..moveTo(1.5, 5.6)
        ..quadraticBezierTo(6, 4, 11, 5.6)
        ..quadraticBezierTo(17, 7.2, 22.5, 5.6),
      orilla,
    );
    c.drawPath(
      Path()
        ..moveTo(1.5, 18.4)
        ..quadraticBezierTo(6, 20, 11, 18.4)
        ..quadraticBezierTo(17, 16.8, 22.5, 18.4),
      orilla,
    );
    // Agua represada del lado izquierdo.
    c.drawPath(
      Path()
        ..moveTo(2, 6.6)
        ..quadraticBezierTo(6, 5.4, 11, 6.7)
        ..lineTo(11, 17.3)
        ..quadraticBezierTo(6, 18.6, 2, 17.4)
        ..close(),
      _pintura(_k.claro),
    );
    final dx = 1.3 * _vaiven(v, 3);
    final ola = _linea(_k.lleno, 1.5);
    c.drawPath(_ola(2.4 + dx, 9.2 + dx, 10), ola);
    c.drawPath(_ola(2.4 + dx, 9.2 + dx, 14), ola);
    // Tapón de sedimento.
    final tiembla = 0.35 * _vaiven(v, 7);
    final tapon = Path()
      ..moveTo(10.6 + tiembla, 6.4)
      ..quadraticBezierTo(12.8, 5.6, 15.4 + tiembla, 6.6)
      ..quadraticBezierTo(16.4, 12, 15.4 + tiembla, 17.4)
      ..quadraticBezierTo(12.8, 18.4, 10.6 + tiembla, 17.6)
      ..quadraticBezierTo(9.6, 12, 10.6 + tiembla, 6.4)
      ..close();
    _figura(c, tapon, _k.acento);
    final grano = _pintura(_k.trazo);
    c.drawCircle(Offset(12.4 + tiembla, 9.6), 0.6, grano);
    c.drawCircle(Offset(13.9 + tiembla, 12.6), 0.6, grano);
    c.drawCircle(Offset(12.2 + tiembla, 15), 0.6, grano);
    // Del otro lado: fondo seco y agrietado.
    final grieta = _linea(_k.trazo, 1.2);
    c.drawPath(
      Path()
        ..moveTo(18, 9.4)
        ..lineTo(19.4, 11.2)
        ..lineTo(18.6, 13)
        ..moveTo(20.8, 12.6)
        ..lineTo(21.6, 14.4),
      grieta,
    );
  }

  // --- fauna: garza en el agua que mueve la cabeza --------------------------

  void _garza(Canvas c, double v) {
    final patas = _linea(_k.trazo, 1.4);
    c.drawLine(const Offset(9, 14.6), const Offset(9, 20.2), patas);
    c.drawLine(const Offset(11, 14.6), const Offset(11.9, 20.2), patas);
    c.drawPath(_ola(1.5, 22.5, 20.6), _linea(_k.agua, 1.5));
    final cuerpo = Path()
      ..moveTo(4.6, 12.6)
      ..quadraticBezierTo(7, 9, 12, 9.4)
      ..quadraticBezierTo(15.2, 9.8, 15, 12)
      ..quadraticBezierTo(14, 15, 9.6, 15)
      ..quadraticBezierTo(5.8, 15, 2.6, 16.6)
      ..quadraticBezierTo(3.6, 14.2, 4.6, 12.6)
      ..close();
    _figura(c, cuerpo, _k.claro);
    c.drawPath(
      Path()
        ..moveTo(7.2, 11.8)
        ..quadraticBezierTo(10, 13.2, 12.8, 11.6),
      _linea(_k.trazo, 1.1),
    );
    // Cuello y cabeza: se inclinan como si fuera a pescar y vuelven.
    final giro = 0.42 * math.sin(v * math.pi * 2.2) * math.pow(1 - v, 1.2);
    c.save();
    c.translate(13.4, 10.4);
    c.rotate(giro);
    c.translate(-13.4, -10.4);
    c.drawPath(
      Path()
        ..moveTo(13.4, 10.4)
        ..cubicTo(16.6, 8.8, 12.4, 6.6, 14.6, 4.8),
      _linea(_k.trazo, 1.8),
    );
    final pico = Path()
      ..moveTo(16.2, 3.8)
      ..lineTo(21.6, 5.2)
      ..lineTo(16.2, 5.6)
      ..close();
    _figura(c, pico, _k.acento, 1.1);
    _figura(c, Path()..addOval(Rect.fromCircle(center: const Offset(15.3, 4.6), radius: 1.45)), _k.claro, 1.4);
    c.drawCircle(const Offset(15.5, 4.3), 0.45, _pintura(_k.trazo));
    c.restore();
  }

  // --- basuras: botella flotando --------------------------------------------

  void _basura(Canvas c, double v) {
    final dy = 1.1 * _vaiven(v, 3);
    final giro = -0.32 + 0.2 * _vaiven(v, 3.2);
    c.save();
    c.translate(11.6, 12.6 + dy);
    c.rotate(giro);
    final botella = Path()
      ..addRRect(RRect.fromLTRBR(-7, -3, 3, 3, const Radius.circular(1.8)));
    _figura(c, botella, _k.claro);
    final cuello = Path()
      ..moveTo(3, -1.8)
      ..lineTo(5.2, -1.1)
      ..lineTo(5.2, 1.1)
      ..lineTo(3, 1.8);
    c.drawPath(cuello, _linea(_k.trazo, 1.5));
    _figura(c, Path()..addRRect(RRect.fromLTRBR(5.2, -1.4, 7.2, 1.4, const Radius.circular(0.5))), _k.acento, 1.3);
    c.drawRect(const Rect.fromLTRB(-4.2, -2.2, -1.2, 2.2), _pintura(_k.lleno));
    c.restore();
    // El agua por encima tapa la parte sumergida.
    final agua = _linea(_k.agua, 1.6);
    c.drawPath(_ola(1.5, 22.5, 15.8), agua);
    c.drawPath(_ola(5.5, 18.5, 19.8, a: 0.7), _linea(_k.agua.withValues(alpha: _k.agua.a * 0.6), 1.4));
  }

  // --- otro: globo de diálogo con signo amable ------------------------------

  void _otro(Canvas c, double v) {
    c.save();
    c.translate(12, 18);
    c.rotate(0.2 * _vaiven(v, 4));
    c.translate(-12, -18);
    final globo = Path()
      ..moveTo(7.6, 3.4)
      ..lineTo(16.4, 3.4)
      ..quadraticBezierTo(21, 3.4, 21, 8)
      ..lineTo(21, 11.8)
      ..quadraticBezierTo(21, 16.4, 16.4, 16.4)
      ..lineTo(11.6, 16.4)
      ..lineTo(6.6, 20.4)
      ..lineTo(7.4, 16.3)
      ..quadraticBezierTo(3, 16, 3, 11.8)
      ..lineTo(3, 8)
      ..quadraticBezierTo(3, 3.4, 7.6, 3.4)
      ..close();
    _figura(c, globo, _k.claro);
    c.drawPath(
      Path()
        ..moveTo(9.7, 8.2)
        ..quadraticBezierTo(9.9, 6.2, 12, 6.2)
        ..quadraticBezierTo(14.3, 6.2, 14.3, 8.1)
        ..quadraticBezierTo(14.3, 9.5, 12.7, 10.1)
        ..quadraticBezierTo(12, 10.4, 12, 11.4),
      _linea(_k.trazo, 1.8),
    );
    c.drawCircle(const Offset(12, 13.7), 1.15, _pintura(_k.acento));
    c.restore();
  }
}
