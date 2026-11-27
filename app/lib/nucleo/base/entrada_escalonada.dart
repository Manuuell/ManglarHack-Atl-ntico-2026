import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'transicion_pestanas.dart';
import 'movimiento.dart';

/// Entrada escalonada compartida para listas: fundido + leve deslizamiento
/// vertical, con 50 ms entre elementos (derivado de [AppMotion.fast], dentro
/// del rango 40–60 ms del brief) y tope para no acumular esperas en listas
/// largas.
///
/// Respeta `MediaQuery.disableAnimations`: con animaciones desactivadas
/// devuelve [child] sin envolverlo en nada.
///
/// Uso en `itemBuilder` / bucles:
///
/// ```dart
/// StaggeredEntry(
///   index: index,
///   child: _MiFila(dato: datos[index]),
/// )
/// ```
///
/// Para pantallas que ya encadenan `.animate()` a mano, [delayFor] expone el
/// mismo cálculo de retardo para migrar sin cambiar el ritmo:
///
/// ```dart
/// .fadeIn(delay: StaggeredEntry.delayFor(index))
/// ```
class StaggeredEntry extends StatelessWidget {
  const StaggeredEntry({
    super.key,
    required this.index,
    required this.child,
  });

  /// Posición del elemento en la lista (0 = lo más importante, aparece primero).
  final int index;

  final Widget child;

  /// Tope de escalonado: a partir de aquí el retardo ya no crece, para que
  /// una lista de 50 no espere segundos antes de mostrar la cola.
  static const int maxStaggerIndex = 6;

  /// Retardo por elemento derivado del token [AppMotion.fast] (150 ~/ 3 = 50 ms).
  static Duration delayFor(int index) {
    final capped = index.clamp(0, maxStaggerIndex);
    return AppMotion.fast * (capped / 3.0);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final delay = delayFor(index);
    return child
        .animate()
        .fadeIn(duration: AppMotion.normal, delay: delay, curve: AppMotion.enter)
        .slideY(
          begin: 0.04,
          end: 0,
          duration: AppMotion.normal,
          delay: delay,
          curve: AppMotion.enter,
        );
  }
}

/// Dirección de entrada de [EntradaEscalonada]: una tira horizontal no debe
/// entrar deslizando en vertical, y un icono no necesita deslizar nada.
enum DireccionEntrada {
  /// Desde abajo, la de hoy: listas verticales.
  abajo,

  /// Desde el lado: tiras horizontales y carruseles.
  lado,

  /// Fundido + escala leve: iconos, insignias y acusos de recibo.
  escala,
}

/// Entrada escalonada con dirección: fundido + desplazamiento según
/// [direccion], con el retardo canónico de [AppMotion.stagger] (60 ms, tope
/// 6) vía `context.staggerDelay`.
///
/// Diferencia con [StaggeredEntry], que se conserva tal cual por
/// compatibilidad: ese usa su propio `delayFor` de 50 ms. No mezcles ambos
/// en la misma lista; el código nuevo usa este.
///
/// Con movimiento reducido devuelve [child] sin envolverlo en nada.
///
/// ```dart
/// EntradaEscalonada(index: index, child: _MiFila(...))
/// EntradaEscalonada.lado(index: index, child: _TarjetaTira(...))
/// EntradaEscalonada.escala(index: 0, child: _Insignia(...))
/// ```
class EntradaEscalonada extends StatelessWidget {
  const EntradaEscalonada({
    super.key,
    required this.index,
    required this.child,
    this.direccion = DireccionEntrada.abajo,
  });

  /// Variante desde abajo (listas verticales): la entrada de siempre.
  const EntradaEscalonada.abajo({
    Key? key,
    required int index,
    required Widget child,
  }) : this(
          key: key,
          index: index,
          child: child,
          direccion: DireccionEntrada.abajo,
        );

  /// Variante desde el lado (tiras horizontales y carruseles).
  const EntradaEscalonada.lado({
    Key? key,
    required int index,
    required Widget child,
  }) : this(
          key: key,
          index: index,
          child: child,
          direccion: DireccionEntrada.lado,
        );

  /// Variante con escala (iconos, insignias, acusos de recibo).
  const EntradaEscalonada.escala({
    Key? key,
    required int index,
    required Widget child,
  }) : this(
          key: key,
          index: index,
          child: child,
          direccion: DireccionEntrada.escala,
        );

  /// Posición del elemento en la lista (0 = lo más importante, aparece primero).
  final int index;

  final Widget child;

  /// De dónde viene el elemento al entrar. Por defecto [DireccionEntrada.abajo].
  final DireccionEntrada direccion;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return _EntradaAnimada(
      retardo: context.staggerDelay(index),
      direccion: direccion,
      child: child,
    );
  }
}

