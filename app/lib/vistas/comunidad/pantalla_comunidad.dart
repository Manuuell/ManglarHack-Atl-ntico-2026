import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../datos/avisos/centro_avisos.dart';
import '../../datos/comunidad/comunidad.dart';
import '../../datos/crecimiento/ranking_colegios.dart';
import '../../datos/estado.dart';
import '../../datos/experiencia/jornada.dart';
import '../../datos/servidor.dart';
import '../../nucleo/base/entrada_escalonada.dart';
import '../../nucleo/base/esqueleto.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/estado_vacio.dart';
import '../../nucleo/kit/ruta_borde.dart';
import '../../nucleo/kit/tirar_actualizar.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';
import '../../datos/comunidad/feed.dart';
import 'datos_abiertos.dart';
import 'feed_y_eventos.dart';
import 'piezas_comunidad.dart';
import '../../datos/admin/contenido_publico.dart';

/// Abre «Comunidad» (desde la tarjeta de Inicio).
Future<void> abrirComunidad(BuildContext context) =>
    abrirConBorde<void>(context, (_) => const PantallaComunidad(), settings: const RouteSettings(name: 'comunidad'));

/// Colegio del ranking de la web (`web/src/data/colegios.json`), que allí se rotula «Datos de ejemplo».
class ColegioWeb {
  const ColegioWeb(this.nombre, this.municipio, this.puntos, this.validados, this.estudiantes);
  final String nombre, municipio;
  final int puntos, validados, estudiantes;
}

Future<List<ColegioWeb>> Function() cargaColegiosWeb = () async {
  final t = await rootBundle.loadString('assets/datos/colegios_web.json');
  final lista = [
    for (final c in jsonDecode(t) as List)
      ColegioWeb('${c['nombre']}', '${c['municipio']}', (c['puntos'] as num).toInt(),
          (c['reportes_validados'] as num).toInt(), (c['estudiantes'] as num).toInt()),
  ]..sort((a, b) => b.puntos.compareTo(a.puntos));
  return lista;
};

/// Lo que se ve en Comunidad, en el orden de la portada de la web: alertas, reportes de la comunidad,
/// jornadas, Guardianes del manglar, noticias y datos abiertos.
class PantallaComunidad extends StatefulWidget {
  const PantallaComunidad({super.key, this.fuente, this.jornadas});
  final FuenteComunidad? fuente;
  final FuenteJornadas? jornadas;

  @override
  State<PantallaComunidad> createState() => _PantallaComunidadState();
}

class _PantallaComunidadState extends State<PantallaComunidad> {
  late final FuenteComunidad _fuente = widget.fuente ?? FuenteComunidad.compartida;
  late final FuenteJornadas _fuenteJornadas = widget.jornadas ?? FuenteJornadas();

  Lote<ResultadoAlertas>? _alertas;
  Lote<List<ReporteComunidad>>? _reportes;
  Lote<List<NoticiaManglar>>? _noticias;
  List<Jornada>? _jornadas;
  List<ColegioEnRanking>? _ranking;
  List<ColegioWeb>? _colegiosWeb;
  bool _rankingFallo = false;
  List<ReporteFeed> _simulados = const [];
  List<Jornada> _respaldo = const [];

