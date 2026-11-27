import 'dart:async';

import 'package:flutter/material.dart';

import '../../datos/tipos.dart';
import '../../nucleo/base/entrada_escalonada.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import 'borrador.dart';

/// Paso 1: ¿qué viste? Ocho tarjetas grandes; al elegir, se marca y pasa sola al
/// siguiente paso (un toque menos, sin perder la confirmación visual).
class PasoTipo extends StatefulWidget {
  const PasoTipo({super.key, required this.borrador, required this.onElegido});
  final Borrador borrador;
  final VoidCallback onElegido;

  @override
  State<PasoTipo> createState() => _PasoTipoState();
}

class _PasoTipoState extends State<PasoTipo> {
  Timer? _avance;

  @override
  void dispose() {
    _avance?.cancel();
    super.dispose();
  }

  void _elegir(TipoAmenaza t) {
    widget.borrador.cambiar(() => widget.borrador.tipo = t);
    _avance?.cancel();
    // Se deja ver el check un instante antes de avanzar.
    _avance = Timer(const Duration(milliseconds: 260), widget.onElegido);
  }

  @override
  Widget build(BuildContext context) {
    final elegido = widget.borrador.tipo;
    // Con letra grande el texto de cada tarjeta crece: la altura fija crece con él.
    final letra = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 148 + 60 * (letra - 1),
      ),
      itemCount: TipoAmenaza.values.length,
      itemBuilder: (context, i) {
        final t = TipoAmenaza.values[i];
        return EntradaEscalonada(
          index: i,
          child: _TarjetaTipo(tipo: t, elegida: t == elegido, onTap: () => _elegir(t)),
        );
      },
    );
  }
}

class _TarjetaTipo extends StatelessWidget {
  const _TarjetaTipo({required this.tipo, required this.elegida, required this.onTap});
  final TipoAmenaza tipo;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Presionable(
      onTap: onTap,
      vibracion: Vibracion.ligera,
      etiqueta: '${tipo.nombre}. ${tipo.ayuda}${elegida ? '. Elegido' : ''}',
      child: AnimatedContainer(
        duration: Zm.corto,
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
        decoration: BoxDecoration(
          color: elegida ? Color.alphaBlend(tipo.color.withValues(alpha: 0.10), Colors.white) : Colors.white,
          borderRadius: BorderRadius.circular(Zr.l),
          border: Border.all(color: elegida ? tipo.color : Zc.linea, width: elegida ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: elegida ? tipo.color.withValues(alpha: 0.22) : const Color(0x0D0B2E24),
              blurRadius: elegida ? 18 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: tipo.color.withValues(alpha: 0.13), shape: BoxShape.circle),
                  child: Icon(tipo.icono, color: tipo.color, size: 24),
                ),
                const Spacer(),
                AnimatedScale(
                  scale: elegida ? 1 : 0,
                  duration: Zm.medio,
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: tipo.color, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(tipo.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleSmall?.copyWith(height: 1.2)),
            const SizedBox(height: 3),
            Text(
              tipo.ayuda,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(fontSize: 11.5, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
