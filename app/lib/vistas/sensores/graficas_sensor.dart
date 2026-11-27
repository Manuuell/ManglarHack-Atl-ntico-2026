/// Gráficas de las sondas: la chispa de las últimas horas y el medidor contra el umbral.
///
/// Tomadas de las gráficas de la app universitaria (`views/widgets/graficas/chispograma.dart` y
/// `medidor_semaforo.dart`): misma pintura (línea con relleno degradado, sin ejes; barra de un
/// valor con estado en texto e ícono además del color) y los mismos casos cuidados (lista vacía,
/// un punto, todos iguales, escala cero). Adaptadas a Zanky: colores de riesgo `Zc.dePrioridad`,
/// línea punteada del umbral en la chispa y marca del umbral en la barra.
library;

import 'package:flutter/material.dart';

import '../../datos/sensores/lecturas_sensor.dart';
import '../../nucleo/tema.dart';

/// Línea de tendencia compacta, con la línea del umbral si cae dentro del rango.
class ChispaSensor extends StatelessWidget {
  const ChispaSensor({
    super.key,
    required this.valores,
    required this.color,
    this.umbral,
    this.altura = 36,
    this.grosor = 2,
    this.etiqueta,
  });

  final List<double> valores;
  final Color color;
  final double? umbral;
  final double altura;
  final double grosor;
  final String? etiqueta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: etiqueta ?? (valores.isEmpty ? 'Sin lecturas para la gráfica' : 'Tendencia de ${valores.length} lecturas'),
      child: SizedBox(
        width: double.infinity,
        height: altura,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: PintorChispaSensor(valores: valores, color: color, grosor: grosor, umbral: umbral),
          ),
        ),
      ),
    );
  }
}

class PintorChispaSensor extends CustomPainter {
  const PintorChispaSensor({required this.valores, required this.color, required this.grosor, this.umbral});

  final List<double> valores;
  final Color color;
  final double grosor;
  final double? umbral;

  @override
  void paint(Canvas canvas, Size size) {
    if (valores.isEmpty || size.width <= 0 || size.height <= 0) return;
    if (valores.length == 1) {
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), grosor + 1, Paint()..color = color);
      return;
    }
    var minimo = valores.first;
    var maximo = valores.first;
    for (final v in valores.skip(1)) {
      if (v < minimo) minimo = v;
      if (v > maximo) maximo = v;
    }
    // El umbral entra en la escala si está cerca: así se ve cuánto falta para llegar.
    final u = umbral;
    if (u != null && u > maximo && u <= maximo + (maximo - minimo).abs() * 1.5 + 1e-9) maximo = u;
    final margen = grosor;
    final anchoUtil = size.width - margen * 2;
    final altoUtil = size.height - margen * 2;
    final rango = maximo - minimo;
    double y(double v) => rango <= 0 ? size.height / 2 : size.height - margen - (v - minimo) * altoUtil / rango;
    Offset punto(int i) => Offset(margen + i * anchoUtil / (valores.length - 1), y(valores[i]));

    if (u != null && rango > 0 && u >= minimo && u <= maximo) {
      final yu = y(u);
      final trazo = Paint()
        ..color = Zc.dePrioridad(5).withValues(alpha: 0.55)
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 6) {
        canvas.drawLine(Offset(x, yu), Offset((x + 3).clamp(0, size.width), yu), trazo);
      }
    }

    final linea = Path()..moveTo(punto(0).dx, punto(0).dy);
    for (var i = 1; i < valores.length; i++) {
      linea.lineTo(punto(i).dx, punto(i).dy);
    }
    final relleno = Path.from(linea)
      ..lineTo(size.width - margen, size.height)
      ..lineTo(margen, size.height)
      ..close();
    canvas.drawPath(
      relleno,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      linea,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(punto(valores.length - 1), grosor + 1.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant PintorChispaSensor o) {
    if (o.color != color || o.grosor != grosor || o.umbral != umbral || o.valores.length != valores.length) return true;
    for (var i = 0; i < valores.length; i++) {
      if (valores[i] != o.valores[i]) return true;
    }
    return false;
  }
}

/// Barra del valor contra el umbral: llena hasta el valor, con una marca en el umbral. La escala
/// va hasta 1,25 × umbral para que el umbral no quede pegado al borde.
class MedidorUmbral extends StatelessWidget {
  const MedidorUmbral({super.key, required this.lectura, required this.ahora, this.altura = 8});

  final LecturaSensor lectura;
  final DateTime ahora;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final v = lectura.valor;
    final u = lectura.umbral;
    final escala = u <= 0 ? 0.0 : u * 1.25;
    final fraccion = v == null || escala <= 0 ? 0.0 : (v / escala).clamp(0.0, 1.0);
    final color = lectura.estado(ahora) == EstadoLectura.vieja
        ? Zc.textoTenue
        : Zc.dePrioridad(lectura.riesgo(ahora));
    return Semantics(
      label: v == null
          ? '${lectura.tipo.nombre}: sin lectura'
          : '${lectura.tipo.nombre} ${lectura.tipo.formatear(v)}, umbral ${lectura.tipo.formatear(u)}',
      child: SizedBox(
        height: altura + 6,
        width: double.infinity,
        child: CustomPaint(
          painter: _PintorMedidor(
            fraccion: fraccion,
            marca: escala <= 0 ? null : u / escala,
            fondo: Zc.linea,
            frente: color,
            colorMarca: Zc.texto,
            altura: altura,
          ),
        ),
      ),
    );
  }
}

class _PintorMedidor extends CustomPainter {
  const _PintorMedidor({
    required this.fraccion,
    required this.marca,
    required this.fondo,
    required this.frente,
    required this.colorMarca,
    required this.altura,
  });

  final double fraccion;
  final double? marca;
  final Color fondo;
  final Color frente;
  final Color colorMarca;
  final double altura;

  @override
  void paint(Canvas canvas, Size size) {
    final top = (size.height - altura) / 2;
    final r = Radius.circular(altura / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, top, size.width, altura), r), Paint()..color = fondo);
    if (fraccion > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, top, size.width * fraccion, altura), r),
        Paint()..color = frente,
      );
    }
    final m = marca;
    if (m != null) {
      final x = size.width * m;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x - 1, 0, 2, size.height), const Radius.circular(1)),
        Paint()..color = colorMarca,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PintorMedidor o) =>
      o.fraccion != fraccion || o.marca != marca || o.frente != frente || o.fondo != fondo;
}
