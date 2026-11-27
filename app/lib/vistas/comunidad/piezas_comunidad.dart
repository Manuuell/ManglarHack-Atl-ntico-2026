import 'package:flutter/material.dart';

import '../../datos/comunidad/comunidad.dart';
import 'package:share_plus/share_plus.dart';

import '../../nucleo/base/hoja.dart';
import '../../nucleo/kit/accion_gesto.dart';
import '../../nucleo/kit/menu_mantenido.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import 'lector_noticia.dart';

/// Colores de los niveles de alerta, con los tonos de la paleta CRA (amarilla = dorado CRA).
Color colorNivel(NivelAlerta n) => switch (n) {
      NivelAlerta.amarilla => Cra.dorado,
      NivelAlerta.naranja => Cra.recuperacion,
      NivelAlerta.roja => Cra.riesgoMuyAlto,
    };

/// Título de sección como en la web: antetítulo en mayúsculas y título con la segunda parte en tono.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion({super.key, required this.antetitulo, required this.titulo, this.tono, this.accion, this.alAccion});
  final String antetitulo, titulo;
  final String? tono, accion;
  final VoidCallback? alAccion;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(antetitulo.toUpperCase(), style: tt.seccion.copyWith(color: Cra.azul)),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: titulo),
                    if (tono != null) TextSpan(text: ' $tono', style: const TextStyle(color: Zc.cienaga)),
                  ]),
                  style: tt.titleLarge?.copyWith(color: Zc.texto),
                ),
              ],
            ),
          ),
          if (accion != null)
            Presionable(
              etiqueta: accion!,
              onTap: alAccion,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Text(accion!, style: tt.labelLarge?.copyWith(color: Zc.cienaga)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Píldora del nivel («Alerta naranja»).
class EtiquetaNivel extends StatelessWidget {
  const EtiquetaNivel(this.nivel, {super.key});
  final NivelAlerta nivel;
  @override
  Widget build(BuildContext context) {
    final c = colorNivel(nivel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(nivel.texto,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Zc.texto, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Tarjeta de una alerta (la `Tarjeta` de AlertasManglar.tsx): nivel, medido o pronóstico, qué hacer, dónde,
/// cuándo y la fuente. [extra]: cuántas alertas más hay en el mismo lugar.
class TarjetaAlerta extends StatelessWidget {
  const TarjetaAlerta({super.key, required this.alerta, this.extra = 0, this.compacta = false});
  final AlertaManglar alerta;
  final int extra;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final a = alerta;
    final cuando = a.desde == a.hasta ? cuandoTexto(a.desde) : '${cuandoTexto(a.desde)} → ${cuandoTexto(a.hasta)}';
    return Semantics(
      container: true,
      label: '${a.nivel.texto}: ${a.titulo}',
      child: Container(
        decoration: BoxDecoration(
          color: Zc.superficie,
          borderRadius: BorderRadius.circular(Zr.m),
          border: Border(left: BorderSide(color: colorNivel(a.nivel), width: 4)),
          boxShadow: const [BoxShadow(color: Color(0x140B2E24), blurRadius: 18, offset: Offset(0, 6))],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              EtiquetaNivel(a.nivel),
              const Spacer(),
              Text(a.medido ? 'Medido' : 'Pronóstico', style: tt.labelSmall?.copyWith(color: Zc.textoSuave)),
            ]),
            const SizedBox(height: 10),
            Text('${a.icono} ${a.titulo}', style: tt.titleMedium?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800)),
            if (extra > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('y $extra ${extra == 1 ? 'aviso más' : 'avisos más'} en este lugar',
                    style: tt.labelSmall?.copyWith(color: Zc.textoSuave)),
              ),
            if (!compacta) ...[
              const SizedBox(height: 6),
              Text(a.detalle, style: tt.bodyMedium?.copyWith(color: Zc.textoSuave, height: 1.4)),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Qué hacer: ', style: TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: a.recomendacion),
                ]),
                style: tt.bodyMedium?.copyWith(color: Zc.texto, height: 1.4),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 6, children: [
              _Dato(icono: Icons.place_rounded, texto: a.lugar),
              _Dato(icono: Icons.schedule_rounded, texto: cuando),
              _Dato(icono: Icons.verified_rounded, texto: a.fuentesTexto),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});
  final IconData icono;
  final String texto;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 15, color: Zc.textoTenue),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(texto,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Zc.textoSuave)),
        ),
      ]);
}

