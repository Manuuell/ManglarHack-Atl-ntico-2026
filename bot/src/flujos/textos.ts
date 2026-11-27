import { Boton, Fila } from '../whatsapp/cloudApi';
import { Jornada, TIPOS_JORNADA, enlaceComoLlegar, enlaceEventoZanky, enlaceInvitacion, fmt as fmtJornada } from '../jornadas/jornadas';
import { DESCRIPCION_ESTADO, ESTADOS, MAGNITUDES, MOMENTOS, MUNICIPIOS, MagnitudId, MomentoId, MunicipioId, ROLES, Reporte, RolId, TIPOS, TipoId } from '../reportes/modelo';

export const ENCABEZADO = 'Zanky BOT 🌿';

// --- Registro de vigías -----------------------------------------------------

export const BIENVENIDA = {
  cuerpo:
    '¡Ajá! Soy *Zanky* 🌿, el vigía del manglar del Atlántico.\n\n' +
    'Aquí puedes avisarle a la CRA cuando algo amenaza el manglar: tala, quemas, basura, vertimientos o un caño tapado.\n\n' +
    '¿Te registras como *vigía del manglar*? Toma menos de un minuto.\n\n' +
    '🔒 Tus datos se tratan según la Ley 1581 de 2012 y nunca se publican tu nombre ni tu número.',
  botones: [
    { id: 'registrarme', titulo: '✅ Registrarme' },
    { id: 'reg_anonimo', titulo: '👤 Sin mi nombre' },
    { id: 'ahora_no', titulo: 'Ahora no' },
  ] as Boton[],
};

/** Se ofrece después del primer envío: primero se atiende la denuncia, después el registro. */
export const OFRECER_REGISTRO =
  '🙌 ¿Te registras como *vigía del manglar*? Toma menos de un minuto y así la CRA sabe quién cuida cada zona.\n\n' +
  '🔒 Tus datos se tratan según la Ley 1581 de 2012 y nunca se publican tu nombre ni tu número.';

export const PEDIR_NOMBRE ='¿Cómo te llamas? Escríbeme tu nombre 🙂';

export const NOMBRE_INVALIDO = 'Ese nombre no me cuadra 🤔. Escríbelo solo con letras, por ejemplo: *María Pérez*.';

export const ROL = {
  cuerpo: '¿Qué te une al manglar?',
  boton: 'Elegir',
  filas: (Object.keys(ROLES) as RolId[]).map<Fila>(id => ({ id, titulo: `${ROLES[id].emoji} ${ROLES[id].nombre}`, descripcion: ROLES[id].descripcion })),
};

export const MUNICIPIO = {
  cuerpo: '¿En qué municipio estás normalmente?',
  boton: 'Elegir',
  filas: (Object.keys(MUNICIPIOS) as MunicipioId[]).map<Fila>(id => ({ id, titulo: MUNICIPIOS[id] })),
};

export function registrado(nombre: string | undefined, numero: number, rol: RolId, municipio: MunicipioId): string {
  return (
    `¡Listo${nombre ? `, *${nombre}*` : ''}! 🌿 Ya eres el *vigía #${numero}* del manglar del Atlántico.\n\n` +
    `${ROLES[rol].emoji} ${ROLES[rol].nombre} · 📍 ${MUNICIPIOS[municipio]}\n\n` +
    'Cuando veas algo raro en el manglar, escríbeme y toca *🚨 Reportar*. Y si quieres ayudar en persona, toca *🌱 Jornadas*.'
  );
}

export function saludoMenu(nombre?: string): string {
  return nombre ? `¡Ajá, *${nombre}*! ¿Qué quieres hacer?` : '¡Ajá! ¿Qué quieres hacer?';
}

