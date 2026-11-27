import 'package:flutter/material.dart';

import '../../datos/comunidad/comunidad.dart';
import '../../datos/comunidad/feed.dart';
import '../../datos/comunidad/marcas_comunidad.dart';
import '../../datos/experiencia/jornada.dart';
import '../../nucleo/base/esqueleto.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/kit/accion_gesto.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/estado_vacio.dart';
import '../../nucleo/kit/fila_deslizable.dart';
import '../../nucleo/kit/menu_mantenido.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../mapa/marcadores.dart' show tintaSobre;
import '../mis_reportes/gestos_reporte.dart' show copiarCodigoReporte;
import '../raiz.dart';
import 'detalle_evento.dart';
import 'piezas_comunidad.dart';

/// Lleva al mapa y lo centra en el punto (el mapa escucha [puntoPedidoMapa]).
void verEnMapa(BuildContext context, ReporteFeed r) {
  puntoPedidoMapa.value = r.publico.punto;
  Navigator.of(context).popUntil((ruta) => ruta.isFirst);
  Raiz.irA(context, 1);
}

/// Rótulo pequeño: «Simulado», «Respaldo», «WhatsApp»…
class Rotulo extends StatelessWidget {
  const Rotulo(this.texto, {super.key, this.color = Zc.textoSuave, this.icono});
  final String texto;
  final Color color;
  final IconData? icono;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icono != null) ...[Icon(icono, size: 12, color: color), const SizedBox(width: 4)],
          Text(texto, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _Prioridad extends StatelessWidget {
  const _Prioridad(this.p);
  final int p;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Prioridad $p',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Zc.dePrioridad(p), borderRadius: BorderRadius.circular(99)),
          child: Text('P$p', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tintaSobre(Zc.dePrioridad(p)))),
        ),
      );
}

// ------------------------------------------------------------------ feed de reportes

/// «Lo que reporta la comunidad»: reales (Supabase + datos abiertos) y simulados rotulados.
class SeccionFeed extends StatelessWidget {
  const SeccionFeed({super.key, required this.feed, required this.origen, required this.cuando, this.maximo = 12});

  /// null: cargando.
  final List<ReporteFeed>? feed;
  final OrigenDato? origen;
  final DateTime? cuando;
  final int maximo;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final f = feed;
    final reales = f == null ? 0 : contarReales(f);
    final simulados = f == null ? 0 : f.length - reales;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TituloSeccion(
        antetitulo: 'Mapa en vivo',
        titulo: 'Lo que reporta',
        tono: 'la comunidad.',
        accion: 'Ver mapa',
        alAccion: () {
          Navigator.of(context).popUntil((r) => r.isFirst);
          Raiz.irA(context, 1);
        },
      ),
      if (f == null)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [Esqueleto.fila(), SizedBox(height: 8), Esqueleto.fila(), SizedBox(height: 8), Esqueleto.fila()]),
        )
      else ...[
        if (origen != null) NotaOrigen(origen: origen!, cuando: cuando),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(reales == 0 ? 'Aún sin reportes reales recientes' : 'Los más recientes primero',
                style: tt.titleSmall?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800)),
            if (simulados > 0) Rotulo('+ $simulados simulados, no cuentan', color: Cra.recuperacion, icono: Icons.science_rounded),
          ]),
        ),
        if (f.isEmpty)
          const EstadoVacio(
            titulo: 'Aún no hay reportes públicos',
            texto: 'Cuando alguien reporte por la app, la web o WhatsApp, aparecerá aquí.',
            tamanoZanky: 90,
            relleno: EdgeInsets.fromLTRB(28, 0, 28, 8),
          )
        else
          for (final r in f.take(maximo))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TarjetaReporte(r: r),
            ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text(
            'La ubicación sale redondeada (~100 m) y sin nombre, para proteger a quien denuncia. '
            'Los marcados «Simulado» son de demostración. Desliza a la izquierda para verlo en el mapa; '
            'mantén presionado para la vista previa.',
            style: tt.labelSmall?.copyWith(color: Zc.textoSuave, height: 1.4),
          ),
        ),
      ],
    ]);
  }
}

