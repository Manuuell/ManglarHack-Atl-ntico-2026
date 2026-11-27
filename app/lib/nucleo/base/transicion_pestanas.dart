import 'dart:async';

import 'package:flutter/material.dart';

import 'movimiento.dart';

/// Cambio de pestaña con fundido corto y desplazamiento mínimo,
/// conservando el estado.
///
/// Cada pestaña se construye la primera vez que se abre **o** cuando la
/// precarga le llega (ver abajo), y queda montada después (como en un
/// [IndexedStack]): el scroll y los filtros no se pierden al volver. La
/// visible se enseña con un fundido de [AppMotion.fast] + [AppMotion.enter]
/// acompañado de un desplazamiento vertical mínimo; las demás quedan en
/// [Offstage] + [TickerMode] apagado para no gastar cuadros. Cada pestaña va
/// en un [RepaintBoundary] para no repintar a las hermanas durante el
/// fundido.
///
/// No es un corte seco (hay fundido) ni una animación larga (150 ms),
/// y nunca un deslizamiento lateral de página completa: eso es una
/// ruta apilada, no una pestaña. Con `MediaQuery.disableAnimations`,
/// el cambio es instantáneo.
///
/// ## Precarga (patrón medido en un proyecto anterior)
///
/// Se midió en el teléfono que la primera visita a una pestaña tardaba
/// ~500 ms porque montarla y verla iban juntos, y que precargada costaba lo
/// mismo que una segunda visita. Aquí igual: un rato después de abrir la
/// app ([retardoPrecarga]), las pestañas nunca abiertas se construyen de
/// fondo **de una en una**, separadas por [pausaPrecarga] y en el orden de
/// [ordenPrecarga] (de la más pesada a la más liviana), para no trabar la
/// pestaña visible con un solo bloque largo.
///
/// Una pestaña precargada no se ve ni anima: su [PestanaVisible] dice
/// `false`, y las entradas escalonadas ([EntradaEscalonada]) esperan a que
/// pase a `true` para arrancar. Así la «cola» de entrada de cada pestaña se
/// ve la primera vez que la persona la abre, no mientras está escondida.
class AnimatedTabStack extends StatefulWidget {
  const AnimatedTabStack({
    super.key,
    required this.index,
    required this.children,
    this.precargar = true,
    this.ordenPrecarga,
    this.retardoPrecarga = const Duration(milliseconds: 1200),
    this.pausaPrecarga = const Duration(milliseconds: 350),
  });

  final int index;
  final List<Widget> children;

  /// Interruptor global de la precarga. Las pruebas lo apagan en
  /// `flutter_test_config.dart`: una pestaña precargada a mitad de una
  /// prueba de otra cosa solo añade trabajo y temporizadores ajenos. Las
  /// pruebas de la precarga lo encienden a mano.
  static bool precargaGlobal = true;

  /// Si se precargan de fondo las pestañas no visitadas.
  final bool precargar;

  /// Orden de la precarga por índice. Nulo = en orden de aparición. Los
  /// índices ya visitados se saltan.
  final List<int>? ordenPrecarga;

  /// Cuánto esperar tras el primer cuadro antes de precargar la primera.
  final Duration retardoPrecarga;

  /// Separación entre una precarga y la siguiente.
  final Duration pausaPrecarga;

  @override
  State<AnimatedTabStack> createState() => _AnimatedTabStackState();
}

class _AnimatedTabStackState extends State<AnimatedTabStack> {
  /// Pestañas ya montadas (visitadas o precargadas): las demás no se
  /// construyen (pintan un hueco cero) y una vez montadas quedan para
  /// siempre.
  final Set<int> _montadas = {};

  Timer? _temporizador;
  final List<int> _cola = [];

  @override
  void initState() {
    super.initState();
    _montadas.add(widget.index);
    if (widget.precargar && AnimatedTabStack.precargaGlobal) {
      final orden = widget.ordenPrecarga ??
          List<int>.generate(widget.children.length, (i) => i);
      _cola.addAll(
        orden.where((i) => i >= 0 && i < widget.children.length),
      );
      _temporizador = Timer(widget.retardoPrecarga, _precargarSiguiente);
    }
  }

  @override
  void didUpdateWidget(AnimatedTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _montadas.add(widget.index);
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  void _precargarSiguiente() {
    if (!mounted) return;
    while (_cola.isNotEmpty && _montadas.contains(_cola.first)) {
      _cola.removeAt(0);
    }
    if (_cola.isEmpty) return;
    final siguiente = _cola.removeAt(0);
    setState(() => _montadas.add(siguiente));
    _temporizador = Timer(widget.pausaPrecarga, _precargarSiguiente);
  }

  @override
  Widget build(BuildContext context) {
    final sinAnimacion = context.animationsDisabled;
    final duracion = sinAnimacion ? Duration.zero : AppMotion.fast;
    // Una pila dentro de otra (las dos caras de Académico): solo está a la
    // vista si también lo está la pestaña que la contiene.
    final padreVisible = PestanaVisible.de(context);
    return Stack(
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (!_montadas.contains(i))
            const SizedBox.shrink()
          else
            PestanaVisible(
              visible: padreVisible && i == widget.index,
              child: TickerMode(
                enabled: i == widget.index,
                child: Offstage(
                  offstage: i != widget.index,
                  child: IgnorePointer(
                    ignoring: i != widget.index,
                    child: RepaintBoundary(
                      child: AnimatedOpacity(
                        opacity: i == widget.index ? 1.0 : 0.0,
                        duration: duracion,
                        curve: AppMotion.enter,
                        child: AnimatedSlide(
                          // Acompaña al fundido sin parecer un cambio de
                          // página: dos centésimas de alto hacia abajo al
                          // salir. Nunca lateral.
                          offset: i == widget.index
                              ? Offset.zero
                              : const Offset(0, 0.02),
                          duration: duracion,
                          curve: AppMotion.enter,
                          child: widget.children[i],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// Dice a lo que vive dentro de una pestaña si esa pestaña está a la vista.
///
/// Fuera de una [AnimatedTabStack] (una pantalla apilada, una hoja, una
/// prueba) no hay ninguna publicada y [de] devuelve `true`: lo que no está
/// en una pestaña siempre está a la vista.
///
/// Úsalo para lo que debe esperar a la primera visita: entradas
/// escalonadas (ya lo hace [EntradaEscalonada]), contadores que cuentan,
/// cargas de red que no deben salir con la pestaña precargada.
class PestanaVisible extends InheritedWidget {
  const PestanaVisible({
    super.key,
    required this.visible,
    required super.child,
  });

  final bool visible;

  /// `true` si la pestaña que contiene a [context] está a la vista (o si no
  /// hay pestaña). Registra la dependencia: quien lo lea se reconstruye al
  /// cambiar.
  static bool de(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<PestanaVisible>()
            ?.visible ??
        true;
  }

  @override
  bool updateShouldNotify(PestanaVisible oldWidget) =>
      visible != oldWidget.visible;
}