  @override
  void initState() {
    super.initState();
    _cargarLocal();
    cargaSimulados().then((v) => mounted ? setState(() => _simulados = v) : null);
    cargaJornadasRespaldo().then((v) => mounted ? setState(() => _respaldo = v) : null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargarLocal() async {
    try {
      final j = await _fuenteJornadas.cargarLocal();
      if (mounted && _jornadas == null) setState(() => _jornadas = j);
    } catch (_) {}
  }

  Future<void> _cargar() async {
    final servidor = Zanky.leer(context).servidor;
    await Future.wait([
      _fuente.alertas().then((v) => mounted ? setState(() => _alertas = v) : null),
      _fuente.reportes().then((v) => mounted ? setState(() => _reportes = v) : null),
      _fuente.noticias().then(ajustarLoteNoticias).then((v) => mounted ? setState(() => _noticias = v) : null),
      _fuenteJornadas.cargar().then((v) => mounted ? setState(() => _jornadas = v) : null).catchError((_) => null),
      _cargarRanking(servidor),
    ]);
  }

  Future<void> _cargarRanking(Servidor servidor) async {
    try {
      final r = await RankingColegios(servidor).cargar();
      List<ColegioWeb>? web;
      if (r.isEmpty) web = await cargaColegiosWeb();
      if (mounted) {
        setState(() {
          _ranking = r;
          _colegiosWeb = web;
          _rankingFallo = false;
        });
      }
    } catch (_) {
      final web = await cargaColegiosWeb().catchError((_) => const <ColegioWeb>[]);
      if (mounted) {
        setState(() {
          _ranking = const [];
          _colegiosWeb = web;
          _rankingFallo = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    final estado = Zanky.de(context);
    final tt = Theme.of(context).textTheme;
    var i = 0;
    Widget entra(Widget w) => EntradaEscalonada(index: i++, child: w);
    return Scaffold(
      backgroundColor: Zc.arena,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: TirarActualizar(
            alActualizar: _cargar,
            child: ListView(
              padding: EdgeInsets.fromLTRB(0, arriba + 6, 0, 120),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 20, 4),
                  child: Row(children: [
                    Presionable(
                      etiqueta: 'Volver',
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Zc.cienaga),
                      ),
                    ),
                    const Spacer(),
                    const ZankyMascota(tamano: 54, animo: Animo.feliz),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('COMUNIDAD', style: tt.seccion.copyWith(color: Cra.azul)),
                    const SizedBox(height: 2),
                    Text('Lo que pasa en el manglar, en vivo.', style: tt.headlineMedium?.copyWith(color: Zc.texto)),
                    const SizedBox(height: 6),
                    Text('Lo mismo que ves en mimanglar.sentralabs.co: alertas, reportes, jornadas, colegios y noticias.',
                        style: tt.bodyMedium?.copyWith(color: Zc.textoSuave)),
                  ]),
                ),
                entra(_SeccionAlertas(lote: _alertas)),
                const SizedBox(height: 26),
                entra(SeccionNoticias(lote: _noticias)),
                const SizedBox(height: 26),
                entra(SeccionFeed(
                  feed: _reportes == null
                      ? null
                      : unirFeed(abiertos: _reportes!.datos, supabase: estado.publicos, simulados: _simulados),
                  origen: _reportes?.origen,
                  cuando: _reportes?.cuando,
                )),
                const SizedBox(height: 26),
                entra(SeccionEventos(
                  eventos: _jornadas == null ? null : completarCartelera([..._jornadas!, ...jornadasDelPanel()], _respaldo),
                  alInscribirse: (j) async {
                    if (esJornadaDelPanel(j)) {
                      avisar(context, 'Sin inscripción en línea: llega al punto de encuentro (${j.puntoEncuentro}).');
                      return;
                    }
                    final ok = await abrirInscripcion(context, j, _fuente);
                    if (ok == true) await _cargar();
                  },
                )),
                const SizedBox(height: 26),
                entra(_SeccionGuardianes(ranking: _ranking, web: _colegiosWeb, fallo: _rankingFallo)),
                const SizedBox(height: 26),
                entra(DatosAbiertos(base: _fuente.base)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ alertas

class _SeccionAlertas extends StatelessWidget {
  const _SeccionAlertas({required this.lote});
  final Lote<ResultadoAlertas>? lote;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = lote;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const TituloSeccion(antetitulo: 'Alertas', titulo: '¿Qué viene para el manglar?', tono: 'Te avisamos.'),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Text(
          'Cada 10 minutos se cruzan las estaciones del IDEAM, el pronóstico y las mareas de DIMAR, '
          'los focos de calor de la CRA y lo que reporta la comunidad.',
          style: tt.bodyMedium?.copyWith(color: Zc.textoSuave, height: 1.4),
        ),
      ),
      if (l == null)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [Esqueleto.tarjeta(), SizedBox(height: 10), Esqueleto.tarjeta()]),
        )
      else ...[
        NotaOrigen(origen: l.origen, cuando: l.cuando),
        if (l.datos.ahora.isNotEmpty)
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: l.datos.ahora.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, k) => CifraOficial(c: l.datos.ahora[k]),
            ),
          ),
        const SizedBox(height: 12),
        if (l.origen == OrigenDato.nada)
          const EstadoVacio(
            titulo: 'No pudimos leer las alertas',
            texto: 'Tira hacia abajo para intentarlo de nuevo cuando tengas señal.',
            animo: Animo.preocupado,
            tamanoZanky: 96,
            relleno: EdgeInsets.fromLTRB(28, 0, 28, 8),
          )
        else if (l.datos.alertas.isEmpty)
          const EstadoVacio(
            titulo: 'Todo en calma',
            texto: 'No hay mar de leva, aguaceros, vientos fuertes ni riesgo de incendio a la vista.',
            animo: Animo.feliz,
            tamanoZanky: 96,
            relleno: EdgeInsets.fromLTRB(28, 0, 28, 8),
          )
        else
          for (final (a, extra) in l.datos.porLugar)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TarjetaAlerta(alerta: a, extra: extra),
            ),
        if (l.datos.generado != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
            child: Text(
              'Actualizado ${haceCuanto(l.datos.generado!)} · '
              '${l.datos.fuentes.map((f) => '${f.ok ? '●' : '○'} ${f.nombre}').join(' · ')}\n'
              '${l.datos.nota} Si hay peligro para las personas, llama al 123.',
              style: tt.labelSmall?.copyWith(color: Zc.textoSuave, height: 1.4),
            ),
          ),
      ],
    ]);
  }
}

