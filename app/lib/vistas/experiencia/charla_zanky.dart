import '../../nucleo/kit/ruta_borde.dart';
import 'package:flutter/material.dart';

import '../../datos/experiencia/dictado.dart';
import '../../datos/experiencia/ia_zanky.dart';
import '../../datos/experiencia/jornada.dart';
import '../../datos/experiencia/preguntas_zanky.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';
import 'piezas.dart';

Future<void> abrirCharlaZanky(BuildContext context, EventoZanky evento) => Navigator.of(context).push(
      RutaBorde<void>(
        sinMovimiento: MediaQuery.disableAnimationsOf(context),
        settings: const RouteSettings(name: 'charla_zanky'),
        builder: (_) => CharlaZanky(evento: evento),
      ),
    );

class _Mensaje {
  _Mensaje.yo(this.texto)
      : esZanky = false,
        fuente = null,
        encontrada = true;
  _Mensaje.zanky(this.texto, {this.fuente, this.encontrada = true}) : esZanky = true;
  final String texto;
  final bool esZanky, encontrada;
  final String? fuente;
}

/// Chat con Zanky: responde sin conexión con preguntas frecuentes; con IA solo si está conectada.
class CharlaZanky extends StatefulWidget {
  const CharlaZanky({super.key, required this.evento, this.ia, this.dictado, this.pausaEscribiendo = const Duration(milliseconds: 700)});
  final EventoZanky evento;
  final IaZanky? ia;
  final Dictado? dictado;

  /// Cuánto se ve «escribiendo…» antes de la respuesta sin conexión.
  final Duration pausaEscribiendo;

  @override
  State<CharlaZanky> createState() => _CharlaZankyState();
}

class _CharlaZankyState extends State<CharlaZanky> {
  late final IaZanky _ia = widget.ia ?? IaZanky();
  late final Dictado _dictado = widget.dictado ?? crearDictado();
  bool _escuchando = false;

  /// null: aún no se sabe; true: la IA respondió; false: falló y se responde sin conexión.
  bool? _iaEnLinea;
  DateTime? _iaFallo;
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  final _foco = FocusNode();
  final _mensajes = <_Mensaje>[];
  List<String> _sugerencias = sugerenciasIniciales;
  bool _escribiendo = false;
  Animo _animo = Animo.feliz;

  @override
  void initState() {
    super.initState();
    _mensajes.add(_Mensaje.zanky(
      widget.evento.generico
          ? '¡Hola! Pregúntame lo que quieras del manglar del Atlántico.'
          : '¡Hola! Pregúntame lo que quieras del manglar o de «${widget.evento.titulo}».',
    ));
  }

  @override
  void dispose() {
    _texto.dispose();
    _scroll.dispose();
    _foco.dispose();
    if (_escuchando) _dictado.detener();
    super.dispose();
  }

  Future<void> _preguntar(String pregunta) async {
    final p = pregunta.trim();
    if (p.isEmpty || _escribiendo) return;
    _texto.clear();
    setState(() {
      _mensajes.add(_Mensaje.yo(p));
      _escribiendo = true;
      _animo = Animo.curioso;
    });
    _bajar();
    final pausa = Future<void>.delayed(widget.pausaEscribiendo);
    // Tras un fallo no se reintenta en 45 s: sin señal, cada pregunta responde al instante sin conexión.
    final reposo = _iaFallo != null && DateTime.now().difference(_iaFallo!) < const Duration(seconds: 45);
    final historial = [for (final m in _mensajes.skip(1).take(_mensajes.length - 2)) (esZanky: m.esZanky, texto: m.texto)];
    final deIa = reposo ? null : await _ia.preguntar(p, evento: widget.evento, historial: historial);
    if (_ia.conectada && !reposo) {
      _iaEnLinea = deIa != null;
      _iaFallo = deIa == null ? DateTime.now() : null;
    }
    final local = responderSinConexion(p, evento: widget.evento);
    await pausa;
    if (!mounted) return;
    setState(() {
      _escribiendo = false;
      if (deIa != null) {
        _mensajes.add(_Mensaje.zanky(deIa, fuente: 'IA de Zanky (puede equivocarse)'));
        _animo = animoDeTexto(deIa);
        _sugerencias = local.sugerencias;
      } else {
        _mensajes.add(_Mensaje.zanky(local.texto, fuente: local.fuente, encontrada: local.encontrada));
        _animo = animoDe(local.tono);
        _sugerencias = local.sugerencias.isEmpty ? sugerenciasIniciales : local.sugerencias;
      }
    });
    _bajar();
  }

