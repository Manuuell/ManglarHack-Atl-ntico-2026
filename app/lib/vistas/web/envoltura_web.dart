import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../nucleo/tema.dart';
import 'entrada_qr.dart';
import 'panel_presentacion.dart';

/// Envuelve toda la app cuando corre en el navegador (el visitante que llegó por el QR de un letrero).
///
/// - Teléfono (< 600 px): la app a pantalla completa, igual que en la tienda.
/// - Tableta (600-900 px): la app en una columna de teléfono centrada, sin panel.
/// - Escritorio (> 900 px): columna de teléfono + panel de presentación a los lados (QR para abrirla en el teléfono).
///
/// Fuera de la web no hace nada: devuelve el hijo tal cual.
class EnvolturaWeb extends StatefulWidget {
  const EnvolturaWeb({super.key, required this.child});
  final Widget child;

  /// Ancho de la columna de teléfono.
  static const anchoTelefono = 420.0;
  static const _topeTelefono = 600.0;
  static const _topeEscritorio = 900.0;
  static const _topeDosPaneles = 1200.0;

  @override
  State<EnvolturaWeb> createState() => _EnvolturaWebState();
}

class _EnvolturaWebState extends State<EnvolturaWeb> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) registrarEntradaQr(); // ?zona=… / ?origen=qr → entradaQr
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return widget.child;
    return LayoutBuilder(builder: (context, c) {
      final ancho = c.maxWidth;
      if (ancho < EnvolturaWeb._topeTelefono) return widget.child;
      final panel = ancho > EnvolturaWeb._topeEscritorio;
      final dos = ancho >= EnvolturaWeb._topeDosPaneles;
      // En ventanas bajas el teléfono ocupa todo el alto, sin margen ni sombra de sobra.
      final margen = c.maxHeight >= 640 ? 24.0 : 0.0;
      final alto = (c.maxHeight - margen * 2).clamp(0.0, 900.0);
      final telefono = _MarcoTelefono(alto: alto, redondeo: margen > 0, child: widget.child);
      return Material(
        color: Zc.raiz,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F6B6F), Color(0xFF0A3F42)],
            ),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: IgnorePointer(child: _FondoOlas())),
              Center(
                child: panel
                    ? _FilaEscritorio(dos: dos, ancho: ancho, telefono: telefono)
                    : telefono,
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _FilaEscritorio extends StatelessWidget {
  const _FilaEscritorio({required this.dos, required this.ancho, required this.telefono});
  final bool dos;
  final double ancho;
  final Widget telefono;

  @override
  Widget build(BuildContext context) {
    const hueco = 40.0;
    final lado = ((ancho - EnvolturaWeb.anchoTelefono - hueco * 2 - 48) / (dos ? 2 : 1)).clamp(260.0, 420.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: lado,
          child: PanelPresentacion(parte: dos ? PartePanel.izquierda : PartePanel.todo),
        ),
        const SizedBox(width: hueco),
        telefono,
        if (dos) ...[
          const SizedBox(width: hueco),
          SizedBox(width: lado, child: const PanelPresentacion(parte: PartePanel.derecha)),
        ],
      ],
    );
  }
}

/// La app dentro de una columna de teléfono: esquinas redondeadas, borde fino y sombra.
class _MarcoTelefono extends StatelessWidget {
  const _MarcoTelefono({required this.alto, required this.redondeo, required this.child});
  final double alto;
  final bool redondeo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final radio = redondeo ? 38.0 : 0.0;
    return Container(
      width: EnvolturaWeb.anchoTelefono,
      height: alto,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radio),
        border: redondeo ? Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.5) : null,
        boxShadow: redondeo
            ? const [
                BoxShadow(color: Color(0x66000000), blurRadius: 70, offset: Offset(0, 30)),
                BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4)),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radio),
        // Dentro de la columna, la app se cree un teléfono: ancho y alto de la columna, sin muescas.
        child: MediaQuery(
          data: mq.copyWith(
            size: Size(EnvolturaWeb.anchoTelefono, alto),
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Olas suaves de fondo (estáticas: no cuestan nada por cuadro).
class _FondoOlas extends StatelessWidget {
  const _FondoOlas();
  @override
  Widget build(BuildContext context) => const RepaintBoundary(child: CustomPaint(painter: _PintorOlas()));
}

class _PintorOlas extends CustomPainter {
  const _PintorOlas();
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.72 + i * 0.1);
      final p = Path()..moveTo(0, size.height)..lineTo(0, y);
      for (var x = 0.0; x <= size.width; x += 12) {
        p.lineTo(x, y + 14 * (i + 1) * 0.6 * math.sin(x / 140 + i * 1.7));
      }
      p
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(p, Paint()..color = Zc.cienaga.withValues(alpha: 0.07 + i * 0.04));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