/// Tarjeta de un reporte: tipo, zona, estado, hace cuánto, prioridad y canal. Tocar abre la ficha;
/// mantener muestra la vista previa; deslizar a la izquierda, «Ver en el mapa».
class TarjetaReporte extends StatelessWidget {
  const TarjetaReporte({super.key, required this.r});
  final ReporteFeed r;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final p = r.publico;
    final mapa = AccionGesto(
      etiqueta: 'Ver en el mapa',
      icono: Icons.map_rounded,
      color: Cra.azul,
      alEjecutar: () => verEnMapa(context, r),
    );
    final ficha = AccionGesto(etiqueta: 'Ver ficha', icono: Icons.description_rounded, alEjecutar: () => abrirFichaReporte(context, r));
    // Copiar y compartir el código del caso: solo los reales (un simulado no se difunde como caso).
    final copiar = AccionGesto(
      etiqueta: 'Copiar código ${p.id}',
      icono: Icons.copy_rounded,
      alEjecutar: () => copiarCodigoReporte(context, p.id),
    );
    final compartir = AccionGesto(
      etiqueta: 'Compartir caso',
      icono: Icons.ios_share_rounded,
      color: Zc.cienaga,
      alEjecutar: () => compartirCasoFeed(context, r),
    );
    final contenido = Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Zc.superficie,
        borderRadius: BorderRadius.circular(Zr.m),
        border: r.simulado ? Border.all(color: Cra.recuperacion.withValues(alpha: 0.35)) : null,
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: p.tipo.color.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: Icon(p.tipo.icono, size: 20, color: p.tipo.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(p.tipo.nombre,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(color: Zc.texto, fontWeight: FontWeight.w700)),
              ),
              if (r.simulado) ...[const SizedBox(width: 6), const Rotulo('Simulado', color: Cra.recuperacion)],
              if (r.prueba && !r.simulado) ...[const SizedBox(width: 6), const Rotulo('Prueba', color: Zc.textoSuave)],
            ]),
            const SizedBox(height: 2),
            Text(
              '${nombreZona(p.zona)} · ${p.estado.nombre} · ${haceCuanto(p.capturadoEn)}'
              '${r.porWhatsapp ? ' · por WhatsApp' : ' · por la app'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.labelMedium?.copyWith(color: Zc.textoSuave),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        _Prioridad(p.prioridad),
      ]),
    );
    return MenuMantenido(
      etiqueta: '${r.simulado ? 'Simulado. ' : ''}${p.tipo.nombre} en ${nombreZona(p.zona)}, ${p.estado.nombre}, '
          '${haceCuanto(p.capturadoEn)}, prioridad ${p.prioridad}',
      radio: BorderRadius.circular(Zr.m),
      alTocar: () => abrirFichaReporte(context, r),
      vistaPrevia: (_) => _FichaReporte(r: r, conBoton: false),
      acciones: [ficha, mapa, if (!r.simulado) ...[compartir, copiar]],
      child: FilaDeslizable(
        radio: BorderRadius.circular(Zr.m),
        accionesInicio: [if (!r.simulado) compartir],
        accionesFin: [mapa],
        hijo: contenido,
      ),
    );
  }
}

/// Comparte el caso del feed: código, tipo, zona y estado. Nunca coordenadas exactas ni datos de quien reporta.
Future<void> compartirCasoFeed(BuildContext context, ReporteFeed r) async {
  final p = r.publico;
  final texto = 'Caso ${p.id} en Zanky: ${p.tipo.nombre} en ${nombreZona(p.zona)}. Estado: ${p.estado.nombre}.'
      '${r.prueba ? ' (Reporte de prueba)' : ''}';
  try {
    await SharePlus.instance.share(ShareParams(text: texto, subject: 'Caso ${p.id} en Zanky'));
  } catch (_) {
    if (context.mounted) avisar(context, 'No pude abrir el menú de compartir.', tipo: TipoAviso.error);
  }
}

Future<void> abrirFichaReporte(BuildContext context, ReporteFeed r) =>
    mostrarHojaZ<void>(context, nombre: 'ficha-reporte', contenido: (_) => _FichaReporte(r: r));

