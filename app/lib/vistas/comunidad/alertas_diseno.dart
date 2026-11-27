/// Sistema visual de las alertas del manglar: niveles, íconos por amenaza, sellos de fuente, pila de
/// tarjetas con gestos y detalle con mapa pequeño.
///
/// - Niveles: amarilla (atento), naranja (prepárate) y roja (actúa ya), cada uno con color, ícono,
///   tinta legible y háptica propia. Solo la roja late (y no late con «reducir movimiento»).
///   El simulacro se ve distinto: franja violeta «SIMULACRO · NO ES REAL».
/// - Tarjeta corta: nivel + lugar en una línea, qué pasa en el título, «qué hacer» en un renglón
///   con verbo, hora relativa y sello de la fuente. Sin emojis como ícono.
/// - Pila: la más grave arriba, contador «1 de 3», «Siguiente» pasa la de arriba al fondo.
///   Tocar abre el detalle (el ícono viaja con Hero); mantener presionado da la vista previa con
///   acciones (ver en el mapa, compartir, «avísame si sube», ocultar); deslizar la descarta con
///   Deshacer.
/// - Lo publicado es lo mismo que la portada web: sin las amenazas ciudadanas (hoy salen de los
///   reportes de la demostración) y solo las 6 más recientes. Inicio y Comunidad usan la misma
///   función, así las cifras coinciden.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../datos/comunidad/comunidad.dart';
import '../../datos/comunidad/feed.dart' show puntoPedidoMapa;
import '../../nucleo/identidad.dart';
import '../../nucleo/kit/accion_gesto.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/menu_mantenido.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../raiz.dart';
import 'piezas_comunidad.dart' show textoCompartirAlerta;

// ------------------------------------------------------------------ niveles

/// Cómo se ve y se siente cada nivel.
class EstiloNivel {
  const EstiloNivel({
    required this.color,
    required this.tinta,
    required this.fondo,
    required this.icono,
    required this.consigna,
    required this.vibracion,
  });

  /// Color del nivel (franja, anillo, ícono).
  final Color color;

  /// El mismo tono, oscuro, para texto sobre fondo claro (contraste AA).
  final Color tinta;
  final Color fondo;
  final IconData icono;

  /// Una palabra que dice qué hacer con el nivel: «Atento», «Prepárate», «Actúa ya».
  final String consigna;
  final Vibracion vibracion;

  static const amarilla = EstiloNivel(
    color: Cra.dorado,
    tinta: Color(0xFF6B4A00),
    fondo: Color(0xFFFFF5D9),
    icono: Icons.visibility_rounded,
    consigna: 'Atento',
    vibracion: Vibracion.ligera,
  );
  static const naranja = EstiloNivel(
    color: Cra.recuperacion,
    tinta: Color(0xFF8A3B00),
    fondo: Color(0xFFFFEBDA),
    icono: Icons.warning_rounded,
    consigna: 'Prepárate',
    vibracion: Vibracion.media,
  );
  static const roja = EstiloNivel(
    color: Cra.riesgoMuyAlto,
    tinta: Color(0xFF9E1B1B),
    fondo: Color(0xFFFDE4E4),
    icono: Icons.report_rounded,
    consigna: 'Actúa ya',
    vibracion: Vibracion.fuerte,
  );

  static EstiloNivel de(NivelAlerta n) => switch (n) {
        NivelAlerta.amarilla => amarilla,
        NivelAlerta.naranja => naranja,
        NivelAlerta.roja => roja,
      };
}

/// El simulacro: violeta, con matraz; nunca se confunde con una alerta real.
const colorSimulacro = Color(0xFF5B4FC4);
const fondoSimulacro = Color(0xFFEEEBFF);

/// Un ícono propio por tipo de amenaza (los mismos tipos que publica `/alertas`).
IconData iconoAmenaza(String tipo) => switch (tipo) {
      'mar_de_leva' => Icons.waves_rounded,
      'inundacion_costera' => Icons.flood_rounded,
      'lluvia_fuerte' => Icons.thunderstorm_rounded,
      'vendaval' => Icons.air_rounded,
      'riesgo_incendio' => Icons.local_fire_department_rounded,
      'foco_calor' => Icons.satellite_alt_rounded,
      'amenaza_ciudadana' => Icons.campaign_rounded,
      'sensor' => Icons.sensors_rounded,
      _ => Icons.warning_amber_rounded,
    };

/// «C.R.A.» se escribe «CRA» en toda la app.
String limpiarCra(String t) => t.replaceAll('C.R.A.', 'CRA').replaceAll('C.R.A', 'CRA');

