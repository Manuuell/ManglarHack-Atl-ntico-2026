import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../datos/comunidad/comunidad.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/ruta_borde.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import 'piezas_comunidad.dart';

/// Abre la noticia dentro de la app (nunca el navegador del sistema), con el gesto de borde de iOS.
Future<void> abrirNoticia(BuildContext context, NoticiaManglar n) =>
    abrirConBorde<void>(context, (_) => LectorNoticia(noticia: n), settings: const RouteSettings(name: 'noticia'));

/// Lector de una noticia de la CRA: foto, fuente, fecha y el texto en párrafos (sin HTML).
class LectorNoticia extends StatelessWidget {
  const LectorNoticia({super.key, required this.noticia});
  final NoticiaManglar noticia;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final n = noticia;
    final arriba = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Zc.arena,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Hero(tag: 'noticia-${n.id}', child: FotoNoticia(url: n.imagen)),
                    ),
                    Positioned(
                      top: arriba + 8,
                      left: 12,
                      child: _BotonFoto(
                        icono: Icons.arrow_back_ios_new_rounded,
                        etiqueta: 'Volver',
                        alTocar: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    Positioned(
                      top: arriba + 8,
                      right: 12,
                      child: _BotonFoto(
                        icono: Icons.ios_share_rounded,
                        etiqueta: 'Compartir noticia',
                        alTocar: () async {
                          try {
                            await SharePlus.instance.share(ShareParams(text: '${n.titulo}\n${n.enlace}', subject: n.titulo));
                          } catch (_) {
                            await Clipboard.setData(ClipboardData(text: n.enlace));
                            if (context.mounted) avisar(context, 'Enlace copiado');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 60),
                sliver: SliverList.list(children: [
                  Text('${n.fuente.toUpperCase()} · ${fechaCorta(n.fecha)}', style: tt.seccion.copyWith(color: Cra.azul)),
                  const SizedBox(height: 8),
                  Text(n.titulo, style: tt.headlineSmall?.copyWith(color: Zc.texto, fontWeight: FontWeight.w900, height: 1.2)),
                  const SizedBox(height: 16),
                  for (final p in n.parrafos.isEmpty ? [n.resumen] : n.parrafos) ...[
                    SelectableText(p, style: tt.bodyLarge?.copyWith(color: Zc.texto, height: 1.55)),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Publicada por la Corporación Autónoma Regional del Atlántico en crautonoma.gov.co. '
                    'Zanky solo la muestra para leerla sin salir de la app.',
                    style: tt.labelMedium?.copyWith(color: Zc.textoSuave, height: 1.4),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonFoto extends StatelessWidget {
  const _BotonFoto({required this.icono, required this.etiqueta, required this.alTocar});
  final IconData icono;
  final String etiqueta;
  final VoidCallback alTocar;
  @override
  Widget build(BuildContext context) => Presionable(
        etiqueta: etiqueta,
        onTap: alTocar,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.42), shape: BoxShape.circle),
          child: Icon(icono, color: Colors.white, size: 20),
        ),
      );
}