class _FichaReporte extends StatelessWidget {
  const _FichaReporte({required this.r, this.conBoton = true});
  final ReporteFeed r;
  final bool conBoton;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final p = r.publico;
    Widget fila(IconData i, String t, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, size: 18, color: Zc.textoTenue),
            const SizedBox(width: 10),
            SizedBox(width: 92, child: Text(t, style: tt.labelMedium?.copyWith(color: Zc.textoSuave))),
            Expanded(child: Text(v, style: tt.bodyMedium?.copyWith(color: Zc.texto))),
          ]),
        );
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: p.tipo.color.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: Icon(p.tipo.icono, size: 26, color: p.tipo.color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.tipo.nombre, style: tt.titleLarge?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800)),
            Text(nombreZona(p.zona), style: tt.bodyMedium?.copyWith(color: Zc.textoSuave)),
          ]),
        ),
        _Prioridad(p.prioridad),
      ]),
      if (r.simulado) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Cra.recuperacion.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Zr.s)),
          child: Row(children: [
            const Icon(Icons.science_rounded, size: 18, color: Cra.recuperacion),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Simulado: reporte de demostración. No es real y no se suma a las cifras.',
                  style: tt.labelMedium?.copyWith(color: Zc.texto)),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      fila(Icons.flag_rounded, 'Estado', '${p.estado.nombre}. ${p.estado.explicacion}'),
      fila(Icons.schedule_rounded, 'Cuándo', '${haceCuanto(p.capturadoEn)} (${cuandoTexto(p.capturadoEn)})'),
      fila(r.porWhatsapp ? Icons.chat_rounded : Icons.phone_iphone_rounded, 'Canal', r.porWhatsapp ? 'WhatsApp' : 'App o web de Zanky'),
      fila(Icons.place_rounded, 'Dónde',
          '${p.punto.latitude.toStringAsFixed(3)}, ${p.punto.longitude.toStringAsFixed(3)} (redondeado, ~100 m)'),
      fila(Icons.photo_rounded, 'Foto', 'Las fotos no se publican: solo las ve la CRA'),
      if (conBoton) ...[
        const SizedBox(height: 14),
        BotonZ(texto: 'Ver en el mapa', icono: Icons.map_rounded, onTap: () => verEnMapa(context, r)),
      ],
    ]);
  }
}

// ------------------------------------------------------------------ eventos

/// Como la web y el bot desplegado: las jornadas no tienen límite de cupos; se dice cuántos van.
String textoCupos(Jornada j) => '${j.inscritos} ${j.inscritos == 1 ? 'inscrito' : 'inscritos'} · cupos sin límite';

/// La jornada que «Próximo evento» muestra en grande en Inicio: «Próximas jornadas» la salta para
/// no repetirla.
final proximoEventoMostrado = ValueNotifier<String?>(null);

/// Tirar para actualizar en Inicio lo sube: alertas, noticias y «Próximo evento» se vuelven a pedir
/// sin volver a mostrar esqueletos (lo que ya se ve se queda hasta que llega lo nuevo).
final recargaComunidadInicio = ValueNotifier<int>(0);

