import 'package:flutter/material.dart';

import '../../nucleo/base/movimiento.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/tema.dart';

/// Una foto real del manglar del Caribe colombiano, empaquetada en la app (funciona sin
/// señal). Licencias y enlaces en `assets/fotos/CREDITOS.md`.
class FotoManglar {
  const FotoManglar({
    required this.ruta,
    required this.lugar,
    required this.autor,
    required this.licencia,
    this.foco = Alignment.center,
  });

  final String ruta;
  final String lugar;
  final String autor;
  final String licencia;

  /// Qué parte de la foto se conserva cuando la pantalla la recorta.
  final Alignment foco;

  /// La imagen decodificada al ancho que se pinta (en escalones, para que la precarga y la
  /// pantalla compartan la misma entrada de la caché y no se decodifique dos veces).
  /// Con `cover` la foto (apaisada, ~3:2) se agranda hasta llenar el alto: en un teléfono
  /// vertical se necesita más ancho que el de la pantalla.
  ImageProvider proveedor(Size caja, double dpr) =>
      ResizeImage(AssetImage(ruta), width: anchoDecodificado(caja, dpr), policy: ResizeImagePolicy.fit);

  static int anchoDecodificado(Size caja, double dpr) {
    final px = (caja.width > caja.height * 1.5 ? caja.width : caja.height * 1.5) * dpr * 1.06;
    for (final e in const [480, 800, 1100]) {
      if (px <= e) return e;
    }
    return 1400;
  }

  /// Pie discreto que va en pantalla: lugar, autor y licencia.
  String get credito => '$lugar · Foto: $autor, $licencia, Wikimedia Commons';

  static const raices = FotoManglar(
    ruta: 'assets/fotos/manglar-raices-cartagena.webp',
    lugar: 'Manglar, Cartagena de Indias',
    autor: 'Ealmagro',
    licencia: 'CC BY-SA 4.0',
    foco: Alignment(0.35, 0),
  );
  static const garza = FotoManglar(
    ruta: 'assets/fotos/garza-mallorquin.webp',
    lugar: 'Ciénaga de Mallorquín, Barranquilla',
    autor: 'Jdvillalobos',
    licencia: 'CC BY-SA 4.0',
    foco: Alignment(0.2, 0),
  );
  static const sendero = FotoManglar(
    ruta: 'assets/fotos/sendero-mallorquin.webp',
    lugar: 'Ecoparque Ciénaga de Mallorquín, Barranquilla',
    autor: 'Jdvillalobos',
    licencia: 'CC BY-SA 4.0',
    foco: Alignment(0.45, 0),
  );
  static const cano = FotoManglar(
    ruta: 'assets/fotos/cano-san-bernardo.webp',
    lugar: 'Manglares de San Bernardo del Viento, Córdoba',
    autor: 'Jorge Correa',
    licencia: 'CC BY-SA 3.0',
  );
}

/// Velo para leer sobre la foto. El texto SIEMPRE va sobre [alfaTexto] de [Cra.hero] como
/// mínimo: en el peor caso (pixel blanco detrás) el blanco queda en 11,9:1 y el dorado en
/// 6,2:1 (AA). Lo comprueba `test/bienvenida_test.dart`.
abstract final class VeloFoto {
  static const alfaTexto = 0.88;
  static const alfaPildora = 0.72;
  static const alturaFundido = 96.0;

  static Color get texto => Cra.hero.withValues(alpha: alfaTexto);
}

/// Las fotos de todas las páginas, una encima de otra, siguiendo al dedo: la que entra
/// llega desde el lado y se funde; la que sale se queda atrás (paralaje al 30 %) y se
/// aclara un poco más. Con «reducir movimiento» solo hay fundido.
class FotosConParalaje extends StatefulWidget {
  /// Decodifica las fotos después del primer cuadro, sin esperarlas: la primera pantalla
  /// sale con el fondo azul y la foto se funde al llegar; las demás ya estarán listas
  /// cuando el dedo pase de página. Usa el mismo proveedor que [FotosConParalaje].
  static void precargar(BuildContext context, List<FotoManglar> fotos, Size caja) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      for (final f in fotos.toSet()) {
        precacheImage(f.proveedor(caja, dpr), context, onError: (_, _) {});
      }
    });
  }

  const FotosConParalaje({super.key, required this.controlador, required this.fotos, this.oscurecerDesde});

  final PageController controlador;
  final List<FotoManglar> fotos;

  /// A partir de esta página (el formulario) la foto se oscurece para que el panel se lea.
  final int? oscurecerDesde;

  @override
  State<FotosConParalaje> createState() => _FotosConParalajeState();
}

/// Acercamiento lento (de la portada de fotos que ya usamos): la foto «respira» entre
/// 1,06 y 1,11 en 14 s de ida y vuelta, como un video sin sonido. Solo escala (la GPU
/// la mueve sin volver a decodificar) y se detiene con «reducir movimiento».
class _FotosConParalajeState extends State<FotosConParalaje> with SingleTickerProviderStateMixin {
  late final AnimationController _respiro = AnimationController(vsync: this, duration: const Duration(seconds: 14));

  PageController get controlador => widget.controlador;
  List<FotoManglar> get fotos => widget.fotos;
  int? get oscurecerDesde => widget.oscurecerDesde;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.animationsDisabled) {
      _respiro.stop();
    } else if (!_respiro.isAnimating) {
      _respiro.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _respiro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quieto = context.animationsDisabled;
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, caja) => AnimatedBuilder(
          animation: Listenable.merge([controlador, _respiro]),
          builder: (context, _) {
            final p = controlador.hasClients && controlador.position.haveDimensions
                ? (controlador.page ?? 0.0)
                : controlador.initialPage.toDouble();
            final i = p.floor().clamp(0, fotos.length - 1);
            final f = (p - i).clamp(0.0, 1.0);
            final hijos = <Widget>[];
            void capa(int k, double d, double opacidad) {
              if (k < 0 || k >= fotos.length || opacidad <= 0) return;
              final foto = fotos[k];
              hijos.add(
                Positioned.fill(
                  child: Opacity(
                    opacity: opacidad.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(quieto ? 0 : -d * caja.maxWidth * 0.3, 0),
                      child: Transform.scale(
                        scale: quieto ? 1 : 1.06 + 0.05 * Curves.easeInOut.transform(_respiro.value),
                        child: Image(
                          image: foto.proveedor(caja.biggest, MediaQuery.devicePixelRatioOf(context)),
                          // La foto que aún se decodifica no aparece de golpe: se funde sobre el azul.
                          frameBuilder: (context, hijo, cuadro, sincrona) => sincrona
                              ? hijo
                              : AnimatedOpacity(
                                  opacity: cuadro == null ? 0 : 1,
                                  duration: context.resolveDuration(Zm.largo),
                                  curve: Zm.entrar,
                                  child: hijo,
                                ),
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          fit: BoxFit.cover,
                          alignment: foto.foco,
                          filterQuality: FilterQuality.medium,
                          gaplessPlayback: true,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            capa(i, f, 1);
            capa(i + 1, f - 1, Curves.easeOut.transform(f));
            final oscuro = oscurecerDesde == null ? 0.0 : (p - (oscurecerDesde! - 1)).clamp(0.0, 1.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Cra.hero),
                ...hijos,
                if (oscuro > 0) ColoredBox(color: Cra.hero.withValues(alpha: 0.45 * oscuro)),
              ],
            );
          },
        ),
      ),
    );
  }
}
