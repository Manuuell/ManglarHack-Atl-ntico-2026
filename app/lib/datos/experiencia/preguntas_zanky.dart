import 'jornada.dart';

/// Cómo suena Zanky en una respuesta; la vista lo traduce a su ánimo.
enum TonoZanky { feliz, curioso, preocupado, celebrando }

class RespuestaZanky {
  const RespuestaZanky({
    required this.texto,
    this.fuente,
    this.tono = TonoZanky.feliz,
    this.sugerencias = const [],
    this.encontrada = true,
  });
  final String texto;
  final String? fuente;
  final TonoZanky tono;
  final List<String> sugerencias;
  final bool encontrada;
}

/// Preguntas cortas para los chips al abrir la charla.
const List<String> sugerenciasIniciales = [
  '¿Qué es un manglar?',
  '¿Qué es el carbono azul?',
  '¿Cómo reporto una amenaza?',
  '¿Qué especies de mangle hay?',
  '¿Qué pasa con mis datos?',
  '¿Qué debo llevar a la jornada?',
];

/// Una pregunta frecuente. [claves] son las palabras que la activan (sin tildes, en minúscula).
class PreguntaFrecuente {
  const PreguntaFrecuente({
    required this.id,
    required this.pregunta,
    required this.claves,
    required this.respuesta,
    required this.fuente,
    this.tono = TonoZanky.feliz,
    this.siguientes = const [],
  });
  final String id, pregunta, claves, respuesta, fuente;
  final TonoZanky tono;
  final List<String> siguientes;
}

const _fInvemar = 'INVEMAR, divulgación sobre manglares de Colombia';
const _fCra = 'CRA, datos entregados en el lanzamiento del 27-11-2026';
const _fZanky = 'Diseño de Zanky (documentación de la app)';
const _fLey = 'Ley estatutaria 1581 de 2012 (protección de datos personales)';

