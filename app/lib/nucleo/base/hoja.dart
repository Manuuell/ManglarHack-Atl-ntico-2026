/// El cromo único de las hojas de la app: superficie, borde, esquinas de
/// arriba, sombra, área segura y relleno.
///
/// Estaba copiado en once sitios —nueve pantallas con `showModalBottomSheet`
/// pelado y dos hojas de gestos—, cada uno con su radio, su color y su
/// relleno escritos otra vez. Cuando una hoja se movía, las demás no.
///
/// Va sobre [mostrarHojaModal] (la ruta propia de la app, con cierre por
/// arrastre que mira la velocidad y movimiento reducido heredado), no sobre
/// `showModalBottomSheet`: así todas las hojas se cierran igual.
library;

import 'package:flutter/material.dart';

import 'ruta_hoja_modal.dart';
import 'tokens.dart';

/// Superficie de una hoja modal de la app.
///
/// El contenido lo pone quien la abre; esto solo aporta la forma. Con
/// [desplazable] en true (lo normal cuando el contenido puede crecer o el
/// teclado sube) el hijo va dentro de un [SingleChildScrollView] y el
/// relleno se aplica dentro, para que el desplazamiento llegue a los bordes.
class HojaZ extends StatelessWidget {
  const HojaZ({
    super.key,
    required this.child,
    this.desplazable = true,
    this.relleno = rellenoPorDefecto,
  });

  /// Relleno interior: generoso abajo para que el último botón no quede
  /// pegado al borde del teléfono.
  static const EdgeInsets rellenoPorDefecto = EdgeInsets.fromLTRB(
    AppSpacing.xl,
    AppSpacing.lg,
    AppSpacing.xl,
    AppSpacing.xxl,
  );

  /// Contenido de la hoja.
  final Widget child;

  /// Si el contenido se desplaza cuando no cabe. Ver la clase.
  final bool desplazable;

  /// Relleno interior. Ver [rellenoPorDefecto].
  final EdgeInsets relleno;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final contenido = desplazable
        ? SingleChildScrollView(
            padding: relleno,
            child: child,
          )
        : Padding(padding: relleno, child: child);
    // El área segura va **dentro** de la superficie: fuera, la hoja
    // terminaba sobre la barra de gestos del sistema y por esa franja se
    // veía la pantalla de abajo (visto en el teléfono, 2026-10-16).
    return Container(
      // El teclado empuja la hoja en vez de taparla.
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        boxShadow: context.elevation.hoja,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      // El recorte va aquí y no en el contenido: sin él, un contenido
      // desplazable pinta por encima de las esquinas redondeadas.
      clipBehavior: Clip.antiAlias,
      // `Material` transparente, no decorativo: el fondo y el borde los
      // pinta el `Container` de arriba. Está aquí porque media librería
      // de Material lo exige como ancestro —`TextField`, `ListTile`, los
      // destellos de tinta— y sin él revienta con «No Material widget
      // found» al construir.
      //
      // El `showModalBottomSheet` de Flutter lo ponía. Al unificar la
      // hoja en la ola 6 se perdió, y no se notó porque ninguna de las
      // hojas migradas llevaba dentro un widget que lo pidiera. El primer
      // formulario con un campo de texto lo destapó.
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          // Nunca más de lo que cabe: una hoja a pantalla completa deja
          // de parecer una hoja y tapa el contexto de abajo.
          // Con el teclado arriba, tampoco más de lo que queda libre sobre
          // él (si no, la hoja se salía por arriba y el campo quedaba tapado).
          constraints: BoxConstraints(maxHeight: _altoMaximo(context)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Agarre(),
              Flexible(child: SafeArea(top: false, child: contenido)),
            ],
          ),
        ),
      ),
    );
  }

  /// Fracción máxima de la pantalla que ocupa una hoja.
  static const double fraccionMaximaAlto = 0.88;

  static double _altoMaximo(BuildContext context) {
    final medida = MediaQuery.of(context);
    final tope = medida.size.height * fraccionMaximaAlto;
    // Lo que queda sobre el teclado, con un respiro arriba (barra de estado).
    final libre = medida.size.height - medida.viewInsets.bottom - medida.padding.top - 12;
    return libre < tope ? (libre < 160 ? 160 : libre) : tope;
  }
}

/// El agarre de arriba: la pista de que la hoja se arrastra para cerrar.
/// Decorativo (el lector de pantalla no lo ve; cerrar tiene su velo y su botón).
class _Agarre extends StatelessWidget {
  const _Agarre();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            width: 38,
            height: 5,
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      );
}

/// Abre una hoja con el cromo de [HojaZ] y completa con lo que devuelva
/// (`Navigator.pop(context, valor)`) o con nulo si se cerró arrastrando,
/// tocando el velo o con el botón de atrás.
///
/// [nombre] nombra la ruta para el `ObservadorRutas` y el diagnóstico.
Future<T?> mostrarHojaZ<T>(
  BuildContext context, {
  required WidgetBuilder contenido,
  String? nombre,
  bool desplazable = true,
  EdgeInsets relleno = HojaZ.rellenoPorDefecto,
}) {
  return mostrarHojaModal<T>(
    context,
    nombre: nombre,
    areaSeguraAbajo: false,
    builder: (contextHoja) => HojaZ(
      desplazable: desplazable,
      relleno: relleno,
      child: Builder(builder: contenido),
    ),
  );
}
