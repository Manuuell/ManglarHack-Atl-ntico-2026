import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../datos/prioridad.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/comunes.dart';
import 'modelo.dart';

/// Caja de cada marcador: deja sitio al anillo que late y da un área de toque de 56 px.
const double cajaMarcador = 56;

/// Tinta que se lee sobre un color de prioridad (el blanco no se ve sobre el amarillo).
Color tintaSobre(Color fondo) => fondo.computeLuminance() > 0.33 ? Zc.raiz : Colors.white;

/// Un reporte en el mapa: círculo del color de su prioridad con el ícono de su tipo.
/// Los míos llevan borde blanco grueso; los que siguen solo en el teléfono, borde
/// punteado de sol («aún no enviado»); los de las últimas 3 h laten.
class MarcadorPunto extends StatelessWidget {
  const MarcadorPunto({
    super.key,
    required this.punto,
    required this.latido,
    required this.latir,
    required this.reciente,
    required this.alTocar,
  });

  final PuntoMapa punto;

  /// Un solo reloj para todos los marcadores (0 → 1 cada ciclo).
  final Animation<double> latido;

  /// Falso con «reducir movimiento»: el anillo queda quieto y tenue.
  final bool latir;
  final bool reciente;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final color = Zc.dePrioridad(punto.prioridad);
    final d = punto.esMio ? 40.0 : 34.0;
    final etiqueta = '${punto.tipo.nombre}, prioridad ${Prioridad.nombres[punto.prioridad]}, '
        '${haceCuanto(punto.capturadoEn)}'
        '${punto.esMio ? ', es tu reporte' : ''}'
        '${punto.enCola ? ', aún no enviado' : ''}. Toca para ver más';
    return Semantics(
      button: true,
      label: etiqueta,
      excludeSemantics: true,
      onTap: alTocar,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          vibrar(Vibracion.seleccion);
          alTocar();
        },
        child: SizedBox(
          width: cajaMarcador,
          height: cajaMarcador,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (reciente)
                RepaintBoundary(
                  child: CustomPaint(
                    size: const Size.square(cajaMarcador),
                    painter: _AnilloPainter(
                      latir ? latido : const AlwaysStoppedAnimation(0.45),
                      color,
                      d,
                      latir ? (punto.id.hashCode & 0xFF) / 255.0 : 0,
                    ),
                  ),
                ),
              RepaintBoundary(
                child: SizedBox.square(
                  dimension: d,
                  child: CustomPaint(
                    painter: DiscoPainter(color: color, mio: punto.esMio, enCola: punto.enCola),
                    child: Center(
                      child: Icon(punto.tipo.icono, size: d * 0.5, color: tintaSobre(color)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Varios reportes en un solo círculo con su número; el color es el de la prioridad
/// más alta que esconde. Al tocarlo, el mapa se acerca.
class MarcadorGrupo extends StatelessWidget {
  const MarcadorGrupo({super.key, required this.grupo, required this.alTocar});
  final GrupoMapa grupo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final color = Zc.dePrioridad(grupo.prioridadMax);
    final n = grupo.puntos.length;
    return Semantics(
      button: true,
      label: '$n reportes juntos, la prioridad más alta es '
          '${Prioridad.nombres[grupo.prioridadMax]}. Toca para acercar el mapa',
      excludeSemantics: true,
      onTap: alTocar,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          vibrar(Vibracion.seleccion);
          alTocar();
        },
        child: Center(
          child: RepaintBoundary(
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: grupo.hayMio ? 4 : 3),
                boxShadow: const [BoxShadow(color: Color(0x4D0B2E24), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: Text(
                n > 99 ? '99+' : '$n',
                maxLines: 1,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: tintaSobre(color), height: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mi ubicación: el punto azul de siempre (el azul es la convención de «estás aquí»).
class PuntoYo extends StatelessWidget {
  const PuntoYo({super.key});

  static const azul = Color(0xFF2F6FED);

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Tu ubicación',
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: azul,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3.5),
              boxShadow: const [BoxShadow(color: Color(0x592F6FED), blurRadius: 10)],
            ),
          ),
        ),
      );
}

/// Una zona con el mapa lejos: solo una hojita en un círculo (sin texto, para que las
/// cuatro no se apilen sobre la costa). Se toca para abrir la hoja; el nombre va en el
/// chip de arriba y en la hoja. De cerca, el polígono habla solo.
class EtiquetaZona extends StatelessWidget {
  const EtiquetaZona({super.key, required this.nombre, required this.alTocar});
  final String nombre;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) => Presionable(
        etiqueta: 'Zona de manglar: $nombre. Toca para ver sus datos',
        onTap: alTocar,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              shape: BoxShape.circle,
              border: Border.all(color: Zc.hoja, width: 2),
              boxShadow: const [BoxShadow(color: Color(0x290B2E24), blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: const Icon(Icons.eco_rounded, size: 19, color: Zc.hoja),
          ),
        ),
      );
}

/// El círculo del marcador: relleno, borde y, si falta enviarlo, punteado de sol.
class DiscoPainter extends CustomPainter {
  const DiscoPainter({required this.color, this.mio = false, this.enCola = false});
  final Color color;
  final bool mio;
  final bool enCola;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final borde = mio ? 4.0 : 2.5;
    canvas.drawShadow(Path()..addOval(Rect.fromCircle(center: c, radius: r - 1)), const Color(0xFF0B2E24), 3, true);
    canvas.drawCircle(c, r, Paint()..color = color);
    final radioBorde = r - borde / 2;
    canvas.drawCircle(
      c,
      radioBorde,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borde
        ..color = Colors.white,
    );
    if (enCola) {
      // Punteado de sol sobre el borde blanco: los huecos dejan ver el blanco.
      const tramos = 12;
      const paso = 2 * math.pi / tramos;
      final pincel = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borde
        ..strokeCap = StrokeCap.butt
        ..color = Zc.sol;
      final caja = Rect.fromCircle(center: c, radius: radioBorde);
      for (var i = 0; i < tramos; i++) {
        canvas.drawArc(caja, i * paso, paso * 0.55, false, pincel);
      }
    }
  }

  @override
  bool shouldRepaint(DiscoPainter old) => old.color != color || old.mio != mio || old.enCola != enCola;
}

/// El anillo que se expande y se apaga. Se repinta con el reloj compartido, sin
/// reconstruir ningún widget.
class _AnilloPainter extends CustomPainter {
  _AnilloPainter(this.t, this.color, this.base, this.fase) : super(repaint: t);
  final Animation<double> t;
  final Color color;
  final double base;
  final double fase;

  @override
  void paint(Canvas canvas, Size size) {
    final v = (t.value + fase) % 1.0;
    final c = size.center(Offset.zero);
    final desde = base / 2;
    final hasta = size.width / 2;
    final r = desde + (hasta - desde) * Curves.easeOut.transform(v);
    final alfa = (1 - v) * 0.5;
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: alfa * 0.45));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: alfa),
    );
  }

  @override
  bool shouldRepaint(_AnilloPainter old) =>
      old.color != color || old.base != base || old.fase != fase || old.t != t;
}
