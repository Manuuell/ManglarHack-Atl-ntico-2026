/// Sistema de movimiento de la app: la única fuente de tiempos, curvas y
/// resortes para que cada transición y micro-interacción se sienta igual en
/// toda la app. Nada de duraciones ni curvas inventadas a ojo en pantallas.
///
/// Tabla de qué usar cuándo:
/// | Situación | Token |
/// |---|---|
/// | Entrada de lista (cada fila aparece por turno) | `EntradaEscalonada` / `StaggeredEntry` + `context.staggerDelay(i)` (60 ms, tope 6) |
/// | Elemento que debe aparecer al entrar en pantalla en una lista larga | `AparicionPorVisibilidad` (dispara la entrada al volverse visible) |
/// | Cambio de estado de un control (chip, selección) | `AppMotion.micro` (90 ms) + curva `press`/`enter` |
/// | Gesto que sigue al dedo en superficies grandes (hojas, tarjetas) | `AppMotion.resorteSuave` con `SpringSimulation` |
/// | Control pequeño con física (paso, interruptor) | `AppMotion.resorteFirme` con `SpringSimulation` |
/// | Acuse de recibo de una acción (éxito, favorito) | `AppMotion.resorteRebote` con `SpringSimulation` |
/// | Número vivo que cuenta (saldo, promedio) | `ContadorAnimado` + `AppMotion.deliberada` (600 ms) |
/// | Transición de pantalla propia | `AppMotion.screenTransition` (300 ms) + `screenCurve` |
/// | Carga con la forma del contenido | `AppMotion.shimmer` (1100 ms) en `Skeleton` |
///
/// Ejemplo con resorte (sin paquetes nuevos, física del SDK):
/// ```dart
/// controlador.animateWith(
///   SpringSimulation(AppMotion.resorteSuave, inicio, fin, velocidad),
/// );
/// ```

library;
import 'package:flutter/material.dart';

/// Centralized animation timing so every transition/micro-interaction in the
/// app feels consistent instead of ad-hoc per widget.
///
/// Curvas coherentes con iOS: las entradas usan `easeOut` (salida rápida,
/// llegada suave — "más salida que entrada"), las salidas `easeIn`, y el
/// presionado un `easeOut` corto sin rebote. Nada de `Curves.linear` ni
/// duraciones inventadas a ojo: toda animación sale de aquí.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration shimmer = Duration(milliseconds: 1100);

  /// Cambio de estado de un control (chip que se activa, fila que se
  /// selecciona): ~90 ms. Más corto que [fast] para responder al instante,
  /// pero con duración real para no parpadear.
  static const Duration micro = Duration(milliseconds: 90);

  /// Algo que el ojo debe seguir, como un número que cuenta hacia arriba
  /// ([ContadorAnimado]): ~600 ms con curva de entrada. Más largo que [slow]
  /// a propósito: si dura menos, el conteo no se lee.
  static const Duration deliberada = Duration(milliseconds: 600);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve press = Curves.easeOut;

  /// Lo que **brota** de un punto y se asienta pasándose un poco: el menú
  /// contextual que sale del elemento mantenido, una insignia que aparece.
  /// Es la única curva con sobrepaso de la app; no la uses para entradas de
  /// lista ni para transiciones de pantalla, donde el rebote distrae.
  static const Curve emergente = Curves.easeOutBack;

  /// Scale factor for the "pressed" state of tappable surfaces — iOS
  /// controls compress slightly on touch-down rather than showing a ripple.
  static const double pressScale = 0.97;

  // Los resortes copian una tabla de resortes medida en un proyecto anterior,
  // afinada cuatro veces con su dueño, que pidió tres veces lo mismo: «los
  // rebotes tardan mucho en asentarse». La razón de amortiguación
  // (damping / 2·√(stiffness·mass)) manda: 1,0 no se pasa, 0,86 se pasa un
  // 0,5 %, 0,78 un 2 %. Todos asientan entre 0,2 y 0,3 s. Antes había un
  // rebote de razón 0,40 que tardaba más de medio segundo en quedarse
  // quieto: eso es lo que se siente «forzado».

  /// Resorte suave para lo que sigue al dedo en superficies grandes: hojas
  /// modales y tarjetas arrastrables. Críticamente amortiguado (razón 1,0):
  /// con hojas altas cualquier sobrepaso se ve como un rebote al llegar.
  static const SpringDescription resorteSuave = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 40,
  );

  /// Resorte firme para controles pequeños (pasos, interruptores,
  /// selectores, píldoras): razón 0,86, se pasa un pelo y asienta en
  /// ~0,22 s. Es el resorte por defecto.
  static const SpringDescription resorteFirme = SpringDescription(
    mass: 1,
    stiffness: 390,
    damping: 34,
  );

  /// Resorte con un rebote leve para el acuse de recibo de una acción
  /// (éxito, favorito, insignia que aparece): razón 0,78, ~2 % de
  /// sobrepaso. Celebra sin quedarse temblando. No lo uses en entradas de
  /// lista ni en gestos.
  static const SpringDescription resorteRebote = SpringDescription(
    mass: 1,
    stiffness: 370,
    damping: 30,
  );

  /// Lo que hace [Pressable] al soltar: razón 0,83, vuelve en ~0,2 s.
  static const SpringDescription resortePresion = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 34,
  );

  /// Ventanas flotantes que brotan (diálogo, menú contextual, desplegable):
  /// razón 0,88, un «pop» de iOS sin cola de rebote.
  static const SpringDescription resorteEmergente = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 36,
  );

  /// Lo que tarda en hundirse algo tocable: 80 ms, menos que [micro], para
  /// que la respuesta llegue antes de que el dedo se levante.
  static const Duration presion = Duration(milliseconds: 80);

  /// Paso del escalonado en entradas de lista: 60 ms, tope del rango iOS
  /// corto (40–60 ms). Estandariza los `60 * index` repartidos hoy por
  /// Noticias/Inicio/Soporte y el `fast * 0.4 * index` del Horario, que
  /// equivalen a lo mismo.
  static const Duration staggerStep = Duration(milliseconds: 60);

  /// Tope de elementos escalonados: a partir de aquí todos comparten el
  /// retardo máximo para que una lista larga no tarde más de ~360 ms en
  /// completar su entrada. El movimiento comunica jerarquía (primero lo
  /// importante), no es animación gratuita.
  static const int staggerCap = 6;

  /// Retardo de entrada para el elemento [index] de una lista, con tope en
  /// [staggerCap]. Envolvente con [AppMotionAccess.staggerDelay] para
  /// respetar movimiento reducido.
  static Duration stagger(int index) {
    final capped = index < 0 ? 0 : (index > staggerCap ? staggerCap : index);
    return staggerStep * capped;
  }

  /// Transición entre pantallas para animaciones propias (la navegación por
  /// defecto ya usa `CupertinoPageTransitionsBuilder` en las cinco
  /// plataformas vía `AppTheme`). 300 ms con curva de entrada: la pantalla
  /// nueva entra con intención, sin rebotes baratos.
  static const Duration screenTransition = Duration(milliseconds: 300);
  static const Curve screenCurve = Curves.easeOutCubic;
}