/// El «qué hacer» en un renglón: la primera frase, que empieza con verbo, cortada en limpio.
String queHacerCorto(String recomendacion, {int maximo = 72}) {
  var t = limpiarCra(recomendacion).trim();
  final fin = RegExp(r'[.;!](?=\s+[A-ZÁÉÍÓÚÑ¿¡])').firstMatch(t);
  if (fin != null) t = t.substring(0, fin.start);
  t = t.replaceFirst(RegExp(r'[.;!\s]+$'), '');
  if (t.length <= maximo) return t;
  final corte = t.lastIndexOf(' ', maximo - 1);
  return '${t.substring(0, corte > 20 ? corte : maximo - 1).replaceFirst(RegExp(r'[,;:\s]+$'), '')}…';
}

/// Sello de la fuente: quién respalda la alerta.
({String texto, IconData icono}) selloFuente(List<String> fuentes) {
  final nombres = [for (final f in fuentes) nombreFuente[f] ?? f];
  final texto = nombres.isEmpty ? 'Zanky' : nombres.join(' + ');
  final icono = fuentes.contains('sensores')
      ? Icons.sensors_rounded
      : fuentes.length == 1 && fuentes.first == 'comunidad'
          ? Icons.groups_rounded
          : Icons.verified_rounded;
  return (texto: limpiarCra(texto), icono: icono);
}

/// «hace 2 h» si ya empezó; «desde mañana, 11:00 a. m.» si es un pronóstico que viene.
String horaRelativa(AlertaManglar a, [DateTime? ahora]) {
  final n = ahora ?? DateTime.now();
  return a.desde.isAfter(n) ? 'desde ${cuandoTexto(a.desde, n)}' : haceCuanto(a.desde, n);
}

// ------------------------------------------------------------------ qué se publica

/// Una alerta por lugar (la más alta) con las demás del mismo lugar, que la forman.
class GrupoAlerta {
  const GrupoAlerta(this.principal, this.resto);
  final AlertaManglar principal;
  final List<AlertaManglar> resto;
  List<AlertaManglar> get todas => [principal, ...resto];
}

const maxAlertasPublicadas = ResultadoAlertas.maxPublicadas;

/// Lo mismo que publica la portada web (`publicadas()` de AlertasManglar.tsx): sin las amenazas
/// ciudadanas y solo las 6 más recientes. Una sola regla: la de [ResultadoAlertas.publicadas].
List<AlertaManglar> alertasPublicadas(List<AlertaManglar> alertas, {bool simulacro = false}) =>
    ResultadoAlertas(generado: null, alertas: alertas, ahora: const [], fuentes: const [], nota: '', simulacro: simulacro)
        .publicadas
        .take(maxAlertasPublicadas)
        .toList();

/// Agrupa por lugar y ordena: la más grave arriba; a igual nivel, la más reciente.
List<GrupoAlerta> agruparAlertas(List<AlertaManglar> alertas) {
  final grupos = <String, List<AlertaManglar>>{};
  for (final a in alertas) {
    grupos.putIfAbsent(a.lugar.isEmpty ? a.id : a.lugar, () => []).add(a);
  }
  int orden(AlertaManglar x, AlertaManglar y) {
    final n = y.nivel.index.compareTo(x.nivel.index);
    return n != 0 ? n : y.desde.compareTo(x.desde);
  }

  return [
    for (final g in grupos.values) (g..sort(orden)).let((l) => GrupoAlerta(l.first, l.skip(1).toList())),
  ]..sort((x, y) => orden(x.principal, y.principal));
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

/// Los grupos que se muestran en Inicio, en Comunidad y en el mapa (la misma cuenta en los tres).
List<GrupoAlerta> gruposPublicados(ResultadoAlertas r) =>
    agruparAlertas(r.publicadas.take(maxAlertasPublicadas).toList());

// ------------------------------------------------------------------ ocultas y seguidas

/// Alertas que la persona ocultó (por id; se guardan en el teléfono).
class AlertasOcultas extends ValueNotifier<Set<String>> {
  AlertasOcultas._() : super(const {}) {
    unawaited(_leer());
  }
  static final compartidas = AlertasOcultas._();
  static const _clave = 'alertas.ocultas';

  Future<void> _leer() async {
    try {
      final p = await SharedPreferences.getInstance();
      final l = p.getStringList(_clave);
      if (l != null && l.isNotEmpty) value = {...value, ...l};
    } catch (_) {}
  }

  Future<void> _guardar() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_clave, value.toList());
    } catch (_) {}
  }

  void ocultar(String id) {
    value = {...value, id};
    unawaited(_guardar());
  }

  void mostrar(String id) {
    value = {...value}..remove(id);
    unawaited(_guardar());
  }

  void mostrarTodas() {
    value = const {};
    unawaited(_guardar());
  }

  /// Para pruebas.
  @visibleForTesting
  void reiniciar() => value = const {};
}

/// «Avísame si sube»: guarda el nivel de hoy por lugar; al volver a leer, si subió, avisa una vez.
abstract final class AlertasSeguidas {
  static const _clave = 'alertas.seguidas';

