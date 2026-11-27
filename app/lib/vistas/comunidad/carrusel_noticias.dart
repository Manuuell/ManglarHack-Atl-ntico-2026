/// Carrusel de noticias de la CRA de borde a borde, con el gesto de una app de domicilios de primera.
///
/// - Tarjetas grandes con la foto a sangre, degradado y título encima; se asoma la siguiente.
/// - En el teléfono la del centro va a tamaño completo y las de los lados, un poco reducidas y
///   atenuadas; la foto se mueve más despacio que la tarjeta (paralaje).
/// - Encaje magnético por página con el rebote de iOS; en 768 px se ven 2 y en 1280 px, casi 3.
/// - Pase automático suave cada [CarruselNoticias.intervalo]: se detiene con el dedo encima, al
///   pausarlo con el botón y del todo con «reducir movimiento». Tras deslizar a mano, el reloj
///   vuelve a empezar (si avanzara justo al tocar, el toque caería en otra noticia).
/// - Indicador de puntos: la activa es una píldora que se llena como barra de progreso.
/// - Tocar abre el lector con la foto compartida (Hero); mantener presionado muestra la vista previa
///   con Leer, Compartir, Guardar y la fuente.
/// - La foto remota se funde sobre una foto local del manglar (con su crédito), así sin señal nunca
///   sale un ícono gris ni hay saltos: la caja tiene su tamaño desde el primer cuadro.
///
/// Fluidez: lo que se anima por cuadro es solo transform y opacity, cada tarjeta va en su
/// [RepaintBoundary], el indicador solo se repinta (no se reconstruye) y la foto siguiente se precarga.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../datos/comunidad/comunidad.dart';
import '../../nucleo/base/esqueleto.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/kit/accion_gesto.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/menu_mantenido.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../web/abrir_enlace.dart';
import 'lector_noticia.dart';

// ------------------------------------------------------------------ datos de la tarjeta

/// Fotos reales del manglar que van dentro de la app (assets/fotos/CREDITOS.md): respaldo de la foto
/// de la noticia. Se rotulan como «foto de referencia» con su autor y licencia.
const fotosRespaldo = <(String, String)>[
  ('assets/fotos/manglar-raices-cartagena.webp', 'Ealmagro · CC BY-SA 4.0'),
  ('assets/fotos/garza-mallorquin.webp', 'Jdvillalobos · CC BY-SA 4.0'),
  ('assets/fotos/sendero-mallorquin.webp', 'Jdvillalobos · CC BY-SA 4.0'),
  ('assets/fotos/cano-san-bernardo.webp', 'Jorge Correa · CC BY-SA 3.0'),
];

(String, String) fotoRespaldo(int semilla) => fotosRespaldo[semilla.abs() % fotosRespaldo.length];

const _mesesCortos = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// «29 oct» (con el año solo si no es el actual).
String fechaRotulo(DateTime d, {DateTime? hoy}) {
  final ahora = hoy ?? DateTime.now();
  final base = '${d.day} ${_mesesCortos[d.month - 1]}';
  return d.year == ahora.year ? base : '$base ${d.year}';
}

/// «CRA · Prensa · 29 oct».
String rotuloNoticia(NoticiaManglar n, {DateTime? hoy}) => '${n.fuente} · ${fechaRotulo(n.fecha, hoy: hoy)}';

/// Minutos de lectura a 200 palabras por minuto (mínimo 1).
int minutosLectura(NoticiaManglar n) {
  final texto = n.parrafos.isEmpty ? n.resumen : n.parrafos.join(' ');
  final palabras = texto.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length;
  return (palabras / 200).ceil().clamp(1, 60);
}

/// Tema de la noticia, deducido de las palabras del título y el resumen (la CRA no lo publica).
class CategoriaNoticia {
  const CategoriaNoticia(this.nombre, this.color, this.tinta);
  final String nombre;
  final Color color;

  /// Color del texto sobre [color].
  final Color tinta;
}

