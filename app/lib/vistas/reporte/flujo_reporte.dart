import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../datos/estado.dart';
import '../../datos/fotos.dart';
import '../../datos/reporte.dart';
import '../../datos/tipos.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/kit/boton_estado.dart';
import '../../nucleo/kit/confirmar.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/burbuja.dart';
import '../comun/zanky_mascota.dart';
import 'borrador.dart';
import 'enviado.dart';
import 'paso_detalles.dart';
import 'paso_evidencia.dart';
import 'paso_tipo.dart';
import 'paso_ubicacion.dart';

/// Abre el flujo de reporte a pantalla completa. [tipo] llega elegido desde el inicio
/// (y entonces se empieza en «¿Dónde?»). [zonaId] centra el mapa de «¿Dónde?» en esa
/// zona mientras no haya GPS.
Future<void> abrirReporte(BuildContext context, {TipoAmenaza? tipo, String? zonaId, LatLng? punto}) {
  final estado = Zanky.leer(context);
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      transitionDuration: Zm.largo,
      reverseTransitionDuration: Zm.medio,
      pageBuilder: (_, _, _) => FlujoReporte(estado: estado, tipo: tipo, zonaId: zonaId, punto: punto),
      // Sube desde abajo como una hoja grande: se entiende que es una tarea aparte.
      transitionsBuilder: (_, a, _, hijo) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Zm.entrar, reverseCurve: Zm.salir)),
        child: hijo,
      ),
    ),
  );
}

class FlujoReporte extends StatefulWidget {
  const FlujoReporte({super.key, required this.estado, this.tipo, this.zonaId, this.punto});
  final EstadoZanky estado;

  /// Punto ya elegido (mantener presionado en el mapa): llega marcado, la persona solo lo acepta.
  final LatLng? punto;
  final TipoAmenaza? tipo;
  final String? zonaId;

  @override
  State<FlujoReporte> createState() => _FlujoReporteState();
}

class _FlujoReporteState extends State<FlujoReporte> {
  late final Borrador _b = Borrador(widget.estado, tipo: widget.tipo);
  late final PageController _paginas = PageController(initialPage: widget.tipo == null ? 0 : 1);
  late int _paso = widget.tipo == null ? 0 : 1;

  /// Lo que devolvió el guardado, para abrir la confirmación cuando el ✓ termine.
  Reporte? _guardado;

  static const _pasos = ['Qué viste', 'Dónde', 'Foto', 'Detalles'];

  @override
  void initState() {
    super.initState();
    final p = widget.punto;
    if (p != null) _b.marcarEnMapa(p);
  }

  @override
  void dispose() {
    _b.dispose();
    _paginas.dispose();
    super.dispose();
  }

  String get _frase => switch (_paso) {
        0 => '¿Qué viste en el manglar?',
        1 => switch (_b.ubicacion) {
            final u? when u.dentro => '¡Ajá! Eso queda dentro del manglar. Confírmame el punto.',
            final u? when u.enInfluencia => 'Queda muy cerquita del manglar: puede afectarlo. ¿Es ahí?',
            _? => 'Ese punto queda lejos del manglar. Si lo afecta, repórtalo igual.',
            null when _b.gps == EstadoGps.sinPermiso || _b.gps == EstadoGps.apagado =>
              'Sin GPS también se puede: toca el mapa donde está pasando.',
            null => '¿Dónde está pasando? Uso el GPS: funciona aunque no haya señal.',
          },
        2 => _b.foto == null
            ? 'Una foto tomada ahí mismo vale oro: ayuda a la CRA a confiar en tu reporte.'
            : '¡Buena foto! Si quieres, toma otra más clara.',
        _ => _b.tipo?.pregunta ?? 'Cuéntame un poco más.',
      };

  Animo get _animo => switch (_paso) {
        0 => Animo.curioso,
        1 => _b.ubicacion == null
            ? (_b.gps == EstadoGps.sinPermiso ? Animo.preocupado : Animo.curioso)
            : (_b.ubicacion!.enInfluencia ? Animo.feliz : Animo.preocupado),
        2 => _b.foto == null ? Animo.curioso : Animo.celebrando,
        _ => (_b.prioridad?.valor ?? 0) >= 4 ? Animo.preocupado : Animo.feliz,
      };

  bool get _puedeSeguir => switch (_paso) {
        0 => _b.tipo != null,
        1 => _b.puntoAceptado, // fuera del Atlántico el servidor lo rechaza siempre
        _ => true,
      };

  void _ir(int paso) {
    FocusScope.of(context).unfocus();
    setState(() => _paso = paso);
    _paginas.animateToPage(paso, duration: context.resolveDuration(Zm.medio), curve: Zm.entrar);
  }

  void _siguiente() {
    if (_paso < 3) _ir(_paso + 1);
  }

