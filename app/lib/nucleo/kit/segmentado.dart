/// Control segmentado estilo iOS: la píldora blanca se desliza con resorte
/// ([AppMotion.resorteFirme]) —solo `transform`, sin relayout— y también se
/// puede **arrastrar** de un segmento a otro. Cada opción mide 44 de alto.
/// Vibra con `selección` al cambiar. Con «reducir movimiento» salta.
///
/// ```dart
/// SegmentadoZ(
///   valor: i,
///   etiquetas: const ['Todos', 'Pendientes', 'Validados'],
///   alCambiar: (n) => setState(() => i = n),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../base/movimiento.dart';
import '../presionable.dart';
import '../tema.dart';

class SegmentadoZ extends StatefulWidget {
  const SegmentadoZ({super.key, required this.valor, required this.etiquetas, required this.alCambiar});
  final int valor;
  final List<String> etiquetas;
  final ValueChanged<int> alCambiar;

  @override
  State<SegmentadoZ> createState() => _SegmentadoZState();
}

class _SegmentadoZState extends State<SegmentadoZ> with SingleTickerProviderStateMixin {
  late final AnimationController _pos = AnimationController.unbounded(vsync: this, value: widget.valor.toDouble());
  double _ancho = 1;
  bool _arrastrando = false;

  @override
  void didUpdateWidget(SegmentadoZ old) {
    super.didUpdateWidget(old);
    if (old.valor == widget.valor || _arrastrando) return;
    _llevarA(widget.valor);
  }

  void _llevarA(int i, {double velocidad = 0}) {
    final destino = i.toDouble();
    if (context.animationsDisabled) {
      _pos.value = destino;
    } else {
      _pos.animateWith(SpringSimulation(AppMotion.resorteFirme, _pos.value, destino, velocidad));
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  void _elegir(int i) {
    if (i == widget.valor) return;
    vibrar(Vibracion.seleccion);
    widget.alCambiar(i);
  }

  void _alArrastrar(DragUpdateDetails d) {
    _arrastrando = true;
    _pos.value = (_pos.value + d.delta.dx / _ancho).clamp(0.0, widget.etiquetas.length - 1.0);
  }

  void _alSoltar(DragEndDetails d) {
    _arrastrando = false;
    final n = widget.etiquetas.length;
    // La velocidad empuja: un gesto rápido salta al vecino aunque no pase la mitad.
    final proyectado = _pos.value + d.velocity.pixelsPerSecond.dx / _ancho * 0.12;
    final destino = proyectado.round().clamp(0, n - 1);
    _llevarA(destino, velocidad: d.velocity.pixelsPerSecond.dx / _ancho);
    _elegir(destino);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.etiquetas.length;
    final tt = Theme.of(context).textTheme;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Zc.linea.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Zr.s + 2),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final ancho = c.maxWidth / n;
          _ancho = ancho;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: _alArrastrar,
            onHorizontalDragEnd: _alSoltar,
            onHorizontalDragCancel: () {
              _arrastrando = false;
              _llevarA(widget.valor);
            },
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _pos,
                  builder: (context, hijo) => Transform.translate(offset: Offset(_pos.value * ancho, 0), child: hijo),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: SizedBox(
                      width: ancho - 6,
                      height: 38,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Zc.superficie,
                          borderRadius: BorderRadius.circular(Zr.s),
                          boxShadow: const [BoxShadow(color: Color(0x1A0B2E24), blurRadius: 8, offset: Offset(0, 2))],
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: Semantics(
                          selected: i == widget.valor,
                          child: Presionable(
                            onTap: i == widget.valor ? null : () => _elegir(i),
                            vibracion: Vibracion.ninguna, // vibra _elegir, una sola vez
                            escala: 0.96,
                            etiqueta: widget.etiquetas[i],
                            child: SizedBox(
                              height: 44,
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: AppMotion.fast,
                                  style: tt.labelLarge!.copyWith(
                                    color: i == widget.valor ? Zc.texto : Zc.textoSuave,
                                  ),
                                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(widget.etiquetas[i])),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
