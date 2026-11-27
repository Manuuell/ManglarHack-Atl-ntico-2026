import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'base/movimiento.dart';

/// Colores de Zanky: salen del propio manglar.
///
/// - [raiz]: el verde casi negro de la sombra bajo el mangle rojo.
/// - [hoja]: el verde de la hoja nueva, el color de la marca.
/// - [cienaga]: el agua salobre de Mallorquín.
/// - [arena] y [fango]: la playa y el lodo donde se asientan las raíces.
/// - [sol]: el atardecer sobre la ciénaga; acento cálido de Zanky.
abstract final class Zc {
  static const raiz = Color(0xFF0B2E24);
  static const raizSuave = Color(0xFF184437);
  static const hoja = Color(0xFF2E9E6A);
  static const hojaClara = Color(0xFFDDF3E6);
  static const cienaga = Color(
    0xFF1FA2A6,
  ); // agua: color principal de la identidad (handoff/08)
  static const cienagaClara = Color(0xFFDDF2F2);
  static const arena = Color(0xFFF6F1E7);
  static const fango = Color(0xFF8A6A4B);
  static const sol = Color(
    0xFFE8B33D,
  ); // el dorado único de la CRA (identidad.dart)
  static const solClaro = Color(0xFFFDEED6);

  // Colores del Carnaval de Barranquilla: el confeti y las celebraciones.
  static const carnavalAmarillo = Color(0xFFF9C80E);
  static const carnavalRojo = Color(0xFFE63946);
  static const carnavalVerde = Color(0xFF2A9D8F);

  static const texto = Color(0xFF12211C);
  static const textoSuave = Color(0xFF55655F);
  static const textoTenue = Color(0xFF8A9893);
  static const linea = Color(0xFFE4E0D6);
  static const superficie = Colors.white;

  // Prioridad 1 (baja) a 5 (crítica): de la calma de la hoja al rojo del fuego.
  static const prioridad = <int, Color>{
    1: Color(0xFF5E9E7E),
    2: Color(0xFF8BA94A),
    3: Color(0xFFE0A030),
    4: Color(0xFFE06B2D),
    5: Color(0xFFD13B3B),
  };

  static Color dePrioridad(int p) => prioridad[p.clamp(1, 5)]!;
}

/// Tiempos y resortes. Un solo lugar para que toda la app se mueva igual.
abstract final class Zm {
  /// Hundir al tocar: rápido y sin rebote, el dedo lo siente antes que nada.
  static const presion = Duration(milliseconds: 80);
  static const escalaPresion = AppMotion.pressScale;

  /// Soltar: el resorte de presión ya medido (1/420/34, ζ≈0,83): asienta en ~0,2 s.
  static const resortePresion = AppMotion.resortePresion;
  static const resorteSuave = AppMotion.resorteSuave;
  static const resorteRebote = AppMotion.resorteRebote;
  static const resorteEmergente = AppMotion.resorteEmergente;

  static const corto = Duration(milliseconds: 180);
  static const medio = Duration(milliseconds: 320);
  static const largo = Duration(milliseconds: 520);

  static const entrar = Cubic(0.2, 0.9, 0.25, 1); // desacelera largo, como iOS
  static const salir = Cubic(0.4, 0, 1, 1);
}

abstract final class Zr {
  static const s = 12.0;
  static const m = 18.0;
  static const l = 26.0;
  static const xl = 34.0;
}

/// Tipografía de la app: Lato va empaquetada (en el manglar no hay señal para bajar fuentes).
const familiaTexto = 'Lato';

ThemeData temaZanky() => construirTema(
  brillo: Brightness.light,
  scheme: ColorScheme.fromSeed(
    seedColor: Zc.hoja,
    primary: Zc.hoja,
    secondary: Zc.cienaga,
    tertiary: Zc.sol,
    surface: Zc.arena,
    error: Zc.prioridad[5]!,
  ),
  fondo: Zc.arena,
  texto: Zc.texto,
  suave: Zc.textoSuave,
  snack: Zc.raiz,
);

/// Un solo constructor de tema: claro (Zanky) u oscuro (CRA) cambian solo los colores.
ThemeData construirTema({
  required Brightness brillo,
  required ColorScheme scheme,
  required Color fondo,
  required Color texto,
  required Color suave,
  required Color snack,
}) {
  const fuente = familiaTexto;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brillo,
    fontFamily: fuente,
    colorScheme: scheme,
    scaffoldBackgroundColor: fondo,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  TextStyle t(
    double size,
    FontWeight w, {
    double h = 1.25,
    double ls = 0,
    Color? c,
  }) => TextStyle(
    fontFamily: fuente,
    fontSize: size,
    fontWeight: w,
    height: h,
    letterSpacing: ls,
    color: c ?? texto,
  );
  return base.copyWith(
    textTheme: TextTheme(
      displaySmall: t(34, FontWeight.w700, h: 1.08, ls: -0.6),
      headlineMedium: t(28, FontWeight.w700, h: 1.12, ls: -0.4),
      headlineSmall: t(22, FontWeight.w700, h: 1.18, ls: -0.3),
      titleLarge: t(19, FontWeight.w700, ls: -0.2),
      titleMedium: t(16, FontWeight.w700, ls: -0.1),
      titleSmall: t(14, FontWeight.w700),
      bodyLarge: t(16, FontWeight.w400, h: 1.42),
      bodyMedium: t(14.5, FontWeight.w400, h: 1.4, c: suave),
      bodySmall: t(12.5, FontWeight.w400, h: 1.35, c: suave),
      labelLarge: t(15, FontWeight.w700),
      labelMedium: t(13, FontWeight.w700, ls: 0.1),
      // Titulares de sección: cada pantalla escribe el texto en MAYÚSCULAS; aquí va el tracking.
      labelSmall: t(11, FontWeight.w700, ls: 1.2, c: suave),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: snack,
      contentTextStyle: t(14, FontWeight.w700, c: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Zr.m)),
    ),
  );
}
