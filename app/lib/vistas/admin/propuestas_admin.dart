import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../datos/comunidad/comunidad.dart';
import '../../nucleo/base/esqueleto.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/kit/accion_gesto.dart';
import '../../nucleo/kit/anuncio.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/fila_deslizable.dart';
import '../../nucleo/kit/menu_mantenido.dart';
import '../../nucleo/kit/tirar_actualizar.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';
import 'piezas_admin.dart';

typedef CargarPropuestas = Future<Lote<List<PropuestaWhatsapp>>> Function();

/// «Propuestas» del panel: las acciones que la gente propone por WhatsApp («💡 Proponer» del bot),
/// las mismas que la web muestra en su panel (`propuestasBot.ts`: mismo título «Siembra propuesta
/// por WhatsApp · PROP-…», mismos nombres de tipo y de quién propone). Sin datos personales.
///
/// Se ve con el permiso `ver_reportes`. Una sola consulta al abrir (la fuente guarda la copia en el
/// teléfono); tirar hacia abajo vuelve a pedir. Sin señal se ve la última copia, con su hora.
class PropuestasAdmin extends StatefulWidget {
  const PropuestasAdmin({super.key, this.cargar});

  /// Para las pruebas; por defecto, `FuenteComunidad.compartida.propuestas()`.
  final CargarPropuestas? cargar;

  @override
  State<PropuestasAdmin> createState() => _PropuestasAdminState();
}

class _PropuestasAdminState extends State<PropuestasAdmin> {
  /// Lo último que se trajo en esta sesión: volver a la pestaña no repite la consulta.
  static Lote<List<PropuestaWhatsapp>>? _memoria;

  Lote<List<PropuestaWhatsapp>>? _lote;
  bool _cargando = false;

  CargarPropuestas get _cargar => widget.cargar ?? FuenteComunidad.compartida.propuestas;

  @override
  void initState() {
    super.initState();
    // Con fuente inyectada (pruebas) no se usa la memoria de la sesión.
    _lote = widget.cargar == null ? _memoria : null;
    if (_lote == null) unawaited(_traer());
  }