export const MENU = {
  cuerpo:
    '¡Ajá! Soy *Zanky*, el vigía del manglar del Atlántico.\n\n' +
    'Si ves algo que le hace daño al manglar (tala, quemas, basura, vertimientos o un caño tapado), ' +
    'cuéntamelo aquí: le llega a la CRA, que lo verifica y decide cómo actuar.\n\n' +
    'También puedes sumarte a una *jornada* de siembra o limpieza. Escribe *ayuda* para saber cómo funciona.',
  botones: [
    { id: 'reportar', titulo: '🚨 Reportar' },
    { id: 'jornadas', titulo: '🌱 Jornadas' },
    { id: 'mis_reportes', titulo: '📋 Mis reportes' },
  ] as Boton[],
  /** El menú completo va como lista: WhatsApp solo admite 3 botones y son 6 opciones. */
  boton: 'Ver opciones',
  filas: [
    { id: 'reportar', titulo: '🚨 Reportar', descripcion: 'Avisa de una tala, quema, basura u otra amenaza' },
    { id: 'proponer', titulo: '💡 Proponer', descripcion: 'Propón una siembra, limpieza u otra acción' },
    { id: 'jornadas', titulo: '🌱 Jornadas', descripcion: 'Siembras y limpiezas: inscríbete aquí mismo' },
    { id: 'mis_reportes', titulo: '📋 Mis reportes', descripcion: 'El estado de lo que has reportado' },
    { id: 'alertas', titulo: '⚠️ Alertas', descripcion: 'Mar de leva, aguaceros, vientos o incendio' },
    { id: 'como_funciona', titulo: '❓ Cómo funciona', descripcion: 'Qué hace Zanky y cómo se usan tus datos' },
  ] as Fila[],
};

export const COMO_FUNCIONA =
  '*Así funciona* 🌿\n\n' +
  '1. Eliges qué está pasando.\n' +
  '2. Me mandas la ubicación (el botón de WhatsApp o un enlace de Google Maps).\n' +
  '3. Si puedes, una foto tomada en el momento.\n' +
  '4. La CRA recibe tu reporte en su panel, lo verifica y decide cómo actuar.\n\n' +
  '🌱 *Jornadas:* toca *Jornadas* para ver las próximas siembras y limpiezas e inscribirte.\n\n' +
  '💡 *Proponer:* toca *Proponer* para sugerir una siembra, una limpieza u otra acción; la CRA la revisa.\n\n' +
  '⚠️ *Alertas:* escribe *alertas* para saber si viene mar de leva, aguaceros, vientos fuertes o riesgo de incendio en el manglar.\n\n' +
  '📶 *¿Sin señal?* Escríbeme igual: WhatsApp guarda tus mensajes y me llegan apenas vuelva la señal, con la hora en que los enviaste.\n\n' +
  '🔒 Nunca se publican tu nombre ni tu número. Los datos abiertos solo muestran el tipo, la zona aproximada y el estado.\n\n' +
  '⚠️ Si hay peligro para las personas, llama primero al *123*.';

export const CONSENTIMIENTO = {
  cuerpo:
    '🔒 *Antes de reportar*\n\n' +
    'Para atender tu reporte, la CRA guarda la ubicación, la foto y lo que me cuentes. ' +
    'Tus datos se tratan según la Ley 1581 de 2012 y *nunca se publican tu nombre ni tu número*.\n\n' +
    '¿Cómo quieres reportar?',
  pie: 'Con tu número, la CRA te puede contactar si hace falta',
  botones: [
    { id: 'acepto', titulo: '✅ Con mi número' },
    { id: 'anonimo', titulo: '👤 Anónimo' },
    { id: 'no_acepto', titulo: '❌ No acepto' },
  ] as Boton[],
};

export const SIN_CONSENTIMIENTO =
  'Entendido. Sin tu autorización no puedo guardar el reporte.\n\nSi cambias de opinión, escribe *menu*. Si hay peligro para las personas, llama al *123*.';

export const TIPO = {
  cuerpo: '¿Qué está pasando en el manglar?',
  boton: 'Elegir',
  filas: (Object.keys(TIPOS) as TipoId[]).map<Fila>(id => ({
    id,
    titulo: `${TIPOS[id].emoji} ${TIPOS[id].corto}`,
    descripcion: TIPOS[id].descripcion,
  })),
};

