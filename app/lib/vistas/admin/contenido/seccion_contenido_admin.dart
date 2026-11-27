import 'package:flutter/material.dart';

import '../../../datos/admin/contenido_panel.dart';
import '../../../datos/comunidad/comunidad.dart';
import '../../../datos/sensores/lecturas_sensor.dart';
import '../../../nucleo/base/esqueleto.dart';
import '../../../nucleo/base/hoja.dart';
import '../../../nucleo/identidad.dart';
import '../../../nucleo/kit/anuncio.dart';
import '../../../nucleo/kit/aviso.dart';
import '../../../nucleo/kit/confirmar.dart';
import '../../../nucleo/kit/haptica.dart';
import '../../../nucleo/kit/interruptor.dart';
import '../../../nucleo/presionable.dart';
import '../../../nucleo/tema.dart';
import '../../comun/zanky_mascota.dart';
import '../piezas_admin.dart';

/// Lo que se ve en el sub-menú de «Contenido»: las secciones que el rol puede editar y el historial.
enum _Pagina { portada, jornadas, noticias, puntos, umbrales, historial }

extension on _Pagina {
  SeccionContenido? get seccion => switch (this) {
        _Pagina.portada => SeccionContenido.portada,
        _Pagina.jornadas => SeccionContenido.jornadas,
        _Pagina.noticias => SeccionContenido.noticias,
        _Pagina.puntos => SeccionContenido.puntosQr,
        _Pagina.umbrales => SeccionContenido.umbrales,
        _Pagina.historial => null,
      };
  String get nombre => seccion?.nombre ?? 'Historial';
  IconData get icono => switch (this) {
        _Pagina.portada => Icons.home_rounded,
        _Pagina.jornadas => Icons.event_available_rounded,
        _Pagina.noticias => Icons.newspaper_rounded,
        _Pagina.puntos => Icons.qr_code_2_rounded,
        _Pagina.umbrales => Icons.speed_rounded,
        _Pagina.historial => Icons.history_rounded,
      };
}

/// «Contenido» dentro del panel: portada, jornadas, noticias, puntos QR, umbrales y el historial
/// de cambios. Cada sección aparece solo con su permiso. Teléfono: una sección a la vez con
/// segmentos; computador (≥ 900 px): lista de secciones a la izquierda y el editor al lado.
class SeccionContenidoAdmin extends StatefulWidget {
  const SeccionContenidoAdmin({super.key, required this.controlador, this.noticias});
  final ControladorContenidoPanel controlador;

  /// Para las pruebas; por defecto, las noticias de la CRA que ya lee Comunidad (con caché).
  final Future<List<NoticiaManglar>> Function()? noticias;

  @override
  State<SeccionContenidoAdmin> createState() => _SeccionContenidoAdminState();
}

class _SeccionContenidoAdminState extends State<SeccionContenidoAdmin> {
  _Pagina? _pagina;

  ControladorContenidoPanel get _c => widget.controlador;

  @override
  void initState() {
    super.initState();
    _c.addListener(_alCambiar);
    if (!_c.cargado && !_c.cargando) _c.cargar();
  }

  @override
  void dispose() {
    _c.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  List<_Pagina> get _paginas => [
        for (final p in _Pagina.values)
          if (p.seccion == null || _c.puedeEditar(p.seccion!)) p,
      ];

  @override
  Widget build(BuildContext context) {
    final paginas = _paginas;
    final actual = paginas.contains(_pagina) ? _pagina! : paginas.first;
    if (_c.cargando && !_c.cargado) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: const [
          Esqueleto.fila(),
          SizedBox(height: 12),
          Esqueleto.fila(),
          SizedBox(height: 12),
          Esqueleto.fila(),
        ],
      );
    }
    final editor = KeyedSubtree(
      key: ValueKey(actual),
      child: switch (actual) {
        _Pagina.portada => _EditorPortada(c: _c),
        _Pagina.jornadas => _EditorJornadas(c: _c),
        _Pagina.noticias => _EditorNoticias(c: _c, noticias: widget.noticias),
        _Pagina.puntos => _EditorPuntos(c: _c),
        _Pagina.umbrales => _EditorUmbrales(c: _c),
        _Pagina.historial => _Historial(c: _c),
      },
    );
    final animado = AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Zm.medio,
      switchInCurve: Zm.entrar,
      child: editor,
    );
    return LayoutBuilder(builder: (context, caja) {
      if (caja.maxWidth >= 900) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 260,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 110),
                    children: [
                      _FranjaOrigen(c: _c),
                      for (final p in paginas)
                        _FilaMenu(pagina: p, activa: p == actual, alTocar: () => setState(() => _pagina = p)),
                    ],
                  ),
                ),
                Expanded(child: animado),
              ],
            ),
          ),
        );
      }
      return Column(
        children: [
          SegmentosZ<_Pagina>(
            valores: paginas,
            actual: actual,
            nombre: (p) => p.nombre,
            alCambiar: (p) {
              vibrar(Vibracion.ligera);
              setState(() => _pagina = p);
            },
          ),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _FranjaOrigen(c: _c)),
          Expanded(child: animado),
        ],
      );
    });
  }
}