  static Future<void> seguir(AlertaManglar a) async {
    try {
      final p = await SharedPreferences.getInstance();
      final l = {...?p.getStringList(_clave)}..removeWhere((e) => e.startsWith('${a.lugar}|'));
      await p.setStringList(_clave, [...l, '${a.lugar}|${a.nivel.index}']);
    } catch (_) {}
  }

  /// Los lugares seguidos que subieron de nivel (y los deja anotados con el nivel nuevo).
  static Future<List<AlertaManglar>> quesubieron(List<GrupoAlerta> grupos) async {
    try {
      final p = await SharedPreferences.getInstance();
      final l = p.getStringList(_clave) ?? const [];
      if (l.isEmpty) return const [];
      final antes = {for (final e in l) e.split('|').first: int.tryParse(e.split('|').last) ?? 0};
      final subieron = [
        for (final g in grupos)
          if ((antes[g.principal.lugar] ?? 99) < g.principal.nivel.index) g.principal,
      ];
      if (subieron.isNotEmpty) {
        await p.setStringList(_clave, [
          for (final e in antes.entries)
            '${e.key}|${subieron.where((s) => s.lugar == e.key).map((s) => s.nivel.index).firstOrNull ?? e.value}',
        ]);
      }
      return subieron;
    } catch (_) {
      return const [];
    }
  }
}

// ------------------------------------------------------------------ piezas

/// Insignia del ícono de la amenaza sobre el color del nivel. La roja late suave (anillo que se
/// abre y se apaga); con «reducir movimiento», quieta.
class InsigniaAlerta extends StatefulWidget {
  const InsigniaAlerta({super.key, required this.tipo, required this.nivel, this.tamano = 48, this.simulacro = false});
  final String tipo;
  final NivelAlerta nivel;
  final double tamano;
  final bool simulacro;

  @override
  State<InsigniaAlerta> createState() => _InsigniaAlertaState();
}

class _InsigniaAlertaState extends State<InsigniaAlerta> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  bool get _late => widget.nivel == NivelAlerta.roja && !widget.simulacro;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ajustar();
  }

  @override
  void didUpdateWidget(InsigniaAlerta old) {
    super.didUpdateWidget(old);
    _ajustar();
  }

  void _ajustar() {
    final quieta = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_late && !quieta) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = EstiloNivel.de(widget.nivel);
    final color = widget.simulacro ? colorSimulacro : e.color;
    final t = widget.tamano;
    final nucleo = Container(
      width: t,
      height: t,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(t * 0.32)),
      child: Icon(iconoAmenaza(widget.tipo), color: Colors.white, size: t * 0.54),
    );
    return SizedBox(
      width: t,
      height: t,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        if (_late)
          AnimatedBuilder(
            animation: _c,
            builder: (_, _) => _c.value == 0
                ? const SizedBox.shrink()
                : Transform.scale(
                    scale: 1 + 0.45 * Curves.easeOut.transform(_c.value),
                    child: Opacity(
                      opacity: (1 - _c.value) * 0.55,
                      child: Container(
                        width: t,
                        height: t,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(t * 0.32),
                          border: Border.all(color: color, width: 3),
                        ),
                      ),
                    ),
                  ),
          ),
        nucleo,
      ]),
    );
  }
}

