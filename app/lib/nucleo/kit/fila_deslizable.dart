/// Acción al deslizar, al estilo iOS: arrastrar en horizontal revela acciones a
/// izquierda y/o derecha. El contenido sigue al dedo (o al ratón), cede con
/// resistencia elástica más allá del ancho de las acciones, vibra una vez al
/// cruzar el umbral y al soltar queda abierto o vuelve con un resorte.
///
/// Traducido de dos fuentes:
/// - `FilaDeslizable` de la app universitaria (gestos/fila_deslizable.dart):
///   resistencia `k·e/(k+e)`, pestillo del háptico, resorte al asentar, destino
///   decidido solo por el umbral y acciones de accesibilidad.
/// - `swipe-action.tsx` de FastFood: ancho de acción, umbral de apertura y
///   versión sin movimiento (cambio instantáneo).
///
/// Ningún gesto es la única vía: cada acción es un botón real (≥ 44 px) y además
/// sale como acción del lector de pantalla. Con «reducir movimiento» el gesto
/// funciona pero el cambio es instantáneo.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';

import '../presionable.dart';
import '../tema.dart';
import 'accion_gesto.dart';

/// Háptico del umbral, inyectable para pruebas.
typedef RetroHapticaFila = void Function();

class FilaDeslizable extends StatefulWidget {
  const FilaDeslizable({
    super.key,
    required this.hijo,
    this.accionesInicio = const [],
    this.accionesFin = const [],
    this.anchoAccion = 76,
    this.proporcionApertura = 0.5,
    this.retroHaptica,
    this.etiquetaSemantica,
    this.radio,
  });

  final Widget hijo;

  /// Se revelan al arrastrar hacia la derecha (aparecen a la izquierda).
  final List<AccionGesto> accionesInicio;

  /// Se revelan al arrastrar hacia la izquierda (aparecen a la derecha).
  final List<AccionGesto> accionesFin;

  final double anchoAccion;

  /// Fracción del ancho revelado que hay que pasar para que quede abierta.
  final double proporcionApertura;

  final RetroHapticaFila? retroHaptica;
  final String? etiquetaSemantica;

  /// Esquinas con las que se recorta la pista de baldosas.
  final BorderRadius? radio;

  static const double constanteResistencia = 120;

  /// Hasta [tope] el desplazamiento pasa intacto; más allá crece cada vez menos
  /// (`k·e/(k+e)`), sin cortarse en seco. Con [tope] 0 casi no cede, pero respira.
  static double aplicarResistencia(double bruto, double tope) {
    final signo = bruto.sign;
    final magnitud = bruto.abs();
    if (magnitud == 0) return 0;
    if (tope <= 0) {
      return signo * constanteResistencia * magnitud / (constanteResistencia + magnitud) * 0.5;
    }
    if (magnitud <= tope) return bruto;
    final exceso = magnitud - tope;
    return signo * (tope + constanteResistencia * exceso / (constanteResistencia + exceso));
  }

  @override
  State<FilaDeslizable> createState() => _FilaDeslizableState();
}

class _FilaDeslizableState extends State<FilaDeslizable> with SingleTickerProviderStateMixin {
  // Nace en initState: perezoso, una fila nunca arrastrada lo creaba por primera vez dentro de dispose().
  late final AnimationController _c;
  bool _avisoUmbral = false;
  bool _abierta = false;

  double get _anchoIni => widget.accionesInicio.length * widget.anchoAccion;
  double get _anchoFin => widget.accionesFin.length * widget.anchoAccion;

