import 'package:flutter/material.dart';

import '../../datos/admin/repositorio_admin.dart';
import '../../datos/gestion/repositorio_puntos.dart';
import '../../datos/servidor.dart';
import '../../nucleo/kit/boton_estado.dart';
import '../../nucleo/kit/estado_vacio.dart';
import '../../nucleo/kit/segmentado.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/accion_gesto.dart';
import '../../nucleo/kit/confirmar.dart';
import '../../nucleo/kit/fila_deslizable.dart';
import '../../nucleo/kit/menu_mantenido.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../../datos/punto/punto_zanky.dart';
import 'cartel_punto.dart';
import 'editor_punto.dart';

/// La puerta al gestor, en la sección del equipo de Guardián. Misma fila que `EntradaPanelCra`
/// (tomada de vistas/admin/entrada_panel.dart): un toque y entras. El servidor decide el rol real.
class EntradaGestor extends StatelessWidget {
  const EntradaGestor({super.key});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Presionable(
        escala: 0.98,
        etiqueta: 'Puntos Zanky. Crear códigos QR y grabar etiquetas NFC',
        onTap: () => abrirGestor(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Zc.superficie,
            borderRadius: BorderRadius.circular(Zr.m),
            border: Border.all(color: Zc.linea),
          ),
          child: Row(children: [
            const Icon(Icons.qr_code_2_rounded, color: Zc.hoja, size: 26),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Puntos Zanky', style: tt.titleSmall),
              Text('Crea un QR, imprime el cartel o graba una etiqueta NFC', style: tt.bodySmall),
            ])),
            const Icon(Icons.chevron_right_rounded, color: Zc.textoTenue),
          ]),
        ),
      ),
    );
  }
}

Future<void> abrirGestor(BuildContext context, {RepositorioPuntos? repositorio}) async {
  await Navigator.of(context).push(MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'gestor_puntos'),
    builder: (_) => GestorPuntos(repositorio: repositorio),
  ));
}

class GestorPuntos extends StatefulWidget {
  const GestorPuntos({super.key, this.repositorio});
  final RepositorioPuntos? repositorio;
  @override
  State<GestorPuntos> createState() => _GestorPuntosState();
}