/// Píldora del nivel: ícono del nivel + «Alerta naranja».
class PildoraNivel extends StatelessWidget {
  const PildoraNivel({super.key, required this.nivel, this.simulacro = false});
  final NivelAlerta nivel;
  final bool simulacro;
  @override
  Widget build(BuildContext context) {
    final e = EstiloNivel.de(nivel);
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
      decoration: BoxDecoration(color: simulacro ? fondoSimulacro : e.fondo, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(e.icono, size: 14, color: simulacro ? colorSimulacro : e.tinta),
        const SizedBox(width: 4),
        Text(nivel.texto,
            style: tt.labelMedium?.copyWith(color: simulacro ? colorSimulacro : e.tinta, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// Sello pequeño de la fuente («IDEAM + DIMAR», «Comunidad», «Sensores»).
class SelloFuente extends StatelessWidget {
  const SelloFuente({super.key, required this.fuentes, this.texto, this.icono});
  final List<String> fuentes;
  final String? texto;
  final IconData? icono;
  @override
  Widget build(BuildContext context) {
    final s = selloFuente(fuentes);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icono ?? s.icono, size: 14, color: Cra.azul),
      const SizedBox(width: 4),
      Flexible(
        child: Text(texto ?? s.texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Cra.azul, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

/// Franja del simulacro, arriba de la tarjeta.
class FranjaSimulacro extends StatelessWidget {
  const FranjaSimulacro({super.key});
  @override
  Widget build(BuildContext context) => Container(
        key: const Key('franja-simulacro'),
        color: colorSimulacro,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: Row(children: [
          const Icon(Icons.science_rounded, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text('SIMULACRO · NO ES REAL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          ),
        ]),
      );
}

/// Tarjeta de una alerta. Corta: nivel + lugar, qué pasa, qué hacer en un renglón, hora y fuente.
/// [expandida] agrega el detalle completo y la recomendación entera (vista previa y hoja).
class TarjetaAlertaZ extends StatelessWidget {
  const TarjetaAlertaZ({
    super.key,
    required this.alerta,
    this.extra = 0,
    this.simulacro = false,
    this.expandida = false,
    this.sombra = true,
  });
  final AlertaManglar alerta;
  final int extra;
  final bool simulacro, expandida, sombra;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final a = alerta;
    final e = EstiloNivel.de(a.nivel);
    final color = simulacro ? colorSimulacro : e.color;
    final tinta = simulacro ? colorSimulacro : e.tinta;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Zc.superficie,
        borderRadius: BorderRadius.circular(Zr.l),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        boxShadow: sombra ? [BoxShadow(color: color.withValues(alpha: 0.14), blurRadius: 20, offset: const Offset(0, 8))] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (simulacro) const FranjaSimulacro(),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Hero(
                tag: 'alerta-insignia-${a.id}',
                child: InsigniaAlerta(tipo: a.tipo, nivel: a.nivel, simulacro: simulacro),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Nivel + lugar en una línea.
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: a.nivel.texto, style: TextStyle(color: tinta, fontWeight: FontWeight.w900)),
                      TextSpan(text: ' · ${e.consigna}', style: TextStyle(color: tinta)),
                      if (a.lugar.isNotEmpty) TextSpan(text: ' · ${a.lugar}', style: const TextStyle(color: Zc.textoSuave)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelMedium,
                  ),
                  const SizedBox(height: 3),
                  // Qué pasa.
                  Text(limpiarCra(a.titulo),
                      maxLines: expandida ? 4 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800, height: 1.2)),
                ]),
              ),
            ]),
            if (expandida && a.detalle.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(limpiarCra(a.detalle), style: tt.bodyMedium?.copyWith(color: Zc.textoSuave, height: 1.4)),
            ],
            const SizedBox(height: 12),
            // Qué hacer: un renglón con verbo.
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
              decoration: BoxDecoration(color: simulacro ? fondoSimulacro : e.fondo, borderRadius: BorderRadius.circular(Zr.s)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.directions_walk_rounded, size: 18, color: tinta),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'Qué hacer: ', style: TextStyle(color: tinta, fontWeight: FontWeight.w900)),
                      TextSpan(text: expandida ? limpiarCra(a.recomendacion) : queHacerCorto(a.recomendacion)),
                    ]),
                    maxLines: expandida ? 8 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(color: Zc.texto, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: SelloFuente(fuentes: a.fuentes)),
              const SizedBox(width: 8),
              const Icon(Icons.schedule_rounded, size: 14, color: Zc.textoTenue),
              const SizedBox(width: 3),
              Text(horaRelativa(a), style: tt.labelSmall?.copyWith(color: Zc.textoSuave)),
            ]),
            if (extra > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('y $extra ${extra == 1 ? 'aviso más' : 'avisos más'} en este lugar',
                    style: tt.labelSmall?.copyWith(color: Zc.textoSuave)),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ gestos

/// Las acciones de una alerta: las mismas en el menú al mantener presionado y para el lector.
List<AccionGesto> accionesAlerta(BuildContext context, GrupoAlerta g, {DateTime? generado, bool simulacro = false}) {
  final a = g.principal;
  return [
    AccionGesto(
      etiqueta: 'Ver detalle',
      icono: Icons.open_in_full_rounded,
      alEjecutar: () => abrirDetalleAlerta(context, g, generado: generado, simulacro: simulacro),
    ),
    if (a.punto != null)
      AccionGesto(etiqueta: 'Ver en el mapa', icono: Icons.map_rounded, alEjecutar: () => verEnElMapa(context, a.punto)),
    AccionGesto(
      etiqueta: 'Compartir',
      icono: Icons.ios_share_rounded,
      alEjecutar: () => SharePlus.instance.share(ShareParams(text: limpiarCra(textoCompartirAlerta(a)))),
    ),
    if (a.nivel != NivelAlerta.roja && !simulacro)
      AccionGesto(
        etiqueta: 'Avísame si sube',
        icono: Icons.notifications_active_rounded,
        alEjecutar: () async {
          await AlertasSeguidas.seguir(a);
          if (context.mounted) {
            avisar(context, 'Listo: si ${a.lugar.isEmpty ? 'esta alerta' : a.lugar} sube de nivel, te lo decimos aquí',
                tipo: TipoAviso.exito);
          }
        },
      ),
    AccionGesto(
      etiqueta: 'Ocultar',
      icono: Icons.visibility_off_rounded,
      destructiva: true,
      alEjecutar: () => ocultarConDeshacer(context, a),
    ),
  ];
}

/// Oculta la alerta y ofrece «Deshacer» en la píldora del kit.
void ocultarConDeshacer(BuildContext context, AlertaManglar a, {AlertasOcultas? ocultas}) {
  final o = ocultas ?? AlertasOcultas.compartidas;
  o.ocultar(a.id);
  vibrar(Vibracion.ligera);
  avisar(context, 'Ocultaste la alerta de ${a.lugar.isEmpty ? 'este lugar' : a.lugar}',
      accion: AccionAviso('Deshacer', () => o.mostrar(a.id)));
}

/// Lleva a la pestaña del mapa (índice 1 en [Raiz]) y la centra en la alerta: el mapa escucha
/// [puntoPedidoMapa] y vuela al punto.
void verEnElMapa(BuildContext context, [LatLng? punto]) {
  if (punto != null) puntoPedidoMapa.value = punto;
  Navigator.of(context).popUntil((r) => r.isFirst);
  Raiz.irA(context, 1);
}

/// Una alerta con todos sus gestos: tocar abre el detalle, mantener presionado da la vista
/// previa con acciones y deslizar la oculta con Deshacer.
class AlertaConGestos extends StatelessWidget {
  const AlertaConGestos({
    super.key,
    required this.grupo,
    this.generado,
    this.simulacro = false,
    this.ocultas,
  });
  final GrupoAlerta grupo;
  final DateTime? generado;
  final bool simulacro;
  final AlertasOcultas? ocultas;

  @override
  Widget build(BuildContext context) {
    final a = grupo.principal;
    final e = EstiloNivel.de(a.nivel);
    return Dismissible(
      key: ValueKey('alerta-${a.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => ocultarConDeshacer(context, a, ocultas: ocultas),
      background: const _FondoOcultar(alineacion: Alignment.centerLeft),
      secondaryBackground: const _FondoOcultar(alineacion: Alignment.centerRight),
      child: MenuMantenido(
        etiqueta: '${a.nivel.texto}, ${e.consigna}, en ${a.lugar}: ${limpiarCra(a.titulo)}. '
            'Qué hacer: ${queHacerCorto(a.recomendacion)}. Fuente: ${selloFuente(a.fuentes).texto}. '
            'Toca para ver el detalle; desliza para ocultarla.',
        radio: BorderRadius.circular(Zr.l),
        escala: 0.98,
        alTocar: () {
          vibrar(e.vibracion);
          abrirDetalleAlerta(context, grupo, generado: generado, simulacro: simulacro);
        },
        vistaPrevia: (_) => TarjetaAlertaZ(alerta: a, simulacro: simulacro, expandida: true, sombra: false),
        acciones: accionesAlerta(context, grupo, generado: generado, simulacro: simulacro),
        child: TarjetaAlertaZ(alerta: a, extra: grupo.resto.length, simulacro: simulacro),
      ),
    );
  }
}

class _FondoOcultar extends StatelessWidget {
  const _FondoOcultar({required this.alineacion});
  final Alignment alineacion;
  @override
  Widget build(BuildContext context) => Container(
        alignment: alineacion,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(color: Zc.linea, borderRadius: BorderRadius.circular(Zr.l)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.visibility_off_rounded, color: Zc.textoSuave),
          Text('Ocultar', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Zc.textoSuave)),
        ]),
      );
}

