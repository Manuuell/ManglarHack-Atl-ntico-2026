import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../datos/estado.dart';
import '../../datos/guardian.dart';
import '../../nucleo/base/entrada_escalonada.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/burbuja.dart';
import '../comun/zanky_mascota.dart';
import 'formulario.dart';
import 'fotos.dart';
import 'puntos.dart';

/// Primera pantalla de la app: cuatro páginas con fotos reales del manglar del Caribe
/// colombiano (a sangre completa, con velo para leer) y una quinta con el consentimiento
/// (Ley 1581) arriba, visible sin buscarlo, y los datos opcionales debajo.
///
/// Las fotos siguen al dedo con paralaje (se quedan atrás al 30 %) y los textos avanzan
/// más despacio todavía y se funden. Zanky habla desde la tarjeta de texto, pequeño, para
/// no tapar la foto; tocarlo cuenta un dato del manglar. Con «reducir movimiento» solo
/// quedan los fundidos. En pantallas anchas (≥ 900 px) foto y texto van en dos columnas.
class Bienvenida extends StatefulWidget {
  const Bienvenida({super.key});

  @override
  State<Bienvenida> createState() => _BienvenidaState();
}

class _Paso {
  const _Paso(this.ceja, this.titulo, this.texto, this.foto, this.pildoras);
  final String ceja;
  final String titulo;
  final String texto;
  final FotoManglar foto;
  final List<(IconData, String)> pildoras;
}

class _BienvenidaState extends State<Bienvenida> {
  static final _pasos = [
    const _Paso(
      'MANGLAR DEL ATLÁNTICO',
      'Lo que pasa en el manglar, ahora.',
      'Zanky convierte lo que ves en un aviso a la CRA. Tala, relleno, basura o quema: tú lo ves, ellos se enteran.',
      FotoManglar.raices,
      [],
    ),
    const _Paso(
      'CÓMO AYUDAS',
      'Una foto basta.',
      'Tomas la foto, Zanky marca dónde estás y el aviso llega a la CRA para verificarlo.',
      FotoManglar.garza,
      [
        (Icons.photo_camera_rounded, 'Foto'),
        (Icons.place_rounded, 'Ubicación'),
        (Icons.campaign_rounded, 'Aviso a la CRA'),
      ],
    ),
    const _Paso(
      'CON O SIN SEÑAL',
      'En la ciénaga también funciona.',
      'Sin internet, tu reporte se guarda en el teléfono y sale solo cuando vuelve la señal.',
      FotoManglar.sendero,
      [(Icons.save_alt_rounded, 'Se guarda'), (Icons.cloud_done_rounded, 'Se envía después')],
    ),
    _Paso(
      'CRECE CONTIGO',
      'De propágulo a guardián.',
      'Cada reporte que la CRA verifica hace crecer a tu Zanky. Tu manglar también se nota.',
      FotoManglar.cano,
      [
        (Icons.spa_rounded, Nivel.todos[0].nombre),
        (Icons.eco_rounded, Nivel.todos[3].nombre),
        (Icons.park_rounded, Nivel.todos[5].nombre),
      ],
    ),
  ];

  /// La foto detrás del formulario (oscurecida).
  static const _fotoFormulario = FotoManglar.raices;

  static final _total = _pasos.length + 1;
  static final _ultima = _total - 1;

  final PageController _ctrl = PageController();
  late final DatosPerfil _datos;