class _FilaMenu extends StatelessWidget {
  const _FilaMenu({required this.pagina, required this.activa, required this.alTocar});
  final _Pagina pagina;
  final bool activa;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        selected: activa,
        button: true,
        child: Presionable(
          etiqueta: pagina.nombre,
          onTap: alTocar,
          escala: 0.98,
          child: AnimatedContainer(
            duration: Zm.corto,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: activa ? Cra.superficieAlta : Colors.transparent,
              borderRadius: BorderRadius.circular(Zr.m),
              border: Border.all(color: activa ? Cra.dorado.withValues(alpha: 0.6) : Colors.transparent),
            ),
            child: Row(children: [
              Icon(pagina.icono, size: 20, color: activa ? Cra.dorado : Cra.textoSuave),
              const SizedBox(width: 12),
              Expanded(child: Text(pagina.nombre, style: tt.titleSmall?.copyWith(color: activa ? Cra.blanco : Cra.textoSuave))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Dice de dónde sale lo que se ve: demostración, valores de fábrica o copia sin señal.
class _FranjaOrigen extends StatelessWidget {
  const _FranjaOrigen({required this.c});
  final ControladorContenidoPanel c;

  @override
  Widget build(BuildContext context) {
    final (icono, texto) = c.demostracion
        ? (Icons.science_rounded, 'Demostración: los cambios viven en este teléfono y no llegan a la app de nadie.')
        : switch (c.origen) {
            OrigenContenido.servidor => (null, ''),
            OrigenContenido.copia => (Icons.cloud_off_rounded, 'Sin señal: ves la última copia guardada. Para guardar, vuelve a tener conexión.'),
            OrigenContenido.fabrica => c.sinSenal
                ? (Icons.cloud_off_rounded, 'Sin señal y sin copia: ves los valores de fábrica.')
                : (Icons.info_outline_rounded, 'Valores de fábrica: falta cargar contenido_editable.sql en Supabase para guardar.'),
          };
    if (icono == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Cra.superficie,
          borderRadius: BorderRadius.circular(Zr.m),
          border: Border.all(color: Cra.borde),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icono, size: 18, color: Cra.dorado),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodySmall)),
          if (!c.demostracion && c.origen != OrigenContenido.servidor)
            TextButton(onPressed: c.cargar, child: const Text('Reintentar')),
        ]),
      ),
    );
  }
}

/// Guarda, avisa y ofrece «Deshacer» (que vuelve a guardar lo de antes y queda en el historial).
Future<bool> _guardar(BuildContext context, ControladorContenidoPanel c, SeccionContenido s, ContenidoPanel nuevo,
    String resumen) async {
  final antes = c.contenido;
  final fallo = await c.guardar(s, nuevo, resumen);
  if (!context.mounted) return fallo == null;
  if (fallo != null) {
    vibrarError();
    anunciar(context, fallo);
    avisar(context, fallo, tipo: TipoAviso.error);
    return false;
  }
  vibrarExito();
  anunciar(context, resumen);
  avisar(context, resumen, tipo: TipoAviso.exito, accion: AccionAviso('Deshacer', () async {
    final f = await c.guardar(s, antes, 'Deshizo: $resumen');
    if (f != null && context.mounted) avisar(context, f, tipo: TipoAviso.error);
  }));
  return true;
}

/// Contenedor común de cada editor: lista con su título y nota.
class _Lienzo extends StatelessWidget {
  const _Lienzo({required this.titulo, required this.nota, required this.children});
  final String titulo;
  final String nota;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        Semantics(header: true, child: Text(titulo, style: tt.titleLarge?.copyWith(color: Cra.dorado))),
        const SizedBox(height: 4),
        Text(nota, style: tt.bodySmall),
        const SizedBox(height: 14),
        ...children,
      ],
    );
  }
}