// ------------------------------------------------------------------ pila (Inicio)

/// Las alertas en una pila de tarjetas: la más grave arriba, las demás asoman detrás, contador
/// «1 de 3» y «Siguiente» para pasar la de arriba al fondo. Sin alertas: tarjeta de calma.
class PilaAlertas extends StatefulWidget {
  const PilaAlertas({
    super.key,
    required this.grupos,
    this.generado,
    this.simulacro = false,
    this.alVerTodas,
    this.ocultas,
  });
  final List<GrupoAlerta> grupos;
  final DateTime? generado;
  final bool simulacro;
  final VoidCallback? alVerTodas;
  final AlertasOcultas? ocultas;

  @override
  State<PilaAlertas> createState() => _PilaAlertasState();
}

class _PilaAlertasState extends State<PilaAlertas> {
  late final AlertasOcultas _ocultas = widget.ocultas ?? AlertasOcultas.compartidas;
  int _frente = 0;

  @override
  void initState() {
    super.initState();
    _ocultas.addListener(_cambio);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revisarSeguidas());
  }

  Future<void> _revisarSeguidas() async {
    if (widget.simulacro) return;
    final subieron = await AlertasSeguidas.quesubieron(widget.grupos);
    if (!mounted || subieron.isEmpty) return;
    final a = subieron.first;
    vibrar(EstiloNivel.de(a.nivel).vibracion);
    avisar(context, 'Subió a ${a.nivel.texto.toLowerCase()} en ${a.lugar}', tipo: TipoAviso.aviso);
  }

  void _cambio() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ocultas.removeListener(_cambio);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final visibles = [for (final g in widget.grupos) if (!_ocultas.value.contains(g.principal.id)) g];
    final ocultasAqui = widget.grupos.length - visibles.length;
    final sinMov = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_frente >= visibles.length) _frente = 0;
    final orden = [for (var i = 0; i < visibles.length; i++) visibles[(_frente + i) % visibles.length]];

    final cabecera = Row(children: [
      Expanded(
        child: Text(widget.simulacro ? 'SIMULACRO · NO ES REAL' : 'ALERTAS DEL MANGLAR',
            style: tt.seccion.copyWith(color: widget.simulacro ? colorSimulacro : Cra.azul)),
      ),
      if (visibles.length > 1) ...[
        Semantics(
          label: 'Alerta ${_frente + 1} de ${visibles.length}',
          excludeSemantics: true,
          child: Container(
            key: const Key('contador-alertas'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Cra.azul, borderRadius: BorderRadius.circular(99)),
            child: Text('${_frente + 1} de ${visibles.length}',
                style: tt.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 4),
        Presionable(
          etiqueta: 'Siguiente alerta',
          vibracion: Vibracion.seleccion,
          onTap: () => setState(() => _frente = (_frente + 1) % visibles.length),
          child: const SizedBox(
            width: 44,
            height: 36,
            child: Icon(Icons.keyboard_arrow_right_rounded, color: Cra.azul),
          ),
        ),
      ],
    ]);

    final Widget cuerpo;
    if (visibles.isEmpty) {
      cuerpo = _Calma(
        key: const ValueKey('calma'),
        ocultas: ocultasAqui,
        alMostrar: ocultasAqui == 0
            ? null
            : () {
                for (final g in widget.grupos) {
                  _ocultas.mostrar(g.principal.id);
                }
              },
        alTocar: widget.alVerTodas,
      );
    } else {
      final atras = orden.length - 1 > 2 ? 2 : orden.length - 1;
      cuerpo = Padding(
        key: ValueKey('pila-${orden.first.principal.id}'),
        padding: EdgeInsets.only(bottom: 8.0 * atras),
        child: Stack(clipBehavior: Clip.none, children: [
          // Las de detrás asoman abajo, más chicas, con el color de su nivel.
          for (var i = atras; i >= 1; i--)
            Positioned(
              left: 10.0 * i,
              right: 10.0 * i,
              bottom: -8.0 * i,
              top: 8.0 * i,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.lerp(Zc.superficie,
                        widget.simulacro ? colorSimulacro : EstiloNivel.de(orden[i].principal.nivel).color, 0.18 - 0.05 * i),
                    borderRadius: BorderRadius.circular(Zr.l),
                    border: Border.all(color: Zc.linea),
                  ),
                ),
              ),
            ),
          AlertaConGestos(
            key: ValueKey('frente-${orden.first.principal.id}'),
            grupo: orden.first,
            generado: widget.generado,
            simulacro: widget.simulacro,
            ocultas: _ocultas,
          ),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.only(bottom: 6), child: cabecera),
      AnimatedSwitcher(
        duration: sinMov ? Duration.zero : Zm.medio,
        switchInCurve: Zm.entrar,
        switchOutCurve: Zm.salir,
        transitionBuilder: (hijo, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
            child: hijo,
          ),
        ),
        child: cuerpo,
      ),
    ]);
  }
}