/// Tarjeta de un evento: foto, tipo, fecha, lugar, inscritos e inscripción.
/// - Tocar: abre el detalle (la foto viaja con Hero).
/// - Mantener: vista previa con Inscribirme / Al calendario, Ver en el mapa, Compartir y Abrir.
/// - Deslizar a la derecha: inscribirme (o «Al calendario» si ya lo estoy); a la izquierda: compartir.
class TarjetaEvento extends StatelessWidget {
  const TarjetaEvento({super.key, required this.e, required this.alInscribirse, this.compacta = false, this.fuente});
  final EventoCartelera e;
  final VoidCallback? alInscribirse;
  final bool compacta;
  final FuenteComunidad? fuente;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final j = e.jornada;
    final semilla = '${j.tipo} ${j.titulo} ${j.puntoEncuentro}';
    void abrir() => abrirDetalleEvento(context, e, fuente: fuente);
    return ValueListenableBuilder<Set<String>>(
      valueListenable: jornadasInscritas,
      builder: (context, inscritas, _) {
        final ya = inscritas.contains(j.id);
        final compartir = AccionGesto(
          etiqueta: 'Compartir',
          icono: Icons.ios_share_rounded,
          color: Cra.azul,
          alEjecutar: () => compartirJornada(j),
        );
        final calendario = AccionGesto(
          etiqueta: 'Al calendario',
          icono: Icons.event_available_rounded,
          color: Zc.cienaga,
          alEjecutar: () => agregarJornadaAlCalendario(context, j),
        );
        final inscribir = AccionGesto(
          etiqueta: 'Inscribirme',
          icono: Icons.how_to_reg_rounded,
          color: Zc.hoja,
          alEjecutar: () => alInscribirse?.call(),
        );
        final principal = ya ? calendario : inscribir;
        return MenuMantenido(
          etiqueta: '${e.respaldo ? 'Respaldo, por confirmar. ' : ''}${ya ? 'Inscrito. ' : ''}${j.tipoLegible}: ${j.titulo}, '
              '${cuandoTexto(j.inicio.toLocal())}, ${j.puntoEncuentro}, ${textoCupos(j)}',
          radio: BorderRadius.circular(Zr.l),
          alTocar: abrir,
          vistaPrevia: (_) => _VistaPreviaEvento(e: e),
          acciones: [
            if (ya || alInscribirse != null) principal,
            if (tieneLugar(j))
              AccionGesto(etiqueta: 'Ver en el mapa', icono: Icons.map_rounded, alEjecutar: () => verJornadaEnMapa(context, j)),
            compartir,
            AccionGesto(etiqueta: 'Abrir', icono: Icons.open_in_full_rounded, alEjecutar: abrir),
          ],
          child: FilaDeslizable(
            radio: BorderRadius.circular(Zr.l),
            accionesInicio: [if (ya || alInscribirse != null) principal],
            accionesFin: [compartir],
            hijo: _cuerpo(context, tt, j, semilla, ya),
          ),
        );
      },
    );
  }

  Widget _cuerpo(BuildContext context, TextTheme tt, Jornada j, String semilla, bool ya) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Zc.superficie,
          borderRadius: BorderRadius.circular(Zr.l),
          boxShadow: const [BoxShadow(color: Color(0x140B2E24), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          AspectRatio(
            aspectRatio: compacta ? 21 / 9 : 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              Hero(tag: heroEvento(j), child: FotoNoticia(url: j.imagen?.toString(), semilla: semilla)),
              Positioned(left: 12, top: 12, child: _FechaGrande(j.inicio.toLocal())),
              if (e.respaldo || j.esEjemplo)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                    child: Text(j.esEjemplo ? 'Ejemplo' : 'Respaldo · por confirmar',
                        style: tt.labelSmall?.copyWith(color: Cra.azul, fontWeight: FontWeight.w800)),
                  ),
                ),
              // Microdetalle: la marca «Inscrito» brota con rebote cuando quedas en la lista.
              Positioned(
                left: 12,
                bottom: 12,
                child: AnimatedScale(
                  scale: ya ? 1 : 0,
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Zm.medio,
                  curve: Curves.easeOutBack,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Zc.hoja, borderRadius: BorderRadius.circular(99)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('Inscrito', style: tt.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(j.tipoLegible.toUpperCase(), style: tt.seccion.copyWith(color: Zc.cienaga)),
              const SizedBox(height: 4),
              Text(j.titulo,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleMedium?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 15, color: Zc.textoTenue),
                const SizedBox(width: 4),
                Flexible(child: Text(cuandoTexto(j.inicio.toLocal()), style: tt.labelMedium?.copyWith(color: Zc.textoSuave))),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.place_rounded, size: 15, color: Zc.textoTenue),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(j.puntoEncuentro.isEmpty ? 'Punto por confirmar' : j.puntoEncuentro,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelMedium?.copyWith(color: Zc.textoSuave)),
                ),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.groups_rounded, size: 15, color: Zc.textoTenue),
                const SizedBox(width: 4),
                Flexible(child: Text(textoCupos(j), style: tt.labelMedium?.copyWith(color: Zc.textoSuave))),
              ]),
              if (!compacta) ...[
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Zm.corto,
                  child: ya
                      ? BotonZ(
                          key: const ValueKey('ya'),
                          texto: 'Al calendario',
                          icono: Icons.event_available_rounded,
                          secundario: true,
                          onTap: () => agregarJornadaAlCalendario(context, j),
                        )
                      : BotonZ(key: const ValueKey('no'), texto: 'Inscribirme', icono: Icons.how_to_reg_rounded, onTap: alInscribirse),
                ),
              ],
            ]),
          ),
        ]),
      );
}

