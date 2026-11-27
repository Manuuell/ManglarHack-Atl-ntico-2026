import 'package:flutter/material.dart';

import '../../nucleo/tema.dart';
import '../web/abrir_enlace.dart';
import 'modelo_contenido.dart';
import 'repositorio_contenido.dart';

/// El mismo pintor se usa en la vista previa y en el contenido público.
class PintarBloques extends StatelessWidget {
  const PintarBloques({super.key, required this.bloques, this.previa = false});
  final List<Bloque> bloques;
  final bool previa;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [for (final b in bloques.where((x) => !x.oculto)) _pintar(context, b)],
  );

  Widget _pintar(BuildContext context, Bloque b) {
    final t = Theme.of(context).textTheme;
    switch (b.tipo) {
      case 'titulo': return Padding(padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(b.texto, style: t.titleLarge));
      case 'texto': return Padding(padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(b.texto, style: t.bodyMedium));
      case 'lista': return Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final linea in b.texto.split('\n').where((x) => x.trim().isNotEmpty))
          Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('• $linea'))]);
      case 'imagen_url':
        final uri = Uri.tryParse(b.url);
        return uri?.scheme == 'https' ? Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(borderRadius: BorderRadius.circular(Zr.m),
            child: Image.network(b.url, height: 170, fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(height: 80,
                child: Center(child: Text('Imagen no disponible')))))) : const SizedBox.shrink();
      case 'boton': return Padding(padding: const EdgeInsets.symmetric(vertical: 8),
        child: FilledButton(onPressed: previa || Uri.tryParse(b.url)?.scheme != 'https'
          ? null : () => abrirEnlace(b.url), child: Text(b.texto.isEmpty ? 'Abrir' : b.texto)));
      case 'aviso': return Card(color: Zc.solClaro, child: Padding(
        padding: const EdgeInsets.all(14), child: Text(b.texto)));
      default: return const SizedBox.shrink();
    }
  }
}

/// Solo muestra la versión publicada. Si la red falla, usa la última copia publicada.
class BloquesContenido extends StatefulWidget {
  const BloquesContenido({super.key, required this.ambito, this.clave = 'principal', this.repositorio});
  final String ambito, clave;
  final RepositorioContenido? repositorio;
  @override
  State<BloquesContenido> createState() => _BloquesContenidoState();
}

class _BloquesContenidoState extends State<BloquesContenido> {
  late final RepositorioContenido _repo = widget.repositorio ?? RepositorioContenido();
  DocumentoContenido? _documento;
  @override
  void initState() { super.initState(); _cargar(); }
  @override
  void didUpdateWidget(covariant BloquesContenido oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ambito != widget.ambito || oldWidget.clave != widget.clave) {
      _documento = null;
      _cargar();
    }
  }
  Future<void> _cargar() async {
    final clave = widget.clave, ambito = widget.ambito;
    final local = await _repo.local(clave, ambito, publicado: true);
    if (clave != widget.clave || ambito != widget.ambito) return;
    if (mounted && local?.publicado == true) setState(() => _documento = local);
    final remoto = await _repo.cargar(clave, ambito);
    if (mounted && clave == widget.clave && ambito == widget.ambito) setState(() => _documento = remoto);
  }
  @override
  void dispose() { if (widget.repositorio == null) _repo.cerrar(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final d = _documento;
    if (d == null || !d.publicado || d.bloques.where((b) => !b.oculto).isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_repo.demostracion) const Text('Demostración · guardado en este dispositivo',
        style: TextStyle(color: Zc.textoSuave, fontSize: 12)),
      PintarBloques(bloques: d.bloques),
    ]);
  }
}