const List<PreguntaFrecuente> preguntasFrecuentes = [
  PreguntaFrecuente(
    id: 'que_es',
    pregunta: '¿Qué es un manglar?',
    claves: 'que es manglar mangle bosque definicion salobre',
    respuesta:
        'Un manglar es un bosque que crece en la orilla del mar y de las ciénagas, con los pies metidos en agua '
        'salobre (una mezcla de agua dulce y salada). Sus árboles aguantan la sal y el suelo inundado.',
    fuente: _fInvemar,
    siguientes: ['¿Qué especies de mangle hay?', '¿Por qué son importantes?'],
  ),
  PreguntaFrecuente(
    id: 'especies',
    pregunta: '¿Qué especies de mangle hay?',
    claves: 'especies tipos clases rojo negro blanco boton zaragoza rhizophora avicennia laguncularia conocarpus',
    respuesta:
        'En el Caribe colombiano hay cuatro: mangle rojo (Rhizophora mangle), mangle negro o salado (Avicennia '
        'germinans), mangle blanco (Laguncularia racemosa) y mangle botón o zaragoza (Conocarpus erectus).',
    fuente: _fInvemar,
    siguientes: ['¿Cómo reconozco el mangle rojo?', '¿Cómo reconozco el mangle negro?'],
  ),
  PreguntaFrecuente(
    id: 'rojo',
    pregunta: '¿Cómo reconozco el mangle rojo?',
    claves: 'reconozco reconocer rojo raices zancos zancudas arqueadas rhizophora',
    respuesta:
        'Por sus raíces: salen del tronco en arco y se hunden en el agua, como patas largas o zancos. De ahí '
        'viene mi nombre. Sus semillas son alargadas como lápices verdes y germinan colgadas del árbol.',
    fuente: _fInvemar,
    siguientes: ['¿Por qué te llamas Zanky?', '¿Cómo nace un mangle?'],
  ),
  PreguntaFrecuente(
    id: 'negro',
    pregunta: '¿Cómo reconozco el mangle negro?',
    claves: 'negro salado avicennia neumatoforos respirar sal hojas cristales',
    respuesta:
        'El mangle negro saca del suelo raíces finas y verticales, como lápices, para respirar. Sus hojas '
        'amanecen con cristalitos de sal: es la forma en que botan la que sobra.',
    fuente: _fInvemar,
    siguientes: ['¿Qué especies de mangle hay?'],
  ),
  PreguntaFrecuente(
    id: 'blanco',
    pregunta: '¿Cómo reconozco el mangle blanco?',
    claves: 'blanco bobo laguncularia glandulas peciolo',
    respuesta:
        'El mangle blanco suele crecer en la parte más alta y seca del manglar. Se reconoce por dos glándulas '
        'pequeñas en la base de la hoja, donde la hoja se une al tallo.',
    fuente: _fInvemar,
    siguientes: ['¿Qué especies de mangle hay?'],
  ),
  PreguntaFrecuente(
    id: 'importancia',
    pregunta: '¿Por qué son importantes los manglares?',
    claves: 'importantes importancia sirven beneficios proteger proteccion costa erosion oleaje tormentas servicios',
    respuesta:
        'Frenan el oleaje y protegen la costa de la erosión, son criadero de peces, camarones y cangrejos, '
        'atrapan sedimentos y contaminantes, y guardan carbono. Mucha gente vive de lo que nace en ellos.',
    fuente: _fInvemar,
    siguientes: ['¿Qué es el carbono azul?', '¿Qué animales viven en el manglar?'],
  ),
  PreguntaFrecuente(
    id: 'carbono',
    pregunta: '¿Qué es el carbono azul?',
    claves: 'carbono azul clima cambio climatico co2 dioxido almacena guarda captura calentamiento',
    respuesta:
        'Es el carbono que guardan los ecosistemas costeros como manglares, pastos marinos y marismas, sobre todo '
        'dentro del suelo. Si se tala o se rellena el manglar, ese carbono vuelve a la atmósfera.',
    fuente: _fInvemar,
    tono: TonoZanky.curioso,
    siguientes: ['¿Por qué se pierden los manglares?'],
  ),
  PreguntaFrecuente(
    id: 'amenazas',
    pregunta: '¿Por qué se pierden los manglares?',
    claves: 'amenazas amenaza pierden perdida acaba destruyen causas problemas tala quema relleno basura deterioro',
    respuesta:
        'Por la tala, la quema, el relleno con tierra o escombros para construir, la basura y los vertimientos, '
        'y por cerrar los caños que traen agua dulce y salada. Por eso Zanky te deja reportar cada una.',
    fuente: _fZanky,
    tono: TonoZanky.preocupado,
    siguientes: ['¿Cómo reporto una amenaza?', '¿Se puede talar el manglar?'],
  ),
  PreguntaFrecuente(
    id: 'talar',
    pregunta: '¿Se puede talar el manglar?',
    claves: 'talar tala cortar permiso prohibido legal ilegal ley autorizacion permitido',
    respuesta:
        'Por regla general, no se puede intervenir el manglar sin autorización de la autoridad ambiental. En el '
        'Atlántico esa autoridad es la CRA. Si ves cortes sin permiso, repórtalo.',
    fuente: 'Resolución 1602 de 1995 del Ministerio de Ambiente y Decreto 1076 de 2015',
    tono: TonoZanky.preocupado,
    siguientes: ['¿Cómo reporto una amenaza?', '¿Qué es la CRA?'],
  ),
  PreguntaFrecuente(
    id: 'cra',
    pregunta: '¿Qué es la CRA?',
    claves: 'cra corporacion autonoma regional autoridad ambiental quien',
    respuesta:
        'Es la Corporación Autónoma Regional del Atlántico, la autoridad ambiental del departamento. Recibe tus '
        'reportes y decide si hace un operativo.',
    fuente: _fCra,
    siguientes: ['¿Qué pasa con mi reporte?'],
  ),
  PreguntaFrecuente(
    id: 'zonas',
    pregunta: '¿Qué zonas de manglar cubre Zanky?',
    claves: 'zonas cubre hectareas atlantico municipios mallorquin tubara acosta piojo donde',
    respuesta:
        'Cuatro zonas costeras del Atlántico, unas 775 hectáreas: Barranquilla y Puerto Colombia (Mallorquín), '
        'Tubará, Juan de Acosta y Piojó.',
    fuente: _fCra,
    siguientes: ['¿Qué es la ciénaga de Mallorquín?'],
  ),
  PreguntaFrecuente(
    id: 'mallorquin',
    pregunta: '¿Qué es la ciénaga de Mallorquín?',
    claves: 'cienaga mallorquin ecoparque barranquilla puerto colombia',
    respuesta:
        'Es una ciénaga costera entre Barranquilla y Puerto Colombia, con su ecoparque y uno de los manglares más '
        'visitados del departamento. Es nuestra zona de prueba.',
    fuente: _fCra,
    siguientes: ['¿Qué zonas de manglar cubre Zanky?'],
  ),
  PreguntaFrecuente(
    id: 'reportar',
    pregunta: '¿Cómo reporto una amenaza?',
    claves: 'reporto reportar reporte denunciar denuncia avisar informar foto',
    respuesta:
        'Toca «Reportar», elige el tipo de amenaza, toma la foto en el momento y confirma el lugar. Si no hay '
        'señal, el reporte queda guardado en tu teléfono y se envía solo cuando vuelva.',
    fuente: _fZanky,
    siguientes: ['¿Qué pasa con mi reporte?', '¿Puedo reportar sin dar mi nombre?'],
  ),
  PreguntaFrecuente(
    id: 'despues',
    pregunta: '¿Qué pasa con mi reporte?',
    claves: 'pasa reporte despues estado validacion validan revisan recibe llega seguimiento',
    respuesta:
        'Le llega a la CRA con foto y ubicación. Un vigía comunitario o un funcionario lo confirma, y puedes ver '
        'su estado en «Mis reportes». Zanky no promete que haya operativo: eso lo decide la CRA.',
    fuente: _fZanky,
    siguientes: ['¿Qué es la CRA?'],
  ),
  PreguntaFrecuente(
    id: 'anonimo',
    pregunta: '¿Puedo reportar sin dar mi nombre?',
    claves: 'anonimo anonima nombre identidad privado esconder',
    respuesta:
        'Sí. Puedes marcar el reporte como anónimo: llega sin tu nombre. La CRA solo ve lo necesario para actuar.',
    fuente: _fZanky,
    siguientes: ['¿Qué pasa con mis datos?'],
  ),
  PreguntaFrecuente(
    id: 'datos',
    pregunta: '¿Qué pasa con mis datos?',
    claves: 'datos personales privacidad guardan guarda cedula informacion',
    respuesta:
        'Tu perfil vive solo en tu teléfono. La cédula es opcional y nunca se guarda en claro. En un evento, tu '
        'nombre y tu grupo también se quedan en tu teléfono y solo con tu permiso.',
    fuente: _fZanky,
    siguientes: ['¿Qué dice la Ley 1581?', '¿Puedo borrar mis datos?'],
  ),
  PreguntaFrecuente(
    id: 'ley1581',
    pregunta: '¿Qué dice la Ley 1581?',
    claves: 'ley 1581 habeas consentimiento proteccion tratamiento derechos',
    respuesta:
        'Es la ley colombiana de protección de datos personales: nadie puede usar tus datos sin tu autorización '
        'informada, y tienes derecho a conocerlos, corregirlos y pedir que se borren. Por eso pedimos tu '
        'consentimiento antes de registrar tu asistencia.',
    fuente: _fLey,
    siguientes: ['¿Puedo borrar mis datos?'],
  ),
  PreguntaFrecuente(
    id: 'borrar',
    pregunta: '¿Puedo borrar mis datos?',
    claves: 'borrar eliminar quitar suprimir olvidar',
    respuesta:
        'Sí: en tu tarjeta de guardián está «Borrar mis datos de este teléfono». Lo que está solo en tu teléfono '
        'se elimina en el momento.',
    fuente: _fLey,
    siguientes: ['¿Qué dice la Ley 1581?'],
  ),
  PreguntaFrecuente(
    id: 'jornadas',
    pregunta: '¿Qué es una jornada?',
    claves: 'jornada jornadas actividad evento siembra limpieza monitoreo recorrido vigias',
    respuesta:
        'Es una salida organizada al manglar: siembra, limpieza, monitoreo o recorrido de vigías. Se llega al '
        'punto de encuentro, se trabaja en grupo y se registra la asistencia en Zanky.',
    fuente: _fZanky,
    siguientes: ['¿Qué debo llevar a la jornada?', '¿Cómo sumo puntos?'],
  ),
  PreguntaFrecuente(
    id: 'llevar',
    pregunta: '¿Qué debo llevar a la jornada?',
    claves: 'llevar llevo traer necesito ropa botas gorra bloqueador agua guantes',
    respuesta:
        'Agua potable, gorra, bloqueador solar, botas que se puedan mojar y guantes de trabajo. Ropa cómoda que '
        'se pueda ensuciar: el fango del manglar no perdona.',
    fuente: _fZanky,
    siguientes: ['¿Qué es una jornada?'],
  ),
  PreguntaFrecuente(
    id: 'puntos',
    pregunta: '¿Cómo sumo puntos?',
    claves: 'puntos sumo sumar ganar puntaje reto trivia asistencia premio',
    respuesta:
        'Registrar tu asistencia a una jornada da 40 puntos. En el reto del manglar sumas 10 por cada acierto, y '
        'si lo repites solo cuenta cuando mejoras tu mejor resultado. Son aparte de los puntos de tus reportes.',
    fuente: _fZanky,
    tono: TonoZanky.celebrando,
    siguientes: ['¿Qué es una jornada?'],
  ),
  PreguntaFrecuente(
    id: 'zanky',
    pregunta: '¿Por qué te llamas Zanky?',
    claves: 'zanky zanqui nombre llamas mascota quien eres zancos zanqueros carnaval',
    respuesta:
        'Soy un mangle rojo chiquito. Mi nombre viene de sus raíces en zancos y de los zanqueros del Carnaval de '
        'Barranquilla. Camino sobre mis raíces para cuidar el manglar contigo.',
    fuente: _fZanky,
    tono: TonoZanky.celebrando,
    siguientes: ['¿Cómo reconozco el mangle rojo?'],
  ),
  PreguntaFrecuente(
    id: 'fauna',
    pregunta: '¿Qué animales viven en el manglar?',
    claves: 'animales fauna viven aves peces cangrejos camarones garzas pelicanos ostras',
    respuesta:
        'Aves como garzas y pelícanos, cangrejos, camarones, ostras y peces jóvenes que crecen entre las raíces '
        'antes de salir al mar abierto.',
    fuente: _fInvemar,
    siguientes: ['¿Por qué son importantes los manglares?'],
  ),
  PreguntaFrecuente(
    id: 'semilla',
    pregunta: '¿Cómo nace un mangle?',
    claves: 'nace nacer semilla propagulo siembra crece crecimiento germina tarda',
    respuesta:
        'El mangle rojo es vivíparo: la semilla germina colgada del árbol y cae como un propágulo alargado que '
        'flota hasta clavarse en el fango. Crecer a un bosque toma muchos años, por eso cuidar el que existe '
        'vale más que sembrar uno nuevo.',
    fuente: _fInvemar,
    tono: TonoZanky.curioso,
    siguientes: ['¿Cómo ayudo sin reportar?'],
  ),
  PreguntaFrecuente(
    id: 'ayudar',
    pregunta: '¿Cómo ayudo sin reportar?',
    claves: 'ayudo ayudar cuidar colaborar voluntario hacer proteger basura visitar',
    respuesta:
        'No dejes basura, no cortes ramas ni raíces, no pises los propágulos, ve a las jornadas y cuéntale a otra '
        'persona lo que aprendiste. Cuidar también es avisar a tiempo.',
    fuente: _fZanky,
    siguientes: ['¿Qué es una jornada?'],
  ),
  PreguntaFrecuente(
    id: 'capas',
    pregunta: '¿De dónde salen los polígonos del mapa?',
    claves: 'mapa poligonos capa capas invemar satelite zonas dibujo origen',
    respuesta:
        'Las zonas oficiales vienen de la CRA. Además hay una capa de referencia del INVEMAR (imagen de 2020, 144 '
        'polígonos y 533 hectáreas en el Atlántico) que no es la capa de la CRA y se rotula aparte.',
    fuente: _fCra,
    siguientes: ['¿Qué zonas de manglar cubre Zanky?'],
  ),
  PreguntaFrecuente(
    id: 'sin_senal',
    pregunta: '¿Funciona sin señal?',
    claves: 'senal internet conexion offline linea wifi datos moviles',
    respuesta:
        'Sí. Los reportes se guardan en tu teléfono y se envían solos cuando vuelve la señal. Estas respuestas '
        'también funcionan sin internet.',
    fuente: _fZanky,
    siguientes: ['¿Cómo reporto una amenaza?'],
  ),
  PreguntaFrecuente(
    id: 'seguridad',
    pregunta: '¿Es seguro ir al manglar?',
    claves: 'seguro seguridad peligro peligros riesgo mosquitos sol lodo marea cuidado',
    respuesta:
        'Ve acompañado y con las indicaciones de la organización: el sol, el fango y los mosquitos son lo más '
        'común. Si ves tala o fuego, no te acerques: reporta a distancia.',
    fuente: _fZanky,
    tono: TonoZanky.preocupado,
    siguientes: ['¿Qué debo llevar a la jornada?'],
  ),
  PreguntaFrecuente(
    id: 'salobre',
    pregunta: '¿Qué es el agua salobre?',
    claves: 'salobre agua dulce salada mezcla sal',
    respuesta:
        'Es agua con menos sal que el mar pero más que un río: la mezcla donde los caños y las ciénagas se '
        'encuentran con el mar. El mangle vive justo ahí.',
    fuente: _fInvemar,
    siguientes: ['¿Qué es un manglar?'],
  ),
];

