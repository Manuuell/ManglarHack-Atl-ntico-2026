/// Hoja modal al estilo iOS 15: sube desde abajo sobre un velo, se arrastra
/// hacia abajo para cerrar y devuelve su resultado al cerrarse.
///
/// La hoja entra con deslizamiento inferior durante [AppMotion.slow] con
/// curva [AppMotion.enter] sobre el velo (`context.colors.scrim`, que sí
/// sigue al modo claro/oscuro); la salida dura [AppMotion.normal] con
/// [AppMotion.exit]. El contenido visual de la hoja (fondo, radio superior,
/// asa, botón de cerrar) lo pone quien la abre —igual que con
/// `showModalBottomSheet`— para no envolver dos veces a las hojas que ya
/// existen (detalle del ticket, carné ampliado, hoja de edición).
///
/// El cierre por arrastre mira la **velocidad**, no solo la distancia: un
/// gesto corto y rápido cierra ([velocidadMinimaCierre]); uno largo y lento
/// que se devuelve antes de soltar, no. La decisión se toma al soltar.
///
/// Con movimiento reducido no hay animación intermedia (aparece y
/// desaparece de golpe), pero la navegación sigue funcionando igual:
/// abrir, cerrar por arrastre, cerrar tocando el velo y devolver el
/// resultado.
///
/// Efecto iOS 15 completo: que la pantalla de abajo se encoja mientras la
/// hoja sube lo pone la ruta de abajo reaccionando a su `secondaryAnimation`
/// con `PantallaDetras` (`pantalla_detras.dart`, del mismo `core/navigation/`);
/// todas las rutas propias ya lo envuelven, así que abrir esta hoja sobre
/// ellas encoge la de detrás un 3 % sin código extra en quien la abre.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'tokens.dart';
import 'movimiento.dart';

/// Hoja modal arrastrable con resultado.
///
/// ```dart
/// import 'package:zanky/core/navigation/ruta_hoja_modal.dart';
///
/// final elegido = await mostrarHojaModal<String>(
///   context,
///   nombre: 'SelectorCategoria',
///   builder: (_) => const _ContenidoHoja(),
/// );
/// ```
class RutaHojaModal<T> extends PageRouteBuilder<T> {
  /// Velocidad de soltura (píxeles lógicos por segundo, hacia abajo) que
  /// cierra la hoja aunque el arrastre haya sido corto.
  ///
  /// Un gesto corto y rápido supera este valor y cierra; uno lento queda muy
  /// por debajo y solo cierra si además se soltó lejos
  /// (ver [fraccionCierrePorArrastre]).
  static const double velocidadMinimaCierre = 700;

  /// Fracción de la altura de la pantalla que hay que haber arrastrado hacia
  /// abajo al soltar para que la hoja cierre por distancia (gesto lento).
  ///
  /// El gesto que se devuelve antes de soltar termina cerca de cero y por
  /// eso no cierra, por largo que haya sido el paseo intermedio.
  static const double fraccionCierrePorArrastre = 0.25;

  /// Crea la ruta. [builder] dibuja el contenido de la hoja.
  ///
  /// Con [areaSeguraAbajo] la ruta deja libre la barra del sistema bajo la
  /// hoja (lo que quieren las hojas flotantes, como la de acciones). La
  /// hoja de superficie entera (`HojaZ`) la pide en falso y se encarga
  /// ella: su fondo llega al borde y el contenido queda por encima.
  RutaHojaModal({
    required WidgetBuilder builder,
    bool areaSeguraAbajo = true,
    super.settings,
    super.allowSnapshotting = true,
  }) : super(
          // Sin barrera propia de la ruta, **a proposito**.
          //
          // [_VeloHoja] ya es la barrera: se dibuja por encima con
          // `HitTestBehavior.opaque`, se lleva todos los toques y trae su
          // propia semantica. Declarar ademas `barrierDismissible: true`
          // con `barrierLabel` metia una segunda barrera que nadie podia
          // tocar y que solo servia para que el lector de pantalla
          // anunciara lo mismo dos veces. Todas las demas rutas de la app
          // (las de fundido y detalle) ya van con
          // `barrierDismissible: false`; esta era la excepcion.
          barrierDismissible: false,
          // Transparente: lo de abajo sigue visible tras el velo que pinta
          // [_PaginaHoja] con `context.colors.scrim`. El color de la barrera
          // no admite contexto, así que el velo propio (tematizado) es el
          // que se ve y el que cierra al tocarlo.
          opaque: false,
          transitionDuration: AppMotion.slow,
          reverseTransitionDuration: AppMotion.normal,
          pageBuilder: (context, animation, _) =>
              _PaginaHoja(
            animacion: animation,
            builder: builder,
            areaSeguraAbajo: areaSeguraAbajo,
          ),
        );
}

