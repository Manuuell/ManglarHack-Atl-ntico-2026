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
  hashSalt: env.HASH_SALT ?? 'zanqui-dev-salt',
  dataDir: path.resolve(env.DATA_DIR ?? './data'),
  zonasGeojson: path.resolve(env.ZONAS_GEOJSON ?? '../datos/manglares_atlantico_invemar_2020.geojson'),
  radioInfluenciaM: Number(env.RADIO_INFLUENCIA_M ?? 500),
  /** Más allá de esta distancia se pregunta si la ubicación es correcta. */
  distanciaSospechosaM: 3000,
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
  return avisos;
}
