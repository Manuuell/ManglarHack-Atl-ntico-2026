import 'package:flutter/material.dart';

import '../../datos/comunidad/comunidad.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/kit/ruta_borde.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import 'carrusel_noticias.dart';

/// Abre la noticia dentro de la app (nunca el navegador del sistema), con el gesto de borde de iOS.
/// [lista]: las noticias del carrusel, para ofrecer «Siguiente noticia» al final.
Future<void> abrirNoticia(BuildContext context, NoticiaManglar n, {List<NoticiaManglar> lista = const []}) =>
    abrirConBorde<void>(context, (_) => LectorNoticia(noticia: n, lista: lista), settings: const RouteSettings(name: 'noticia'));

/// Cuánto hay que tirar hacia abajo desde arriba para cerrar el lector.
const double umbralCerrarLector = 110;

/// Lector de una noticia de la CRA: foto grande que se estira al tirar hacia abajo, barra de progreso
/// de lectura, tema, fuente, fecha y minutos, el texto en párrafos (sin HTML) y la siguiente al final.
/// Tirar hacia abajo más de [umbralCerrarLector] y soltar lo cierra.
class LectorNoticia extends StatefulWidget {
  const LectorNoticia({super.key, required this.noticia, this.lista = const []});
  final NoticiaManglar noticia;
  final List<NoticiaManglar> lista;

  @override
  State<LectorNoticia> createState() => _LectorNoticiaState();
}

class _LectorNoticiaState extends State<LectorNoticia> {
  final _scroll = ScrollController();
  final _progreso = ValueNotifier<double>(0);
  final _tiron = ValueNotifier<double>(0);
  bool _pasoUmbral = false;
  bool _cerrando = false;

  NoticiaManglar? get _siguiente {
    final l = widget.lista;
    if (l.length < 2) return null;
    final i = l.indexWhere((x) => x.id == widget.noticia.id);
    if (i < 0) return null;
    return l[(i + 1) % l.length];
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final p = _scroll.position;
      _progreso.value = p.maxScrollExtent <= 0 ? 1 : (p.pixels / p.maxScrollExtent).clamp(0.0, 1.0);
      _tiron.value = (-p.pixels).clamp(0.0, 400.0);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _progreso.dispose();
    _tiron.dispose();
    super.dispose();
  }

  bool _alDesplazar(ScrollNotification s) {
    if (s.depth != 0 || _cerrando) return false;
    if (s is ScrollUpdateNotification) {
      if (s.dragDetails != null) {
        final paso = -s.metrics.pixels > umbralCerrarLector;
        if (paso != _pasoUmbral) {
          _pasoUmbral = paso;
          if (paso) vibrar(Vibracion.ligera);
        }
      } else if (_pasoUmbral) {
        _cerrar();
      }
    } else if (s is ScrollEndNotification && _pasoUmbral) {
      _cerrar();
    }
    return false;
  }

  void _cerrar() {
    _cerrando = true;
    Navigator.of(context).maybePop();
  }

  void _abrirSiguiente(NoticiaManglar s) {
    vibrar(Vibracion.ligera);
    Navigator.of(context).pushReplacement(RutaBorde<void>(
      builder: (_) => LectorNoticia(noticia: s, lista: widget.lista),
      settings: const RouteSettings(name: 'noticia'),
      sinMovimiento: MediaQuery.disableAnimationsOf(context),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final n = widget.noticia;
    final arriba = MediaQuery.paddingOf(context).top;
    final sinMov = MediaQuery.disableAnimationsOf(context);
    final siguiente = _siguiente;
    return Scaffold(
      backgroundColor: Zc.arena,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: LayoutBuilder(builder: (context, caja) {
            final altoFoto = (caja.maxWidth * 10 / 16).clamp(200.0, 450.0);
            return Stack(children: [
              NotificationListener<ScrollNotification>(
                onNotification: _alDesplazar,
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: altoFoto,
                        // Estirar al tirar: la foto crece desde abajo lo mismo que se tira (solo transform).
                        child: ValueListenableBuilder<double>(
                          valueListenable: _tiron,
                          child: Hero(
                            tag: 'noticia-${n.id}',
                            child: FotoConRespaldo(url: n.imagen, semilla: n.id, credito: true),
                          ),
                          builder: (_, t, hijo) => sinMov
                              ? hijo!
                              : Transform.scale(scale: 1 + t / altoFoto, alignment: Alignment.bottomCenter, child: hijo),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                      sliver: SliverList.list(children: [
                        Row(children: [
                          PildoraCategoria(categoriaDe(n)),
                          const SizedBox(width: 8),
                          PildoraLectura(minutosLectura(n), oscura: false),
                        ]),
                        const SizedBox(height: 12),
                        Text(rotuloNoticia(n).toUpperCase(), style: tt.seccion.copyWith(color: Cra.azul)),
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
                        if (siguiente != null) ...[
                          const SizedBox(height: 24),
                          _SiguienteNoticia(noticia: siguiente, alTocar: () => _abrirSiguiente(siguiente)),
                        ],
                        SizedBox(height: 40 + MediaQuery.paddingOf(context).bottom),
                      ]),
                    ),
                  ],
                ),
              ),
              // Barra de progreso de lectura: dorada, bajo la barra de estado (solo transform).
              Positioned(
                top: arriba,
                left: 0,
                right: 0,
                height: 3,
                child: IgnorePointer(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _progreso,
                    child: const ColoredBox(color: Cra.dorado),
                    builder: (_, p, hijo) => Transform(
                      alignment: Alignment.centerLeft,
                      transform: Matrix4.diagonal3Values(p, 1, 1),
                      child: hijo,
                    ),
                  ),
                ),
              ),
              // Pista de «suelta para cerrar» al tirar hacia abajo (solo opacity y transform).
              Positioned(
                top: arriba + 10,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _tiron,
                    builder: (_, t, _) {
                      final f = (t / umbralCerrarLector).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: f,
                        child: Center(
                          child: Transform.scale(
                            scale: 0.8 + 0.2 * f,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                              child: Icon(f >= 1 ? Icons.close_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
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
                  alTocar: () => compartirNoticia(context, n),
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

/// «Siguiente noticia»: miniatura, tema y título; tocar la abre en lugar de esta.
class _SiguienteNoticia extends StatelessWidget {
  const _SiguienteNoticia({required this.noticia, required this.alTocar});
  final NoticiaManglar noticia;
  final VoidCallback alTocar;
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final n = noticia;
    return Presionable(
      escala: 0.98,
      etiqueta: 'Siguiente noticia: ${n.titulo}',
      onTap: alTocar,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Cra.azul,
          borderRadius: BorderRadius.circular(Zr.l),
          boxShadow: const [BoxShadow(color: Color(0x290A2A47), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: 112, child: FotoConRespaldo(url: n.imagen, semilla: n.id, anchoCache: 300)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('SIGUIENTE NOTICIA', style: tt.seccion.copyWith(color: Cra.dorado, fontSize: 10.5)),
                  const SizedBox(height: 6),
                  Text(n.titulo,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.25)),
                  const SizedBox(height: 6),
                  Text('${categoriaDe(n).nombre} · ${minutosLectura(n)} min',
                      style: tt.labelSmall?.copyWith(color: Cra.textoSuave)),
                ]),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.arrow_forward_ios_rounded, color: Cra.dorado, size: 18),
            ),
          ]),
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
