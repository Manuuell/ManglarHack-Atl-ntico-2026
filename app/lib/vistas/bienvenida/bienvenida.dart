import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../datos/estado.dart';
import '../../datos/guardian.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/burbuja.dart';
import '../comun/zanky_mascota.dart';
import 'fondo.dart';
import 'formulario.dart';
import 'puntos.dart';

/// Primera pantalla de la app: tres páginas que cuentan para qué sirve Zanky y una
/// cuarta que pide el nombre, el aviso de privacidad y el consentimiento (Ley 1581).
///
/// Zanky es UNO solo, fijo arriba: cambia de ánimo con la página y encoge al llegar al
/// formulario (y se esconde con el teclado para que nada tape el campo activo). Los
/// textos de cada página no se deslizan completos con el PageView: se desvanecen y
/// avanzan más despacio que el dedo (paralaje), leyendo el valor continuo del
/// [PageController], así se sienten pegados al dedo.
class Bienvenida extends StatefulWidget {
  const Bienvenida({super.key});

  @override
  State<Bienvenida> createState() => _BienvenidaState();
}

class _Paso {
  const _Paso(this.burbuja, this.titulo, this.texto, this.cadena);
  final String burbuja;
  final String titulo;
  final String texto;
  final List<_Eslabon> cadena;
}

class _Eslabon {
  const _Eslabon(this.icono, this.etiqueta, this.color);
  final IconData icono;
  final String etiqueta;
  final Color color;
}

class _BienvenidaState extends State<Bienvenida> {
  static const _total = 4;
  static const _ultima = _total - 1;

  static final _pasos = [
    const _Paso(
      'Tócame y te cuento algo del manglar.',
      '¡Ajá! Soy Zanky',
      'Te ayudo a avisarle a la CRA cuando algo amenaza el manglar del Atlántico, en el momento en que pasa.',
      [
        _Eslabon(Icons.photo_camera_rounded, 'Foto', Zc.hoja),
        _Eslabon(Icons.place_rounded, 'Ubicación', Zc.cienaga),
        _Eslabon(Icons.campaign_rounded, 'Aviso a la CRA', Zc.sol),
      ],
    ),
    const _Paso(
      'Sin señal no pasa nada: yo guardo todo.',
      'Funciono sin señal',
      'En la ciénaga casi no hay internet. Tomas la foto y la ubicación igual; yo lo envío apenas vuelva la señal.',
      [
        _Eslabon(Icons.photo_camera_rounded, 'Tomas la foto', Zc.hoja),
        _Eslabon(Icons.save_alt_rounded, 'Se guarda en tu teléfono', Zc.cienaga),
        _Eslabon(Icons.cloud_done_rounded, 'Se envía al volver la señal', Zc.sol),
      ],
    ),
    _Paso(
      '¡Cada reporte verificado te hace crecer!',
      'Tus reportes cuentan',
      'Cuando la CRA verifica lo que reportas, creces: de propágulo a guardián del manglar.',
      [
        _Eslabon(Icons.spa_rounded, Nivel.todos[0].nombre, Zc.hoja),
        _Eslabon(Icons.eco_rounded, Nivel.todos[3].nombre, Zc.cienaga),
        _Eslabon(Icons.park_rounded, Nivel.todos[5].nombre, Zc.sol),
      ],
    ),
  ];

  static const _burbujaPerfil = 'Casi listo. Cuéntame cómo te llamamos.';

  final PageController _ctrl = PageController();
  late final DatosPerfil _datos;

  int _indice = 0;
  int _siguienteDato = 1; // el 0 repite la presentación de la primera página
  String? _frase;
  bool _celebrando = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    // Si ya había un perfil sin consentimiento, no se pierde lo que se escribió.
    final previo = Zanky.leer(context).perfil;
    _datos = DatosPerfil(
      nombre: previo?.nombre ?? '',
      colegio: previo?.colegio ?? '',
      anonimo: previo?.anonimoPorDefecto ?? false,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _datos.dispose();
    super.dispose();
  }

  Animo get _animo => _celebrando
      ? Animo.celebrando
      : const [Animo.feliz, Animo.curioso, Animo.celebrando, Animo.feliz][_indice];

