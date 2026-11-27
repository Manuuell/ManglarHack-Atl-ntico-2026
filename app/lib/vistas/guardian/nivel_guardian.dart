import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../datos/guardian.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/base/transicion_pestanas.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/burbuja.dart';
import '../comun/zanky_mascota.dart';
import '../reporte/flujo_reporte.dart';

const _cifras = [FontFeature.tabularFigures()];

/// Nivel: anillo de puntos validados, lo que está en revisión (aparte) y la escalera
/// del mangle rojo.
class SeccionNivel extends StatelessWidget {
  const SeccionNivel({super.key, required this.progreso, required this.sinReportes});
  final Progreso progreso;

  /// No hay ni un reporte en el teléfono: Zanky anima a empezar.
  final bool sinReportes;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final nivel = progreso.nivel;
    final sig = nivel.siguiente;
    final faltan = sig == null ? 0 : sig.desde - progreso.puntos;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TarjetaZ(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AnilloNivel(avance: progreso.avanceNivel, puntos: progreso.puntos),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nivel ${nivel.numero} de ${Nivel.todos.length}', style: tt.labelSmall?.copyWith(color: Zc.hoja)),
                      const SizedBox(height: 2),
                      Text(nivel.nombre, style: tt.headlineSmall),
                      const SizedBox(height: 6),
                      Text(
                        sig == null
                            ? '¡Llegaste al nivel más alto!'
                            : 'Te faltan $faltan ${faltan == 1 ? 'punto' : 'puntos'} para ser ${sig.nombre}.',
                        style: tt.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ZankyEtapa(etapa: nivel.numero, tamano: 64),
                const SizedBox(width: 12),
                Expanded(child: Text(nivel.lema, style: tt.bodyMedium)),
              ],
            ),
            if (progreso.pendientes > 0) ...[
              const SizedBox(height: 14),
              _EnRevision(pendientes: progreso.pendientes),
            ],
            if (sinReportes) ...[
              const SizedBox(height: 18),
              const _Arranque(),
            ],
            const SizedBox(height: 18),
            Text('Tu camino', style: tt.titleMedium),
            const SizedBox(height: 8),
            for (final n in Nivel.todos) _PasoEscalera(nivel: n, actual: nivel, puntos: progreso.puntos),
          ],
        ),
      ),
    );
  }
}

class _Arranque extends StatelessWidget {
  const _Arranque();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Zc.hojaClara.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(Zr.m)),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ZankyMascota(tamano: 64, animo: Animo.celebrando, onTap: () => vibrar(Vibracion.ligera)),
              const SizedBox(width: 8),
              const Expanded(
                child: BurbujaZanky(
                  texto: 'Todo guardián empezó como un propágulo. Tu primer reporte validado te hace crecer.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BotonZ(texto: 'Hacer mi primer reporte', icono: Icons.add_a_photo_rounded, onTap: () => abrirReporte(context)),
        ],
      ),
    );
  }
}

