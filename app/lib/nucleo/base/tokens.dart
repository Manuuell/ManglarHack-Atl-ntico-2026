import 'package:flutter/material.dart';

import '../tema.dart';

/// Tokens que usan las piezas de `nucleo/base` (hojas, esqueletos, entrada escalonada).
/// Esas piezas vienen de una base de movimiento ya medida en teléfono; aquí se
/// conectan a los colores de Zanky sin reescribirlas.
abstract final class AppRadius {
  static const double sm = 10;
  static const double xl = Zr.m;
  static const double xxl = Zr.l;
  static const double sheet = Zr.xl;
}

abstract final class AppSpacing {
  static const double sm = 8;
  static const double lg = 16;
  static const double xl = 22;
  static const double xxl = 30;
}

class ColoresBase {
  const ColoresBase();
  Color get surface => Zc.superficie;
  Color get surfaceAlt => const Color(0xFFEFEAE0);
  Color get border => Zc.linea;
  Color get scrim => const Color(0x8C0B2E24);
}

class ElevacionBase {
  const ElevacionBase();
  List<BoxShadow> get hoja => const [
        BoxShadow(color: Color(0x290B2E24), blurRadius: 40, offset: Offset(0, -6)),
      ];
}

extension TokensBase on BuildContext {
  ColoresBase get colors => const ColoresBase();
  ElevacionBase get elevation => const ElevacionBase();
}
