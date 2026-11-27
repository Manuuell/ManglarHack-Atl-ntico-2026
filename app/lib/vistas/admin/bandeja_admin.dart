import 'package:flutter/material.dart';

import '../../datos/admin/controlador_admin.dart';
import '../../datos/admin/reporte_admin.dart';
import '../../nucleo/base/entrada_escalonada.dart';
import '../../nucleo/base/esqueleto.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/comunes.dart';
import '../comun/zanky_mascota.dart';
import 'detalle_admin.dart';
import 'piezas_admin.dart';

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
    return Column(
      children: [
        SegmentosZ<FiltroBandeja>(
          valores: FiltroBandeja.values,
          actual: c.filtro,
          nombre: (f) => f.nombre,
          cuenta: (f) => c.cargado ? conteos[f] : null,
          alCambiar: c.cambiarFiltro,
        ),
        Expanded(
          child: RefreshIndicator(
            color: Zc.hoja,
            onRefresh: () => c.actualizar(),
            child: _Cuerpo(controlador: c, lista: lista),
          ),
        ),
      ],
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
          Text(texto, style: tt.bodySmall?.copyWith(color: Zc.textoTenue)),
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
                  size: 20, color: activo ? Zc.hoja : Zc.textoSuave),
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
  const _Cuerpo({required this.controlador, required this.lista});
  final ControladorAdmin controlador;
  final List<ReporteAdmin> lista;

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
          key: ValueKey(r.id),
          padding: EdgeInsets.fromLTRB(16, i == cabecera.length ? 10 : 0, 16, 10),
          child: EntradaEscalonada(index: i - cabecera.length, child: TarjetaAdmin(reporte: r, alTocar: () => abrirDetalleAdmin(context, r.id))),
        );
      },
    );
  }
}

/// Una fila de la bandeja: lo que decide si abrirla ya o después.
class TarjetaAdmin extends StatelessWidget {
  const TarjetaAdmin({super.key, required this.reporte, required this.alTocar});
  final ReporteAdmin reporte;
  final VoidCallback alTocar;

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
          color: Zc.superficie,
          borderRadius: BorderRadius.circular(Zr.l),
          border: Border.all(color: r.pendiente && r.prioridad >= 4 ? Zc.dePrioridad(r.prioridad).withValues(alpha: 0.5) : Zc.linea.withValues(alpha: 0.7)),
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
              child: Icon(Icons.chevron_right_rounded, color: Zc.textoTenue),
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
        Icon(icono, size: 14, color: Zc.textoSuave),
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
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'panel_cra/detalle'),
      builder: (_) => AdminScope(controlador: c, child: DetalleAdmin(id: id)),
    ),
  );
}
