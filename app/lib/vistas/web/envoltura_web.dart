import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../datos/estado.dart';
import '../../datos/experiencia/entrada_evento.dart';
import '../../datos/punto/punto_zanky.dart';
import '../../nucleo/identidad.dart';
import 'entrada_qr.dart';
import 'panel_presentacion.dart';

/// Envuelve toda la app cuando corre en el navegador (el visitante que llegó por el QR de un letrero o un evento).
///
/// - Teléfono (< 600 px): la app a pantalla completa, igual que en la tienda.
/// - Tableta (600-959 px): la app en una columna cómoda a todo el alto, centrada sobre el azul CRA.
/// - Escritorio (>= 960 px): composición de dos columnas, como una app web: a la izquierda la presentación
///   (qué es Zanky y el QR para seguir en el teléfono) y a la derecha la app a todo el alto, sin marco de teléfono.
///   La bienvenida, que ya tiene su propia composición ancha, ocupa la ventana entera.
///
/// Fuera de la web no hace nada: devuelve el hijo tal cual.
class EnvolturaWeb extends StatefulWidget {
  const EnvolturaWeb({super.key, required this.child});
  final Widget child;

  /// Ancho de la columna de la app en tableta (y mínimo en escritorio).
  static const anchoTelefono = 460.0;
  static const _topeTelefono = 600.0;
  static const _topeEscritorio = 960.0;

  /// Ancho de la columna de la app en escritorio: cómodo para leer, sin estirar las tarjetas.
  static double anchoColumna(double ventana) => (ventana * 0.42).clamp(anchoTelefono, 580.0);

  @override
  State<EnvolturaWeb> createState() => _EnvolturaWebState();
}

class _EnvolturaWebState extends State<EnvolturaWeb> {
  /// Se entró por un enlace que abre otra pantalla encima (evento o punto): esa pantalla va en la columna.
  late final bool _entradaDirecta;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) registrarEntradaQr(); // ?zona=… / ?origen=qr → entradaQr
    _entradaDirecta = kIsWeb &&
        (leerEntradaEvento(Uri.base) != null || leerCodigoPunto(Uri.base) != null);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return widget.child;
    final estado = Zanky.de(context);
    return LayoutBuilder(builder: (context, c) {
      final ancho = c.maxWidth;
      if (ancho < EnvolturaWeb._topeTelefono) return widget.child;
      final escritorio = ancho >= EnvolturaWeb._topeEscritorio;
      // La bienvenida (sin perfil) ya sabe repartirse en una ventana ancha: foto a un lado, texto al otro.
      final bienvenida = estado.listo && estado.perfil?.consentimiento == null &&
          !_entradaDirecta && entradaEvento.value == null;
      if (escritorio && bienvenida) return widget.child;
      final anchoApp = escritorio ? EnvolturaWeb.anchoColumna(ancho) : EnvolturaWeb.anchoTelefono;
      final app = _ColumnaApp(ancho: anchoApp, alto: c.maxHeight, child: widget.child);
      return Material(
        color: Cra.hero,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Cra.azul, Cra.hero],
            ),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: IgnorePointer(child: _FondoOlas())),
              if (escritorio)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: PanelPresentacion(parte: PartePanel.todo),
                          ),
                        ),
                      ),
                    ),
                    app,
                    // Margen derecho proporcional: la app no queda pegada al borde en monitores grandes.
                    SizedBox(width: ((ancho - anchoApp) * 0.12).clamp(0.0, 160.0)),
                  ],
                )
              else
                Center(child: app),
            ],
          ),
        ),
      );
    });
  }
}

/// La app en una columna a todo el alto: sin bisel de teléfono, con una sombra suave que la separa del fondo.
class _ColumnaApp extends StatelessWidget {
  const _ColumnaApp({required this.ancho, required this.alto, required this.child});
  final double ancho;
  final double alto;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      width: ancho,
      height: alto,
      decoration: const BoxDecoration(
        boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 40, offset: Offset(0, 0))],
      ),
      child: ClipRect(
        // Dentro de la columna, la app se cree un teléfono ancho: ancho y alto de la columna, sin muescas.
        child: MediaQuery(
          data: mq.copyWith(
            size: Size(ancho, alto),
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
      canvas.drawPath(p, Paint()..color = Cra.agua.withValues(alpha: 0.05 + i * 0.03));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