/// Acceso a movimiento con respeto a accesibilidad.
///
/// Forma correcta de consultar movimiento reducido (única válida en la app):
/// ```dart
/// if (context.animationsDisabled) return child;
/// return child.animate().fadeIn(delay: context.staggerDelay(index));
/// ```
/// Por qué `disableAnimationsOf` y no `MediaQuery.of(context)`: el accesor
/// dedicado solo escucha ese flag en vez de reconstruir con cualquier cambio
/// del `MediaQuery`. Rendimiento a 60 fps: en listas largas no se anima
/// `Opacity` ni `BackdropFilter`; se usa `AnimatedOpacity`/`FadeTransition`
/// y `RepaintBoundary` donde corresponda (ver `skeleton.dart`).
extension AppMotionAccess on BuildContext {
  /// `true` cuando el sistema pide movimiento reducido
  /// (`MediaQuery.disableAnimations`).
  bool get animationsDisabled => MediaQuery.disableAnimationsOf(this);

  bool get animationsEnabled => !animationsDisabled;

  /// Devuelve [duration] o cero si hay movimiento reducido. Úsalo en cada
  /// `Animated*`/`animate()` propio.
  Duration resolveDuration(Duration duration) =>
      animationsDisabled ? Duration.zero : duration;

  /// [AppMotion.stagger] o cero si hay movimiento reducido.
  Duration staggerDelay(int index) =>
      animationsDisabled ? Duration.zero : AppMotion.stagger(index);
}

/// Número que cuenta de un valor a otro con [AppMotion.deliberada]: lo que
/// hace que un saldo o un promedio se sienta vivo sin ser un adorno.
///
/// El [formato] es inyectable para reusar los formatos reales de
/// `lib/core/i18n/formatos.dart` (p. ej. `formatearPeso`, `formatearNota`):
///
/// ```dart
/// ContadorAnimado(valor: saldo, formato: formatearPeso)
/// ContadorAnimado(valor: promedio, formato: formatearNota)
/// ```
///
/// Sin [formato] se muestra el valor crudo. Con movimiento reducido no hay
/// animación: se muestra el valor final directamente.
class ContadorAnimado extends StatefulWidget {
  const ContadorAnimado({
    super.key,
    required this.valor,
    this.valorInicial = 0,
    this.formato,
    this.duracion = AppMotion.deliberada,
    this.estilo,
  });

  /// Valor final: lo que queda pintado al terminar la animación.
  final double valor;

  /// Valor desde el que cuenta la primera vez que aparece. Cuando [valor]
  /// cambia después, la animación parte del valor anterior, no de este.
  final double valorInicial;

  /// Cómo se pinta cada valor intermedio y el final. Recibe el número crudo
  /// y devuelve el texto visible.
  final String Function(double)? formato;

  /// Duración del conteo. Por defecto [AppMotion.deliberada].
  final Duration duracion;

  /// Estilo del texto. Nulo = estilo por defecto del tema.
  final TextStyle? estilo;

  @override
  State<ContadorAnimado> createState() => _ContadorAnimadoState();
}

class _ContadorAnimadoState extends State<ContadorAnimado> {
  late double _origen;

  static String _crudo(double valor) => valor.toString();

  @override
  void initState() {
    super.initState();
    _origen = widget.valorInicial;
  }

  @override
  void didUpdateWidget(ContadorAnimado oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valor != widget.valor) {
      _origen = oldWidget.valor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pintar = widget.formato ?? _crudo;
    if (context.animationsDisabled) {
      return Text(pintar(widget.valor), style: widget.estilo);
    }
    // El lector de pantalla oye solo el valor final: sin esto leía los
    // números de paso («1, 2, 3…») mientras el conteo corría.
    return Semantics(
      label: pintar(widget.valor),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: _origen, end: widget.valor),
        duration: widget.duracion,
        curve: AppMotion.enter,
        builder: (context, actual, _) =>
            Text(pintar(actual), style: widget.estilo),
        onEnd: () => _origen = widget.valor,
      ),
    );
  }
}
