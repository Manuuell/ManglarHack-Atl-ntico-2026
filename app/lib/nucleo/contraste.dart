/// Utilidades de contraste de color según WCAG 2.1.
///
/// Funciones puras para medir de verdad el contraste en vez de estimarlo:
/// la auditoría calculó ~4.0:1 para el blanco sobre la marca sin medir y sin
/// componer el alfa, y ese es el error que invalida casi todas las
/// mediciones caseras: un blanco al 85% sobre rojo **no** es blanco, hay que
/// componerlo sobre el fondo antes de medir.
///
/// Uso:
/// ```dart
/// // Texto sólido sobre un fondo opaco.
/// final r = contrasteTexto(Colors.white, const Color(0xFFE42313));
/// // Texto con alfa: se compone solo sobre el fondo.
/// final r2 = contrasteTexto(Colors.white.withValues(alpha: 0.85), fondo);
/// // Fondo teñido (tinte translúcido sobre una base opaca): primero se
/// // resuelve el fondo y luego se mide el texto sobre el fondo resuelto.
/// final fondoEfectivo = componerSobre(tinte, surface);
/// final r3 = razonContraste(acento, fondoEfectivo);
/// ```
///
/// Notas de la fórmula:
/// - Luminancia relativa WCAG 2.1 con umbral `0.03928` y exponente `2.4`.
/// - El fondo se asume opaco. Si el fondo tiene alfa (un teñido con
///   `withValues(alpha: 0.14)` sobre `surface`), compónlo primero con
///   [componerSobre] sobre su base y mide sobre el resultado.
/// - Umbrales: [umbralTextoNormal] 4.5:1 para texto normal,
///   [umbralTextoGrande] 3.0:1 para texto grande.

library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Contraste mínimo para texto normal (WCAG AA).
const double umbralTextoNormal = 4.5;

/// Contraste mínimo para texto grande (WCAG AA, ≥18 pt o ≥14 pt en negrita).
const double umbralTextoGrande = 3.0;

/// Luminancia relativa de [color] según WCAG 2.1 (0.0–1.0).
///
/// Solo usa los canales RGB; el alfa no forma parte de la luminancia: si el
/// color tiene alfa, compónlo primero con [componerSobre].
double luminanciaRelativa(Color color) {
  // Cada canal en 0–255 como siempre (redondeado), para que la cuenta no
  // cambie con la API nueva de `Color` (canales en coma flotante).
  double canal(double componente) {
    final c = _a8bits(componente) / 255.0;
    if (c <= 0.03928) return c / 12.92;
    return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * canal(color.r) +
      0.7152 * canal(color.g) +
      0.0722 * canal(color.b);
}

/// Compone [frente] sobre [fondo] (mezcla alfa "source over").
///
/// El resultado es siempre opaco. [fondo] se asume opaco: se usa su RGB tal
/// cual. Si el fondo real es un teñido sobre otra base, llama primero con el
/// teñido como frente y la base como fondo.
Color componerSobre(Color frente, Color fondo) {
  final a = frente.a.clamp(0.0, 1.0);
  if (a >= 1.0) return frente.withValues(alpha: 1.0);
  int mezclar(double f, double b) =>
      ((a * _a8bits(f)) + ((1.0 - a) * _a8bits(b))).round().clamp(0, 255);
  return Color.fromARGB(
    255,
    mezclar(frente.r, fondo.r),
    mezclar(frente.g, fondo.g),
    mezclar(frente.b, fondo.b),
  );
}

/// Razón de contraste WCAG 2.1 entre dos colores (1.0–21.0).
///
/// Ambos se asumen opacos. El orden no importa.
double razonContraste(Color a, Color b) {
  final la = luminanciaRelativa(a);
  final lb = luminanciaRelativa(b);
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

/// Contraste del [texto] sobre [fondo], componiendo el alfa del texto.
///
/// Si el texto es opaco equivale a [razonContraste]. Si tiene alfa (por
/// ejemplo blanco al 85% sobre la marca), primero lo compone con
/// [componerSobre] y luego mide: ese paso es el que falta en las mediciones
/// caseras que comparan el blanco puro contra el fondo.
double contrasteTexto(Color texto, Color fondo) {
  if (texto.a >= 1.0) return razonContraste(texto, fondo);
  return razonContraste(componerSobre(texto, fondo), fondo);
}

/// Verdadero si el contraste texto/fondo alcanza el umbral WCAG AA.
///
/// Con [textoGrande] en falso exige 4.5:1; en verdadero, 3.0:1.
bool cumpleContraste(Color texto, Color fondo, {bool textoGrande = false}) {
  final umbral = textoGrande ? umbralTextoGrande : umbralTextoNormal;
  return contrasteTexto(texto, fondo) >= umbral;
}

/// El tono de [base] oscurecido lo justo para que el blanco sólido se lea
/// encima a [umbral]:1. Si ya llega, se devuelve tal cual.
///
/// Para los fondos de marca con texto pequeño encima: los azules de marca
/// casi no cambian; el naranja brillante de San Buenaventura (≈3:1) sí.
Color tonoLegibleBajoBlanco(Color base, {double umbral = 4.5}) {
  var hsl = HSLColor.fromColor(base);
  while (razonContraste(Colors.white, hsl.toColor()) < umbral &&
      hsl.lightness > 0.05) {
    hsl = hsl.withLightness((hsl.lightness - 0.02).clamp(0.0, 1.0));
  }
  return hsl.toColor();
}

/// Un canal de `Color` (0.0–1.0) en 0–255, como lo daban `red`/`green`/`blue`.
int _a8bits(double componente) => (componente * 255.0).round().clamp(0, 255);
