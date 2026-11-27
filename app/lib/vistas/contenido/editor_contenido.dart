import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../nucleo/kit/segmentado.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import 'bloques_contenido.dart';
import 'estudio_contenido.dart';
import 'modelo_contenido.dart';
import 'repositorio_contenido.dart';

/// Editor de contenido por pasos: **Bloques → Vista previa → Versiones**.
///
/// Estructura portada de FastFood `src/components/admin/brand-studio.tsx`:
/// pasos con indicador que se desliza (aquí `SegmentadoZ`), cada paso
/// queda montado al ir y volver (no se pierde lo escrito), botón «Seguir
/// con…», borrador compartido en vivo ([EstudioContenido], igual que
/// `BrandDraftProvider`), y barra de guardado fija ([BarraGuardado], de
/// `settings-save-bar.tsx`). En pantalla ancha la vista previa queda al
/// lado, como la columna de `brand-preview-stage.tsx`.
class EditorContenido extends StatefulWidget {
  const EditorContenido({super.key, required this.ambito, this.clave = 'principal', this.repositorio});
  final String ambito, clave;
  final RepositorioContenido? repositorio;
  @override State<EditorContenido> createState() => _EditorContenidoState();
}

class _EditorContenidoState extends State<EditorContenido> {
  late final RepositorioContenido _repo = widget.repositorio ?? RepositorioContenido();
  late final EstudioContenido _estudio = EstudioContenido(DocumentoContenido(
    clave: widget.clave, ambito: widget.ambito, bloques: const []));
  bool _cargando = true, _guardando = false, _error = false;
  String? _mensaje;
  int _paso = 0;
  final Set<int> _abiertos = {0};
  List<DocumentoContenido>? _versiones;

  static const _pasos = ['Bloques', 'Vista previa', 'Versiones'];

