import '../../nucleo/kit/ruta_borde.dart';
import 'package:flutter/material.dart';

import '../../datos/experiencia/jornada.dart';
import '../../datos/experiencia/participacion.dart';
import '../../datos/experiencia/trivia.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';
import 'piezas.dart';

Future<void> abrirRetoZanky(BuildContext context, EventoZanky evento) => Navigator.of(context).push(
      RutaBorde<void>(
        sinMovimiento: MediaQuery.disableAnimationsOf(context),
        settings: const RouteSettings(name: 'reto_zanky'),
        builder: (_) => RetoZanky(evento: evento),
      ),
    );

/// El reto del manglar: 5 preguntas, con explicación y fuente. Suma 10 puntos por acierto,
/// pero solo cuando mejora el mejor resultado de este evento.
class RetoZanky extends StatefulWidget {
  const RetoZanky({super.key, required this.evento, this.almacen});
  final EventoZanky evento;
  final AlmacenParticipacion? almacen;

  @override
  State<RetoZanky> createState() => _RetoZankyState();
}

class _RetoZankyState extends State<RetoZanky> {
  late final AlmacenParticipacion _almacen = widget.almacen ?? AlmacenParticipacion.instancia;
  late List<PreguntaReto> _preguntas = retoPara(widget.evento.codigo);
  int _i = 0;
  int? _elegida;
  int _aciertos = 0;
  int _errores = 0; // dispara la sacudida
  bool _fin = false;
  int _nuevos = 0;
  int _mejorPrevio = 0;

  PreguntaReto get _p => _preguntas[_i];

  @override
  void initState() {
    super.initState();
    _almacen.cargar().then((_) {
      if (mounted) setState(() => _mejorPrevio = _almacen.mejorReto(widget.evento.codigo));
    });
  }

  void _elegir(int k) {
    if (_elegida != null) return;
    final bien = k == _p.correcta;
    vibrar(bien ? Vibracion.ligera : Vibracion.fuerte);
    setState(() {
      _elegida = k;
      if (bien) {
        _aciertos++;
      } else {
        _errores++;
      }
    });
  }

  Future<void> _siguiente() async {
    if (_i < _preguntas.length - 1) {
      setState(() {
        _i++;
        _elegida = null;
      });
      return;
    }
    await _almacen.cargar();
    final previo = _almacen.mejorReto(widget.evento.codigo);
    final nuevos = await _almacen.guardarReto(widget.evento.codigo, _aciertos);
    if (!mounted) return;
    setState(() {
      _mejorPrevio = previo;
      _nuevos = nuevos;
      _fin = true;
    });
  }

  void _repetir() => setState(() {
        _preguntas = retoPara(widget.evento.codigo);
        _i = 0;
        _elegida = null;
        _aciertos = 0;
        _fin = false;
        _nuevos = 0;
      });

