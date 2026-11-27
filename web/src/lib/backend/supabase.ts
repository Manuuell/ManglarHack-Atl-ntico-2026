// Conexión de la web con el backend común (Supabase), solo con la clave pública: la misma puerta que la
// app y el bot de WhatsApp. El público puede leer la vista reportes_publicos (sin descripción, foto ni
// quién reporta; ubicación a 3 decimales y hora en punto), crear reportes con la RPC crear_reporte
// (el servidor valida el contrato y recalcula zona, prioridad y confianza), subir la foto del propio
// reporte y preguntar el estado por id. La URL y la clave van en web/.env (ignorado por git):
//   PUBLIC_SUPABASE_URL=https://<proyecto>.supabase.co
//   PUBLIC_SUPABASE_ANON_KEY=sb_publishable_…
// Sin ellas la web sigue en modo demostración (reportes en este navegador).
import type { Canal, EstadoReporte, Prioridad, TipoReporte } from '../../types/manglar';

const URL_BASE = String(import.meta.env.PUBLIC_SUPABASE_URL ?? '').replace(/\/+$/, '');
const CLAVE = String(import.meta.env.PUBLIC_SUPABASE_ANON_KEY ?? '');

/** true si la web está conectada al backend común. */
export const backendActivo = Boolean(URL_BASE && CLAVE);

export class ErrorBackend extends Error {
  constructor(mensaje: string, readonly status: number) { super(mensaje); }
  /** El servidor rechazó el reporte (no sirve reintentar con lo mismo). */
  get rechazado(): boolean { return this.status === 400 || this.status === 413 || this.status === 422; }
}

async function pedir(ruta: string, init: RequestInit = {}): Promise<Response> {
  let res: Response;
  try {
    res = await fetch(`${URL_BASE}${ruta}`, {
      ...init,
      headers: { apikey: CLAVE, Authorization: `Bearer ${CLAVE}`, ...(init.headers as Record<string, string> | undefined) },
      signal: AbortSignal.timeout(20_000),
    });
  } catch {
    throw new ErrorBackend('No hay conexión con el servidor. Revisa tu internet e inténtalo de nuevo.', 0);
  }
  if (!res.ok) {
    let mensaje = '';
    try { mensaje = String(((await res.json()) as { message?: string }).message ?? ''); } catch { /* sin cuerpo */ }
    // crear_reporte responde «motivo: explicación»; a la persona se le muestra la explicación.
    const explicacion = mensaje.includes(':') ? mensaje.slice(mensaje.indexOf(':') + 1).trim() : mensaje;
    if (res.status === 429) throw new ErrorBackend('Ya enviaste varios reportes en la última hora. Inténtalo un poco más tarde.', 429);
    throw new ErrorBackend(explicacion ? capital(explicacion) + '.' : `El servidor respondió ${res.status}. Inténtalo de nuevo.`, res.status);
  }
  return res;
}
const capital = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

/** Fila de la vista pública reportes_publicos. */
export interface FilaPublica {
  id_publico: string;
  tipo: TipoReporte;
  lat: number;
  lon: number;
  prioridad: Prioridad;
  estado: EstadoReporte;
  capturado_en: string;
  zona: string | null;
  municipio: string | null;
  canal: Canal;
}

/** Los reportes públicos, del más reciente al más antiguo (los descartados no salen). */
export async function leerReportesPublicos(): Promise<FilaPublica[]> {
  const campos = 'id_publico,tipo,lat,lon,prioridad,estado,capturado_en,zona,municipio,canal';
  const res = await pedir(`/rest/v1/reportes_publicos?select=${campos}&order=capturado_en.desc&limit=500`, { cache: 'no-store' });
  return (await res.json()) as FilaPublica[];
}

/** Lo que manda la web: las columnas del contrato común que lee crear_reporte. */
export interface ReporteNuevo {
  id: string;
  canal: 'web';
  tipo: TipoReporte;
  descripcion: string;
  lat: number;
  lon: number;
  precision_m: number | null;
  metodo_ubicacion: 'gps' | 'mapa';
  capturado_en: string;
  momento: 'ahora' | 'hoy' | 'antes';
  magnitud: 'pequena' | 'mediana' | 'grande';
  zona: string | null;
  municipio: string | null;
  dentro_poligono: boolean;
  distancia_m: number | null;
  confianza: number;
  foto_hash: string | null;
  foto_de_camara: boolean;
  foto_url: string | null;
  anonimo: boolean;
  reportante_id: string | null;
  sincronizado_tarde: boolean;
}

export interface ReporteCreado { id: string; nuevo: boolean; id_publico: string }

/** Crea el reporte. Es idempotente por id: reintentar el mismo envío no lo duplica. */
export async function crearReporte(p: ReporteNuevo): Promise<ReporteCreado> {
  const res = await pedir('/rest/v1/rpc/crear_reporte', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ p }),
  });
  return (await res.json()) as ReporteCreado;
}

/** Sube la foto al bucket privado como evidencias/<id>.jpg (solo la ve el panel, con auditoría). */
export async function subirFoto(id: string, jpeg: Blob): Promise<void> {
  try {
    await pedir(`/storage/v1/object/evidencias/${id}.jpg`, { method: 'POST', headers: { 'Content-Type': 'image/jpeg' }, body: jpeg });
  } catch (err) {
    // Un reintento del mismo reporte: la foto ya estaba arriba.
    if (err instanceof ErrorBackend && (err.status === 409 || /duplicate|already exists/i.test(err.message))) return;
    throw err;
  }
}

export interface EstadoDeReporte { id: string; estado: EstadoReporte; prioridad: Prioridad; confianza: number; id_publico: string }

/** Estado, prioridad y confianza que fijó el servidor para reportes propios (por su id interno). */
export async function estadoDeReportes(ids: string[]): Promise<EstadoDeReporte[]> {
  if (!ids.length) return [];
  const res = await pedir('/rest/v1/rpc/estado_de_reportes', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ ids: ids.slice(0, 100) }),
  });
  return (await res.json()) as EstadoDeReporte[];
}

/**
 * Identificador de este navegador para el límite anti-spam del servidor (10 reportes por hora).
 * Es un número al azar guardado aquí: no dice quién es la persona y no se publica.
 */
export function idDeEsteNavegador(): string | null {
  try {
    const clave = 'zanky-web:v1:navegador';
    let id = window.localStorage.getItem(clave);
    if (!id) { id = `web-${crypto.randomUUID()}`; window.localStorage.setItem(clave, id); }
    return id;
  } catch {
    return null;
  }
}

/** Convierte la foto a JPEG (máximo 1600 px de lado) y calcula su huella SHA-256. */
export async function prepararFoto(archivo: File): Promise<{ jpeg: Blob; hash: string }> {
  const imagen = await createImageBitmap(archivo);
  const escala = Math.min(1, 1600 / Math.max(imagen.width, imagen.height));
  const lienzo = document.createElement('canvas');
  lienzo.width = Math.round(imagen.width * escala);
  lienzo.height = Math.round(imagen.height * escala);
  lienzo.getContext('2d')!.drawImage(imagen, 0, 0, lienzo.width, lienzo.height);
  imagen.close();
  const jpeg = await new Promise<Blob>((ok, mal) => lienzo.toBlob((b) => (b ? ok(b) : mal(new Error('No se pudo preparar la foto.'))), 'image/jpeg', 0.82));
  const huella = await crypto.subtle.digest('SHA-256', await jpeg.arrayBuffer());
  const hash = [...new Uint8Array(huella)].map((b) => b.toString(16).padStart(2, '0')).join('');
  return { jpeg, hash };
}