/// Puntos que aún no cuentan: claramente aparte del anillo (color cálido, reloj de arena).
class _EnRevision extends StatelessWidget {
  const _EnRevision({required this.pendientes});
  final int pendientes;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      label: 'Más $pendientes puntos en revisión. Cuentan cuando una persona los valide.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Zc.solClaro,
          borderRadius: BorderRadius.circular(Zr.m),
          border: Border.all(color: Zc.sol.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded, color: Color(0xFF9A5B00), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '+$pendientes en revisión',
                    style: tt.titleSmall?.copyWith(color: const Color(0xFF7A4800), fontFeatures: _cifras),
                  ),
                  TextSpan(
                    text: '  Cuentan cuando una persona de la CRA o un vigía los valide.',
                    style: tt.bodySmall?.copyWith(color: const Color(0xFF7A4800)),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnilloNivel extends StatelessWidget {
  const _AnilloNivel({required this.avance, required this.puntos});
  final double avance;
  final int puntos;
  static const _lado = 132.0;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    // Una pestaña precargada no se ve: el anillo espera a que se abra para llenarse.
    final visible = PestanaVisible.de(context);
    final meta = visible ? avance : 0.0;
    return Semantics(
      label: '$puntos puntos validados, ${(avance * 100).round()} por ciento del camino al siguiente nivel',
      excludeSemantics: true,
      child: SizedBox(
        width: _lado,
        height: _lado,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: meta),
                duration: context.resolveDuration(const Duration(milliseconds: 1100)),
                curve: AppMotion.enter,
                builder: (context, v, _) => CustomPaint(size: const Size(_lado, _lado), painter: _AnilloPainter(v)),
              ),
            ),
            // Dentro del anillo no cabe más: con letra muy grande el texto se achica un poco.
            Padding(
              padding: const EdgeInsets.all(20),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ContadorAnimado(
                      valor: visible ? puntos.toDouble() : 0,
                      formato: (v) => v.round().toString(),
                      estilo: tt.displaySmall?.copyWith(fontSize: 32, fontFeatures: _cifras),
                    ),
                    Text('puntos', style: tt.bodySmall),
                    Text('validados', style: tt.bodySmall?.copyWith(color: Zc.hoja)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnilloPainter extends CustomPainter {
  const _AnilloPainter(this.avance);
  final double avance;
  static const _grosor = 13.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(_grosor / 2, _grosor / 2) & Size(size.width - _grosor, size.height - _grosor);
    final fondo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _grosor
      ..color = Zc.hojaClara;
    canvas.drawArc(rect, 0, math.pi * 2, false, fondo);
    if (avance <= 0.004) return;
    final tinta = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _grosor
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [Zc.cienaga, Zc.hoja, Zc.hoja],
        stops: [0, 0.55, 1],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * avance.clamp(0.0, 1.0), false, tinta);
  }

  @override
  bool shouldRepaint(covariant _AnilloPainter old) => old.avance != avance;
}

class _PasoEscalera extends StatelessWidget {
  const _PasoEscalera({required this.nivel, required this.actual, required this.puntos});
  final Nivel nivel;
  final Nivel actual;
  final int puntos;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final pasado = nivel.numero < actual.numero;
    final esActual = nivel.numero == actual.numero;
    final esSiguiente = nivel.numero == actual.numero + 1;
    final detalle = pasado
        ? 'Superado'
        : esActual
            ? 'Estás aquí'
            : esSiguiente
                ? 'Te faltan ${nivel.desde - puntos} ${nivel.desde - puntos == 1 ? 'punto' : 'puntos'}'
                : 'Desde ${nivel.desde} puntos';
    final Widget marca;
    if (pasado) {
      marca = Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(color: Zc.hoja, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 19),
      );
    } else {
      marca = Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: esActual ? Zc.raiz : Colors.transparent,
          shape: BoxShape.circle,
          border: esActual ? null : Border.all(color: Zc.linea, width: 2),
        ),
        child: Text('${nivel.numero}',
            style: tt.labelMedium?.copyWith(color: esActual ? Colors.white : Zc.textoTenue, fontFeatures: _cifras)),
      );
    }
    return Semantics(
      label: 'Nivel ${nivel.numero}, ${nivel.nombre}. $detalle.',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: esActual ? Zc.hojaClara : Colors.transparent,
          borderRadius: BorderRadius.circular(Zr.s),
        ),
        child: Row(
          children: [
            marca,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nivel.nombre,
                      style: tt.titleSmall?.copyWith(color: pasado || esActual || esSiguiente ? Zc.texto : Zc.textoSuave)),
                  Text(detalle,
                      style: tt.bodySmall?.copyWith(
                          color: esSiguiente ? const Color(0xFF9A5B00) : (esActual ? Zc.raizSuave : Zc.textoSuave))),
                ],
              ),
            ),
            Text('${nivel.desde}', style: tt.labelMedium?.copyWith(color: Zc.textoSuave, fontFeatures: _cifras)),
          ],
        ),
      ),
    );
  }
}

/// «Cómo se ganan puntos»: la regla, sin letra chica.
class SeccionPuntos extends StatelessWidget {
  const SeccionPuntos({super.key, required this.servidorConectado});
  final bool servidorConectado;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    Widget fila(IconData i, String t, String puntos) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(i, size: 22, color: Zc.hoja),
              const SizedBox(width: 12),
              Expanded(child: Text(t, style: tt.bodyLarge)),
              const SizedBox(width: 8),
              Text(puntos, style: tt.titleSmall?.copyWith(color: Zc.hoja, fontFeatures: _cifras)),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TarjetaZ(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cómo se ganan puntos', style: tt.titleLarge),
            const SizedBox(height: 6),
            Text('Solo cuentan los reportes que una persona valida. Reportar mucho no da puntos; reportar bien sí.',
                style: tt.bodyMedium),
            const SizedBox(height: 10),
            fila(Icons.verified_rounded, 'Reporte validado', '+50'),
            fila(Icons.photo_camera_rounded, 'Foto tomada en el sitio', '+10'),
            fila(Icons.priority_high_rounded, 'Prioridad 4 o 5', '+10'),
            fila(Icons.gavel_rounded, 'Se abrió expediente', '+30'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Zc.arena, borderRadius: BorderRadius.circular(Zr.s)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: Zc.textoSuave),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      servidorConectado
                          ? 'Un reporte descartado no da puntos. Así nadie gana inflando cifras.'
                          : 'Modo demostración: sin el servidor de la CRA nadie valida tus reportes, así que los puntos '
                              'todavía no suben. La regla es esta y no cambia.',
                      style: tt.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