// Palabras que no ayudan a decidir (y las que están en casi toda pregunta sobre el tema).
const _vacias = {
  'que', 'como', 'cual', 'cuales', 'donde', 'cuando', 'para', 'con', 'sin', 'una', 'uno', 'unos',
  'unas', 'los', 'las', 'del', 'por', 'hay', 'mis', 'tus', 'sus', 'mas', 'muy', 'pero', 'son', 'soy', 'eres',
  'esta', 'este', 'esto', 'ese', 'esa', 'puedo', 'puede', 'hace', 'hacer', 'dime', 'hola', 'sobre', 'tiene',
  'tienen', 'cuanto', 'cuantos', 'cuantas', 'quien', 'porque',
};

// Las palabras del tema: casi toda pregunta las trae, así que solo cuentan cuando no hay otra cosa.
const _deTema = {'zanky', 'zanqui', 'manglar', 'manglares'};

String _sinTildes(String s) {
  const de = 'áàäâéèëêíìïîóòöôúùüûñ';
  const a = 'aaaaeeeeiiiioooouuuun';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = de.indexOf(c);
    b.write(i >= 0 ? a[i] : c);
  }
  return b.toString();
}

String _raiz(String t) {
  if (t.length > 4 && t.endsWith('es')) return t.substring(0, t.length - 2);
  if (t.length > 3 && t.endsWith('s')) return t.substring(0, t.length - 1);
  return t;
}

