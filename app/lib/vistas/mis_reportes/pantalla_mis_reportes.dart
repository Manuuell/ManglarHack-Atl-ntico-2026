import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../datos/estado.dart';
import '../../datos/reporte.dart';
import '../../datos/tipos.dart';
import '../../nucleo/base/entrada_escalonada.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/burbuja.dart';
import '../comun/comunes.dart';
import '../comun/zanky_mascota.dart';
import '../reporte/flujo_reporte.dart';
import 'detalle_reporte.dart';
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
    final enTel = todos.length - enCra;
    final partes = [
      if (enCra > 0) '$enCra en la CRA',
      if (enTel > 0) '$enTel en el teléfono',
    ];
    return partes.isEmpty ? null : partes.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final e = Zanky.de(context);
    final todos = e.reportes;
    final filtrados = todos.where(_pasa).toList();
    final enTel = filtrados.where((r) => r.envio != Envio.enviado).toList();
    final enCra = filtrados.where((r) => r.envio == Envio.enviado).toList();

    final filas = <Object>[
      if (enTel.isNotEmpty) ...[
        const _Seccion('En tu teléfono'),
        const _AvisoEnvio(),
        ...enTel,
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
              child: _Segmentado(
                valor: _filtro.index,
                etiquetas: const ['Todos', 'Pendientes', 'Validados'],
                alCambiar: (i) => setState(() => _filtro = _Filtro.values[i]),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              color: Zc.hoja,
              backgroundColor: Zc.superficie,
              onRefresh: _actualizar,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (todos.isEmpty)
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
      w = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: RepaintBoundary(
          child: TarjetaReporte(reporte: fila, alTocar: () => abrirDetalleReporte(context, fila)),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ZankyMascota(tamano: 190, animo: Animo.curioso),
            const SizedBox(height: 20),
            const BurbujaZanky(
              texto: 'Aún no has reportado nada. Cuando veas algo raro en el manglar, tócame aquí abajo.',
            ),
            const SizedBox(height: 24),
            BotonZ(
              texto: 'Hacer mi primer reporte',
              icono: Icons.add_a_photo_rounded,
              onTap: () => abrirReporte(context),
            ),
          ],
        ),
      );
}

/// Hay reportes, pero ninguno cae en este filtro.
class _VacioFiltro extends StatelessWidget {
  const _VacioFiltro(this.filtro);
  final _Filtro filtro;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final (titulo, texto) = switch (filtro) {
      _Filtro.pendientes => ('Nada pendiente', 'Todo lo que reportaste ya fue revisado. ¡Gracias por vigilar!'),
      _Filtro.validados => (
          'Aún no hay validados',
          'Cuando la CRA o un vigía confirme uno de tus reportes, aparecerá aquí.'
        ),
      _Filtro.todos => ('Nada por aquí', 'No hay reportes que mostrar.'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 110),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ZankyMascota(tamano: 110),
          const SizedBox(height: 14),
          Text(titulo, style: tt.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(texto, style: tt.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Selector de tres opciones propio: la píldora blanca se desliza con un resorte
/// (solo `transform`, sin relayout) y cada opción mide 44 px de alto.
class _Segmentado extends StatefulWidget {
  const _Segmentado({required this.valor, required this.etiquetas, required this.alCambiar});
  final int valor;
  final List<String> etiquetas;
  final ValueChanged<int> alCambiar;

  @override
  State<_Segmentado> createState() => _SegmentadoState();
}

class _SegmentadoState extends State<_Segmentado> with SingleTickerProviderStateMixin {
  late final AnimationController _pos = AnimationController.unbounded(vsync: this, value: widget.valor.toDouble());

  @override
  void didUpdateWidget(_Segmentado old) {
    super.didUpdateWidget(old);
    if (old.valor == widget.valor) return;
    final destino = widget.valor.toDouble();
    if (context.animationsDisabled) {
      _pos.value = destino;
    } else {
      _pos.animateWith(SpringSimulation(AppMotion.resorteFirme, _pos.value, destino, _pos.velocity));
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.etiquetas.length;
    final tt = Theme.of(context).textTheme;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Zc.linea.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Zr.s + 2),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final ancho = c.maxWidth / n;
          return Stack(
            children: [
              AnimatedBuilder(
                animation: _pos,
                builder: (context, hijo) => Transform.translate(offset: Offset(_pos.value * ancho, 0), child: hijo),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: SizedBox(
                    width: ancho - 6,
                    height: 38,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Zc.superficie,
                        borderRadius: BorderRadius.circular(Zr.s),
                        boxShadow: const [BoxShadow(color: Color(0x1A0B2E24), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: Semantics(
                        selected: i == widget.valor,
                        child: Presionable(
                          onTap: i == widget.valor ? null : () => widget.alCambiar(i),
                          escala: 0.96,
                          etiqueta: widget.etiquetas[i],
                          child: SizedBox(
                            height: 44,
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: Zm.corto,
                                style: tt.labelLarge!.copyWith(
                                  color: i == widget.valor ? Zc.texto : Zc.textoSuave,
                                ),
                                child: FittedBox(fit: BoxFit.scaleDown, child: Text(widget.etiquetas[i])),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
