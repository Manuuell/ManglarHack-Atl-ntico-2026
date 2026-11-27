import 'package:flutter/material.dart';

import '../../datos/estado.dart';
import '../../datos/reporte.dart';
import '../../datos/tipos.dart';
import '../../nucleo/base/entrada_escalonada.dart';
import '../../nucleo/base/esqueleto.dart';
import '../../nucleo/kit/fila_deslizable.dart';
import '../../nucleo/kit/menu_mantenido.dart';
import '../../nucleo/kit/tirar_actualizar.dart';
import 'detalle_reporte.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/estado_vacio.dart';
import '../../nucleo/kit/segmentado.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/comunes.dart';
import '../comun/zanky_mascota.dart';
import '../reporte/flujo_reporte.dart';
import 'gestos_reporte.dart';
import 'tarjeta_reporte.dart';

enum _Filtro { todos, pendientes, validados }

/// Todo lo que reportaste: lo que aún está en el teléfono y lo que ya llegó a la CRA.
class PantallaMisReportes extends StatefulWidget {
  const PantallaMisReportes({super.key});

  @override
  State<PantallaMisReportes> createState() => _PantallaMisReportesState();
}

class _PantallaMisReportesState extends State<PantallaMisReportes> {
  _Filtro _filtro = _Filtro.todos;
  EstadoZanky? _estado;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final e = Zanky.leer(context);
    if (!identical(e, _estado)) {
      _estado?.novedades.removeListener(_novedad);
      _estado = e..novedades.addListener(_novedad);
    }
  }

  @override
  void dispose() {
    _estado?.novedades.removeListener(_novedad);
    super.dispose();
  }

  /// Seguimiento como en WhatsApp: «llegó» y «ahora está…» se anuncian solos.
  void _novedad() {
    final texto = _estado?.novedades.value;
    if (texto == null || !mounted) return;
    avisar(context, texto, tipo: TipoAviso.exito);
  }

  /// Cuántas filas entran escalonadas: lo que cabe en la primera pantalla. Las de más
  /// abajo aparecen al desplazar y no deben re-animarse cada vez que vuelven a la vista.
  static const _filasConEntrada = 8;

  bool _pasa(Reporte r) => switch (_filtro) {
        _Filtro.todos => true,
        _Filtro.pendientes =>
          r.envio != Envio.enviado || (!r.estado.validado && r.estado != EstadoReporte.descartado),
        _Filtro.validados => r.envio == Envio.enviado && r.estado.validado,
      };

  Future<void> _actualizar() async {
    try {
      await Zanky.leer(context).sincronizar();
    } catch (_) {
      // sincronizar() ya deja el error en cada reporte; el gesto solo termina.
    }
  }

  static String? _resumen(List<Reporte> todos) {
    final enCra = todos.where((r) => r.envio == Envio.enviado).length;
    final noAceptados = todos.where((r) => r.envio == Envio.rechazado).length;
    final enTel = todos.length - enCra - noAceptados;
    final partes = [
      if (enCra > 0) '$enCra en la CRA',
      if (enTel > 0) '$enTel en el teléfono',
      if (noAceptados > 0) '$noAceptados no aceptado${noAceptados == 1 ? '' : 's'}',
    ];
    return partes.isEmpty ? null : partes.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final e = Zanky.de(context);
    final todos = e.reportes;
    final filtrados = todos.where(_pasa).toList();
    final enTel = filtrados.where((r) => r.envio != Envio.enviado && r.envio != Envio.rechazado).toList();
    final rechazados = filtrados.where((r) => r.envio == Envio.rechazado).toList();
    final enCra = filtrados.where((r) => r.envio == Envio.enviado).toList();

    // Primera vuelta con el servidor y nada guardado todavía: esqueletos con la forma de las tarjetas.
    final cargando = todos.isEmpty && e.servidor.configurado && e.sincronizando && e.ultimaSincronizacion == null;

    final filas = <Object>[
      if (enTel.isNotEmpty) ...[
        const _Seccion('En tu teléfono'),
        const _AvisoEnvio(),
        ...enTel,
      ],
      if (rechazados.isNotEmpty) ...[
        const _Seccion('No aceptados'),
        const _AvisoRechazados(),
        ...rechazados,
      ],
      if (enCra.isNotEmpty) ...[
        const _Seccion('En la CRA'),
        ...enCra,
      ],
    ];

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CabeceraZ(titulo: 'Mis reportes', subtitulo: _resumen(todos)),
          if (Zanky.de(context).servidor.configurado) const FranjaConexion(),
          if (todos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SegmentadoZ(
                valor: _filtro.index,
                etiquetas: const ['Todos', 'Pendientes', 'Validados'],
                alCambiar: (i) => setState(() => _filtro = _Filtro.values[i]),
              ),
            ),
          Expanded(
            child: TirarActualizar(
              alActualizar: _actualizar,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (cargando)
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 110),
                      sliver: SliverToBoxAdapter(child: _EsqueletosLista()),
                    )
                  else if (todos.isEmpty)
                    const SliverFillRemaining(hasScrollBody: false, child: _VacioTotal())
                  else if (filtrados.isEmpty)
                    SliverFillRemaining(hasScrollBody: false, child: _VacioFiltro(_filtro))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      sliver: SliverList.builder(
                        itemCount: filas.length,
                        itemBuilder: (context, i) => _fila(context, filas[i], i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(BuildContext context, Object fila, int i) {
    final Widget w;
    if (fila is Reporte) {
      final acc = AccionesReporte(context, fila);
      final quitable = EstadoZanky.sePuedeQuitar(fila);
      final tarjeta = TarjetaReporte(
        reporte: fila,
        alTocar: () => abrirDetalleReporte(context, fila),
      );
      // Deslizar: derecha compartir, izquierda quitar. Mantener o clic derecho: menú con vista previa.
      w = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: RepaintBoundary(
          child: MenuMantenido(
            etiqueta: '${fila.tipo.nombre}, caso ${fila.caso}',
            vistaPrevia: (_) => VistaPreviaReporte(reporte: fila),
            acciones: [acc.abrir, acc.compartir, if (quitable) acc.quitar],
            child: FilaDeslizable(
              radio: BorderRadius.circular(Zr.l),
              accionesInicio: [acc.compartir],
              accionesFin: [if (quitable) acc.quitar],
              hijo: tarjeta,
            ),
          ),
        ),
      );
    } else {
      w = fila as Widget;
    }
    // La llave lleva el filtro: al cambiar de pestaña las filas entran de nuevo; al
    // sincronizar (mismo filtro) no se re-animan.
    return KeyedSubtree(
      key: ValueKey('${_filtro.name}-${fila is Reporte ? fila.id : fila.runtimeType}'),
      child: i < _filasConEntrada ? EntradaEscalonada(index: i, child: w) : w,
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.titulo);
  final String titulo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
        child: Semantics(header: true, child: Text(titulo, style: Theme.of(context).textTheme.titleLarge)),
      );
}

/// Explica qué pasó con los reportes que el servidor no aceptó (no se reintentan solos).
class _AvisoRechazados extends StatelessWidget {
  const _AvisoRechazados();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Zc.solClaro, borderRadius: BorderRadius.circular(Zr.m)),
          child: Text(
            'El servidor no aceptó estos reportes y no se reenvían solos. Ábrelos para ver el motivo y volver a intentar.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Zc.texto),
          ),
        ),
      );
}