/** El primer mensaje ya describía la amenaza: se va directo a la ubicación. */
export function amenazaReconocida(tipo: TipoId): string {
  return (
    `🚨 Entendí: *${TIPOS[tipo].emoji} ${TIPOS[tipo].nombre}*. Vamos a reportarlo ya, con lo que me contaste como descripción.\n\n` +
    'Si no es eso, al final toca *✏️ Corregir*.'
  );
}

// Texto plano (no el mensaje interactivo de «Enviar ubicación»): ese no carga en WhatsApp Web.
export const PEDIR_UBICACION =
  '📍 *¿Dónde está pasando?*\n\n' +
  'Toca el clip 📎 → *Ubicación* y envía tu ubicación actual, o mueve el pin al sitio exacto.\n\n' +
  'También puedes pegar un enlace de Google Maps.';

export const UBICACION_NO_LEIDA =
  'No pude leer esa ubicación 🤔. Toca el clip 📎 → *Ubicación*, o pega un enlace de Google Maps.\n\n' +
  'O escribe *salir* para cancelar.';

export function ubicacionRecibida(dentro: boolean, distanciaM: number, zona?: string): string {
  const lugar = zona ? ` (${zona})` : '';
  if (dentro) return `✅ Ubicación recibida: está *dentro* del manglar${lugar}.`;
  return `✅ Ubicación recibida: está a ${distanciaM} m del manglar${lugar}. Lo que pasa cerca también lo afecta.`;
}

/** El punto queda a más de RADIO_INFLUENCIA_M de la cobertura de manglar de la C.R.A.: no se crea el reporte. */
export function fueraDelArea(radioM: number): string {
  return (
    '📍 Ese punto queda fuera del manglar; si afecta a uno cercano, comparte la ubicación del manglar afectado.\n\n' +
    `Zanky recibe denuncias dentro del manglar del Atlántico o a menos de ${radioM} m de él.`
  );
}

export const BOTONES_FUERA_DEL_AREA: Boton[] = [
  { id: 'otra_ubicacion', titulo: '📍 Cambiar ubicación' },
  { id: 'menu', titulo: '🏠 Volver al menú' },
];

export const PEDIR_FOTO =
  '📸 Envíame una *foto* de lo que está pasando, tomada ahora mismo.\n\n' +
  'Si no puedes acercarte, no te arriesgues: toca *Sin foto*.';

export const BOTON_SIN_FOTO: Boton[] = [{ id: 'sin_foto', titulo: 'Sin foto' }];

export const PEDIR_DESCRIPCION = '✍️ Cuéntame en pocas palabras qué viste: qué pasa, cuántas personas o máquinas, desde cuándo.';

export const BOTON_OMITIR: Boton[] = [{ id: 'omitir', titulo: 'Omitir' }];

export const PEDIR_CUANDO = '⏱️ ¿Cuándo está pasando?';

export const BOTONES_CUANDO: Boton[] = (Object.keys(MOMENTOS) as MomentoId[]).map(id => ({ id, titulo: MOMENTOS[id] }));

export const PEDIR_MAGNITUD =
  '📏 ¿Qué tan grande es lo que ves?\n\n' +
  (Object.keys(MAGNITUDES) as MagnitudId[]).map(id => `• *${MAGNITUDES[id].nombre}:* ${MAGNITUDES[id].ejemplo.toLowerCase()}`).join('\n');

export const BOTONES_MAGNITUD: Boton[] = (Object.keys(MAGNITUDES) as MagnitudId[]).map(id => ({ id, titulo: MAGNITUDES[id].nombre }));

export const FUERA_DEL_ATLANTICO =
  '📍 Esa ubicación queda fuera del Atlántico, y Zanky solo recibe reportes del manglar del departamento.\n\n' +
  'Si el sitio sí está en el Atlántico, vuelve a enviar la ubicación o un enlace de Google Maps.';

export interface Resumen {
  tipo: TipoId;
  zona?: string;
  dentro: boolean;
  distanciaM: number;
  conFoto: boolean;
  descripcion?: string;
  momento: MomentoId;
  magnitud: MagnitudId;
}