  int _indice = 0;
  int _siguienteDato = 0;
  String? _frase;
  bool _celebrando = false;
  bool _guardando = false;
  bool _precargado = false;

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
      : const [Animo.feliz, Animo.curioso, Animo.curioso, Animo.celebrando, Animo.feliz][_indice];

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
      // Se arma un perfil nuevo con el mismo id: si guardar falla, el que ya está en
      // memoria no queda marcado como «con consentimiento» sin estarlo en el disco.
      // El rol ya no se pregunta: el perfil conserva el que tenía (o el de por defecto).
      final perfil = Perfil(
        id: base.id,
        creado: base.creado,
        nombre: _datos.nombre.text.trim(),
        colegio: _datos.colegio.text.trim(),
        // La cédula ya no se pide aquí; si el perfil previo tenía una huella, se conserva.
        cedulaHash: base.cedulaHash,
        sal: base.sal,
        anonimoPorDefecto: _datos.anonimo,
        rol: base.rol,
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

  /// 0 en las páginas de foto, 1 en el formulario; sigue al dedo.
  double _haciaForm() => (_paginaDe(_ctrl) - (_ultima - 1)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final relleno = MediaQuery.paddingOf(context);
    final fotos = [for (final p in _pasos) p.foto, _fotoFormulario];

    return Scaffold(
      // Con pantalla completa el sistema no ajusta por el teclado: se hace a mano.
      resizeToAvoidBottomInset: false,
      backgroundColor: Cra.hero,
      body: LayoutBuilder(
        builder: (context, caja) {
          final ancho = caja.maxWidth >= 900;
          final anchoTexto = (caja.maxWidth * 0.42).clamp(420.0, 560.0);
          if (!_precargado) {
            _precargado = true;
            FotosConParalaje.precargar(
              context,
              fotos,
              ancho ? Size(caja.maxWidth - anchoTexto, caja.maxHeight) : caja.biggest,
            );
          }
          final columna = Padding(
            padding: EdgeInsets.only(bottom: insets),
            child: Column(
              children: [
                SizedBox(height: relleno.top),
                _cabecera(conLogo: !ancho),
                Expanded(child: _paginas(caja.maxHeight, ancho)),
                _barraInferior(math.max(0, relleno.bottom - insets), ancho),
              ],
            ),
          );
          if (!ancho) {
            return Stack(
              children: [
                Positioned.fill(
                  child: FotosConParalaje(controlador: _ctrl, fotos: fotos, oscurecerDesde: _ultima),
                ),
                // Velo de arriba: el logo y «Saltar» se leen sobre cualquier cielo.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: relleno.top + 120,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Cra.hero.withValues(alpha: 0.55), Cra.hero.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(child: columna),
              ],
            );
          }
          // Dos columnas: la foto a la izquierda (con el logo) y el texto a la derecha.
          return Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FotosConParalaje(controlador: _ctrl, fotos: fotos, oscurecerDesde: _ultima),
                    ),
                    Positioned(left: 32, top: relleno.top + 28, child: const InsigniaCra(alto: 52)),
                  ],
                ),
              ),
              SizedBox(
                width: anchoTexto,
                child: ColoredBox(color: Cra.hero, child: columna),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Logo de la CRA a la izquierda y «Saltar» a la derecha; «Saltar» se pliega al
  /// llegar al formulario siguiendo al dedo.
  Widget _cabecera({required bool conLogo}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            if (conLogo) const InsigniaCra(alto: 40),
            const Spacer(),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final v = 1 - _haciaForm();
                return Opacity(
                  opacity: v,
                  child: IgnorePointer(
                    ignoring: v < 0.5,
                    child: Presionable(
                      etiqueta: 'Saltar la presentación',
                      onTap: () => _irA(_ultima),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
                        child: Center(
                          widthFactor: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Cra.hero.withValues(alpha: VeloFoto.alfaPildora),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Saltar',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Cra.blanco),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _paginas(double altoPantalla, bool ancho) {
    return PageView(
      controller: _ctrl,
      onPageChanged: _alCambiarPagina,
      physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        for (var i = 0; i < _pasos.length; i++)
          _Paralaje(
            controlador: _ctrl,
            indice: i,
            child: _PaginaFoto(
              paso: _pasos[i],
              zanky: ZankyMascota(tamano: 64, animo: i == _indice ? _animo : Animo.feliz, onTap: _tocarZanky),
              frase: i == _indice ? _frase : null,
              ancho: ancho,
            ),
          ),
        _Paralaje(
          controlador: _ctrl,
          indice: _ultima,
          child: Padding(
            // En el teléfono se asoma un poco de foto arriba; el panel es una hoja.
            padding: EdgeInsets.only(top: ancho ? 8 : math.min(120, altoPantalla * 0.08)),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: ColoredBox(
                color: Zc.arena,
                child: PaginaPerfil(
                  datos: _datos,
                  zanky: ZankyMascota(tamano: 56, animo: _indice == _ultima ? _animo : Animo.feliz, onTap: _tocarZanky),
                  frase: _indice == _ultima ? _frase : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _barraInferior(double seguro, bool ancho) {
    final enForm = _indice == _ultima;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, hijo) {
        final t = _haciaForm();
        return ColoredBox(color: Color.lerp(ancho ? Cra.hero : VeloFoto.texto, Zc.arena, t)!, child: hijo);
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 6, 24, 16 + seguro),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 4),
              child: Center(
                child: PuntosPagina(controlador: _ctrl, total: _total, actual: _indice, ultimaClara: true),
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
                          alPedirAcepto: () {
                            vibrar(Vibracion.ligera);
                            _datos.pedirAcepto();
                          },
                        ),
                      )
                    : BotonZ(
                        key: const ValueKey('siguiente'),
                        texto: _indice == _ultima - 1 ? 'Casi listo' : 'Siguiente',
                        icono: Icons.arrow_forward_rounded,
                        color: Cra.dorado,
                        colorTexto: Cra.azul,
                        onTap: () => _irA(_indice + 1),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _paginaDe(PageController c) => c.hasClients && c.position.haveDimensions ? (c.page ?? 0.0) : 0.0;

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
            child: Transform.translate(offset: Offset(quieto ? 0 : d * caja.maxWidth * 0.65, 0), child: hijo),
          );
        },
      ),
    );
  }
}

/// Una página de foto: la tarjeta de texto abajo, sobre el velo. Si la letra crece, la
/// tarjeta se desplaza en vez de desbordar (y nunca sale del velo: el fundido va encima).
class _PaginaFoto extends StatelessWidget {
  const _PaginaFoto({required this.paso, required this.zanky, required this.frase, required this.ancho});

  final _Paso paso;
  final Widget zanky;
  final String? frase;
  final bool ancho;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final tarjeta = Container(
      width: double.infinity,
      color: ancho ? Cra.hero : VeloFoto.texto,
      padding: EdgeInsets.fromLTRB(ancho ? 40 : 24, 0, ancho ? 40 : 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          EntradaEscalonada(
            index: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                zanky,
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(paso.ceja, style: estiloSeccion(context)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          EntradaEscalonada(
            index: 1,
            child: Semantics(
              header: true,
              child: Text(
                paso.titulo,
                style: tema.headlineLarge?.copyWith(
                  color: Cra.blanco,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                  fontSize: ancho ? 40 : 32,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          EntradaEscalonada(
            index: 2,
            child: Text(paso.texto, style: tema.bodyLarge?.copyWith(color: Cra.textoSuave, height: 1.45)),
          ),
          if (paso.pildoras.isNotEmpty) ...[
            const SizedBox(height: 18),
            EntradaEscalonada(
              index: 3,
              child: Semantics(
                label: paso.pildoras.map((p) => p.$2).join(', luego '),
                excludeSemantics: true,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final p in paso.pildoras) _Pildora(icono: p.$1, texto: p.$2)],
                ),
              ),
            ),
          ],
          AnimatedSize(
            duration: context.resolveDuration(Zm.corto),
            curve: Zm.entrar,
            alignment: Alignment.topCenter,
            child: frase == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Semantics(
                      liveRegion: true,
                      child: Text.rich(
                        TextSpan(
                          text: 'Zanky: ',
                          style: tema.titleSmall?.copyWith(color: Cra.dorado),
                          children: [
                            TextSpan(
                              text: frase,
                              style: tema.bodyMedium?.copyWith(color: Cra.blanco),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Text(paso.foto.credito, style: tema.bodySmall?.copyWith(color: Cra.textoTenue, fontSize: 11)),
        ],
      ),
    );
    return Align(
      alignment: ancho ? Alignment.centerLeft : Alignment.bottomCenter,
      child: SingleChildScrollView(
        reverse: !ancho,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!ancho)
              // El velo empieza antes que el texto: nada queda en el borde duro.
              IgnorePointer(
                child: Container(
                  height: VeloFoto.alturaFundido,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Cra.hero.withValues(alpha: 0), VeloFoto.texto],
                    ),
                  ),
                ),
              ),
            tarjeta,
          ],
        ),
      ),
    );
  }
}

class _Pildora extends StatelessWidget {
  const _Pildora({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Cra.blanco.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Cra.blanco.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 18, color: Cra.dorado),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Cra.blanco, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// El botón del final. Igual que [BotonZ] pero deja que el texto largo pase a dos
/// renglones (con letra grande no se corta) y explica por qué está apagado.
class _BotonEmpezar extends StatelessWidget {
  const _BotonEmpezar({required this.activo, required this.cargando, required this.onTap, required this.alPedirAcepto});

  final bool activo;
  final bool cargando;
  final VoidCallback onTap;

  /// Con el botón apagado, tocarlo lleva a la casilla que falta.
  final VoidCallback alPedirAcepto;

  static const _texto = 'Empezar a cuidar el manglar';

  @override
  Widget build(BuildContext context) {
    const color = Zc.hoja;
    final habilitado = activo && !cargando;
    return Presionable(
      onTap: habilitado ? onTap : (cargando ? null : alPedirAcepto),
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