  @override
  void initState() {
    super.initState();
    _c = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _alEmpezar(DragStartDetails _) {
    _c.stop();
    _avisoUmbral = false;
  }

  void _alMover(DragUpdateDetails d) {
    final bruto = _c.value + d.delta.dx;
    final tope = bruto > 0 ? _anchoIni : (bruto < 0 ? _anchoFin : 0.0);
    final aplicado = FilaDeslizable.aplicarResistencia(bruto, tope);
    _c.value = aplicado;
    final ancho = aplicado > 0 ? _anchoIni : _anchoFin;
    if (ancho > 0 && !_avisoUmbral && aplicado.abs() >= ancho * widget.proporcionApertura) {
      _avisoUmbral = true;
      (widget.retroHaptica ?? () => vibrar(Vibracion.ligera))();
    }
  }

  void _alTerminar(DragEndDetails _) {
    final x = _c.value;
    if (x == 0) return _asentar(0);
    final ancho = x > 0 ? _anchoIni : _anchoFin;
    if (ancho <= 0) return _asentar(0);
    // Sin fling por velocidad a propósito: el umbral decide, el gesto es predecible.
    _asentar(x.abs() >= ancho * widget.proporcionApertura ? x.sign * ancho : 0);
  }

  void _asentar(double destino) {
    final abierta = destino != 0;
    if (abierta != _abierta && mounted) setState(() => _abierta = abierta);
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = destino;
      return;
    }
    unawaited(_c.animateWith(SpringSimulation(Zm.resorteSuave, _c.value, destino, _c.velocity)));
  }

  Future<void> _ejecutar(AccionGesto a) async {
    _asentar(0);
    await a.alEjecutar();
  }

  @override
  Widget build(BuildContext context) {
    final acciones = [...widget.accionesInicio, ...widget.accionesFin];
    Widget contenido = acciones.isEmpty
        ? widget.hijo
        : Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(animation: _c, builder: (_, _) => _pista(_c.value)),
              ),
              AnimatedBuilder(
                animation: _c,
                builder: (_, hijo) => Transform.translate(offset: Offset(_c.value, 0), child: hijo),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  // El arrastre no tiene nada que decirle al lector: su camino son las acciones de abajo.
                  excludeFromSemantics: true,
                  onHorizontalDragStart: _alEmpezar,
                  onHorizontalDragUpdate: _alMover,
                  onHorizontalDragEnd: _alTerminar,
                  onHorizontalDragCancel: () => _asentar(0),
                  child: _abierta
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _asentar(0),
                          child: AbsorbPointer(child: widget.hijo),
                        )
                      : widget.hijo,
                ),
              ),
            ],
          );
    final radio = widget.radio;
    if (radio != null) contenido = ClipRRect(borderRadius: radio, child: contenido);
    if (acciones.isEmpty && widget.etiquetaSemantica == null) return contenido;
    return Semantics(
      label: widget.etiquetaSemantica,
      customSemanticsActions: {
        for (final a in acciones) CustomSemanticsAction(label: a.anuncio): () => unawaited(_ejecutar(a)),
      },
      child: contenido,
    );
  }

  Widget _pista(double x) {
    if (x == 0) return const SizedBox.shrink();
    final alInicio = x > 0;
    final lista = alInicio ? widget.accionesInicio : widget.accionesFin;
    return Align(
      alignment: alInicio ? Alignment.centerLeft : Alignment.centerRight,
      child: SizedBox(
        width: lista.length * widget.anchoAccion,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final a in lista) Expanded(child: _Baldosa(accion: a, alTocar: () => _ejecutar(a)))],
        ),
      ),
    );
  }
}

class _Baldosa extends StatelessWidget {
  const _Baldosa({required this.accion, required this.alTocar});
  final AccionGesto accion;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: accion.anuncio,
      onTap: alTocar,
      excludeSemantics: true,
      child: Presionable(
        vibracion: Vibracion.ligera,
        onTap: alTocar,
        escala: 0.96,
        child: Container(
          key: Key('accion-${accion.etiqueta}'),
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          color: accion.colorResuelto,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          // En tarjetas bajas icono y texto se encogen juntos en vez de desbordar.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(accion.icono, size: 22, color: Colors.white),
                const SizedBox(height: 3),
                Text(accion.etiqueta, maxLines: 1, style: tt.labelMedium?.copyWith(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
