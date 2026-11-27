/// Interruptor estilo iOS: 51×31, la perilla se estira al tocarla y sigue al
/// dedo; al soltar, un resorte ([AppMotion.resorteFirme]) la lleva a su lado.
/// Vibra con `selección` al cambiar de verdad.
///
/// Solo se mueven `transform` y color (pintura); nada de relayout. Con
/// «reducir movimiento» cambia de golpe. Es un control de 51×31 dentro de un
/// área tocable de 60×48.
library;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../base/movimiento.dart';
import '../presionable.dart';
import '../tema.dart';

class InterruptorIos extends StatefulWidget {
  const InterruptorIos({
    super.key,
    required this.valor,
    required this.alCambiar,
    this.etiqueta,
    this.colorActivo = Zc.hoja,
  });

  final bool valor;

  /// Nulo: apagado (45 %) y sin respuesta.
  final ValueChanged<bool>? alCambiar;

  /// Lo que dice el lector de pantalla.
  final String? etiqueta;
  final Color colorActivo;

  static const double ancho = 51;
  static const double alto = 31;
  static const double _perilla = 27;
  static const double _margen = 2;

  @override
  State<InterruptorIos> createState() => _InterruptorIosState();
}

class _InterruptorIosState extends State<InterruptorIos> with TickerProviderStateMixin {
  /// 0 = apagado, 1 = encendido (sin límites: el resorte puede pasarse un pelo).
  late final AnimationController _pos =
      AnimationController.unbounded(vsync: this, value: widget.valor ? 1 : 0);

  /// 0 = reposo, 1 = presionado (la perilla se estira).
  late final AnimationController _presion = AnimationController(vsync: this, duration: Zm.presion);

  bool _arrastrando = false;

  bool get _sinMovimiento => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static const double _recorrido = InterruptorIos.ancho - InterruptorIos._perilla - 2 * InterruptorIos._margen;

  @override
  void didUpdateWidget(InterruptorIos old) {
    super.didUpdateWidget(old);
    if (old.valor != widget.valor && !_arrastrando) _llevarA(widget.valor);
  }

  @override
  void dispose() {
    _pos.dispose();
    _presion.dispose();
    super.dispose();
  }

  void _llevarA(bool encendido, {double velocidad = 0}) {
    final destino = encendido ? 1.0 : 0.0;
    if (_sinMovimiento) {
      _pos.value = destino;
    } else {
      _pos.animateWith(SpringSimulation(AppMotion.resorteFirme, _pos.value, destino, velocidad));
    }
  }

  void _cambiar(bool nuevo) {
    if (widget.alCambiar == null) return;
    vibrar(Vibracion.seleccion);
    widget.alCambiar!(nuevo);
  }

  void _bajar() {
    if (widget.alCambiar == null || _sinMovimiento) return;
    _presion.forward();
  }

  void _soltarPresion() => _presion.reverse();

  void _alArrastrar(DragUpdateDetails d) {
    if (widget.alCambiar == null) return;
    _arrastrando = true;
    _pos.value = (_pos.value + d.delta.dx / _recorrido).clamp(0.0, 1.0);
  }

  void _alSoltarArrastre(DragEndDetails d) {
    _arrastrando = false;
    final destino = _pos.value > 0.5;
    if (destino != widget.valor) {
      _cambiar(destino);
    }
    // Con el valor que el padre decida (si no cambió, vuelve a su lado).
    _llevarA(destino,
        velocidad: d.velocity.pixelsPerSecond.dx / _recorrido);
    _soltarPresion();
  }

  @override
  Widget build(BuildContext context) {
    final activo = widget.alCambiar != null;
    return Semantics(
      toggled: widget.valor,
      enabled: activo,
      label: widget.etiqueta,
      onTap: activo ? () => _cambiar(!widget.valor) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _bajar(),
        onTapCancel: _soltarPresion,
        onTapUp: (_) => _soltarPresion(),
        onTap: activo ? () => _cambiar(!widget.valor) : null,
        onHorizontalDragStart: (_) => _bajar(),
        onHorizontalDragUpdate: _alArrastrar,
        onHorizontalDragEnd: _alSoltarArrastre,
        onHorizontalDragCancel: () {
          _arrastrando = false;
          _llevarA(widget.valor);
          _soltarPresion();
        },
        child: SizedBox(
          width: 60,
          height: 48,
          child: Center(
            child: Opacity(
              opacity: activo ? 1 : 0.45,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pos, _presion]),
                  builder: (context, _) {
                    final t = _pos.value.clamp(0.0, 1.0);
                    final estira = 4.0 * Curves.easeOut.transform(_presion.value);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.lerp(const Color(0xFFD9D5CA), widget.colorActivo, t),
                        borderRadius: BorderRadius.circular(InterruptorIos.alto),
                      ),
                      child: SizedBox(
                        width: InterruptorIos.ancho,
                        height: InterruptorIos.alto,
                        child: Stack(
                          children: [
                            Positioned(
                              left: InterruptorIos._margen,
                              top: InterruptorIos._margen,
                              child: Transform.translate(
                                // Al estirarse hacia el lado de adentro, no sale del carril.
                                offset: Offset(_pos.value * _recorrido - estira * t, 0),
                                child: Container(
                                  width: InterruptorIos._perilla + estira,
                                  height: InterruptorIos._perilla,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(InterruptorIos._perilla),
                                    boxShadow: const [
                                      BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