class _FechaGrande extends StatelessWidget {
  const _FechaGrande(this.d);
  final DateTime d;
  static const _meses = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEPT', 'OCT', 'NOV', 'DIC'];
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ExcludeSemantics(
      child: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Zr.s)),
        child: Column(children: [
          Text(_meses[d.month - 1], style: tt.labelSmall?.copyWith(color: Cra.riesgoMuyAlto, fontWeight: FontWeight.w800)),
          Text('${d.day}', style: tt.titleLarge?.copyWith(color: Cra.azul, fontWeight: FontWeight.w900, height: 1.1)),
        ]),
      ),
    );
  }
}

class _VistaPreviaEvento extends StatelessWidget {
  const _VistaPreviaEvento({required this.e});
  final EventoCartelera e;
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final j = e.jornada;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Zr.m),
        child: AspectRatio(
            aspectRatio: 16 / 9, child: FotoNoticia(url: j.imagen?.toString(), semilla: '${j.tipo} ${j.titulo} ${j.puntoEncuentro}')),
      ),
      const SizedBox(height: 12),
      Text(j.titulo, style: tt.titleMedium?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('${cuandoTexto(j.inicio.toLocal())} · ${j.puntoEncuentro}', style: tt.labelMedium?.copyWith(color: Zc.textoSuave)),
      const SizedBox(height: 4),
      Text('${textoCuentaRegresiva(j.inicio, j.fin, DateTime.now())} · ${textoCupos(j)}',
          style: tt.labelMedium?.copyWith(color: Cra.azul, fontWeight: FontWeight.w700)),
      if (j.descripcion.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(j.descripcion, maxLines: 5, overflow: TextOverflow.ellipsis, style: tt.bodyMedium?.copyWith(color: Zc.textoSuave, height: 1.4)),
      ],
      if (j.queLlevar.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Qué llevar: ${j.queLlevar.join(', ')}', style: tt.bodySmall?.copyWith(color: Zc.texto)),
      ],
    ]);
  }
}

/// Esqueleto con la forma exacta de [TarjetaEvento] (foto 16:9 o 21:9 y cuatro líneas): al llegar
/// los datos no salta nada.
class EsqueletoEvento extends StatelessWidget {
  const EsqueletoEvento({super.key, this.compacta = false});
  final bool compacta;
  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Zc.superficie, borderRadius: BorderRadius.circular(Zr.l)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          AspectRatio(
            aspectRatio: compacta ? 21 / 9 : 16 / 9,
            child: const Skeleton(width: double.infinity, height: double.infinity, borderRadius: BorderRadius.zero),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Skeleton(width: 70, height: 10),
              const SizedBox(height: 8),
              const Skeleton(width: 220, height: 16),
              const SizedBox(height: 10),
              const Skeleton(width: 160, height: 11),
              const SizedBox(height: 6),
              const Skeleton(width: 190, height: 11),
              if (!compacta) ...[const SizedBox(height: 14), const Skeleton(width: double.infinity, height: 48)],
            ]),
          ),
        ]),
      );
}

/// La cartelera de eventos de Comunidad.
class SeccionEventos extends StatelessWidget {
  const SeccionEventos({super.key, required this.eventos, required this.alInscribirse, this.fuente});
  final List<EventoCartelera>? eventos;
  final void Function(Jornada) alInscribirse;
  final FuenteComunidad? fuente;

