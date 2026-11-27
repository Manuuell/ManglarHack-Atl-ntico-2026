/// Tirar para actualizar estilo iOS, con Zanky: la lista cede con rebote, aparece
/// una píldora con Zanky que baja con lo que tiras, vibra una vez al pasar el
/// umbral («Suelta para actualizar») y al soltar se queda «Actualizando…» hasta
/// que termina [alActualizar].
///
/// Traducido de `pull-to-refresh.tsx` de FastFood (umbral 64, tope 96,
/// resistencia 0,55, la píldora se pliega al terminar). En vez de tocar el
/// desplazamiento de la lista se escucha su sobredesplazamiento, así sirve para
/// cualquier `ListView`/`CustomScrollView` y no pelea con el scroll.
///
/// - Rebote en todas las plataformas y arrastre con ratón (web/escritorio).
/// - Camino sin gesto: acción «Actualizar» del lector de pantalla (y cada
///   pantalla conserva su botón visible donde lo tiene).
/// - Con «reducir movimiento» la píldora aparece sin deslizar.
library;

import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../vistas/comun/zanky_mascota.dart';
import '../presionable.dart';
import '../tema.dart';
import 'anuncio.dart';

class TirarActualizar extends StatefulWidget {
  const TirarActualizar({
    super.key,
    required this.alActualizar,
    required this.child,
    this.umbral = 64,
    this.tope = 96,
    this.resistencia = 0.55,
  });

  final Future<void> Function() alActualizar;

  /// Un scrollable (ListView, CustomScrollView…).
  final Widget child;
  final double umbral;
  final double tope;
  final double resistencia;

  @override
  State<TirarActualizar> createState() => _TirarActualizarState();
}

class _Rebote extends MaterialScrollBehavior {
  const _Rebote();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics());

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  // El rebote ya es la señal: sin destello azul de Android.
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

class _TirarActualizarState extends State<TirarActualizar> {
  final ValueNotifier<double> _tirado = ValueNotifier(0);
  bool _actualizando = false;
  bool _pasoUmbral = false;

  @override
  void dispose() {
    _tirado.dispose();
    super.dispose();
  }

  bool _sostenido = false;

  bool _alScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical || _actualizando) return false;
    // Soltar = la primera notificación sin dedo (el rebote ya es el resorte de vuelta, y para
    // entonces el sobredesplazamiento baja): se decide con lo que se había tirado.
    final conDedo = switch (n) {
      ScrollStartNotification(:final dragDetails) => dragDetails != null,
      ScrollUpdateNotification(:final dragDetails) => dragDetails != null,
      OverscrollNotification(:final dragDetails) => dragDetails != null,
      _ => false,
    };
    if (_sostenido && !conDedo) {
      _sostenido = false;
      _soltar();
      return false;
    }
    if (n is ScrollEndNotification) return false;
    if (conDedo) _sostenido = true;
    final sobra = n.metrics.pixels < 0 ? -n.metrics.pixels : 0.0;
    final v = (sobra * widget.resistencia * 2).clamp(0.0, widget.tope).toDouble();
    _tirado.value = v;
    if (v >= widget.umbral && !_pasoUmbral) {
      _pasoUmbral = true;
      vibrar(Vibracion.ligera);
    } else if (v < widget.umbral * 0.8) {
      _pasoUmbral = false;
    }
    return false;
  }

  void _soltar() {
    final llego = _tirado.value >= widget.umbral;
    _pasoUmbral = false;
    if (llego) {
      unawaited(actualizar());
    } else {
      _tirado.value = 0;
    }
  }

  /// También es el camino del lector de pantalla.
  Future<void> actualizar() async {
    if (_actualizando) return;
    setState(() => _actualizando = true);
    _tirado.value = widget.umbral;
    try {
      await widget.alActualizar();
    } catch (_) {
      // Cada pantalla deja su error donde corresponde; el gesto solo termina.
    }
    if (!mounted) return;
    setState(() => _actualizando = false);
    _tirado.value = 0;
    anunciar(context, 'Actualizado');
  }

  @override
  Widget build(BuildContext context) {
    final sinMov = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      customSemanticsActions: {const CustomSemanticsAction(label: 'Actualizar'): () => unawaited(actualizar())},
      child: Stack(
        children: [
          ScrollConfiguration(
            behavior: const _Rebote(),
            child: NotificationListener<ScrollNotification>(onNotification: _alScroll, child: widget.child),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _tirado,
                builder: (_, v, _) => _Pildora(
                  tirado: v,
                  umbral: widget.umbral,
                  actualizando: _actualizando,
                  sinMovimiento: sinMov,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pildora extends StatelessWidget {
  const _Pildora({required this.tirado, required this.umbral, required this.actualizando, required this.sinMovimiento});
  final double tirado;
  final double umbral;
  final bool actualizando;
  final bool sinMovimiento;

  @override
  Widget build(BuildContext context) {
    final progreso = (tirado / umbral).clamp(0.0, 1.0);
    if (progreso == 0 && !actualizando) return const SizedBox(height: 0);
    final listo = tirado >= umbral;
    final texto = actualizando ? 'Actualizando…' : (listo ? 'Suelta para actualizar' : 'Tira para actualizar');
    final baja = sinMovimiento ? 8.0 : (tirado - 44).clamp(-44.0, 52.0).toDouble();
    return Semantics(
      liveRegion: true,
      label: texto,
      child: Transform.translate(
        offset: Offset(0, baja + 6),
        child: Opacity(
          opacity: sinMovimiento ? 1 : progreso,
          child: Center(
            child: Container(
              key: const Key('tirar-pildora'),
              padding: const EdgeInsets.fromLTRB(6, 4, 16, 4),
              decoration: BoxDecoration(
                color: Zc.superficie,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Zc.linea),
                boxShadow: const [BoxShadow(color: Color(0x1F0B2E24), blurRadius: 16, offset: Offset(0, 6))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ZankyMascota(tamano: 36, animo: actualizando || listo ? Animo.feliz : Animo.curioso),
                  const SizedBox(width: 6),
                  Text(texto, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Zc.texto)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
