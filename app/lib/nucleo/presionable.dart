import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'tema.dart';

enum Vibracion { ninguna, seleccion, ligera, media, fuerte }

void vibrar(Vibracion v) {
  if (kIsWeb) return;
  switch (v) {
    case Vibracion.ninguna:
      return;
    case Vibracion.seleccion:
      HapticFeedback.selectionClick();
    case Vibracion.ligera:
      HapticFeedback.lightImpact();
    case Vibracion.media:
      HapticFeedback.mediumImpact();
    case Vibracion.fuerte:
      HapticFeedback.heavyImpact();
  }
}

/// La microinteracción base de toda la app: al tocar, el elemento se hunde un poco
/// y vibra; al soltar, vuelve con un resorte. Si el dedo se sale antes de soltar,
/// el toque se cancela (como en iOS).
class Presionable extends StatefulWidget {
  const Presionable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.escala = Zm.escalaPresion,
    this.vibracion = Vibracion.seleccion,
    this.etiqueta,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double escala;
  final Vibracion vibracion;

  /// Texto para TalkBack: sin él, el lector anuncia solo «botón».
  final String? etiqueta;

  @override
  State<Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<Presionable> with SingleTickerProviderStateMixin {
  late final AnimationController _hundido = AnimationController.unbounded(vsync: this);
  late Animation<double> _escala = _crearEscala();
  bool _abajo = false;

  bool get _activo => widget.onTap != null || widget.onLongPress != null;
  bool get _sinMovimiento => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  Animation<double> _crearEscala() =>
      _hundido.drive(Tween(begin: 1.0, end: widget.escala));

  @override
  void didUpdateWidget(Presionable old) {
    super.didUpdateWidget(old);
    if (old.escala != widget.escala) _escala = _crearEscala();
  }

  @override
  void dispose() {
    _hundido.dispose();
    super.dispose();
  }

  void _hundir() {
    _abajo = true;
    if (_sinMovimiento) return;
    _hundido.animateTo(1, duration: Zm.presion, curve: Curves.easeOut);
  }

  void _soltar() {
    _abajo = false;
    if (!mounted) return;
    if (_sinMovimiento) {
      _hundido.value = 0;
      return;
    }
    _hundido.animateWith(
      SpringSimulation(Zm.resortePresion, _hundido.value, 0, _hundido.velocity),
    );
  }

  /// Un toque muy corto llega con el «abajo» y el «arriba» juntos: sin esto no se
  /// vería el hundido. Se hunde lo justo y vuelve solo.
  void _pulso() {
    if (_sinMovimiento || _hundido.value >= 0.6) return;
    _hundido.animateTo(1, duration: Zm.presion, curve: Curves.easeOut).then((_) {
      if (mounted && !_abajo) _soltar();
    });
  }

  void _tap() {
    _pulso();
    vibrar(widget.vibracion);
    widget.onTap!();
  }

  void _mantener() {
    vibrar(Vibracion.media);
    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    final gesto = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _activo ? (_) => _hundir() : null,
      onTapUp: _activo ? (_) => _soltar() : null,
      onTapCancel: _activo ? _soltar : null,
      onTap: widget.onTap == null ? null : _tap,
      onLongPress: widget.onLongPress == null ? null : _mantener,
      // Atados a onLongPress y no a _activo: si no, este detector se comería el
      // mantenido de sus ancestros aunque solo tuviera onTap.
      onLongPressUp: widget.onLongPress == null ? null : _soltar,
      onLongPressCancel: widget.onLongPress == null ? null : _soltar,
      child: ScaleTransition(scale: _escala, child: widget.child),
    );
    final etiqueta = widget.etiqueta;
    if (etiqueta == null) return gesto;
    return Semantics(
      button: true,
      enabled: _activo,
      label: etiqueta,
      onTap: widget.onTap == null ? null : _tap,
      excludeSemantics: true,
      child: gesto,
    );
  }
}

/// Botón principal: lleno, alto (56 px, se acierta con el pulgar al sol) y con su
/// estado de carga dentro, para que no salte nada al tocarlo.
class BotonZ extends StatelessWidget {
  const BotonZ({
    super.key,
    required this.texto,
    this.onTap,
    this.icono,
    this.color = Zc.hoja,
    this.colorTexto = Colors.white,
    this.cargando = false,
    this.secundario = false,
  });

  final String texto;
  final VoidCallback? onTap;
  final IconData? icono;
  final Color color;
  final Color colorTexto;
  final bool cargando;
  final bool secundario;

  @override
  Widget build(BuildContext context) {
    final activo = onTap != null && !cargando;
    final fondo = secundario ? color.withValues(alpha: 0.12) : color;
    final tinta = secundario ? color : colorTexto;
    return Presionable(
      onTap: activo ? onTap : null,
      vibracion: secundario ? Vibracion.seleccion : Vibracion.ligera,
      etiqueta: texto,
      child: AnimatedOpacity(
        duration: Zm.corto,
        opacity: activo || cargando ? 1 : 0.45,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(Zr.m),
            boxShadow: secundario || !activo
                ? null
                : [BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: AnimatedSwitcher(
            duration: Zm.corto,
            child: cargando
                ? SizedBox(
                    key: const ValueKey('c'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: tinta),
                  )
                : Row(
                    key: const ValueKey('t'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icono != null) ...[Icon(icono, color: tinta, size: 21), const SizedBox(width: 10)],
                      Flexible(
                        child: Text(
                          texto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tinta, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta blanca con borde suave: la superficie de casi todo en Zanqui.
class TarjetaZ extends StatelessWidget {
  const TarjetaZ({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final caja = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Zc.superficie,
        borderRadius: BorderRadius.circular(Zr.l),
        border: Border.all(color: Zc.linea.withValues(alpha: 0.7)),
        boxShadow: const [BoxShadow(color: Color(0x0F0B2E24), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: child,
    );
    return onTap == null ? caja : Presionable(onTap: onTap, escala: 0.98, child: caja);
  }
}
