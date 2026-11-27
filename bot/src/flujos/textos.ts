import { Boton, Fila } from '../whatsapp/cloudApi';
import { CUANDO, ESTADOS, MUNICIPIOS, MunicipioId, ROLES, Reporte, RolId, TIPOS, TipoId } from '../reportes/modelo';

export const ENCABEZADO = 'Zanqui BOT 🌿';

// --- Registro de vigías -----------------------------------------------------

export const BIENVENIDA = {
  cuerpo:
    '¡Ajá! Soy *Zanqui* 🌿, el vigía del manglar del Atlántico.\n\n' +
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
    'Cuando veas algo raro en el manglar, escríbeme y toca *🚨 Reportar*.'
  );
}

export function saludoMenu(nombre?: string): string {
  return nombre ? `¡Ajá, *${nombre}*! ¿Qué quieres hacer?` : '¡Ajá! ¿Qué quieres hacer?';
}

export const MENU = {
  cuerpo:
    '¡Ajá! Soy *Zanqui*, el vigía del manglar del Atlántico.\n\n' +
    'Si ves algo que le hace daño al manglar (tala, quemas, basura, vertimientos o un caño tapado), ' +
    'cuéntamelo aquí y le llega a la CRA para que actúe a tiempo.',
  botones: [
    { id: 'reportar', titulo: '🚨 Reportar' },
    { id: 'mis_reportes', titulo: '📋 Mis reportes' },
    { id: 'como_funciona', titulo: 'ℹ️ Cómo funciona' },
  ] as Boton[],
};

export const COMO_FUNCIONA =
  '*Así funciona* 🌿\n\n' +
  '1. Eliges qué está pasando.\n' +
  '2. Me mandas la ubicación (el botón de WhatsApp o un enlace de Google Maps).\n' +
  '3. Si puedes, una foto tomada en el momento.\n' +
  '4. La CRA recibe tu reporte en su panel, lo verifica y decide cómo actuar.\n\n' +
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

export const BOTONES_CUANDO: Boton[] = (Object.keys(CUANDO) as (keyof typeof CUANDO)[]).map(id => ({ id, titulo: CUANDO[id] }));

export interface Resumen {
  tipo: TipoId;
  zona?: string;
  dentro: boolean;
  distanciaM: number;
  conFoto: boolean;
  descripcion?: string;
  cuando: keyof typeof CUANDO;
}

export function resumen(r: Resumen): string {
  const lugar = r.dentro ? `Dentro del manglar${r.zona ? ` (${r.zona})` : ''}` : `A ${r.distanciaM} m del manglar${r.zona ? ` (${r.zona})` : ''}`;
  return (
    '*Revisa tu reporte*\n\n' +
    `${TIPOS[r.tipo].emoji} ${TIPOS[r.tipo].nombre}\n` +
    `📍 ${lugar}\n` +
    `📸 ${r.conFoto ? 'Con foto' : 'Sin foto'}\n` +
    `✍️ ${r.descripcion ? r.descripcion.slice(0, 200) : 'Sin descripción'}\n` +
    `⏱️ ${CUANDO[r.cuando]}\n\n` +
    '¿Lo envío a la CRA?'
  );
}

export const BOTONES_CONFIRMAR: Boton[] = [
  { id: 'enviar', titulo: '✅ Enviar' },
  { id: 'reiniciar', titulo: '✏️ Corregir' },
  { id: 'cancelar', titulo: '❌ Cancelar' },
];

export function enviado(codigo: string): string {
  return (
    `🌿 ¡Gracias, vigía! Tu reporte *${codigo}* ya está en el panel de la CRA.\n\n` +
    `Estado: *${ESTADOS.recibido}*. La CRA lo va a verificar antes de actuar.\n\n` +
    'Escribe *menu* para volver al inicio.'
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
      .map(r => `• *${r.codigo}* · ${TIPOS[r.tipo].emoji} ${TIPOS[r.tipo].nombre}\n   ${ESTADOS[r.estado]} · ${r.recibido_en.slice(0, 10)}`)
      .join('\n')
  );
}

export function cambioDeEstado(codigo: string, estado: keyof typeof ESTADOS): string {
  return `🌿 Novedad de tu reporte *${codigo}*: ahora está *${ESTADOS[estado]}*. ¡Gracias por cuidar el manglar!`;
}

export const NO_ENTENDI = 'No te entendí 🤔. Toca una de las opciones o escribe *menu* para empezar de nuevo.';
