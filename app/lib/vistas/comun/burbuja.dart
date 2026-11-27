import 'package:flutter/material.dart';

import '../../nucleo/tema.dart';

/// La burbuja de diálogo de Zanky. El texto nuevo entra con un fundido y un leve
/// desplazamiento; el alto se acomoda con animación para que nada salte.
class BurbujaZanky extends StatelessWidget {
  const BurbujaZanky({
    super.key,
    required this.texto,
    this.colaIzquierda = true,
    this.oscura = false,
    this.colaArriba = false,
  });

  final String texto;
  final bool colaIzquierda;
  final bool oscura;

  /// Cola en el centro de arriba, para cuando Zanky está encima de la burbuja (pantalla del evento).
  final bool colaArriba;

  @override
  Widget build(BuildContext context) {
    final fondo = oscura ? Zc.raizSuave : Colors.white;
    final tinta = oscura ? Colors.white : Zc.texto;
    return CustomPaint(
      painter: _Cola(fondo, colaIzquierda, arriba: colaArriba),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(Zr.m),
          boxShadow: const [BoxShadow(color: Color(0x140B2E24), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: AnimatedSize(
          duration: Zm.medio,
          curve: Zm.entrar,
          alignment: Alignment.topLeft,
          child: AnimatedSwitcher(
            duration: Zm.medio,
            switchInCurve: Zm.entrar,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(a),
                child: child,
              ),
            ),
            layoutBuilder: (actual, previos) => Stack(
              alignment: Alignment.topLeft,
              children: [...previos, ?actual],
            ),
            child: Text(
              texto,
              key: ValueKey(texto),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: tinta, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cola extends CustomPainter {
  _Cola(this.color, this.izquierda, {this.arriba = false});
  final Color color;
  final bool izquierda;
  final bool arriba;

  @override
  void paint(Canvas canvas, Size size) {
    if (arriba) {
      final cx = size.width / 2;
      final pico = Path()
        ..moveTo(cx - 12, 2)
        ..quadraticBezierTo(cx - 3, -1, cx, -11)
        ..quadraticBezierTo(cx + 3, -1, cx + 12, 2)
        ..close();
      canvas.drawPath(pico, Paint()..color = color);
      return;
    }
    final x = izquierda ? 0.0 : size.width;
    final d = izquierda ? -1.0 : 1.0;
    final y = size.height * 0.62;
    final cola = Path()
      ..moveTo(x - d * 2, y - 10)
      ..quadraticBezierTo(x + d * 10, y + 2, x + d * 12, y + 12)
      ..quadraticBezierTo(x + d * 2, y + 6, x - d * 4, y + 6)
      ..close();
    canvas.drawPath(cola, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Cola o) => o.color != color || o.izquierda != izquierda || o.arriba != arriba;
}

/// Lo que Zanky cuenta cuando lo tocas: concientizar sin sermonear.
/// Las cifras vienen de lo que dijo la CRA en el lanzamiento o de fuentes públicas.
abstract final class DatosZanky {
  static const todos = [
    '¡Ajá! Soy Zanky. Mis raíces parecen zancos, como los zanqueros del Carnaval.',
    'El manglar frena el oleaje y protege la costa cuando el mar sube.',
    'Guardamos carbono en el fango por siglos: somos de los bosques que más carbono atrapan.',
    'Necesito agua salada del mar y agua dulce de los caños. Si un caño se tapa, me ahogo de sal.',
    'Entre mis raíces crecen peces, cangrejos y camarones que alimentan a los pescadores.',
    'Soy resiliente: si me dejan tranquilo, vuelvo a brotar.',
    'En el Atlántico quedan unas 775 hectáreas de manglar, según la CRA. Cuidémoslas.',
    'Si ves algo raro, repórtalo de una: la CRA solo puede actuar sobre lo que pasa ahora.',
  ];
}
