import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../datos/admin/controlador_admin.dart';
import '../../datos/admin/reporte_admin.dart';
import '../../nucleo/base/esqueleto.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/kit/haptica.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/tema.dart';
import '../comun/comunes.dart';
import 'piezas_admin.dart';
import '../../nucleo/kit/icono_amenaza.dart';

/// El reporte completo para decidir: foto grande, datos, mapa y las tres acciones.
class DetalleAdmin extends StatelessWidget {
  const DetalleAdmin({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final c = AdminScope.de(context);
    final r = c.reportes.where((x) => x.id == id).firstOrNull;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
              child: Row(
                children: [
                  BotonIcono(
                    icono: Icons.arrow_back_rounded,
                    etiqueta: 'Volver a la bandeja',
                    alTocar: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Semantics(header: true, child: Text('Reporte', style: tt.titleLarge))),
                ],
              ),
            ),
            Expanded(
              child: r == null
                  ? const VacioAdmin(titulo: 'Este reporte ya no está', detalle: 'Vuelve a la bandeja para ver los demás.')
                  : _Ficha(reporte: r, controlador: c),
            ),
            SafeArea(top: false, child: BarraDeshacer(controlador: c)),
          ],
        ),
      ),
    );
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha({required this.reporte, required this.controlador});
  final ReporteAdmin reporte;
  final ControladorAdmin controlador;

  @override
  Widget build(BuildContext context) {
    final r = reporte;
    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        _FotoAdmin(reporte: r, controlador: controlador),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconoTipo(r.tipo, tamano: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.tipo.nombre, style: tt.titleLarge),
                  const SizedBox(height: 2),
                  Text('${r.zona}${r.municipio.isEmpty ? '' : ' · ${r.municipio}'}', style: tt.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [PildoraPrioridad(r.prioridad), EtiquetaEstado(r.estado)],
        ),
        const SizedBox(height: 16),
        _Datos(reporte: r),
        if (r.descripcion.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _Bloque(titulo: 'Lo que contó quien reportó', texto: r.descripcion),
        ],
        if (r.iaMotivo != null && r.iaMotivo!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _Bloque(titulo: 'Lo que vio el análisis automático', texto: r.iaMotivo!),
        ],
        if (r.notaPublica != null && r.notaPublica!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _Bloque(titulo: 'Mensaje para quien reportó', texto: r.notaPublica!, resaltado: true),
        ],
        const SizedBox(height: 16),
        _MapaAdmin(reporte: r),
        const SizedBox(height: 20),
        if (r.pendiente) _Acciones(reporte: r, controlador: controlador) else _Resuelto(reporte: r),
      ],
    );
  }
}

class _Datos extends StatelessWidget {
  const _Datos({required this.reporte});
  final ReporteAdmin reporte;

  @override
  Widget build(BuildContext context) {
    final r = reporte;
    final dist = r.dentroPoligono
        ? 'Dentro del manglar'
        : (r.distanciaM == null ? 'Sin calcular' : (r.distanciaM! < 1000 ? '${r.distanciaM} m' : '${(r.distanciaM! / 1000).toStringAsFixed(1)} km'));
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Cifra(icono: Icons.flag_rounded, titulo: 'Prioridad CRA', valor: '${r.prioridad} de 5', color: Cra.dePrioridad(r.prioridad)),
        _Cifra(icono: Icons.near_me_rounded, titulo: 'Distancia al manglar', valor: dist),
        _Cifra(icono: Icons.verified_user_rounded, titulo: 'Confianza', valor: '${r.confianza} %', barra: r.confianza / 100),
        _Cifra(icono: Icons.schedule_rounded, titulo: 'Llegó', valor: haceCuanto(r.llegadaEn)),
        _Cifra(icono: Icons.straighten_rounded, titulo: 'Tamaño', valor: r.magnitud.nombre),
        _Cifra(icono: Icons.history_toggle_off_rounded, titulo: 'Cuándo pasó', valor: r.momento.nombre),
        if (r.corroboraciones > 0)
          _Cifra(icono: Icons.groups_rounded, titulo: 'También lo reportaron', valor: '${r.corroboraciones} más'),
        if (r.expediente != null) _Cifra(icono: Icons.gavel_rounded, titulo: 'Expediente', valor: r.expediente!),
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.icono, required this.titulo, required this.valor, this.barra, this.color});
  final IconData icono;
  final String titulo;
  final String valor;
  final double? barra;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final c = color ?? Cra.hoja;
    return Semantics(
      container: true,
      label: '$titulo: $valor',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 150, maxWidth: 260),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Cra.superficie,
          borderRadius: BorderRadius.circular(Zr.m),
          border: Border.all(color: Cra.linea.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, size: 15, color: c),
                const SizedBox(width: 6),
                Flexible(child: Text(titulo, style: tt.labelSmall)),
              ],
            ),
            const SizedBox(height: 4),
            Text(valor, style: tt.titleSmall),
            if (barra != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: barra!.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Cra.arena,
                  color: barra! >= 0.7 ? Cra.hoja : (barra! >= 0.4 ? Cra.sol : Cra.prioridad[4]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.titulo, required this.texto, this.resaltado = false});
  final String titulo;
  final String texto;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: resaltado ? Cra.solClaro : Cra.superficie,
        borderRadius: BorderRadius.circular(Zr.m),
        border: Border.all(color: Cra.linea.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: tt.labelSmall),
          const SizedBox(height: 4),
          Text(texto, style: tt.bodyLarge),
        ],
      ),
    );
  }
}