class _Calma extends StatelessWidget {
  const _Calma({super.key, required this.ocultas, this.alMostrar, this.alTocar});
  final int ocultas;
  final VoidCallback? alMostrar, alTocar;
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Presionable(
      escala: 0.98,
      etiqueta: ocultas > 0 ? 'Ocultaste $ocultas alertas' : 'Sin alertas en el manglar ahora',
      onTap: alTocar,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Zc.hojaClara,
          borderRadius: BorderRadius.circular(Zr.l),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Zc.hoja, borderRadius: BorderRadius.circular(15)),
            child: Icon(ocultas > 0 ? Icons.visibility_off_rounded : Icons.check_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ocultas > 0 ? 'Ocultaste ${ocultas == 1 ? 'la alerta' : 'las $ocultas alertas'}' : 'Sin alertas en el manglar ahora',
                  style: tt.titleSmall?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                ocultas > 0
                    ? 'Siguen activas en Comunidad.'
                    : 'Sin mar de leva, aguaceros, vientos fuertes ni riesgo de incendio a la vista.',
                style: tt.bodySmall?.copyWith(color: Zc.textoSuave),
              ),
            ]),
          ),
          if (alMostrar != null)
            TextButton(onPressed: alMostrar, child: const Text('Mostrar')),
        ]),
      ),
    );
  }
}