  Future<void> _traer() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    Lote<List<PropuestaWhatsapp>>? l;
    try {
      l = await _cargar();
    } catch (_) {
      l = const Lote(<PropuestaWhatsapp>[], OrigenDato.nada, null);
    }
    if (!mounted) return;
    if (widget.cargar == null) _memoria = l;
    setState(() {
      _lote = l;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = _lote;
    final Widget cuerpo;
    if (l == null) {
      cuerpo = ListView(
        key: const ValueKey('cargando'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: const [
          Esqueleto.fila(),
          SizedBox(height: 12),
          Esqueleto.fila(),
          SizedBox(height: 12),
          Esqueleto.fila(),
        ],
      );
    } else if (l.datos.isEmpty && l.origen == OrigenDato.nada) {
      cuerpo = ListView(key: const ValueKey('error'), children: [
        ErrorAdmin(
          mensaje: 'No pudimos traer las propuestas de WhatsApp y no hay copia en este teléfono.',
          alReintentar: _traer,
        ),
      ]);
    } else {
      cuerpo = _Lista(key: const ValueKey('lista'), lote: l);
    }
    return TirarActualizar(
      alActualizar: _traer,
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context) ? const Duration(milliseconds: 1) : Zm.medio,
        switchInCurve: Zm.entrar,
        child: cuerpo,
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({super.key, required this.lote});
  final Lote<List<PropuestaWhatsapp>> lote;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final lista = lote.datos;
    return LayoutBuilder(builder: (context, caja) {
      final ancho = caja.maxWidth >= 900;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              Semantics(header: true, child: Text('Propuestas por WhatsApp', style: tt.titleLarge?.copyWith(color: Cra.dorado))),
              const SizedBox(height: 4),
              Text(
                'Lo que la gente propone con «💡 Proponer» en el WhatsApp de Zanky. Mantén presionada una para verla entera.',
                style: tt.bodySmall,
              ),
              const SizedBox(height: 12),
              if (lote.sinSenal) _FranjaCopia(cuando: lote.cuando),
              if (lista.isEmpty)
                const VacioAdmin(
                  titulo: 'Aún no hay propuestas por WhatsApp',
                  detalle: 'Cuando alguien proponga una siembra, una limpieza o un recorrido por WhatsApp, aparecerá aquí.',
                  animo: Animo.curioso,
                )
              else ...[
                Text('${lista.length} ${lista.length == 1 ? 'propuesta' : 'propuestas'}',
                    style: tt.labelLarge?.copyWith(color: Cra.textoSuave)),
                const SizedBox(height: 8),
                for (final p in lista) ...[
                  _FilaPropuesta(p: p, ancha: ancho),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _FranjaCopia extends StatelessWidget {
  const _FranjaCopia({this.cuando});
  final DateTime? cuando;

  @override
  Widget build(BuildContext context) {
    final c = cuando;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('propuestas-sin-senal'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Cra.superficie,
          borderRadius: BorderRadius.circular(Zr.m),
          border: Border.all(color: Cra.borde),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: Cra.dorado),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              c == null ? 'Sin señal: ves la última copia guardada.' : 'Sin señal: ves la copia de ${cuandoTexto(c)}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ]),
      ),
    );
  }
}

String _lugar(PropuestaWhatsapp p) =>
    p.zonaNombre ?? (p.dentroManglar ? 'En el manglar, sin zona asignada' : 'Fuera de la franja del manglar');

Future<void> _copiar(BuildContext context, String texto, String aviso) async {
  await Clipboard.setData(ClipboardData(text: texto));
  vibrar(Vibracion.ligera);
  if (!context.mounted) return;
  anunciar(context, aviso);
  avisar(context, aviso, tipo: TipoAviso.exito);
}

Future<void> _verDetalle(BuildContext context, PropuestaWhatsapp p) => mostrarHojaZ<void>(
      context,
      nombre: 'propuesta_whatsapp',
      contenido: (_) => _Detalle(p: p),
    );

class _FilaPropuesta extends StatelessWidget {
  const _FilaPropuesta({required this.p, required this.ancha});
  final PropuestaWhatsapp p;
  final bool ancha;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final ver = AccionGesto(etiqueta: 'Ver completa', icono: Icons.open_in_full_rounded, alEjecutar: () => _verDetalle(context, p));
    final copiarCodigo = AccionGesto(
      etiqueta: 'Copiar código',
      icono: Icons.tag_rounded,
      color: Cra.azul,
      alEjecutar: () => _copiar(context, p.codigo, 'Código ${p.codigo} copiado'),
    );
    final copiarTexto = AccionGesto(
      etiqueta: 'Copiar texto',
      icono: Icons.content_copy_rounded,
      color: Cra.hoja,
      alEjecutar: () => _copiar(context, '${p.titulo}\n${p.descripcion}\n${_lugar(p)}', 'Propuesta copiada'),
    );
    final tarjeta = Semantics(
      container: true,
      label: '${p.titulo}. Propone: ${p.proponenteNombre}. ${p.descripcion}. ${_lugar(p)}. ${cuandoTexto(p.creadaEn)}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Cra.superficie,
            borderRadius: BorderRadius.circular(Zr.l),
            border: Border.all(color: Cra.borde),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Cra.superficieAlta, borderRadius: BorderRadius.circular(Zr.m)),
              child: Text(p.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.titulo, style: tt.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Propone: ${p.proponenteNombre}', style: tt.bodySmall?.copyWith(color: Cra.dorado)),
                const SizedBox(height: 4),
                Text(p.descripcion, style: tt.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(spacing: 10, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  _Dato(icono: Icons.place_rounded, texto: _lugar(p)),
                  _Dato(icono: Icons.schedule_rounded, texto: cuandoTexto(p.creadaEn)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
    return MenuMantenido(
      key: ValueKey('propuesta-${p.id}'),
      etiqueta: p.titulo,
      alTocar: () => _verDetalle(context, p),
      vistaPrevia: (_) => _Detalle(p: p, enVistaPrevia: true),
      acciones: [ver, copiarCodigo, copiarTexto],
      child: FilaDeslizable(
        radio: BorderRadius.circular(Zr.l),
        accionesInicio: [copiarTexto],
        accionesFin: [copiarCodigo],
        hijo: tarjeta,
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 14, color: Cra.textoSuave),
        const SizedBox(width: 4),
        Flexible(child: Text(texto, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Cra.textoSuave))),
      ]);
}

/// La propuesta entera: en la vista previa al mantener presionado y en la hoja al tocar.
class _Detalle extends StatelessWidget {
  const _Detalle({required this.p, this.enVistaPrevia = false});
  final PropuestaWhatsapp p;
  final bool enVistaPrevia;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final contenido = Column(
      key: Key(enVistaPrevia ? 'propuesta-vista-previa' : 'propuesta-detalle'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(p.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(child: Text(p.titulo, style: tt.titleMedium)),
        ]),
        const SizedBox(height: 10),
        Text(p.descripcion, style: tt.bodyLarge),
        const SizedBox(height: 12),
        _Linea('Quién propone', p.proponenteNombre),
        _Linea('Tipo', p.tipoNombre),
        _Linea('Dónde', _lugar(p)),
        _Linea('Punto', '${p.punto.latitude.toStringAsFixed(4)}, ${p.punto.longitude.toStringAsFixed(4)}'),
        _Linea('Cuándo', cuandoTexto(p.creadaEn)),
        _Linea('Canal', 'WhatsApp'),
        if (!enVistaPrevia) ...[
          const SizedBox(height: 16),
          Presionable(
            etiqueta: 'Copiar código ${p.codigo}',
            onTap: () => _copiar(context, p.codigo, 'Código ${p.codigo} copiado'),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Cra.dorado, borderRadius: BorderRadius.circular(Zr.m)),
              child: Text('Copiar ${p.codigo}', style: tt.titleSmall?.copyWith(color: Cra.azul)),
            ),
          ),
        ],
      ],
    );
    if (!enVistaPrevia) return contenido;
    return Container(color: Cra.superficie, padding: const EdgeInsets.all(16), child: contenido);
  }
}

class _Linea extends StatelessWidget {
  const _Linea(this.titulo, this.valor);
  final String titulo, valor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(titulo, style: tt.labelMedium?.copyWith(color: Cra.textoSuave))),
        Expanded(child: Text(valor, style: tt.bodyMedium)),
      ]),
    );
  }
}
