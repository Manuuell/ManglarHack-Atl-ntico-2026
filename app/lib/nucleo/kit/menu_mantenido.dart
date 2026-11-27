/// Menú al mantener presionado, como el de iOS, con vista previa («peek») opcional.
///
/// Se abre con: mantener presionado (380 ms; en pantalla táctil y con ratón),
/// clic derecho (web y escritorio) o la tecla Menú / Mayús+F10 con el foco en el
/// elemento. También sale como acciones del lector de pantalla.
///
/// Qué hace al abrirse:
/// 1. Vibra (media) y desenfoca todo lo demás con un velo; el elemento queda
///    nítido en un «hueco» del velo (así no se reconstruye ni se duplica, y las
///    piezas con estado no vuelven a pedir sus datos).
/// 2. Con [vistaPrevia] el elemento no se resalta: la vista previa se agranda
///    (0,9 → 1) en el centro y el menú queda debajo.
/// 3. El menú brota anclado al elemento, con la curva emergente.
/// 4. **Se elige sin levantar el dedo**: tras mantener, deslizar sobre las filas
///    las resalta (clic de selección en cada cambio) y soltar elige. Soltar sin
///    moverse lo deja abierto; tocar fuera, «atrás» o Esc lo cierran (soltar
///    fuera de las filas tras arrastrar también lo cierra).
/// 5. Teclado: ↑ ↓ mueven, Intro elige, Esc cierra y devuelve el foco.
///
/// Traducido de:
/// - `MenuContextual` de Transcar (widgets/gestos/menu_contextual.dart): Overlay
///   raíz, velo con `BackdropFilter`, elegir arrastrando, `PopEntry` para «atrás»,
///   Escape.
/// - `long-press-menu.tsx` de FastFood: 450→380 ms, cancelar si el dedo se mueve,
///   clic derecho, teclado ↑↓, vista previa que entra 0,92 → 1.
/// - `long-press-hint.ts` de FastFood: la pista «Mantén presionado» no se pone
///   si no cabe entera ([colocarPista]).
///
/// Con «reducir movimiento» no hay escalas ni desenfoque animado.
library;

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../presionable.dart';
import '../tema.dart';
import 'accion_gesto.dart';

const double _altoFila = 48;
const double _anchoMenu = 260;
const Duration _tiempoMantener = Duration(milliseconds: 380);

/// De `long-press-hint.ts`: arriba de la pista si cabe debajo; si no, encima; si
/// no cabe en ningún lado, `null` (no se muestra).
double? colocarPista({
  required double debajo,
  required double arribaAncla,
  required double alto,
  required double limite,
  required double minimo,
}) {
  bool cabe(double top) => top >= minimo && top + alto <= limite;
  if (cabe(debajo)) return debajo;
  final encima = arribaAncla - alto - 4;
  if (cabe(encima)) return encima;
  return null;
}

class MenuMantenido extends StatefulWidget {
  const MenuMantenido({
    super.key,
    required this.child,
    required this.acciones,
    this.vistaPrevia,
    this.alTocar,
    this.etiqueta,
    this.radio = const BorderRadius.all(Radius.circular(Zr.l)),
    this.escala = 0.97,
  });

  final Widget child;
  final List<AccionGesto> acciones;

  /// Si se da, se muestra en grande en vez de resaltar el elemento (el «peek»).
  final WidgetBuilder? vistaPrevia;
  final VoidCallback? alTocar;

  /// Nombre para el lector de pantalla.
  final String? etiqueta;

  /// Esquinas del hueco que deja el velo alrededor del elemento.
  final BorderRadius radio;
  final double escala;

  @override
  State<MenuMantenido> createState() => MenuMantenidoState();
}

class MenuMantenidoState extends State<MenuMantenido> {
  final GlobalKey _hueco = GlobalKey();
  _Abierto? _abierto;
  Offset? _ultimoToque;

  bool get abierto => _abierto != null;

  List<AccionGesto> get _ordenadas => [
        ...widget.acciones.where((a) => !a.destructiva),
        ...widget.acciones.where((a) => a.destructiva),
      ];

  @override
  void dispose() {
    final a = _abierto;
    if (a != null) {
      _quitar(a);
      if (!a.eleccion.isCompleted) a.eleccion.complete(null);
    }
    super.dispose();
  }

