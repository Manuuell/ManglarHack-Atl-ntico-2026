import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../../datos/comunidad/comunidad.dart';
import '../../datos/comunidad/feed.dart';
import '../../datos/comunidad/marcas_comunidad.dart';
import '../../datos/experiencia/jornada.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/celebracion.dart';
import '../../nucleo/kit/ruta_borde.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../raiz.dart';
import '../web/abrir_enlace.dart';
import 'pantalla_comunidad.dart' show abrirInscripcion;
import 'piezas_comunidad.dart';

/// Etiqueta del Hero de la foto de un evento (tarjeta → detalle).
String heroEvento(Jornada j) => 'evento-${j.id}';

/// Abre el detalle de un evento: la foto viaja desde la tarjeta (Hero), deslizar desde el borde vuelve.
Future<void> abrirDetalleEvento(BuildContext context, EventoCartelera e, {FuenteComunidad? fuente}) =>
    abrirConBorde<void>(context, (_) => DetalleEvento(e: e, fuente: fuente),
        settings: RouteSettings(name: 'evento/${e.jornada.id}'));

/// Inscripción con la hoja del formulario; si queda hecha, la marca en el teléfono.
Future<bool> inscribirEnJornada(BuildContext context, Jornada j, {FuenteComunidad? fuente}) async {
  final ok = await abrirInscripcion(context, j, fuente ?? FuenteComunidad.compartida);
  if (ok == true) jornadasInscritas.poner(j.id, true);
  return ok == true;
}

/// Lleva al mapa centrado en el punto de encuentro.
void verJornadaEnMapa(BuildContext context, Jornada j) {
  puntoPedidoMapa.value = LatLng(j.lat, j.lon);
  Navigator.of(context).popUntil((r) => r.isFirst);
  Raiz.irA(context, 1);
}

bool tieneLugar(Jornada j) => j.lat != 0 && j.lon != 0;

String _dosDigitos(int n) => n.toString().padLeft(2, '0');
String _utc(DateTime d) {
  final u = d.toUtc();
  return '${u.year}${_dosDigitos(u.month)}${_dosDigitos(u.day)}T${_dosDigitos(u.hour)}${_dosDigitos(u.minute)}00Z';
}

/// Agregar al calendario: en la web abre el de Google con todo lleno; en el teléfono comparte un .ics,
/// que Android e iOS ofrecen abrir con la app de calendario.
Future<void> agregarJornadaAlCalendario(BuildContext context, Jornada j) async {
  final fin = j.fin.isAfter(j.inicio) ? j.fin : j.inicio.add(const Duration(hours: 2));
  final detalle = '${j.descripcion}\n\nInscripción y novedades: https://mimanglar.sentralabs.co/#jornadas'.trim();
  if (kIsWeb) {
    final u = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': j.titulo,
      'dates': '${_utc(j.inicio)}/${_utc(fin)}',
      'details': detalle,
      'location': j.puntoEncuentro,
    });
    abrirEnlace(u.toString());
    return;
  }
  String esc(String s) => s.replaceAll('\\', '\\\\').replaceAll(';', '\\;').replaceAll(',', '\\,').replaceAll('\n', '\\n');
  final ics = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Zanky//Jornadas//ES',
    'BEGIN:VEVENT',
    'UID:${j.id}@zanky',
    'DTSTAMP:${_utc(DateTime.now())}',
    'DTSTART:${_utc(j.inicio)}',
    'DTEND:${_utc(fin)}',
    'SUMMARY:${esc(j.titulo)}',
    'LOCATION:${esc(j.puntoEncuentro)}',
    'DESCRIPTION:${esc(detalle)}',
    if (tieneLugar(j)) 'GEO:${j.lat};${j.lon}',
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n');
  try {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(utf8.encode(ics), mimeType: 'text/calendar', name: 'jornada.ics')],
      fileNameOverrides: const ['jornada.ics'],
      subject: j.titulo,
    ));
  } catch (_) {
    if (context.mounted) avisar(context, 'No pude abrir el calendario', tipo: TipoAviso.error);
  }
}

