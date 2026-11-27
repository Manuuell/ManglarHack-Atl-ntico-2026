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

import 'package:flutter/material.dart';

import 'tokens.dart';
import 'movimiento.dart';

/// Hoja modal arrastrable con resultado.
///
/// ```dart
/// import 'package:zanqui/core/navigation/ruta_hoja_modal.dart';
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
class _PaginaHoja extends StatelessWidget {
  const _PaginaHoja({
    required this.animacion,
    required this.builder,
    required this.areaSeguraAbajo,
  });

  final Animation<double> animacion;
  final WidgetBuilder builder;
  final bool areaSeguraAbajo;

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
          bottom: areaSeguraAbajo,
          child: _HojaArrastrable(child: Builder(builder: builder)),
        ),
      ),
    );
    if (context.animationsDisabled) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _VeloHoja(color: velo, alCerrar: () => _cerrar(context)),
          hoja,
        ],
      );
    }
    final curva = CurvedAnimation(
      parent: animacion,
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
    this.opacidad,
  });

  final Color color;
  final VoidCallback alCerrar;

  /// Nula → velo opaco del todo (movimiento reducido, sin fundido).
  final Animation<double>? opacidad;

  @override
  Widget build(BuildContext context) {
    final velo = ColoredBox(color: color);
    final fondo = opacidad == null
        ? velo
        : FadeTransition(opacity: opacidad!, child: velo);
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
  const _HojaArrastrable({required this.child});

  final Widget child;

  @override
  State<_HojaArrastrable> createState() => _HojaArrastrableState();
}

/// Distancia de arrastre a la que la resistencia ya recorta el avance a la
/// mitad: con 350 px bajados, cada píxel de dedo mueve la hoja medio píxel.
const double _distanciaResistencia = 350;

class _HojaArrastrableState extends State<_HojaArrastrable>
    with SingleTickerProviderStateMixin {
  double _arrastre = 0;
  late final AnimationController _retroceso;
  late final CurvedAnimation _curvaRetroceso;
  double _origenRetroceso = 0;

  @override
  void initState() {
    super.initState();
    _retroceso = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
    );
    _curvaRetroceso = CurvedAnimation(
      parent: _retroceso,
      curve: AppMotion.enter,
    )..addListener(_alRetroceder);
  }

  @override
  void dispose() {
    _curvaRetroceso.dispose();
    _retroceso.dispose();
    super.dispose();
  }

  void _alEmpezar(DragStartDetails details) {
    _retroceso.stop();
  }

  void _alMover(DragUpdateDetails details) {
    _retroceso.stop();
    final delta = details.delta.dy;
    if (delta <= 0) {
      final siguiente = _arrastre + delta;
      setState(() {
        _arrastre = siguiente < 0 ? 0 : siguiente;
      });
      return;
    }
    final resistencia = 1 / (1 + _arrastre / _distanciaResistencia);
    final siguiente = _arrastre + delta * resistencia;
    setState(() {
      _arrastre = siguiente < 0 ? 0 : siguiente;
    });
  }

  void _alRetroceder() {
    if (!mounted) {
      return;
    }
    setState(() {
      _arrastre = _origenRetroceso * (1 - _curvaRetroceso.value);
    });
  }

  void _volverASitio() {
    _origenRetroceso = _arrastre;
    _retroceso
      ..reset()
      ..forward();
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
      setState(() {
        _arrastre = 0;
      });
      return;
    }
    _volverASitio();
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
      child: Transform.translate(
        offset: Offset(0, _arrastre),
        child: widget.child,
      ),
    );
  }
}