const _categorias = <(String, CategoriaNoticia)>[
  (r'riesgo|emergencia|incendio|inundaci|erosi|lluvia|sequ', CategoriaNoticia('Riesgo', Color(0xFFE06B2D), Colors.white)),
  (r'manglar|mangle', CategoriaNoticia('Manglar', Zc.hoja, Colors.white)),
  (r'fauna|especie|\bave|tortuga|manat|iguana|rescat|liberaci|silvestre', CategoriaNoticia('Fauna', Zc.cienaga, Colors.white)),
  (r'siembra|árbol|arbol|reforest|vivero|bosque|plant', CategoriaNoticia('Siembra', Zc.hoja, Colors.white)),
  (r'educa|coleg|taller|capacita|niñ|joven|estudiant|escuela', CategoriaNoticia('Educación', Cra.dorado, Cra.azul)),
  (r'agua|ciénaga|cienaga|\brío|\brio|\bmar\b|playa|costa|humedal', CategoriaNoticia('Agua', Color(0xFF1B7FA8), Colors.white)),
  (r'residuo|basura|reciclaj|contamina|vertimiento', CategoriaNoticia('Residuos', Color(0xFF8A6A4B), Colors.white)),
];

const categoriaGeneral = CategoriaNoticia('CRA', Cra.azul, Colors.white);

CategoriaNoticia categoriaDe(NoticiaManglar n) {
  final t = '${n.titulo} ${n.resumen}'.toLowerCase();
  for (final (patron, c) in _categorias) {
    if (RegExp(patron).hasMatch(t)) return c;
  }
  return categoriaGeneral;
}

// ------------------------------------------------------------------ guardadas

/// Noticias guardadas en el teléfono (solo los id): se marcan con el ícono de guardado.
class NoticiasGuardadas extends ValueNotifier<Set<int>> {
  NoticiasGuardadas._() : super(const {}) {
    _cargar();
  }
  static final instancia = NoticiasGuardadas._();
  static const _clave = 'zanky.noticias.guardadas';

  Future<void> _cargar() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ids = (p.getStringList(_clave) ?? const []).map(int.tryParse).whereType<int>().toSet();
      if (ids.isNotEmpty) value = {...value, ...ids};
    } catch (_) {}
  }

  bool tiene(int id) => value.contains(id);

  Future<void> alternar(int id) async {
    value = tiene(id) ? ({...value}..remove(id)) : {...value, id};
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_clave, [for (final i in value) '$i']);
    } catch (_) {}
  }
}

// ------------------------------------------------------------------ acciones

Future<void> compartirNoticia(BuildContext context, NoticiaManglar n) async {
  try {
    await SharePlus.instance.share(ShareParams(text: '${n.titulo}\n${n.enlace}', subject: n.titulo));
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: n.enlace));
    if (context.mounted) avisar(context, 'Enlace copiado');
  }
}

/// Las acciones de la vista previa: Leer, Compartir, Guardar y la fuente. En el teléfono la fuente
/// se copia (nunca se abre el navegador del sistema); en la web se abre en otra pestaña.
List<AccionGesto> accionesNoticia(BuildContext context, NoticiaManglar n, {List<NoticiaManglar> lista = const []}) {
  final guardada = NoticiasGuardadas.instancia.tiene(n.id);
  return [
    AccionGesto(etiqueta: 'Leer', icono: Icons.menu_book_rounded, alEjecutar: () => abrirNoticia(context, n, lista: lista)),
    AccionGesto(etiqueta: 'Compartir', icono: Icons.ios_share_rounded, alEjecutar: () => compartirNoticia(context, n)),
    AccionGesto(
      etiqueta: guardada ? 'Quitar de guardadas' : 'Guardar',
      icono: guardada ? Icons.bookmark_remove_rounded : Icons.bookmark_add_rounded,
      alEjecutar: () {
        NoticiasGuardadas.instancia.alternar(n.id);
        vibrar(Vibracion.ligera);
        avisar(
          context,
          guardada ? 'Quitada de guardadas' : 'Noticia guardada',
          tipo: TipoAviso.exito,
          accion: AccionAviso('Deshacer', () => NoticiasGuardadas.instancia.alternar(n.id)),
        );
      },
    ),
    if (kIsWeb)
      AccionGesto(etiqueta: 'Abrir la fuente', icono: Icons.open_in_new_rounded, alEjecutar: () => abrirEnlace(n.enlace))
    else
      AccionGesto(
        etiqueta: 'Copiar enlace de la fuente',
        icono: Icons.link_rounded,
        alEjecutar: () async {
          await Clipboard.setData(ClipboardData(text: n.enlace));
          if (context.mounted) avisar(context, 'Enlace de la CRA copiado');
        },
      ),
  ];
}