/// La foto de evidencia: privada, se pide al servidor al abrir el detalle (queda en
/// auditoría) y no antes. Toque para verla a pantalla completa.
class _FotoAdmin extends StatefulWidget {
  const _FotoAdmin({required this.reporte, required this.controlador});
  final ReporteAdmin reporte;
  final ControladorAdmin controlador;

  @override
  State<_FotoAdmin> createState() => _FotoAdminState();
}

class _FotoAdminState extends State<_FotoAdmin> {
  late Future<Uint8List?> _futuro = _pedir();

  Future<Uint8List?> _pedir() => widget.reporte.tieneFoto ? widget.controlador.foto(widget.reporte) : Future.value(null);

  @override
  Widget build(BuildContext context) {
    final r = widget.reporte;
    final demo = widget.controlador.demostracion;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Zr.l),
        child: FutureBuilder<Uint8List?>(
          future: _futuro,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Skeleton(height: double.infinity, borderRadius: BorderRadius.zero);
            }
            if (s.hasError) {
              return _Hueco(
                icono: const Icon(Icons.broken_image_rounded, size: 40, color: Cra.hoja),
                texto: 'No se pudo cargar la foto',
                accion: 'Reintentar',
                alTocar: () => setState(() => _futuro = _pedir()),
              );
            }
            final bytes = s.data;
            if (bytes == null) {
              return _Hueco(
                icono: IconoAmenaza(r.tipo, tamano: 44, color: Cra.hoja),
                texto: !r.tieneFoto
                    ? 'Este reporte no trae foto'
                    : (demo ? 'La demostración no trae fotos' : 'Sin foto disponible'),
              );
            }
            return Presionable(
              escala: 0.99,
              etiqueta: 'Foto de evidencia. Toca para verla grande',
              onTap: () => _verGrande(context, bytes),
              child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
            );
          },
        ),
      ),
    );
  }

  void _verGrande(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, _, _) => Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                Center(child: InteractiveViewer(maxScale: 5, child: Image.memory(bytes))),
                Positioned(
                  top: 4,
                  right: 4,
                  child: BotonIcono(icono: Icons.close_rounded, etiqueta: 'Cerrar foto', alTocar: () => Navigator.of(context).maybePop()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hueco extends StatelessWidget {
  const _Hueco({required this.icono, required this.texto, this.accion, this.alTocar});

  /// El dibujo del hueco: el ícono propio de la amenaza (`IconoAmenaza`) o uno de Material.
  final Widget icono;
  final String texto;
  final String? accion;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      color: Cra.hojaClara,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: icono),
            const SizedBox(height: 8),
            Text(texto, textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: Cra.texto)),
            if (accion != null)
              Presionable(
                etiqueta: accion,
                onTap: alTocar,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(accion!, style: tt.labelLarge?.copyWith(color: Cra.hoja)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mapa chico del punto. Solo se mueve con pellizco: un dedo sigue desplazando la pantalla.
class _MapaAdmin extends StatelessWidget {
  const _MapaAdmin({required this.reporte});
  final ReporteAdmin reporte;

  @override
  Widget build(BuildContext context) {
    final r = reporte;
    return Semantics(
      label: 'Mapa del punto del reporte en ${r.zona}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Zr.l),
        child: SizedBox(
          height: 180,
          child: ExcludeSemantics(
            child: Stack(children: [
              Positioned.fill(
                child: FlutterMap(
              options: MapOptions(
                backgroundColor: Cra.cienagaClara,
                initialCenter: r.punto,
                initialZoom: 15.5,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.pinchMove),
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'co.zanky.app'),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: r.punto,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: r.tipo.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))],
                        ),
                        child: Center(child: IconoAmenaza(r.tipo, tamano: 23, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
              ),
              Positioned(
                right: 6,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(6)),
                  child: Text('© OpenStreetMap', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: Cra.azul)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Resuelto extends StatelessWidget {
  const _Resuelto({required this.reporte});
  final ReporteAdmin reporte;

  @override
  Widget build(BuildContext context) {
    final e = reporte.estado;
    final c = ChipEstado.colorDe(e);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(Zr.m)),
      child: Row(
        children: [
          Icon(ChipEstado.iconoDe(e), color: c),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Ya está ${e.nombre.toLowerCase()}. ${e.explicacion}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Cra.texto)),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ acciones

class _Acciones extends StatelessWidget {
  const _Acciones({required this.reporte, required this.controlador});
  final ReporteAdmin reporte;
  final ControladorAdmin controlador;

  Future<void> _decidir(BuildContext context, AccionAdmin a) async {
    final texto = await mostrarHojaZ<String>(
      context,
      nombre: 'panel_cra/${a.name}',
      contenido: (_) => HojaDecision(accion: a, reporte: reporte),
    );
    if (texto == null || !context.mounted) return;
    vibrarExito();
    await controlador.decidir(a, reporte, texto: texto.isEmpty ? null : texto);
    if (context.mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BotonZ(texto: 'Aprobar', icono: Icons.verified_rounded, onTap: () => _decidir(context, AccionAdmin.aprobar)),
        const SizedBox(height: 10),
        BotonZ(
          texto: 'Pedir más datos',
          icono: Icons.chat_bubble_outline_rounded,
          color: Cra.cienaga,
          secundario: true,
          onTap: () => _decidir(context, AccionAdmin.pedirDatos),
        ),
        const SizedBox(height: 10),
        BotonZ(
          texto: 'Rechazar',
          icono: Icons.do_not_disturb_on_rounded,
          color: Cra.prioridad[5]!,
          secundario: true,
          onTap: () => _decidir(context, AccionAdmin.rechazar),
        ),
      ],
    );
  }
}

/// La hoja que pide confirmar. Rechazar exige el motivo y pedir datos exige el mensaje
/// (los lee quien reportó, hasta 280 letras); aprobar solo confirma.
class HojaDecision extends StatefulWidget {
  const HojaDecision({super.key, required this.accion, required this.reporte});
  final AccionAdmin accion;
  final ReporteAdmin reporte;

  static const motivos = ['Foto de otro lugar', 'No parece el manglar', 'Ya lo reportaron', 'No se pudo confirmar'];
  static const preguntas = ['¿Puedes tomar otra foto más cerca?', '¿Hay maquinaria o personas ahora?', 'Confirma la ubicación en el mapa'];

  @override
  State<HojaDecision> createState() => _HojaDecisionState();
}

class _HojaDecisionState extends State<HojaDecision> {
  final _texto = TextEditingController();
  final _foco = FocusNode();

  AccionAdmin get _a => widget.accion;
  bool get _pideTexto => _a != AccionAdmin.aprobar;
  bool get _valido => !_pideTexto || _texto.text.trim().isNotEmpty;

  @override
  void dispose() {
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!_valido) return;
    vibrar(Vibracion.ligera);
    Navigator.of(context).pop(_texto.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final r = widget.reporte;
    final (titulo, detalle, boton, icono, color) = switch (_a) {
      AccionAdmin.aprobar => (
          '¿Aprobar este reporte?',
          'Pasa a «Verificado» y quien reportó lo verá en su app. Tienes unos segundos para deshacerlo.',
          'Sí, aprobar',
          Icons.verified_rounded,
          Cra.hoja,
        ),
      AccionAdmin.rechazar => (
          '¿Rechazar este reporte?',
          'Quien reportó leerá tu motivo. Escríbelo con amabilidad: casi siempre lo hizo de buena fe.',
          'Rechazar',
          Icons.do_not_disturb_on_rounded,
          Cra.prioridad[5]!,
        ),
      AccionAdmin.pedirDatos => (
          'Pedir más datos',
          'El reporte queda «En verificación» y quien lo envió lee tu mensaje la próxima vez que abra Zanky.',
          'Enviar mensaje',
          Icons.chat_bubble_outline_rounded,
          Cra.cienaga,
        ),
    };
    final sugerencias = _a == AccionAdmin.rechazar ? HojaDecision.motivos : HojaDecision.preguntas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconoTipo(r.tipo, tamano: 40),
            const SizedBox(width: 12),
            Expanded(child: Text(r.tipo.nombre, style: tt.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(header: true, child: Text(titulo, style: tt.titleLarge)),
        const SizedBox(height: 6),
        Text(detalle, style: tt.bodyMedium),
        if (_pideTexto) ...[
          const SizedBox(height: 14),
          CampoAdmin(
            etiqueta: _a == AccionAdmin.rechazar ? 'Motivo' : 'Mensaje para quien reportó',
            controlador: _texto,
            foco: _foco,
            lineas: 2,
            maximo: 280,
            accion: TextInputAction.newline,
            teclado: TextInputType.multiline,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in sugerencias)
                Presionable(
                  etiqueta: 'Usar: $s',
                  onTap: () {
                    _texto.text = s;
                    _texto.selection = TextSelection.collapsed(offset: s.length);
                    setState(() {});
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Cra.superficie,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Cra.linea),
                    ),
                    child: Text(s, style: tt.labelMedium),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        ListenableBuilder(
          listenable: _texto,
          builder: (context, _) => BotonZ(
            texto: boton,
            icono: icono,
            color: color,
            onTap: _valido ? _confirmar : null,
          ),
        ),
        const SizedBox(height: 8),
        Presionable(
          etiqueta: 'Cancelar',
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            child: Text('Cancelar', style: tt.labelLarge?.copyWith(color: Cra.textoSuave)),
          ),
        ),
      ],
    );
  }
}