  /// Último paso: guarda (y envía si hay señal). Lo corre el botón con su ciclo
  /// cargando → hecho; si lanza, el botón se sacude. Un fallo de guardado no
  /// pierde nada (el borrador sigue aquí): se ofrece reintentar y, solo si falta
  /// espacio y hay foto, seguir sin ella.
  Future<void> _enviar() async {
    while (true) {
      try {
        _guardado = await _b.enviar();
        return;
      } catch (e) {
        if (!mounted) rethrow;
        final error = e is ErrorAlGuardar ? e : ErrorAlGuardar.de(e, conFoto: _b.foto != null);
        final decision = await _avisarFalloGuardado(error);
        if (decision == null) rethrow; // cerró la hoja sin elegir: el botón lo muestra
        if (decision) _b.quitarFoto();
      }
    }
  }

  /// El ✓ del botón ya se dibujó: se pasa a la confirmación.
  Future<void> _irAEnviado() async {
    final r = _guardado;
    if (r == null || !mounted) return;
    await Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      transitionDuration: Zm.largo,
      pageBuilder: (_, _, _) => ReporteEnviado(reporteId: r.id),
      transitionsBuilder: (_, a, _, hijo) => FadeTransition(opacity: a, child: hijo),
    ));
  }

  /// Hoja de fallo de guardado. `true` = seguir sin foto, `false` = reintentar, nulo = cerrada.
  Future<bool?> _avisarFalloGuardado(ErrorAlGuardar error) {
    final conFoto = _b.foto != null && error.sinEspacio;
    vibrar(Vibracion.media);
    return mostrarHojaZ<bool>(
      context,
      nombre: 'FalloGuardado',
      contenido: (ctx) {
        final tt = Theme.of(ctx).textTheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ZankyMascota(tamano: 70, animo: Animo.preocupado),
            const SizedBox(height: 10),
            Text('No pude guardar tu reporte', style: tt.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(error.mensaje, style: tt.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            BotonZ(texto: 'Reintentar', onTap: () => Navigator.pop(ctx, false)),
            if (conFoto) ...[
              const SizedBox(height: 8),
              BotonZ(texto: 'Seguir sin foto', secundario: true, onTap: () => Navigator.pop(ctx, true)),
            ],
          ],
        );
      },
    );
  }

  Future<void> _cerrar() async {
    if (!_b.tieneAlgo || await _confirmarDescartar()) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmarDescartar() => confirmarEnHoja(
        context,
        titulo: '¿Descartar este reporte?',
        texto: 'Lo que llevas no se guarda. Si algo está pasando, la CRA necesita saberlo.',
        textoConfirmar: 'Descartar',
        textoCancelar: 'Seguir reportando',
        destructivo: true,
        seguroPrimero: true,
      );

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    final abajo = MediaQuery.paddingOf(context).bottom;
    final primerPaso = widget.tipo == null ? 0 : 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (hecho, _) {
        if (hecho) return;
        // Atrás del sistema: retrocede un paso; en el primero, pregunta antes de cerrar.
        if (_paso > primerPaso) {
          _ir(_paso - 1);
        } else {
          _cerrar();
        }
      },
      child: Scaffold(
        backgroundColor: Zc.arena,
        body: ListenableBuilder(
          listenable: _b,
          builder: (context, _) => Column(
            children: [
              SizedBox(height: arriba + 6),
              _Cabecera(
                paso: _paso,
                pasos: _pasos,
                onCerrar: _cerrar,
                onAtras: _paso > 0 ? () => _ir(_paso - 1) : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 20, 4),
                child: Row(
                  children: [
                    ZankyMascota(tamano: 62, animo: _animo),
                    const SizedBox(width: 12),
                    Expanded(child: BurbujaZanky(texto: _frase)),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _paginas,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _PasoTransicion(controlador: _paginas, indice: 0, inicial: _paso, child: PasoTipo(borrador: _b, onElegido: () => _ir(1))),
                    _PasoTransicion(controlador: _paginas, indice: 1, inicial: _paso, child: PasoUbicacion(borrador: _b, zonaId: widget.zonaId)),
                    _PasoTransicion(controlador: _paginas, indice: 2, inicial: _paso, child: PasoEvidencia(borrador: _b)),
                    _PasoTransicion(controlador: _paginas, indice: 3, inicial: _paso, child: PasoDetalles(borrador: _b)),
                  ],
                ),
              ),
              _BarraAccion(
                abajo: abajo,
                texto: switch (_paso) {
                  0 => 'Elige qué viste',
                  1 => _b.punto != null
                      ? (_b.puntoAceptado ? 'Usar este punto' : 'Marca otro punto en el mapa')
                      : (_b.gps == EstadoGps.buscando ? 'Buscando tu ubicación…' : 'Toca el mapa para marcar'),
                  2 => _b.foto == null ? 'Seguir sin foto' : 'Seguir',
                  _ => !widget.estado.servidor.configurado
                      ? 'Guardar reporte (demostración)'
                      : (widget.estado.enLinea ? 'Enviar a la CRA' : 'Guardar y enviar con señal'),
                },
                icono: _paso == 3 ? Icons.send_rounded : Icons.arrow_forward_rounded,
                secundario: _paso == 2 && _b.foto == null,
                ultimo: _paso == 3,
                textoHecho: widget.estado.servidor.configurado && widget.estado.enLinea ? 'Enviado' : 'Guardado',
                alEnviar: _enviar,
                alHecho: _irAEnviado,
                onTap: _puedeSeguir ? _siguiente : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.paso, required this.pasos, required this.onCerrar, this.onAtras});
  final int paso;
  final List<String> pasos;
  final VoidCallback onCerrar;
  final VoidCallback? onAtras;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              _BotonIcono(
                icono: Icons.arrow_back_rounded,
                etiqueta: 'Paso anterior',
                visible: onAtras != null,
                onTap: onAtras,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('NUEVO REPORTE · PASO ${paso + 1} DE ${pasos.length}', style: tt.labelSmall),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: Zm.corto,
                      child: Text(pasos[paso], key: ValueKey(paso), style: tt.titleMedium),
                    ),
                  ],
                ),
              ),
              _BotonIcono(icono: Icons.close_rounded, etiqueta: 'Cerrar el reporte', onTap: onCerrar),
            ],
          ),
          const SizedBox(height: 10),
          // Progreso por segmentos: cada uno se llena con su paso.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                for (var i = 0; i < pasos.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Stack(children: [
                        Container(height: 5, color: Zc.linea),
                        // Se llena con scaleX (transform): sin relayout por cuadro.
                        TweenAnimationBuilder<double>(
                          tween: Tween(end: i <= paso ? 1.0 : 0.0),
                          duration: context.resolveDuration(Zm.medio),
                          curve: Zm.entrar,
                          builder: (_, v, hijo) =>
                              Transform(alignment: Alignment.centerLeft, transform: Matrix4.diagonal3Values(v, 1, 1), child: hijo),
                          child: Container(height: 5, color: Zc.hoja),
                        ),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonIcono extends StatelessWidget {
  const _BotonIcono({required this.icono, required this.etiqueta, this.onTap, this.visible = true});
  final IconData icono;
  final String etiqueta;
  final VoidCallback? onTap;
  final bool visible;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        duration: Zm.corto,
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: Presionable(
            escala: 0.88,
            etiqueta: etiqueta,
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(icono, color: Zc.texto, size: 22),
            ),
          ),
        ),
      );
}