  /// Abre el menú: final del gesto y camino alternativo (teclado, clic derecho).
  Future<void> abrir() async {
    final acciones = _ordenadas;
    if (acciones.isEmpty || _abierto != null || !mounted) return;
    final caja = _hueco.currentContext?.findRenderObject();
    if (caja is! RenderBox || !caja.attached || !caja.hasSize) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final raiz = overlay.context.findRenderObject();
    final origen = caja.localToGlobal(Offset.zero, ancestor: raiz is RenderBox ? raiz : null) & caja.size;
    if (kIsWeb) unawaited(BrowserContextMenu.disableContextMenu());
    vibrar(Vibracion.media);

    final sinMov = MediaQuery.disableAnimationsOf(context);
    final ctl = AnimationController(
      vsync: overlay,
      duration: sinMov ? Duration.zero : Zm.medio,
      reverseDuration: sinMov ? Duration.zero : Zm.corto,
    );
    final eleccion = Completer<int?>();
    final arrastre = _Arrastre(inicio: _ultimoToque, total: acciones.length);
    final foco = FocusNode(debugLabel: 'menu-mantenido');
    void terminar(int? i) {
      if (!eleccion.isCompleted) eleccion.complete(i);
    }

    arrastre.alSoltarElegido = terminar;
    arrastre.alSoltarFuera = () => terminar(null);
    final entrada = OverlayEntry(
      builder: (_) => _Capa(
        origen: origen,
        radio: widget.radio,
        vistaPrevia: widget.vistaPrevia,
        acciones: acciones,
        animacion: ctl,
        arrastre: arrastre,
        foco: foco,
        sinMovimiento: sinMov,
        etiqueta: widget.etiqueta,
        alElegir: terminar,
        alCerrar: () => terminar(null),
      ),
    );
    final ruta = ModalRoute.of(context);
    final atras = _AtrasCierra(() => terminar(null));
    ruta?.registerPopEntry(atras);
    final a = _Abierto(ctl, entrada, ruta, atras, arrastre, eleccion, foco, FocusManager.instance.primaryFocus);
    _abierto = a;
    overlay.insert(entrada);
    unawaited(ctl.forward());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (foco.context != null) foco.requestFocus();
    });
    SemanticsService.sendAnnouncement(
        View.of(context), 'Menú con ${acciones.length} acciones. Esc para cerrar.', Directionality.of(context));

    final elegido = await eleccion.future;
    if (!mounted || _abierto != a) return;
    await ctl.reverse();
    if (!mounted || _abierto != a) return;
    _quitar(a);
    final previo = a.focoPrevio;
    if (previo != null && previo.context != null) previo.requestFocus();
    if (elegido == null || elegido < 0 || elegido >= acciones.length) return;
    await acciones[elegido].alEjecutar();
  }

  void _quitar(_Abierto a) {
    if (_abierto == a) _abierto = null;
    a.ruta?.unregisterPopEntry(a.atras);
    a.atras.dispose();
    if (a.entrada.mounted) a.entrada.remove();
    a.entrada.dispose();
    a.ctl.dispose();
    a.arrastre.dispose();
    a.foco.dispose();
  }

  KeyEventResult _tecla(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final menu = e.logicalKey == LogicalKeyboardKey.contextMenu ||
        (e.logicalKey == LogicalKeyboardKey.f10 && HardwareKeyboard.instance.isShiftPressed);
    if (!menu) return KeyEventResult.ignored;
    unawaited(abrir());
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final acciones = _ordenadas;
    return Semantics(
      label: widget.etiqueta,
      customSemanticsActions: {
        for (final a in acciones) CustomSemanticsAction(label: a.anuncio): () => unawaited(Future.sync(a.alEjecutar)),
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _tecla,
        child: Listener(
          onPointerDown: (e) => _ultimoToque = e.position,
          onPointerMove: (e) => _abierto?.arrastre.mover(e.position),
          onPointerUp: (_) => _abierto?.arrastre.soltar(),
          onPointerCancel: (_) => _abierto?.arrastre.cancelar(),
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: {
              LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(duration: _tiempoMantener),
                (r) => r.onLongPress = () => unawaited(abrir()),
              ),
              // Clic derecho (ratón) = mantener.
              TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                TapGestureRecognizer.new,
                (r) => r.onSecondaryTapUp = (_) => unawaited(abrir()),
              ),
            },
            child: Presionable(
              onTap: widget.alTocar,
              escala: widget.escala,
              child: KeyedSubtree(key: _hueco, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class _Abierto {
  _Abierto(this.ctl, this.entrada, this.ruta, this.atras, this.arrastre, this.eleccion, this.foco, this.focoPrevio);
  final AnimationController ctl;
  final OverlayEntry entrada;
  final ModalRoute<Object?>? ruta;
  final _AtrasCierra atras;
  final _Arrastre arrastre;
  final Completer<int?> eleccion;
  final FocusNode foco;
  final FocusNode? focoPrevio;
}

/// «Atrás» cierra el menú en vez de salir de la pantalla (de Transcar).
class _AtrasCierra extends PopEntry<Object?> {
  _AtrasCierra(this._cerrar);
  final VoidCallback _cerrar;
  final ValueNotifier<bool> _puede = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get canPopNotifier => _puede;

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (!didPop) _cerrar();
  }

  void dispose() => _puede.dispose();
}

/// El dedo que abrió el menú, visto desde el menú: resalta la fila de abajo y
/// la elige al soltar.
class _Arrastre {
  _Arrastre({required this.inicio, required this.total});
  final Offset? inicio;
  final int total;
  final ValueNotifier<int?> resaltada = ValueNotifier<int?>(null);
  final GlobalKey claveMenu = GlobalKey();
  bool _seMovio = false;
  void Function(int?)? alSoltarElegido;
  VoidCallback? alSoltarFuera;

  int? _filaEn(Offset global) {
    final caja = claveMenu.currentContext?.findRenderObject();
    if (caja is! RenderBox || !caja.attached) return null;
    final l = caja.globalToLocal(global);
    if (l.dx < 0 || l.dx > caja.size.width) return null;
    final i = ((l.dy - _relleno) / _altoFila).floor();
    return (l.dy >= _relleno && i >= 0 && i < total) ? i : null;
  }

  void mover(Offset p) {
    if (!_seMovio) {
      if (inicio != null && (p - inicio!).distance < 10) return;
      _seMovio = true;
    }
    final i = _filaEn(p);
    if (i != resaltada.value) {
      resaltada.value = i;
      if (i != null) vibrar(Vibracion.seleccion);
    }
  }

  void soltar() {
    if (!_seMovio) return;
    final i = resaltada.value;
    if (i != null) {
      alSoltarElegido?.call(i);
    } else {
      alSoltarFuera?.call();
    }
  }

  void cancelar() => resaltada.value = null;
  void dispose() => resaltada.dispose();
}

const double _relleno = 6;

class _Capa extends StatelessWidget {
  const _Capa({
    required this.origen,
    required this.radio,
    required this.vistaPrevia,
    required this.acciones,
    required this.animacion,
    required this.arrastre,
    required this.foco,
    required this.sinMovimiento,
    required this.etiqueta,
    required this.alElegir,
    required this.alCerrar,
  });

  final Rect origen;
  final BorderRadius radio;
  final WidgetBuilder? vistaPrevia;
  final List<AccionGesto> acciones;
  final Animation<double> animacion;
  final _Arrastre arrastre;
  final FocusNode foco;
  final bool sinMovimiento;
  final String? etiqueta;
  final void Function(int?) alElegir;
  final VoidCallback alCerrar;

  KeyEventResult _tecla(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final r = arrastre.resaltada;
    if (k == LogicalKeyboardKey.escape) {
      alCerrar();
    } else if (k == LogicalKeyboardKey.arrowDown) {
      r.value = ((r.value ?? -1) + 1) % acciones.length;
      vibrar(Vibracion.seleccion);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      r.value = ((r.value ?? 0) - 1 + acciones.length) % acciones.length;
      vibrar(Vibracion.seleccion);
    } else if (k == LogicalKeyboardKey.home) {
      r.value = 0;
    } else if (k == LogicalKeyboardKey.end) {
      r.value = acciones.length - 1;
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.space) {
      if (r.value != null) alElegir(r.value);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final curva = CurvedAnimation(parent: animacion, curve: Zm.entrar, reverseCurve: Zm.salir);
    final tam = MediaQuery.sizeOf(context);
    final seg = MediaQuery.paddingOf(context);
    final anchoMenu = _anchoMenu.clamp(0, tam.width - 32).toDouble();
    final altoMenu = acciones.length * _altoFila + _relleno * 2;
    final conPeek = vistaPrevia != null;

    final menu = _Emergente(
      animacion: curva,
      sinMovimiento: sinMovimiento,
      ancla: Alignment.topCenter,
      escalaInicial: 0.92,
      child: _Menu(
        clave: arrastre.claveMenu,
        ancho: anchoMenu,
        acciones: acciones,
        resaltada: arrastre.resaltada,
        alElegir: alElegir,
      ),
    );

    final Widget cuerpo;
    if (conPeek) {
      final anchoPeek = (tam.width - 32).clamp(0, 380).toDouble();
      cuerpo = Padding(
        padding: EdgeInsets.fromLTRB(16, seg.top + 12, 16, seg.bottom + 12),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Emergente(
                  animacion: curva,
                  sinMovimiento: sinMovimiento,
                  ancla: Alignment.center,
                  escalaInicial: 0.9,
                  child: Container(
                    key: const Key('peek'),
                    width: anchoPeek,
                    constraints: BoxConstraints(maxHeight: tam.height * 0.45),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Zc.superficie,
                      borderRadius: BorderRadius.circular(Zr.l),
                      boxShadow: const [BoxShadow(color: Color(0x330B2E24), blurRadius: 40, offset: Offset(0, 16))],
                    ),
                    child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: vistaPrevia!(context)),
                  ),
                ),
                const SizedBox(height: 12),
                menu,
              ],
            ),
          ),
        ),
      );
    } else {
      final cercaDerecha = origen.center.dx > tam.width / 2;
      var izq = cercaDerecha ? origen.right - anchoMenu : origen.left;
      izq = izq.clamp(16, (tam.width - 16 - anchoMenu).clamp(16, double.infinity)).toDouble();
      var arriba = origen.bottom + 8;
      if (arriba + altoMenu > tam.height - seg.bottom - 8) arriba = origen.top - 8 - altoMenu;
      arriba = arriba.clamp(seg.top + 8, (tam.height - altoMenu - 8).clamp(seg.top + 8, double.infinity)).toDouble();
      cuerpo = Stack(children: [Positioned(left: izq, top: arriba, child: menu)]);
    }

    return Focus(
      focusNode: foco,
      onKeyEvent: _tecla,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: etiqueta == null ? 'Acciones' : 'Acciones de $etiqueta',
        child: Stack(
          children: [
            Positioned.fill(
              child: _Velo(
                animacion: curva,
                sinMovimiento: sinMovimiento,
                hueco: conPeek ? null : origen,
                radio: radio,
                alTocar: alCerrar,
              ),
            ),
            Positioned.fill(child: cuerpo),
          ],
        ),
      ),
    );
  }
}

