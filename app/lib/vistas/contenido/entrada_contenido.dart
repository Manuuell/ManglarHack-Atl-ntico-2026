import 'package:flutter/material.dart';

import '../../datos/admin/controlador_admin.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/presionable.dart';
import 'editor_contenido.dart';
import 'repositorio_contenido.dart';

/// Ámbito válido: `global` o `evento:CODIGO` / `punto:CODIGO` (letras, números, guion).
/// Es lo único que acepta la base; aquí se valida antes para avisar en el momento.
final RegExp _ambitoValido = RegExp(r'^(global|(evento|punto):[A-Za-z0-9_-]{1,100})$');
bool ambitoContenidoValido(String ambito) => _ambitoValido.hasMatch(ambito);

/// Pocos toques: Portada de la app o el evento por su código. Abre el editor
/// con la sesión del panel; quien manda sobre los permisos es la base (RLS).
Future<void> abrirEditorContenido(BuildContext context, ControladorAdmin panel) {
  return mostrarHojaZ<void>(context, nombre: 'editar_contenido',
    contenido: (c) => _HojaContenido(panel: panel, raiz: context));
}

class _HojaContenido extends StatefulWidget {
  const _HojaContenido({required this.panel, required this.raiz});
  final ControladorAdmin panel;
  final BuildContext raiz;
  @override State<_HojaContenido> createState() => _HojaContenidoState();
}

class _HojaContenidoState extends State<_HojaContenido> {
  final _codigo = TextEditingController();
  @override void dispose() { _codigo.dispose(); super.dispose(); }

  void _abrir(String ambito) {
    final raiz = widget.raiz, panel = widget.panel;
    Navigator.of(context).pop();
    Navigator.of(raiz).push(MaterialPageRoute<void>(builder: (_) => EditorContenido(
      ambito: ambito, repositorio: RepositorioContenido(panel: panel))));
  }

  @override Widget build(BuildContext context) {
    final ambito = 'evento:${_codigo.text.trim()}';
    final valido = ambitoContenidoValido(ambito);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Editar contenido', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      BotonZ(texto: 'Portada de la app', icono: Icons.home_rounded, onTap: () => _abrir('global')),
      const SizedBox(height: 16),
      TextField(controller: _codigo, onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: 'Código del evento',
          errorText: _codigo.text.trim().isNotEmpty && !valido ? 'Usa letras, números o guion' : null)),
      const SizedBox(height: 10),
      BotonZ(texto: 'Editar ese evento', icono: Icons.event_rounded, secundario: true,
        onTap: valido ? () => _abrir(ambito) : null),
    ]);
  }
}