export function resumen(r: Resumen): string {
  const lugar = r.dentro ? `Dentro del manglar${r.zona ? ` (${r.zona})` : ''}` : `A ${r.distanciaM} m del manglar${r.zona ? ` (${r.zona})` : ''}`;
  return (
    '*Revisa tu reporte*\n\n' +
    `${TIPOS[r.tipo].emoji} ${TIPOS[r.tipo].nombre}\n` +
    `📍 ${lugar}\n` +
    `📸 ${r.conFoto ? 'Con foto' : 'Sin foto'}\n` +
    `✍️ ${r.descripcion ? r.descripcion.slice(0, 200) : 'Sin descripción'}\n` +
    `⏱️ ${MOMENTOS[r.momento]}\n` +
    `📏 ${MAGNITUDES[r.magnitud].nombre} (${MAGNITUDES[r.magnitud].ejemplo.toLowerCase()})\n\n` +
    '¿Lo envío a la CRA?'
  );
}

export const BOTONES_CONFIRMAR: Boton[] = [
  { id: 'enviar', titulo: '✅ Enviar' },
  { id: 'reiniciar', titulo: '✏️ Corregir' },
  { id: 'cancelar', titulo: '❌ Cancelar' },
];

/** Solo se usa cuando el backend común confirmó que guardó el reporte. */
export function enviado(codigo: string, enlace?: string, conAvisos = false): string {
  return (
    `🌿 ¡Gracias, vigía! Tu reporte *${codigo}* ya está en el panel de la CRA.\n\n` +
    `Estado: *${ESTADOS.recibido}*. La CRA lo verifica y decide cómo actuar. En unos minutos aparece en el mapa de la web, sin tus datos y con la ubicación aproximada.\n\n` +
    (conAvisos ? '🔔 Te escribo aquí cuando la CRA cambie el estado.\n' : '') +
    (enlace ? `🔎 Sigue tu caso: ${enlace}\n` : '') +
    `📋 Toca *Mis reportes* para ver el estado de *${codigo}* cuando quieras.`
  );
}

/** El servidor no respondió: el reporte queda en cola y todavía no tiene número de caso confirmado. */
export const ENVIO_PENDIENTE =
  '📶 Guardé tu reporte, pero el servidor de la CRA no respondió.\n\n' +
  'Lo reenvío solo en cuanto vuelva y te escribo con tu número de caso. No tienes que hacer nada más.';

/** Un reporte que estaba en cola por fin llegó al servidor. */
export function enviadoTarde(codigo: string): string {
  return `🌿 Listo: tu reporte *${codigo}* ya llegó al panel de la CRA. ¡Gracias por cuidar el manglar!`;
}

export const ENVIO_RECHAZADO =
  '⚠️ El servidor de la CRA no aceptó este reporte. Intenta de nuevo con *menu* → *🚨 Reportar*. Si hay peligro, llama al *123*.';

/** Versión de prueba sin backend: no se promete que esté en el panel. */
export function guardadoSinBackend(codigo: string): string {
  return (
    `🌿 ¡Gracias, vigía! Guardé tu reporte *${codigo}*.\n\n` +
    'Esta es una versión de prueba: todavía no está conectada al panel de la CRA.'
  );
}

/** Tocó un botón de un reporte que ya no está en curso (venció a los 30 minutos o ya se envió). */
export const REPORTE_VENCIDO =
  'Ese botón era de un reporte que ya no está en curso (se envió, se canceló o pasaron más de 30 minutos) 🙈.\n\n' +
  'Si quieres reportar algo, toca *🚨 Reportar* y empezamos de nuevo.';

export const CANCELADO ='Listo, cancelé el reporte. Escribe *menu* cuando quieras.';

export const DEMASIADOS = 'Has enviado varios reportes seguidos 🙏. Espera un rato antes de enviar otro. Si hay peligro, llama al *123*.';

export function misReportes(reportes: Reporte[]): string {
  if (!reportes.length) return 'Todavía no tienes reportes. Toca *🚨 Reportar* cuando veas algo raro en el manglar.';
  const ultimos = reportes.slice(-5).reverse();
  return (
    '*Tus últimos reportes* 📋\n\n' +
    ultimos
      .map(r => {
        const estado = r.envio?.estado === 'pendiente' ? 'Pendiente de envío' : r.envio?.estado === 'rechazado' ? 'No se pudo enviar' : ESTADOS[r.estado];
        return `• *${r.codigo}* · ${TIPOS[r.tipo].emoji} ${TIPOS[r.tipo].nombre}\n   ${estado} · ${r.capturado_en.slice(0, 10)}`;
      })
      .join('\n')
  );
}