/// El mismo mensaje que arma `compartir()` en AlertasManglar.tsx.
String textoCompartirAlerta(AlertaManglar a) =>
    '${a.nivel == NivelAlerta.roja ? '🔴' : a.nivel == NivelAlerta.naranja ? '🟠' : '🟡'} ${a.titulo}\n'
    '${a.detalle}\n👉 ${a.recomendacion}\n\nMás en https://mimanglar.sentralabs.co/#alertas';

/// Hoja con el detalle de una alerta (desde el mapa o Inicio).
/// [generado]: la hora en que el servidor cruzó las fuentes.
Future<void> abrirHojaAlerta(BuildContext context, AlertaManglar a, {int extra = 0, DateTime? generado}) =>
    mostrarHojaZ<void>(
      context,
      nombre: 'alerta',
      contenido: (c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TarjetaAlerta(alerta: a, extra: extra),
          const SizedBox(height: 12),
          Text(
              'Respaldo: ${a.fuentesTexto}'
              '${generado == null ? '' : ', cruzado por Zanky ${cuandoTexto(generado)}'}. '
              'No reemplaza los avisos oficiales de la CRA ni de la Gestión del Riesgo.',
              textAlign: TextAlign.center,
              style: Theme.of(c).textTheme.labelMedium?.copyWith(color: Zc.textoSuave)),
          const SizedBox(height: 14),
          // «Avisar por WhatsApp» de la web: el mismo texto, por la hoja de compartir del teléfono.
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: Cra.azul),
            onPressed: () => SharePlus.instance.share(ShareParams(text: textoCompartirAlerta(a))),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Avisar a mis vecinos'),
          ),
          const SizedBox(height: 10),
          Text('Si hay peligro para las personas, llama al 123.',
              textAlign: TextAlign.center,
              style: Theme.of(c).textTheme.labelMedium?.copyWith(color: Zc.textoSuave)),
        ],
      ),
    );

/// Marcador de alerta en el mapa: el ícono de la web sobre un círculo del color del nivel.
class MarcadorAlerta extends StatelessWidget {
  const MarcadorAlerta({super.key, required this.alerta, required this.alTocar});
  final AlertaManglar alerta;
  final VoidCallback alTocar;
  @override
  Widget build(BuildContext context) {
    final c = colorNivel(alerta.nivel);
    return Presionable(
      etiqueta: '${alerta.nivel.texto}: ${alerta.titulo}',
      onTap: alTocar,
      child: Center(
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: c, width: 3),
            boxShadow: [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 12)],
          ),
          child: Text(alerta.icono, style: const TextStyle(fontSize: 18, height: 1)),
        ),
      ),
    );
  }
}

/// La vista previa al mantener presionada una noticia: foto, fecha y el comienzo del texto.
class _VistaPreviaNoticia extends StatelessWidget {
  const _VistaPreviaNoticia({required this.noticia});
  final NoticiaManglar noticia;
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final n = noticia;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Zr.m),
        child: AspectRatio(aspectRatio: 16 / 9, child: FotoNoticia(url: n.imagen)),
      ),
      const SizedBox(height: 12),
      Text('${n.fuente.toUpperCase()} · ${fechaCorta(n.fecha)}', style: tt.seccion.copyWith(color: Cra.azul, fontSize: 10.5)),
      const SizedBox(height: 6),
      Text(n.titulo, style: tt.titleMedium?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800, height: 1.25)),
      const SizedBox(height: 8),
      Text(n.parrafos.take(2).join('\n\n'),
          maxLines: 7, overflow: TextOverflow.ellipsis, style: tt.bodyMedium?.copyWith(color: Zc.textoSuave, height: 1.45)),
    ]);
  }
}

