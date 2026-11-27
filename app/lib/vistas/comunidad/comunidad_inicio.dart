import 'package:flutter/material.dart';

import '../../datos/comunidad/comunidad.dart';
import '../../nucleo/base/esqueleto.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../inicio/pronostico_compacto.dart';
import 'pantalla_comunidad.dart';
import '../../datos/experiencia/jornada.dart';
import 'feed_y_eventos.dart';
import 'piezas_comunidad.dart';
import '../../datos/admin/contenido_publico.dart';

/// En Inicio: la alerta oficial del servidor (`/alertas`, la misma de la portada web) con las cifras
/// oficiales de «Ahora», la entrada a «Comunidad» y la noticia destacada de la CRA
///
/// Las alertas del servidor son la ÚNICA fuente de alertas: las reglas locales con Open-Meteo solo
/// aparecen si no hay red ni copia guardada, y rotuladas como respaldo no oficial.
class ComunidadInicio extends StatefulWidget {
  const ComunidadInicio({super.key, this.fuente, this.respaldo, this.jornadas});
  final FuenteComunidad? fuente;
  final FuenteJornadas? jornadas;

  /// Lo que se ve sin alertas oficiales ni copia (por defecto, el pronóstico local). Para pruebas.
  final Widget? respaldo;

  @override
  State<ComunidadInicio> createState() => _ComunidadInicioState();
}

class _ComunidadInicioState extends State<ComunidadInicio> {
  late final FuenteComunidad _f = widget.fuente ?? FuenteComunidad.compartida;
  Lote<ResultadoAlertas>? _alertas;
  Lote<List<NoticiaManglar>>? _noticias;

  @override
  void initState() {
    super.initState();
    recargaComunidadInicio.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    recargaComunidadInicio.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    await Future.wait([
      _f.alertas().then((v) => mounted ? setState(() => _alertas = v) : null),
      _f.noticias().then(ajustarLoteNoticias).then((v) => mounted ? setState(() => _noticias = v) : null),
    ]);
  }

  Widget _alerta(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = _alertas;
    if (l == null) {
      return const Padding(
        key: ValueKey('esq-alerta'),
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Esqueleto.tarjeta(),
      );
    }
    if (l.origen == OrigenDato.nada) {
      return Column(key: const ValueKey('respaldo'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(children: [
            const Icon(Icons.cloud_off_rounded, size: 16, color: Zc.textoSuave),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Sin red: respaldo con reglas locales (Open-Meteo). No son alertas oficiales.',
                style: tt.labelMedium?.copyWith(color: Zc.textoSuave),
              ),
            ),
          ]),
        ),
        widget.respaldo ?? const PronosticoCompacto(),
      ]);
    }
    final d = l.datos;
    final grupos = d.porLugar;
    return Column(key: ValueKey('oficial-${grupos.length}'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      NotaOrigen(origen: l.origen, cuando: l.cuando),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TarjetaAlertaInicio(
          grupos: grupos,
          generado: d.generado,
          simulacro: d.simulacro,
          alTocar: grupos.isEmpty
              ? () => abrirComunidad(context)
              : () => abrirHojaAlerta(context, grupos.first.$1, extra: grupos.first.$2, generado: d.generado),
        ),
      ),
      if (d.ahora.isNotEmpty) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: d.ahora.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, k) => CifraOficial(c: d.ahora[k]),
          ),
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final noticia = (_noticias?.datos.isNotEmpty ?? false) ? _noticias!.datos.first : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnimatedSwitcher(duration: Zm.corto, switchInCurve: Zm.entrar, child: _alerta(context)),
      const SizedBox(height: 16),
      ProximoEventoInicio(fuente: widget.jornadas, alAbrir: () => abrirComunidad(context)),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Presionable(
          etiqueta: 'Abrir Comunidad: alertas, reportes, jornadas, colegios y noticias',
          onTap: () => abrirComunidad(context),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Cra.azul, Cra.superficie], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(Zr.l),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('COMUNIDAD', style: tt.seccion.copyWith(color: Cra.dorado)),
                  const SizedBox(height: 4),
                  Text('Lo que pasa en el manglar, en vivo',
                      style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Alertas, reportes de la comunidad, jornadas, colegios guardianes y noticias.',
                      style: tt.bodySmall?.copyWith(color: Cra.textoSuave)),
                ]),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_ios_rounded, color: Cra.dorado, size: 18),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text('DESDE LA CRA', style: tt.seccion.copyWith(color: Cra.azul)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AnimatedSwitcher(
          duration: Zm.corto,
          child: _noticias == null
              ? const Esqueleto.cabecera(key: ValueKey('esq'))
              : noticia == null
                  ? Text('Sin noticias guardadas todavía. Con señal aparecen las de la CRA',
                      key: const ValueKey('vacio'), style: tt.bodyMedium?.copyWith(color: Zc.textoSuave))
                  : TarjetaNoticia(key: ValueKey(noticia.id), noticia: noticia, destacada: true),
        ),
      ),
    ]);
  }
}

