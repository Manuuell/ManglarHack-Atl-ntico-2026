import 'dart:math' as math;

/// Una pregunta del reto del manglar. [correcta] es el índice dentro de [opciones].
class PreguntaReto {
  const PreguntaReto({
    required this.id,
    required this.enunciado,
    required this.opciones,
    required this.correcta,
    required this.explicacion,
    required this.fuente,
  });
  final String id, enunciado, explicacion, fuente;
  final List<String> opciones;
  final int correcta;

  String get respuestaCorrecta => opciones[correcta];

  PreguntaReto conOpciones(List<String> nuevas) => PreguntaReto(
        id: id,
        enunciado: enunciado,
        opciones: nuevas,
        correcta: nuevas.indexOf(respuestaCorrecta),
        explicacion: explicacion,
        fuente: fuente,
      );
}

const _inv = 'INVEMAR, divulgación sobre manglares de Colombia';
const _cra = 'CRA, datos entregados en el lanzamiento del 27-11-2026';

const List<PreguntaReto> bancoRetos = [
  PreguntaReto(
    id: 'especies',
    enunciado: '¿Cuántas especies de mangle verdadero hay en el Caribe colombiano?',
    opciones: ['Dos', 'Cuatro', 'Diez', 'Veinte'],
    correcta: 1,
    explicacion: 'Son cuatro: rojo, negro, blanco y botón. Cada una vive en una franja distinta del manglar.',
    fuente: _inv,
  ),
  PreguntaReto(
    id: 'rojo_raices',
    enunciado: '¿Qué mangle tiene raíces en arco, como zancos?',
    opciones: ['Mangle rojo', 'Mangle blanco', 'Mangle botón', 'Ninguno'],
    correcta: 0,
    explicacion: 'El mangle rojo (Rhizophora mangle) apoya el tronco en raíces zancudas. Por eso Zanky camina en zancos.',
    fuente: _inv,
  ),
  PreguntaReto(
    id: 'carbono',
    enunciado: '¿Dónde guarda más carbono un manglar?',
    opciones: ['En el suelo', 'En las flores', 'En el aire', 'En las nubes'],
    correcta: 0,
    explicacion: 'Gran parte del carbono azul queda bajo tierra. Si se rellena o se tala, se escapa a la atmósfera.',
    fuente: _inv,
  ),
  PreguntaReto(
    id: 'salobre',
    enunciado: '¿Qué es el agua salobre?',
    opciones: ['Agua dulce de río', 'Agua del mar puro', 'Mezcla de agua dulce y salada', 'Agua de lluvia'],
    correcta: 2,
    explicacion: 'El manglar vive donde los caños y las ciénagas se mezclan con el mar.',
    fuente: _inv,
  ),
  PreguntaReto(
    id: 'zonas',
    enunciado: '¿Cuántas zonas costeras de manglar del Atlántico cubre Zanky?',
    opciones: ['Una', 'Dos', 'Cuatro', 'Nueve'],
    correcta: 2,
    explicacion: 'Mallorquín, Tubará, Juan de Acosta y Piojó, unas 775 hectáreas en total.',
    fuente: _cra,
  ),
  PreguntaReto(
    id: 'autoridad',
    enunciado: '¿Quién es la autoridad ambiental del departamento del Atlántico?',
    opciones: ['La CRA', 'El INVEMAR', 'La Registraduría', 'Las empresas de aseo'],
    correcta: 0,
    explicacion: 'La Corporación Autónoma Regional del Atlántico recibe los reportes y decide cómo actuar.',
    fuente: _cra,
  ),
  PreguntaReto(
    id: 'negro_respira',
    enunciado: '¿Cómo respira el mangle negro en suelo inundado?',
    opciones: ['Con raíces verticales como lápices', 'Con branquias', 'Con las flores', 'No respira'],
    correcta: 0,
    explicacion: 'Saca del fango raíces finas y verticales (neumatóforos) que toman aire.',
    fuente: _inv,
  ),
  PreguntaReto(
    id: 'criadero',
    enunciado: '¿Qué animales usan las raíces del manglar como criadero?',
    opciones: ['Peces y camarones jóvenes', 'Solo los camellos', 'Ningún animal', 'Solo los murciélagos'],
    correcta: 0,
    explicacion: 'Entre las raíces los peces, camarones y cangrejos pequeños crecen protegidos antes de salir al mar.',
    fuente: _inv,
  ),
  PreguntaReto(
    id: 'amenaza',
    enunciado: '¿Cuál de estas es una amenaza para el manglar?',
    opciones: ['Rellenar con escombros', 'Sembrar mangle', 'Contar aves', 'Caminar sin dejar basura'],
    correcta: 0,
    explicacion: 'El relleno, la tala, la quema, la basura y los vertimientos son las amenazas que Zanky te deja reportar.',
    fuente: 'Diseño de Zanky (documentación de la app)',
  ),
  PreguntaReto(
    id: 'ley',
    enunciado: '¿Qué protege la Ley 1581 de 2012?',
    opciones: ['Los datos personales', 'Los precios del mercado', 'Las vías', 'Los uniformes'],
    correcta: 0,
    explicacion: 'Es la ley de protección de datos personales: por eso Zanky pide tu consentimiento antes de guardar tu nombre.',
    fuente: 'Ley estatutaria 1581 de 2012',
  ),
  PreguntaReto(
    id: 'foto',
    enunciado: 'Al reportar una amenaza, la foto debe...',
    opciones: ['Tomarse en el momento', 'Bajarse de internet', 'Venir de hace un mes', 'No hacer falta'],
    correcta: 0,
    explicacion: 'Un reporte sirve a la CRA si es de «ahora mismo» y con ubicación; la foto se toma desde la app, no de la galería.',
    fuente: _cra,
  ),
  PreguntaReto(
    id: 'propagulo',
    enunciado: '¿Cómo es la semilla del mangle rojo?',
    opciones: ['Alargada, germina colgada del árbol', 'Redonda como una pelota', 'Con alas', 'Es un hongo'],
    correcta: 0,
    explicacion: 'Se llama propágulo: ya viene germinada y cae para clavarse en el fango o flotar hasta otro sitio.',
    fuente: _inv,
  ),
  PreguntaReto(
    id: 'costa',
    enunciado: '¿Cómo protege el manglar a la costa?',
    opciones: ['Frena el oleaje y la erosión', 'Sube el nivel del mar', 'Seca la ciénaga', 'No la protege'],
    correcta: 0,
    explicacion: 'Sus raíces enredadas amortiguan las olas y sujetan el suelo.',
    fuente: _inv,
  ),
  PreguntaReto(
    id: 'sin_senal',
    enunciado: 'Si no hay señal en el manglar, ¿qué pasa con tu reporte en Zanky?',
    opciones: ['Se guarda y se envía luego', 'Se pierde', 'Se borra', 'No se puede hacer'],
    correcta: 0,
    explicacion: 'Queda en tu teléfono y se manda solo cuando vuelve la señal, sin duplicarse.',
    fuente: 'Diseño de Zanky (documentación de la app)',
  ),
  PreguntaReto(
    id: 'jornada_llevar',
    enunciado: '¿Qué conviene llevar a una jornada en el manglar?',
    opciones: ['Agua, gorra y botas que se puedan mojar', 'Solo tacones', 'Una nevera de hielo seco', 'Nada: allá dan todo'],
    correcta: 0,
    explicacion: 'Agua, gorra, bloqueador, botas que se puedan mojar y guantes: el sol y el fango se sienten.',
    fuente: 'Diseño de Zanky (documentación de la app)',
  ),
];

int _semilla(String texto) {
  var h = 0x811C9DC5; // FNV-1a de 32 bits
  for (final u in texto.codeUnits) {
    h = ((h ^ u) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// El reto de un evento: siempre el mismo para el mismo código (todos los del grupo juegan lo mismo),
/// con las opciones barajadas de forma estable.
List<PreguntaReto> retoPara(String codigoEvento, {int cuantas = 5}) {
  final azar = math.Random(_semilla(codigoEvento));
  final orden = List<PreguntaReto>.of(bancoRetos)..shuffle(azar);
  return [
    for (final p in orden.take(cuantas.clamp(1, bancoRetos.length)))
      p.conOpciones(List<String>.of(p.opciones)..shuffle(azar)),
  ];
}
