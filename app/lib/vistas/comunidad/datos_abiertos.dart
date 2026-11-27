import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../nucleo/identidad.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/haptica.dart';
import '../../nucleo/kit/spinner.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../../nucleo/web/descarga.dart' as descarga;

/// Un formato de los datos abiertos: extensión, nombre visible y tipo MIME.
class FormatoAbierto {
  const FormatoAbierto(this.ext, this.mime);
  final String ext;
  final String mime;
  String get nombre => ext.toUpperCase();
  String get archivo => 'reportes-zanky.$ext';
}

const formatosAbiertos = [
  FormatoAbierto('geojson', 'application/geo+json'),
  FormatoAbierto('csv', 'text/csv'),
  FormatoAbierto('kml', 'application/vnd.google-earth.kml+xml'),
];

/// Trae el archivo (las pruebas lo cambian por uno sin red).
Future<Uint8List> Function(Uri url) traerDatoAbierto = (url) async {
  final r = await http.get(url).timeout(const Duration(seconds: 20));
  if (r.statusCode != 200) throw StateError('HTTP ${r.statusCode}');
  return r.bodyBytes;
};

/// Entrega el archivo: descarga en la web, compartir en el teléfono (las pruebas lo cambian).
Future<void> Function(Uint8List bytes, FormatoAbierto f) entregarDatoAbierto =
    (bytes, f) => descarga.guardarArchivo(bytes, nombre: f.archivo, mime: f.mime);

/// «Datos abiertos»: cada formato se descarga (web) o se comparte como archivo (teléfono), y al
/// lado queda el botón para copiar el enlace (para pegarlo en QGIS o en una hoja de cálculo).
class DatosAbiertos extends StatelessWidget {
  const DatosAbiertos({super.key, required this.base});
  final String base;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final verbo = descarga.descargaDirecta ? 'descargarlo' : 'guardarlo o compartirlo';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Cra.azul, borderRadius: BorderRadius.circular(Zr.m)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('DATOS ABIERTOS', style: tt.seccion.copyWith(color: Cra.dorado)),
          const SizedBox(height: 4),
          Text('Los reportes de la comunidad, libres (CC BY 4.0)',
              style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Sin nombres, fotos ni descripciones; coordenadas a ~110 m. Toca un formato para $verbo; '
              'el ícono de al lado copia su enlace.',
              style: tt.bodySmall?.copyWith(color: Cra.textoSuave)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in formatosAbiertos) _Formato(formato: f, url: Uri.parse('$base/datos-abiertos/reportes.${f.ext}')),
          ]),
        ]),
      ),
    );
  }
}

class _Formato extends StatefulWidget {
  const _Formato({required this.formato, required this.url});
  final FormatoAbierto formato;
  final Uri url;

  @override
  State<_Formato> createState() => _FormatoState();
}

class _FormatoState extends State<_Formato> {
  bool _bajando = false;

  Future<void> _descargar() async {
    if (_bajando) return;
    setState(() => _bajando = true);
    final f = widget.formato;
    try {
      final bytes = await traerDatoAbierto(widget.url);
      await entregarDatoAbierto(bytes, f);
      vibrarExito();
      if (mounted && descarga.descargaDirecta) avisar(context, 'Descargaste ${f.archivo}', tipo: TipoAviso.exito);
    } catch (_) {
      if (mounted) {
        avisar(
          context,
          'No pude traer el ${f.nombre}: parece que no hay señal. Copia el enlace y ábrelo cuando vuelva.',
          tipo: TipoAviso.error,
          accion: AccionAviso('Copiar enlace', _copiar),
        );
      }
    } finally {
      if (mounted) setState(() => _bajando = false);
    }
  }

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.url.toString()));
    vibrar(Vibracion.ligera);
    if (mounted) avisar(context, 'Enlace ${widget.formato.nombre} copiado');
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final f = widget.formato;
    final verbo = descarga.descargaDirecta ? 'Descargar' : 'Guardar o compartir';
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Cra.borde), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Presionable(
          key: ValueKey('descargar-${f.ext}'),
          etiqueta: '$verbo ${f.nombre}',
          onTap: _descargar,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.only(left: 14, right: 10),
            alignment: Alignment.center,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox.square(
                dimension: 18,
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 160),
                  child: _bajando
                      ? const SpinnerZ(key: ValueKey('girando'), tamano: 16, grosor: 2)
                      : Icon(
                          descarga.descargaDirecta ? Icons.download_rounded : Icons.ios_share_rounded,
                          key: const ValueKey('icono'),
                          size: 18,
                          color: Cra.dorado,
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Text(f.nombre, style: tt.labelLarge?.copyWith(color: Colors.white)),
            ]),
          ),
        ),
        Container(width: 1, height: 22, color: Cra.borde),
        Presionable(
          key: ValueKey('copiar-${f.ext}'),
          etiqueta: 'Copiar enlace ${f.nombre}',
          onTap: _copiar,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.link_rounded, size: 18, color: Cra.textoSuave),
          ),
        ),
      ]),
    );
  }
}
