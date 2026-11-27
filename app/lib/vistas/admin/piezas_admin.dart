import 'package:flutter/material.dart';

import '../../datos/admin/controlador_admin.dart';
import '../../datos/tipos.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/tema.dart';
import '../comun/comunes.dart';
import '../comun/zanky_mascota.dart';

/// Pone el controlador del panel al alcance de las pantallas. Las rutas que se apilan
/// encima de la raíz no heredan de ella, así que cada ruta del panel lo vuelve a poner.
class AdminScope extends InheritedNotifier<ControladorAdmin> {
  const AdminScope({super.key, required ControladorAdmin controlador, required super.child})
      : super(notifier: controlador);

  static ControladorAdmin de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminScope>()!.notifier!;

  /// Nulo si no hay panel en este árbol (las pantallas sueltas de las pruebas).
  static ControladorAdmin? maybeDe(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminScope>()?.notifier;

  static ControladorAdmin leer(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AdminScope>()!.widget as AdminScope).notifier!;
}

/// Segmentos con número (Pendientes 5, Aprobados 3…). Se desplazan de lado si no caben
/// (letra grande, pantalla angosta) y cada uno mide al menos 44 px de alto.
class SegmentosZ<T> extends StatelessWidget {
  const SegmentosZ({
    super.key,
    required this.valores,
    required this.actual,
    required this.nombre,
    required this.alCambiar,
    this.cuenta,
  });
  final List<T> valores;
  final T actual;
  final String Function(T) nombre;
  final int? Function(T)? cuenta;
  final ValueChanged<T> alCambiar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final v in valores) ...[
            _Segmento(
              texto: nombre(v),
              cuenta: cuenta?.call(v),
              activo: v == actual,
              alTocar: () => alCambiar(v),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Segmento extends StatelessWidget {
  const _Segmento({required this.texto, required this.cuenta, required this.activo, required this.alTocar});
  final String texto;
  final int? cuenta;
  final bool activo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final etiqueta = cuenta == null ? texto : '$texto, $cuenta';
    return Semantics(
      selected: activo,
      child: Presionable(
        etiqueta: etiqueta,
        onTap: alTocar,
        child: AnimatedContainer(
          duration: context.resolveDuration(Zm.corto),
          curve: Zm.entrar,
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activo ? Cra.dorado : Cra.superficie,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: activo ? Cra.dorado : Cra.linea),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(texto, style: tt.labelLarge?.copyWith(color: activo ? Cra.azul : Cra.texto)),
              if (cuenta != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: activo ? Cra.azul.withValues(alpha: 0.14) : Cra.azul,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('$cuenta',
                      style: tt.labelMedium?.copyWith(color: activo ? Cra.azul : Cra.textoSuave)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// El estado de un reporte como etiqueta de color.
class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado(this.estado, {super.key});
  final EstadoReporte estado;

  @override
  Widget build(BuildContext context) {
    final c = ChipEstado.colorDe(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ChipEstado.iconoDe(estado), size: 14, color: c),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              estado.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Color.lerp(c, Cra.texto, 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío con Zanky: una frase y, si hace falta, qué hacer.
class VacioAdmin extends StatelessWidget {
  const VacioAdmin({super.key, required this.titulo, required this.detalle, this.animo = Animo.feliz, this.accion});
  final String titulo;
  final String detalle;
  final Animo animo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ZankyMascota(tamano: 120, animo: animo),
          const SizedBox(height: 14),
          Text(titulo, textAlign: TextAlign.center, style: tt.titleLarge),
          const SizedBox(height: 6),
          Text(detalle, textAlign: TextAlign.center, style: tt.bodyMedium),
          if (accion != null) ...[const SizedBox(height: 16), accion!],
        ],
      ),
    );
  }
}

/// Avisa de un fallo con la opción de reintentar.
class ErrorAdmin extends StatelessWidget {
  const ErrorAdmin({super.key, required this.mensaje, required this.alReintentar});
  final String mensaje;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return VacioAdmin(
      titulo: 'No pude traer los reportes',
      detalle: mensaje,
      animo: Animo.preocupado,
      accion: Presionable(
        etiqueta: 'Reintentar',
        onTap: alReintentar,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(color: Cra.dorado, borderRadius: BorderRadius.circular(Zr.m)),
          child: Text('Reintentar', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Cra.azul)),
        ),
      ),
    );
  }
}

/// Botón redondo de 48 px para la cabecera.
class BotonIcono extends StatelessWidget {
  const BotonIcono({super.key, required this.icono, required this.etiqueta, required this.alTocar, this.cuenta = 0});
  final IconData icono;
  final String etiqueta;
  final VoidCallback alTocar;
  final int cuenta;

  @override
  Widget build(BuildContext context) {
    return Presionable(
      etiqueta: cuenta > 0 ? '$etiqueta, $cuenta sin ver' : etiqueta,
      onTap: alTocar,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Cra.superficie,
              shape: BoxShape.circle,
              border: Border.all(color: Cra.linea),
            ),
            child: Badge(
              isLabelVisible: cuenta > 0,
              backgroundColor: Cra.sol,
              textColor: Cra.raiz,
              label: Text(cuenta > 99 ? '99+' : '$cuenta'),
              child: Icon(icono, size: 22, color: Cra.raiz),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Aprobado · Deshacer»: la decisión ya se ve, pero sale al servidor pasados unos segundos.
class BarraDeshacer extends StatelessWidget {
  const BarraDeshacer({super.key, required this.controlador});
  final ControladorAdmin controlador;

  @override
  Widget build(BuildContext context) {
    final d = controlador.pendiente;
    return AnimatedSwitcher(
      duration: context.resolveDuration(Zm.corto),
      switchInCurve: Zm.entrar,
      transitionBuilder: (hijo, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
          child: hijo,
        ),
      ),
      child: d == null
          ? const SizedBox(key: ValueKey('nada'), width: double.infinity)
          : _Barra(key: ValueKey(d), decision: d, controlador: controlador),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({super.key, required this.decision, required this.controlador});
  final DecisionPendiente decision;
  final ControladorAdmin controlador;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final sinAnimar = context.animationsDisabled;
    return Semantics(
      liveRegion: true,
      container: true,
      label: '${decision.resumen}. Puedes deshacerlo unos segundos.',
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Cra.raiz,
          borderRadius: BorderRadius.circular(Zr.m),
          boxShadow: const [BoxShadow(color: Color(0x330B2E24), blurRadius: 24, offset: Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Cra.acierto, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(decision.resumen, style: tt.titleSmall?.copyWith(color: Colors.white)),
                  ),
                  Presionable(
                    etiqueta: 'Deshacer',
                    onTap: controlador.deshacer,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      child: Text('Deshacer', style: tt.labelLarge?.copyWith(color: Cra.sol)),
                    ),
                  ),
                ],
              ),
            ),
            // El tiempo que queda para deshacer. Con movimiento reducido, una línea quieta.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: sinAnimar ? 1 : 0),
              duration: controlador.plazoDeshacer,
              builder: (_, v, _) => ExcludeSemantics(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: v,
                    child: Container(height: 3, color: Cra.sol),
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

/// Campo de texto del panel: etiqueta arriba, borde que se enciende al enfocar.
class CampoAdmin extends StatelessWidget {
  const CampoAdmin({
    super.key,
    required this.etiqueta,
    required this.controlador,
    required this.foco,
    this.icono,
    this.teclado = TextInputType.text,
    this.accion = TextInputAction.next,
    this.oculto = false,
    this.lineas = 1,
    this.maximo,
    this.alEnviar,
    this.sufijo,
    this.pistas,
  });
  final String etiqueta;
  final TextEditingController controlador;
  final FocusNode foco;
  final IconData? icono;
  final TextInputType teclado;
  final TextInputAction accion;
  final bool oculto;
  final int lineas;
  final int? maximo;
  final VoidCallback? alEnviar;
  final Widget? sufijo;
  final Iterable<String>? pistas;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: foco,
      builder: (context, _) {
        final enfocado = foco.hasFocus;
        final borde = enfocado ? Cra.hoja : Cra.linea;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 7),
              child: Text(etiqueta, style: tt.labelMedium?.copyWith(color: Cra.texto)),
            ),
            AnimatedContainer(
              duration: context.resolveDuration(Zm.corto),
              curve: Zm.entrar,
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.only(left: 16, right: 6, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: Cra.superficie,
                borderRadius: BorderRadius.circular(Zr.m),
                border: Border.all(color: borde, width: 1.5),
                boxShadow: [
                  BoxShadow(color: borde.withValues(alpha: enfocado ? 0.16 : 0), blurRadius: 14, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  if (icono != null) ...[
                    Icon(icono, size: 22, color: enfocado ? Cra.hoja : Cra.textoTenue),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Semantics(
                      label: etiqueta,
                      textField: true,
                      child: TextField(
                        controller: controlador,
                        focusNode: foco,
                        keyboardType: teclado,
                        textInputAction: accion,
                        obscureText: oculto,
                        minLines: lineas,
                        maxLines: oculto ? 1 : (lineas > 1 ? lineas + 2 : 1),
                        maxLength: maximo,
                        autocorrect: !oculto && teclado != TextInputType.emailAddress,
                        enableSuggestions: !oculto,
                        autofillHints: pistas,
                        onSubmitted: alEnviar == null ? null : (_) => alEnviar!(),
                        style: tt.bodyLarge,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  ?sufijo,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bloque con título para agrupar cosas del panel.
class SeccionAdmin extends StatelessWidget {
  const SeccionAdmin({super.key, required this.titulo, required this.child, this.nota});
  final String titulo;
  final String? nota;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Semantics(header: true, child: Text(titulo, style: tt.titleMedium)),
          ),
          if (nota != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(nota!, style: tt.bodySmall),
            ),
          child,
        ],
      ),
    );
  }
}

/// Lo que deja claro que es una demostración, con el modo de ver el aviso de llegada.
class FranjaDemo extends StatelessWidget {
  const FranjaDemo({super.key, required this.controlador});
  final ControladorAdmin controlador;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 0),
      decoration: BoxDecoration(color: Cra.solClaro, borderRadius: BorderRadius.circular(Zr.s)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.science_rounded, size: 18, color: Cra.fango)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Datos de ejemplo en este teléfono. Nada llega a la CRA.', style: tt.bodySmall?.copyWith(color: Cra.texto)),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Presionable(
              etiqueta: 'Simular un reporte nuevo',
              onTap: controlador.simularLlegada,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                child: Text('Simular llegada de un reporte', textAlign: TextAlign.center, style: tt.labelMedium?.copyWith(color: Cra.fango)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