export function cambioDeEstado(codigo: string, estado: keyof typeof ESTADOS, notaPublica?: string | null, enlace?: string): string {
  return (
    `🌿 Novedad de tu reporte *${codigo}*: ahora está *${ESTADOS[estado]}*.\n` +
    DESCRIPCION_ESTADO[estado] +
    (notaPublica ? `\n\n📝 La C.R.A. dice: ${notaPublica.slice(0, 500)}` : '') +
    (enlace ? `\n\n🔎 Sigue tu caso: ${enlace}` : '') +
    '\n\n¡Gracias por cuidar el manglar!'
  );
}

// --- Jornadas comunitarias ----------------------------------------------------

const TIPO_CORTO: Record<Jornada['tipo'], string> = { siembra: 'Siembra', limpieza: 'Limpieza', recorrido_vigias: 'Recorrido', monitoreo: 'Monitoreo' };

export const JORNADAS = {
  cuerpo: '🌱 *Jornadas comunitarias*\n\nEstas son las próximas siembras, limpiezas y recorridos para cuidar el manglar. Elige una para ver la invitación.',
  boton: 'Ver jornadas',
  filas: (js: Jornada[]): Fila[] =>
    js.slice(0, 10).map(j => ({
      id: `jor:${j.id}`,
      titulo: `${TIPOS_JORNADA[j.tipo].emoji} ${fmtJornada.corta(j.inicio)} · ${TIPO_CORTO[j.tipo]}`,
      // Cuánta gente va, en la misma línea, sin tener que abrir la invitación.
      descripcion: `${resumenInscritos(j)} · ${j.titulo}`.slice(0, 72),
    })),
};

export function sinJornadas(web: string): string {
  return `Por ahora no hay jornadas próximas publicadas 🌿.\n\nMira la cartelera aquí: ${web}`;
}

export function jornadasNoDisponibles(web: string): string {
  return `No pude consultar las jornadas en este momento 🙏. Puedes verlas en ${web}`;
}

export function invitacionJornada(j: Jornada, aviso: string): string {
  return (
    `${TIPOS_JORNADA[j.tipo].emoji} *${j.titulo}*\n\n` +
    `📅 ${fmtJornada.larga(j.inicio)}, de ${fmtJornada.hora(j.inicio)} a ${fmtJornada.hora(j.fin)}\n` +
    `📍 ${j.punto_encuentro}\n` +
    `🧭 Cómo llegar: ${enlaceComoLlegar(j)}\n` +
    `👥 ${j.inscritos > 0 ? `${j.inscritos} ${j.inscritos === 1 ? 'persona inscrita' : 'personas inscritas'}` : 'Sé de las primeras personas en inscribirte'} · gratis y sin límite de cupos\n` +
    (j.que_llevar.length ? `🎒 Qué llevar: ${j.que_llevar.join(', ')}\n` : '') +
    `\n✅ Inscríbete aquí: ${enlaceInvitacion(j)}\n` +
    'Desde ese enlace también la agregas a tu calendario y la compartes.\n' +
    `\n📱 El día de la jornada, interactúa conmigo: ${enlaceEventoZanky(j)}\n` +
    'Ahí registras tu llegada, haces el reto del manglar y reportas lo que veas.' +
    (aviso ? `\n\nℹ️ _${aviso}_` : '')
  );
}

export const BOTONES_DESPUES_DE_JORNADA: Boton[] = [
  { id: 'jornadas', titulo: '🌱 Otra jornada' },
  { id: 'menu', titulo: '🏠 Menú' },
];

/** Las jornadas no tienen límite de cupos: se dice cuánta gente va. */
export function resumenInscritos(j: Jornada): string {
  return j.inscritos > 0 ? `${j.inscritos} ${j.inscritos === 1 ? 'inscrito' : 'inscritos'}` : 'Gratis';
}

