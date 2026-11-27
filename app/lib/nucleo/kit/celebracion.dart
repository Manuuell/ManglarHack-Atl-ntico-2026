import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../base/movimiento.dart';
import '../tema.dart';
import 'anuncio.dart';
import 'haptica.dart';

// ============================================================================
// ✓ dibujado
// ============================================================================

/// Círculo + ✓ que se **dibuja** una sola vez (≈0,4 s): el disco brota con
/// [AppMotion.emergente] y el trazo corre con [AppMotion.curvaTrazo].
///
/// - `conCirculo: true` (por defecto): disco de [color] con ✓ de [colorCheck].
/// - `conCirculo: false`: solo el ✓ en [color] (dentro de un botón, por ejemplo).
/// - Con «reducir movimiento» no hay trazo ni brote: el ✓ ya hecho aparece
///   con un fundido de [AppMotion.fast].
///
/// ```dart
/// const CheckDibujado(tamano: 72)                                   // éxito grande
/// CheckDibujado(tamano: 22, conCirculo: false, color: Colors.white) // dentro de un botón
/// CheckDibujado(alTerminar: () => Navigator.pop(context))
/// ```
///
/// Un solo controlador; el `CustomPainter` se repinta con `repaint:` y no hay
/// reconstrucciones por cuadro.
class CheckDibujado extends StatefulWidget {
  const CheckDibujado({
    super.key,
    this.tamano = 72,
    this.color = Zc.hoja,
    this.colorCheck = Colors.white,
    this.conCirculo = true,
    this.animar = true,
    this.etiqueta,
    this.alTerminar,
  });

  final double tamano;
  final Color color;

  /// Color del ✓ cuando hay disco.
  final Color colorCheck;
  final bool conCirculo;

  /// `false`: se pinta ya hecho, sin recorrido.
  final bool animar;

  /// Texto para el lector de pantalla. Nulo: el ✓ se esconde del lector (lo
  /// anuncia quien lo usa).
  final String? etiqueta;

  /// Se llama una vez cuando el trazo termina.
  final VoidCallback? alTerminar;

  @override
  State<CheckDibujado> createState() => _CheckDibujadoState();
}

class _CheckDibujadoState extends State<CheckDibujado> with SingleTickerProviderStateMixin {
  late final AnimationController _trazo = AnimationController(vsync: this, duration: AppMotion.trazoCheck);
  bool _reducido = false;
  bool _arrancado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducido = context.animationsDisabled;
    if (_arrancado) return;
    _arrancado = true;
    if (!widget.animar) {
      _trazo.value = 1;
      return;
    }
    _trazo.duration = _reducido ? AppMotion.fast : AppMotion.trazoCheck;
    _trazo.forward().whenComplete(() {
      if (mounted) widget.alTerminar?.call();
    });
  }

  @override
  void dispose() {
    _trazo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget dibujo = RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.tamano,
        child: CustomPaint(
          painter: _PintorCheck(
            progreso: _trazo,
            color: widget.color,
            colorCheck: widget.colorCheck,
            conCirculo: widget.conCirculo,
            reducido: _reducido,
          ),
        ),
      ),
    );
    if (_reducido) dibujo = FadeTransition(opacity: _trazo, child: dibujo);
    final etiqueta = widget.etiqueta;
    return etiqueta == null
        ? ExcludeSemantics(child: dibujo)
        : Semantics(label: etiqueta, image: true, child: ExcludeSemantics(child: dibujo));
  }
}

/// Traza el ✓ (dos segmentos) dentro de [rect] hasta [progreso] (0..1).
/// Lo comparten [CheckDibujado] y `CasillaIos`.
void trazarCheck(Canvas canvas, Rect rect, double progreso, Paint pincel) {
  if (progreso <= 0) return;
  final path = Path()
    ..moveTo(rect.left + rect.width * 0.28, rect.top + rect.height * 0.53)
    ..lineTo(rect.left + rect.width * 0.44, rect.top + rect.height * 0.68)
    ..lineTo(rect.left + rect.width * 0.73, rect.top + rect.height * 0.36);
  final metrica = path.computeMetrics().first;
  canvas.drawPath(metrica.extractPath(0, metrica.length * progreso.clamp(0.0, 1.0)), pincel);
}

class _PintorCheck extends CustomPainter {
  _PintorCheck({
    required this.progreso,
    required this.color,
    required this.colorCheck,
    required this.conCirculo,
    required this.reducido,
  }) : super(repaint: progreso);

  final Animation<double> progreso;
  final Color color;
  final Color colorCheck;
  final bool conCirculo;
  final bool reducido;

