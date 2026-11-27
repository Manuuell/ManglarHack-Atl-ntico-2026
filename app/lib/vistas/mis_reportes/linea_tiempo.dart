import 'package:flutter/material.dart';

import '../../datos/estado.dart';
import '../../datos/reporte.dart';
import '../../datos/tipos.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/tema.dart';
import '../comun/comunes.dart';
import 'tarjeta_reporte.dart' show indiceAlcanzado;

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// «27 nov 2026, 14:05» (hora del teléfono).
String fechaLarga(DateTime t) {
  final l = t.toLocal();
  final hm = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  return '${l.day} ${_meses[l.month - 1]} ${l.year}, $hm';
}

/// El servidor dijo que no a este reporte (reintentar tal cual no lo arregla).
bool envioRechazado(Reporte r) => r.envio == Envio.rechazado;

/// El motivo que dio el servidor, o una frase honesta si no dijo ninguno.
String textoMotivoRechazo(Reporte r) {
  final m = (r.motivoRechazo ?? '').trim();
  return m.isEmpty ? 'El servidor no aceptó este reporte.' : m;
}

/// La nota con la que el teléfono apunta «Recibido» al crear el reporte: es un apunte
/// local, no un aviso de la CRA, y no debe salir como si lo fuera.
bool _notaLocal(CambioEstado c) => c.nota?.trim() == 'Creado en el teléfono';

enum _Fase { hecho, actual, futuro }

class _Paso {
  const _Paso({
    required this.titulo,
    required this.fase,
    required this.color,
    required this.icono,
    this.detalle,
    this.fecha,
  });
  final String titulo;
  final String? detalle;
  final DateTime? fecha;
  final _Fase fase;
  final Color color;
  final IconData icono;
}

/// El camino del reporte, de «guardado en tu teléfono» hasta «cerrado»: lo que ya
/// pasó en color y con su fecha, lo de ahora latiendo suave, lo que falta en gris
/// con lo que significa.
class LineaTiempo extends StatelessWidget {
  const LineaTiempo({super.key, required this.reporte});
  final Reporte reporte;

  CambioEstado? _cambio(EstadoReporte s) {
    for (final c in reporte.historial.reversed) {
      // El apunte local de «Recibido» (hora de captura) no vale: «Recibido» lo dice la CRA.
      if (c.estado == s && !(s == EstadoReporte.recibido && _notaLocal(c))) return c;
    }
    return null;
  }

  List<_Paso> _pasos(BuildContext context) {
    final r = reporte;
    final demo = !Zanky.de(context).servidor.configurado;
    final enviado = r.envio == Envio.enviado;
    final pasos = <_Paso>[
      _Paso(
        titulo: 'Guardado en tu teléfono',
        detalle: r.capturadoSinSenal ? 'Lo guardaste sin señal: queda seguro hasta poder enviarlo.' : null,
        fecha: r.capturadoEn,
        fase: _Fase.hecho,
        color: Zc.cienaga,
        icono: Icons.phone_android_rounded,
      ),
      if (enviado)
        _Paso(
          titulo: 'Enviado a la CRA',
          fecha: r.enviadoEn,
          fase: _Fase.hecho,
          color: Zc.cienaga,
          icono: Icons.cloud_done_rounded,
        )
      else if (envioRechazado(r))
        _Paso(
          titulo: 'No se pudo enviar',
          detalle: '${textoMotivoRechazo(r)}\n'
              'Reintentar tal cual no lo arregla: revisa los datos, o haz uno nuevo.',
          fase: _Fase.actual,
          color: Zc.fango,
          icono: Icons.error_outline_rounded,
        )
      else
        _Paso(
          titulo: r.envio == Envio.enviando
              ? 'Enviando a la CRA'
              : (demo ? 'Modo demostración' : 'Esperando señal'),
          detalle: switch (r.envio) {
            _ when demo => 'En esta versión de prueba el reporte se queda en el teléfono; conectada, sale sola a la CRA.',
            Envio.enviando => 'Un momento, ya va en camino.',
            Envio.error => 'No se pudo enviar todavía. Lo intento de nuevo solo; no se pierde.',
            _ => 'Se envía solo apenas haya señal. No tienes que hacer nada.',
          },
          fase: _Fase.actual,
          color: Zc.sol,
          icono: r.envio == Envio.enviando ? Icons.cloud_upload_rounded : Icons.signal_cellular_alt_rounded,
        ),
    ];

    final alcanzado = indiceAlcanzado(r);
    final descartado = r.estado == EstadoReporte.descartado;
    final camino = EstadoReporte.camino;
    for (var i = 0; i < camino.length; i++) {
      final s = camino[i];
      final cambio = _cambio(s);
      final nota = (cambio?.nota ?? '').trim();
      if (i <= alcanzado) {
        // El último paso alcanzado es «el de ahora», salvo que el caso ya se cerró
        // o se descartó: ahí no hay nada esperándose.
        final actual = i == alcanzado && !descartado && s != EstadoReporte.cerrado;
        final lineas = [if (actual) s.explicacion, if (nota.isNotEmpty) nota];
        pasos.add(_Paso(
          titulo: s.nombre,
          detalle: lineas.isEmpty ? null : lineas.join('\n'),
          // «Recibido» sin aviso real de la CRA: la hora en que salió del teléfono.
          fecha: cambio?.fecha ?? (s == EstadoReporte.recibido ? r.enviadoEn : null),
          fase: actual ? _Fase.actual : _Fase.hecho,
          color: ChipEstado.colorDe(s),
          icono: ChipEstado.iconoDe(s),
        ));
      } else if (!descartado) {
        pasos.add(_Paso(
          titulo: s.nombre,
          detalle: s.explicacion,
          fase: _Fase.futuro,
          color: Zc.textoTenue,
          icono: ChipEstado.iconoDe(s),
        ));
      }
    }
    if (descartado) {
      final cambio = _cambio(EstadoReporte.descartado);
      pasos.add(_Paso(
        titulo: EstadoReporte.descartado.nombre,
        detalle: EstadoReporte.descartado.explicacion,
        fecha: cambio?.fecha,
        fase: _Fase.hecho,
        color: Zc.textoTenue,
        icono: ChipEstado.iconoDe(EstadoReporte.descartado),
      ));
    }
    return pasos;
  }

