import 'package:flutter/material.dart';

import 'tema.dart';

/// FUENTE DE VERDAD de la identidad de la app. Decisión del 27-nov: la app sigue la paleta pedida por
/// el equipo; la web (`web/src/styles/global.css`) usa valores cercanos que conviene alinear:
///
/// | Token          | App (aquí) | Web publicada   |
/// |----------------|------------|-----------------|
/// | fondo          | `#0A2A47`  | `#082B45`       |
/// | fondo profundo | `#061E35`  | `#061F33`       |
/// | superficie     | `#12395E`  | `#0D3A5C`       |
/// | dorado         | `#E8B33D`  | `#EDB512`       |
/// | tipografía     | Lato       | Inter / Figtree |
///
/// Las diferencias son de pocos puntos y no rompen el contraste. Si se unifican, se cambia SOLO aquí
/// y en las variables `:root` de `global.css`.
///
/// Identidad de la Corporación (CRA): UN solo lugar. Para pasar toda la app a oscuro basta con
/// usar [temaCra] en `main.dart` (y apuntar `Zc` a estos mismos valores).
///
/// Contrastes medidos (WCAG 2.x, luminancia relativa; los comprueba `test/identidad_test.dart`):
///
/// | Texto sobre fondo                         | Razón  | AA texto (4,5) |
/// |-------------------------------------------|--------|----------------|
/// | blanco sobre [azul] `#0A2A47`             | 14,63  | cumple         |
/// | blanco sobre [hero] `#061E35`             | 16,87  | cumple         |
/// | blanco sobre [superficie] `#12395E`       | 11,85  | cumple         |
/// | [textoSuave] `#B9C9D6` sobre [azul]       |  8,63  | cumple         |
/// | [textoSuave] sobre [superficie]           |  6,99  | cumple         |
/// | [textoTenue] `#9DB4C6` sobre [superficie] |  5,52  | cumple         |
/// | [dorado] `#E8B33D` sobre [azul]           |  7,63  | cumple         |
/// | [dorado] sobre [hero]                     |  8,79  | cumple         |
/// | [dorado] sobre [superficie]               |  6,18  | cumple         |
/// | [azul] sobre [dorado] (botón dorado)      |  7,63  | cumple         |
/// | [riesgo] `#FF8A8A` sobre [superficie]     |  5,22  | cumple         |
/// | `#0A2A47` sobre arena `#F6F1E7` (claro)   | 13,00  | cumple         |
///
/// El [borde] `#3A6286` (1,85 sobre superficie) es solo decoración: ningún control depende de él
/// para entenderse; el foco y los campos activos usan [dorado] (≥ 3:1).
abstract final class Cra {
  // Marca.
  static const azul = Color(0xFF0A2A47);
  static const hero = Color(0xFF061E35);
  static const superficie = Color(0xFF12395E);
  static const superficieAlta = Color(0xFF1B4A73);
  static const borde = Color(0xFF3A6286);
  static const blanco = Color(0xFFFFFFFF);
  static const textoSuave = Color(0xFFB9C9D6);
  static const textoTenue = Color(0xFF9DB4C6);

  /// El dorado ÚNICO: eyebrows, títulos destacados y botones destacados. Nunca otro amarillo.
  static const dorado = Color(0xFFE8B33D);

  /// Relleno suave para la nota de «datos de ejemplo» sobre fondo oscuro.
  static const doradoSuave = Color(0xFF3A4A52);

  // Colores de mapa (leyenda y capas).
  static const manglarProbable = Color(0xFFD63384); // magenta
  static const preservacion = Color(0xFF2E9E6A); // verde
  static const agua = Color(0xFF3AA9E0); // azul agua
  static const recuperacion = Color(0xFFF08A24); // naranja
  static const rehabilitacion = Color(0xFFF4B6C8); // rosa pálido
  static const riesgoMuyAlto = Color(0xFFD13B3B); // rojo

  // Semánticos legibles sobre fondo oscuro (AA >= 4,5 sobre [superficie]).
  static const riesgo = Color(0xFFFF8A8A);
  static const acierto = Color(0xFF6FD6A4);
  static const info = Color(0xFF7CCBF2);

  // ---- Alias con los nombres de `Zc`, para el tema oscuro del panel ---------------------------
  // Las pantallas del panel usan estos nombres: pasar de claro a oscuro es cambiar de clase.
  static const texto = blanco;
  static const linea = borde;
  static const arena = azul; // fondo de página
  static const raiz = hero; // lo más profundo: barras, chips activos
  static const raizSuave = superficie;
  static const hoja = dorado; // acento
  static const hojaClara = superficieAlta; // panel de estado
  static const cienaga = info;
  static const cienagaClara = superficieAlta;
  static const sol = dorado;
  static const solClaro = doradoSuave;
  static const fango = dorado;

  static const prioridad = <int, Color>{
    1: Color(0xFF6FD6A4),
    2: Color(0xFFB5D96A),
    3: Color(0xFFF2C14E),
    4: Color(0xFFF6A55C),
    5: riesgo,
  };

  static Color dePrioridad(int p) => prioridad[p.clamp(1, 5)]!;

