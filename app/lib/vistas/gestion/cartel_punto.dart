import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../datos/experiencia/nfc_evento.dart';
import '../../datos/punto/punto_zanky.dart';
import '../../nucleo/kit/boton_estado.dart';
import 'impresion.dart';

class CartelPunto extends StatefulWidget {
  const CartelPunto({super.key, required this.punto, this.grabador, this.demostracion = false});
  final PuntoZanky punto;
  final GrabadorNfc? grabador;
  final bool demostracion;
  @override
  State<CartelPunto> createState() => _CartelPuntoState();
}

class _CartelPuntoState extends State<CartelPunto> {
  late final GrabadorNfc _grabador = widget.grabador ?? crearGrabadorNfc();
  String? _mensaje;
  String? _imagen;

  @override
  void initState() {
    super.initState();
    QrPainter(data: enlacePunto(widget.punto.codigo), version: QrVersions.auto,
      gapless: false).toImageData(600).then((datos) {
        if (mounted && datos != null) setState(() => _imagen = base64Encode(datos.buffer.asUint8List()));
      });
  }

  Future<void> _imprimir() async {
    final imagen = _imagen;
    if (imagen == null) throw StateError('El QR aún se está preparando.');
    imprimirCartel(widget.punto.titulo, widget.punto.codigo, imagen);
  }

  Future<void> _grabar() async {
    try {
      await _grabador.grabar(enlacePunto(widget.punto.codigo));
      if (mounted) setState(() => _mensaje = 'Etiqueta grabada. Compruébala con otro teléfono.');
    } catch (_) {
      if (mounted) setState(() => _mensaje = 'No se grabó la etiqueta. Revisa NFC, permisos y escritura.');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cartel del punto')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      if (widget.demostracion) const Text('DEMOSTRACIÓN · este QR es de ejemplo y no está publicado.'),
      Semantics(header: true, child: Text(widget.punto.titulo, style: Theme.of(context).textTheme.headlineSmall)),
      const SizedBox(height: 16),
      Center(child: Semantics(label: 'Código QR del punto ${widget.punto.codigo}',
        child: QrImageView(data: enlacePunto(widget.punto.codigo), size: 260))),
      const SizedBox(height: 12),
      SelectableText(enlacePunto(widget.punto.codigo), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      if (!widget.demostracion) BotonEstado(texto: 'Compartir enlace', icono: Icons.share_rounded,
        alPresionar: () async { await SharePlus.instance.share(ShareParams(text: enlacePunto(widget.punto.codigo))); }),
      if (!widget.demostracion && puedeImprimirCartel) ...[
        const SizedBox(height: 10),
        BotonEstado(texto: 'Imprimir cartel A4', icono: Icons.print_rounded,
          alPresionar: _imagen == null ? null : _imprimir),
      ],
      const SizedBox(height: 10),
      if (widget.demostracion) const Text('Conecta el servidor y crea un punto real para compartir, imprimir o grabar NFC.')
      else if (_grabador.disponible)
        BotonEstado(texto: 'Grabar etiqueta NFC', icono: Icons.nfc_rounded, alPresionar: _grabar)
      else const Text('Este dispositivo no puede grabar NFC desde la app. Usa el enlace con una app de escritura NFC.'),
      if (_mensaje != null) Semantics(liveRegion: true, child: Text(_mensaje!)),
    ]),
  );
}