  @override
  Widget build(BuildContext context) {
    final pasos = _pasos(context);
    return Column(
      children: [
        for (var i = 0; i < pasos.length; i++)
          _FilaPaso(
            paso: pasos[i],
            primero: i == 0,
            ultimo: i == pasos.length - 1,
            siguienteLlegado: i + 1 < pasos.length && pasos[i + 1].fase != _Fase.futuro,
          ),
      ],
    );
  }
}

class _FilaPaso extends StatelessWidget {
  const _FilaPaso({
    required this.paso,
    required this.primero,
    required this.ultimo,
    required this.siguienteLlegado,
  });
  final _Paso paso;
  final bool primero;
  final bool ultimo;
  final bool siguienteLlegado;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final futuro = paso.fase == _Fase.futuro;
    final p = paso;
    return Semantics(
      container: true,
      label: '${p.titulo}. ${futuro ? 'Todavía no' : p.fase == _Fase.actual ? 'Ahora' : 'Listo'}'
          '${p.fecha != null ? '. ${fechaLarga(p.fecha!)}' : ''}${p.detalle != null ? '. ${p.detalle}' : ''}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 30,
              child: Column(
                children: [
                  _Punto(paso: p),
                  if (!ultimo)
                    Expanded(
                      child: Container(
                        width: 3,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: siguienteLlegado && !futuro ? p.color.withValues(alpha: 0.55) : Zc.linea,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: ultimo ? 0 : 18, top: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.titulo,
                      style: tt.titleSmall?.copyWith(color: futuro ? Zc.textoTenue : Zc.texto),
                    ),
                    if (p.fecha != null)
                      Text(fechaLarga(p.fecha!), style: tt.bodySmall?.copyWith(color: Zc.textoSuave)),
                    if (p.detalle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.detalle!,
                        style: tt.bodySmall?.copyWith(color: futuro ? Zc.textoTenue : Zc.textoSuave),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.paso});
  final _Paso paso;

  @override
  Widget build(BuildContext context) {
    const d = 28.0;
    switch (paso.fase) {
      case _Fase.hecho:
        return Container(
          width: d,
          height: d,
          decoration: BoxDecoration(color: paso.color, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 17, color: Zc.superficie),
        );
      case _Fase.futuro:
        return Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Zc.linea, width: 2),
          ),
          child: Icon(paso.icono, size: 14, color: Zc.textoTenue),
        );
      case _Fase.actual:
        return _PuntoLatiendo(color: paso.color, icono: paso.icono);
    }
  }
}

/// El paso de ahora: un halo que respira despacio (un solo bucle en la pantalla, lento,
/// de escala y opacidad). Con «reducir movimiento» queda el halo quieto.
class _PuntoLatiendo extends StatefulWidget {
  const _PuntoLatiendo({required this.color, required this.icono});
  final Color color;
  final IconData icono;

  @override
  State<_PuntoLatiendo> createState() => _PuntoLatiendoState();
}

class _PuntoLatiendoState extends State<_PuntoLatiendo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  // La curva y los Tween se crean una vez: crearlos en build sumaba un listener al
  // controlador por cada reconstrucción.
  late final CurvedAnimation _curva = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  late final Animation<double> _escala = Tween(begin: 1.0, end: 1.65).animate(_curva);
  late final Animation<double> _opacidad = Tween(begin: 0.45, end: 0.0).animate(_curva);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.animationsDisabled) {
      _c.stop();
      _c.value = 0.4;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _curva.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ScaleTransition(
              scale: _escala,
              child: FadeTransition(
                opacity: _opacidad,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                ),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
              child: Icon(widget.icono, size: 15, color: Zc.superficie),
            ),
          ],
        ),
      ),
    );
  }
}
