import 'dart:async';

import 'package:flutter/material.dart';

import '../base/movimiento.dart';
import '../presionable.dart';
import '../tema.dart';
import 'anuncio.dart';
import 'celebracion.dart';
import 'haptica.dart';
import 'sacudida.dart';
import 'spinner.dart';

/// Los estados de un [BotonEstado].
enum EstadoBoton { reposo, cargando, hecho, error }

/// Botón principal con su ciclo completo: **reposo → cargando → hecho → reposo**
/// (o **→ error** con sacudida → reposo).
///
/// Maneja el estado solo: le pasas una función asíncrona y él hace lo demás.
/// Mientras corre, el spinner propio ([SpinnerZ]) reemplaza al texto; si
/// termina bien, un ✓ se dibuja ([CheckDibujado]) y vibra con éxito; si lanza,
/// el botón se pone rojo, se sacude y vibra con error. Luego vuelve a reposo.
///
/// - **El ancho no salta**: el texto de reposo siempre está medido (invisible
///   cuando no se ve) y los demás estados se dibujan encima.
/// - **No se dispara dos veces**: mientras no esté en reposo ignora toques
///   (también el segundo toque que llega antes de repintar).
/// - Con alPresionar nulo se ve apagado (45 %) y no responde.
/// - «Reducir movimiento»: los cambios son cortes (sin escala ni trazo del ✓)
///   y no hay sacudida; la vibración y el texto para el lector se conservan.
///
/// ```dart
/// BotonEstado(
///   texto: 'Enviar reporte',
///   textoHecho: 'Enviado',
///   alPresionar: () async => await servidor.enviar(reporte), // si lanza → error
/// )
/// ```
/// Para pintarlo secundario: `secundario: true`. Usa [Presionable] para la
/// escala y la vibración al tocar (`Vibracion.ligera`).
class BotonEstado extends StatefulWidget {
  const BotonEstado({
    super.key,
    required this.texto,
    required this.alPresionar,
    this.icono,
    this.color = Zc.hoja,
    this.colorTexto = Colors.white,
    this.secundario = false,
    this.textoHecho = 'Listo',
    this.textoError = 'No se pudo',
    this.textoCargando = 'Cargando',
  });

  final String texto;
  final IconData? icono;
  final Color color;
  final Color colorTexto;
  final bool secundario;

  /// Lo que se dice (al lector de pantalla) y se ve en error y al terminar.
  final String textoHecho;
  final String textoError;
  final String textoCargando;

  /// Se llama al tocar, una vez. Si lanza, el botón pasa a error. Nulo:
  /// botón apagado.
  final Future<void> Function()? alPresionar;

  @override
  State<BotonEstado> createState() => _BotonEstadoState();
}

class _BotonEstadoState extends State<BotonEstado> {
  EstadoBoton _estado = EstadoBoton.reposo;

  /// Verdadero desde el toque hasta volver a reposo: la guarda del doble toque
  /// (se pone **antes** de `setState`, así un segundo toque en el mismo cuadro
  /// ya no pasa).
  bool _ocupado = false;
  int _errores = 0;
  Timer? _vuelta;

  @override
  void dispose() {
    _vuelta?.cancel();
    super.dispose();
  }

  Future<void> _tocar() async {
    if (_ocupado || widget.alPresionar == null) return;
    _ocupado = true;
    setState(() => _estado = EstadoBoton.cargando);
    var bien = true;
    try {
      await widget.alPresionar!();
    } catch (_) {
      bien = false;
    }
    if (!mounted) return;
    if (bien) {
      vibrarExito();
      anunciar(context, widget.textoHecho);
      setState(() => _estado = EstadoBoton.hecho);
    } else {
      // La sacudida ya vibra con error por su cuenta (vibrar: false abajo, y
      // aquí una sola vez para que con reducir movimiento también vibre).
      vibrarError();
      anunciar(context, widget.textoError);
      setState(() {
        _estado = EstadoBoton.error;
        _errores++;
      });
    }
    _vuelta = Timer(bien ? AppMotion.reposoHecho : AppMotion.reposoError, () {
      if (!mounted) return;
      setState(() => _estado = EstadoBoton.reposo);
      _ocupado = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final reposo = _estado == EstadoBoton.reposo;
    final apagado = w.alPresionar == null && reposo;
    final fondo = switch (_estado) {
      EstadoBoton.error => Zc.dePrioridad(5),
      _ => w.secundario && reposo ? w.color.withValues(alpha: 0.12) : w.color,
    };
    final tinta = w.secundario && reposo ? w.color : w.colorTexto;
    final estiloTexto = Theme.of(context).textTheme.labelLarge?.copyWith(color: tinta, fontSize: 16);
    final etiqueta = switch (_estado) {
      EstadoBoton.reposo => w.texto,
      EstadoBoton.cargando => w.textoCargando,
      EstadoBoton.hecho => w.textoHecho,
      EstadoBoton.error => w.textoError,
    };

    // Lo que se dibuja encima del texto medido, según el estado.
    final Widget encima = switch (_estado) {
      EstadoBoton.reposo => const SizedBox.shrink(key: ValueKey('r')),
      EstadoBoton.cargando => SpinnerZ(key: const ValueKey('c'), color: w.colorTexto),
      EstadoBoton.hecho => CheckDibujado(key: const ValueKey('h'), tamano: 26, conCirculo: false, color: w.colorTexto),
      EstadoBoton.error => Padding(
          key: const ValueKey('e'),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text(w.textoError, maxLines: 1, overflow: TextOverflow.ellipsis, style: estiloTexto?.copyWith(color: w.colorTexto)),
        ),
    };

    return Sacudida(
      disparos: _errores,
      vibrar: false,
      child: Presionable(
        // Fuera de reposo no hay toque (ni hundido ni vibración de toque).
        onTap: reposo && !apagado ? _tocar : null,
        vibracion: w.secundario ? Vibracion.seleccion : Vibracion.ligera,
        etiqueta: etiqueta,
        child: AnimatedOpacity(
          duration: context.resolveDuration(AppMotion.fast),
          opacity: apagado ? 0.45 : 1,
          child: AnimatedContainer(
            duration: context.resolveDuration(AppMotion.fast),
            curve: AppMotion.enter,
            constraints: const BoxConstraints(minHeight: 56),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(Zr.m),
              boxShadow: w.secundario || apagado
                  ? null
                  : [BoxShadow(color: fondo.withValues(alpha: 0.32), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // El texto de reposo siempre está medido: él manda el ancho y
                // el alto, así que ningún estado hace saltar el botón.
                AnimatedOpacity(
                  duration: context.resolveDuration(AppMotion.micro),
                  opacity: reposo ? 1 : 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (w.icono != null) ...[Icon(w.icono, color: tinta, size: 21), const SizedBox(width: 10)],
                      Flexible(child: Text(w.texto, maxLines: 2, overflow: TextOverflow.ellipsis, style: estiloTexto)),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: context.resolveDuration(AppMotion.fast),
                  switchInCurve: AppMotion.enter,
                  switchOutCurve: AppMotion.exit,
                  child: encima,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
