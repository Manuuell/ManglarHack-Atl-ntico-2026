/// Estado vacío con Zanky: la mascota brota con resorte, el título y el texto
/// entran escalonados y la acción (si hay) llega al final.
///
/// ```dart
/// EstadoVacio(
///   titulo: 'Nada pendiente',
///   texto: 'Todo lo que reportaste ya fue revisado.',
///   animo: Animo.feliz,
///   textoAccion: 'Hacer un reporte',
///   alAccion: () => abrirReporte(context),
/// )
/// ```
///
/// Con «reducir movimiento» (heredado de `EntradaEscalonada`) todo aparece ya
/// puesto. Zanky mismo sigue respirando: es la mascota, no una animación de
/// entrada.
library;

import 'package:flutter/material.dart';

import '../../vistas/comun/burbuja.dart';
import '../../vistas/comun/zanky_mascota.dart';
import '../base/entrada_escalonada.dart';
import '../presionable.dart';

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.titulo,
    required this.texto,
    this.animo = Animo.curioso,
    this.tamanoZanky = 150,
    this.conBurbuja = false,
    this.textoAccion,
    this.iconoAccion,
    this.alAccion,
    this.relleno = const EdgeInsets.fromLTRB(28, 8, 28, 110),
  });

  final String titulo;
  final String texto;
  final Animo animo;
  final double tamanoZanky;

  /// `true`: el texto sale en una burbuja de Zanky en vez de debajo del título.
  final bool conBurbuja;
  final String? textoAccion;
  final IconData? iconoAccion;
  final VoidCallback? alAccion;
  final EdgeInsets relleno;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: relleno,
      child: Center(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EntradaEscalonada.escala(index: 0, child: ZankyMascota(tamano: tamanoZanky, animo: animo)),
              const SizedBox(height: 16),
              EntradaEscalonada(
                index: 1,
                child: Semantics(
                  header: true,
                  child: Text(titulo, style: tt.titleLarge, textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(height: 8),
              EntradaEscalonada(
                index: 2,
                child: conBurbuja
                    ? BurbujaZanky(texto: texto)
                    : Text(texto, style: tt.bodyMedium, textAlign: TextAlign.center),
              ),
              if (textoAccion != null && alAccion != null) ...[
                const SizedBox(height: 22),
                EntradaEscalonada(
                  index: 3,
                  child: BotonZ(texto: textoAccion!, icono: iconoAccion, onTap: alAccion),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