/// La entrada de verdad: un controlador propio con el retardo DENTRO de la
/// curva (`Interval`), no un temporizador aparte.
///
/// `flutter_animate` programa un `Future.delayed` por cada entrada (aunque
/// el retardo sea cero) que no se cancela al desmontar: en listas largas son
/// decenas de temporizadores vivos y las pruebas lo detectaban al terminar.
class _EntradaAnimada extends StatefulWidget {
  const _EntradaAnimada({
    required this.retardo,
    required this.direccion,
    required this.child,
  });

  final Duration retardo;
  final DireccionEntrada direccion;
  final Widget child;

  @override
  State<_EntradaAnimada> createState() => _EntradaAnimadaState();
}

class _EntradaAnimadaState extends State<_EntradaAnimada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control;
  late final Animation<double> _curva;

  @override
  void initState() {
    super.initState();
    final total = widget.retardo + AppMotion.normal;
    final inicio = total.inMicroseconds == 0
        ? 0.0
        : widget.retardo.inMicroseconds / total.inMicroseconds;
    _control = AnimationController(vsync: this, duration: total);
    _curva = CurvedAnimation(
      parent: _control,
      curve: Interval(inicio, 1, curve: AppMotion.enter),
    );
  }

  /// Arranca la entrada solo con la pestaña a la vista: una pestaña
  /// precargada de fondo guarda su cola de entrada para la primera visita.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_control.status == AnimationStatus.dismissed &&
        !_control.isAnimating &&
        PestanaVisible.de(context)) {
      _control.forward();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget movido;
    switch (widget.direccion) {
      case DireccionEntrada.abajo:
        movido = SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
              .animate(_curva),
          child: widget.child,
        );
      case DireccionEntrada.lado:
        movido = SlideTransition(
          position: Tween(begin: const Offset(0.04, 0), end: Offset.zero)
              .animate(_curva),
          child: widget.child,
        );
      case DireccionEntrada.escala:
        movido = ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(_curva),
          child: widget.child,
        );
    }
    return FadeTransition(opacity: _curva, child: movido);
  }
}

class AparicionPorVisibilidad extends StatefulWidget {
  const AparicionPorVisibilidad({
    super.key,
    required this.child,
    this.controlador,
    this.direccion = DireccionEntrada.abajo,
  });

  final Widget child;

  /// Controlador de la lista donde vive el elemento. Opcional: si se omite
  /// se usa el desplazable ambiente. Sirve también para mover la lista en
  /// pruebas (`jumpTo`) y comprobar la aparición.
  final ScrollController? controlador;

  /// Dirección de la entrada una vez visible.
  final DireccionEntrada direccion;

  @override
  State<AparicionPorVisibilidad> createState() =>
      _AparicionPorVisibilidadState();
}

class _AparicionPorVisibilidadState extends State<AparicionPorVisibilidad> {
  bool _visible = false;
  ScrollPosition? _escuchada;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _comprobar());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resuscribir();
  }

  @override
  void didUpdateWidget(AparicionPorVisibilidad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controlador != widget.controlador) _resuscribir();
  }

  ScrollPosition? get _posicion {
    final externo = widget.controlador;
    if (externo != null && externo.hasClients) return externo.position;
    return Scrollable.maybeOf(context)?.position;
  }

  void _resuscribir() {
    final actual = _posicion;
    if (identical(actual, _escuchada)) return;
    _escuchada?.removeListener(_alDesplazar);
    _escuchada = actual;
    if (!_visible) _escuchada?.addListener(_alDesplazar);
  }

  void _alDesplazar() => _comprobar();

  void _comprobar() {
    if (!mounted || _visible) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    if (_estaEnPantalla()) {
      setState(() => _visible = true);
      _escuchada?.removeListener(_alDesplazar);
      _escuchada = null;
    }
  }

  bool _estaEnPantalla() {
    final render = context.findRenderObject() as RenderBox?;
    if (render == null || !render.attached || !render.hasSize) return false;
    final posicion = _posicion;
    if (posicion == null || !posicion.hasViewportDimension) return true;
    final viewport = RenderAbstractViewport.maybeOf(render);
    if (viewport == null) return true;
    try {
      final revelado = viewport.getOffsetToReveal(render, 0.0);
      final inicio = revelado.offset;
      final pixeles = posicion.pixels;
      final finVisible = pixeles + posicion.viewportDimension;
      final esVertical =
          axisDirectionToAxis(posicion.axisDirection) == Axis.vertical;
      final largo = esVertical ? render.size.height : render.size.width;
      return inicio < finVisible && inicio + largo > pixeles;
    } catch (_) {
      return true;
    }
  }

  @override
  void dispose() {
    _escuchada?.removeListener(_alDesplazar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    if (!_visible) {
      return Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: widget.child,
      );
    }
    return EntradaEscalonada(
      index: 0,
      direccion: widget.direccion,
      child: widget.child,
    );
  }
}
