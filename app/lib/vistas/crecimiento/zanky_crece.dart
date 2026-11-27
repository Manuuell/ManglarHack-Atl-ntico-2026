import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../datos/crecimiento/progreso_crecimiento.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/kit/anuncio.dart';
import '../../nucleo/kit/haptica.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';

/// El árbol vivo de la gamificación. [nivel] es el rango de Guardián; el arte
/// se decide por los puntos validados y conserva la quinta forma en rango 6.
class ZankyCrece extends StatefulWidget {
  const ZankyCrece({
    super.key,
    required this.puntos,
    required this.nivel,
    this.idGuardian,
    this.hora,
    this.alEvolucionar,
  });

  final int puntos;
  final int nivel;
  final String? idGuardian;
  final DateTime? hora;
  final ValueChanged<int>? alEvolucionar;

  @override
  State<ZankyCrece> createState() => _ZankyCreceState();
}

class _ZankyCreceState extends State<ZankyCrece> with SingleTickerProviderStateMixin {
  late final AnimationController _evolucion = AnimationController.unbounded(vsync: this, duration: Zm.largo);
  int? _anterior;
  int _revision = 0;
  final Map<String, int> _vistasSesion = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revisar());
  }

  @override
  void didUpdateWidget(ZankyCrece anterior) {
    super.didUpdateWidget(anterior);
    if (widget.puntos != anterior.puntos || widget.idGuardian != anterior.idGuardian) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revisar());
    }
  }

  Future<void> _revisar() async {
    if (!mounted) return;
    final revision = ++_revision;
    final etapa = EtapaCrecimiento.dePuntos(widget.puntos).numero;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || revision != _revision) return;
    final clave = RegistroEvolucion.clave(widget.idGuardian);
    final guardada = prefs.getInt(clave);
    final sesion = _vistasSesion[clave];
    final vista = guardada == null ? sesion :
        sesion == null ? guardada : math.max(guardada, sesion);
    if (vista == null || etapa > vista) {
      _vistasSesion[clave] = etapa;
      try {
        await prefs.setInt(clave, etapa);
      } catch (_) {
        // La vista actual sigue funcionando y no repite la fiesta en esta sesión.
      }
    }
    if (!mounted || revision != _revision) return;
    if (!RegistroEvolucion.debeEvolucionar(vista, etapa)) {
      if (_anterior != null) {
        _evolucion.stop();
        setState(() => _anterior = null);
      }
      return;
    }
    setState(() => _anterior = RegistroEvolucion.etapaAnterior(vista!, etapa));
    widget.alEvolucionar?.call(etapa);
    anunciar(context, 'Zanky creció: ahora es ${EtapaCrecimiento.todas[etapa - 1].nombre}');
    vibrarExito();
    _evolucion.stop();
    if (context.animationsDisabled) {
      _evolucion.value = 0;
      await _evolucion.animateTo(1, duration: AppMotion.fast, curve: AppMotion.enter);
    } else {
      try {
        await _evolucion.animateWith(SpringSimulation(Zm.resorteRebote, 0, 1, 0)).orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (mounted && revision == _revision) setState(() => _anterior = null);
  }

  @override
  void dispose() {
    _evolucion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avance = AvanceCrecimiento.de(widget.puntos);
    final ancho = MediaQuery.sizeOf(context).width;
    final horizontal = ancho >= 900;
    final escena = _EscenaZanky(
      etapa: avance.etapa,
      anterior: _anterior,
      evolucion: _evolucion,
      hora: widget.hora ?? DateTime.now(),
      reducido: context.animationsDisabled,
      altura: horizontal ? 360 : (ancho < 380 ? 270 : 300),
    );
    final datos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('ETAPA ${avance.etapa.numero} DE 5', style: Theme.of(context).textTheme.seccion.copyWith(color: Zc.hoja)),
        const SizedBox(height: 8),
        Text(avance.etapa.nombre, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(avance.etapa.lema, style: Theme.of(context).textTheme.bodyMedium),
        if (widget.nivel > 5) ...[
          const SizedBox(height: 8),
          Text('Rango ${widget.nivel}: Guardián del manglar', style: Theme.of(context).textTheme.labelLarge),
        ],
        const SizedBox(height: 20),
        _ProgresoEtapas(avance: avance, puntos: widget.puntos),
      ],
    );
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Zc.superficie,
          borderRadius: BorderRadius.circular(Zr.l),
          border: Border.all(color: Zc.linea),
        ),
        child: horizontal
            ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(flex: 6, child: escena),
                const SizedBox(width: 28),
                Expanded(flex: 5, child: datos),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                escena,
                const SizedBox(height: 20),
                datos,
              ]),
      ),
    );
  }
}

class _EscenaZanky extends StatelessWidget {
  const _EscenaZanky({required this.etapa, required this.anterior,
    required this.evolucion, required this.hora, required this.reducido, required this.altura});