Future<void> compartirJornada(Jornada j) => SharePlus.instance.share(ShareParams(
    text: '${j.titulo}\n${cuandoTexto(j.inicio.toLocal())} · ${j.puntoEncuentro}\n'
        'Inscríbete en Zanky: https://mimanglar.sentralabs.co/#jornadas'));

/// Detalle de un evento: foto que viaja desde la tarjeta, cuenta regresiva, cupos, qué llevar, mapa
/// pequeño del punto de encuentro y un botón fijo de inscripción que pasa a «Inscrito ✓».
class DetalleEvento extends StatelessWidget {
  const DetalleEvento({super.key, required this.e, this.fuente});
  final EventoCartelera e;
  final FuenteComunidad? fuente;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final j = e.jornada;
    final arriba = MediaQuery.paddingOf(context).top;
    final sinMov = MediaQuery.disableAnimationsOf(context);
    Widget fila(IconData i, String titulo, String valor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: Zc.cienagaClara, borderRadius: BorderRadius.circular(Zr.s)),
              child: Icon(i, size: 18, color: Cra.azul),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: tt.labelMedium?.copyWith(color: Zc.textoSuave)),
                const SizedBox(height: 2),
                Text(valor, style: tt.bodyMedium?.copyWith(color: Zc.texto, height: 1.35)),
              ]),
            ),
          ]),
        );
    return Scaffold(
      backgroundColor: Zc.arena,
      bottomNavigationBar: _BarraInscripcion(j: j, fuente: fuente),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Stack(children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Hero(
                    tag: heroEvento(j),
                    child: FotoNoticia(url: j.imagen?.toString()),
                  ),
                ),
                // Velo arriba para que «Volver» se lea sobre cualquier foto.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: arriba + 70,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x66000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: arriba + 4,
                  child: _BotonRedondo(
                    icono: Icons.arrow_back_ios_new_rounded,
                    etiqueta: 'Volver',
                    alTocar: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: arriba + 4,
                  child: _BotonRedondo(icono: Icons.ios_share_rounded, etiqueta: 'Compartir', alTocar: () => compartirJornada(j)),
                ),
              ]),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              sliver: SliverList.list(children: [
                Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(j.tipoLegible.toUpperCase(), style: tt.seccion.copyWith(color: Zc.cienaga)),
                  if (j.esEjemplo || e.respaldo)
                    _Chip(j.esEjemplo ? 'Ejemplo' : 'Respaldo · por confirmar', color: Cra.recuperacion),
                ]),
                const SizedBox(height: 6),
                Text(j.titulo, style: tt.headlineSmall?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 14),
                RepaintBoundary(child: CuentaRegresiva(inicio: j.inicio, fin: j.fin)),
                const SizedBox(height: 14),
                _Cupos(j: j, sinMovimiento: sinMov),
                const SizedBox(height: 8),
                fila(Icons.schedule_rounded, 'Cuándo', cuandoTexto(j.inicio.toLocal())),
                fila(Icons.place_rounded, 'Punto de encuentro', j.puntoEncuentro.isEmpty ? 'Por confirmar' : j.puntoEncuentro),
                if (j.queLlevar.isNotEmpty) fila(Icons.backpack_rounded, 'Qué llevar', j.queLlevar.join(' · ')),
                if (j.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('De qué se trata', style: tt.titleSmall?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(j.descripcion, style: tt.bodyMedium?.copyWith(color: Zc.textoSuave, height: 1.5)),
                ],
                if (tieneLugar(j)) ...[
                  const SizedBox(height: 18),
                  _MapaLugar(j: j),
                ],
                const SizedBox(height: 14),
                Text('Inscribirse es gratis. Tu nombre solo lo ve quien organiza, según la Ley 1581.',
                    style: tt.labelSmall?.copyWith(color: Zc.textoSuave, height: 1.4)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.texto, {required this.color});
  final String texto;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
        child: Text(texto, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800)),
      );
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({required this.icono, required this.etiqueta, required this.alTocar});
  final IconData icono;
  final String etiqueta;
  final VoidCallback alTocar;
  @override
  Widget build(BuildContext context) => Presionable(
        etiqueta: etiqueta,
        onTap: alTocar,
        escala: 0.9,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Color(0x290B2E24), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Icon(icono, size: 19, color: Cra.azul),
        ),
      );
}