  @override
  Widget build(BuildContext context) {
    final ev = eventos;
    return LayoutBuilder(builder: (context, c) {
      final dos = c.maxWidth >= 720;
      final ancho = dos ? (c.maxWidth - 40 - 12) / 2 : c.maxWidth - 40;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const TituloSeccion(antetitulo: 'Cartelera', titulo: 'Eventos y jornadas', tono: 'para sumarte.'),
        if (ev == null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SizedBox(width: ancho, child: const EsqueletoEvento()))
        else if (ev.isEmpty)
          const EstadoVacio(
            titulo: 'No hay jornadas programadas',
            texto: 'Cuando la CRA o un organizador publique una, aparecerá aquí.',
            tamanoZanky: 90,
            relleno: EdgeInsets.fromLTRB(28, 0, 28, 8),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(spacing: 12, runSpacing: 12, children: [
              for (final e in ev.take(6))
                SizedBox(
                  width: ancho,
                  child: TarjetaEvento(e: e, fuente: fuente, alInscribirse: () => alInscribirse(e.jornada)),
                ),
            ]),
          ),
        if (ev != null && ev.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              '${ev.any((e) => e.respaldo) ? '«Respaldo · por confirmar»: jornadas guardadas en la app; el servidor aún no las publica. ' : ''}'
              'Desliza una tarjeta a la derecha para inscribirte y a la izquierda para compartirla; mantén presionado para la vista previa.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Zc.textoSuave, height: 1.4),
            ),
          ),
      ]);
    });
  }
}

/// Tarjeta «Próximo evento» de Inicio: lo guardado primero y luego la red, completado con el respaldo.
/// Tocar abre el detalle; «Inscribirme» (deslizar o mantener) abre la hoja de inscripción.
class ProximoEventoInicio extends StatefulWidget {
  const ProximoEventoInicio({super.key, this.fuente, required this.alAbrir});
  final FuenteJornadas? fuente;

  /// Abre Comunidad (el «Ver todos»).
  final VoidCallback alAbrir;
  @override
  State<ProximoEventoInicio> createState() => _ProximoEventoInicioState();
}

class _ProximoEventoInicioState extends State<ProximoEventoInicio> {
  late final FuenteJornadas _f = widget.fuente ?? FuenteJornadas();
  EventoCartelera? _proximo;
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    jornadasInscritas.cargar();
    recargaComunidadInicio.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    recargaComunidadInicio.removeListener(_cargar);
    if (proximoEventoMostrado.value == _proximo?.jornada.id) proximoEventoMostrado.value = null;
    super.dispose();
  }

  Future<void> _cargar() async {
    final respaldo = await cargaJornadasRespaldo();
    Future<void> usar(List<Jornada> l) async {
      final ahora = DateTime.now();
      // Solo las que no han terminado: «Próximo» nunca muestra una jornada pasada.
      final c = completarCartelera(l, respaldo).where((e) => !e.jornada.inicio.isBefore(ahora.subtract(const Duration(hours: 3))));
      if (mounted) {
        setState(() {
          _proximo = c.isEmpty ? null : c.first;
          _listo = true;
        });
        proximoEventoMostrado.value = _proximo?.jornada.id;
      }
    }

    try {
      await usar(await _f.cargarLocal());
      await usar(await _f.cargar());
    } catch (_) {
      if (mounted) setState(() => _listo = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final p = _proximo;
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Zm.medio,
      curve: Zm.entrar,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: Zm.corto,
        child: !_listo
            ? const Padding(
                key: ValueKey('esq'), padding: EdgeInsets.symmetric(horizontal: 20), child: EsqueletoEvento(compacta: true))
            : p == null
                ? const SizedBox(key: ValueKey('nada'), width: double.infinity)
                : Column(key: ValueKey(p.jornada.id), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
                      child: Row(children: [
                        Expanded(child: Text('PRÓXIMO EVENTO', style: tt.seccion.copyWith(color: Cra.azul))),
                        Presionable(
                          etiqueta: 'Ver todos los eventos',
                          onTap: widget.alAbrir,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Center(child: Text('Ver todos', style: tt.labelLarge?.copyWith(color: Zc.cienaga))),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TarjetaEvento(
                        e: p,
                        compacta: true,
                        alInscribirse: () => inscribirEnJornada(context, p.jornada),
                      ),
                    ),
                  ]),
      ),
    );
  }
}
