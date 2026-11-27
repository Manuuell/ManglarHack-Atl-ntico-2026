import { config } from '../config';
import { whatsapp } from '../whatsapp/cloudApi';
import { hashDe } from '../reportes/almacen';

/**
 * Notas de voz de WhatsApp → texto, con la transcripción de OpenAI (por defecto gpt-4o-mini-transcribe).
 * El audio vive solo en memoria: no se guarda en disco y los registros nunca llevan lo que dijo la persona,
 * solo el motivo cuando algo falla. A la persona se le confirma lo que se entendió («🎧 Te entendí: …»).
 */
const MAX_AUDIO_BYTES = 8 * 1024 * 1024;
const MAX_TRANSCRIPCION = 1000;
/** Hosts a los que se puede mandar el token de Meta para bajar el archivo. */
const HOSTS_MEDIA = ['fbsbx.com', 'facebook.com', 'whatsapp.net'];
const EXTENSIONES: Record<string, string> = {
  'audio/ogg': 'ogg', 'audio/opus': 'ogg', 'audio/mpeg': 'mp3', 'audio/mp3': 'mp3', 'audio/mp4': 'm4a',
  'audio/m4a': 'm4a', 'audio/x-m4a': 'm4a', 'audio/aac': 'm4a', 'audio/amr': 'amr', 'audio/wav': 'wav',
  'audio/x-wav': 'wav', 'audio/webm': 'webm', 'audio/flac': 'flac',
};
/** Vocabulario del manglar para que la transcripción acierte nombres y términos de la zona. */
const CONTEXTO = 'Reporte ciudadano sobre el manglar del Atlántico, Colombia: Ciénaga de Mallorquín, Ciénaga del Totumo, '
  + 'Balboa, Manatíes, Puerto Colombia, Tubará, Juan de Acosta, Bocas de Ceniza, caño, mangle rojo, tala, quema, '
  + 'relleno, vertimiento, basura, escombros, C.R.A., Zanky, jornada, vigía.';

type Motivo = 'apagado' | 'limite' | 'muy_grande' | 'formato' | 'descarga' | 'transcripcion' | 'vacio';
class ErrorAudio extends Error {
  constructor(readonly motivo: Motivo) { super(`audio: ${motivo}`); }
}

const extension = (mime: string | undefined) => EXTENSIONES[String(mime ?? '').split(';')[0].trim().toLowerCase()] ?? null;
const limpiar = (t: unknown) => {
  const s = String(t ?? '').replace(/\s+/g, ' ').trim();
  return s.length > MAX_TRANSCRIPCION ? `${s.slice(0, MAX_TRANSCRIPCION - 1).trimEnd()}…` : s;
};
function hostPermitido(url: string): boolean {
  try {
    const u = new URL(url);
    return u.protocol === 'https:' && HOSTS_MEDIA.some(h => u.hostname === h || u.hostname.endsWith(`.${h}`));
  } catch {
    return false;
  }
}

async function descargar(mediaId: string): Promise<{ datos: Buffer; mime: string }> {
  const auth = { Authorization: `Bearer ${config.token}` };
  const meta = await fetch(`https://graph.facebook.com/${config.graphVersion}/${encodeURIComponent(mediaId)}`, { headers: auth, signal: AbortSignal.timeout(15_000) }).catch(() => null);
  if (!meta?.ok) throw new ErrorAudio('descarga');
  const info = (await meta.json()) as { url?: string; mime_type?: string; file_size?: number };
  if (!info.url || !hostPermitido(info.url)) throw new ErrorAudio('descarga');
  if ((info.file_size ?? 0) > MAX_AUDIO_BYTES) throw new ErrorAudio('muy_grande');
  if (!extension(info.mime_type)) throw new ErrorAudio('formato');
  const archivo = await fetch(info.url, { headers: auth, signal: AbortSignal.timeout(30_000) }).catch(() => null);
  if (!archivo?.ok) throw new ErrorAudio('descarga');
  const datos = Buffer.from(await archivo.arrayBuffer());
  if (datos.length > MAX_AUDIO_BYTES) throw new ErrorAudio('muy_grande');
  return { datos, mime: String(info.mime_type) };
}

