import 'package:flutter/material.dart';

import '../../nucleo/presionable.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/tema.dart';
import 'panel_cra.dart';
import 'piezas_admin.dart';

/// La puerta discreta al panel, al final de Guardián: una fila pequeña que no estorba a
/// quien solo viene a reportar, y que se vuelve un aviso con número si ya hay sesión del
/// equipo y hay reportes sin ver.
class EntradaPanelCra extends StatelessWidget {
  const EntradaPanelCra({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AdminScope.maybeDe(context);
    if (c == null) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final dentro = c.dentro;
    final n = dentro ? c.sinVer : 0;
    final subtitulo = dentro
        ? (n > 0 ? '$n por revisar' : 'Todo al día')
        : (c.configurado ? 'Solo para el equipo de la CRA' : 'Ver cómo se verifican los reportes');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Presionable(
        escala: 0.98,
        etiqueta: 'Panel CRA. $subtitulo',
        onTap: () => abrirPanelCra(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: dentro ? Cra.hojaClara : Cra.superficie,
            borderRadius: BorderRadius.circular(Zr.m),
            border: Border.all(color: dentro ? Cra.hoja.withValues(alpha: 0.4) : Cra.linea),
          ),
          child: Row(
            children: [
              Badge(
                isLabelVisible: n > 0,
                backgroundColor: Cra.sol,
                textColor: Cra.raiz,
                label: Text(n > 99 ? '99+' : '$n'),
                child: Icon(Icons.shield_outlined, color: dentro ? Cra.hoja : Cra.textoSuave, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Panel CRA', style: tt.titleSmall),
                    Text(subtitulo, style: tt.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Cra.textoTenue),
            ],
          ),
        ),
      ),
    );
  }
}