  @override
  Widget build(BuildContext context) {
    final rapido = sinMovimiento(context);
    return Scaffold(
      backgroundColor: Zc.arena,
      body: SafeArea(
        child: Column(
          children: [
            const BarraEvento(titulo: 'Reto del manglar', icono: Icons.arrow_back_rounded, etiqueta: 'Volver'),
            Expanded(
              child: AnimatedSwitcher(
                duration: rapido ? Duration.zero : Zm.medio,
                switchInCurve: Zm.entrar,
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a), child: c),
                ),
                child: _fin ? _resultado(context) : _pregunta(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pregunta(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final p = _p;
    final respondida = _elegida != null;
    final bien = respondida && _elegida == p.correcta;
    return ListView(
      key: ValueKey('p$_i'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            // Pregunta a la izquierda y aciertos pegados a la derecha (con Flexible + Expanded quedaba un hueco
            // y los aciertos flotaban en el centro).
            Expanded(
              child: Text('Pregunta ${_i + 1} de ${_preguntas.length}', style: tt.labelMedium?.copyWith(color: Zc.hoja)),
            ),
            const SizedBox(width: 8),
            Text('$_aciertos ${_aciertos == 1 ? 'acierto' : 'aciertos'}', style: tt.labelMedium),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (_i + (respondida ? 1 : 0)) / _preguntas.length),
            duration: sinMovimiento(context) ? Duration.zero : Zm.medio,
            curve: Zm.entrar,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: Zc.linea,
              color: Zc.hoja,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Semantics(header: true, child: Text(p.enunciado, style: tt.titleLarge?.copyWith(height: 1.25))),
        const SizedBox(height: 16),
        for (var k = 0; k < p.opciones.length; k++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Sacudida(
              disparos: _elegida == k && k != p.correcta ? _errores : 0,
              child: _Opcion(
                texto: p.opciones[k],
                estado: !respondida
                    ? _EstadoOpcion.libre
                    : k == p.correcta
                        ? _EstadoOpcion.correcta
                        : k == _elegida
                            ? _EstadoOpcion.errada
                            : _EstadoOpcion.apagada,
                onTap: respondida ? null : () => _elegir(k),
              ),
            ),
          ),
        AnimatedSize(
          duration: sinMovimiento(context) ? Duration.zero : Zm.medio,
          curve: Zm.entrar,
          alignment: Alignment.topCenter,
          child: !respondida
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: bien ? Zc.hojaClara : Zc.solClaro,
                          borderRadius: BorderRadius.circular(Zr.m),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bien ? '¡Muy bien!' : 'Casi. La respuesta era «${p.respuestaCorrecta}».', style: tt.titleSmall),
                            const SizedBox(height: 4),
                            Text(p.explicacion, style: tt.bodyMedium?.copyWith(color: Zc.texto)),
                            const SizedBox(height: 6),
                            Text('Fuente: ${p.fuente}', style: tt.bodySmall?.copyWith(fontSize: 11.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      BotonEstado(
                        texto: _i < _preguntas.length - 1 ? 'Siguiente' : 'Ver mi resultado',
                        icono: Icons.arrow_forward_rounded,
                        onTap: _siguiente,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _resultado(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final n = _preguntas.length;
    final (animo, titulo, mensaje) = switch (_aciertos) {
      final a when a == n => (Animo.celebrando, '¡Perfecto!', 'Respondiste todo bien: eres guardián del manglar de verdad.'),
      final a when a >= n - 2 => (Animo.feliz, '¡Muy bien!', 'Casi todo correcto. Con las explicaciones ya sabes más que ayer.'),
      final a when a >= 1 => (Animo.curioso, 'Vas aprendiendo', 'Repite el reto: el manglar tiene muchas cosas por descubrir.'),
      _ => (Animo.preocupado, 'Esta vez no fue', 'No pasa nada. Lee las explicaciones y vuelve a intentarlo.'),
    };
    final mejoro = _nuevos > 0;
    return ListView(
      key: const ValueKey('resultado'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Center(child: ZankyMascota(tamano: 150, animo: animo)),
        const SizedBox(height: 8),
        Text(titulo, textAlign: TextAlign.center, style: tt.headlineSmall),
        const SizedBox(height: 6),
        Text(mensaje, textAlign: TextAlign.center, style: tt.bodyMedium),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Zr.l)),
          child: Column(
            children: [
              Text('$_aciertos de $n', style: tt.displaySmall),
              Text('aciertos', style: tt.bodySmall),
              const SizedBox(height: 10),
              Pildora(
                mejoro
                    ? '+$_nuevos puntos'
                    : _mejorPrevio >= _aciertos && _mejorPrevio > 0
                        ? 'Sin puntos nuevos: tu mejor es $_mejorPrevio'
                        : 'Sin puntos esta vez',
                color: mejoro ? Zc.hoja : Zc.textoSuave,
                icono: mejoro ? Icons.stars_rounded : Icons.info_outline_rounded,
              ),
              const SizedBox(height: 8),
              Text(
                'Cada acierto da ${AlmacenParticipacion.puntosPorAcierto} puntos, y solo suma cuando mejoras tu mejor resultado.',
                textAlign: TextAlign.center,
                style: tt.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        BotonEstado(texto: 'Repetir el reto', icono: Icons.replay_rounded, onTap: _repetir),
        const SizedBox(height: 10),
        BotonEstado(texto: 'Volver al evento', secundario: true, onTap: () => Navigator.of(context).maybePop()),
      ],
    );
  }
}

enum _EstadoOpcion { libre, correcta, errada, apagada }

class _Opcion extends StatelessWidget {
  const _Opcion({required this.texto, required this.estado, required this.onTap});
  final String texto;
  final _EstadoOpcion estado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (fondo, borde, tinta) = switch (estado) {
      _EstadoOpcion.libre => (Colors.white, Zc.linea, Zc.texto),
      _EstadoOpcion.correcta => (Zc.hojaClara, Zc.hoja, Zc.raizSuave),
      _EstadoOpcion.errada => (const Color(0xFFFBE4E4), Zc.prioridad[5]!, Zc.texto),
      _EstadoOpcion.apagada => (Colors.white, Zc.linea, Zc.textoTenue),
    };
    final marca = switch (estado) {
      _EstadoOpcion.correcta => const CheckDibujado(tamano: 26, color: Zc.hoja),
      _EstadoOpcion.errada => Icon(Icons.close_rounded, color: Zc.prioridad[5], size: 26),
      _ => null,
    };
    final etiqueta = switch (estado) {
      _EstadoOpcion.correcta => '$texto, respuesta correcta',
      _EstadoOpcion.errada => '$texto, respuesta incorrecta',
      _ => texto,
    };
    return Presionable(
      onTap: onTap,
      etiqueta: etiqueta,
      escala: 0.98,
      child: AnimatedContainer(
        duration: sinMovimiento(context) ? Duration.zero : Zm.corto,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(Zr.m),
          border: Border.all(color: borde, width: estado == _EstadoOpcion.libre || estado == _EstadoOpcion.apagada ? 1.2 : 2),
        ),
        child: Row(
          children: [
            Expanded(child: Text(texto, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: tinta, fontSize: 15.5))),
            if (marca != null) ...[const SizedBox(width: 10), marca],
          ],
        ),
      ),
    );
  }
}
