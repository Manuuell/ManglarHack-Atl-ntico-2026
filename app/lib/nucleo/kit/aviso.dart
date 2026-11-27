/// Aviso en píldora flotante: baja desde arriba con resorte, se apila (hasta
/// [AvisoZ.maximo]), se descarta deslizando y puede llevar una acción
/// («Deshacer») con su plazo a la vista.
///
/// Reemplaza al `SnackBar`: el aviso vive en el overlay raíz (sobre hojas y
/// diálogos), no depende de un `Scaffold` y no tapa los botones de abajo.
///
/// ```dart
/// avisar(context, 'Reporte guardado');
/// avisar(context, 'Quitaste el reporte',
///     accion: AccionAviso('Deshacer', () => restaurar()));
/// avisar(context, 'No pude abrir compartir', tipo: TipoAviso.error);
/// ```
///
/// Solo se animan `transform` y `opacity` de la píldora; el plazo del
/// «Deshacer» es una barra que se vacía con `scaleX` (sin relayout). Con
/// «reducir movimiento» los avisos aparecen y se van con un corte/fundido
/// corto, sin deslizar. El lector de pantalla lo anuncia (`liveRegion`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../base/movimiento.dart';
import '../tema.dart';
import 'anuncio.dart';
import 'haptica.dart';

/// Qué tono tiene el aviso: cambia el ícono, el color de acento y la vibración.
enum TipoAviso { info, exito, aviso, error }

/// Acción opcional del aviso (el botón de la derecha).
class AccionAviso {
  const AccionAviso(this.texto, this.alTocar);
  final String texto;
  final VoidCallback alTocar;
}

