import 'package:flutter/material.dart';

import '../../datos/roles.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';

/// «¿Qué hago ya?»: la única cosa que más conviene hacer ahora, según el rol y el momento.
/// Cuando la sugerencia cambia (llegó un reporte, volvió la señal) la tarjeta se cruza con un
/// fundido corto en vez de saltar.
class QueHagoYa extends StatelessWidget {
  const QueHagoYa({super.key, required this.accion, required this.alTocar});
  final AccionYa accion;
  final ValueChanged<DestinoYa> alTocar;

  static (Color fondo, Color tinta) _colores(TonoYa t) => switch (t) {
        TonoYa.urgente => (const Color(0xFFFCE6E3), Zc.prioridad[5]!),
        TonoYa.normal => (Zc.hojaClara, Zc.hoja),
        TonoYa.suave => (Zc.cienagaClara, const Color(0xFF137579)),
      };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final (fondo, tinta) = _colores(accion.tono);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedSwitcher(
        duration: context.resolveDuration(Zm.medio),
        switchInCurve: Zm.entrar,
        transitionBuilder: (hijo, anim) => FadeTransition(opacity: anim, child: hijo),
        layoutBuilder: (actual, anteriores) => Stack(
          alignment: Alignment.topCenter,
          children: [...anteriores, ?actual],
        ),
        child: Presionable(
          key: ValueKey(accion.clave),
          escala: 0.98,
          vibracion: Vibracion.media,
          etiqueta: '¿Qué hago ya? ${accion.titulo}. ${accion.boton}',
          onTap: () => alTocar(accion.destino),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(Zr.l),
              border: Border.all(color: tinta.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: tinta, shape: BoxShape.circle),
                  child: Icon(accion.icono, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('¿QUÉ HAGO YA?', style: tt.labelSmall?.copyWith(color: tinta)),
                      const SizedBox(height: 2),
                      Text(accion.titulo, style: tt.titleMedium),
                      const SizedBox(height: 2),
                      Text(accion.detalle, style: tt.bodySmall),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: tinta, borderRadius: BorderRadius.circular(99)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(child: Text(accion.boton, style: tt.labelMedium?.copyWith(color: Colors.white))),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                        ]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
