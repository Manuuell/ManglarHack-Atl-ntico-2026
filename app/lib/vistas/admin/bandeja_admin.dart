import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../datos/admin/controlador_admin.dart';
import '../../datos/admin/reporte_admin.dart';
import '../../nucleo/base/entrada_escalonada.dart';
import '../../nucleo/base/esqueleto.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/kit/accion_gesto.dart';
import '../../nucleo/kit/bandeja_acciones.dart';
import '../../nucleo/kit/fila_deslizable.dart';
import '../../nucleo/kit/haptica.dart';
import '../../nucleo/kit/menu_mantenido.dart';
import '../../nucleo/kit/ruta_borde.dart';
import '../../nucleo/kit/tirar_actualizar.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/tema.dart';
import '../comun/comunes.dart';
import '../comun/zanky_mascota.dart';
import '../avisos_zona/avisos_encargado.dart';
import 'detalle_admin.dart';
import 'permisos/pantalla_permisos.dart';
import 'piezas_admin.dart';
import '../../datos/permisos/permisos_rol.dart';

/// La bandeja de verificación: filtros arriba, lo pendiente primero y lo más urgente
/// arriba. Al abrirla, lo que había deja de contar como «nuevo» en el ícono del panel.
class BandejaAdmin extends StatefulWidget {
  const BandejaAdmin({super.key, required this.controlador});
  final ControladorAdmin controlador;

  @override
  State<BandejaAdmin> createState() => _BandejaAdminState();
}

class _BandejaAdminState extends State<BandejaAdmin> {
  ControladorAdmin get _c => widget.controlador;

  /// Atajos de teclado (web y escritorio): j/k mueven, a aprueba, r rechaza.
  String? _sel;
  final Map<String, GlobalKey> _claves = {};

  List<ReporteAdmin> get _lista => _c.visibles;

  void _mover(int paso) {
    final l = _lista;
    if (l.isEmpty) return;
    final i = l.indexWhere((r) => r.id == _sel);
    final n = i < 0 ? (paso > 0 ? 0 : l.length - 1) : (i + paso).clamp(0, l.length - 1);
    setState(() => _sel = l[n].id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _claves[_sel]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 160), alignment: 0.3);
    });
  }

  KeyEventResult _tecla(FocusNode nodo, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final t = HardwareKeyboard.instance;
    if (t.isControlPressed || t.isMetaPressed || t.isAltPressed) return KeyEventResult.ignored;
    // Escribiendo en un campo: las letras son letras.
    if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final sel = _lista.where((r) => r.id == _sel && puedeEnPanel(context, _c.rol, Permiso.decidirReportes)).firstOrNull;
    if (k == LogicalKeyboardKey.keyJ) {
      _mover(1);
    } else if (k == LogicalKeyboardKey.keyK) {
      _mover(-1);
    } else if (k == LogicalKeyboardKey.keyA && sel != null && sel.pendiente) {
      unawaited(aprobarConDeshacer(context, _c, sel));
    } else if (k == LogicalKeyboardKey.keyR && sel != null && sel.pendiente) {
      unawaited(rechazarConMotivo(context, _c, sel));
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  void initState() {
    super.initState();
    _c.addListener(_visto);
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.marcarVistos());
  }

  @override
  void dispose() {
    _c.removeListener(_visto);
    super.dispose();
  }

  /// Mientras la bandeja está a la vista, lo que llega se ve en el momento: no suma al contador.
  void _visto() {
    if (mounted && _c.sinVer > 0) WidgetsBinding.instance.addPostFrameCallback((_) => _c.marcarVistos());
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final conteos = c.conteos;
    final lista = c.visibles;
    return Focus(
      autofocus: true,
      onKeyEvent: _tecla,
      child: Column(
      children: [
        SegmentosZ<FiltroBandeja>(
          valores: FiltroBandeja.values,
          actual: c.filtro,
          nombre: (f) => f.nombre,
          cuenta: (f) => c.cargado ? conteos[f] : null,
          alCambiar: c.cambiarFiltro,
        ),
        if (c.dentro) Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => AvisosEncargado(controlador: c),
            )),
            icon: const Icon(Icons.notifications_outlined),
            label: const Text('Avisos de mi zona'),
          ),
        ),
        Expanded(
          child: TirarActualizar(
            alActualizar: () => c.actualizar(),
            child: _Cuerpo(controlador: c, lista: lista, seleccion: _sel, claves: _claves),
          ),
        ),
      ],
      ),
    );
  }
}