/// La lista de Comunidad: todas las publicadas, con los mismos gestos.
class ListaAlertas extends StatefulWidget {
  const ListaAlertas({super.key, required this.grupos, this.generado, this.simulacro = false, this.ocultas});
  final List<GrupoAlerta> grupos;
  final DateTime? generado;
  final bool simulacro;
  final AlertasOcultas? ocultas;

  @override
  State<ListaAlertas> createState() => _ListaAlertasState();
}

class _ListaAlertasState extends State<ListaAlertas> {
  late final AlertasOcultas _o = widget.ocultas ?? AlertasOcultas.compartidas;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Set<String>>(
        valueListenable: _o,
        builder: (context, ocultas, _) {
          final visibles = [for (final g in widget.grupos) if (!ocultas.contains(g.principal.id)) g];
          final n = widget.grupos.length - visibles.length;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final g in visibles)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: AlertaConGestos(grupo: g, generado: widget.generado, simulacro: widget.simulacro, ocultas: _o),
              ),
            if (n > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      for (final g in widget.grupos) {
                        _o.mostrar(g.principal.id);
                      }
                    },
                    icon: const Icon(Icons.visibility_rounded, size: 18),
                    label: Text(n == 1 ? 'Mostrar la alerta oculta' : 'Mostrar las $n alertas ocultas'),
                  ),
                ),
              ),
          ]);
        },
      );
}

// ------------------------------------------------------------------ detalle

/// Abre el detalle: el ícono viaja desde la tarjeta (Hero), mapa pequeño del lugar y lo que forma
/// la alerta (las demás del mismo lugar y las fuentes).
Future<void> abrirDetalleAlerta(BuildContext context, GrupoAlerta g, {DateTime? generado, bool simulacro = false}) {
  final sinMov = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return Navigator.of(context).push(PageRouteBuilder<void>(
    settings: const RouteSettings(name: 'alerta'),
    transitionDuration: sinMov ? Duration.zero : Zm.medio,
    reverseTransitionDuration: sinMov ? Duration.zero : Zm.corto,
    pageBuilder: (_, _, _) => DetalleAlerta(grupo: g, generado: generado, simulacro: simulacro),
    transitionsBuilder: (_, anim, _, hijo) {
      final c = CurvedAnimation(parent: anim, curve: Zm.entrar, reverseCurve: Zm.salir);
      return FadeTransition(
        opacity: c,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(c), child: hijo),
      );
    },
  ));
}

class DetalleAlerta extends StatelessWidget {
  const DetalleAlerta({super.key, required this.grupo, this.generado, this.simulacro = false, this.conMapa = true});
  final GrupoAlerta grupo;
  final DateTime? generado;
  final bool simulacro;