/// Palabras útiles de un texto: sin tildes, sin signos, sin palabras vacías, en singular aproximado.
List<String> palabrasClave(String texto, {bool conTema = false}) {
  final limpio = _sinTildes(texto).replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  return [
    for (final p in limpio.split(RegExp(r'\s+')))
      if (p.length >= 3 && !_vacias.contains(p) && (conTema || !_deTema.contains(p))) _raiz(p),
  ];
}

bool _coincide(String a, String b) {
  if (a == b) return true;
  final m = a.length < b.length ? a : b;
  final l = a.length < b.length ? b : a;
  return m.length >= 5 && l.startsWith(m);
}

/// Las preguntas más parecidas a [consulta], de mejor a peor (puntaje > 0). Para la búsqueda y los chips.
List<PreguntaFrecuente> buscarPreguntas(String consulta, {int max = 3}) {
  var conTema = false;
  var q = palabrasClave(consulta);
  if (q.isEmpty) {
    conTema = true; // «¿Qué es un manglar?»: solo queda la palabra del tema
    q = palabrasClave(consulta, conTema: true);
  }
  if (q.isEmpty) return const [];
  final puntuadas = <(PreguntaFrecuente, double)>[];
  for (final p in preguntasFrecuentes) {
    final claves = palabrasClave(p.claves, conTema: conTema);
    final enPregunta = palabrasClave(p.pregunta, conTema: conTema);
    var puntos = 0.0;
    for (final t in q) {
      if (claves.any((c) => _coincide(t, c))) {
        puntos += 1;
      } else if (enPregunta.any((c) => _coincide(t, c))) {
        puntos += 0.6;
      }
    }
    if (puntos > 0) puntuadas.add((p, puntos));
  }
  puntuadas.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final e in puntuadas.take(max)) e.$1];
}