class _BarraAccion extends StatelessWidget {
  const _BarraAccion({
    required this.abajo,
    required this.texto,
    required this.icono,
    required this.onTap,
    required this.alEnviar,
    required this.alHecho,
    required this.textoHecho,
    this.ultimo = false,
    this.secundario = false,
  });
  final double abajo;
  final String texto;
  final IconData icono;
  final VoidCallback? onTap;
  final Future<void> Function() alEnviar;
  final VoidCallback alHecho;
  final String textoHecho;

  /// Último paso: el botón es [BotonEstado] (cargando → ✓ → seguir).
  final bool ultimo;
  final bool secundario;

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, (teclado ? 0 : abajo) + 14),
      decoration: BoxDecoration(
        color: Zc.arena,
        border: Border(top: BorderSide(color: Zc.linea.withValues(alpha: 0.7))),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ultimo
            ? BotonEstado(
                texto: texto,
                icono: icono,
                textoHecho: textoHecho,
                textoError: 'No se guardó',
                textoCargando: 'Guardando',
                alPresionar: onTap == null ? null : alEnviar,
                alHecho: alHecho,
              )
            : BotonZ(texto: texto, icono: icono, secundario: secundario, onTap: onTap),
      ),
    );
  }
}

/// Parallax suave entre pasos: la página que se va y la que llega se desplazan un
/// poco menos que el dedo y se achican apenas. Solo `transform` (nada de opacidad
/// sobre un mapa); con movimiento reducido no hace nada.
class _PasoTransicion extends StatelessWidget {
  const _PasoTransicion({required this.controlador, required this.indice, required this.inicial, required this.child});
  final PageController controlador;
  final int indice;
  final int inicial;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.animationsDisabled) return child;
    return AnimatedBuilder(
      animation: controlador,
      child: child,
      builder: (context, hijo) {
        final pos = controlador.hasClients && controlador.position.haveDimensions
            ? (controlador.page ?? inicial.toDouble())
            : inicial.toDouble();
        final d = (pos - indice).clamp(-1.0, 1.0);
        if (d == 0) return hijo!;
        final ancho = MediaQuery.sizeOf(context).width;
        return Transform.translate(
          offset: Offset(d * ancho * 0.18, 0),
          child: Transform.scale(scale: 1 - 0.04 * d.abs(), child: hijo),
        );
      },
    );
  }
}