/// La línea de «actualizado hace…» y el interruptor de avisos del navegador (solo en la web).
class _Estado extends StatelessWidget {
  const _Estado({required this.controlador});
  final ControladorAdmin controlador;

  @override
  Widget build(BuildContext context) {
    final c = controlador;
    final tt = Theme.of(context).textTheme;
    final t = c.ultimaConsulta;
    final texto = t == null
        ? 'Sin actualizar todavía'
        : 'Actualizado ${haceCuanto(t, c.reloj())}${c.cada > Duration.zero ? ' · se revisa solo cada ${c.cada.inSeconds} s' : ''}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto, style: tt.bodySmall?.copyWith(color: Cra.textoTenue)),
          if (c.navegador.disponible) _AvisosNavegador(controlador: c),
        ],
      ),
    );
  }
}

class _AvisosNavegador extends StatelessWidget {
  const _AvisosNavegador({required this.controlador});
  final ControladorAdmin controlador;

  @override
  Widget build(BuildContext context) {
    final c = controlador;
    final tt = Theme.of(context).textTheme;
    final activo = c.navegador.activo;
    final bloqueado = c.navegador.bloqueado;
    return Semantics(
      toggled: activo,
      child: Presionable(
        etiqueta: activo ? 'Desactivar avisos del navegador' : 'Activar avisos del navegador',
        onTap: bloqueado ? null : () => c.activarAvisosNavegador(!activo),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Icon(activo ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                  size: 20, color: activo ? Cra.hoja : Cra.textoSuave),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  bloqueado
                      ? 'Avisos del navegador bloqueados: actívalos en los permisos del sitio'
                      : (activo ? 'Avisos del navegador activados' : 'Avisarme en el navegador cuando llegue un reporte'),
                  style: tt.bodySmall,
                ),
              ),
              if (!bloqueado) ExcludeSemantics(child: Switch(value: activo, onChanged: (v) => c.activarAvisosNavegador(v))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({required this.controlador, required this.lista, this.seleccion, this.claves = const {}});
  final ControladorAdmin controlador;
  final List<ReporteAdmin> lista;
  final String? seleccion;
  final Map<String, GlobalKey> claves;

  @override
  Widget build(BuildContext context) {
    final c = controlador;
    // Siempre desplazable: así el «tirar para actualizar» funciona también vacío. La franja
    // de demostración y la línea de «actualizado» viajan con la lista: con letra grande no
    // le quitan la pantalla a lo que importa.
    const fisica = AlwaysScrollableScrollPhysics();
    final cabecera = <Widget>[
      if (c.demostracion) FranjaDemo(controlador: c),
      _Estado(controlador: c),
      if (_hayTeclado(context) && lista.any((r) => r.pendiente)) const _AyudaAtajos(),
    ];
    if (!c.cargado) {
      return ListView(
        physics: fisica,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
        children: [
          ...cabecera,
          if (c.error == null)
            const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: Esqueleto.lista(4))
          else
            ErrorAdmin(mensaje: c.error!, alReintentar: () => c.actualizar()),
        ],
      );
    }
    if (lista.isEmpty) {
      final (titulo, detalle, animo) = switch (c.filtro) {
        FiltroBandeja.pendientes => ('Todo al día', 'No hay reportes esperando decisión. Zanky respira tranquilo.', Animo.celebrando),
        FiltroBandeja.aprobados => ('Aún no hay aprobados', 'Cuando apruebes un reporte aparecerá aquí.', Animo.curioso),
        FiltroBandeja.rechazados => ('Nada rechazado', 'Los reportes que descartes con su motivo quedan aquí.', Animo.feliz),
        FiltroBandeja.todos => ('Sin reportes todavía', 'Cuando alguien reporte algo, lo verás aquí en menos de 30 segundos.', Animo.curioso),
      };
      return ListView(physics: fisica, children: [...cabecera, VacioAdmin(titulo: titulo, detalle: detalle, animo: animo)]);
    }
    return ListView.builder(
      physics: fisica,
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: cabecera.length + lista.length,
      itemBuilder: (context, i) {
        if (i < cabecera.length) return cabecera[i];
        final r = lista[i - cabecera.length];
        return Padding(
          key: claves.putIfAbsent(r.id, GlobalKey.new),
          padding: EdgeInsets.fromLTRB(16, i == cabecera.length ? 10 : 0, 16, 10),
          child: EntradaEscalonada(
            index: i - cabecera.length,
            child: TarjetaAdminConGestos(controlador: c, reporte: r, resaltada: r.id == seleccion),
          ),
        );
      },
    );
  }
}

/// Una fila de la bandeja: lo que decide si abrirla ya o después.
class TarjetaAdmin extends StatelessWidget {
  const TarjetaAdmin({super.key, required this.reporte, required this.alTocar, this.resaltada = false});
  final ReporteAdmin reporte;
  final VoidCallback alTocar;