/// Responde sin conexión. Si no encuentra nada lo dice, con sugerencias; nunca inventa.
RespuestaZanky responderSinConexion(String pregunta, {EventoZanky? evento}) {
  final texto = pregunta.trim();
  if (palabrasClave(texto, conTema: true).isEmpty) {
    return const RespuestaZanky(
      texto: 'Cuéntame qué quieres saber del manglar. Por ejemplo, prueba con una de estas preguntas.',
      tono: TonoZanky.curioso,
      sugerencias: sugerenciasIniciales,
      encontrada: false,
    );
  }
  // Preguntas sobre ESTE evento: se responden con sus datos reales.
  final j = evento?.jornada;
  final sn = _sinTildes(texto);
  final sobreEvento = RegExp(r'(cuando|hora|fecha|donde|punto de encuentro|cupo|inscri|esta jornada|este evento)')
      .hasMatch(sn);
  if (j != null && sobreEvento && !sn.contains('mallorquin') && !sn.contains('zona')) {
    final cupos = j.sinLimite
        ? ' Es gratis y sin límite de cupos${j.inscritos > 0 ? ': ya van ${j.inscritos}' : ''}.'
        : j.llena
            ? ' Los cupos están llenos.'
            : ' Quedan ${j.cuposLibres} de ${j.cupos} cupos.';
    return RespuestaZanky(
      texto: '${j.titulo}: ${fechaLarga(j.inicio)}, de ${horaCorta(j.inicio)} a ${horaCorta(j.fin)}. '
          'Nos vemos en ${j.puntoEncuentro}.$cupos${j.esEjemplo ? ' (Datos de ejemplo.)' : ''}',
      fuente: j.esEjemplo ? 'Datos de ejemplo de la jornada' : 'Datos de la jornada',
      sugerencias: const ['¿Qué debo llevar a la jornada?', '¿Cómo sumo puntos?'],
    );
  }
  if (j != null && j.queLlevar.isNotEmpty && RegExp(r'(llevar|llevo|traer)').hasMatch(sn)) {
    return RespuestaZanky(
      texto: 'Para esta jornada: ${j.queLlevar.map((e) => e.toLowerCase()).join(', ')}.',
      fuente: j.esEjemplo ? 'Datos de ejemplo de la jornada' : 'Datos de la jornada',
      sugerencias: const ['¿Es seguro ir al manglar?', '¿Cómo sumo puntos?'],
    );
  }
  final r = buscarPreguntas(texto, max: 3);
  if (r.isNotEmpty) {
    final p = r.first;
    return RespuestaZanky(
      texto: p.respuesta,
      fuente: p.fuente,
      tono: p.tono,
      sugerencias: p.siguientes.isNotEmpty ? p.siguientes : [for (final o in r.skip(1)) o.pregunta],
    );
  }
  return const RespuestaZanky(
    texto: 'Esa no me la sé sin conexión, y prefiero no inventarte nada. Puedo contarte de estas cosas:',
    tono: TonoZanky.curioso,
    sugerencias: sugerenciasIniciales,
    encontrada: false,
  );
}