  final EtapaCrecimiento etapa;
  final int? anterior;
  final Animation<double> evolucion;
  final DateTime hora;
  final bool reducido;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final noche = hora.hour < 6 || hora.hour >= 18;
    return LayoutBuilder(builder: (context, limites) {
      final arte = math.min(limites.maxWidth * 0.68, altura * 0.73).clamp(160.0, 300.0).toDouble();
      return SizedBox(
        height: altura,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Zr.m),
          child: Stack(fit: StackFit.expand, children: [
            DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: noche
                  ? const [Color(0xFF153D53), Color(0xFF2E665E), Color(0xFF0D424A)]
                  : const [Color(0xFFFDEAC5), Color(0xFFE4F3D9), Color(0xFFB6E5DE)],
            ))),
            Positioned(top: 22, right: 28, child: Icon(
              noche ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              color: noche ? const Color(0xFFFDEBC1) : Zc.sol, size: 54,
              semanticLabel: noche ? 'Luz de luna' : 'Luz del sol',
            )),
            Positioned.fill(child: CustomPaint(painter: _Paisaje(oscuro: noche, etapa: etapa.numero))),
            if (anterior != null)
              AnimatedBuilder(animation: evolucion, builder: (context, _) {
                final t = evolucion.value.clamp(0.0, 1.0);
                return Center(child: Opacity(opacity: (1 - t * 1.5).clamp(0.0, 1.0),
                  child: Transform.scale(scale: reducido ? 1 : 1 + 0.12 * t,
                    child: ExcludeSemantics(child: ZankyEtapa(etapa: anterior!, tamano: arte))),
                ));
              }),
            AnimatedBuilder(animation: evolucion, builder: (context, _) {
              final t = anterior == null ? 1.0 : evolucion.value.clamp(0.0, 1.0);
              return Center(child: Opacity(opacity: anterior == null ? 1 : t,
                child: Transform.scale(key: const Key('etapa-nueva'),
                  scale: anterior == null || reducido ? 1 : 0.66 + 0.34 * evolucion.value,
                  child: ZankyEtapa(etapa: etapa.numero, tamano: arte,
                    etiqueta: 'Zanky, ${etapa.nombre}, etapa ${etapa.numero} de 5')),
              ));
            }),
            if (anterior != null && !reducido)
              AnimatedBuilder(animation: evolucion, builder: (context, _) {
                final t = evolucion.value.clamp(0.0, 1.0);
                return IgnorePointer(key: const Key('hojas-evolucion'), child: Stack(children: [
                  Positioned.fill(child: Opacity(opacity: math.sin(math.pi * t).clamp(0.0, 1.0).toDouble(),
                    child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(
                      colors: [Colors.white.withValues(alpha: 0.65), Colors.transparent],
                    ))))),
                  for (var i = 0; i < 9; i++)
                    Positioned(
                      left: limites.maxWidth * (0.5 + math.cos(i * 2.4) * 0.33),
                      top: altura * (0.56 + math.sin(i * 2.4) * 0.27),
                      child: Opacity(opacity: math.sin(math.pi * t).clamp(0.0, 1.0).toDouble(),
                        child: Transform.translate(offset: Offset(
                          math.cos(i * 2.4) * 38 * t, math.sin(i * 2.4) * 46 * t),
                          child: Transform.rotate(angle: t * (i.isEven ? 1 : -1),
                            child: const Icon(Icons.eco_rounded, color: Zc.hoja, size: 16)))),
                    ),
                ]));
              }),
          ]),
        ),
      );
    });
  }
}

class _Paisaje extends CustomPainter {
  const _Paisaje({required this.oscuro, required this.etapa});
  final bool oscuro;
  final int etapa;

  @override
  void paint(Canvas canvas, Size size) {
    final agua = Paint()..color = oscuro ? const Color(0xFF0A3444) : const Color(0xFF64C5C3);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.78, size.width, size.height * 0.22), agua);
    final reflejo = Paint()..color = Colors.white.withValues(alpha: oscuro ? 0.16 : 0.3)
      ..style = PaintingStyle.stroke..strokeWidth = 2;
    for (var i = 0; i < 6; i++) {
      final y = size.height * (0.82 + i * 0.027);
      canvas.drawLine(Offset(size.width * (0.06 + (i % 3) * 0.11), y),
        Offset(size.width * (0.33 + (i % 3) * 0.1), y), reflejo);
      canvas.drawLine(Offset(size.width * 0.7, y), Offset(size.width * 0.91, y), reflejo);
    }
    final fango = Paint()..color = oscuro ? const Color(0xFF244B43) : const Color(0xFF8A6A4B);
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.82),
      width: size.width * 0.58, height: 28), fango);
    if (etapa >= 4) {
      final raiz = Paint()..color = (oscuro ? const Color(0xFF573B2E) : const Color(0xFF7B4D32))
        ..strokeWidth = 6..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
      for (final lado in const [-1.0, 1.0]) {
        final centro = size.width * 0.5;
        canvas.drawPath(Path()
          ..moveTo(centro + lado * 22, size.height * 0.68)
          ..quadraticBezierTo(centro + lado * 85, size.height * 0.73,
            centro + lado * size.width * 0.25, size.height * 0.85), raiz);
      }
    }
  }

  @override
  bool shouldRepaint(_Paisaje anterior) =>
      oscuro != anterior.oscuro || etapa != anterior.etapa;
}