/// Texto de la cuenta regresiva (puro, para probar): «Empieza en 2 d 4 h», «en 3 h 12 min»,
/// «en 12:05», «En curso», «Terminó».
String textoCuentaRegresiva(DateTime inicio, DateTime fin, DateTime ahora) {
  final finReal = fin.isAfter(inicio) ? fin : inicio.add(const Duration(hours: 2));
  if (ahora.isAfter(finReal)) return 'Terminó';
  if (!ahora.isBefore(inicio)) return 'En curso ahora';
  final d = inicio.difference(ahora);
  if (d.inDays >= 1) return 'Empieza en ${d.inDays} d ${d.inHours % 24} h';
  if (d.inHours >= 1) return 'Empieza en ${d.inHours} h ${_dosDigitos(d.inMinutes % 60)} min';
  return 'Empieza en ${_dosDigitos(d.inMinutes)}:${_dosDigitos(d.inSeconds % 60)}';
}

/// Cuenta regresiva viva: late cada segundo en la última hora y cada 30 s antes; solo se repinta
/// ella (va dentro de un RepaintBoundary).
class CuentaRegresiva extends StatefulWidget {
  const CuentaRegresiva({super.key, required this.inicio, required this.fin, this.reloj});
  final DateTime inicio, fin;

  /// Para pruebas.
  final DateTime Function()? reloj;
  @override
  State<CuentaRegresiva> createState() => _CuentaRegresivaState();
}

class _CuentaRegresivaState extends State<CuentaRegresiva> {
  Timer? _t;
  DateTime _ahora() => (widget.reloj ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _programar();
  }

  void _programar() {
    _t?.cancel();
    final falta = widget.inicio.difference(_ahora());
    final paso = falta.inHours < 1 ? const Duration(seconds: 1) : const Duration(seconds: 30);
    _t = Timer.periodic(paso, (_) {
      if (!mounted) return;
      setState(() {});
      // Al cruzar la última hora pasa a latir cada segundo.
      if (paso.inSeconds > 1 && widget.inicio.difference(_ahora()).inHours < 1) _programar();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final texto = textoCuentaRegresiva(widget.inicio, widget.fin, _ahora());
    final vivo = texto.startsWith('En curso');
    final paso = texto == 'Terminó';
    final color = paso ? Zc.textoSuave : (vivo ? Zc.hoja : Cra.azul);
    return Semantics(
      liveRegion: false,
      label: texto,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Zr.m),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(vivo ? Icons.circle : Icons.timer_outlined, size: vivo ? 12 : 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: tt.titleMedium?.copyWith(
                    color: color, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ]),
      ),
    );
  }
}

class _Cupos extends StatelessWidget {
  const _Cupos({required this.j, required this.sinMovimiento});
  final Jornada j;
  final bool sinMovimiento;
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final ins = '${j.inscritos} ${j.inscritos == 1 ? 'persona inscrita' : 'personas inscritas'}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.groups_rounded, size: 18, color: Zc.hoja),
        const SizedBox(width: 6),
        Expanded(child: Text(ins, style: tt.titleSmall?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800))),
        Text(j.cupos <= 0 ? 'sin límite de cupos' : '${j.cuposLibres} libres de ${j.cupos}',
            style: tt.labelMedium?.copyWith(color: Zc.textoSuave)),
      ]),
      if (j.cupos > 0) ...[
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (j.inscritos / j.cupos).clamp(0.0, 1.0)),
            duration: sinMovimiento ? Duration.zero : Zm.largo,
            curve: Zm.entrar,
            builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: Zc.linea, color: Zc.hoja),
          ),
        ),
      ],
    ]);
  }
}