// ------------------------------------------------------------------ reportes

/// Hoja de inscripción: nombre, celular opcional, consentimiento obligatorio y confirmación.
Future<bool?> abrirInscripcion(BuildContext context, Jornada j, FuenteComunidad fuente) {
  final nombre = Zanky.leer(context).perfil?.nombre.trim() ?? '';
  return mostrarHojaZ<bool>(context, nombre: 'inscripcion', contenido: (c) => _Inscripcion(j: j, fuente: fuente, nombre: nombre));
}

class _Inscripcion extends StatefulWidget {
  const _Inscripcion({required this.j, required this.fuente, required this.nombre});
  final Jornada j;
  final FuenteComunidad fuente;
  final String nombre;
  @override
  State<_Inscripcion> createState() => _InscripcionState();
}

class _InscripcionState extends State<_Inscripcion> {
  late final _nombre = TextEditingController(text: widget.nombre);
  final _cel = TextEditingController();
  bool _datos = false, _whatsapp = false, _enviando = false;
  String _error = '';

  @override
  void dispose() {
    _nombre.dispose();
    _cel.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_nombre.text.trim().length < 2) return setState(() => _error = 'Escribe tu nombre.');
    if (!_datos) return setState(() => _error = 'Para inscribirte, acepta el tratamiento de tus datos (Ley 1581).');
    setState(() {
      _enviando = true;
      _error = '';
    });
    final r = await widget.fuente.inscribirse(widget.j.id,
        nombre: _nombre.text, telefono: _cel.text, aceptaDatos: _datos, aceptaWhatsapp: _whatsapp && _cel.text.trim().isNotEmpty);
    if (!mounted) return;
    if (r.ok) {
      // Desde aquí se recuerda la jornada: la víspera y 2 h antes.
      CentroAvisos.compartido.recordarJornada(widget.j).ignore();
      vibrar(Vibracion.media);
      Navigator.of(context).pop(true);
      avisar(context, '¡Listo! Quedaste en la lista. Te esperamos.', tipo: TipoAviso.exito);
    } else {
      setState(() {
        _enviando = false;
        _error = r.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Inscribirme', style: tt.headlineSmall?.copyWith(color: Zc.texto)),
      const SizedBox(height: 4),
      Text(widget.j.titulo, style: tt.bodyMedium?.copyWith(color: Zc.textoSuave)),
      const SizedBox(height: 16),
      TextField(
        controller: _nombre,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Tu nombre', hintText: 'Como quieres aparecer en la lista'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _cel,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
        decoration: const InputDecoration(labelText: 'Celular (WhatsApp, opcional)', hintText: '300 123 4567'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      CheckboxListTile(
        value: _datos,
        onChanged: (v) => setState(() => _datos = v ?? false),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text('Acepto que la organización use mi nombre (y mi celular, si lo dejo) solo para la lista de esta jornada, según la Ley 1581 de 2012. No se publica.', style: tt.bodyMedium),
      ),
      if (_cel.text.trim().isNotEmpty)
        CheckboxListTile(
          value: _whatsapp,
          onChanged: (v) => setState(() => _whatsapp = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('Acepto recibir por WhatsApp recordatorios de esta jornada e invitaciones a otras.', style: tt.bodyMedium),
        ),
      AnimatedSwitcher(
        duration: Zm.corto,
        child: _error.isEmpty
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: ValueKey(_error),
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error, style: tt.bodyMedium?.copyWith(color: Cra.riesgoMuyAlto)),
              ),
      ),
      const SizedBox(height: 14),
      BotonZ(texto: 'Confirmar asistencia', icono: Icons.check_rounded, cargando: _enviando, onTap: _enviando ? null : _enviar),
    ]);
  }
}

// ------------------------------------------------------------------ guardianes

class _SeccionGuardianes extends StatelessWidget {
  const _SeccionGuardianes({required this.ranking, required this.web, required this.fallo});
  final List<ColegioEnRanking>? ranking;
  final List<ColegioWeb>? web;
  final bool fallo;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final real = ranking ?? const [];
    final filas = real.isNotEmpty
        ? [for (final c in real.take(5)) (c.puesto, c.nombre, '${c.validados} reportes validados')]
        : [
            for (final (k, c) in (web ?? const <ColegioWeb>[]).take(5).indexed)
              (k + 1, c.nombre, '${c.municipio} · ${c.puntos} puntos · ${c.validados} validados'),
          ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const TituloSeccion(antetitulo: 'Sostenibilidad y comunidad', titulo: 'Guardianes', tono: 'del manglar.'),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Row(children: [
          Expanded(
            child: Text('Los puntos salen de reportes verificados, no de la cantidad.',
                style: tt.bodyMedium?.copyWith(color: Zc.textoSuave)),
          ),
          if (ranking != null && real.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Zc.solClaro, borderRadius: BorderRadius.circular(99)),
              child: Text('Datos de ejemplo', style: tt.labelSmall?.copyWith(color: Zc.texto)),
            ),
        ]),
      ),
      if (ranking == null)
        const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Esqueleto.fila())
      else if (filas.isEmpty)
        const EstadoVacio(
          titulo: 'Pronto conocerás a los colegios guardianes',
          texto: 'Cuando la CRA valide reportes de un colegio, sube aquí.',
          tamanoZanky: 90,
          relleno: EdgeInsets.fromLTRB(28, 0, 28, 8),
        )
      else
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: Zc.superficie, borderRadius: BorderRadius.circular(Zr.m)),
          child: Column(children: [
            for (final (k, f) in filas.indexed) ...[
              if (k > 0) const Divider(height: 1, indent: 60, color: Zc.linea),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: f.$1 == 1 ? Cra.dorado : Zc.cienagaClara, shape: BoxShape.circle),
                    child: Text('${f.$1}', style: tt.titleSmall?.copyWith(color: Zc.texto, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleSmall?.copyWith(color: Zc.texto)),
                      Text(f.$3, style: tt.labelMedium?.copyWith(color: Zc.textoSuave)),
                    ]),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      if (fallo)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text('No se pudo leer el ranking real; se muestra el de la web.', style: tt.labelSmall?.copyWith(color: Zc.textoSuave)),
        ),
    ]);
  }
}

