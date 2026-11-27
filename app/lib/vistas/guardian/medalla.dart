import 'package:flutter/material.dart';

import '../../datos/guardian.dart';
import '../../nucleo/tema.dart';

/// La insignia dibujada: a color con su ícono si está ganada; si no, la silueta gris del
/// mismo hueco con un candadito (nunca un «?»).
class Medalla extends StatelessWidget {
  const Medalla({super.key, required this.insignia, required this.ganada, this.tamano = 64});
  final Insignia insignia;
  final bool ganada;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final c = insignia.color;
    final disco = ganada
        ? Container(
            width: tamano,
            height: tamano,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.5),
                colors: [Color.lerp(c, Colors.white, 0.28)!, c],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: tamano > 40 ? 2 : 1),
              boxShadow: tamano > 40
                  ? [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))]
                  : null,
            ),
            child: Icon(insignia.icono, color: Colors.white, size: tamano * 0.5),
          )
        : Container(
            width: tamano,
            height: tamano,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Zc.linea.withValues(alpha: 0.55),
              border: Border.all(color: Zc.linea, width: tamano > 40 ? 2 : 1),
            ),
            child: Icon(insignia.icono, color: Zc.textoTenue.withValues(alpha: 0.6), size: tamano * 0.5),
          );
    if (ganada || tamano <= 40) return disco;
    return SizedBox(
      width: tamano,
      height: tamano,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          disco,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Zc.arena, shape: BoxShape.circle),
              child: const Icon(Icons.lock_rounded, size: 13, color: Zc.textoSuave),
            ),
          ),
        ],
      ),
    );
  }
}