/// Abre una [RutaHojaModal] y completa con el resultado que la hoja devuelva
/// (`Navigator.pop(context, valor)` desde su contenido) o con nulo si se
/// cerró arrastrando, tocando el velo o con el botón de atrás.
///
/// [nombre] nombra la ruta (`RouteSettings.name`) para que el
/// [ObservadorRutas] y el diagnóstico sepan qué pantalla se veía.
Future<T?> mostrarHojaModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? nombre,
  bool areaSeguraAbajo = true,
}) {
  return Navigator.of(context).push<T>(
    RutaHojaModal<T>(
      builder: builder,
      areaSeguraAbajo: areaSeguraAbajo,
      settings: nombre == null ? null : RouteSettings(name: nombre),
    ),
  );
}

/// Página de la hoja: velo de fondo + hoja alineada abajo.
///
/// Con movimiento reducido no hay fundido ni deslizamiento: la hoja aparece
/// de golpe y sigue cerrándose igual.
class _PaginaHoja extends StatefulWidget {
  const _PaginaHoja({
    required this.animacion,
    required this.builder,
    required this.areaSeguraAbajo,
  });

  final Animation<double> animacion;
  final WidgetBuilder builder;
  final bool areaSeguraAbajo;

  @override
  State<_PaginaHoja> createState() => _PaginaHojaState();
}

class _PaginaHojaState extends State<_PaginaHoja> {
  /// Cuánto ha bajado la hoja con el dedo (px). El velo lo lee para aclararse
  /// a la par: la hoja y el fondo se mueven como una sola cosa.
  final ValueNotifier<double> _arrastre = ValueNotifier(0);

  @override
  void dispose() {
    _arrastre.dispose();
    super.dispose();
  }

  void _cerrar(BuildContext context) {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final velo = context.colors.scrim;
    final hoja = RepaintBoundary(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          top: false,
          bottom: widget.areaSeguraAbajo,
          child: _HojaArrastrable(
            arrastre: _arrastre,
            child: Builder(builder: widget.builder),
          ),
        ),
      ),
    );
    if (context.animationsDisabled) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _VeloHoja(color: velo, alCerrar: () => _cerrar(context), arrastre: _arrastre),
          hoja,
        ],
      );
    }
    final curva = CurvedAnimation(
      parent: widget.animacion,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        _VeloHoja(
          color: velo,
          alCerrar: () => _cerrar(context),
          opacidad: curva,
          arrastre: _arrastre,
        ),
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curva),
          child: hoja,
        ),
      ],
    );
  }
}

/// Velo de fondo: oscurece lo de abajo y cierra la hoja al tocarlo.
///
/// Es un gesto del sistema (área de descarte a pantalla completa, sin estado
/// de presión), no un botón visible: por eso usa `GestureDetector` directo
/// igual que la franja de volver de `card_detail_route.dart`, y no
/// `Pressable` (comprimir el velo al tocarlo se vería roto). Para el lector
/// de pantalla se anuncia como botón «Cerrar».
class _VeloHoja extends StatelessWidget {
  const _VeloHoja({
    required this.color,
    required this.alCerrar,
    required this.arrastre,
    this.opacidad,
  });

  final Color color;
  final VoidCallback alCerrar;

  /// Cuánto bajó la hoja con el dedo: aclara el velo en proporción.
  final ValueListenable<double> arrastre;

  /// Nula → velo opaco del todo (movimiento reducido, sin fundido).
  final Animation<double>? opacidad;

  /// Con este arrastre el velo ya es invisible.
  static const double _arrastreSinVelo = 420;

  @override
  Widget build(BuildContext context) {
    // El color cambia por cuadro (pintura), no la opacidad de un subárbol: no
    // hay `saveLayer` mientras se arrastra.
    final fondo = AnimatedBuilder(
      animation: Listenable.merge([arrastre, ?opacidad]),
      builder: (context, _) {
        final base = opacidad?.value ?? 1.0;
        final suelta = 1 - (arrastre.value / _arrastreSinVelo).clamp(0.0, 1.0);
        return ColoredBox(color: color.withValues(alpha: color.a * base * suelta));
      },
    );
    return Positioned.fill(
      child: Semantics(
        button: true,
        // «Descartar» y no «Cerrar»: la cabecera de la hoja ya ofrece un
        // boton «Cerrar», y dos botones con la misma etiqueta dejan al
        // lector de pantalla anunciando lo mismo dos veces sin poder
        // distinguirlos. Es la misma palabra que usa Material para su
        // propio velo.
        label: 'Descartar',
        onTap: alCerrar,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: alCerrar,
          child: RepaintBoundary(child: fondo),
        ),
      ),
    );
  }
}