/// Mapa pequeño del punto de encuentro (sin gestos de un dedo: la pantalla sigue desplazándose).
/// Tocar lleva al mapa grande.
class _MapaLugar extends StatelessWidget {
  const _MapaLugar({required this.j});
  final Jornada j;
  @override
  Widget build(BuildContext context) {
    final p = LatLng(j.lat, j.lon);
    return Presionable(
      escala: 0.98,
      etiqueta: 'Ver el punto de encuentro en el mapa',
      onTap: () => verJornadaEnMapa(context, j),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Zr.m),
        child: SizedBox(
          height: 160,
          child: Stack(children: [
            IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                  backgroundColor: Zc.cienagaClara,
                  initialCenter: p,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'co.zanky.app'),
                  MarkerLayer(markers: [
                    Marker(
                      point: p,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Zc.hoja,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Color(0x330B2E24), blurRadius: 8, offset: Offset(0, 3))],
                        ),
                        child: const Icon(Icons.flag_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.map_rounded, size: 15, color: Cra.azul),
                  const SizedBox(width: 6),
                  Text('Ver en el mapa',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Cra.azul, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
            Positioned(
              right: 6,
              bottom: 4,
              child: Text('© OpenStreetMap', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Barra fija de abajo: «Inscribirme» → (hoja con el formulario: cargando → ✓) → «Estás inscrito ✓»
/// con «Al calendario». El cambio se anima con fundido y escala; con «reducir movimiento», corte.
class _BarraInscripcion extends StatefulWidget {
  const _BarraInscripcion({required this.j, this.fuente});
  final Jornada j;
  final FuenteComunidad? fuente;
  @override
  State<_BarraInscripcion> createState() => _BarraInscripcionState();
}

class _BarraInscripcionState extends State<_BarraInscripcion> {
  bool _recien = false;

  @override
  void initState() {
    super.initState();
    jornadasInscritas.cargar();
  }

  Future<void> _inscribir() async {
    final ok = await inscribirEnJornada(context, widget.j, fuente: widget.fuente);
    if (ok && mounted) setState(() => _recien = true);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final abajo = MediaQuery.paddingOf(context).bottom;
    final sinMov = MediaQuery.disableAnimationsOf(context);
    final termino = textoCuentaRegresiva(widget.j.inicio, widget.j.fin, DateTime.now()) == 'Terminó';
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + abajo),
      decoration: const BoxDecoration(
        color: Zc.superficie,
        boxShadow: [BoxShadow(color: Color(0x1A0B2E24), blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: jornadasInscritas,
            builder: (context, inscritas, _) {
              final ya = inscritas.contains(widget.j.id);
              return AnimatedSwitcher(
                duration: sinMov ? Duration.zero : Zm.medio,
                switchInCurve: Zm.entrar,
                transitionBuilder: (hijo, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: hijo),
                ),
                child: ya
                    ? Row(key: const ValueKey('ya'), children: [
                        CheckDibujado(tamano: 36, animar: _recien && !sinMov, etiqueta: 'Estás inscrito'),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text('Estás inscrito', style: tt.titleSmall?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800)),
                            Text('Te esperamos. Agrégalo para no olvidarlo.',
                                maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.labelSmall?.copyWith(color: Zc.textoSuave)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 150,
                          child: BotonZ(
                            texto: 'Al calendario',
                            icono: Icons.event_available_rounded,
                            secundario: true,
                            onTap: () => agregarJornadaAlCalendario(context, widget.j),
                          ),
                        ),
                      ])
                    : BotonZ(
                        key: const ValueKey('no'),
                        texto: termino ? 'Esta jornada ya terminó' : 'Inscribirme',
                        icono: Icons.how_to_reg_rounded,
                        onTap: termino ? null : _inscribir,
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}
