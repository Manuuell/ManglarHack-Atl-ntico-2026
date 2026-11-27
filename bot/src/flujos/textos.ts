import { Boton, Fila } from '../whatsapp/cloudApi';
import { Jornada, TIPOS_JORNADA, enlaceComoLlegar, enlaceEventoZanky, enlaceInvitacion, fmt as fmtJornada } from '../jornadas/jornadas';
import { ESTADOS, MAGNITUDES, MOMENTOS, MUNICIPIOS, MagnitudId, MomentoId, MunicipioId, ROLES, Reporte, RolId, TIPOS, TipoId } from '../reportes/modelo';

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

export const PEDIR_NOMBRE = '¿Cómo te llamas? Escríbeme tu nombre 🙂';

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
};

export const COMO_FUNCIONA =
  '*Así funciona* 🌿\n\n' +
  '1. Eliges qué está pasando.\n' +
  '2. Me mandas la ubicación (el botón de WhatsApp o un enlace de Google Maps).\n' +
  '3. Si puedes, una foto tomada en el momento.\n' +
  '4. La CRA recibe tu reporte en su panel, lo verifica y decide cómo actuar.\n\n' +
  '🌱 *Jornadas:* toca *Jornadas* para ver las próximas siembras y limpiezas e inscribirte.\n\n' +
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

const TITULO_CORTO: Partial<Record<TipoId, string>> = { relleno: 'Relleno/construcción' };

export const TIPO = {
  cuerpo: '¿Qué está pasando en el manglar?',
  boton: 'Elegir',
  filas: (Object.keys(TIPOS) as TipoId[]).map<Fila>(id => ({
    id,
    titulo: `${TIPOS[id].emoji} ${TITULO_CORTO[id] ?? TIPOS[id].nombre}`,
    descripcion: TIPOS[id].descripcion,
  })),
};

export const PEDIR_UBICACION =
  '📍 *¿Dónde está pasando?*\n\n' +
  'Toca *Enviar ubicación* y elige tu ubicación actual, o mueve el pin al sitio exacto.\n\n' +
  'También puedes pegar un enlace de Google Maps.';

export const UBICACION_NO_LEIDA =
  'No pude leer esa ubicación 🤔. Usa el botón *Enviar ubicación* o pega un enlace de Google Maps.';

export function ubicacionRecibida(dentro: boolean, distanciaM: number, zona?: string): string {
  const lugar = zona ? ` (${zona})` : '';
  if (dentro) return `✅ Ubicación recibida: está *dentro* del manglar${lugar}.`;
  return `✅ Ubicación recibida: está a ${distanciaM} m del manglar${lugar}. Lo que pasa cerca también lo afecta.`;
}

export function ubicacionLejana(distanciaM: number): string {
  return `🤔 Esa ubicación está a ${(distanciaM / 1000).toFixed(1)} km del manglar más cercano. ¿Seguro que es ahí?`;
}

export const BOTONES_LEJOS: Boton[] = [
  { id: 'seguir', titulo: 'Sí, es ahí' },
  { id: 'otra_ubicacion', titulo: '📍 Cambiarla' },
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
export function enviado(codigo: string): string {
  return (
    `🌿 ¡Gracias, vigía! Tu reporte *${codigo}* ya está en el panel de la CRA.\n\n` +
    `Estado: *${ESTADOS.recibido}*. La CRA lo verifica y decide cómo actuar. También aparece en el mapa de la app y de la web, sin tus datos.\n\n` +
    'Escribe *menu* para volver al inicio.'
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

export const CANCELADO = 'Listo, cancelé el reporte. Escribe *menu* cuando quieras.';

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

export function cambioDeEstado(codigo: string, estado: keyof typeof ESTADOS): string {
  return `🌿 Novedad de tu reporte *${codigo}*: ahora está *${ESTADOS[estado]}*. ¡Gracias por cuidar el manglar!`;
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
      descripcion: j.titulo,
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

export const NO_ENTENDI = 'No te entendí 🤔. Toca una de las opciones o escribe *menu* para empezar de nuevo.';

export const IA_NO_DISPONIBLE =
  'Uy, se me enredó la respuesta 🙈. Intenta de nuevo en un momento, o usa el menú: puedo recibir tu reporte o mostrarte las jornadas.';