class _Caja extends StatelessWidget {
  const _Caja({required this.child, this.apagada = false});
  final Widget child;
  final bool apagada;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        duration: Zm.corto,
        opacity: apagada ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Cra.superficie,
            borderRadius: BorderRadius.circular(Zr.l),
            border: Border.all(color: Cra.borde),
          ),
          child: child,
        ),
      );
}

class _BotonDorado extends StatelessWidget {
  const _BotonDorado({required this.texto, required this.icono, required this.alTocar, this.cargando = false});
  final String texto;
  final IconData icono;
  final VoidCallback? alTocar;
  final bool cargando;

  @override
  Widget build(BuildContext context) =>
      BotonZ(texto: texto, icono: icono, onTap: alTocar, cargando: cargando, color: Cra.dorado, colorTexto: Cra.azul);
}

// ───────────────────────────── Portada ─────────────────────────────

class _EditorPortada extends StatefulWidget {
  const _EditorPortada({required this.c});
  final ControladorContenidoPanel c;
  @override
  State<_EditorPortada> createState() => _EditorPortadaState();
}

class _EditorPortadaState extends State<_EditorPortada> {
  late final _mensaje = TextEditingController(text: widget.c.contenido.portada.mensaje);
  late final _aviso = TextEditingController(text: widget.c.contenido.portada.aviso);
  late bool _avisoActivo = widget.c.contenido.portada.avisoActivo;
  bool _guardando = false;

  PortadaPanel get _borrador => PortadaPanel(mensaje: _mensaje.text.trim(), aviso: _aviso.text.trim(), avisoActivo: _avisoActivo);
  bool get _cambio => _borrador != widget.c.contenido.portada;

  @override
  void dispose() {
    _mensaje.dispose();
    _aviso.dispose();
    super.dispose();
  }