/// Velo: desenfoca y apaga todo menos el [hueco] (el elemento se queda nítido).
class _Velo extends StatelessWidget {
  const _Velo({required this.animacion, required this.sinMovimiento, required this.hueco, required this.radio, required this.alTocar});
  final Animation<double> animacion;
  final bool sinMovimiento;
  final Rect? hueco;
  final BorderRadius radio;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cerrar el menú',
      onTap: alTocar,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: alTocar,
        child: AnimatedBuilder(
          animation: animacion,
          builder: (_, _) {
            final t = sinMovimiento ? 1.0 : animacion.value.clamp(0.0, 1.0);
            final sigma = 7 * t;
            final velo = BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: ColoredBox(color: Zc.raiz.withValues(alpha: 0.30 * t)),
            );
            if (hueco == null) return velo;
            return ClipPath(clipper: _ConHueco(hueco!, radio), child: velo);
          },
        ),
      ),
    );
  }
}

class _ConHueco extends CustomClipper<Path> {
  _ConHueco(this.hueco, this.radio);
  final Rect hueco;
  final BorderRadius radio;

  @override
  Path getClip(Size size) => Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(radio.toRRect(hueco)),
      );

  @override
  bool shouldReclip(_ConHueco old) => old.hueco != hueco || old.radio != radio;
}

