import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../datos/guardian.dart';
import '../../datos/roles.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';
import 'medalla.dart';

const _mesesCortos = [
  'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.', 'jul.', 'ago.', 'sep.', 'oct.', 'nov.', 'dic.', //
];


/// La tarjeta digital del guardián con su botón de compartir.
///
/// Frente: nombre, nivel, colegio y código público. Reverso: QR con el código (sin datos
/// personales), reportes e insignias. Se voltea al tocar (giro 3D con resorte) y el
/// brillo sigue al dedo al arrastrar.
class SeccionTarjeta extends StatelessWidget {
  const SeccionTarjeta({super.key, required this.perfil, required this.progreso});
  final Perfil perfil;
  final Progreso progreso;

  Future<void> _compartir(BuildContext context) async {
    final nivel = progreso.nivel;
    final nombre = perfil.nombre.trim();
    final quien = nombre.isEmpty ? 'Soy guardián del manglar' : 'Soy $nombre, guardián del manglar';
    final v = progreso.validados;
    final logro = v == 0
        ? 'Estoy empezando mi camino'
        : 'Llevo $v ${v == 1 ? 'reporte validado' : 'reportes validados'}';
    final texto = '$quien del Atlántico en Zanky. Nivel ${nivel.numero}: ${nivel.nombre}. $logro.\n'
        'Mi código de guardián: ${perfil.codigo}\n'
        'El manglar nos cuida a todos. Únete a Zanky y reporta tala, quema, relleno o basura cuando la veas.';
    try {
      await SharePlus.instance.share(ShareParams(text: texto, subject: 'Mi tarjeta de guardián del manglar'));
    } catch (_) {
      if (context.mounted) avisar(context, 'No pude abrir el menú de compartir en este teléfono.', tipo: TipoAviso.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          TarjetaGuardian(perfil: perfil, progreso: progreso),
          const SizedBox(height: 10),
          Text('Toca la tarjeta para voltearla · arrastra para ver el brillo',
              textAlign: TextAlign.center, style: tt.bodySmall),
          const SizedBox(height: 14),
          BotonZ(
            texto: 'Compartir mi tarjeta',
            icono: Icons.ios_share_rounded,
            secundario: true,
            onTap: () => _compartir(context),
          ),
        ],
      ),
    );
  }
}

class TarjetaGuardian extends StatefulWidget {
  const TarjetaGuardian({super.key, required this.perfil, required this.progreso});
  final Perfil perfil;
  final Progreso progreso;

  @override
  State<TarjetaGuardian> createState() => _TarjetaGuardianState();
}

class _TarjetaGuardianState extends State<TarjetaGuardian> with TickerProviderStateMixin {
  /// Dónde cae el brillo cuando nadie toca la tarjeta (arriba a la derecha).
  static const _reposo = Offset(0.55, -0.6);

  /// 0 = frente, 1 = reverso. Sin tope: el resorte puede pasarse un pelo.
  late final AnimationController _giro = AnimationController.unbounded(vsync: this);
  late final AnimationController _suelta = AnimationController(vsync: this, duration: Zm.medio);
  final _brillo = ValueNotifier<Offset>(_reposo);
  Offset _desde = _reposo;
  bool _atras = false;

  /// El QR se construye UNA vez (y otra solo si cambia el código): reconstruirlo en cada
  /// cuadro del giro o del arrastre repetía la codificación y las 8 máscaras. Al ser la
  /// misma instancia de widget, Flutter no lo vuelve a construir, y el RepaintBoundary
  /// deja su dibujo en su propia capa mientras la tarjeta gira.
  late Widget _qr = _construirQr(widget.perfil.codigo);