  @override void initState() { super.initState(); _cargar(); }
  @override void dispose() {
    _estudio.dispose();
    if (widget.repositorio == null) _repo.cerrar();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final d = await _repo.cargar(widget.clave, widget.ambito, editor: true);
      if (mounted) setState(() { if (d != null) _estudio.cargar(d); _cargando = false; });
    } catch (e) {
      if (mounted) setState(() { _mensaje = '$e'; _error = true; _cargando = false; });
    }
  }

  void _irA(int i) {
    vibrar(Vibracion.seleccion);
    setState(() { _paso = i; _abiertos.add(i); });
    if (i == 2) _cargarVersiones();
  }

  Future<void> _cargarVersiones() async {
    try {
      final v = await _repo.versiones(widget.clave, widget.ambito);
      if (mounted) setState(() => _versiones = v);
    } catch (e) {
      if (mounted) setState(() { _mensaje = '$e'; _error = true; _versiones = const []; });
    }
  }

  Future<void> _guardar(bool publicar) async {
    if (_guardando) return;
    setState(() { _guardando = true; _error = false; });
    try {
      final d = await _repo.guardar(_estudio.actual, publicar: publicar);
      _estudio.alGuardar(d);
      vibrar(Vibracion.media);
      if (mounted) {
        setState(() { _mensaje = publicar ? 'Publicado · versión ${d.version}' : 'Borrador guardado · versión ${d.version}'; });
        if (_abiertos.contains(2)) _cargarVersiones();
      }
    } catch (e) {
      if (mounted) setState(() { _error = true; _mensaje = e.toString().replaceFirst('Bad state: ', ''); });
      rethrow;
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _editar(Bloque b) async {
    final texto = TextEditingController(text: b.texto);
    final url = TextEditingController(text: b.url);
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true,
      builder: (context) => StatefulBuilder(builder: (context, refrescar) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Editar ${_nombreTipo(b.tipo)}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(controller: texto, autofocus: true,
            maxLines: b.tipo == 'texto' || b.tipo == 'lista' ? 5 : 1,
            onChanged: (_) => refrescar(() {}),
            decoration: InputDecoration(labelText: b.tipo == 'lista' ? 'Un elemento por línea' : 'Texto')),
          if (b.tipo == 'imagen_url' || b.tipo == 'boton') TextField(controller: url,
            onChanged: (_) => refrescar(() {}),
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: 'Enlace https://',
              errorText: url.text.trim().isNotEmpty && Uri.tryParse(url.text.trim())?.scheme != 'https'
                ? 'Debe empezar con https://' : null)),
          const SizedBox(height: 12),
          const Text('Así se verá'),
          PintarBloques(bloques: [b.copiar(texto: texto.text, url: url.text)], previa: true),
          const SizedBox(height: 12),
          FilledButton(onPressed: () {
            final valor = url.text.trim();
            if (valor.isNotEmpty && Uri.tryParse(valor)?.scheme != 'https') return;
            vibrar(Vibracion.ligera);
            _estudio.cambio((e) => e.editar(b.id, texto: texto.text, url: valor));
            Navigator.pop(context);
          }, child: const Text('Aplicar')),
        ])))));
    texto.dispose(); url.dispose();
  }

  static String _nombreTipo(String t) => switch (t) {
    'titulo' => 'título', 'texto' => 'texto', 'imagen_url' => 'imagen',
    'boton' => 'botón', 'aviso' => 'aviso', 'lista' => 'lista', _ => t };

  Widget _pasoBloques() {
    final d = _estudio.actual;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Bloques', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      const Text('Toca un bloque para editarlo. Mantén presionada el asa para cambiar el orden.'),
      const SizedBox(height: 8),
      ReorderableListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false, itemCount: d.bloques.length,
        onReorderItem: (a, b) => _estudio.cambio((e) => e.reordenar(a, b > a ? b + 1 : b)),
        itemBuilder: (context, i) { final b = d.bloques[i]; return Card(key: ValueKey(b.id),
          child: Row(children: [
            ReorderableDragStartListener(index: i, child: const SizedBox(width: 48, height: 48,
              child: Icon(Icons.drag_handle_rounded, semanticLabel: 'Cambiar orden'))),
            Expanded(child: ListTile(title: Text(b.texto.isEmpty ? _nombreTipo(b.tipo) : b.texto,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: b.oculto ? Zc.textoTenue : null)),
              subtitle: Text(_nombreTipo(b.tipo) + (b.oculto ? ' · oculto' : '')),
              onTap: () => _editar(b))),
            IconButton(tooltip: b.oculto ? 'Mostrar' : 'Ocultar',
              onPressed: () => _estudio.cambio((e) => e.editar(b.id, oculto: !b.oculto)),
              icon: Icon(b.oculto ? Icons.visibility_off : Icons.visibility)),
            IconButton(tooltip: 'Quitar', onPressed: () => _estudio.cambio((e) => e.quitar(b.id)),
              icon: const Icon(Icons.close)),
          ])); }),
      PopupMenuButton<String>(tooltip: 'Agregar bloque',
        onSelected: (tipo) { vibrar(Vibracion.ligera);
          _estudio.cambio((e) => e.agregar(Bloque(id: const Uuid().v4(), tipo: tipo))); },
        itemBuilder: (_) => [for (final t in tiposBloque) PopupMenuItem(value: t, child: Text(_nombreTipo(t)))],
        child: const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Row(children: [
          Icon(Icons.add_circle_outline), SizedBox(width: 8), Text('Agregar bloque')]))),
      _seguir(),
    ]);
  }

  Widget _seguir() {
    if (_paso >= _pasos.length - 1) return const SizedBox.shrink();
    return Align(alignment: Alignment.centerRight, child: FilledButton.tonalIcon(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: () => _irA(_paso + 1), icon: const Icon(Icons.arrow_forward),
      label: Text('Seguir con ${_pasos[_paso + 1]}')));
  }

  Widget _pasoPrevia() => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Vista previa en vivo', style: Theme.of(context).textTheme.titleLarge),
    const Text('Es lo que verá el ciudadano. Los bloques ocultos no aparecen.'),
    const VistaPreviaContenido(),
    _seguir(),
  ]);

  Widget _pasoVersiones() => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Versiones guardadas', style: Theme.of(context).textTheme.titleLarge),
    const Text('Toca una versión para recuperar sus bloques como cambio sin guardar.'),
    const SizedBox(height: 8),
    if (_versiones == null) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
    else if (_versiones!.isEmpty) const Padding(padding: EdgeInsets.all(24),
      child: Text('Todavía no hay versiones guardadas.'))
    else for (final d in _versiones!) Card(child: ListTile(minVerticalPadding: 12,
      title: Text('Versión ${d.version} · ${d.publicado ? "Publicada" : "Borrador"}'),
      subtitle: Text(d.editadoEn?.toLocal().toString().split('.').first ?? ''),
      trailing: const Icon(Icons.restore_rounded),
      onTap: () { vibrar(Vibracion.seleccion);
        _estudio.cambio((e) => e.cambiar(e.actual.copiar(bloques: d.bloques)));
        setState(() => _mensaje = 'Recuperaste la versión ${d.version}. Guarda para conservarla.'); _irA(0); })),
  ]);

  @override Widget build(BuildContext context) => EnVivoContenido(estudio: _estudio,
    child: ListenableBuilder(listenable: _estudio, builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text('Contenido · ${widget.ambito}'), actions: [
        IconButton(tooltip: 'Deshacer', onPressed: _estudio.borrador.puedeDeshacer ? _estudio.deshacer : null,
          icon: const Icon(Icons.undo_rounded)),
      ]),
      bottomNavigationBar: _cargando ? null : BarraGuardado(sucio: _estudio.sucio, guardando: _guardando,
        mensaje: _mensaje, error: _error, alDescartar: () { _estudio.descartar(); setState(() => _mensaje = null); },
        alGuardar: () => _guardar(false), alPublicar: () => _guardar(true)),
      body: _cargando ? const Center(child: CircularProgressIndicator()) : SafeArea(child: LayoutBuilder(
        builder: (context, c) {
          final ancho = c.maxWidth >= 900;
          return Column(children: [
            if (_repo.demostracion) Container(width: double.infinity, color: Zc.solClaro,
              padding: const EdgeInsets.all(10),
              child: const Text('Demostración: los cambios se guardan solo en este dispositivo.')),
            if (!ancho) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SegmentadoZ(valor: _paso, etiquetas: _pasos, alCambiar: _irA))
            else Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(alignment: Alignment.centerLeft, child: SizedBox(width: 360,
                child: SegmentadoZ(valor: _paso == 2 ? 1 : 0, etiquetas: const ['Bloques', 'Versiones'],
                  alCambiar: (i) => _irA(i == 0 ? 0 : 2))))),
            Expanded(child: ancho
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: IndexedStack(index: _paso == 2 ? 1 : 0, children: [
                    _pasoBloques(), if (_abiertos.contains(2)) _pasoVersiones() else const SizedBox.shrink()])),
                  SizedBox(width: 400, child: ListView(padding: const EdgeInsets.all(16), children: [
                    Text('Vista previa en vivo', style: Theme.of(context).textTheme.titleLarge),
                    const VistaPreviaContenido()])),
                ])
              : IndexedStack(index: _paso, children: [
                  _pasoBloques(),
                  if (_abiertos.contains(1)) _pasoPrevia() else const SizedBox.shrink(),
                  if (_abiertos.contains(2)) _pasoVersiones() else const SizedBox.shrink(),
                ])),
          ]);
        })),
    )));
}