/** Después de la invitación: inscribirse aquí mismo (además del enlace de la web). */
export function botonesInvitacion(j: Jornada): Boton[] {
  return [
    { id: `ins:${j.id}`, titulo: '✅ Inscribirme' },
    { id: 'jornadas', titulo: '🌱 Otra jornada' },
    { id: 'menu', titulo: '🏠 Menú' },
  ];
}

export function confirmarInscripcion(j: Jornada, nombre: string): string {
  return (
    `✅ *Confirma tu asistencia*\n\n${TIPOS_JORNADA[j.tipo].emoji} ${j.titulo}\n📅 ${fmtJornada.larga(j.inicio)}, ${fmtJornada.hora(j.inicio)}\n` +
    `👤 A nombre de *${nombre}*\n\n` +
    '🔒 Tu nombre y tu número solo se usan para organizar esta jornada y avisarte de cambios (Ley 1581 de 2012).'
  );
}

export const BOTONES_CONFIRMAR_INSCRIPCION: Boton[] = [
  { id: 'ins_si', titulo: '✅ Confirmo' },
  { id: 'ins_nombre', titulo: '✏️ Otro nombre' },
  { id: 'cancelar', titulo: '❌ Cancelar' },
];

export const PEDIR_NOMBRE_INSCRIPCION = '¿A nombre de quién te inscribo? Escribe tu nombre y apellido 🙂';

export function inscrito(j: Jornada, enlace: string): string {
  return (
    `🎉 ¡Listo! Quedaste inscrito en *${j.titulo}*.\n\n📅 ${fmtJornada.larga(j.inicio)}, de ${fmtJornada.hora(j.inicio)} a ${fmtJornada.hora(j.fin)}\n📍 ${j.punto_encuentro}\n\n` +
    `${j.inscritos > 1 ? `Ya van ${j.inscritos} personas. ` : ''}Si al final no puedes ir, avísame escribiendo *no podré ir*.\n` +
    `Invitación, calendario y QR: ${enlace}`
  );
}

export function inscripcionCancelada(j: Jornada, liberados: number): string {
  return liberados
    ? `Listo, cancelé tu inscripción en *${j.titulo}* 🙏. Si cambias de idea, puedes volver a inscribirte.`
    : `No encontré una inscripción tuya en *${j.titulo}*.`;
}

export const NO_ENTENDI = 'No te entendí 🤔. Toca una de las opciones o escribe *menu* para empezar de nuevo.';

export const IA_NO_DISPONIBLE =
  'Uy, se me enredó la respuesta 🙈. Intenta de nuevo en un momento, o usa el menú: puedo recibir tu reporte o mostrarte las jornadas.';

// --- Comandos globales, consulta por código y entrada no reconocida ----------------------------------

/** Se escribió salir/cancelar/menú/hola con algo a medias. */
export function cancelado(que: 'reporte' | 'propuesta' | 'registro' | 'inscripcion'): string {
  const nombre = { reporte: 'Tu reporte en curso se canceló', propuesta: 'Tu propuesta en curso se canceló', registro: 'Tu registro de vigía se canceló', inscripcion: 'Tu inscripción en curso se canceló' }[que];
  return `${nombre}, no quedó guardado.`;
}

export function noEntendi(paso: string, pregunta: string): string {
  return `🤔 No te entendí. Estás en *${paso}*: ${pregunta}\n\nO escribe *salir* para cancelar.`;
}

export const BOTONES_NO_ENTENDI: Boton[] = [
  { id: 'ayuda_paso', titulo: '❓ Ayuda' },
  { id: 'salir', titulo: '🏠 Salir al menú' },
];

