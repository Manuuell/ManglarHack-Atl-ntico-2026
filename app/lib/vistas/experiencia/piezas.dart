import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../datos/experiencia/preguntas_zanky.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';

/// Piezas propias de la experiencia del evento (no hay kit común en esta rama).

bool sinMovimiento(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

Animo animoDe(TonoZanky t) => switch (t) {
      TonoZanky.feliz => Animo.feliz,
      TonoZanky.curioso => Animo.curioso,
      TonoZanky.preocupado => Animo.preocupado,
      TonoZanky.celebrando => Animo.celebrando,
    };

/// Ánimo de Zanky según una respuesta libre de la IA (palabras de la respuesta, sin otra llamada).
Animo animoDeTexto(String texto) {
  final t = texto.toLowerCase();
  const malas = ['peligro', 'tala', 'basura', 'contamina', 'quema', 'relleno', 'amenaza', 'riesgo', 'reporta', 'lo siento'];
  const buenas = ['¡bien', 'felicit', 'gracias por', 'genial', 'excelente', '¡sí', 'celebr', '🎉'];
  if (malas.any(t.contains)) return Animo.preocupado;
  if (buenas.any(t.contains)) return Animo.celebrando;
  if (t.trim().endsWith('?')) return Animo.curioso;
  return Animo.feliz;
}

/// Un check que se dibuja trazo a trazo (o ya dibujado con movimiento reducido).
class CheckDibujado extends StatefulWidget {
  const CheckDibujado({super.key, this.tamano = 24, this.color = Colors.white, this.grosor = 3});
  final double tamano, grosor;
  final Color color;

  @override
  State<CheckDibujado> createState() => _CheckDibujadoState();
}

class _CheckDibujadoState extends State<CheckDibujado> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    if (sinMovimiento(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: widget.tamano,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(
              painter: _PintorCheck(Curves.easeOutCubic.transform(_c.value), widget.color, widget.grosor),
            ),
          ),
        ),
      );
}

class _PintorCheck extends CustomPainter {
  _PintorCheck(this.t, this.color, this.grosor);
  final double t, grosor;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final a = Offset(s.width * 0.18, s.height * 0.54);
    final b = Offset(s.width * 0.42, s.height * 0.76);
    final c = Offset(s.width * 0.82, s.height * 0.28);
    final l1 = (b - a).distance, l2 = (c - b).distance;
    final total = (l1 + l2) * t;
    final p = Path()..moveTo(a.dx, a.dy);
    if (total <= l1) {
      p.lineTo(a.dx + (b.dx - a.dx) * total / l1, a.dy + (b.dy - a.dy) * total / l1);
    } else {
      final k = (total - l1) / l2;
      p
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx + (c.dx - b.dx) * k, b.dy + (c.dy - b.dy) * k);
    }
    canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_PintorCheck o) => o.t != t || o.color != color;
}

enum FaseBoton { reposo, cargando, hecho }

/// Botón principal con su estado dentro: texto → rueda → check. No cambia de tamaño al pasar de uno a otro.
class BotonEstado extends StatelessWidget {
  const BotonEstado({
    super.key,
    required this.texto,
    required this.onTap,
    this.fase = FaseBoton.reposo,
    this.textoHecho,
    this.icono,
    this.color = Zc.hoja,
    this.secundario = false,
  });

  final String texto;
  final String? textoHecho;
  final VoidCallback? onTap;
  final FaseBoton fase;
  final IconData? icono;
  final Color color;
  final bool secundario;

  @override
  Widget build(BuildContext context) {
    final activo = onTap != null && fase == FaseBoton.reposo;
    final tinta = secundario ? color : Colors.white;
    final fondo = secundario ? color.withValues(alpha: 0.12) : color;
    final estilo = Theme.of(context).textTheme.labelLarge?.copyWith(color: tinta, fontSize: 16);
    final Widget interior = switch (fase) {
      FaseBoton.cargando => SizedBox(
          key: const ValueKey('c'),
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.6, color: tinta),
        ),
      FaseBoton.hecho => Row(
          key: const ValueKey('h'),
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckDibujado(color: tinta),
            if (textoHecho != null) ...[
              const SizedBox(width: 10),
              Flexible(child: Text(textoHecho!, textAlign: TextAlign.center, style: estilo)),
            ],
          ],
        ),
      FaseBoton.reposo => Row(
          key: const ValueKey('t'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[Icon(icono, color: tinta, size: 21), const SizedBox(width: 10)],
            Flexible(child: Text(texto, textAlign: TextAlign.center, style: estilo)),
          ],
        ),
    };
    return Presionable(
      onTap: activo ? onTap : null,
      vibracion: Vibracion.ligera,
      etiqueta: fase == FaseBoton.hecho ? (textoHecho ?? texto) : texto,
      child: AnimatedOpacity(
        duration: Zm.corto,
        opacity: activo || fase != FaseBoton.reposo ? 1 : 0.45,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(Zr.m),
            boxShadow: secundario || !activo
                ? null
                : [BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: sinMovimiento(context)
              ? interior
              : AnimatedSwitcher(
                  duration: Zm.corto,
                  switchInCurve: Zm.entrar,
                  transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: a, child: c)),
                  child: interior,
                ),
        ),
      ),
    );
  }
}

/// Sacude de lado a lado (amortiguado) cada vez que [disparos] sube. Con movimiento reducido no mueve nada.
class Sacudida extends StatefulWidget {
  const Sacudida({super.key, required this.disparos, required this.child});
  final int disparos;
  final Widget child;

  @override
  State<Sacudida> createState() => _SacudidaState();
}

class _SacudidaState extends State<Sacudida> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(Sacudida old) {
    super.didUpdateWidget(old);
    if (widget.disparos > old.disparos && !sinMovimiento(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, hijo) => Transform.translate(
          offset: Offset(math.sin(_c.value * math.pi * 6) * 9 * (1 - _c.value), 0),
          child: hijo,
        ),
        child: widget.child,
      );
}

/// Barra de arriba de las pantallas del evento: botón de cerrar de 48 px y un título corto.
class BarraEvento extends StatelessWidget {
  const BarraEvento({super.key, required this.titulo, this.icono = Icons.close_rounded, this.etiqueta = 'Cerrar'});
  final String titulo, etiqueta;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
      child: Row(
        children: [
          Presionable(
            onTap: () => Navigator.of(context).maybePop(),
            etiqueta: etiqueta,
            child: SizedBox.square(dimension: 48, child: Icon(icono, color: Zc.texto, size: 26)),
          ),
          const SizedBox(width: 4),
          Expanded(child: Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleMedium)),
        ],
      ),
    );
  }
}

/// Etiqueta redondeada (tipo de jornada, «Datos de ejemplo»…).
class Pildora extends StatelessWidget {
  const Pildora(this.texto, {super.key, this.color = Zc.hoja, this.icono});
  final String texto;
  final Color color;
  final IconData? icono;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icono != null) ...[Icon(icono, size: 14, color: color), const SizedBox(width: 5)],
          Flexible(
            child: Text(texto,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

/// Un renglón con icono y texto, para las tarjetas de datos.
class DatoFila extends StatelessWidget {
  const DatoFila({super.key, required this.icono, required this.texto, this.detalle});
  final IconData icono;
  final String texto;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: Zc.hoja),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texto, style: tt.titleSmall),
                if (detalle != null) Text(detalle!, style: tt.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
