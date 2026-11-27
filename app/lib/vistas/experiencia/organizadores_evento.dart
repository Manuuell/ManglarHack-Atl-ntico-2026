import 'package:flutter/material.dart';

import '../../datos/experiencia/entrada_evento.dart';
import '../../datos/experiencia/nfc_evento.dart';
import '../../nucleo/tema.dart';

/// Herramienta opcional de la jornada; la grabación requiere un toque del organizador.
class OrganizadoresEvento extends StatefulWidget {
  const OrganizadoresEvento({super.key, required this.codigo, this.grabador});

  final String codigo;
  final GrabadorNfc? grabador;

  @override
  State<OrganizadoresEvento> createState() => _OrganizadoresEventoState();
}

class _OrganizadoresEventoState extends State<OrganizadoresEvento> {
  late final GrabadorNfc _grabador = widget.grabador ?? crearGrabadorNfc();
  bool _abierto = false;
  bool _grabando = false;
  String? _resultado;

  Future<void> _grabar() async {
    setState(() {
      _grabando = true;
      _resultado = null;
    });
    try {
      await _grabador.grabar(enlaceAsistenciaEvento(widget.codigo));
      if (mounted) {
        setState(
          () => _resultado =
              'Etiqueta grabada. Acércala a otro teléfono para comprobarla.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _resultado =
              'No se grabó la etiqueta. Comprueba el permiso, que NFC esté activado y que la etiqueta permita escritura.',
        );
      }
    } finally {
      if (mounted) setState(() => _grabando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _abierto = !_abierto),
          icon: const Icon(Icons.settings_outlined, size: 18),
          label: const Text('Para organizadores'),
        ),
        if (_abierto)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Etiqueta NFC del evento', style: tt.titleSmall),
                const SizedBox(height: 6),
                Text(
                  'La etiqueta abrirá este evento directamente en el registro de asistencia.',
                  style: tt.bodySmall,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  enlaceAsistenciaEvento(widget.codigo),
                  style: tt.bodySmall,
                ),
                const SizedBox(height: 10),
                if (_grabador.disponible)
                  FilledButton.icon(
                    onPressed: _grabando ? null : _grabar,
                    icon: const Icon(Icons.nfc_rounded),
                    label: Text(
                      _grabando
                          ? 'Acerca la etiqueta…'
                          : 'Grabar etiqueta NFC del evento',
                    ),
                  )
                else
                  Text(
                    'Este dispositivo no puede grabar NFC desde la web. En iPhone o PC usa una app de escritura NFC; cualquier teléfono compatible puede abrir el enlace al acercarlo a la etiqueta.',
                    style: tt.bodySmall?.copyWith(color: Zc.textoSuave),
                  ),
                if (_resultado != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_resultado!, style: tt.bodySmall),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
