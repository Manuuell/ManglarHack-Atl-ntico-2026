import 'dotenv/config';
import path from 'path';

const env = process.env;

const token = env.WHATSAPP_TOKEN ?? '';

export const config = {
  port: Number(env.PORT ?? 3000),
  token,
  phoneNumberId: env.WHATSAPP_PHONE_NUMBER_ID ?? '',
  verifyToken: env.WHATSAPP_VERIFY_TOKEN ?? '',
  appSecret: env.META_APP_SECRET ?? '',
  /** Secreto a probar sin exigirlo: se anota si la firma coincide, pero no se rechaza nada. */
  appSecretPrueba: env.META_APP_SECRET_PRUEBA ?? '',
  graphVersion: env.GRAPH_API_VERSION ?? 'v25.0',
  /** Sin token no se envía nada a Meta: los mensajes salen por consola. */
  dryRun: token === '',
  panelApiKey: env.PANEL_API_KEY ?? '',
  hashSalt: env.HASH_SALT ?? 'zanky-dev-salt',
  dataDir: path.resolve(env.DATA_DIR ?? './data'),
  /** Zonas de manglar: el mismo archivo que usan la app y el backend (4 zonas con id y prioridad). */
  zonasGeojson: path.resolve(env.ZONAS_GEOJSON ?? '../app/assets/datos/manglar_zonas.json'),
  /** Backend común (backend/supabase). Sin estos dos valores los reportes se quedan en la copia local. */
  supabaseUrl: (env.SUPABASE_URL ?? '').replace(/\/$/, ''),
  supabaseAnon: env.SUPABASE_ANON_KEY ?? '',
  /** Jornadas comunitarias publicadas por la web (siembras, limpiezas, recorridos). */
  jornadasUrl: env.JORNADAS_URL ?? 'https://mimanglar.sentralabs.co/datos/jornadas.json',
  radioInfluenciaM: Number(env.RADIO_INFLUENCIA_M ?? 500),
  /** OpenAI: Zanky conversa en la burbuja de la web (POST /chat) y responde preguntas libres en WhatsApp. */
  openaiKey: env.OPENAI_API_KEY ?? '',
  openaiModel: env.OPENAI_MODEL ?? 'gpt-4o-mini',
  /** Notas de voz: se transcriben con este modelo y siguen la conversación como texto. TRANSCRIBIR_AUDIOS=no las apaga. */
  openaiTranscribeModel: env.OPENAI_TRANSCRIBE_MODEL ?? 'gpt-4o-mini-transcribe',
  transcribirAudios: env.TRANSCRIBIR_AUDIOS !== 'no',
  /** Tope de audios por persona en una hora (cuidan el costo de la transcripción). */
  audiosPorHora: Number(env.AUDIOS_POR_HORA ?? 20),
  openaiUrl: (env.OPENAI_BASE_URL ?? 'https://api.openai.com/v1').replace(/\/$/, ''),
  /** POST /chat (charla con IA desde la web). Apagado: la web lleva a WhatsApp. Se prende con CHAT_WEB=si. */
  chatWeb: env.CHAT_WEB === 'si',
  /** Sitios que pueden usar POST /chat desde el navegador. */
  chatOrigenes: (env.CHAT_ORIGENES ?? 'https://mimanglar.sentralabs.co,http://localhost:4329,http://localhost:4321')
    .split(',').map(o => o.trim()).filter(Boolean),
  /** Tope de preguntas a la IA: por IP cada 10 minutos y en total por hora (para que el costo no se dispare). */
  chatPorIp: Number(env.CHAT_POR_IP ?? 20),
  chatPorHora: Number(env.CHAT_POR_HORA ?? 400),
  /** Web de Zanky (enlaces de invitación y CORS de la API /api). */
  webUrl: (env.WEB_URL ?? 'https://mimanglar.sentralabs.co').replace(/\/$/, ''),
  /**
   * Panel admin: cuentas de la web (Supabase Auth) con rol admin o moderador_cra en panel_roles, o con su correo
   * en esta lista (separados por coma). Los scripts del servidor pueden usar además x-api-key = PANEL_API_KEY.
   */
  adminCorreos: (env.ADMIN_CORREOS ?? '').split(',').map(c => c.trim().toLowerCase()).filter(Boolean),
  /** Plantilla aprobada de WhatsApp para invitar a una jornada: imagen, 4 variables, botón de URL y «No podré ir». */
  plantillaInvitacion: env.PLANTILLA_INVITACION ?? 'nodo_recordatorio_evento',
  plantillaIdioma: env.PLANTILLA_IDIOMA ?? 'es',
  /** El botón de URL de la plantilla termina en este sufijo + id de la jornada; nginx lo redirige a la web. */
  prefijoBotonEvento: env.PREFIJO_BOTON_EVENTO ?? 'zanky-',
  /** Imagen del encabezado de la invitación cuando la jornada no trae la suya (JPG o PNG público, menos de 5 MB). */
  imagenInvitacion: env.IMAGEN_INVITACION ?? 'https://zanqui.sentralabs.co/invitaciones/jornada-limpieza-manglar.jpg',
  /** Más allá de esta distancia se pregunta si la ubicación es correcta. */
  distanciaSospechosaM: 3000,
  /** Reportes por persona en una hora antes de frenar el envío. */
  maxReportesPorHora: 5,
  sesionTtlMs: 30 * 60 * 1000,
};

export function avisosDeConfiguracion(): string[] {
  const avisos: string[] = [];
  if (config.dryRun) avisos.push('WHATSAPP_TOKEN vacío: modo simulación, no se envía nada a WhatsApp.');
  if (!config.dryRun && !config.appSecret) avisos.push(config.appSecretPrueba
    ? 'Firma de Meta en MODO PRUEBA (META_APP_SECRET_PRUEBA): se anota si coincide, pero no se rechaza nada.'
    : 'META_APP_SECRET vacío: los webhooks se aceptan SIN verificar la firma.');
  if (!config.dryRun && !config.phoneNumberId) avisos.push('WHATSAPP_PHONE_NUMBER_ID vacío.');
  if (env.HASH_SALT === undefined) avisos.push('HASH_SALT vacío: se usa una sal de desarrollo.');
  if (!config.panelApiKey) avisos.push('PANEL_API_KEY vacío: la API del panel queda cerrada.');
  if (!config.supabaseUrl || !config.supabaseAnon) avisos.push('SUPABASE_URL o SUPABASE_ANON_KEY vacíos: los reportes NO llegan al backend común (app, web y panel).');
  if (!config.openaiKey) avisos.push('OPENAI_API_KEY vacío: Zanky no conversa (burbuja de la web ni preguntas libres en WhatsApp).');
  return avisos;
}