  Future<void> _guardarPortada() async {
    setState(() => _guardando = true);
    await _guardar(context, widget.c, SeccionContenido.portada, widget.c.contenido.copiar(portada: _borrador),
        'Cambió los textos de la portada');
    if (mounted) {
      final p = widget.c.contenido.portada;
      setState(() {
        _guardando = false;
        if (_mensaje.text.trim() != p.mensaje) _mensaje.text = p.mensaje;
        if (_aviso.text.trim() != p.aviso) _aviso.text = p.aviso;
        _avisoActivo = p.avisoActivo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final b = _borrador;
    return _Lienzo(
      titulo: 'Portada de la app',
      nota: 'Lo primero que ve la gente en Inicio. Vacío = Inicio muestra lo de siempre.',
      children: [
        TextField(
          controller: _mensaje,
          maxLength: PortadaPanel.maxMensaje,
          maxLines: 2,
          minLines: 1,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Mensaje destacado', hintText: 'Ej.: Este sábado sembramos en Bocana'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _aviso,
          maxLength: PortadaPanel.maxAviso,
          maxLines: 3,
          minLines: 1,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Aviso del día', hintText: 'Ej.: Marea alta a las 4 p. m.: no entrar al caño'),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: Text('Mostrar el aviso del día', style: tt.bodyLarge)),
          InterruptorIos(
            valor: _avisoActivo,
            etiqueta: 'Mostrar el aviso del día',
            colorActivo: Cra.dorado,
            alCambiar: _aviso.text.trim().isEmpty ? null : (v) => setState(() => _avisoActivo = v),
          ),
        ]),
        const SizedBox(height: 16),
        Text('Vista previa', style: tt.labelLarge?.copyWith(color: Cra.textoSuave)),
        const SizedBox(height: 8),
        _Caja(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.mensaje.isEmpty ? 'Inicio de siempre (sin mensaje destacado)' : b.mensaje,
                style: tt.titleMedium?.copyWith(color: b.mensaje.isEmpty ? Cra.textoTenue : Cra.blanco)),
            if (b.avisoActivo && b.aviso.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Cra.dorado.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(Zr.m)),
                child: Row(children: [
                  const Icon(Icons.campaign_rounded, color: Cra.dorado, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(b.aviso, style: tt.bodyMedium?.copyWith(color: Cra.blanco))),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 18),
        _BotonDorado(
          texto: _cambio ? 'Guardar portada' : 'Sin cambios',
          icono: Icons.check_rounded,
          cargando: _guardando,
          alTocar: _cambio && widget.c.editable ? _guardarPortada : null,
        ),
      ],
    );
  }
}

// ───────────────────────────── Jornadas ─────────────────────────────

const _mesesCortos = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];

String fechaCorta(DateTime f) {
  final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
  final m = f.minute.toString().padLeft(2, '0');
  return '${f.day} ${_mesesCortos[f.month - 1]} ${f.year} · $h:$m ${f.hour < 12 ? 'a. m.' : 'p. m.'}';
}

class _EditorJornadas extends StatelessWidget {
  const _EditorJornadas({required this.c});
  final ControladorContenidoPanel c;

  Future<void> _editar(BuildContext context, JornadaPanel? j) async {
    final r = await mostrarHojaZ<JornadaPanel>(context,
        nombre: j == null ? 'nueva_jornada' : 'editar_jornada', contenido: (_) => _HojaJornada(inicial: j));
    if (r == null || !context.mounted) return;
    final lista = [...c.contenido.jornadas];
    final i = lista.indexWhere((x) => x.id == r.id);
    if (i < 0) {
      lista.add(r);
    } else {
      lista[i] = r;
    }
    lista.sort((a, b) => a.fecha.compareTo(b.fecha));
    await _guardar(context, c, SeccionContenido.jornadas, c.contenido.copiar(jornadas: lista),
        i < 0 ? 'Creó la jornada «${r.titulo}»' : 'Editó la jornada «${r.titulo}»');
  }

  Future<void> _cerrar(BuildContext context, JornadaPanel j) async {
    final cerrar = !j.cerrada;
    if (cerrar) {
      final ok = await confirmarEnHoja(context,
          titulo: '¿Cerrar «${j.titulo}»?',
          texto: 'Nadie más podrá inscribirse. Puedes reabrirla después.',
          textoConfirmar: 'Cerrar inscripciones');
      if (!ok || !context.mounted) return;
    }
    await _guardar(
        context,
        c,
        SeccionContenido.jornadas,
        c.contenido.copiar(jornadas: [for (final x in c.contenido.jornadas) x.id == j.id ? x.copiar(cerrada: cerrar) : x]),
        cerrar ? 'Cerró la jornada «${j.titulo}»' : 'Reabrió la jornada «${j.titulo}»');
  }

  Future<void> _quitar(BuildContext context, JornadaPanel j) async {
    final ok = await confirmarEnHoja(context,
        titulo: '¿Quitar «${j.titulo}»?',
        texto: 'Deja de verse en la app. Tendrás unos segundos para deshacer.',
        textoConfirmar: 'Quitar',
        destructivo: true);
    if (!ok || !context.mounted) return;
    await _guardar(context, c, SeccionContenido.jornadas,
        c.contenido.copiar(jornadas: [for (final x in c.contenido.jornadas) if (x.id != j.id) x]), 'Quitó la jornada «${j.titulo}»');
  }

  @override
  Widget build(BuildContext context) {
    final lista = c.contenido.jornadas;
    return _Lienzo(
      titulo: 'Jornadas',
      nota: 'Siembras, limpiezas y recorridos que convoca el equipo, con foto, fecha, lugar y cupos.',
      children: [
        _BotonDorado(texto: 'Nueva jornada', icono: Icons.add_rounded, alTocar: c.editable ? () => _editar(context, null) : null),
        const SizedBox(height: 14),
        if (lista.isEmpty)
          const VacioAdmin(
            titulo: 'Aún no hay jornadas del panel',
            detalle: 'Crea la primera: se verá en Comunidad junto a las que ya tiene la app.',
            animo: Animo.curioso,
          ),
        for (final j in lista) ...[
          _FilaJornada(
            j: j,
            editable: c.editable,
            alEditar: () => _editar(context, j),
            alCerrar: () => _cerrar(context, j),
            alQuitar: () => _quitar(context, j),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FilaJornada extends StatelessWidget {
  const _FilaJornada({required this.j, required this.editable, required this.alEditar, required this.alCerrar, required this.alQuitar});
  final JornadaPanel j;
  final bool editable;
  final VoidCallback alEditar, alCerrar, alQuitar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '${j.titulo}, ${fechaCorta(j.fecha)}, ${j.lugar}, ${j.textoCupos}${j.cerrada ? ', cerrada' : ''}',
      child: _Caja(
        apagada: j.cerrada,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Zr.m),
              child: SizedBox(
                width: 64,
                height: 64,
                child: j.fotoUrl.isEmpty
                    ? const ColoredBox(color: Cra.superficieAlta, child: Icon(Icons.park_rounded, color: Cra.dorado))
                    : Image.network(j.fotoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: Cra.superficieAlta, child: Icon(Icons.broken_image_rounded, color: Cra.textoTenue))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ExcludeSemantics(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(j.titulo, style: tt.titleMedium),
                  const SizedBox(height: 2),
                  Text(fechaCorta(j.fecha), style: tt.bodySmall),
                  Text(j.lugar, style: tt.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _Chip(j.textoCupos),
                    _Chip(j.cerrada ? 'Cerrada' : 'Abierta', resaltado: !j.cerrada),
                  ]),
                ]),
              ),
            ),
          ]),
          if (editable) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 4, children: [
              TextButton.icon(onPressed: alEditar, icon: const Icon(Icons.edit_rounded, size: 18), label: const Text('Editar')),
              TextButton.icon(
                  onPressed: alCerrar,
                  icon: Icon(j.cerrada ? Icons.lock_open_rounded : Icons.lock_rounded, size: 18),
                  label: Text(j.cerrada ? 'Reabrir' : 'Cerrar')),
              TextButton.icon(onPressed: alQuitar, icon: const Icon(Icons.delete_outline_rounded, size: 18), label: const Text('Quitar')),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.texto, {this.resaltado = false});
  final String texto;
  final bool resaltado;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: resaltado ? Cra.dorado.withValues(alpha: 0.18) : Cra.superficieAlta,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(texto, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: resaltado ? Cra.dorado : Cra.textoSuave)),
      );
}

/// Hoja para crear o editar una jornada. Devuelve la jornada lista, o nada si se cancela.
class _HojaJornada extends StatefulWidget {
  const _HojaJornada({this.inicial});
  final JornadaPanel? inicial;
  @override
  State<_HojaJornada> createState() => _HojaJornadaState();
}

class _HojaJornadaState extends State<_HojaJornada> {
  late final _titulo = TextEditingController(text: widget.inicial?.titulo ?? '');
  late final _lugar = TextEditingController(text: widget.inicial?.lugar ?? '');
  late final _foto = TextEditingController(text: widget.inicial?.fotoUrl ?? '');
  late final _cupos = TextEditingController(text: widget.inicial?.cupos?.toString() ?? '');
  late bool _sinLimite = widget.inicial == null || widget.inicial!.cupos == null;
  late DateTime _fecha = widget.inicial?.fecha ?? _sabadoProximo();
  bool _intento = false;