/// Explica qué pasa con lo que sigue en el teléfono y deja enviarlo a mano.
class _AvisoEnvio extends StatelessWidget {
  const _AvisoEnvio();

  @override
  Widget build(BuildContext context) {
    final e = Zanky.de(context);
    final tt = Theme.of(context).textTheme;
    final conError = e.reportes.any((r) => r.envio == Envio.error);
    final String texto;
    if (!e.servidor.configurado) {
      texto = 'Modo demostración: estos reportes se quedan en este teléfono, no se envían a nadie.';
    } else if (!e.enLinea) {
      texto = 'Sin señal por ahora. Se envían solos cuando vuelva; no tienes que hacer nada.';
    } else if (conError) {
      texto = 'Alguno no pudo enviarse. Lo vuelvo a intentar solo, y también puedes probar ahora.';
    } else {
      texto = 'Se envían solos cuando hay señal. Si no quieres esperar, puedes enviarlos ahora.';
    }
    final puedeEnviar = e.servidor.configurado && e.enLinea;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Zc.solClaro,
          borderRadius: BorderRadius.circular(Zr.m),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.phone_android_rounded, size: 18, color: Zc.fango),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(texto, style: tt.bodyMedium?.copyWith(color: Zc.texto))),
              ],
            ),
            if (puedeEnviar) ...[
              const SizedBox(height: 12),
              BotonZ(
                texto: 'Enviar ahora',
                icono: Icons.cloud_upload_rounded,
                color: Zc.sol,
                colorTexto: Zc.raiz,
                cargando: e.sincronizando,
                onTap: () => Zanky.leer(context).sincronizar(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Todavía no hay ni un reporte: Zanky invita al primero.
class _VacioTotal extends StatelessWidget {
  const _VacioTotal();

  @override
  Widget build(BuildContext context) => EstadoVacio(
        titulo: 'Aún no has reportado nada',
        texto: 'Cuando veas algo raro en el manglar, tócame aquí abajo.',
        tamanoZanky: 170,
        conBurbuja: true,
        textoAccion: 'Hacer mi primer reporte',
        iconoAccion: Icons.add_a_photo_rounded,
        alAccion: () => abrirReporte(context),
      );
}

/// Hay reportes, pero ninguno cae en este filtro.
class _VacioFiltro extends StatelessWidget {
  const _VacioFiltro(this.filtro);
  final _Filtro filtro;

  @override
  Widget build(BuildContext context) {
    final (titulo, texto, animo) = switch (filtro) {
      _Filtro.pendientes => ('Nada pendiente', 'Todo lo que reportaste ya fue revisado. ¡Gracias por vigilar!', Animo.feliz),
      _Filtro.validados => (
          'Aún no hay validados',
          'Cuando la CRA o un vigía confirme uno de tus reportes, aparecerá aquí.',
          Animo.curioso
        ),
      _Filtro.todos => ('Nada por aquí', 'No hay reportes que mostrar.', Animo.curioso),
    };
    return EstadoVacio(
      // La llave lleva el filtro: al cambiar de pestaña Zanky vuelve a brotar.
      key: ValueKey(filtro),
      titulo: titulo,
      texto: texto,
      animo: animo,
      tamanoZanky: 120,
      relleno: const EdgeInsets.fromLTRB(32, 8, 32, 110),
    );
  }
}

/// Esqueletos con la forma de las tarjetas mientras llega la primera respuesta.
class _EsqueletosLista extends StatelessWidget {
  const _EsqueletosLista();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: EntradaEscalonada(
                index: i,
                child: const Skeleton(height: 130, borderRadius: BorderRadius.all(Radius.circular(Zr.l))),
              ),
            ),
        ],
      );
}
