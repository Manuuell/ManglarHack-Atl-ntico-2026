import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../datos/estado.dart';
import '../../datos/reporte.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/burbuja.dart';
import '../comun/comunes.dart';
import '../comun/zanky_mascota.dart';
import '../raiz.dart';

/// Confirmación. Dice la verdad sobre dónde está el reporte (en el teléfono, enviándose
/// o ya en la CRA) y se actualiza sola cuando cambia.
class ReporteEnviado extends StatefulWidget {
  const ReporteEnviado({super.key, required this.reporteId});
  final String reporteId;

  @override
  State<ReporteEnviado> createState() => _ReporteEnviadoState();
}

class _ReporteEnviadoState extends State<ReporteEnviado> with SingleTickerProviderStateMixin {
  late final AnimationController _check =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      _check.forward();
      // El golpe de éxito llega cuando el trazo se completa, no antes.
      Future.delayed(const Duration(milliseconds: 380), () => HapticFeedback.mediumImpact());
    });
  }

  @override
  void dispose() {
    _check.dispose();
    super.dispose();
  }

  void _verMisReportes() {
    final nav = Navigator.of(context);
    nav.pop();
    // La raíz queda debajo: se cambia a «Mis reportes».
    Raiz.irA(nav.context, 2);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final estado = Zanky.de(context);
    final r = estado.reportes.where((x) => x.id == widget.reporteId).firstOrNull;
    if (r == null) return const Scaffold(backgroundColor: Zc.arena);
    final (titulo, detalle, color) = switch (r.envio) {
      Envio.enviado => ('¡Llegó a la CRA!', 'Te aviso cuando lo revisen. Puedes seguirlo en «Mis reportes».', Zc.hoja),
      Envio.enviando => ('Enviando…', 'Un momento: lo estoy subiendo con la foto.', Zc.cienaga),
      _ when !estado.servidor.configurado => (
          'Guardado en tu teléfono',
          'Modo demostración: en la versión conectada se envía solo a la CRA.',
          Zc.textoSuave,
        ),
      _ => (
          'Guardado en tu teléfono',
          'No hay señal ahora. Lo envío solo apenas vuelva, con la hora en que lo viste.',
          Zc.fango,
        ),
    };
    final abajo = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Zc.arena,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                children: [
                  Center(
                    child: SizedBox(
                      width: 108,
                      height: 108,
                      child: AnimatedBuilder(
                        animation: _check,
                        builder: (_, _) => CustomPaint(painter: _Check(_check.value, Zc.hoja)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: Zm.medio,
                    child: Text(titulo, key: ValueKey(titulo), textAlign: TextAlign.center, style: tt.headlineMedium),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: Zm.medio,
                    child: Text(detalle,
                        key: ValueKey(detalle), textAlign: TextAlign.center, style: tt.bodyLarge?.copyWith(color: color)),
                  ),
                  const SizedBox(height: 22),
                  // Número de caso: grande, copiable, para decirlo por teléfono o WhatsApp.
                  Presionable(
                    etiqueta: 'Número de caso ${r.caso}. Toca para copiar',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: r.caso));
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text('Copiado: ${r.caso}')));
                    },
                    child: TarjetaZ(
                      child: Column(
                        children: [
                          Text('NÚMERO DE CASO', style: tt.labelSmall),
                          const SizedBox(height: 4),
                          Text(r.caso,
                              style: tt.displaySmall?.copyWith(letterSpacing: 2, fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ])),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              PildoraPrioridad(r.prioridad),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration:
                                    BoxDecoration(color: Zc.cienagaClara, borderRadius: BorderRadius.circular(99)),
                                child: Text(r.zonaNombre, style: tt.labelMedium?.copyWith(color: Zc.cienaga)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ChipEstado(r),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const ZankyMascota(tamano: 86, animo: Animo.celebrando),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BurbujaZanky(
                          texto: r.anonimo
                              ? '¡Gracias! Lo enviaste en anónimo: nadie sabrá que fuiste tú.'
                              : '¡Gracias, ${estado.perfil?.nombre.trim().split(' ').first.isNotEmpty == true ? estado.perfil!.nombre.trim().split(' ').first : 'guardián'}! Si la CRA lo verifica, sumas puntos.',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, abajo + 16),
              child: Column(
                children: [
                  SizedBox(width: double.infinity, child: BotonZ(texto: 'Ver mis reportes', onTap: _verMisReportes)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: BotonZ(texto: 'Listo', secundario: true, onTap: () => Navigator.of(context).pop()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Disco que brota y un check que se dibuja (el trazo empieza cuando el disco ya creció).
class _Check extends CustomPainter {
  _Check(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final disco = Curves.easeOutBack.transform((t / 0.45).clamp(0.0, 1.0));
    canvas.drawCircle(c, r * disco, Paint()..color = color.withValues(alpha: 0.14));
    canvas.drawCircle(c, r * 0.74 * disco, Paint()..color = color);
    // Anillo que se expande y se desvanece.
    final anillo = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
    if (anillo > 0 && anillo < 1) {
      canvas.drawCircle(
        c,
        r * (0.74 + 0.3 * anillo),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color.withValues(alpha: 0.5 * (1 - anillo)),
      );
    }
    final trazo = Curves.easeInOutCubic.transform(((t - 0.28) / 0.5).clamp(0.0, 1.0));
    if (trazo <= 0) return;
    final p = Path()
      ..moveTo(c.dx - r * 0.3, c.dy + r * 0.02)
      ..lineTo(c.dx - r * 0.08, c.dy + r * 0.24)
      ..lineTo(c.dx + r * 0.34, c.dy - r * 0.22);
    final metrica = p.computeMetrics().first;
    canvas.drawPath(
      metrica.extractPath(0, metrica.length * trazo),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(4, r * 0.11)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_Check o) => o.t != t;
}