// ------------------------------------------------------------------ foto

/// Foto de la noticia sin saltos: fondo de la marca del tamaño exacto, encima una foto local del
/// manglar (fundido al decodificarse) y encima la foto real, que se funde cuando llega. Si la real
/// falla (sin señal, CORS), queda la local con su crédito.
class FotoConRespaldo extends StatelessWidget {
  const FotoConRespaldo({super.key, required this.url, required this.semilla, this.credito = false, this.anchoCache});
  final String? url;
  final int semilla;

  /// Muestra «Foto de referencia · autor · licencia» mientras se ve la local.
  final bool credito;

  /// Ancho en píxeles para decodificar (ahorra memoria en las tarjetas).
  final int? anchoCache;

  static Widget _fundido(Widget hijo, int? cuadro, bool sincronico, Duration d) => sincronico
      ? hijo
      : AnimatedOpacity(opacity: cuadro == null ? 0 : 1, duration: d, curve: Zm.entrar, child: hijo);

  @override
  Widget build(BuildContext context) {
    final (ruta, autor) = fotoRespaldo(semilla);
    final u = url;
    return Stack(fit: StackFit.expand, children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Cra.azul, Color(0xFF184437)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
      ),
      Image.asset(
        ruta,
        fit: BoxFit.cover,
        cacheWidth: anchoCache,
        excludeFromSemantics: true,
        frameBuilder: (_, hijo, cuadro, sinc) => _fundido(hijo, cuadro, sinc, Zm.corto),
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
      if (credito)
        Positioned(
          left: 10,
          bottom: 10,
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(99)),
              child: Text('Foto de referencia · $autor',
                  style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      if (u != null && u.isNotEmpty)
        Image.network(
          u,
          fit: BoxFit.cover,
          cacheWidth: anchoCache,
          excludeFromSemantics: true,
          frameBuilder: (_, hijo, cuadro, sinc) => _fundido(hijo, cuadro, sinc, Zm.medio),
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
    ]);
  }
}

// ------------------------------------------------------------------ medidas

/// Cuánto ocupa cada página según el ancho: una y un poco en el teléfono, 2 en tableta, casi 3 en escritorio.
double fraccionCarrusel(double ancho) => ancho >= 1000 ? 0.34 : ancho >= 600 ? 0.5 : 0.86;

/// Alto del carrusel (tarjetas + indicador): el esqueleto usa el mismo para que no haya salto.
double altoTarjetaCarrusel(double ancho) => ((ancho * fraccionCarrusel(ancho) - 12) * 0.92).clamp(250.0, 380.0);

const double _altoIndicador = 44;

/// Esqueleto del carrusel, del tamaño exacto que tendrá.
class EsqueletoCarrusel extends StatelessWidget {
  const EsqueletoCarrusel({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, caja) {
        final ancho = caja.maxWidth;
        final f = fraccionCarrusel(ancho);
        final alto = altoTarjetaCarrusel(ancho);
        final anchoTarjeta = ancho * f - 12;
        final cuantas = (1 / f).ceil() + (f > 0.6 ? 1 : 0);
        return Semantics(
          label: 'Cargando noticias',
          child: SizedBox(
            height: alto + _altoIndicador,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: double.infinity,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: f > 0.6 ? ancho * (1 - f) / 2 + 6 : 6),
                  for (var i = 0; i < cuantas; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Skeleton(width: anchoTarjeta, height: alto, borderRadius: BorderRadius.circular(Zr.l)),
                    ),
                ]),
              ),
            ),
          ),
        );
      });
}

// ------------------------------------------------------------------ carrusel