export function estadoDeCaso(r: Reporte): string {
  const envio = r.envio?.estado === 'pendiente' ? 'Pendiente de envío a la CRA' : r.envio?.estado === 'rechazado' ? 'No se pudo enviar' : `*${ESTADOS[r.estado]}*. ${DESCRIPCION_ESTADO[r.estado]}`;
  const fecha = new Intl.DateTimeFormat('es-CO', { timeZone: 'America/Bogota', day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(r.capturado_en));
  return `📋 *${r.codigo}* · ${TIPOS[r.tipo].emoji} ${TIPOS[r.tipo].nombre}\nEstado: ${envio}\nFecha: ${fecha}${r.zonaNombre ? ` · ${r.zonaNombre}` : ''}`;
}

export function casoNoEncontrado(codigo: string): string {
  return `🔎 No encontré un reporte con el código *${codigo}*. Revisa que esté bien escrito (por ejemplo *ZK-16D1*) o toca *📋 Mis reportes*.`;
}

// --- Reporte: lo que llega antes de tiempo y la corrección por campo -----------------------------------

export const FOTO_PRIMERO = '📸 ¡Recibí tu foto! Vamos a reportar lo que muestra.';
export const UBICACION_PRIMERO = '📍 Recibí la ubicación. Vamos a reportar lo que pasa ahí.';
export const DESCRIPCION_ANOTADA = '✍️ Anoté lo que me contaste.';

export const CORREGIR = {
  cuerpo: '✏️ ¿Qué quieres corregir? Lo demás se queda como está.',
  boton: 'Elegir',
  filas: [
    { id: 'c_tipo', titulo: '🚨 Qué pasa', descripcion: 'El tipo de amenaza' },
    { id: 'c_ubicacion', titulo: '📍 Ubicación' },
    { id: 'c_foto', titulo: '📸 Foto' },
    { id: 'c_descripcion', titulo: '✍️ Descripción' },
    { id: 'c_cuando', titulo: '⏱️ Cuándo' },
    { id: 'c_magnitud', titulo: '📏 Tamaño' },
    { id: 'c_todo', titulo: '🔄 Todo de nuevo' },
  ] as Fila[],
};

// --- Proponer -------------------------------------------------------------------------------------------

export const PROPUESTA_TIPO = {
  cuerpo: '💡 *Proponer una acción*\n\n¿Qué quieres proponer para el manglar? La CRA revisa cada propuesta.',
  boton: 'Elegir',
};

export const PROPUESTA_UBICACION =
  '📍 *¿Dónde sería?*\n\n' +
  'Toca el clip 📎 → *Ubicación* y envía el sitio (puedes mover el pin), o pega un enlace de Google Maps.\n\n' +
  'Tiene que ser en el manglar o a menos de 500 m de él.';

export const PROPUESTA_DESCRIPCION =
  '✍️ *Cuéntanos la propuesta*: qué harían, con cuántas personas, qué necesitan y para cuándo. (Al menos una frase.)';

export const PROPUESTA_DESCRIPCION_CORTA = 'Cuéntame un poco más, al menos una frase (10 letras o más) ✍️.';

export const PROPUESTA_QUIEN = { cuerpo: '👥 ¿Quién propone?', boton: 'Elegir' };

export const BOTONES_CONFIRMAR_PROPUESTA: Boton[] = [
  { id: 'p_enviar', titulo: '✅ Enviar' },
  { id: 'p_corregir', titulo: '✏️ Corregir' },
  { id: 'cancelar', titulo: '❌ Cancelar' },
];

export const CORREGIR_PROPUESTA = {
  cuerpo: '✏️ ¿Qué quieres corregir de la propuesta?',
  boton: 'Elegir',
  filas: [
    { id: 'pc_tipo', titulo: '💡 Qué propones' },
    { id: 'pc_ubicacion', titulo: '📍 Dónde' },
    { id: 'pc_descripcion', titulo: '✍️ Descripción' },
    { id: 'pc_quien', titulo: '👥 Quién propone' },
  ] as Fila[],
};

export function propuestaEnviada(codigo: string): string {
  return (
    `💡 ¡Gracias! Tu propuesta *${codigo}* quedó registrada.\n\n` +
    'La CRA la revisa en su panel y la ve el catálogo de soluciones de la plataforma. Guarda el código para preguntar por ella.'
  );
}

export const PROPUESTA_NO_GUARDADA =
  '⚠️ No pude guardar tu propuesta por un error del servidor. No quedó registrada: inténtalo de nuevo en unos minutos con *proponer*.';