/// Envuelve el contenido de la hoja con el arrastre vertical para cerrar.
///
/// La hoja sigue al dedo mientras baja (nunca sube por encima de su sitio)
/// con resistencia progresiva: cuanto más baja, más cuesta seguir bajando,
/// como la tarjeta de iOS. Al soltar decide: cierra si la velocidad hacia
/// abajo supera [RutaHojaModal.velocidadMinimaCierre] o si se soltó más allá
/// de [RutaHojaModal.fraccionCierrePorArrastre] de la pantalla; si no,
/// vuelve a su sitio. Cerrar por arrastre sale sin resultado (nulo), como
/// el velo.
///
/// Sin `saveLayer`: solo un [Transform.translate] dentro del
/// [RepaintBoundary] de la página.
class _HojaArrastrable extends StatefulWidget {
  const _HojaArrastrable({required this.child, required this.arrastre});

  final Widget child;

  /// Se actualiza con lo que ha bajado la hoja (lo lee el velo).
  final ValueNotifier<double> arrastre;

  @override
  State<_HojaArrastrable> createState() => _HojaArrastrableState();
}

/// Distancia de arrastre a la que la resistencia ya recorta el avance a la
/// mitad: con 350 px bajados, cada píxel de dedo mueve la hoja medio píxel.
const double _distanciaResistencia = 350;

/// Hacia arriba, la hoja cede un poco (como el elástico de iOS) y vuelve.
const double _cedeArriba = 14;

class _HojaArrastrableState extends State<_HojaArrastrable>
    with SingleTickerProviderStateMixin {
  /// Posición de la hoja (px, hacia abajo). Sin límites: lo mueve el dedo y,
  /// al soltar, un resorte que conserva la velocidad del gesto.
  late final AnimationController _pos = AnimationController.unbounded(vsync: this)
    ..addListener(_alMoverse);

  double get _arrastre => _pos.value;

  void _alMoverse() => widget.arrastre.value = _pos.value < 0 ? 0 : _pos.value;

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  void _alEmpezar(DragStartDetails details) {
    _pos.stop();
    // Con el teclado arriba, arrastrar la hoja lo baja (como en iOS): la hoja
    // no se queda a media pantalla con el teclado tapándola.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _alMover(DragUpdateDetails details) {
    _pos.stop();
    final delta = details.delta.dy;
    final actual = _arrastre;
    if (delta <= 0) {
      // Subir: libre hasta su sitio y, pasado eso, con mucha resistencia.
      final siguiente = actual + (actual > 0 ? delta : delta * 0.25);
      _pos.value = siguiente < -_cedeArriba ? -_cedeArriba : siguiente;
      return;
    }
    final resistencia = actual < 0 ? 1.0 : 1 / (1 + actual / _distanciaResistencia);
    _pos.value = actual + delta * resistencia;
  }

  void _alSoltar(DragEndDetails details) {
    final velocidad = details.primaryVelocity ?? 0;
    final umbral = MediaQuery.sizeOf(context).height *
        RutaHojaModal.fraccionCierrePorArrastre;
    if (velocidad > RutaHojaModal.velocidadMinimaCierre ||
        _arrastre > umbral) {
      Navigator.of(context).maybePop();
      return;
    }
    if (context.animationsDisabled) {
      _pos.value = 0;
      return;
    }
    // Vuelve a su sitio con el resorte suave y la velocidad con que se soltó.
    _pos.animateWith(
      SpringSimulation(AppMotion.resorteSuave, _arrastre, 0, velocidad),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Translúcido: los toques siguen llegando al contenido (botones,
      // campos) y solo el arrastre vertical lo reclama esta capa.
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: _alEmpezar,
      onVerticalDragUpdate: _alMover,
      onVerticalDragEnd: _alSoltar,
      child: AnimatedBuilder(
        animation: _pos,
        // El contenido no se reconstruye por cuadro: solo se traslada.
        child: widget.child,
        builder: (context, hijo) => Transform.translate(
          offset: Offset(0, _pos.value),
          child: hijo,
        ),
      ),
    );
  }
}