/// Muestra un aviso. Devuelve un [AvisoZ] para poder cerrarlo antes de tiempo.
AvisoZ avisar(
  BuildContext context,
  String texto, {
  TipoAviso tipo = TipoAviso.info,
  AccionAviso? accion,
  Duration? vida,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final aviso = AvisoZ._(
    texto: texto,
    tipo: tipo,
    accion: accion,
    vida: vida ?? (accion != null ? AppMotion.plazoDeshacer : AppMotion.vidaAviso(texto)),
  );
  if (overlay == null) return aviso;
  anunciar(context, texto);
  switch (tipo) {
    case TipoAviso.error:
      vibrarError();
    case TipoAviso.aviso:
      vibrarAviso();
    case TipoAviso.exito:
    case TipoAviso.info:
      break;
  }
  _Pila.de(overlay).agregar(aviso);
  return aviso;
}

/// Un aviso vivo. [cerrar] lo quita con su salida.
class AvisoZ {
  AvisoZ._({required this.texto, required this.tipo, required this.accion, required this.vida});

  /// Cuántos avisos caben a la vez: el más viejo sale cuando llega uno más.
  static const int maximo = 3;

  final String texto;
  final TipoAviso tipo;
  final AccionAviso? accion;
  final Duration vida;
  final ValueNotifier<bool> _saliendo = ValueNotifier(false);
  bool _cerrado = false;

  bool get cerrado => _cerrado;

  /// Lo saca con su animación de salida.
  void cerrar() {
    if (_cerrado) return;
    _cerrado = true;
    _saliendo.value = true;
  }
}

/// La pila de avisos de un overlay: una sola entrada en el overlay que lleva
/// todos los avisos vivos.
class _Pila extends ChangeNotifier {
  _Pila._(this._overlay);

  static final Expando<_Pila> _pilas = Expando<_Pila>('avisos');

  static _Pila de(OverlayState overlay) => _pilas[overlay] ??= _Pila._(overlay);

  final OverlayState _overlay;
  final List<AvisoZ> avisos = [];
  OverlayEntry? _entrada;

  void agregar(AvisoZ a) {
    avisos.add(a);
    final vivos = avisos.where((x) => !x.cerrado).toList();
    for (var i = 0; i < vivos.length - AvisoZ.maximo; i++) {
      vivos[i].cerrar();
    }
    if (_entrada == null) {
      _entrada = OverlayEntry(builder: (_) => _CapaAvisos(pila: this));
      _overlay.insert(_entrada!);
    }
    notifyListeners();
  }

  void quitar(AvisoZ a) {
    avisos.remove(a);
    if (avisos.isEmpty && _entrada != null) {
      _entrada!.remove();
      _entrada!.dispose();
      _entrada = null;
    }
    notifyListeners();
  }
}

class _CapaAvisos extends StatelessWidget {
  const _CapaAvisos({required this.pila});
  final _Pila pila;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: ListenableBuilder(
            listenable: pila,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in pila.avisos)
                  _PildoraAviso(key: ObjectKey(a), aviso: a, alTerminar: () => pila.quitar(a)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PildoraAviso extends StatefulWidget {
  const _PildoraAviso({super.key, required this.aviso, required this.alTerminar});
  final AvisoZ aviso;
  final VoidCallback alTerminar;

  @override
  State<_PildoraAviso> createState() => _PildoraAvisoState();
}

class _PildoraAvisoState extends State<_PildoraAviso> with TickerProviderStateMixin {
  /// 0 = fuera (arriba, transparente), 1 = en su sitio. Es un resorte.
  late final AnimationController _entrada = AnimationController.unbounded(vsync: this, value: 0);

  /// El plazo del aviso: 1 → 0 durante su vida. Mueve la barra de abajo.
  late final AnimationController _plazo = AnimationController(vsync: this, duration: widget.aviso.vida, value: 1);

  /// Desplazamiento del dedo al arrastrar (horizontal y vertical hacia arriba).
  Offset _arrastre = Offset.zero;
  bool _arrancado = false;
  bool _saliendo = false;

  @override
  void initState() {
    super.initState();
    widget.aviso._saliendo.addListener(_alPedirSalida);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrancado) return;
    _arrancado = true;
    if (context.animationsDisabled) {
      _entrada.value = 1;
    } else {
      _entrada.animateWith(SpringSimulation(AppMotion.resorteEmergente, 0, 1, 0));
    }
    _plazo.reverse(from: 1).whenComplete(() {
      if (mounted && !_saliendo) widget.aviso.cerrar();
    });
  }

  @override
  void dispose() {
    widget.aviso._saliendo.removeListener(_alPedirSalida);
    _entrada.dispose();
    _plazo.dispose();
    super.dispose();
  }

  void _alPedirSalida() {
    if (widget.aviso._saliendo.value) _salir();
  }

  Future<void> _salir() async {
    if (_saliendo) return;
    _saliendo = true;
    _plazo.stop();
    if (context.animationsDisabled) {
      if (mounted) widget.alTerminar();
      return;
    }
    await _entrada.animateTo(0, duration: AppMotion.fast, curve: AppMotion.exit);
    if (mounted) widget.alTerminar();
  }

  void _alSoltar(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    final lejos = _arrastre.dx.abs() > AppMotion.distanciaDescarte || _arrastre.dy < -AppMotion.distanciaDescarte;
    final rapido = v.dx.abs() > AppMotion.velocidadDescarte || v.dy < -AppMotion.velocidadDescarte;
    if (lejos || rapido) {
      widget.aviso.cerrar();
    } else {
      setState(() => _arrastre = Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.aviso;
    final (icono, acento) = switch (a.tipo) {
      TipoAviso.info => (Icons.info_rounded, Zc.cienaga),
      TipoAviso.exito => (Icons.check_circle_rounded, Zc.hoja),
      TipoAviso.aviso => (Icons.warning_amber_rounded, Zc.sol),
      TipoAviso.error => (Icons.error_rounded, Zc.dePrioridad(5)),
    };
    final tt = Theme.of(context).textTheme;
    final pildora = DecoratedBox(
      decoration: BoxDecoration(
        color: Zc.raiz,
        borderRadius: BorderRadius.circular(Zr.m),
        boxShadow: const [BoxShadow(color: Color(0x330B2E24), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Zr.m),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
              child: Row(
                children: [
                  Icon(icono, color: acento, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(a.texto, style: tt.bodyLarge?.copyWith(color: Colors.white, fontSize: 14.5, height: 1.3)),
                  ),
                  if (a.accion != null)
                    _BotonAccion(
                      texto: a.accion!.texto,
                      alTocar: () {
                        a.accion!.alTocar();
                        a.cerrar();
                      },
                    )
                  else
                    const SizedBox(width: 6),
                ],
              ),
            ),
            // El plazo: una barra fina que se vacía con scaleX.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: AnimatedBuilder(
                animation: _plazo,
                builder: (_, _) => Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.diagonal3Values(_plazo.value, 1, 1),
                  child: ColoredBox(color: acento.withValues(alpha: 0.85)),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedBuilder(
        animation: _entrada,
        builder: (context, hijo) {
          final t = _entrada.value;
          final fuera = (1 - t).clamp(0.0, 1.5);
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(_arrastre.dx, _arrastre.dy - 64 * fuera),
              child: Transform.scale(scale: 0.94 + 0.06 * t.clamp(0.0, 1.2), child: hijo),
            ),
          );
        },
        child: Semantics(
          liveRegion: true,
          container: true,
          label: a.texto,
          child: GestureDetector(
            onPanStart: (_) => _plazo.stop(),
            onPanUpdate: (d) => setState(() {
              _arrastre = Offset(_arrastre.dx + d.delta.dx, (_arrastre.dy + d.delta.dy).clamp(-200.0, 8.0));
            }),
            onPanEnd: _alSoltar,
            onPanCancel: () => setState(() => _arrastre = Offset.zero),
            child: RepaintBoundary(child: pildora),
          ),
        ),
      ),
    );
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({required this.texto, required this.alTocar});
  final String texto;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: texto,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: alTocar,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                texto,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Zc.solClaro, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