// ------------------------------------------------------------------ noticias

/// Noticias del manglar: una destacada y el resto en un carrusel (también lo usa Inicio).
class SeccionNoticias extends StatelessWidget {
  const SeccionNoticias({super.key, required this.lote});
  final Lote<List<NoticiaManglar>>? lote;

  @override
  Widget build(BuildContext context) {
    final l = lote;
    return LayoutBuilder(builder: (context, caja) {
      final ancho = caja.maxWidth;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const TituloSeccion(antetitulo: 'Desde la CRA', titulo: 'La CRA', tono: 'en el manglar'),
        if (l == null)
          const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Esqueleto.cabecera())
        else ...[
          NotaOrigen(origen: l.origen, cuando: l.cuando),
          if (l.datos.isEmpty)
            const EstadoVacio(
              titulo: 'Sin noticias por ahora',
              texto: 'Tira hacia abajo para buscar las más recientes de la CRA',
              tamanoZanky: 90,
              relleno: EdgeInsets.fromLTRB(28, 0, 28, 8),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TarjetaNoticia(noticia: l.datos.first, destacada: true),
            ),
            if (l.datos.length > 1) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 236,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: l.datos.length - 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, k) => TarjetaNoticia(noticia: l.datos[k + 1], ancho: ancho < 600 ? 230 : 260),
                ),
              ),
            ],
          ],
        ],
      ]);
    });
  }
}

// ------------------------------------------------------------------ datos abiertos

// La tarjeta vive en datos_abiertos.dart (descargar y copiar enlace).
