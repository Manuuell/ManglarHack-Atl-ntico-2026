/// Bandeja de acciones: una fila de botones con ícono y texto (≥ 44 px) que
/// reemplaza al gesto cuando no hay dedo (ratón, teclado, lector de pantalla).
///
/// Traducido de `action-tray.tsx` de FastFood: las mismas acciones que el gesto,
/// siempre a la vista, con el color de cada una y sin depender de mantener ni
/// deslizar.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../presionable.dart';
import '../tema.dart';
import 'accion_gesto.dart';

class BandejaAcciones extends StatelessWidget {
  const BandejaAcciones({super.key, required this.acciones, this.etiqueta});
  final List<AccionGesto> acciones;
  final String? etiqueta;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: etiqueta ?? 'Acciones',
      child: Row(
        children: [
          for (final (i, a) in acciones.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Presionable(
                vibracion: Vibracion.ligera,
                etiqueta: a.anuncio,
                onTap: () => unawaited(Future.sync(a.alEjecutar)),
                child: Container(
                  key: Key('bandeja-${a.etiqueta}'),
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: a.colorResuelto.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Zr.s),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(a.icono, size: 18, color: a.colorResuelto),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(a.etiqueta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelMedium?.copyWith(color: a.colorResuelto)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
