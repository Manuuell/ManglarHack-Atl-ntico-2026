import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../datos/prioridad.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import 'borrador.dart';

/// Paso 3: la foto. La cámara va primero porque una foto tomada en el sitio y en el
/// momento es la evidencia que más pesa (pregunta 2 del reto). La galería se permite,
/// pero se dice que pesa menos.
class PasoEvidencia extends StatefulWidget {
  const PasoEvidencia({super.key, required this.borrador});
  final Borrador borrador;

  @override
  State<PasoEvidencia> createState() => _PasoEvidenciaState();
}

class _PasoEvidenciaState extends State<PasoEvidencia> {
  final _picker = ImagePicker();
  bool _abriendo = false;
  String? _error;

  Future<void> _tomar(ImageSource origen) async {
    if (_abriendo) return;
    setState(() {
      _abriendo = true;
      _error = null;
    });
    try {
      // Reducida en el teléfono: ~200-400 KB sube rápido con poca señal y basta
      // para ver qué pasa. 1600 px conserva detalle de troncos, humo o tubos.
      final f = await _picker.pickImage(
        source: origen,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 78,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      // En la web el navegador decide (cámara o archivo), así que no se puede afirmar
      // que vino de la cámara.
      widget.borrador.ponerFoto(bytes, deCamara: origen == ImageSource.camera && !kIsWeb);
      vibrar(Vibracion.ligera);
    } catch (_) {
      setState(() => _error = origen == ImageSource.camera
          ? 'No pude abrir la cámara. Revisa el permiso de cámara o elige una foto.'
          : 'No pude abrir la galería.');
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final b = widget.borrador;
    return ListenableBuilder(
      listenable: b,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          AnimatedSwitcher(
            duration: Zm.medio,
            switchInCurve: Zm.entrar,
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: c),
            ),
            child: b.foto == null ? _sinFoto(tt) : _conFoto(tt),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: tt.bodySmall?.copyWith(color: Zc.prioridad[5])),
          ],
          const SizedBox(height: 16),
          _MedidorSolidez(solidez: b.solidez),
        ],
      ),
    );
  }

  Widget _sinFoto(TextTheme tt) => Column(
        key: const ValueKey('sin'),
        children: [
          Presionable(
            escala: 0.98,
            vibracion: Vibracion.media,
            etiqueta: 'Tomar foto con la cámara',
            onTap: () => _tomar(ImageSource.camera),
            child: Container(
              height: 230,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Zc.raizSuave, Zc.raiz],
                ),
                borderRadius: BorderRadius.circular(Zr.l),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                    ),
                    child: _abriendo
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          )
                        : const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 14),
                  Text('Tomar foto ahora', style: tt.titleLarge?.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    'Sin acercarte al peligro: desde donde estés seguro.',
                    style: tt.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Presionable(
            etiqueta: 'Elegir una foto de la galería',
            onTap: () => _tomar(ImageSource.gallery),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Zr.m),
                border: Border.all(color: Zc.linea),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_library_outlined, size: 19, color: Zc.textoSuave),
                  const SizedBox(width: 8),
                  Flexible(child: Text('Elegir de la galería', maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelLarge)),
                  const SizedBox(width: 6),
                  Flexible(child: Text('(pesa menos)', maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall)),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _conFoto(TextTheme tt) {
    final b = widget.borrador;
    return Column(
      key: const ValueKey('con'),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Zr.l),
          child: Stack(
            children: [
              Image.memory(
                b.foto!,
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: 1000,
              ),
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(b.fotoDeCamara ? Icons.verified_rounded : Icons.photo_library_outlined,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(b.fotoDeCamara ? 'Tomada en el sitio' : 'De la galería',
                        style: tt.labelSmall?.copyWith(color: Colors.white)),
                  ]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: BotonZ(
                texto: 'Tomar otra',
                icono: Icons.photo_camera_rounded,
                secundario: true,
                onTap: () => _tomar(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BotonZ(
                texto: 'Quitar',
                icono: Icons.delete_outline_rounded,
                secundario: true,
                color: Zc.textoSuave,
                onTap: b.quitarFoto,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Cuánto se puede confiar en el reporte antes de que lo revise una persona.
/// Muestra qué falta para subir: enseña a reportar bien sin regañar.
class _MedidorSolidez extends StatelessWidget {
  const _MedidorSolidez({required this.solidez});
  final Solidez solidez;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final v = solidez.valor;
    final color = v >= 75 ? Zc.hoja : (v >= 50 ? Zc.sol : Zc.fango);
    final falta = [for (final p in solidez.partes) if (p.$2 < p.$3) p];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Zr.l)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Solidez del reporte', style: tt.titleSmall)),
              TweenAnimationBuilder<double>(
                tween: Tween(end: v.toDouble()),
                duration: Zm.largo,
                curve: Zm.entrar,
                builder: (_, x, _) => Text('${x.round()}/100', style: tt.titleMedium?.copyWith(color: color)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: v / 100),
              duration: Zm.largo,
              curve: Zm.entrar,
              builder: (_, x, _) => LinearProgressIndicator(
                value: x,
                minHeight: 9,
                color: color,
                backgroundColor: Zc.linea,
              ),
            ),
          ),
          if (falta.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final p in falta.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(children: [
                  const Icon(Icons.add_circle_outline_rounded, size: 15, color: Zc.textoTenue),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${p.$1}: +${p.$3 - p.$2}', style: tt.bodySmall)),
                ]),
              ),
          ],
          const SizedBox(height: 8),
          Text('La decisión final la toma una persona de la CRA o un vigía.',
              style: tt.bodySmall?.copyWith(fontSize: 11.5, color: Zc.textoTenue)),
        ],
      ),
    );
  }
}
