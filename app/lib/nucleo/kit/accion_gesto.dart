/// Modelo único de acción de gesto: lo comparten el deslizar para revelar
/// ([FilaDeslizable]), el menú al mantener presionado ([MenuMantenido]) y la
/// bandeja de acciones ([BandejaAcciones]).
///
/// Traducido de `AccionGesto` de la app universitaria (gestos/accion_gesto.dart),
/// sin la confirmación embebida: aquí cada pantalla decide si confirma en hoja o
/// deja «Deshacer» (la vara pide Deshacer antes que confirmar).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../tema.dart';

@immutable
class AccionGesto {
  const AccionGesto({
    required this.etiqueta,
    required this.icono,
    required this.alEjecutar,
    this.color,
    this.destructiva = false,
    this.etiquetaSemantica,
  });

  /// Texto visible («Compartir»).
  final String etiqueta;

  /// El ícono acompaña siempre al texto: lo destructivo no se distingue solo por color.
  final IconData icono;

  /// Qué pasa al elegirla. Puede ser asíncrona.
  final FutureOr<void> Function() alEjecutar;

  /// Fondo de la baldosa al deslizar. Nulo: rojo si es destructiva, hoja si no.
  final Color? color;

  /// Va al final del menú, separada y en rojo.
  final bool destructiva;

  final String? etiquetaSemantica;

  String get anuncio => etiquetaSemantica ?? etiqueta;

  Color get colorResuelto => color ?? (destructiva ? Zc.dePrioridad(5) : Zc.hoja);

  /// Tinta de la fila sobre una superficie clara.
  Color get tinta => destructiva ? Zc.dePrioridad(5) : Zc.texto;
}