  void _alCambiarPagina(int i) {
    if (i == _indice) return;
    vibrar(Vibracion.seleccion);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _indice = i;
      _frase = null;
    });
  }

  void _irA(int i) {
    final destino = i.clamp(0, _ultima);
    if (context.animationsDisabled) {
      _ctrl.jumpToPage(destino);
    } else {
      _ctrl.animateToPage(destino, duration: Zm.largo, curve: Zm.entrar);
    }
  }

  void _tocarZanky() {
    setState(() {
      _frase = DatosZanky.todos[_siguienteDato % DatosZanky.todos.length];
      _siguienteDato++;
    });
  }

  Future<void> _empezar() async {
    if (_guardando || !_datos.acepto) return;
    if (!_datos.valido) {
      vibrar(Vibracion.fuerte);
      _datos.mostrarErrores();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final estado = Zanky.leer(context);
    final espera = context.resolveDuration(const Duration(milliseconds: 560));
    _datos.ponerErrorGuardar(null);
    setState(() {
      _guardando = true;
      _celebrando = true;
    });
    vibrar(Vibracion.media);
    try {
      // Zanky celebra un instante (< 700 ms) antes de que la app cambie de pantalla.
      if (espera > Duration.zero) await Future<void>.delayed(espera);
      final base = estado.perfil ?? estado.perfilNuevo();
      final cedula = DatosPerfil.soloDigitos(_datos.cedula.text);
      // Se arma un perfil nuevo con el mismo id: si guardar falla, el que ya está en
      // memoria no queda marcado como «con consentimiento» sin estarlo en el disco.
      final perfil = Perfil(
        id: base.id,
        creado: base.creado,
        nombre: _datos.nombre.text.trim(),
        colegio: _datos.colegio.text.trim(),
        // Solo la huella; el número nunca se guarda.
        cedulaHash: cedula.isEmpty ? null : Perfil.huellaCedula(cedula),
        anonimoPorDefecto: _datos.anonimo,
        consentimiento: DateTime.now(),
      );
      await estado.guardarPerfil(perfil);
    } catch (_) {
      if (!mounted) return;
      vibrar(Vibracion.fuerte);
      setState(() {
        _guardando = false;
        _celebrando = false;
      });
      _datos.ponerErrorGuardar(
        'No pudimos guardar tu perfil. Revisa que tu teléfono tenga espacio y vuelve a intentarlo.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final relleno = MediaQuery.paddingOf(context);
    final escala = MediaQuery.textScalerOf(context).scale(1);
    final teclado = insets > 80;

    return Scaffold(
      // Con pantalla completa el sistema no ajusta por el teclado: se hace a mano.
      resizeToAvoidBottomInset: false,
      backgroundColor: Zc.arena,
      body: Stack(
        children: [
          const Positioned.fill(child: FondoBienvenida()),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, caja) {
                final libre = caja.maxHeight - insets;
                final tamano = (libre * 0.26 / (escala > 1.15 ? 1.2 : 1.0)).clamp(120.0, 190.0);
                return TweenAnimationBuilder<double>(
                  tween: Tween(end: teclado ? 0.0 : 1.0),
                  duration: context.resolveDuration(Zm.medio),
                  curve: Zm.entrar,
                  builder: (context, kf, _) => Padding(
                    padding: EdgeInsets.only(bottom: insets),
                    child: Column(
                      children: [
                        SizedBox(height: relleno.top),
                        _cabecera(tamano, kf),
                        Expanded(child: _paginas()),
                        _barraInferior(kf, math.max(0, relleno.bottom - insets)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// «Saltar» y Zanky. Los dos siguen al valor continuo del PageController: Zanky
  /// encoge hacia el formulario y «Saltar» se pliega, sin saltos.
  Widget _cabecera(double tamano, double kf) {
    final alto = tamano * 1.2;
    final mascota = ZankyMascota(tamano: tamano, animo: _animo, onTap: _tocarZanky);
    return AnimatedBuilder(
      animation: _ctrl,
      child: mascota,
      builder: (context, hijo) {
        final p = _paginaDe(_ctrl);
        final haciaForm = (p - (_ultima - 1)).clamp(0.0, 1.0);
        final saltar = (1 - haciaForm) * kf;
        final s = ((1 - 0.34 * haciaForm) * kf).clamp(0.001, 1.0);
        return Column(
          children: [
            ClipRect(
              child: Align(
                heightFactor: saltar,
                alignment: Alignment.topRight,
                child: Opacity(
                  opacity: saltar,
                  child: IgnorePointer(
                    ignoring: saltar < 0.5,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 12, 0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Presionable(
                          etiqueta: 'Saltar la presentación',
                          onTap: () => _irA(_ultima),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Center(
                                widthFactor: 1,
                                child: Text(
                                  'Saltar',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Zc.textoSuave),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: alto * s,
              width: double.infinity,
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: alto,
                minWidth: 0,
                maxWidth: tamano,
                child: Transform.scale(scale: s, alignment: Alignment.topCenter, child: hijo),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _paginas() {
    final paginas = PageView(
      controller: _ctrl,
      onPageChanged: _alCambiarPagina,
      physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        for (var i = 0; i < _pasos.length; i++)
          _Paralaje(
            controlador: _ctrl,
            indice: i,
            child: _PaginaIntro(paso: _pasos[i], frase: i == _indice ? _frase : null),
          ),
        _Paralaje(
          controlador: _ctrl,
          indice: _ultima,
          child: PaginaPerfil(datos: _datos, burbuja: _indice == _ultima ? (_frase ?? _burbujaPerfil) : _burbujaPerfil),
        ),
      ],
    );
    // Desvanecido de 24 px en el borde superior: lo que se desplaza no se corta en seco
    // bajo las raíces de Zanky. Las páginas llevan 24 px de relleno arriba para que en
    // reposo el contenido empiece justo donde termina el desvanecido.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
        stops: [0, math.min(1.0, 24 / math.max(24.0, r.height))],
      ).createShader(r),
      child: paginas,
    );
  }

  Widget _barraInferior(double kf, double seguro) {
    final enForm = _indice == _ultima;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 6, 24, 16 + seguro),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRect(
            child: Align(
              heightFactor: kf,
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 4),
                child: Center(child: PuntosPagina(controlador: _ctrl, total: _total, actual: _indice)),
              ),
            ),
          ),
          AnimatedSize(
            duration: context.resolveDuration(Zm.corto),
            curve: Zm.entrar,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: context.resolveDuration(Zm.corto),
              child: enForm
                  ? ListenableBuilder(
                      key: const ValueKey('empezar'),
                      listenable: _datos,
                      builder: (context, _) => _BotonEmpezar(
                        activo: _datos.acepto,
                        cargando: _guardando,
                        onTap: _empezar,
                      ),
                    )
                  : BotonZ(
                      key: const ValueKey('siguiente'),
                      texto: 'Siguiente',
                      icono: Icons.arrow_forward_rounded,
                      onTap: () => _irA(_indice + 1),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

double _paginaDe(PageController c) =>
    c.hasClients && c.position.haveDimensions ? (c.page ?? 0.0) : 0.0;

/// Paralaje de una página: el PageView la mueve a la velocidad del dedo; aquí se le
/// devuelve el 65 % de ese desplazamiento (avanza solo el 35 %) y se desvanece rápido.
/// Con «reducir movimiento» no hay recorrido, solo el fundido.
class _Paralaje extends StatelessWidget {
  const _Paralaje({required this.controlador, required this.indice, required this.child});

  final PageController controlador;
  final int indice;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final quieto = context.animationsDisabled;
    return LayoutBuilder(
      builder: (context, caja) => AnimatedBuilder(
        animation: controlador,
        child: child,
        builder: (context, hijo) {
          final d = _paginaDe(controlador) - indice;
          final opacidad = (1 - d.abs() * 1.6).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacidad,
            child: Transform.translate(
              offset: Offset(quieto ? 0 : d * caja.maxWidth * 0.65, 0),
              child: hijo,
            ),
          );
        },
      ),
    );
  }
}

/// Una de las tres primeras páginas: burbuja, título, texto y la cadena de tres pasos.
class _PaginaIntro extends StatelessWidget {
  const _PaginaIntro({required this.paso, required this.frase});

  final _Paso paso;
  final String? frase;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BurbujaZanky(texto: frase ?? paso.burbuja),
          const SizedBox(height: 22),
          Semantics(header: true, child: Text(paso.titulo, style: tema.headlineMedium)),
          const SizedBox(height: 10),
          Text(paso.texto, style: tema.bodyLarge?.copyWith(color: Zc.textoSuave)),
          const SizedBox(height: 26),
          _Cadena(eslabones: paso.cadena),
        ],
      ),
    );
  }
}

/// Tres pasos con su flecha: lo que Zanky hace, dibujado en vez de explicado.
class _Cadena extends StatelessWidget {
  const _Cadena({required this.eslabones});

  final List<_Eslabon> eslabones;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final hijos = <Widget>[];
    for (var i = 0; i < eslabones.length; i++) {
      final e = eslabones[i];
      if (i > 0) {
        hijos.add(const Padding(
          padding: EdgeInsets.only(top: 14),
          child: Icon(Icons.chevron_right_rounded, size: 20, color: Zc.textoTenue),
        ));
      }
      hijos.add(
        Expanded(
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: e.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Zr.m),
                ),
                child: Icon(e.icono, size: 26, color: e.color),
              ),
              const SizedBox(height: 8),
              Text(
                e.etiqueta,
                textAlign: TextAlign.center,
                style: tema.bodySmall?.copyWith(color: Zc.texto, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }
    return Semantics(
      label: eslabones.map((e) => e.etiqueta).join(', luego '),
      excludeSemantics: true,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: hijos),
    );
  }
}

/// El botón del final. Igual que [BotonZ] pero deja que el texto largo pase a dos
/// renglones (con letra grande no se corta) y explica por qué está apagado.
class _BotonEmpezar extends StatelessWidget {
  const _BotonEmpezar({required this.activo, required this.cargando, required this.onTap});

  final bool activo;
  final bool cargando;
  final VoidCallback onTap;

  static const _texto = 'Empezar a cuidar el manglar';

  @override
  Widget build(BuildContext context) {
    const color = Zc.hoja;
    final habilitado = activo && !cargando;
    return Presionable(
      onTap: habilitado ? onTap : null,
      vibracion: Vibracion.ligera,
      etiqueta: activo ? _texto : '$_texto. Primero acepta el tratamiento de tus datos.',
      child: AnimatedOpacity(
        duration: context.resolveDuration(Zm.corto),
        opacity: habilitado || cargando ? 1 : 0.45,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(Zr.m),
            boxShadow: habilitado || cargando
                ? [BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 18, offset: const Offset(0, 8))]
                : null,
          ),
          child: AnimatedSwitcher(
            duration: context.resolveDuration(Zm.corto),
            child: cargando
                ? const SizedBox(
                    key: ValueKey('c'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                  )
                : Row(
                    key: const ValueKey('t'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.eco_rounded, color: Colors.white, size: 21),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _texto,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
