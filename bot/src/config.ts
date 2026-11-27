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
  graphVersion: env.GRAPH_API_VERSION ?? 'v25.0',
  /** Sin token no se envía nada a Meta: los mensajes salen por consola. */
  dryRun: token === '',
  panelApiKey: env.PANEL_API_KEY ?? '',
  hashSalt: env.HASH_SALT ?? 'zanky-dev-salt',
  dataDir: path.resolve(env.DATA_DIR ?? './data'),
  /** Zonas de manglar: el mismo archivo que usan la app y el backend (4 zonas con id y prioridad). */
  zonasGeojson: path.resolve(env.ZONAS_GEOJSON ?? '../app/assets/datos/manglar_zonas.json'),
  /** Área donde se admiten denuncias: la cobertura de manglar de la C.R.A. 1:5.000 (la misma regla que la web). */
  areaReporteGeojson: path.resolve(env.AREA_REPORTE_GEOJSON ?? '../datos/cra/manglar_cra_escala_1-5000.geojson'),
  /** Backend común (backend/supabase). Sin estos dos valores los reportes se quedan en la copia local. */
  supabaseUrl: (env.SUPABASE_URL ?? '').replace(/\/$/, ''),
  supabaseAnon: env.SUPABASE_ANON_KEY ?? '',
  /** Jornadas comunitarias publicadas por la web (siembras, limpiezas, recorridos). */
  jornadasUrl: env.JORNADAS_URL ?? 'https://mimanglar.sentralabs.co/datos/jornadas.json',
  /** Hasta esta distancia (m) de la cobertura C.R.A. se admite la denuncia; más lejos no se crea el reporte. */
  radioInfluenciaM: Number(env.RADIO_INFLUENCIA_M ?? 500),
  /** Cada cuánto se pregunta al backend si la C.R.A. cambió el estado de un reporte (para avisar por WhatsApp). */
  sondeoEstadosMs: Math.max(60_000, Number(env.SONDEO_ESTADOS_MS ?? 5 * 60_000)),
  /**
   * Página de la web para seguir un caso. Si se define, el bot manda <SEGUIMIENTO_URL>#caso=<uuid> al ciudadano:
   * la web lee el uuid del fragmento (no viaja al servidor) y consulta estado_de_reportes. Vacío: no se manda enlace.
   */
  seguimientoUrl: (env.SEGUIMIENTO_URL ?? '').trim(),
  /** OpenAI: Zanky conversa en la burbuja de la web (POST /chat) y responde preguntas libres en WhatsApp. */
  openaiKey: env.OPENAI_API_KEY ?? '',
  openaiModel: env.OPENAI_MODEL ?? 'gpt-4o-mini',
  openaiUrl: (env.OPENAI_BASE_URL ?? 'https://api.openai.com/v1').replace(/\/$/, ''),
  /** POST /chat (charla con IA desde la web). Apagado: la web lleva a WhatsApp. Se prende con CHAT_WEB=si. */
  chatWeb: env.CHAT_WEB === 'si',
  /** Sitios que pueden usar POST /chat desde el navegador. */
  chatOrigenes: (env.CHAT_ORIGENES ?? 'https://mimanglar.sentralabs.co,http://localhost:4329,http://localhost:4321')
    .split(',').map(o => o.trim()).filter(Boolean),
  /** Tope de preguntas a la IA: por IP cada 10 minutos y en total por hora (para que el costo no se dispare). */
  chatPorIp: Number(env.CHAT_POR_IP ?? 20),
  chatPorHora: Number(env.CHAT_POR_HORA ?? 400),
  /** Reportes por persona en una hora antes de frenar el envío. */
  maxReportesPorHora: 5,
  sesionTtlMs: 30 * 60 * 1000,
};

export function avisosDeConfiguracion(): string[] {
  const avisos: string[] = [];
  if (config.dryRun) avisos.push('WHATSAPP_TOKEN vacío: modo simulación, no se envía nada a WhatsApp.');
  if (!config.dryRun && !config.appSecret) avisos.push('META_APP_SECRET vacío: los webhooks se aceptan SIN verificar la firma.');
  if (!config.dryRun && !config.phoneNumberId) avisos.push('WHATSAPP_PHONE_NUMBER_ID vacío.');
  if (env.HASH_SALT === undefined) avisos.push('HASH_SALT vacío: se usa una sal de desarrollo.');
  if (!config.panelApiKey) avisos.push('PANEL_API_KEY vacío: la API del panel queda cerrada.');
  if (!config.supabaseUrl || !config.supabaseAnon) avisos.push('SUPABASE_URL o SUPABASE_ANON_KEY vacíos: los reportes NO llegan al backend común (app, web y panel).');
  if (!config.openaiKey) avisos.push('OPENAI_API_KEY vacío: Zanky no conversa (burbuja de la web ni preguntas libres en WhatsApp).');
  return avisos;
}