  static Widget _construirQr(String codigo) => RepaintBoundary(
        child: QrImageView(
          // Solo el código público: nada de nombre, cédula ni id interno.
          data: 'zanky:guardian:$codigo',
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Zc.raiz),
          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Zc.raiz),
          semanticsLabel: 'Código QR de la tarjeta $codigo',
        ),
      );

  @override
  void didUpdateWidget(TarjetaGuardian anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.perfil.codigo != widget.perfil.codigo) _qr = _construirQr(widget.perfil.codigo);
  }

  @override
  void initState() {
    super.initState();
    _suelta.addListener(() {
      _brillo.value = Offset.lerp(_desde, _reposo, Curves.easeOutCubic.transform(_suelta.value))!;
    });
  }

  @override
  void dispose() {
    _giro.dispose();
    _suelta.dispose();
    _brillo.dispose();
    super.dispose();
  }

  void _voltear() {
    _atras = !_atras;
    final meta = _atras ? 1.0 : 0.0;
    vibrar(Vibracion.ligera);
    if (context.animationsDisabled) {
      _giro.value = meta;
      return;
    }
    _giro.animateWith(SpringSimulation(AppMotion.resorteFirme, _giro.value, meta, _giro.velocity));
  }

  static double _tope(double v) => v < -1 ? -1 : (v > 1 ? 1 : v);

  void _seguir(Offset local, Size s) {
    _suelta.stop();
    _brillo.value = Offset(_tope(local.dx / s.width * 2 - 1), _tope(local.dy / s.height * 2 - 1));
  }

  void _soltar() {
    _desde = _brillo.value;
    _suelta.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, caja) {
      final w = caja.maxWidth;
      final h = w / 1.586;
      final tam = Size(w, h);
      final sinMovimiento = context.animationsDisabled;
      return Semantics(
        button: true,
        label: 'Tarjeta de guardián de ${widget.perfil.nombreVisible}, código ${widget.perfil.codigo}. '
            'Toca para ${_atras ? 'ver el frente' : 'ver el reverso con tu código QR'}.',
        onTap: _voltear,
        excludeSemantics: true,
        child: RepaintBoundary(
          child: SizedBox(
            width: w,
            height: h,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _voltear,
              onPanStart: (d) => _seguir(d.localPosition, tam),
              onPanUpdate: (d) => _seguir(d.localPosition, tam),
              onPanEnd: (_) => _soltar(),
              onPanCancel: _soltar,
              child: AnimatedBuilder(
                animation: Listenable.merge([_giro, _brillo]),
                builder: (context, _) {
                  final angulo = _giro.value * math.pi;
                  final atras = angulo > math.pi / 2;
                  final b = _brillo.value;
                  final inclinaX = sinMovimiento ? 0.0 : -(b.dy - _reposo.dy) * 0.06;
                  final inclinaY = sinMovimiento ? 0.0 : (b.dx - _reposo.dx) * 0.06;
                  final matriz = Matrix4.identity()
                    ..setEntry(3, 2, 0.0011)
                    ..rotateX(inclinaX)
                    ..rotateY(angulo + inclinaY);
                  // En la segunda mitad del giro se ve el reverso; se le da otra vuelta
                  // para que no salga en espejo.
                  final cara = atras
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(math.pi),
                          child: _Reverso(
                              perfil: widget.perfil, progreso: widget.progreso, ancho: w, brillo: b, qr: _qr),
                        )
                      : _Frente(perfil: widget.perfil, progreso: widget.progreso, ancho: w, brillo: b);
                  return Transform(alignment: Alignment.center, transform: matriz, child: cara);
                },
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Base común de las dos caras: degradado, textura de hojas y raíces, y el brillo.
class _Cara extends StatelessWidget {
  const _Cara({required this.ancho, required this.brillo, required this.degradado, required this.child});
  final double ancho;
  final Offset brillo;
  final List<Color> degradado;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(ancho * 0.06);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radio,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: degradado),
        boxShadow: const [BoxShadow(color: Color(0x400B2E24), blurRadius: 28, offset: Offset(0, 14))],
      ),
      child: ClipRRect(
        borderRadius: radio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const RepaintBoundary(child: CustomPaint(painter: _TexturaManglar())),
            // Aro de luz en el borde, como el canto de una tarjeta de plástico.
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radio,
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
            ),
            MediaQuery.withClampedTextScaling(maxScaleFactor: 1.15, child: child),
            IgnorePointer(child: CustomPaint(painter: _BrilloPainter(brillo))),
          ],
        ),
      ),
    );
  }
}

const _verdeFrente = [Zc.raiz, Zc.raizSuave, Color(0xFF247050)];
const _verdeReverso = [Color(0xFF247050), Zc.raizSuave, Zc.raiz];