class _GestorPuntosState extends State<GestorPuntos> {
  final _servidor = Servidor();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  RepositorioPuntos? _repo;
  List<PuntoZanky> _puntos = [];
  int _filtro = 0;
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.repositorio != null) {
      _repo = widget.repositorio;
      _actualizar();
    } else if (!_servidor.configurado) {
      _repo = RepositorioPuntosDemo(puntosDemostracion);
      _actualizar();
    }
  }

  @override
  void dispose() { _correo.dispose(); _clave.dispose(); super.dispose(); }

  Future<void> _entrar() async {
    try {
      final (sesion, rol) = await RepositorioRemoto.entrar(_servidor, _correo.text, _clave.text, DateTime.now());
      if (!puedeGestionarPuntos(rol)) {
        throw const ErrorPanel('Tu rol no permite gestionar puntos Zanky.');
      }
      if (!mounted) return;
      setState(() { _repo = RepositorioPuntosRemoto(_servidor, sesion); _error = null; });
      await _actualizar();
    } on ErrorPanel catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
      rethrow;
    }
  }

  Future<void> _actualizar() async {
    final repo = _repo;
    if (repo == null) return;
    setState(() => _cargando = true);
    try {
      final puntos = await repo.listar();
      if (mounted) setState(() { _puntos = puntos; _error = null; });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar los puntos. Revisa tu sesión y conexión.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar([PuntoZanky? punto]) async {
    final repo = _repo!;
    final guardado = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => EditorPunto(repositorio: repo, punto: punto)));
    if (guardado == true) await _actualizar();
  }

  Future<void> _abrirCartel(PuntoZanky p) => Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => CartelPunto(punto: p, demostracion: _repo?.demostracion ?? true)));

  Future<void> _alternar(PuntoZanky p) async {
    final repo = _repo;
    if (repo == null) return;
    final quitar = p.activo;
    if (quitar) {
      final si = await confirmarEnHoja(context, titulo: 'Desactivar punto',
        texto: 'El QR y la etiqueta de "${p.titulo}" dejarán de registrar visitas hasta que lo actives otra vez.',
        textoConfirmar: 'Desactivar', destructivo: true, seguroPrimero: true);
      if (!si) return;
    }
    try {
      await repo.guardar(PuntoZanky.deJson({...p.aJson(), 'activo': !p.activo}));
      await _actualizar();
    } catch (_) {
      if (mounted) avisar(context, 'No se pudo cambiar el estado del punto.');
    }
  }

  Future<void> _resumen(PuntoZanky punto) async {
    try {
      final r = await _repo!.resumen(punto.codigo);
      if (!mounted) return;
      await showModalBottomSheet<void>(context: context, showDragHandle: true,
        builder: (context) => SafeArea(child: ListView(shrinkWrap: true,
          padding: const EdgeInsets.all(24), children: [
          Semantics(header: true, child: Text('Visitas de ${punto.titulo}', style: Theme.of(context).textTheme.titleLarge)),
          const SizedBox(height: 12),
          Text('Total: ${r['total'] ?? 0}'),
          Text('Fotografías de seguimiento: ${r['fotografias'] ?? 0}'),
          for (final d in (r['por_dia'] as List? ?? []))
            Text('${d['dia']}: ${d['visitas']} visitas'),
          for (final d in (r['fotos_por_dia'] as List? ?? []))
            Text('${d['dia']}: ${d['fotografias']} fotografías'),
          if (_repo!.demostracion) const Text('DEMOSTRACIÓN · cifras de ejemplo'),
        ])));
    } catch (_) {
      if (mounted) avisar(context, 'No se pudo cargar el resumen de visitas.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    final filtrados = filtrarPuntos(_puntos, _filtro);
    return Scaffold(appBar: AppBar(title: const Text('Puntos Zanky')),
      floatingActionButton: repo == null ? null : FloatingActionButton.extended(
        onPressed: () => _editar(), icon: const Icon(Icons.add), label: const Text('Crear punto')),
      body: repo == null ? _acceso() : Column(children: [
        if (repo.demostracion) Container(width: double.infinity, padding: const EdgeInsets.all(12),
          color: Colors.amber.shade100, child: const Text('DEMOSTRACIÓN · los cambios viven solo en esta sesión; no se publican.')),
        Padding(padding: const EdgeInsets.all(16), child: SegmentadoZ(
          valor: _filtro, etiquetas: const ['Todos', 'Activos', 'Inactivos'],
          alCambiar: (i) => setState(() => _filtro = i))),
        if (_cargando) const LinearProgressIndicator(),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        Expanded(child: RefreshIndicator(onRefresh: _actualizar,
          child: filtrados.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                EstadoVacio(titulo: 'Sin puntos', texto: 'Crea el primer punto Zanky o cambia el filtro.')])
            : ListView.builder(itemCount: filtrados.length,
              itemBuilder: (context, i) {
                final p = filtrados[i];
                final editar = AccionGesto(etiqueta: 'Editar', icono: Icons.edit_rounded,
                  alEjecutar: () => _editar(p));
                final cartel = AccionGesto(etiqueta: 'QR y NFC', icono: Icons.qr_code_2_rounded,
                  alEjecutar: () => _abrirCartel(p));
                final visitas = AccionGesto(etiqueta: 'Visitas', icono: Icons.bar_chart_rounded,
                  alEjecutar: () => _resumen(p));
                final alternar = AccionGesto(
                  etiqueta: p.activo ? 'Desactivar' : 'Activar',
                  icono: p.activo ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  destructiva: p.activo,
                  alEjecutar: () => _alternar(p));
                return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: MenuMantenido(
                  etiqueta: '${p.titulo}, ${p.tipo.nombre}',
                  alTocar: () => _abrirCartel(p),
                  acciones: [cartel, editar, visitas, alternar],
                  child: FilaDeslizable(
                    radio: BorderRadius.circular(Zr.l),
                    accionesInicio: [cartel],
                    accionesFin: [alternar],
                    hijo: Card(margin: EdgeInsets.zero, child: Padding(
                      padding: const EdgeInsets.all(12), child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.titulo, style: Theme.of(context).textTheme.titleMedium),
                        Text('${p.tipo.nombre} · ${p.zona} · ${p.activo ? 'Activo' : 'Inactivo'}'),
                        Text(p.codigo),
                        Wrap(spacing: 8, children: [
                          TextButton(onPressed: () => _editar(p), child: const Text('Editar')),
                          TextButton(onPressed: () => _abrirCartel(p), child: const Text('QR y NFC')),
                          TextButton(onPressed: () => _resumen(p), child: const Text('Visitas')),
                        ]),
                      ]))),
                  ),
                ));
              }))),
      ]));
  }

  Widget _acceso() => ListView(padding: const EdgeInsets.all(24), children: [
    const Text('Entra con la cuenta del equipo. El servidor confirma tu rol antes de mostrar los puntos.'),
    const SizedBox(height: 18),
    TextField(controller: _correo, keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(labelText: 'Correo')),
    const SizedBox(height: 12),
    TextField(controller: _clave, obscureText: true,
      decoration: const InputDecoration(labelText: 'Contraseña')),
    const SizedBox(height: 18),
    if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
    BotonEstado(texto: 'Entrar al gestor', icono: Icons.login_rounded, alPresionar: _entrar),
  ]);
}