  /// La que tiene el cursor de los atajos de teclado (j/k).
  final bool resaltada;

  @override
  Widget build(BuildContext context) {
    final r = reporte;
    final tt = Theme.of(context).textTheme;
    final dist = r.dentroPoligono
        ? 'Dentro del manglar'
        : (r.distanciaM == null ? null : 'A ${_metros(r.distanciaM!)} del manglar');
    final resumenLector = '${r.tipo.nombre}, ${r.zona}, prioridad ${r.prioridad} de 5, confianza ${r.confianza} por ciento, '
        '${r.estado.nombre}${r.tieneFoto ? ', con foto' : ''}';
    return Presionable(
      escala: 0.98,
      etiqueta: resumenLector,
      onTap: alTocar,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Cra.superficie,
          borderRadius: BorderRadius.circular(Zr.l),
          border: Border.all(width: resaltada ? 2.5 : 1, color: resaltada ? Cra.cienaga : r.pendiente && r.prioridad >= 4 ? Cra.dePrioridad(r.prioridad).withValues(alpha: 0.5) : Cra.linea.withValues(alpha: 0.7)),
          boxShadow: const [BoxShadow(color: Color(0x0F0B2E24), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconoTipo(r.tipo, tamano: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.tipo.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleSmall),
                  const SizedBox(height: 2),
                  Text('${r.zona} · ${haceCuanto(r.llegadaEn)}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PildoraPrioridad(r.prioridad, compacta: true),
                      EtiquetaEstado(r.estado),
                      if (r.tieneFoto) const _Dato(Icons.photo_camera_rounded, 'Con foto'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (dist != null) _Dato(Icons.near_me_rounded, dist),
                      _Dato(Icons.verified_user_rounded, 'Confianza ${r.confianza} %'),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 10),
              child: Icon(Icons.chevron_right_rounded, color: Cra.textoTenue),
            ),
          ],
        ),
      ),
    );
  }

  static String _metros(int m) => m < 1000 ? '$m m' : '${(m / 1000).toStringAsFixed(1)} km';
}

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.texto);
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: Cra.textoSuave),
        const SizedBox(width: 4),
        Flexible(child: Text(texto, style: Theme.of(context).textTheme.bodySmall)),
      ],
    );
  }
}

/// Abre el detalle de un reporte. Recibe el id, no el reporte: así, si cambia mientras se
/// mira (otra consulta, una decisión), la pantalla lo ve actualizado.
Future<void> abrirDetalleAdmin(BuildContext context, String id) {
  final c = AdminScope.leer(context);
  return Navigator.of(context).push(
    RutaBorde<void>(
      sinMovimiento: MediaQuery.disableAnimationsOf(context),
      settings: const RouteSettings(name: 'panel_cra/detalle'),
      builder: (_) => AdminScope(controlador: c, child: DetalleAdmin(id: id)),
    ),
  );
}

/// ¿Hay teclado de verdad? Web y escritorio (en el teléfono no se muestran atajos).
bool _hayTeclado(BuildContext context) {
  if (kIsWeb || MediaQuery.sizeOf(context).width >= 700) return true;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => false,
    _ => true,
  };
}

class _AyudaAtajos extends StatelessWidget {
  const _AyudaAtajos();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Text('Atajos: J / K moverse · A aprobar · R rechazar',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Cra.textoTenue)),
      );
}

/// Aprobar sin pedir confirmación: la barra «Deshacer» del panel da 6 segundos.
Future<void> aprobarConDeshacer(BuildContext context, ControladorAdmin c, ReporteAdmin r) async {
  vibrarExito();
  await c.decidir(AccionAdmin.aprobar, r);
}

