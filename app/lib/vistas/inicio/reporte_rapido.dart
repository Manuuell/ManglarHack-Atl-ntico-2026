import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../datos/tipos.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/base/transicion_pestanas.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/kit/icono_amenaza.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';

/// «Reporte rápido» de Inicio: una tira de tarjetas grandes, una por tipo de
/// amenaza, que entran una tras otra y hacen su gesto propio al llegar.
///
/// - Un solo reloj para toda la tira: cada tarjeta toma su tramo con un
///   `Interval` desfasado [paso] (sin `Timer` ni `Future.delayed`), así que no
///   quedan temporizadores vivos al salir de la pantalla.
/// - El gesto del ícono (560 ms) se dispara cuando su tarjeta ya se ve, no
///   todos a la vez.
/// - Desliza con encaje a la tarjeta y deja asomar la siguiente si no caben.
/// - Con «reducir movimiento» todo aparece quieto y en su sitio.
class ReporteRapido extends StatefulWidget {
  const ReporteRapido({super.key, required this.alElegir, this.tipos = tiposRapidos});

  final void Function(TipoAmenaza tipo) alElegir;
  final List<TipoAmenaza> tipos;

  /// Desfase entre una tarjeta y la siguiente (rango iOS de 60 a 80 ms).
  static const paso = Duration(milliseconds: 70);

  /// Lo que tarda cada tarjeta en asentarse.
  static const entrada = Duration(milliseconds: 420);

  /// El gesto del ícono arranca cuando la tarjeta ya va por la mitad de su entrada.
  static const retrasoGesto = Duration(milliseconds: 120);

  static const tiposRapidos = [
    TipoAmenaza.tala,
    TipoAmenaza.quema,
    TipoAmenaza.vertimiento,
    TipoAmenaza.canoTaponado,
    TipoAmenaza.relleno,
    TipoAmenaza.fauna,
    TipoAmenaza.basuras,
  ];

  /// Clave de la tarjeta [i] (la usan las pruebas para leer su opacidad).
  static Key claveTarjeta(int i) => ValueKey('reporte-rapido-$i');

  @override
  State<ReporteRapido> createState() => _ReporteRapidoState();
}

class _ReporteRapidoState extends State<ReporteRapido> with SingleTickerProviderStateMixin {
  late Duration _total;
  late AnimationController _reloj;
  late List<GlobalKey<IconoAmenazaEstado>> _iconos;
  int _disparados = 0;