/// Tarjeta de noticia: foto, fuente, fecha y título; se lee dentro de la app.
class TarjetaNoticia extends StatelessWidget {
  const TarjetaNoticia({super.key, required this.noticia, this.destacada = false, this.ancho});
  final NoticiaManglar noticia;
  final bool destacada;
  final double? ancho;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final n = noticia;
    return SizedBox(
      width: ancho,
      // Tocar abre la noticia dentro de la app; mantener presionado muestra la vista previa (peek)
      // con «Leer» y «Compartir».
      child: MenuMantenido(
        etiqueta: 'Leer: ${n.titulo}. Mantén presionado para ver la vista previa',
        radio: BorderRadius.circular(Zr.m),
        alTocar: () => abrirNoticia(context, n),
        vistaPrevia: (_) => _VistaPreviaNoticia(noticia: n),
        acciones: [
          AccionGesto(etiqueta: 'Leer aquí', icono: Icons.menu_book_rounded, alEjecutar: () => abrirNoticia(context, n)),
          AccionGesto(
            etiqueta: 'Compartir',
            icono: Icons.ios_share_rounded,
            alEjecutar: () => SharePlus.instance.share(ShareParams(text: '${n.titulo}\n${n.enlace}', subject: n.titulo)),
          ),
        ],
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Zc.superficie,
            borderRadius: BorderRadius.circular(Zr.m),
            boxShadow: const [BoxShadow(color: Color(0x140B2E24), blurRadius: 18, offset: Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: destacada ? 16 / 9 : 16 / 10,
                child: Hero(tag: 'noticia-${n.id}', child: FotoNoticia(url: n.imagen)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${n.fuente.toUpperCase()} · ${fechaCorta(n.fecha)}',
                        style: tt.seccion.copyWith(color: Cra.azul, fontSize: 10.5)),
                    const SizedBox(height: 6),
                    Text(n.titulo,
                        maxLines: destacada ? 3 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: (destacada ? tt.titleLarge : tt.titleSmall)
                            ?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800, height: 1.25)),
                    if (destacada && n.resumen.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(n.resumen,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(color: Zc.textoSuave, height: 1.4)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Foto de la noticia con fundido al llegar; sin foto o sin señal, un fondo de la marca.
class FotoNoticia extends StatelessWidget {
  const FotoNoticia({super.key, required this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    const fondo = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Cra.azul, Cra.superficie], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(child: Icon(Icons.newspaper_rounded, color: Cra.textoSuave, size: 34)),
    );
    if (url == null) return fondo;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      frameBuilder: (_, hijo, cuadro, sincronico) => sincronico
          ? hijo
          : AnimatedOpacity(
              opacity: cuadro == null ? 0 : 1,
              duration: Zm.corto,
              curve: Zm.entrar,
              child: hijo,
            ),
      errorBuilder: (_, _, _) => fondo,
    );
  }
}

/// Nota honesta de procedencia: «Sin señal: lo último guardado, de hace 2 h».
class NotaOrigen extends StatelessWidget {
  const NotaOrigen({super.key, required this.origen, required this.cuando});
  final OrigenDato origen;
  final DateTime? cuando;
  @override
  Widget build(BuildContext context) {
    if (origen == OrigenDato.red) return const SizedBox.shrink();
    final texto = origen == OrigenDato.cache
        ? 'Sin señal: lo último guardado${cuando == null ? '' : ', ${haceCuanto(cuando!)}'}.'
        : 'Sin señal y sin nada guardado todavía.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(children: [
        const Icon(Icons.cloud_off_rounded, size: 16, color: Zc.textoSuave),
        const SizedBox(width: 6),
        Expanded(child: Text(texto, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Zc.textoSuave))),
      ]),
    );
  }
}

/// Una cifra oficial de «Ahora» (de `/alertas`): viento, lluvia, ola, pleamar o calor.
class CifraOficial extends StatelessWidget {
  const CifraOficial({super.key, required this.c});
  final CifraAhora c;
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      width: 168,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Cra.azul, borderRadius: BorderRadius.circular(Zr.m)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${c.icono} ${c.titulo}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelMedium?.copyWith(color: Cra.textoSuave)),
        const SizedBox(height: 4),
        Text(c.valor, style: tt.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
        const Spacer(),
        Text(c.pie, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelSmall?.copyWith(color: Cra.textoTenue)),
      ]),
    );
  }
}
