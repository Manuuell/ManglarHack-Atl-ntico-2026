import 'package:flutter/material.dart';

/// Lo que se puede reportar. El `slug` es el contrato común con la web, el bot y el
/// backend (handoff/05): no cambiarlo sin avisar al equipo.
///
/// `gravedad` (1-5) es la base de la prioridad. Es PROVISIONAL: se valida con los
/// mentores ambientales y comunitarios.
enum TipoAmenaza {
  tala(
    slug: 'tala',
    nombre: 'Tala o corte de mangle',
    corto: 'Tala',
    ayuda: 'Árboles cortados, troncos apilados, motosierra o machete.',
    pregunta: '¿Están cortando ahora mismo o ya está cortado?',
    icono: Icons.carpenter_rounded,
    color: Color(0xFF8A5A2B),
    gravedad: 5,
  ),
  quema(
    slug: 'quema',
    nombre: 'Quema o incendio',
    corto: 'Fuego',
    ayuda: 'Humo, llamas o vegetación quemada en el manglar o al lado.',
    pregunta: '¿Ves llamas o solo humo?',
    icono: Icons.local_fire_department_rounded,
    color: Color(0xFFD13B3B),
    gravedad: 5,
  ),
  relleno(
    slug: 'relleno',
    nombre: 'Relleno o construcción',
    corto: 'Relleno',
    ayuda: 'Volquetas con tierra o escombros, lotes que avanzan sobre el agua, obras.',
    pregunta: '¿Hay maquinaria trabajando?',
    icono: Icons.construction_rounded,
    color: Color(0xFF7A6A55),
    gravedad: 4,
  ),
  vertimiento(
    slug: 'vertimiento',
    nombre: 'Vertimiento o contaminación',
    corto: 'Vertimiento',
    ayuda: 'Tubos que botan agua sucia, manchas de aceite, mal olor, espuma.',
    pregunta: '¿De dónde sale? ¿Tiene color u olor?',
    icono: Icons.water_drop_rounded,
    color: Color(0xFF6A4FA3),
    gravedad: 4,
  ),
  canoTaponado(
    slug: 'cano_taponado',
    nombre: 'Caño taponado o agua alterada',
    corto: 'Caño',
    ayuda: 'Un caño cerrado con tierra, basura o una obra: el manglar se queda sin agua dulce.',
    pregunta: '¿El agua todavía corre o está quieta?',
    icono: Icons.waves_rounded,
    color: Color(0xFF1F7A8C),
    gravedad: 4,
  ),
  fauna(
    slug: 'fauna',
    nombre: 'Fauna afectada',
    corto: 'Fauna',
    ayuda: 'Caza, aves o peces muertos, animales atrapados o heridos.',
    pregunta: '¿Cuántos animales ves, más o menos?',
    icono: Icons.flutter_dash_rounded,
    color: Color(0xFF2E7D5B),
    gravedad: 4,
  ),
  basuras(
    slug: 'basuras',
    nombre: 'Basuras o residuos',
    corto: 'Basuras',
    ayuda: 'Plástico enredado en las raíces, botaderos, escombros.',
    pregunta: '¿Es poca basura o un botadero?',
    icono: Icons.delete_outline_rounded,
    color: Color(0xFF5B6B73),
    gravedad: 2,
  ),
  otro(
    slug: 'otro',
    nombre: 'Otra situación',
    corto: 'Otro',
    ayuda: 'Algo raro que pone en riesgo el manglar. Cuéntalo con tus palabras.',
    pregunta: 'Cuéntame qué está pasando.',
    icono: Icons.help_outline_rounded,
    color: Color(0xFF55655F),
    gravedad: 2,
  );

  const TipoAmenaza({
    required this.slug,
    required this.nombre,
    required this.corto,
    required this.ayuda,
    required this.pregunta,
    required this.icono,
    required this.color,
    required this.gravedad,
  });

  final String slug;
  final String nombre;
  final String corto;
  final String ayuda;
  final String pregunta;
  final IconData icono;
  final Color color;
  final int gravedad;

  static TipoAmenaza deSlug(String s) =>
      values.firstWhere((t) => t.slug == s, orElse: () => TipoAmenaza.otro);
}

/// Estados del contrato común (handoff/05).
enum EstadoReporte {
  recibido('recibido', 'Recibido', 'La CRA ya lo tiene.'),
  enVerificacion('en_verificacion', 'En verificación', 'Un vigía o funcionario lo está revisando.'),
  verificado('verificado', 'Verificado', 'Se confirmó que es real. ¡Gracias!'),
  alertaOficial('alerta_oficial', 'Alerta oficial', 'Se abrió un expediente en la CRA.'),
  enAtencion('en_atencion', 'En atención', 'Hay un operativo en camino o en el sitio.'),
  cerrado('cerrado', 'Cerrado', 'El caso se atendió y se cerró.'),
  descartado('descartado', 'Descartado', 'No se pudo confirmar o no era una amenaza.');

  const EstadoReporte(this.slug, this.nombre, this.explicacion);
  final String slug;
  final String nombre;
  final String explicacion;

  /// Orden en la línea de tiempo (descartado va aparte).
  static const camino = [recibido, enVerificacion, verificado, alertaOficial, enAtencion, cerrado];

  bool get validado => this == verificado || this == alertaOficial || this == enAtencion || this == cerrado;

  static EstadoReporte deSlug(String s) =>
      values.firstWhere((e) => e.slug == s, orElse: () => EstadoReporte.recibido);
}

/// ¿Cuándo pasó? La CRA solo puede actuar sobre lo que pasa «ahora mismo».
enum Momento {
  ahora('ahora', 'Está pasando ahora'),
  hoy('hoy', 'Pasó hace poco, hoy'),
  antes('antes', 'Lo vi antes de hoy');

  const Momento(this.slug, this.nombre);
  final String slug;
  final String nombre;
  static Momento deSlug(String s) => values.firstWhere((m) => m.slug == s, orElse: () => Momento.ahora);
}

/// Magnitud aproximada: ayuda a priorizar sin pedir medidas que nadie tiene.
enum Magnitud {
  pequena('pequena', 'Pequeña', 'Unos metros'),
  mediana('mediana', 'Mediana', 'Como una cancha'),
  grande('grande', 'Grande', 'Más que una cancha');

  const Magnitud(this.slug, this.nombre, this.ejemplo);
  final String slug;
  final String nombre;
  final String ejemplo;
  static Magnitud deSlug(String s) => values.firstWhere((m) => m.slug == s, orElse: () => Magnitud.pequena);
}
