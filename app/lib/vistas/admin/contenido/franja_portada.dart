import 'package:flutter/material.dart';

import '../../../datos/admin/contenido_panel.dart';
import '../../../datos/admin/contenido_publico.dart';
import '../../../nucleo/identidad.dart';
import '../../../nucleo/tema.dart';

/// Arriba de Inicio: el mensaje destacado y el aviso del día que escribe el equipo en el panel
/// (Contenido › Portada). Si no hay nada, no ocupa espacio.
class FranjaPortada extends StatefulWidget {
  const FranjaPortada({super.key});

  @override
  State<FranjaPortada> createState() => _FranjaPortadaState();
}

class _FranjaPortadaState extends State<FranjaPortada> {
  @override
  void initState() {
    super.initState();
    cargarContenidoPublico();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ContenidoPanel>(
      valueListenable: contenidoPublico,
      builder: (context, c, _) {
        final p = c.portada;
        final aviso = p.avisoActivo && p.aviso.isNotEmpty;
        final hay = p.mensaje.isNotEmpty || aviso;
        final tt = Theme.of(context).textTheme;
        return AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context) ? const Duration(milliseconds: 1) : Zm.medio,
          curve: Zm.entrar,
          child: !hay
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Semantics(
                    container: true,
                    label: [if (p.mensaje.isNotEmpty) p.mensaje, if (aviso) 'Aviso del día: ${p.aviso}'].join('. '),
                    child: ExcludeSemantics(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        decoration: BoxDecoration(color: Cra.azul, borderRadius: BorderRadius.circular(Zr.l)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('DE LA CRA', style: tt.labelSmall?.copyWith(color: Cra.dorado, letterSpacing: 1.2)),
                          if (p.mensaje.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(p.mensaje, style: tt.titleMedium?.copyWith(color: Cra.blanco)),
                          ],
                          if (aviso) ...[
                            const SizedBox(height: 8),
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.campaign_rounded, color: Cra.dorado, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(p.aviso, style: tt.bodyMedium?.copyWith(color: Cra.blanco))),
                            ]),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