  @override
  void paint(Canvas canvas, Size size) {
    final t = reducido ? 1.0 : progreso.value;
    final rect = Offset.zero & size;
    // El disco brota en el primer 45 %; el trazo corre entre el 35 % y el 100 %.
    final brote = conCirculo ? AppMotion.emergente.transform((t / 0.45).clamp(0.0, 1.0)) : 1.0;
    final avance = reducido ? 1.0 : AppMotion.curvaTrazo.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
    if (conCirculo) {
      canvas.drawCircle(rect.center, size.shortestSide / 2 * brote.clamp(0.0, 1.2), Paint()..color = color);
    }
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.shortestSide * (conCirculo ? 0.085 : 0.11)
      ..color = conCirculo ? colorCheck : color;
    trazarCheck(canvas, rect, avance, pincel);
  }

  @override
  bool shouldRepaint(_PintorCheck old) =>
      old.color != color || old.colorCheck != colorCheck || old.conCirculo != conCirculo || old.reducido != reducido;
}

// ============================================================================
// Confeti
// ============================================================================

/// Colores del confeti: los tres del Carnaval y los verdes de la marca.
const List<Color> coloresConfeti = [
  Zc.carnavalAmarillo,
  Zc.carnavalRojo,
  Zc.carnavalVerde,
  Zc.hoja,
  Zc.cienaga,
  Zc.sol,
];

class _Particula {
  const _Particula({
    required this.vx,
    required this.vy,
    required this.arrastre,
    required this.giro,
    required this.fase,
    required this.ancho,
    required this.alto,
    required this.color,
  });
  final double vx, vy, arrastre, giro, fase, ancho, alto;
  final Color color;
}

/// Estallido de confeti: **una** ráfaga de [AppMotion.confeti] y se queda
/// quieto, sin repetirse. Se pinta a pantalla completa de su padre y no
/// intercepta toques.
///
/// Física simple (gravedad + arrastre), con las partículas generadas una vez
/// con semilla fija (la misma ráfaga siempre; las pruebas son estables):
/// salen hacia arriba en abanico (−165°…−15°), caen planeando y se desvanecen
/// al final; el giro en 3D se finge con una altura que oscila.
///
/// Costo: **un** controlador, **un** `CustomPainter` con `repaint:` (cero
/// reconstrucciones de widgets por partícula) y `RepaintBoundary`. Con
/// «reducir movimiento» no dibuja nada (solo avisa de que terminó).
///
/// ```dart
/// Stack(children: [
///   contenido,
///   Celebracion(origen: const Alignment(0, -0.3), alTerminar: () {}),
/// ])
/// ```
/// Para algo ya armado con ✓ y overlay, ver [celebrar].
class Celebracion extends StatefulWidget {
  const Celebracion({
    super.key,
    this.origen = const Alignment(0, -0.3),
    this.particulas = 48,
    this.grande = false,
    this.semilla = 7,
    this.alTerminar,
  });

  /// De dónde brota, relativo al área de su padre (como `Alignment`).
  final Alignment origen;
  final int particulas;

  /// Más fuerte y con más papelitos (premios mayores).
  final bool grande;
  final int semilla;
  final VoidCallback? alTerminar;

  @override
  State<Celebracion> createState() => _CelebracionState();
}

class _CelebracionState extends State<Celebracion> with SingleTickerProviderStateMixin {
  late final AnimationController _tiempo;
  late final List<_Particula> _lista = _generar();
  bool _arrancado = false;

  @override
  void initState() {
    super.initState();
    // Se crea aquí (no perezoso): con «reducir movimiento» nadie lo toca y crearlo
    // dentro de dispose() falla («deactivated widget's ancestor»).
    _tiempo = AnimationController(vsync: this, duration: AppMotion.confeti);
  }

  List<_Particula> _generar() {
    // Generador congruencial lineal (el de Numerical Recipes): determinista.
    var s = widget.semilla;
    double azar() {
      s = (1664525 * s + 1013904223) & 0x7fffffff;
      return s / 0x7fffffff;
    }

    final n = widget.grande ? (widget.particulas * 1.6).round() : widget.particulas;
    final fuerza = widget.grande ? 1.25 : 1.0;
    return List.generate(n, (i) {
      final angulo = (-165 + 150 * azar()) * math.pi / 180;
      final rapidez = (480 + 520 * azar()) * fuerza;
      return _Particula(
        vx: math.cos(angulo) * rapidez,
        vy: math.sin(angulo) * rapidez,
        arrastre: 2.4 + 1.2 * azar(),
        giro: (6 + 8 * azar()) * (azar() < 0.5 ? -1 : 1),
        fase: azar() * 2 * math.pi,
        ancho: 6 + 3 * azar(),
        alto: 10 + 5 * azar(),
        color: coloresConfeti[i % coloresConfeti.length],
      );
    }, growable: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrancado) return;
    _arrancado = true;
    if (context.animationsDisabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.alTerminar?.call();
      });
      return;
    }
    _tiempo.forward().whenComplete(() {
      if (mounted) widget.alTerminar?.call();
    });
  }

  @override
  void dispose() {
    _tiempo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.animationsDisabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox.expand(
            child: CustomPaint(painter: _PintorConfeti(_tiempo, _lista, widget.origen)),
          ),
        ),
      ),
    );
  }
}

