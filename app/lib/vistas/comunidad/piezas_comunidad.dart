import 'package:flutter/material.dart';

import '../../datos/comunidad/comunidad.dart';
import 'package:share_plus/share_plus.dart';

import '../../nucleo/base/hoja.dart';
import '../../nucleo/kit/menu_mantenido.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import 'alertas_diseno.dart';
import 'carrusel_noticias.dart';
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

  /// El diseño vive en `alertas_diseno.dart` (niveles, ícono por amenaza, sello de fuente).
  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: '${alerta.nivel.texto}: ${alerta.titulo}',
        child: TarjetaAlertaZ(alerta: alerta, extra: extra, expandida: !compacta),
      );
}

/// El mismo mensaje que arma `compartir()` en AlertasManglar.tsx.
String textoCompartirAlerta(AlertaManglar a) =>
    '${a.nivel == NivelAlerta.roja ? '🔴' : a.nivel == NivelAlerta.naranja ? '🟠' : '🟡'} ${sinPuntosCra(a.titulo)}\n'
    '${sinPuntosCra(a.detalle)}\n👉 ${sinPuntosCra(a.recomendacion)}\n\nMás en https://mimanglar.sentralabs.co/#alertas';

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
              'Respaldo: ${sinPuntosCra(a.fuentesTexto)}'
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

/// Marcador de alerta en el mapa: anillo que respira según el nivel, ícono de la amenaza y conteo
/// (el diseño, en `alertas_diseno.dart`).
class MarcadorAlerta extends StatelessWidget {
  const MarcadorAlerta({super.key, required this.alerta, required this.alTocar, this.conteo = 1});
  final AlertaManglar alerta;
  final VoidCallback alTocar;
  final int conteo;
  @override
  Widget build(BuildContext context) => Presionable(
        etiqueta: '${alerta.nivel.texto}: ${alerta.titulo}${conteo > 1 ? ' y ${conteo - 1} avisos más' : ''}',
        onTap: alTocar,
        child: MarcadorAlertaZ(alerta: alerta, conteo: conteo),
      );
}

/// Tarjeta de noticia: foto, fuente, fecha y título; se lee dentro de la app.
/// Tocar: leer. Mantener: vista previa con Leer, Guardar, Compartir y Ocultar. En la destacada,
/// deslizar a la derecha guarda y a la izquierda oculta (con «Deshacer»); en el carrusel no se
/// desliza para no pelear con el desplazamiento horizontal.
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
        vistaPrevia: (_) => VistaPreviaNoticia(noticia: n),
        acciones: accionesNoticia(context, n),
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
                child: Hero(tag: 'noticia-${n.id}', child: FotoNoticia(url: n.imagen, semilla: n.titulo)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${sinPuntosCra(n.fuente).toUpperCase()} · ${fechaCorta(n.fecha)}',
                        style: tt.seccion.copyWith(color: Cra.azul, fontSize: 10.5)),
                    const SizedBox(height: 6),
                    Text(sinPuntosCra(n.titulo),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: (destacada ? tt.titleLarge : tt.titleSmall)
                            ?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800, height: 1.25)),
                    if (destacada && n.resumen.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(sinPuntosCra(n.resumen),
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

/// La foto local (en `assets/fotos/`) que mejor va con un evento o una noticia, por palabras del
/// tipo, el título o el lugar; si ninguna coincide, una fija por el texto (no cambia entre cuadros).
String fotoLocalPara(String texto) {
  final t = texto.toLowerCase();
  bool hay(List<String> l) => l.any(t.contains);
  if (hay(['aves', 'garza', 'pájar', 'pajar', 'fauna', 'avistamiento'])) return 'assets/fotos/garza-mallorquin.webp';
  if (hay(['caño', 'cano', 'agua', 'basura', 'recolec', 'limpieza', 'residuo', 'bocas'])) {
    return 'assets/fotos/cano-san-bernardo.webp';
  }
  if (hay(['sendero', 'recorrido', 'caminata', 'visita', 'mallorqu'])) return 'assets/fotos/sendero-mallorquin.webp';
  if (hay(['siembra', 'sembr', 'mangle', 'raíz', 'raiz', 'vivero', 'restaura'])) {
    return 'assets/fotos/manglar-raices-cartagena.webp';
  }
  const todas = [
    'assets/fotos/manglar-raices-cartagena.webp',
    'assets/fotos/sendero-mallorquin.webp',
    'assets/fotos/garza-mallorquin.webp',
    'assets/fotos/cano-san-bernardo.webp',
  ];
  var h = 0;
  for (final c in t.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return todas[h % todas.length];
}

/// La CRA se escribe «CRA» en toda la app, aunque el texto venga del servidor con puntos.
String sinPuntosCra(String s) => s.replaceAll('C.R.A.', 'CRA').replaceAll('C.R.A', 'CRA');

/// Foto de la noticia o del evento. Debajo siempre hay una foto local del manglar elegida por
/// [semilla] (tipo, título, lugar) con un degradado de la marca y el rótulo «Foto de referencia»;
/// la real se funde encima cuando llega. Sin foto, sin señal o si el servidor no deja leerla
/// (CORS en la web), queda la local: nunca un rectángulo vacío.
class FotoNoticia extends StatelessWidget {
  const FotoNoticia({super.key, required this.url, this.semilla});
  final String? url;
  final String? semilla;
  @override
  Widget build(BuildContext context) {
    final local = Stack(fit: StackFit.expand, children: [
      Image.asset(
        fotoLocalPara(semilla ?? url ?? ''),
        fit: BoxFit.cover,
        cacheWidth: 1200,
        errorBuilder: (_, _, _) => const ColoredBox(color: Cra.azul),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x000A2A47), Color(0x8C0A2A47)],
            stops: [0.45, 1],
          ),
        ),
      ),
      Positioned(
        right: 8,
        bottom: 6,
        child: ExcludeSemantics(
          child: Text('Foto de referencia',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70, fontSize: 10)),
        ),
      ),
    ]);
    if (url == null || url!.isEmpty) return local;
    return Stack(fit: StackFit.expand, children: [
      local,
      Image.network(
        url!,
        fit: BoxFit.cover,
        frameBuilder: (_, hijo, cuadro, sincronico) => sincronico
            ? hijo
            : AnimatedOpacity(
                opacity: cuadro == null ? 0 : 1,
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Zm.medio,
                curve: Zm.entrar,
                child: hijo,
              ),
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    ]);
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