class _ProgresoEtapas extends StatelessWidget {
  const _ProgresoEtapas({required this.avance, required this.puntos});
  final AvanceCrecimiento avance;
  final int puntos;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(avance.siguiente == null ? 'Crecimiento completo' :
        'Hacia ${avance.siguiente!.nombre}', style: tt.titleSmall),
      const SizedBox(height: 8),
      Semantics(label: '${(avance.fraccion * 100).round()} por ciento hacia la siguiente etapa',
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
          value: avance.fraccion, minHeight: 10, color: Zc.hoja, backgroundColor: Zc.hojaClara,
        ))),
      const SizedBox(height: 7),
      Text(avance.faltaTexto, style: tt.bodySmall?.copyWith(color: Zc.raiz)),
      const SizedBox(height: 4),
      Text('$puntos puntos de reportes validados', style: tt.bodySmall),
      const SizedBox(height: 18),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final e in EtapaCrecimiento.todas)
          Expanded(child: Semantics(
            label: '${e.nombre}, ${e.numero < avance.etapa.numero ? 'alcanzada' : e.numero == avance.etapa.numero ? 'actual' : 'pendiente'}',
            child: Column(children: [
              Container(
                width: 48, height: 48, alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: e.numero == avance.etapa.numero ? Zc.hojaClara : Zc.arena,
                  border: Border.all(color: e.numero == avance.etapa.numero ? Zc.hoja : Zc.linea,
                    width: e.numero == avance.etapa.numero ? 2 : 1)),
                child: e.numero > avance.etapa.numero
                    ? ColorFiltered(colorFilter: const ColorFilter.mode(Zc.textoTenue, BlendMode.srcIn),
                        child: Opacity(opacity: 0.45, child: ZankyEtapa(etapa: e.numero, tamano: 36)))
                    : ZankyEtapa(etapa: e.numero, tamano: 38),
              ),
              const SizedBox(height: 6),
              Text(e.nombre, textAlign: TextAlign.center, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(color: e.numero == avance.etapa.numero ? Zc.raiz : Zc.textoSuave)),
            ]),
          )),
      ]),
    ]);
  }
}

/// Vista breve para Inicio. No consulta preferencias ni dispara otra evolución.
class ZankyCreceCompacto extends StatelessWidget {
  const ZankyCreceCompacto({super.key, required this.puntos, required this.alAbrir});
  final int puntos;
  final VoidCallback alAbrir;

  @override
  Widget build(BuildContext context) {
    final avance = AvanceCrecimiento.de(puntos);
    final tt = Theme.of(context).textTheme;
    // El arte oficial de la etapa (assets/zanky/etapas) sobre un halo suave, sin dibujo en código.
    return Presionable(
      escala: 0.98,
      etiqueta: 'Mi manglar. Zanky es ${avance.etapa.nombre}. ${avance.faltaTexto}',
      onTap: alAbrir,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: Zc.superficie,
          borderRadius: BorderRadius.circular(Zr.l),
          border: Border.all(color: Zc.linea.withValues(alpha: 0.7)),
        ),
        child: Row(children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(color: Zc.hojaClara, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: ZankyEtapa(etapa: avance.etapa.numero, tamano: 68),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MI MANGLAR · ETAPA ${avance.etapa.numero} DE 5',
                  style: tt.labelSmall?.copyWith(color: Cra.azul, letterSpacing: 0.6, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Zanky está creciendo', style: tt.titleMedium),
              Text(avance.etapa.nombre, style: tt.bodySmall),
              const SizedBox(height: 8),
              // La barra se llena al aparecer (600 ms); con «reducir movimiento» sale ya llena.
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: MediaQuery.disableAnimationsOf(context)
                      ? LinearProgressIndicator(
                          value: avance.fraccion, minHeight: 6, color: Zc.hoja, backgroundColor: Zc.hojaClara)
                      : TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: avance.fraccion),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => LinearProgressIndicator(
                              value: v, minHeight: 6, color: Zc.hoja, backgroundColor: Zc.hojaClara),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(avance.faltaTexto, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(color: Zc.textoTenue)),
            ]),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: Zc.raiz),
        ]),
      ),
    );
  }
}