  Future<void> _dictar() async {
    if (_escuchando) {
      _dictado.detener();
      return;
    }
    setState(() => _escuchando = true);
    final t = await _dictado.escuchar();
    if (!mounted) return;
    setState(() => _escuchando = false);
    if (t != null) {
      _texto.text = t;
      await _preguntar(t);
    }
  }

  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final fin = _scroll.position.maxScrollExtent;
      if (sinMovimiento(context)) {
        _scroll.jumpTo(fin);
      } else {
        _scroll.animateTo(fin, duration: Zm.medio, curve: Zm.entrar);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Zc.arena,
      body: SafeArea(
        child: Column(
          children: [
            const BarraEvento(titulo: 'Habla con Zanky', icono: Icons.arrow_back_rounded, etiqueta: 'Volver'),
            _Aviso(conectada: _ia.conectada, enLinea: _iaEnLinea),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                children: [
                  Center(child: ZankyMascota(tamano: 84, animo: _animo)),
                  const SizedBox(height: 8),
                  for (final m in _mensajes) _Globo(m),
                  if (_escribiendo) const _Escribiendo(),
                ],
              ),
            ),
            if (_sugerencias.isNotEmpty && !_escribiendo)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final s in _sugerencias.take(6)) _Chip(s, () => _preguntar(s))],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _texto,
                      focusNode: _foco,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _preguntar,
                      maxLength: 200,
                      style: tt.bodyLarge,
                      decoration: InputDecoration(
                        hintText: _escuchando ? 'Te escucho…' : 'Escribe tu pregunta',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  if (_dictado.disponible) ...[
                    const SizedBox(width: 8),
                    Presionable(
                      onTap: _dictar,
                      etiqueta: _escuchando ? 'Dejar de escuchar' : 'Preguntar con la voz',
                      child: AnimatedContainer(
                        duration: Zm.corto,
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _escuchando ? Zc.carnavalRojo : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Zc.hoja.withValues(alpha: 0.35)),
                        ),
                        child: Icon(_escuchando ? Icons.stop_rounded : Icons.mic_rounded,
                            color: _escuchando ? Colors.white : Zc.hoja),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Presionable(
                    onTap: () => _preguntar(_texto.text),
                    etiqueta: 'Enviar pregunta',
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(color: Zc.hoja, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.conectada, required this.enLinea});
  final bool conectada;
  final bool? enLinea;

  @override
  Widget build(BuildContext context) {
    final viva = conectada && enLinea != false;
    final color = enLinea == true ? Zc.hoja : Zc.textoSuave;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Semantics(
        container: true,
        child: Row(
          children: [
            Icon(viva ? Icons.bolt_rounded : Icons.offline_bolt_outlined, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                !conectada
                    ? 'Respondo con lo que sé, sin internet.'
                    : switch (enLinea) {
                        true => 'IA de Zanky en línea. Sin señal también respondo.',
                        false => 'La IA no responde ahora: te contesto con lo que sé, sin internet.',
                        null => 'Con señal respondo con IA; sin ella, con lo que sé.',
                      },
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Globo extends StatelessWidget {
  const _Globo(this.m);
  final _Mensaje m;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final ancho = MediaQuery.sizeOf(context).width * 0.82;
    final globo = Container(
      constraints: BoxConstraints(maxWidth: ancho),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: m.esZanky ? Colors.white : Zc.hoja,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(Zr.m),
          topRight: const Radius.circular(Zr.m),
          bottomLeft: Radius.circular(m.esZanky ? 4 : Zr.m),
          bottomRight: Radius.circular(m.esZanky ? Zr.m : 4),
        ),
        boxShadow: const [BoxShadow(color: Color(0x100B2E24), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.texto, style: tt.bodyLarge?.copyWith(color: m.esZanky ? Zc.texto : Colors.white, fontWeight: FontWeight.w500)),
          if (m.fuente != null) ...[
            const SizedBox(height: 6),
            Text('Fuente: ${m.fuente}', style: tt.bodySmall?.copyWith(fontSize: 11.5, color: Zc.textoTenue)),
          ],
        ],
      ),
    );
    final animado = sinMovimiento(context)
        ? globo
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Zm.medio,
            curve: Zm.entrar,
            builder: (_, t, hijo) => Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: hijo),
            ),
            child: globo,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Align(
        alignment: m.esZanky ? Alignment.centerLeft : Alignment.centerRight,
        child: Semantics(
          container: true,
          label: m.esZanky ? 'Zanky dice' : 'Tú dijiste',
          child: animado,
        ),
      ),
    );
  }
}

/// Tres puntos que suben y bajan: «Zanky está escribiendo…».
class _Escribiendo extends StatefulWidget {
  const _Escribiendo();
  @override
  State<_Escribiendo> createState() => _EscribiendoState();
}

class _EscribiendoState extends State<_Escribiendo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iniciado && !sinMovimiento(context)) {
      _iniciado = true;
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          liveRegion: true,
          label: 'Zanky está escribiendo',
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Zr.m)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _c,
                    builder: (_, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Container(
                            width: 8,
                            height: 8,
                            margin: EdgeInsets.only(right: i < 2 ? 5 : 10, bottom: _salto(i)),
                            decoration: const BoxDecoration(color: Zc.hoja, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  ),
                  Text('escribiendo…', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _salto(int i) {
    if (!_iniciado) return 0;
    final t = (_c.value - i * 0.15) % 1.0;
    return t < 0.4 ? 6 * (1 - (t / 0.2 - 1).abs()) : 0;
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.texto, this.onTap);
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Presionable(
      onTap: onTap,
      etiqueta: texto,
      escala: 0.95,
      child: Container(
        constraints: BoxConstraints(minHeight: 44, maxWidth: MediaQuery.sizeOf(context).width - 32),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Zc.hojaClara,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Zc.hoja.withValues(alpha: 0.35)),
        ),
        child: Text(texto, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Zc.raizSuave)),
      ),
    );
  }
}