/// Rechazar exige el motivo (lo lee quien reportó): abre la misma hoja del detalle y, al
/// decidir, queda «Deshacer».
Future<void> rechazarConMotivo(BuildContext context, ControladorAdmin c, ReporteAdmin r) async {
  final texto = await mostrarHojaZ<String>(
    context,
    nombre: 'panel_cra/${AccionAdmin.rechazar.name}',
    contenido: (_) => HojaDecision(accion: AccionAdmin.rechazar, reporte: r),
  );
  if (texto == null || !context.mounted) return;
  vibrarExito();
  await c.decidir(AccionAdmin.rechazar, r, texto: texto.isEmpty ? null : texto);
}

/// Una tarjeta de la bandeja con todos sus caminos: tocar abre; deslizar a la derecha
/// aprueba y a la izquierda rechaza; mantener (o clic derecho) abre un menú con la foto;
/// en pantallas anchas hay además botones a la vista. Solo lo pendiente se decide.
class TarjetaAdminConGestos extends StatelessWidget {
  const TarjetaAdminConGestos({super.key, required this.controlador, required this.reporte, this.resaltada = false});
  final ControladorAdmin controlador;
  final ReporteAdmin reporte;
  final bool resaltada;

  @override
  Widget build(BuildContext context) {
    final r = reporte;
    final c = controlador;
    // Solo decide quien tiene el permiso (matriz de permisos del panel); los demás solo miran.
    final decide = r.pendiente && puedeEnPanel(context, c.rol, Permiso.decidirReportes);
    final abrir = AccionGesto(
      etiqueta: 'Abrir detalle',
      icono: Icons.open_in_new_rounded,
      alEjecutar: () => abrirDetalleAdmin(context, r.id),
    );
    final aprobar = AccionGesto(
      etiqueta: 'Aprobar',
      icono: Icons.verified_rounded,
      color: Cra.hoja,
      alEjecutar: () => aprobarConDeshacer(context, c, r),
    );
    final rechazar = AccionGesto(
      etiqueta: 'Rechazar',
      icono: Icons.do_not_disturb_on_rounded,
      color: Cra.dePrioridad(5),
      alEjecutar: () => rechazarConMotivo(context, c, r),
    );
    final tarjeta = TarjetaAdmin(reporte: r, alTocar: () => abrirDetalleAdmin(context, r.id), resaltada: resaltada);
    final ancha = MediaQuery.sizeOf(context).width >= 700;
    final conBotones = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tarjeta,
        if (decide && ancha) ...[
          const SizedBox(height: 8),
          BandejaAcciones(acciones: [aprobar, rechazar], etiqueta: 'Decidir ${r.tipo.nombre}'),
        ],
      ],
    );
    return MenuMantenido(
      etiqueta: '${r.tipo.nombre}, ${r.zona}',
      vistaPrevia: (_) => _VistaPreviaAdmin(controlador: c, reporte: r),
      acciones: [abrir, if (decide) ...[aprobar, rechazar]],
      child: FilaDeslizable(
        radio: BorderRadius.circular(Zr.l),
        accionesInicio: [if (decide) aprobar],
        accionesFin: [if (decide) rechazar],
        hijo: conBotones,
      ),
    );
  }
}

class _VistaPreviaAdmin extends StatelessWidget {
  const _VistaPreviaAdmin({required this.controlador, required this.reporte});
  final ControladorAdmin controlador;
  final ReporteAdmin reporte;

  @override
  Widget build(BuildContext context) {
    final r = reporte;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 170,
          width: double.infinity,
          child: r.tieneFoto
              ? FutureBuilder<Uint8List?>(
                  future: controlador.foto(r),
                  builder: (_, s) => s.data != null
                      ? Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true)
                      : Container(
                          color: Cra.hojaClara,
                          alignment: Alignment.center,
                          child: s.connectionState == ConnectionState.done
                              ? Text(controlador.demostracion ? 'La demostración no trae fotos' : 'Sin foto disponible',
                                  style: tt.bodySmall)
                              : const SizedBox.square(
                                  dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Cra.hoja)),
                        ),
                )
              : Container(
                  color: Cra.hojaClara,
                  alignment: Alignment.center,
                  child: Text('Este reporte no trae foto', style: tt.bodySmall),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.tipo.nombre, style: tt.titleMedium),
              const SizedBox(height: 2),
              Text('${r.zona} · ${haceCuanto(r.llegadaEn)}', style: tt.bodySmall),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [PildoraPrioridad(r.prioridad, compacta: true), EtiquetaEstado(r.estado)]),
            ],
          ),
        ),
      ],
    );
  }
}
