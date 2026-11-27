import 'package:flutter/material.dart';

import '../../datos/cuenta/cuenta.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';

/// Pone la cuenta al alcance de las pantallas. Como el panel, cada ruta apilada lo vuelve a
/// poner (las rutas no heredan de la raíz).
class CuentaScope extends InheritedNotifier<ControladorCuenta> {
  const CuentaScope({
    super.key,
    required ControladorCuenta cuenta,
    required super.child,
  }) : super(notifier: cuenta);

  /// Nulo si no hay cuenta en este árbol (pantallas sueltas de las pruebas).
  static ControladorCuenta? maybeDe(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CuentaScope>()?.notifier;

  static ControladorCuenta? leer(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<CuentaScope>()?.widget
              as CuentaScope?)
          ?.notifier;
}

/// Un grupo de filas al estilo de Ajustes de iOS: título pequeño arriba, filas en una tarjeta
/// con separadores que empiezan donde empieza el texto, y una nota opcional abajo.
/// Tomado de `_seccion` de la pantalla de ajustes de otra app de la casa y adaptado a Zanky.
class GrupoAjustes extends StatelessWidget {
  const GrupoAjustes({super.key, this.titulo, required this.filas, this.nota});
  final String? titulo;
  final List<Widget> filas;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titulo != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Semantics(
                header: true,
                child: Text(
                  titulo!.toUpperCase(),
                  style: tt.seccion.copyWith(color: Zc.textoSuave),
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: Zc.superficie,
              borderRadius: BorderRadius.circular(Zr.m),
              border: Border.all(color: Zc.linea),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var k = 0; k < filas.length; k++) ...[
                  if (k > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Zc.linea,
                      indent: 62,
                    ),
                  filas[k],
                ],
              ],
            ),
          ),
          if (nota != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(nota!, style: tt.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// Una fila de ajustes: ícono en un cuadro de color, título, detalle y, a la derecha, un
/// control propio ([fin]) o el chevrón. Mide al menos 56 px de alto.
class FilaAjustes extends StatelessWidget {
  const FilaAjustes({
    super.key,
    required this.icono,
    required this.titulo,
    this.detalle,
    this.alTocar,
    this.fin,
    this.color = Zc.hoja,
    this.destructiva = false,
    this.cuenta = 0,
  });
  final IconData icono;
  final String titulo;
  final String? detalle;
  final VoidCallback? alTocar;
  final Widget? fin;
  final Color color;
  final bool destructiva;
  final int cuenta;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final tinta = destructiva ? Zc.prioridad[5]! : Zc.texto;
    final fila = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: destructiva ? Zc.prioridad[5] : color,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icono, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: tt.titleSmall?.copyWith(color: tinta)),
                  if (detalle != null) ...[
                    const SizedBox(height: 2),
                    Text(detalle!, style: tt.bodySmall),
                  ],
                ],
              ),
            ),
            if (cuenta > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Zc.sol,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  cuenta > 99 ? '99+' : '$cuenta',
                  style: tt.labelSmall?.copyWith(color: Zc.raiz),
                ),
              ),
              const SizedBox(width: 6),
            ],
            fin ??
                (alTocar == null
                    ? const SizedBox.shrink()
                    : const Icon(
                        Icons.chevron_right_rounded,
                        color: Zc.textoTenue,
                      )),
          ],
        ),
      ),
    );
    if (alTocar == null) return Semantics(container: true, child: fila);
    return Presionable(
      escala: 0.98,
      etiqueta: [
        titulo,
        ?detalle,
        if (cuenta > 0) '$cuenta por revisar',
      ].join('. '),
      onTap: alTocar,
      child: fila,
    );
  }
}