/// La alerta oficial más alta en Inicio: franja del color del nivel, título, lugar, recomendación y
/// fuente con hora. Al tocar abre la hoja de detalle.
class TarjetaAlertaInicio extends StatelessWidget {
  const TarjetaAlertaInicio({super.key, required this.grupos, required this.alTocar, this.generado, this.simulacro = false});
  final List<(AlertaManglar, int)> grupos;
  final VoidCallback alTocar;
  final DateTime? generado;
  final bool simulacro;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final calma = grupos.isEmpty;
    final a = calma ? null : grupos.first.$1;
    final color = a == null ? Zc.hoja : colorNivel(a.nivel);
    final pie = [
      if (a != null) sinPuntosCra(a.fuentesTexto) else 'IDEAM + DIMAR + CRA + Comunidad',
      if (generado != null) 'actualizado ${haceCuanto(generado!)}',
    ].join(' · ');
    return Presionable(
      escala: 0.98,
      etiqueta: calma
          ? 'Sin alertas en el manglar ahora. Abrir Comunidad'
          : '${a!.nivel.texto} en ${sinPuntosCra(a.lugar)}: ${sinPuntosCra(a.titulo)}. ${sinPuntosCra(a.recomendacion)}. Ver detalle',
      onTap: alTocar,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Zc.superficie,
          borderRadius: BorderRadius.circular(Zr.l),
          border: Border.all(color: color.withValues(alpha: 0.45)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 6, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(simulacro ? 'SIMULACRO · NO ES REAL' : 'ALERTAS DEL MANGLAR',
                          style: tt.seccion.copyWith(color: simulacro ? Cra.riesgoMuyAlto : Cra.azul)),
                    ),
                    const SizedBox(width: 8),
                    if (a != null) EtiquetaNivel(a.nivel),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    calma ? '✅ Sin alertas en el manglar ahora' : '${a!.icono} ${sinPuntosCra(a.titulo)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800),
                  ),
                  if (a != null && sinPuntosCra(a.lugar).isNotEmpty)
                    Text(
                      grupos.length > 1
                          ? '${sinPuntosCra(a.lugar)} · y ${grupos.length - 1} ${grupos.length == 2 ? 'lugar' : 'lugares'} más'
                          : sinPuntosCra(a.lugar),
                      style: tt.labelMedium?.copyWith(color: Zc.textoSuave),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    calma
                        ? 'No hay mar de leva, aguaceros, vientos fuertes ni riesgo de incendio a la vista.'
                        : 'Qué hacer: ${sinPuntosCra(a!.recomendacion)}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(color: Zc.texto, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.verified_rounded, size: 14, color: Zc.textoTenue),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(pie,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelSmall?.copyWith(color: Zc.textoSuave)),
                    ),
                    Text(calma ? 'Comunidad' : 'Ver detalle', style: tt.labelMedium?.copyWith(color: Zc.hoja)),
                    const Icon(Icons.chevron_right_rounded, color: Zc.hoja, size: 18),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Muestra [child] (la tarjeta del tiempo con Open-Meteo) solo si `/alertas` no trae las cifras de
/// «Ahora» (sin red ni copia): así el tiempo sale UNA sola vez en Inicio.
class SoloSinCifrasDelServidor extends StatefulWidget {
  const SoloSinCifrasDelServidor({super.key, required this.child, this.fuente});
  final Widget child;
  final FuenteComunidad? fuente;
  @override
  State<SoloSinCifrasDelServidor> createState() => _SoloSinCifrasDelServidorState();
}

class _SoloSinCifrasDelServidorState extends State<SoloSinCifrasDelServidor> {
  bool? _hayCifras;

  @override
  void initState() {
    super.initState();
    (widget.fuente ?? FuenteComunidad.compartida).alertas().then((l) {
      if (mounted) setState(() => _hayCifras = l.origen != OrigenDato.nada && l.datos.ahora.isNotEmpty);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: Zm.corto,
        child: _hayCifras == false ? widget.child : const SizedBox(width: double.infinity),
      );
}
