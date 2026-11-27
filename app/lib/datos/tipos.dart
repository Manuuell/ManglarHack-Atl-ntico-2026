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
    ayuda: 'Árboles cortados o troncos apilados.',
    pregunta: '¿Están cortando ahora mismo o ya está cortado?',
    icono: Icons.carpenter_rounded,
    color: Color(0xFF8A5A2B),
    gravedad: 5,
  ),
  quema(
    slug: 'quema',
    nombre: 'Quema o incendio',
    corto: 'Quema',
    ayuda: 'Humo, llamas o mangle quemado.',
    pregunta: '¿Ves llamas o solo humo?',
    icono: Icons.local_fire_department_rounded,
    color: Color(0xFFD13B3B),
    gravedad: 5,
  ),
  relleno(
    slug: 'relleno',
    nombre: 'Relleno o construcción',
    corto: 'Relleno',
    ayuda: 'Tierra, escombros u obras sobre el agua.',
    pregunta: '¿Hay maquinaria trabajando?',
    icono: Icons.construction_rounded,
    color: Color(0xFF7A6A55),
    gravedad: 4,
  ),
  vertimiento(
    slug: 'vertimiento',
    nombre: 'Vertimiento o contaminación del agua',
    corto: 'Vertimiento',
    ayuda: 'Agua sucia, aceite, espuma o mal olor.',
    pregunta: '¿De dónde sale? ¿Tiene color u olor?',
    icono: Icons.water_drop_rounded,
    color: Color(0xFF6A4FA3),
    gravedad: 4,
  ),
  canoTaponado(
    slug: 'cano_taponado',
    nombre: 'Caño taponado o alteración del agua',
    corto: 'Caño',
    ayuda: 'Un caño cerrado: le falta agua dulce.',
    pregunta: '¿El agua todavía corre o está quieta?',
    icono: Icons.waves_rounded,
    color: Color(0xFF1F7A8C),
    gravedad: 4,
  ),
  fauna(
    slug: 'fauna',
    nombre: 'Fauna afectada',
    corto: 'Fauna',
    ayuda: 'Caza, peces o aves muertas, animales heridos.',
    pregunta: '¿Cuántos animales ves, más o menos?',
    icono: Icons.flutter_dash_rounded,
    color: Color(0xFF2E7D5B),
    gravedad: 4,
  ),
  basuras(
    slug: 'basuras',
    nombre: 'Basuras o residuos',
    corto: 'Basuras',
    ayuda: 'Plástico en las raíces o botaderos.',
    pregunta: '¿Es poca basura o un botadero?',
    icono: Icons.delete_outline_rounded,
    color: Color(0xFF5B6B73),
    gravedad: 2,
  ),
  otro(
    slug: 'otro',
    nombre: 'Otro',
    corto: 'Otro',
    ayuda: 'Algo raro que lo pone en riesgo.',
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

/// Estados del contrato común (handoff/05). `nombre` y `explicacion` son las MISMAS frases que el bot
/// manda por WhatsApp (`bot/src/reportes/modelo.ts`: ESTADOS y DESCRIPCION_ESTADO) y la web
/// (`web/src/lib/catalogos.ts`): quien reporta por WhatsApp y mira la app lee lo mismo.
enum EstadoReporte {
  recibido('recibido', 'Recibido', 'Recibido para revisión.'),
  enVerificacion('en_verificacion', 'En verificación', 'Una persona de la C.R.A. revisa la evidencia.'),
  verificado('verificado', 'Verificado', 'Hallazgo confirmado por una persona.'),
  alertaOficial('alerta_oficial', 'Alerta oficial', 'Alerta emitida con apertura de expediente.'),
  enAtencion('en_atencion', 'En atención', 'Caso en atención por el equipo.'),
  cerrado('cerrado', 'Cerrado', 'Seguimiento finalizado.'),
  descartado('descartado', 'Descartado', 'La evidencia no confirma el reporte.');

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
