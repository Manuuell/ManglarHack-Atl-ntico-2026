import 'package:flutter/material.dart';

import '../../nucleo/identidad.dart';
import '../../nucleo/tema.dart';

/// Puntos indicadores: el activo se alarga como píldora y el alargamiento sigue al
/// desplazamiento del dedo (se interpola con el valor continuo de [controlador]).
///
/// Mientras un punto crece, el vecino encoge lo mismo: el ancho total no cambia y nada
/// salta alrededor.
class PuntosPagina extends StatelessWidget {
  const PuntosPagina({super.key, required this.controlador, required this.total, required this.actual, this.ultimaClara = false});

  /// Fondo oscuro (fotos) en todas las páginas menos la última, que es clara: los colores
  /// pasan de dorado sobre oscuro a hoja sobre arena siguiendo al dedo.
  final bool ultimaClara;

  final PageController controlador;
  final int total;

  /// Página entera más cercana: solo para el lector de pantalla.
  final int actual;

  static const _punto = 8.0, _extra = 18.0, _hueco = 8.0;

  @override
  Widget build(BuildContext context) {
    final ancho = total * _punto + _extra + (total - 1) * _hueco;
    return Semantics(
      label: 'Paso ${actual + 1} de $total',
      excludeSemantics: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(ancho, _punto),
          painter: _PintorPuntos(controlador, total, ultimaClara),
        ),
      ),
    );
  }
}

class _PintorPuntos extends CustomPainter {
  _PintorPuntos(this.controlador, this.total, this.ultimaClara) : super(repaint: controlador);

  final bool ultimaClara;

  final PageController controlador;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final pagina = controlador.hasClients && controlador.position.haveDimensions
        ? (controlador.page ?? 0.0).clamp(0.0, total - 1.0)
        : 0.0;
    final claro = ultimaClara ? (pagina - (total - 2)).clamp(0.0, 1.0) : 1.0;
    final colorActivo = Color.lerp(Cra.dorado, Zc.hoja, claro)!;
    final colorInactivo = Color.lerp(Cra.blanco.withValues(alpha: 0.45), Zc.textoTenue.withValues(alpha: 0.4), claro)!;
    var x = 0.0;
    for (var i = 0; i < total; i++) {
      final activo = (1 - (pagina - i).abs()).clamp(0.0, 1.0);
      final ancho = PuntosPagina._punto + PuntosPagina._extra * activo;
      final color = Color.lerp(colorInactivo, colorActivo, activo)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, ancho, size.height), Radius.circular(size.height / 2)),
        Paint()..color = color,
      );
      x += ancho + PuntosPagina._hueco;
    }
  }

  @override
  bool shouldRepaint(_PintorPuntos old) => old.controlador != controlador || old.total != total || old.ultimaClara != ultimaClara;
}