  static DateTime _sabadoProximo() {
    final h = DateTime.now();
    final d = (DateTime.saturday - h.weekday + 7) % 7;
    return DateTime(h.year, h.month, h.day + (d == 0 ? 7 : d), 7);
  }

  @override
  void dispose() {
    _titulo.dispose();
    _lugar.dispose();
    _foto.dispose();
    _cupos.dispose();
    super.dispose();
  }

  String? get _errTitulo => _titulo.text.trim().length < 3 ? 'Escribe un título (3 letras o más)' : null;
  String? get _errLugar => _lugar.text.trim().isEmpty ? 'Di dónde es el encuentro' : null;
  String? get _errFoto {
    final t = _foto.text.trim();
    if (t.isEmpty) return null;
    final u = Uri.tryParse(t);
    return u == null || u.scheme != 'https' || u.host.isEmpty ? 'Pega un enlace https de la foto' : null;
  }

  String? get _errCupos {
    if (_sinLimite) return null;
    final n = int.tryParse(_cupos.text.trim());
    return n == null || n < 1 || n > 5000 ? 'Un número entre 1 y 5000' : null;
  }

  Future<void> _elegirFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha de la jornada',
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_fecha), helpText: 'Hora de encuentro');
    if (!mounted) return;
    setState(() => _fecha = DateTime(d.year, d.month, d.day, t?.hour ?? _fecha.hour, t?.minute ?? _fecha.minute));
  }

  void _listo() {
    setState(() => _intento = true);
    if (_errTitulo != null || _errLugar != null || _errFoto != null || _errCupos != null) {
      vibrarError();
      return;
    }
    final i = widget.inicial;
    Navigator.of(context).pop(JornadaPanel(
      id: i?.id ?? 'j-${DateTime.now().millisecondsSinceEpoch}',
      titulo: _titulo.text.trim(),
      fecha: _fecha,
      lugar: _lugar.text.trim(),
      fotoUrl: _foto.text.trim(),
      cupos: _sinLimite ? null : int.parse(_cupos.text.trim()),
      cerrada: i?.cerrada ?? false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.inicial == null ? 'Nueva jornada' : 'Editar jornada', style: tt.titleLarge),
      const SizedBox(height: 12),
      TextField(
        controller: _titulo,
        maxLength: 80,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: 'Título', errorText: _intento ? _errTitulo : null),
      ),
      const SizedBox(height: 6),
      Presionable(
        etiqueta: 'Fecha y hora: ${fechaCorta(_fecha)}. Toca para cambiar',
        onTap: _elegirFecha,
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'Fecha y hora', suffixIcon: Icon(Icons.calendar_month_rounded)),
          child: Text(fechaCorta(_fecha)),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _lugar,
        maxLength: 120,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: 'Lugar de encuentro', errorText: _intento ? _errLugar : null),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: _foto,
        keyboardType: TextInputType.url,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
            labelText: 'Foto (enlace https, opcional)', errorText: _errFoto != null && (_intento || _foto.text.length > 8) ? _errFoto : null),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: Text('Cupos sin límite', style: tt.bodyLarge)),
        InterruptorIos(
          valor: _sinLimite,
          etiqueta: 'Cupos sin límite',
          colorActivo: Cra.dorado,
          alCambiar: (v) => setState(() => _sinLimite = v),
        ),
      ]),
      AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Zm.corto,
        child: _sinLimite
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _cupos,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: 'Número de cupos', errorText: _intento ? _errCupos : null),
                ),
              ),
      ),
      const SizedBox(height: 18),
      _BotonDorado(texto: widget.inicial == null ? 'Crear jornada' : 'Guardar cambios', icono: Icons.check_rounded, alTocar: _listo),
    ]);
  }
}

