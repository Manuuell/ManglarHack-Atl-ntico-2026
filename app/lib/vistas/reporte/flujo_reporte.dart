import 'package:flutter/material.dart';

import '../../datos/estado.dart';
import '../../datos/tipos.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/burbuja.dart';
import '../comun/zanqui_mascota.dart';
import 'borrador.dart';
import 'enviado.dart';
import 'paso_detalles.dart';
import 'paso_evidencia.dart';
import 'paso_tipo.dart';
import 'paso_ubicacion.dart';

/// Abre el flujo de reporte a pantalla completa. [tipo] llega elegido desde el inicio
/// (y entonces se empieza en «¿Dónde?»).
Future<void> abrirReporte(BuildContext context, {TipoAmenaza? tipo}) {
  final estado = Zanqui.leer(context);
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      transitionDuration: Zm.largo,
      reverseTransitionDuration: Zm.medio,
      pageBuilder: (_, _, _) => FlujoReporte(estado: estado, tipo: tipo),
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
  const FlujoReporte({super.key, required this.estado, this.tipo});
  final EstadoZanqui estado;
  final TipoAmenaza? tipo;

  @override
  State<FlujoReporte> createState() => _FlujoReporteState();
}

class _FlujoReporteState extends State<FlujoReporte> {
  late final Borrador _b = Borrador(widget.estado, tipo: widget.tipo);
  late final PageController _paginas = PageController(initialPage: widget.tipo == null ? 0 : 1);
  late int _paso = widget.tipo == null ? 0 : 1;

  static const _pasos = ['Qué viste', 'Dónde', 'Foto', 'Detalles'];

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
        1 => _b.punto != null,
        _ => true,
      };

  void _ir(int paso) {
    FocusScope.of(context).unfocus();
    setState(() => _paso = paso);
    _paginas.animateToPage(paso, duration: Zm.medio, curve: Zm.entrar);
  }

  Future<void> _siguiente() async {
    if (_paso < 3) {
      _ir(_paso + 1);
      return;
    }
    vibrar(Vibracion.media);
    final r = await _b.enviar();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      transitionDuration: Zm.largo,
      pageBuilder: (_, _, _) => ReporteEnviado(reporteId: r.id),
      transitionsBuilder: (_, a, _, hijo) => FadeTransition(opacity: a, child: hijo),
    ));
  }

  Future<void> _cerrar() async {
    if (!_b.tieneAlgo || await _confirmarDescartar()) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmarDescartar() async {
    vibrar(Vibracion.media);
    final r = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x8C0B2E24),
      builder: (_) => const _DialogoDescartar(),
    );
    return r ?? false;
  }

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
                    ZanquiMascota(tamano: 62, animo: _animo),
                    const SizedBox(width: 12),
                    Expanded(child: BurbujaZanqui(texto: _frase)),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _paginas,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    PasoTipo(borrador: _b, onElegido: () => _ir(1)),
                    PasoUbicacion(borrador: _b),
                    PasoEvidencia(borrador: _b),
                    PasoDetalles(borrador: _b),
                  ],
                ),
              ),
              _BarraAccion(
                abajo: abajo,
                texto: switch (_paso) {
                  0 => 'Elige qué viste',
                  1 => _b.punto != null
                      ? 'Usar este punto'
                      : (_b.gps == EstadoGps.buscando ? 'Buscando tu ubicación…' : 'Toca el mapa para marcar'),
                  2 => _b.foto == null ? 'Seguir sin foto' : 'Seguir',
                  _ => !widget.estado.servidor.configurado
                      ? 'Guardar reporte (demostración)'
                      : (widget.estado.enLinea ? 'Enviar a la CRA' : 'Guardar y enviar con señal'),
                },
                icono: _paso == 3 ? Icons.send_rounded : Icons.arrow_forward_rounded,
                secundario: _paso == 2 && _b.foto == null,
                cargando: _b.enviando,
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
                        AnimatedFractionallySizedBox(
                          duration: Zm.medio,
                          curve: Zm.entrar,
                          widthFactor: i <= paso ? 1 : 0,
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
    this.secundario = false,
    this.cargando = false,
  });
  final double abajo;
  final String texto;
  final IconData icono;
  final VoidCallback? onTap;
  final bool secundario;
  final bool cargando;

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
        child: BotonZ(texto: texto, icono: icono, secundario: secundario, cargando: cargando, onTap: onTap),
      ),
    );
  }
}

class _DialogoDescartar extends StatelessWidget {
  const _DialogoDescartar();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Zr.l)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ZanquiMascota(tamano: 70, animo: Animo.preocupado),
            const SizedBox(height: 10),
            Text('¿Descartar este reporte?', style: tt.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Lo que llevas no se guarda. Si algo está pasando, la CRA necesita saberlo.',
                style: tt.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            BotonZ(texto: 'Seguir reportando', onTap: () => Navigator.pop(context, false)),
            const SizedBox(height: 8),
            BotonZ(
              texto: 'Descartar',
              secundario: true,
              color: Zc.prioridad[5]!,
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
  }
}