class CarruselNoticias extends StatefulWidget {
  const CarruselNoticias({super.key, required this.noticias, this.intervalo = const Duration(seconds: 6), this.autoPase = true});
  final List<NoticiaManglar> noticias;
  final Duration intervalo;
  final bool autoPase;

  /// Para pruebas: fuerza (o apaga) el pase automático. Nulo: activo solo en la app de verdad (en las
  /// pruebas de widgets un reloj infinito no deja asentar la pantalla).
  @visibleForTesting
  static bool? pasoAutomaticoForzado;

  @override
  State<CarruselNoticias> createState() => CarruselNoticiasState();
}

class CarruselNoticiasState extends State<CarruselNoticias> with SingleTickerProviderStateMixin {
  PageController? _ctl;
  double _fraccion = 0;
  int _pagina = 0;
  bool _tocando = false;
  bool _pausado = false;
  bool _sinMovimiento = false;
  bool _arrastreUsuario = false;
  final _foco = FocusNode(debugLabel: 'carrusel-noticias');

  late final AnimationController _reloj = AnimationController(vsync: this, duration: widget.intervalo)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _avanzarSolo();
    });

  /// Página visible (la de la izquierda en tableta y escritorio).
  int get pagina => _pagina;
  bool get pausado => _pausado;

  int get _visibles => _fraccion <= 0 ? 1 : (1 / _fraccion).floor().clamp(1, 3);
  int get _maxPagina => (widget.noticias.length - _visibles).clamp(0, widget.noticias.length - 1);
  bool get _telefono => _fraccion > 0.6;

  bool get _autoPermitido =>
      widget.autoPase &&
      widget.noticias.length > _visibles &&
      !_sinMovimiento &&
      (CarruselNoticias.pasoAutomaticoForzado ?? WidgetsBinding.instance is WidgetsFlutterBinding);

  void _reanudar({bool desdeCero = false}) {
    if (desdeCero) _reloj.value = 0;
    if (_autoPermitido && !_tocando && !_pausado) {
      _reloj.forward();
    } else {
      _reloj.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sinMovimiento = MediaQuery.disableAnimationsOf(context);
    _precargar(_pagina);
    _reanudar();
  }

  @override
  void didUpdateWidget(covariant CarruselNoticias oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.intervalo != widget.intervalo) _reloj.duration = widget.intervalo;
    if (_pagina >= widget.noticias.length) _pagina = 0;
    _reanudar();
  }

  @override
  void dispose() {
    _reloj.dispose();
    _ctl?.dispose();
    _foco.dispose();
    super.dispose();
  }

  PageController _controlador(double fraccion) {
    final viejo = _ctl;
    if (viejo != null && _fraccion == fraccion) return viejo;
    _fraccion = fraccion;
    _pagina = _pagina.clamp(0, _maxPagina);
    final nuevo = PageController(viewportFraction: fraccion, initialPage: _pagina);
    if (viejo != null) WidgetsBinding.instance.addPostFrameCallback((_) => viejo.dispose());
    return _ctl = nuevo;
  }

  void _precargar(int i) {
    final n = widget.noticias;
    for (var j = i; j <= i + _visibles && j < n.length; j++) {
      unawaited(precacheImage(AssetImage(fotoRespaldo(n[j].id).$1), context, onError: (_, _) {}));
      final u = n[j].imagen;
      if (u != null && u.isNotEmpty) unawaited(precacheImage(NetworkImage(u), context, onError: (_, _) {}));
    }
  }

  void irA(int i, {bool usuario = true}) {
    final c = _ctl;
    if (c == null || !c.hasClients) return;
    final destino = i.clamp(0, _maxPagina);
    if (usuario) vibrar(Vibracion.seleccion);
    if (_sinMovimiento) {
      c.jumpToPage(destino);
    } else {
      // Regresar al principio recorre varias tarjetas: un poco más largo para que no sea un latigazo.
      final lejos = (destino - _pagina).abs() > 1;
      c.animateToPage(destino, duration: lejos ? const Duration(milliseconds: 900) : const Duration(milliseconds: 620), curve: Zm.entrar);
    }
  }

  void _avanzarSolo() {
    if (!mounted || !_autoPermitido) return;
    irA(_pagina >= _maxPagina ? 0 : _pagina + 1, usuario: false);
  }

  void _alCambiarPagina(int i) {
    if (i > _maxPagina && !_tocando) {
      // En tableta y escritorio no se deja un hueco a la derecha: vuelve a la última que llena la fila.
      WidgetsBinding.instance.addPostFrameCallback((_) => irA(_maxPagina, usuario: false));
    }
    setState(() => _pagina = i.clamp(0, widget.noticias.length - 1));
    if (_arrastreUsuario) vibrar(Vibracion.seleccion);
    _precargar(_pagina);
    _reanudar(desdeCero: true);
  }

  void _alternarPausa() {
    setState(() => _pausado = !_pausado);
    vibrar(Vibracion.ligera);
    _reanudar();
  }

  double _paginaActual() {
    final c = _ctl;
    return (c != null && c.hasClients && c.position.hasContentDimensions) ? (c.page ?? _pagina.toDouble()) : _pagina.toDouble();
  }

  /// Delta de la tarjeta [i] respecto a la que está al centro (0 = centrada, ±1 = una página al lado).
  double _delta(int i) {
    final pag = _paginaActual();
    final centro = _telefono ? 0.0 : (_visibles - 1) / 2;
    return i - pag - centro;
  }

  KeyEventResult _tecla(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      irA(_pagina + 1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      irA(_pagina - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final noticias = widget.noticias;
    return LayoutBuilder(builder: (context, caja) {
      final ancho = caja.maxWidth;
      final ctl = _controlador(fraccionCarrusel(ancho));
      final alto = altoTarjetaCarrusel(ancho);
      final anchoTarjeta = ancho * _fraccion - 12;
      final dpr = MediaQuery.devicePixelRatioOf(context);
      return Focus(
        focusNode: _foco,
        onKeyEvent: _tecla,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: alto,
            child: Listener(
              onPointerDown: (_) {
                _tocando = true;
                _reanudar();
              },
              onPointerUp: (_) {
                _tocando = false;
                _reanudar();
              },
              onPointerCancel: (_) {
                _tocando = false;
                _reanudar();
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (s) {
                  if (s is ScrollStartNotification) _arrastreUsuario = s.dragDetails != null;
                  if (s is ScrollEndNotification) _arrastreUsuario = false;
                  return false;
                },
                child: PageView.builder(
                  key: const ValueKey('carrusel-noticias'),
                  controller: ctl,
                  padEnds: _telefono,
                  clipBehavior: Clip.none,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: _alCambiarPagina,
                  itemCount: noticias.length,
                  itemBuilder: (context, i) {
                    final tarjeta = RepaintBoundary(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: TarjetaCarrusel(
                          noticia: noticias[i],
                          lista: noticias,
                          paralaje: ParalajePagina(ctl, () => _delta(i)),
                          anchoCache: (anchoTarjeta * 1.25 * dpr).round(),
                        ),
                      ),
                    );
                    if (!_telefono || _sinMovimiento) return tarjeta;
                    return AnimatedBuilder(
                      animation: ctl,
                      child: tarjeta,
                      builder: (_, hijo) {
                        final t = _delta(i).abs().clamp(0.0, 1.0);
                        return Opacity(
                          opacity: 1 - 0.32 * t,
                          child: Transform.scale(scale: 1 - 0.07 * t, child: hijo),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          SizedBox(
            height: _altoIndicador,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _Indicador(
                cuantas: noticias.length,
                controlador: ctl,
                reloj: _reloj,
                pagina: _paginaActual,
                activo: _pagina,
                alTocar: irA,
              ),
              if (_autoPermitido || _pausado)
                Semantics(
                  button: true,
                  label: _pausado ? 'Reanudar el pase automático de noticias' : 'Pausar el pase automático de noticias',
                  child: Presionable(
                    onTap: _alternarPausa,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(_pausado ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18, color: Zc.textoSuave),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      );
    });
  }
}

/// Lo que necesita la foto para su paralaje: el controlador (para escuchar) y el delta de su página.
class ParalajePagina {
  const ParalajePagina(this.escuchar, this.delta);
  final Listenable escuchar;
  final double Function() delta;
}

// ------------------------------------------------------------------ indicador

/// Puntos con la píldora activa que se estira según la página y se llena con el reloj del pase.
/// Es un solo [CustomPaint] que se repinta (sin reconstruir ni medir) en su propio [RepaintBoundary].
class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.cuantas,
    required this.controlador,
    required this.reloj,
    required this.pagina,
    required this.activo,
    required this.alTocar,
  });
  final int cuantas;
  final Listenable controlador;
  final Animation<double> reloj;
  final double Function() pagina;
  final int activo;
  final void Function(int) alTocar;

  static const _punto = 6.0, _hueco = 6.0, _extra = 16.0;

  double get _ancho => cuantas * _punto + (cuantas - 1) * _hueco + _extra;

  @override
  Widget build(BuildContext context) {
    if (cuantas < 2) return const SizedBox.shrink();
    return Semantics(
      label: 'Noticia ${activo + 1} de $cuantas',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final x = d.localPosition.dx - 8;
          final i = (x / (_punto + _hueco)).floor().clamp(0, cuantas - 1);
          alTocar(i);
        },
        child: RepaintBoundary(
          child: SizedBox(
            width: _ancho + 16,
            height: 44,
            child: CustomPaint(
              painter: _PintorIndicador(
                cuantas: cuantas,
                pagina: pagina,
                reloj: reloj,
                repintar: Listenable.merge([controlador, reloj]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorIndicador extends CustomPainter {
  _PintorIndicador({required this.cuantas, required this.pagina, required this.reloj, required Listenable repintar})
      : super(repaint: repintar);
  final int cuantas;
  final double Function() pagina;
  final Animation<double> reloj;

  @override
  void paint(Canvas canvas, Size size) {
    const p = _Indicador._punto, h = _Indicador._hueco, e = _Indicador._extra;
    final pag = pagina().clamp(0.0, (cuantas - 1).toDouble());
    final base = Paint()..color = Cra.azul.withValues(alpha: 0.22);
    final lleno = Paint()..color = Cra.dorado;
    final cerca = pag.round();
    var x = 8.0;
    final y = (size.height - p) / 2;
    for (var i = 0; i < cuantas; i++) {
      final t = (1 - (pag - i).abs()).clamp(0.0, 1.0);
      final w = p + e * t;
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, p), const Radius.circular(p / 2));
      canvas.drawRRect(r, i == cerca ? (Paint()..color = Cra.azul.withValues(alpha: 0.30 + 0.25 * t)) : base);
      if (i == cerca) {
        final progreso = reloj.value;
        if (progreso > 0) {
          canvas.save();
          canvas.clipRRect(r);
          canvas.drawRect(Rect.fromLTWH(x, y, w * progreso, p), lleno);
          canvas.restore();
        } else if (t > 0.99) {
          // Sin pase automático (pausado o «reducir movimiento»): la activa va entera en dorado.
          canvas.drawRRect(r, lleno);
        }
      }
      x += w + h;
    }
  }

  @override
  bool shouldRepaint(covariant _PintorIndicador viejo) => viejo.cuantas != cuantas;
}

// ------------------------------------------------------------------ tarjeta

class TarjetaCarrusel extends StatelessWidget {
  const TarjetaCarrusel({super.key, required this.noticia, this.lista = const [], this.paralaje, this.anchoCache});
  final NoticiaManglar noticia;
  final List<NoticiaManglar> lista;
  final ParalajePagina? paralaje;
  final int? anchoCache;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final n = noticia;
    final cat = categoriaDe(n);
    final min = minutosLectura(n);
    final rotulo = rotuloNoticia(n);
    final radio = BorderRadius.circular(Zr.l);

    Widget foto = RepaintBoundary(child: FotoConRespaldo(url: n.imagen, semilla: n.id, anchoCache: anchoCache));
    final p = paralaje;
    if (p != null && !MediaQuery.disableAnimationsOf(context)) {
      // Paralaje: la foto (agrandada un 18 %) se corre al revés que la tarjeta, solo con transform.
      foto = LayoutBuilder(
        builder: (_, caja) => AnimatedBuilder(
          animation: p.escuchar,
          child: foto,
          builder: (_, hijo) => Transform.scale(
            scale: 1.18,
            child: Transform.translate(offset: Offset(-p.delta().clamp(-1.5, 1.5) * caja.maxWidth * 0.07, 0), child: hijo),
          ),
        ),
      );
    }

    return MenuMantenido(
      etiqueta: '${cat.nombre}. ${n.titulo}. $rotulo, $min min de lectura. Toca para leer; mantén presionado para la vista previa',
      radio: radio,
      alTocar: () => abrirNoticia(context, n, lista: lista),
      vistaPrevia: (_) => VistaPreviaNoticia(noticia: n),
      acciones: accionesNoticia(context, n, lista: lista),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radio,
          boxShadow: const [BoxShadow(color: Color(0x290A2A47), blurRadius: 22, offset: Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: radio,
          child: Stack(fit: StackFit.expand, children: [
            Hero(tag: 'noticia-${n.id}', child: ClipRect(child: foto)),
            // Degradado: arriba apenas (para las píldoras) y abajo fuerte (para el título).
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.28, 0.5, 1],
                  colors: [Color(0x59000000), Color(0x00000000), Color(0x1A0A2A47), Color(0xF00A2A47)],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(children: [
                PildoraCategoria(cat),
                const Spacer(),
                ValueListenableBuilder<Set<int>>(
                  valueListenable: NoticiasGuardadas.instancia,
                  builder: (_, g, _) => g.contains(n.id)
                      ? const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.bookmark_rounded, color: Cra.dorado, size: 20, semanticLabel: 'Guardada'),
                        )
                      : const SizedBox.shrink(),
                ),
                PildoraLectura(min),
              ]),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(rotulo.toUpperCase(),
                    style: tt.seccion.copyWith(color: Cra.dorado, fontSize: 10.5, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Text(
                  n.titulo,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.18,
                    shadows: const [Shadow(color: Color(0x66000000), blurRadius: 12)],
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class PildoraCategoria extends StatelessWidget {
  const PildoraCategoria(this.categoria, {super.key});
  final CategoriaNoticia categoria;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: categoria.color, borderRadius: BorderRadius.circular(99)),
        child: Text(categoria.nombre.toUpperCase(),
            style: TextStyle(color: categoria.tinta, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
      );
}

class PildoraLectura extends StatelessWidget {
  const PildoraLectura(this.minutos, {super.key, this.oscura = true});
  final int minutos;
  final bool oscura;
  @override
  Widget build(BuildContext context) {
    final color = oscura ? Colors.white : Zc.textoSuave;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: oscura ? Colors.black.withValues(alpha: 0.42) : Zc.linea.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.schedule_rounded, size: 12, color: color),
        const SizedBox(width: 4),
        Text('$minutos min', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// La vista previa al mantener presionada una noticia: foto, tema, fecha y el comienzo del texto.
class VistaPreviaNoticia extends StatelessWidget {
  const VistaPreviaNoticia({super.key, required this.noticia});
  final NoticiaManglar noticia;
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final n = noticia;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Zr.m),
        child: AspectRatio(aspectRatio: 16 / 9, child: FotoConRespaldo(url: n.imagen, semilla: n.id, credito: true)),
      ),
      const SizedBox(height: 12),
      Row(children: [
        PildoraCategoria(categoriaDe(n)),
        const SizedBox(width: 8),
        PildoraLectura(minutosLectura(n), oscura: false),
      ]),
      const SizedBox(height: 10),
      Text(rotuloNoticia(n).toUpperCase(), style: tt.seccion.copyWith(color: Cra.azul, fontSize: 10.5)),
      const SizedBox(height: 6),
      Text(n.titulo, style: tt.titleMedium?.copyWith(color: Zc.texto, fontWeight: FontWeight.w800, height: 1.25)),
      const SizedBox(height: 8),
      Text((n.parrafos.isEmpty ? [n.resumen] : n.parrafos.take(2)).join('\n\n'),
          maxLines: 6, overflow: TextOverflow.ellipsis, style: tt.bodyMedium?.copyWith(color: Zc.textoSuave, height: 1.45)),
    ]);
  }
}