class _Emergente extends StatelessWidget {
  const _Emergente({required this.animacion, required this.sinMovimiento, required this.ancla, required this.escalaInicial, required this.child});
  final Animation<double> animacion;
  final bool sinMovimiento;
  final Alignment ancla;
  final double escalaInicial;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (sinMovimiento) return child;
    return AnimatedBuilder(
      animation: animacion,
      builder: (_, hijo) => Opacity(
        opacity: animacion.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: escalaInicial + (1 - escalaInicial) * animacion.value, alignment: ancla, child: hijo),
      ),
      child: child,
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.clave, required this.ancho, required this.acciones, required this.resaltada, required this.alElegir});
  final GlobalKey clave;
  final double ancho;
  final List<AccionGesto> acciones;
  final ValueListenable<int?> resaltada;
  final void Function(int?) alElegir;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        key: clave,
        width: ancho,
        padding: const EdgeInsets.symmetric(vertical: _relleno),
        decoration: BoxDecoration(
          color: Zc.superficie,
          borderRadius: BorderRadius.circular(Zr.m),
          boxShadow: const [BoxShadow(color: Color(0x330B2E24), blurRadius: 32, offset: Offset(0, 12))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, a) in acciones.indexed)
              ValueListenableBuilder<int?>(
                valueListenable: resaltada,
                builder: (_, sel, _) => Semantics(
                  button: true,
                  label: a.anuncio,
                  selected: sel == i,
                  onTap: () => alElegir(i),
                  excludeSemantics: true,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => (resaltada as ValueNotifier<int?>).value = i,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        vibrar(Vibracion.seleccion);
                        alElegir(i);
                      },
                      child: Container(
                        key: Key('menu-${a.etiqueta}'),
                        height: _altoFila,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: sel == i ? Zc.hojaClara : Colors.transparent,
                          borderRadius: BorderRadius.circular(Zr.s),
                          border: sel == i ? Border.all(color: Zc.hoja.withValues(alpha: 0.5), width: 1.5) : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(a.etiqueta, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleSmall?.copyWith(color: a.tinta))),
                            const SizedBox(width: 10),
                            Icon(a.icono, size: 20, color: a.tinta),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
