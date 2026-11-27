import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../datos/guardian.dart';
import '../../nucleo/base/entrada_escalonada.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/zanqui_mascota.dart';
import 'medalla.dart';

/// Cuadrícula de insignias: a color las ganadas, en silueta gris las que faltan.
class SeccionInsignias extends StatelessWidget {
  const SeccionInsignias({super.key, required this.progreso});
  final Progreso progreso;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final ganadas = Insignia.todas.where((i) => progreso.insignias.contains(i.id)).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TarjetaZ(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Insignias', style: tt.titleLarge)),
                Text('$ganadas de ${Insignia.todas.length}',
                    style: tt.labelMedium?.copyWith(color: Zc.hoja, fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              ganadas == 0 ? 'Aún no tienes ninguna. Toca una para ver cómo se gana.' : 'Toca una para ver cómo se gana.',
              style: tt.bodyMedium,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, caja) {
              final columnas = caja.maxWidth >= 300 ? 4 : 3;
              const hueco = 10.0;
              final ancho = (caja.maxWidth - hueco * (columnas - 1)) / columnas;
              return Wrap(
                spacing: hueco,
                runSpacing: 14,
                children: [
                  for (var i = 0; i < Insignia.todas.length; i++)
                    SizedBox(
                      width: ancho,
                      child: EntradaEscalonada.escala(
                        index: i,
                        child: _FichaInsignia(
                          insignia: Insignia.todas[i],
                          ganada: progreso.insignias.contains(Insignia.todas[i].id),
                          progreso: progreso,
                        ),
                      ),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FichaInsignia extends StatelessWidget {
  const _FichaInsignia({required this.insignia, required this.ganada, required this.progreso});
  final Insignia insignia;
  final bool ganada;
  final Progreso progreso;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Presionable(
      etiqueta: '${insignia.nombre}, ${ganada ? 'ganada' : 'por ganar'}. ${insignia.como}',
      onTap: () => mostrarHojaZ<void>(
        context,
        nombre: 'insignia',
        contenido: (_) => _HojaInsignia(insignia: insignia, ganada: ganada, pista: pistaDe(insignia, progreso)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Column(
          children: [
            Medalla(insignia: insignia, ganada: ganada, tamano: 56),
            const SizedBox(height: 6),
            Text(
              insignia.nombre,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(color: ganada ? Zc.texto : Zc.textoSuave, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuánto falta, cuando se puede decir con datos reales del teléfono.
String? pistaDe(Insignia i, Progreso p) {
  if (p.insignias.contains(i.id)) return null;
  switch (i.id) {
    case 'ojo_de_garza':
      return 'Llevas ${p.validados} de 3 reportes validados.';
    case 'primer_aviso':
      return 'Aún no has enviado ningún reporte.';
    default:
      return null;
  }
}

class _HojaInsignia extends StatelessWidget {
  const _HojaInsignia({required this.insignia, required this.ganada, required this.pista});
  final Insignia insignia;
  final bool ganada;
  final String? pista;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color = ganada ? Zc.hoja : Zc.textoSuave;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Medalla(insignia: insignia, ganada: ganada, tamano: 96),
        const SizedBox(height: 16),
        Text(insignia.nombre, textAlign: TextAlign.center, style: tt.headlineSmall),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ganada ? Icons.check_circle_rounded : Icons.lock_outline_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Text(ganada ? 'Ganada' : 'Por ganar', style: tt.labelMedium?.copyWith(color: color)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('Cómo se gana', style: tt.labelSmall),
        const SizedBox(height: 4),
        Text(insignia.como, textAlign: TextAlign.center, style: tt.bodyLarge),
        if (pista != null) ...[
          const SizedBox(height: 10),
          Text(pista!, textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: Zc.textoSuave)),
        ],
        const SizedBox(height: 20),
        BotonZ(texto: 'Cerrar', secundario: true, onTap: () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// Celebra una insignia recién ganada. La pantalla la llama UNA sola vez por insignia.
Future<void> mostrarCelebracion(BuildContext context, Insignia insignia) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: const Color(0x990B2E24),
    transitionDuration: context.resolveDuration(Zm.corto),
    pageBuilder: (_, _, _) => _Celebracion(insignia: insignia),
    transitionBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
  );
}

class _Celebracion extends StatefulWidget {
  const _Celebracion({required this.insignia});
  final Insignia insignia;

  @override
  State<_Celebracion> createState() => _CelebracionState();
}

class _CelebracionState extends State<_Celebracion> with TickerProviderStateMixin {
  /// Pop de la insignia: de 0 a 1 con el resorte del acuse de recibo.
  late final AnimationController _pop = AnimationController.unbounded(vsync: this);

  /// Chispas que salen en círculo: 650 ms, una sola vez.
  late final AnimationController _chispas =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void initState() {
    super.initState();
    vibrar(Vibracion.media);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.animationsDisabled) {
        _pop.value = 1;
        _chispas.value = 1;
        return;
      }
      _pop.animateWith(SpringSimulation(AppMotion.resorteRebote, 0, 1, 0));
      _chispas.forward();
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    _chispas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final i = widget.insignia;
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              label: 'Nueva insignia: ${i.nombre}',
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                decoration: BoxDecoration(color: Zc.superficie, borderRadius: BorderRadius.circular(Zr.xl)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(child: ZanquiMascota(tamano: 84, animo: Animo.celebrando)),
                    const SizedBox(height: 4),
                    Text('¡Nueva insignia!', style: tt.labelSmall?.copyWith(color: Zc.hoja, fontSize: 13)),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: 150,
                      height: 130,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_pop, _chispas]),
                        builder: (context, _) => CustomPaint(
                          foregroundPainter: _ChispasPainter(_chispas.value, i.color),
                          child: Center(
                            child: Transform.scale(
                              scale: _pop.value.clamp(0.0, 1.4),
                              child: Medalla(insignia: i, ganada: true, tamano: 96),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(i.nombre, textAlign: TextAlign.center, style: tt.headlineSmall),
                    const SizedBox(height: 6),
                    Text(i.como, textAlign: TextAlign.center, style: tt.bodyMedium),
                    const SizedBox(height: 20),
                    BotonZ(texto: 'Seguir', onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChispasPainter extends CustomPainter {
  const _ChispasPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    final salida = Curves.easeOutCubic.transform(t);
    final p = Paint()..color = color.withValues(alpha: (1 - t) * 0.9);
    for (var k = 0; k < 12; k++) {
      final a = k / 12 * math.pi * 2;
      final r = 52 + 24 * salida;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, (k.isEven ? 4.5 : 3) * (1 - t * 0.5), p);
    }
  }

  @override
  bool shouldRepaint(covariant _ChispasPainter old) => old.t != t;
}