  @override
  void initState() {
    super.initState();
    final n = widget.tipos.length;
    _total = ReporteRapido.paso * math.max(0, n - 1) + ReporteRapido.entrada;
    _reloj = AnimationController(vsync: this, duration: _total)..addListener(_dispararGestos);
    _iconos = [for (var i = 0; i < n; i++) GlobalKey<IconoAmenazaEstado>()];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.animationsDisabled) {
      _reloj.value = 1;
      _disparados = widget.tipos.length;
      return;
    }
    // Como la entrada de las secciones: solo arranca con la pestaña a la vista.
    if (_reloj.status == AnimationStatus.dismissed && !_reloj.isAnimating && PestanaVisible.de(context)) {
      _reloj.forward();
    }
  }

  /// Corre el gesto de cada ícono cuando le llega su turno. Solo lee el reloj:
  /// no reconstruye nada.
  void _dispararGestos() {
    final ms = _reloj.value * _total.inMilliseconds;
    while (_disparados < _iconos.length &&
        ms >= (ReporteRapido.paso * _disparados + ReporteRapido.retrasoGesto).inMilliseconds) {
      _iconos[_disparados].currentState?.reproducir();
      _disparados++;
    }
  }

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  /// Tramo del reloj que le toca a la tarjeta [i].
  Interval _tramo(int i, Curve curva) {
    final total = _total.inMicroseconds;
    final inicio = (ReporteRapido.paso * i).inMicroseconds / total;
    final fin = ((ReporteRapido.paso * i) + ReporteRapido.entrada).inMicroseconds / total;
    return Interval(inicio.clamp(0.0, 1.0), fin.clamp(0.0, 1.0), curve: curva);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final quieto = context.animationsDisabled;
    final escalaLetra = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0);
    const sep = 10.0, margen = 16.0, disco = 60.0;
    // 4 + 14 de aire para la sombra, 12 + disco + 8 + texto + 12 de tarjeta.
    final alto = 4 + 14 + 12 + disco + 8 + 24 * escalaLetra + 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          // En una línea si cabe; con letra grande la pista baja debajo del título
          // en vez de desbordarse.
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            runSpacing: 2,
            children: [
              Text('Reporte rápido', style: tt.titleMedium),
              Text('Toca y ve directo a «¿Dónde?»', style: tt.labelSmall?.copyWith(color: Zc.textoTenue)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, caja) {
            final n = widget.tipos.length;
            final util = caja.maxWidth - margen * 2;
            // Si caben todas con holgura, se reparten; si no, la última visible asoma a medias.
            double ancho;
            if (n * 96 + (n - 1) * sep <= util) {
              ancho = math.min(124.0, (util - (n - 1) * sep) / n);
            } else {
              final caben = math.max(1, ((util + sep) / (96 + sep)).floor());
              ancho = (util - caben * sep) / (caben + 0.42);
              ancho = ancho.clamp(84.0, 120.0);
            }
            return SizedBox(
              height: alto,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                physics: _FisicaEncaje(paso: ancho + sep),
                padding: const EdgeInsets.fromLTRB(margen, 4, margen, 14),
                itemCount: n,
                separatorBuilder: (_, _) => const SizedBox(width: sep),
                itemBuilder: (context, i) {
                  final t = widget.tipos[i];
                  final tarjeta = _TarjetaRapida(
                    tipo: t,
                    ancho: ancho,
                    disco: disco,
                    icono: _iconos[i],
                    alTocar: () => widget.alElegir(t),
                  );
                  if (quieto) return KeyedSubtree(key: ReporteRapido.claveTarjeta(i), child: tarjeta);
                  final suave = CurvedAnimation(parent: _reloj, curve: _tramo(i, AppMotion.enter));
                  final brota = CurvedAnimation(parent: _reloj, curve: _tramo(i, AppMotion.emergente));
                  return FadeTransition(
                    key: ReporteRapido.claveTarjeta(i),
                    opacity: suave,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0.35, 0), end: Offset.zero).animate(suave),
                      child: ScaleTransition(scale: Tween(begin: 0.86, end: 1.0).animate(brota), child: tarjeta),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Tarjeta de un tipo: fondo suave de su color, borde y sombra del mismo tono,
/// ícono grande con su gesto, y presión con resorte y vibración.
class _TarjetaRapida extends StatelessWidget {
  const _TarjetaRapida({
    required this.tipo,
    required this.ancho,
    required this.disco,
    required this.icono,
    required this.alTocar,
  });

  final TipoAmenaza tipo;
  final double ancho;
  final double disco;
  final GlobalKey<IconoAmenazaEstado> icono;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final c = tipo.color;
    return RepaintBoundary(
      // El gesto del ícono arranca al apoyar el dedo, antes de soltar.
      child: Listener(
        onPointerDown: (_) => icono.currentState?.reproducir(),
        child: Presionable(
          escala: 0.92,
          vibracion: Vibracion.ligera,
          etiqueta: 'Reportar ${tipo.nombre}',
          onTap: alTocar,
          child: Container(
            width: ancho,
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(Colors.white, c, 0.13)!, Color.lerp(Colors.white, c, 0.05)!],
              ),
              borderRadius: BorderRadius.circular(Zr.l),
              border: Border.all(color: c.withValues(alpha: 0.22)),
              boxShadow: [BoxShadow(color: c.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: disco,
                  height: disco,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.withValues(alpha: 0.16), width: 1.5),
                  ),
                  child: Center(child: IconoAmenaza(tipo, key: icono, tamano: 44, animado: true)),
                ),
                const SizedBox(height: 8),
                Text(
                  tipo.corto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: Color.lerp(c, Cra.azul, 0.55)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Encaje a la tarjeta: al soltar, la tira se asienta con resorte en el borde
/// de la tarjeta más cercana (o la siguiente si iba rápido).
class _FisicaEncaje extends ScrollPhysics {
  const _FisicaEncaje({required this.paso, super.parent});

  final double paso;

  @override
  _FisicaEncaje applyTo(ScrollPhysics? ancestor) =>
      _FisicaEncaje(paso: paso, parent: buildParent(ancestor ?? const BouncingScrollPhysics()));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tol = toleranceFor(position);
    var destino = position.pixels / paso;
    if (velocity < -tol.velocity) {
      destino -= 0.5;
    } else if (velocity > tol.velocity) {
      destino += 0.5;
    }
    final objetivo = (destino.roundToDouble() * paso)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((objetivo - position.pixels).abs() < tol.distance) return null;
    return ScrollSpringSimulation(spring, position.pixels, objetivo, velocity, tolerance: tol);
  }

  @override
  bool get allowImplicitScrolling => false;
}