class _Frente extends StatelessWidget {
  const _Frente({required this.perfil, required this.progreso, required this.ancho, required this.brillo});
  final Perfil perfil;
  final Progreso progreso;
  final double ancho;
  final Offset brillo;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final nivel = progreso.nivel;
    final blanco = Colors.white;
    final desde = '${_mesesCortos[perfil.creado.month - 1]} ${perfil.creado.year}';
    final colegio = perfil.colegio.trim();
    // Nada se corta con puntos suspensivos: si un texto no cabe, se encoge.
    Widget ajustado(String t, TextStyle? e, {AlignmentGeometry alinea = Alignment.centerLeft}) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alinea,
          child: Text(t, maxLines: 1, softWrap: false, style: e),
        );
    return _Cara(
      ancho: ancho,
      brillo: brillo,
      degradado: _verdeFrente,
      child: Padding(
        padding: EdgeInsets.all(ancho * 0.06),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ajustado('Guardián del manglar del Atlántico',
                            tt.labelMedium?.copyWith(color: blanco.withValues(alpha: 0.82))),
                        ajustado(
                          colegio.isEmpty ? 'Guardián del manglar' : 'Guardián · $colegio',
                          tt.bodySmall?.copyWith(color: blanco.withValues(alpha: 0.92)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RepaintBoundary(child: ZankyMascota(tamano: ancho * 0.15, animo: Animo.feliz)),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                // Como el carné de la universidad: las iniciales en un círculo (o el ícono del rol).
                Container(
                  width: ancho * 0.1,
                  height: ancho * 0.1,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: blanco.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: blanco.withValues(alpha: 0.5)),
                  ),
                  child: inicialesDe(perfil.nombre).isEmpty
                      ? Icon(Icons.eco_rounded, size: ancho * 0.05, color: blanco)
                      : Text(inicialesDe(perfil.nombre),
                          style: tt.labelMedium?.copyWith(color: blanco, fontSize: ancho * 0.04)),
                ),
                SizedBox(width: ancho * 0.03),
                Expanded(
                  child: ajustado(
                    perfil.nombreVisible,
                    tt.titleLarge?.copyWith(
                        color: blanco,
                        fontSize: ancho * 0.07,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        letterSpacing: -0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: blanco.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.eco_rounded, size: 14, color: blanco),
                  const SizedBox(width: 6),
                  Flexible(child: ajustado('Nivel ${nivel.numero} · ${nivel.nombre}', tt.labelMedium?.copyWith(color: blanco))),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ajustado('Desde $desde', tt.bodySmall?.copyWith(color: blanco.withValues(alpha: 0.78))),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: ajustado(
                    perfil.codigo,
                    tt.titleSmall?.copyWith(
                        color: blanco, letterSpacing: 1.2, fontFeatures: const [FontFeature.tabularFigures()]),
                    alinea: Alignment.centerRight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Reverso extends StatelessWidget {
  const _Reverso(
      {required this.perfil, required this.progreso, required this.ancho, required this.brillo, required this.qr});
  final Perfil perfil;
  final Widget qr;
  final Progreso progreso;
  final double ancho;
  final Offset brillo;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final blanco = Colors.white;
    final pad = ancho * 0.06;
    final lado = ancho * 0.36;
    final ganadas = [for (final i in Insignia.todas) if (progreso.insignias.contains(i.id)) i];
    return _Cara(
      ancho: ancho,
      brillo: brillo,
      degradado: _verdeReverso,
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Row(
          children: [
            Container(
              width: lado,
              height: lado,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: qr,
            ),
            SizedBox(width: ancho * 0.05),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(perfil.codigo,
                      style: tt.titleMedium?.copyWith(
                          color: blanco, letterSpacing: 1.4, fontFeatures: const [FontFeature.tabularFigures()])),
                  Text('Guardián del manglar', style: tt.labelSmall?.copyWith(color: blanco.withValues(alpha: 0.82))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Cifra(valor: progreso.enviados, texto: 'enviados'),
                      const SizedBox(width: 18),
                      _Cifra(valor: progreso.validados, texto: 'validados'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ganadas.isEmpty ? 'Aún sin insignias' : '${ganadas.length} de ${Insignia.todas.length} insignias',
                    style: tt.bodySmall?.copyWith(color: blanco.withValues(alpha: 0.82)),
                  ),
                  if (ganadas.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [for (final i in ganadas) Medalla(insignia: i, ganada: true, tamano: 22)],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.valor, required this.texto});
  final int valor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$valor',
            style: tt.headlineSmall?.copyWith(color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()])),
        Text(texto, style: tt.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.78))),
      ],
    );
  }
}

/// Raíces de zanco que suben desde abajo y hojas sueltas arriba, muy tenues.
class _TexturaManglar extends CustomPainter {
  const _TexturaManglar();

  @override
  void paint(Canvas canvas, Size size) {
    final azar = math.Random(7);
    final raiz = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.07);
    for (var i = 0; i < 9; i++) {
      final x0 = size.width * (i / 8) + (azar.nextDouble() - 0.5) * 24;
      final alto = size.height * (0.35 + azar.nextDouble() * 0.3);
      final desvio = (azar.nextDouble() - 0.5) * size.width * 0.35;
      final p = Path()
        ..moveTo(x0, size.height + 4)
        ..quadraticBezierTo(x0 + desvio * 0.2, size.height - alto * 0.5, x0 + desvio, size.height - alto);
      canvas.drawPath(p, raiz);
    }
    final hoja = Paint()..color = Colors.white.withValues(alpha: 0.055);
    for (var i = 0; i < 10; i++) {
      final largo = size.width * (0.07 + azar.nextDouble() * 0.06);
      final ancho = largo * 0.36;
      canvas
        ..save()
        ..translate(size.width * (0.45 + azar.nextDouble() * 0.6), size.height * (azar.nextDouble() * 0.75))
        ..rotate(azar.nextDouble() * math.pi * 2);
      final p = Path()
        ..quadraticBezierTo(largo * 0.5, -ancho, largo, 0)
        ..quadraticBezierTo(largo * 0.5, ancho, 0, 0);
      canvas
        ..drawPath(p, hoja)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// El brillo especular: una mancha de luz que va donde está el dedo, más una franja
/// diagonal fina que la acompaña.
class _BrilloPainter extends CustomPainter {
  const _BrilloPainter(this.centro);
  final Offset centro;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset((centro.dx + 1) / 2 * size.width, (centro.dy + 1) / 2 * size.height);
    final mancha = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withValues(alpha: 0.26), Colors.white.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c, radius: size.width * 0.62));
    canvas.drawRect(Offset.zero & size, mancha);
    final franja = Paint()
      ..shader = LinearGradient(
        begin: Alignment(centro.dx - 0.6, centro.dy - 0.6),
        end: Alignment(centro.dx + 0.6, centro.dy + 0.6),
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, franja);
  }

  @override
  bool shouldRepaint(covariant _BrilloPainter old) => old.centro != centro;
}