  /// Para pruebas sin teselas.
  final bool conMapa;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final a = grupo.principal;
    final e = EstiloNivel.de(a.nivel);
    final color = simulacro ? colorSimulacro : e.color;
    final tinta = simulacro ? colorSimulacro : e.tinta;
    return Scaffold(
      backgroundColor: Zc.arena,
      appBar: AppBar(
        backgroundColor: simulacro ? fondoSimulacro : e.fondo,
        foregroundColor: tinta,
        title: Text(simulacro ? 'Simulacro' : a.nivel.texto),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: -20),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          color: simulacro ? fondoSimulacro : e.fondo,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (simulacro) ...[
              const ClipRRect(borderRadius: BorderRadius.all(Radius.circular(8)), child: FranjaSimulacro()),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Hero(
                tag: 'alerta-insignia-${a.id}',
                child: InsigniaAlerta(tipo: a.tipo, nivel: a.nivel, tamano: 64, simulacro: simulacro),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PildoraNivel(nivel: a.nivel, simulacro: simulacro),
                  const SizedBox(height: 6),
                  Text('${e.consigna} · ${a.lugar}',
                      style: tt.labelLarge?.copyWith(color: tinta, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Text(limpiarCra(a.titulo), style: tt.headlineSmall?.copyWith(color: Zc.texto, fontWeight: FontWeight.w900, height: 1.15)),
            const SizedBox(height: 8),
            Row(children: [
              Flexible(child: SelloFuente(fuentes: a.fuentes)),
              Text('  ·  ${a.medido ? 'Medido' : 'Pronóstico'} · ${horaRelativa(a)}',
                  style: tt.labelSmall?.copyWith(color: Zc.textoSuave)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        _Bloque(
          icono: Icons.directions_walk_rounded,
          titulo: 'Qué hacer',
          color: tinta,
          child: Text(limpiarCra(a.recomendacion), style: tt.bodyLarge?.copyWith(color: Zc.texto, height: 1.4)),
        ),
        if (a.detalle.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Bloque(
            icono: Icons.info_outline_rounded,
            titulo: 'Qué pasa',
            color: Cra.azul,
            child: Text(limpiarCra(a.detalle), style: tt.bodyMedium?.copyWith(color: Zc.textoSuave, height: 1.45)),
          ),
        ],
        if (a.punto != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(Zr.m),
            child: SizedBox(
              height: 170,
              child: conMapa
                  ? Stack(children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: a.punto!,
                          initialZoom: 12.5,
                          backgroundColor: Zc.cienagaClara,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'co.zanky.app'),
                          CircleLayer(circles: [
                            CircleMarker(
                              point: a.punto!,
                              radius: 1500,
                              useRadiusInMeter: true,
                              color: color.withValues(alpha: 0.18),
                              borderColor: color,
                              borderStrokeWidth: 2,
                            ),
                          ]),
                          MarkerLayer(markers: [
                            Marker(
                              point: a.punto!,
                              width: 56,
                              height: 56,
                              child: MarcadorAlertaZ(alerta: a, conteo: grupo.todas.length),
                            ),
                          ]),
                        ],
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: FilledButton.tonalIcon(
                          onPressed: () => verEnElMapa(context, a.punto),
                          icon: const Icon(Icons.map_rounded, size: 18),
                          label: const Text('Ver en el mapa'),
                        ),
                      ),
                    ])
                  : const ColoredBox(color: Zc.cienagaClara),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('LO QUE FORMA ESTA ALERTA', style: tt.seccion.copyWith(color: Cra.azul)),
        const SizedBox(height: 8),
        for (final x in grupo.todas)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FilaSenal(alerta: x, simulacro: simulacro),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Cra.azul),
          onPressed: () => SharePlus.instance.share(ShareParams(text: limpiarCra(textoCompartirAlerta(a)))),
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('Avisar a mis vecinos'),
        ),
        const SizedBox(height: 14),
        Text(
          '${generado == null ? '' : 'Cruzado por Zanky ${haceCuanto(generado!)}. '}'
          'No reemplaza los avisos oficiales de la CRA ni de la Gestión del Riesgo. '
          'Si hay peligro para las personas, llama al 123.',
          textAlign: TextAlign.center,
          style: tt.labelMedium?.copyWith(color: Zc.textoSuave, height: 1.4),
        ),
      ]),
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.icono, required this.titulo, required this.color, required this.child});
  final IconData icono;
  final String titulo;
  final Color color;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Zc.superficie, borderRadius: BorderRadius.circular(Zr.m)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icono, size: 18, color: color),
            const SizedBox(width: 6),
            Text(titulo, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 6),
          child,
        ]),
      );
}

class _FilaSenal extends StatelessWidget {
  const _FilaSenal({required this.alerta, required this.simulacro});
  final AlertaManglar alerta;
  final bool simulacro;
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final a = alerta;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Zc.superficie, borderRadius: BorderRadius.circular(Zr.s)),
      child: Row(children: [
        InsigniaAlerta(tipo: a.tipo, nivel: a.nivel, tamano: 34, simulacro: simulacro),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(limpiarCra(a.titulo),
                maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.bodyMedium?.copyWith(color: Zc.texto, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Row(children: [
              Flexible(child: SelloFuente(fuentes: a.fuentes)),
              Text(' · ${a.medido ? 'Medido' : 'Pronóstico'} · ${horaRelativa(a)}',
                  style: tt.labelSmall?.copyWith(color: Zc.textoSuave)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ mapa

/// Marcador de alerta en el mapa: ícono de la amenaza sobre el color del nivel, anillo que respira
/// (lento en la naranja, más rápido en la roja, quieto en la amarilla y con «reducir movimiento»)
/// y conteo de avisos en el lugar.
class MarcadorAlertaZ extends StatefulWidget {
  const MarcadorAlertaZ({super.key, required this.alerta, this.conteo = 1});
  final AlertaManglar alerta;
  final int conteo;
  @override
  State<MarcadorAlertaZ> createState() => _MarcadorAlertaZState();
}

class _MarcadorAlertaZState extends State<MarcadorAlertaZ> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  Duration? get _periodo => switch (widget.alerta.nivel) {
        NivelAlerta.amarilla => null,
        NivelAlerta.naranja => const Duration(milliseconds: 2400),
        NivelAlerta.roja => const Duration(milliseconds: 1400),
      };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = _periodo;
    final quieto = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (p != null && !quieto) {
      _c.duration = p;
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alerta;
    final c = EstiloNivel.de(a.nivel).color;
    return Center(
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, _) {
              final t = Curves.easeInOut.transform(_c.value);
              return Container(
                width: 40 + 8 * t,
                height: 40 + 8 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.withValues(alpha: 0.22 - 0.1 * t),
                ),
              );
            },
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 10)],
            ),
            child: Icon(iconoAmenaza(a.tipo), color: Colors.white, size: 18),
          ),
          if (widget.conteo > 1)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Cra.azul,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text('${widget.conteo}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, height: 1)),
              ),
            ),
        ]),
      ),
    );
  }
}