async function transcribir(datos: Buffer, mime: string): Promise<string> {
  const form = new FormData();
  form.append('file', new Blob([new Uint8Array(datos)], { type: mime.split(';')[0] }), `nota-de-voz.${extension(mime) ?? 'ogg'}`);
  form.append('model', config.openaiTranscribeModel);
  form.append('language', 'es');
  form.append('prompt', CONTEXTO);
  const res = await fetch(`${config.openaiUrl}/audio/transcriptions`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${config.openaiKey}` },
    body: form,
    signal: AbortSignal.timeout(60_000),
  }).catch(() => null);
  if (!res?.ok) {
    if (res) console.warn(`[audio] OpenAI respondió ${res.status}`);
    throw new ErrorAudio('transcripcion');
  }
  const texto = limpiar(((await res.json().catch(() => ({}))) as { text?: string }).text);
  if (!texto) throw new ErrorAudio('vacio');
  return texto;
}

const usos = new Map<string, number[]>();
function dentroDelTope(de: string): boolean {
  const ahora = Date.now();
  const propios = (usos.get(de) ?? []).filter(t => ahora - t < 3600_000);
  if (propios.length >= config.audiosPorHora) return false;
  propios.push(ahora);
  usos.set(de, propios);
  return true;
}

function mensajeFallido(motivo: Motivo): string {
  if (motivo === 'limite') return 'Me mandaste muchos audios seguidos 😅. Por ahora escríbeme, ¿sí?';
  if (motivo === 'muy_grande') return 'Tu audio es muy largo para mí 🙏. ¿Me lo mandas más corto o por escrito?';
  if (motivo === 'formato') return 'No pude abrir ese audio 🙏. ¿Me lo escribes o me mandas una nota de voz?';
  if (motivo === 'apagado') return 'Por ahora solo puedo leer mensajes escritos 🙏. ¿Me lo escribes?';
  return 'No pude escuchar bien tu audio 🙏. ¿Me lo escribes o lo intentas otra vez?';
}

/**
 * Transcribe la nota de voz y le confirma a la persona lo que entendió. Devuelve el texto para seguir el flujo,
 * o null si no se pudo (y en ese caso ya se le respondió).
 * En simulación (sin token de WhatsApp), un mediaId «sim-audio:texto» se toma como ya transcrito.
 */
export async function escucharAudio(de: string, mediaId: string, mime?: string): Promise<string | null> {
  const quien = hashDe(de).slice(0, 8);
  try {
    let texto: string;
    if (config.dryRun && mediaId.startsWith('sim-audio:')) {
      texto = limpiar(mediaId.slice('sim-audio:'.length));
    } else {
      if (!config.transcribirAudios || !config.openaiKey || config.dryRun) throw new ErrorAudio('apagado');
      if (!dentroDelTope(de)) throw new ErrorAudio('limite');
      const audio = await descargar(mediaId);
      texto = await transcribir(audio.datos, audio.mime || mime || 'audio/ogg');
    }
    const corto = texto.length > 180 ? `${texto.slice(0, 179).trimEnd()}…` : texto;
    await whatsapp.texto(de, `🎧 Te entendí: «${corto}»`);
    console.log(`[audio] ${quien} transcrito (${texto.length} caracteres)`);
    return texto;
  } catch (err) {
    const motivo: Motivo = err instanceof ErrorAudio ? err.motivo : 'transcripcion';
    console.warn(`[audio] ${quien} sin transcribir: ${motivo}`);
    await whatsapp.texto(de, mensajeFallido(motivo)).catch(() => undefined);
    return null;
  }
}