// ───────────────────────────── Noticias ─────────────────────────────

class _EditorNoticias extends StatefulWidget {
  const _EditorNoticias({required this.c, this.noticias});
  final ControladorContenidoPanel c;
  final Future<List<NoticiaManglar>> Function()? noticias;
  @override
  State<_EditorNoticias> createState() => _EditorNoticiasState();
}

class _EditorNoticiasState extends State<_EditorNoticias> {
  late Future<List<NoticiaManglar>> _futuro = _pedir();

  Future<List<NoticiaManglar>> _pedir() =>
      widget.noticias?.call() ?? FuenteComunidad.compartida.noticias().then((l) => l.datos);

  Future<void> _cambiar(NoticiaManglar n, {bool? fijar, bool? ocultar}) {
    final c = widget.c.contenido;
    final fijadas = {...c.fijadas}, ocultas = {...c.ocultas};
    String resumen;
    if (fijar != null) {
      fijar ? fijadas.add(n.id) : fijadas.remove(n.id);
      if (fijar) ocultas.remove(n.id);
      resumen = fijar ? 'Fijó la noticia «${n.titulo}»' : 'Soltó la noticia «${n.titulo}»';
    } else {
      ocultar! ? ocultas.add(n.id) : ocultas.remove(n.id);
      if (ocultar) fijadas.remove(n.id);
      resumen = ocultar ? 'Ocultó la noticia «${n.titulo}»' : 'Volvió a mostrar «${n.titulo}»';
    }
    return _guardar(context, widget.c, SeccionContenido.noticias, c.copiar(fijadas: fijadas, ocultas: ocultas), resumen);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return FutureBuilder<List<NoticiaManglar>>(
      future: _futuro,
      builder: (context, s) {
        final c = widget.c.contenido;
        return _Lienzo(
          titulo: 'Noticias',
          nota: 'Las noticias de la CRA que ve Comunidad. Fija hasta tres arriba u oculta las que no van.',
          children: [
            if (s.connectionState != ConnectionState.done) ...[
              const Esqueleto.fila(),
              const SizedBox(height: 10),
              const Esqueleto.fila(),
            ] else if (s.hasError || (s.data?.isEmpty ?? true))
              VacioAdmin(
                titulo: s.hasError ? 'No pude traer las noticias' : 'No hay noticias por ahora',
                detalle: s.hasError ? 'Revisa la señal y vuelve a intentar.' : 'Cuando la CRA publique, aparecerán aquí.',
                animo: s.hasError ? Animo.preocupado : Animo.curioso,
                accion: TextButton(onPressed: () => setState(() => _futuro = _pedir()), child: const Text('Reintentar')),
              )
            else
              for (final n in s.data!) ...[
                _Caja(
                  apagada: c.ocultas.contains(n.id),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (c.fijadas.contains(n.id)) const _Chip('Fijada arriba', resaltado: true),
                        if (c.ocultas.contains(n.id)) const _Chip('Oculta'),
                        Text(n.titulo, style: tt.titleSmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                        Text(fechaCorta(n.fecha).split(' · ').first, style: tt.bodySmall),
                      ]),
                    ),
                    if (widget.c.editable) ...[
                      IconButton(
                        tooltip: c.fijadas.contains(n.id) ? 'Soltar' : 'Fijar arriba',
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: Icon(c.fijadas.contains(n.id) ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                            color: c.fijadas.contains(n.id) ? Cra.dorado : Cra.textoSuave),
                        onPressed: !c.fijadas.contains(n.id) && c.fijadas.length >= 3
                            ? () => avisar(context, 'Ya hay tres fijadas: suelta una primero.', tipo: TipoAviso.aviso)
                            : () => _cambiar(n, fijar: !c.fijadas.contains(n.id)),
                      ),
                      IconButton(
                        tooltip: c.ocultas.contains(n.id) ? 'Mostrar' : 'Ocultar',
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: Icon(c.ocultas.contains(n.id) ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: Cra.textoSuave),
                        onPressed: () => _cambiar(n, ocultar: !c.ocultas.contains(n.id)),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

// ───────────────────────────── Puntos QR ─────────────────────────────

class _EditorPuntos extends StatefulWidget {
  const _EditorPuntos({required this.c});
  final ControladorContenidoPanel c;
  @override
  State<_EditorPuntos> createState() => _EditorPuntosState();
}

class _EditorPuntosState extends State<_EditorPuntos> {
  @override
  void initState() {
    super.initState();
    if (widget.c.puntos == null) widget.c.cargarPuntos();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final tt = Theme.of(context).textTheme;
    final puntos = c.puntos;
    return _Lienzo(
      titulo: 'Puntos QR y retos',
      nota: 'Un punto apagado deja de sumar visitas: quien lo escanee verá que está cerrado.',
      children: [
        if (puntos == null) ...[
          const Esqueleto.fila(),
          const SizedBox(height: 10),
          const Esqueleto.fila(),
        ] else if (puntos.isEmpty)
          VacioAdmin(
            titulo: c.falloPuntos == null ? 'Aún no hay puntos' : 'No pude traer los puntos',
            detalle: c.falloPuntos ?? 'Crea puntos desde Configuración › Gestión › Puntos.',
            animo: c.falloPuntos == null ? Animo.curioso : Animo.preocupado,
            accion: TextButton(onPressed: c.cargarPuntos, child: const Text('Reintentar')),
          )
        else
          for (final p in puntos) ...[
            _Caja(
              apagada: c.contenido.puntosInactivos.contains(p.codigo),
              child: Row(children: [
                const Icon(Icons.qr_code_2_rounded, color: Cra.dorado),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (p.ejemplo) const _Chip('Ejemplo'),
                    Text(p.titulo.isEmpty ? p.codigo : p.titulo, style: tt.titleSmall),
                    Text([p.codigo, if (p.zona.isNotEmpty) p.zona].join(' · '), style: tt.bodySmall),
                  ]),
                ),
                InterruptorIos(
                  valor: !c.contenido.puntosInactivos.contains(p.codigo),
                  etiqueta: 'Punto ${p.titulo} activo',
                  colorActivo: Cra.dorado,
                  alCambiar: !c.editable
                      ? null
                      : (activo) {
                          final s = {...c.contenido.puntosInactivos};
                          activo ? s.remove(p.codigo) : s.add(p.codigo);
                          _guardar(context, c, SeccionContenido.puntosQr, c.contenido.copiar(puntosInactivos: s),
                              activo ? 'Activó el punto «${p.titulo}»' : 'Apagó el punto «${p.titulo}»');
                        },
                ),
              ]),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

// ───────────────────────────── Umbrales ─────────────────────────────

class _EditorUmbrales extends StatefulWidget {
  const _EditorUmbrales({required this.c});
  final ControladorContenidoPanel c;
  @override
  State<_EditorUmbrales> createState() => _EditorUmbralesState();
}

class _EditorUmbralesState extends State<_EditorUmbrales> {
  late Map<String, double> _borrador = {for (final t in TipoSensor.values) t.id: widget.c.contenido.umbral(t)};
  bool _guardando = false;

  bool get _cambio => TipoSensor.values.any((t) => _borrador[t.id] != widget.c.contenido.umbral(t));

  String _texto(TipoSensor t, double v) => '${v.toStringAsFixed(t.decimales)} ${t.unidad}';

  Future<void> _guardarUmbrales() async {
    setState(() => _guardando = true);
    await _guardar(context, widget.c, SeccionContenido.umbrales, widget.c.contenido.copiar(umbrales: {..._borrador}),
        'Cambió los umbrales de alerta de los sensores');
    if (mounted) {
      setState(() {
        _guardando = false;
        _borrador = {for (final t in TipoSensor.values) t.id: widget.c.contenido.umbral(t)};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return _Lienzo(
      titulo: 'Umbrales de alerta',
      nota: 'Desde qué lectura la estación avisa. Se aplican a todas las sondas de esa medida.',
      children: [
        for (final t in TipoSensor.values) ...[
          _Caja(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(t.nombre, style: tt.titleSmall)),
                Text(_texto(t, _borrador[t.id]!), style: tt.titleMedium?.copyWith(color: Cra.dorado)),
              ]),
              Slider(
                value: _borrador[t.id]!.clamp(t.minimo, t.maximo).toDouble(),
                min: t.minimo,
                max: t.maximo,
                activeColor: Cra.dorado,
                label: _texto(t, _borrador[t.id]!),
                semanticFormatterCallback: (v) => _texto(t, v),
                onChanged: widget.c.editable
                    ? (v) {
                        final paso = t.decimales == 0 ? 1.0 : (t.decimales == 1 ? 0.1 : 0.01);
                        setState(() => _borrador[t.id] = (v / paso).round() * paso);
                      }
                    : null,
              ),
              Text(t.explicacion, style: tt.bodySmall),
              if (_borrador[t.id] != t.umbralReferencia && widget.c.editable)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _borrador[t.id] = t.umbralReferencia),
                    child: Text('Volver al de referencia (${_texto(t, t.umbralReferencia)})'),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        _BotonDorado(
          texto: _cambio ? 'Guardar umbrales' : 'Sin cambios',
          icono: Icons.check_rounded,
          cargando: _guardando,
          alTocar: _cambio && widget.c.editable ? _guardarUmbrales : null,
        ),
      ],
    );
  }
}

// ───────────────────────────── Historial ─────────────────────────────

class _Historial extends StatefulWidget {
  const _Historial({required this.c});
  final ControladorContenidoPanel c;
  @override
  State<_Historial> createState() => _HistorialState();
}

class _HistorialState extends State<_Historial> {
  @override
  void initState() {
    super.initState();
    widget.c.cargarHistorial();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final tt = Theme.of(context).textTheme;
    final lista = c.historial;
    return _Lienzo(
      titulo: 'Historial de cambios',
      nota: 'Quién cambió qué y cuándo (los últimos 50).',
      children: [
        if (c.cargandoHistorial && lista.isEmpty) ...[
          const Esqueleto.fila(),
          const SizedBox(height: 10),
          const Esqueleto.fila(),
        ] else if (lista.isEmpty)
          VacioAdmin(
            titulo: c.falloHistorial == null ? 'Sin cambios todavía' : 'Historial no disponible',
            detalle: c.falloHistorial ?? 'Cada cambio guardado en el panel aparecerá aquí.',
            animo: c.falloHistorial == null ? Animo.curioso : Animo.preocupado,
            accion: c.falloHistorial == null ? null : TextButton(onPressed: c.cargarHistorial, child: const Text('Reintentar')),
          )
        else
          for (final h in lista)
            Semantics(
              container: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: Cra.superficieAlta, shape: BoxShape.circle),
                    child: Icon(switch (h.seccion) {
                      SeccionContenido.portada => Icons.home_rounded,
                      SeccionContenido.jornadas => Icons.event_available_rounded,
                      SeccionContenido.noticias => Icons.newspaper_rounded,
                      SeccionContenido.puntosQr => Icons.qr_code_2_rounded,
                      SeccionContenido.umbrales => Icons.speed_rounded,
                      null => Icons.edit_rounded,
                    }, size: 18, color: Cra.dorado),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(h.resumen, style: tt.bodyLarge),
                      Text('${h.quien} · ${fechaCorta(h.cuando)}', style: tt.bodySmall),
                    ]),
                  ),
                ]),
              ),
            ),
      ],
    );
  }
}