  /// Escala 1-5 de la capa de prioridad del MAPA con la paleta de capas de la CRA: del verde de
  /// preservación al rojo de riesgo muy alto. Las zonas alta/media/baja de la capa oficial valen
  /// 5/4/3 (`PrioridadCRA.puntos`): rojo, naranja y rosa pálido. El nivel no depende solo del color:
  /// el borde engorda y la leyenda lo dice con palabras.
  static const prioridadMapa = <int, Color>{
    1: preservacion,
    2: agua,
    3: rehabilitacion,
    4: recuperacion,
    5: riesgoMuyAlto,
  };

  static Color deMapa(int p) => prioridadMapa[p.clamp(1, 5)]!;
}

/// Titular de sección: UN solo estilo (MAYÚSCULAS con tracking; el texto lo escribe la pantalla en
/// mayúsculas). Se usa como `tt.seccion` y, si hace falta, `.copyWith(color: ...)`.
extension EstiloSeccion on TextTheme {
  TextStyle get seccion => labelSmall!.copyWith(letterSpacing: 1.6, fontWeight: FontWeight.w700);
}

/// Eyebrow dorado sobre fondo oscuro; sobre claro va en [Cra.azul] (el dorado no llega a 4,5:1).
TextStyle estiloSeccion(BuildContext context, {Color color = Cra.dorado}) =>
    Theme.of(context).textTheme.seccion.copyWith(color: color);

/// Insignia de la CRA: el logo blanco sobre su azul. Va en la cabecera de cada pantalla grande.
class InsigniaCra extends StatelessWidget {
  const InsigniaCra({super.key, this.alto = 34});
  final double alto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Corporación Autónoma Regional del Atlántico',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          height: alto,
          width: alto,
          padding: EdgeInsets.all(alto * 0.14),
          decoration: BoxDecoration(
            color: Cra.azul,
            borderRadius: BorderRadius.circular(alto * 0.3),
            border: Border.all(color: Cra.borde.withValues(alpha: 0.7)),
          ),
          child: Image.asset(
            'assets/marca/logo-cra-blanco.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

/// Tema oscuro CRA completo: panel, gestión y cifras. Misma tipografía y movimiento que Zanky.
ThemeData temaCra() => construirTema(
  brillo: Brightness.dark,
  scheme: ColorScheme.fromSeed(
    brightness: Brightness.dark,
    seedColor: Cra.dorado,
    primary: Cra.dorado,
    onPrimary: Cra.azul,
    secondary: Cra.info,
    tertiary: Cra.dorado,
    surface: Cra.azul,
    onSurface: Cra.blanco,
    error: Cra.riesgo,
  ),
  fondo: Cra.azul,
  texto: Cra.blanco,
  suave: Cra.textoSuave,
  snack: Cra.superficieAlta,
).copyWith(extensions: const [PaletaCra.oscura]);

/// Paleta como [ThemeExtension] (estructura portada de `AppColors` de Tooli, `core/theme/app_colors.dart`):
/// las pantallas leen `context.paleta` y no escriben hex. Cambiar claro/oscuro es cambiar la instancia.
@immutable
class PaletaCra extends ThemeExtension<PaletaCra> {
  const PaletaCra({
    required this.fondo,
    required this.superficie,
    required this.superficieAlta,
    required this.borde,
    required this.acento,
    required this.sobreAcento,
    required this.texto,
    required this.textoSuave,
    required this.textoTenue,
    required this.riesgo,
  });

  final Color fondo, superficie, superficieAlta, borde;

  /// El dorado único y el texto que va encima (azul: 7,63:1).
  final Color acento, sobreAcento;
  final Color texto, textoSuave, textoTenue, riesgo;

  static const oscura = PaletaCra(
    fondo: Cra.azul,
    superficie: Cra.superficie,
    superficieAlta: Cra.superficieAlta,
    borde: Cra.borde,
    acento: Cra.dorado,
    sobreAcento: Cra.azul,
    texto: Cra.blanco,
    textoSuave: Cra.textoSuave,
    textoTenue: Cra.textoTenue,
    riesgo: Cra.riesgo,
  );

  @override
  PaletaCra copyWith({Color? fondo, Color? superficie, Color? acento}) =>
      PaletaCra(
        fondo: fondo ?? this.fondo,
        superficie: superficie ?? this.superficie,
        superficieAlta: superficieAlta,
        borde: borde,
        acento: acento ?? this.acento,
        sobreAcento: sobreAcento,
        texto: texto,
        textoSuave: textoSuave,
        textoTenue: textoTenue,
        riesgo: riesgo,
      );

  @override
  PaletaCra lerp(ThemeExtension<PaletaCra>? other, double t) => this;
}

extension PaletaDelContexto on BuildContext {
  PaletaCra get paleta =>
      Theme.of(this).extension<PaletaCra>() ?? PaletaCra.oscura;
}

/// Franja de marca para las pantallas ciudadanas: logo CRA y su nombre en dorado, sobre el azul.
/// Conserva la calidez de Zanky (esquinas redondas, margen amplio) y firma cada pantalla grande.
class FranjaMarcaCra extends StatelessWidget {
  const FranjaMarcaCra({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
        decoration: BoxDecoration(
          color: Cra.azul,
          borderRadius: BorderRadius.circular(Zr.m),
        ),
        child: Row(
          children: [
            const InsigniaCra(alto: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'CORPORACIÓN AUTÓNOMA REGIONAL DEL ATLÁNTICO',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: familiaTexto,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  height: 1.25,
                  color: Cra.dorado,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