class _PintorConfeti extends CustomPainter {
  _PintorConfeti(this.tiempo, this.lista, this.origen) : super(repaint: tiempo);

  final Animation<double> tiempo;
  final List<_Particula> lista;
  final Alignment origen;

  /// Gravedad en px/s². Con el arrastre de cada partícula, la velocidad de
  /// caída límite queda en unos 330 px/s: planean, no se desploman.
  static const double _gravedad = 1000;

  @override
  void paint(Canvas canvas, Size size) {
    if (tiempo.value <= 0 || tiempo.value >= 1) return;
    final t = tiempo.value * AppMotion.confeti.inMilliseconds / 1000;
    final centro = origen.alongSize(size);
    final alfa = tiempo.value < 0.7 ? 1.0 : (1 - (tiempo.value - 0.7) / 0.3).clamp(0.0, 1.0);
    final pincel = Paint();
    for (final p in lista) {
      final k = p.arrastre;
      final f = (1 - math.exp(-k * t)) / k;
      final x = centro.dx + p.vx * f;
      final y = centro.dy + (p.vy - _gravedad / k) * f + _gravedad / k * t;
      final volteo = math.cos(t * p.giro + p.fase); // «giro en 3D» barato
      pincel.color = p.color.withValues(alpha: alfa);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.fase + t * p.giro * 0.5);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.ancho, height: p.alto * (0.25 + 0.75 * volteo.abs())),
        pincel,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PintorConfeti old) => old.lista != lista || old.origen != origen;
}

// ============================================================================
// celebrar(context)
// ============================================================================

/// Celebra algo con un ✓ grande y un estallido de confeti encima de **todo**
/// (overlay raíz: también sobre hojas ya abiertas). Dura ≈1,8 s y se limpia
/// solo; no bloquea toques. El `Future` termina cuando ya se quitó.
///
/// Con «reducir movimiento»: solo el ✓ (con fundido), sin confeti.
/// Anuncia [etiqueta] al lector de pantalla y vibra con éxito cuando el ✓
/// aterriza (≈0,36 s). Con [conCheck] en `false` no pone ✓ (solo confeti):
/// para pantallas que ya dibujan el suyo.
///
/// ```dart
/// await celebrar(context);                       // ✓ + confeti
/// await celebrar(context, etiqueta: 'Reporte enviado', conConfeti: false);
/// ```
Future<void> celebrar(
  BuildContext context, {
  String etiqueta = 'Listo',
  bool conConfeti = true,
  bool grande = false,
  bool conCheck = true,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return Future.value();
  final fin = Completer<void>();
  late final OverlayEntry entrada;
  entrada = OverlayEntry(
    builder: (_) => _EscenaCelebracion(
      conConfeti: conConfeti,
      grande: grande,
      conCheck: conCheck,
      alTerminar: () {
        if (entrada.mounted) entrada.remove();
        entrada.dispose();
        if (!fin.isCompleted) fin.complete();
      },
    ),
  );
  overlay.insert(entrada);
  anunciar(context, etiqueta);
  return fin.future;
}

class _EscenaCelebracion extends StatefulWidget {
  const _EscenaCelebracion({
    required this.conConfeti,
    required this.grande,
    required this.conCheck,
    required this.alTerminar,
  });
  final bool conConfeti;
  final bool grande;

  /// `false`: solo el confeti (la pantalla ya dibuja su propio ✓ y no se
  /// duplica).
  final bool conCheck;
  final VoidCallback alTerminar;

  @override
  State<_EscenaCelebracion> createState() => _EscenaCelebracionState();
}

class _EscenaCelebracionState extends State<_EscenaCelebracion> with SingleTickerProviderStateMixin {
  static const _vida = Duration(milliseconds: 1800);
  late final AnimationController _reloj = AnimationController(vsync: this, duration: _vida);
  late final Animation<double> _salida =
      ReverseAnimation(CurvedAnimation(parent: _reloj, curve: const Interval(0.8, 1, curve: Curves.easeIn)));
  bool _vibro = false;
  bool _arrancada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrancada) return;
    _arrancada = true;
    _reloj.addListener(() {
      if (!_vibro && _reloj.value >= 0.2) {
        _vibro = true;
        vibrarExito();
      }
    });
    _reloj.forward().whenComplete(() {
      if (mounted) widget.alTerminar();
    });
  }

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.conConfeti) Celebracion(grande: widget.grande),
          if (widget.conCheck)
            Align(
              alignment: const Alignment(0, -0.3),
              // El ✓ se va con un fundido en el último 20 %.
              child: FadeTransition(opacity: _salida, child: const CheckDibujado(tamano: 96)),
            ),
        ],
      ),
    );
  }
}
