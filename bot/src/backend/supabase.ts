import { config } from '../config';
import { Estado } from '../reportes/modelo';

/**
 * Puente al backend común (backend/supabase). Usa la clave pública (anon), como la app: el público solo
 * puede crear reportes con la RPC crear_reporte (valida el contrato y recalcula zona, prioridad y
 * confianza en el servidor), subir la foto del propio reporte y consultar el estado por id.
 * La service_role no hace falta aquí.
 */

export function backendActivo(): boolean {
  return Boolean(config.supabaseUrl && config.supabaseAnon);
}

export class ErrorBackend extends Error {
  constructor(
    mensaje: string,
    readonly status: number,
    /** Si vale la pena reintentar más tarde (caída, límite, tiempo agotado) o el servidor lo rechazó. */
    readonly reintentable: boolean,
  ) {
    super(mensaje);
  }
}

function encabezados(extra: Record<string, string> = {}): Record<string, string> {
  return { apikey: config.supabaseAnon, Authorization: `Bearer ${config.supabaseAnon}`, ...extra };
}

async function pedir(ruta: string, init: RequestInit): Promise<Response> {
  let res: Response;
  try {
    res = await fetch(`${config.supabaseUrl}${ruta}`, { ...init, signal: AbortSignal.timeout(20_000) });
  } catch (err) {
    throw new ErrorBackend(`sin conexión con el backend: ${(err as Error).message}`, 0, true);
  }
  if (!res.ok) {
    const cuerpo = (await res.text()).slice(0, 300);
    throw new ErrorBackend(`backend ${res.status}: ${cuerpo}`, res.status, res.status >= 500 || res.status === 429 || res.status === 408);
  }
  return res;
}

/** Las 23 columnas del contrato que manda el cliente (las lee crear_reporte de schema.sql). */
export interface FilaReporte {
  id: string;
  canal: 'whatsapp';
  tipo: string;
  descripcion: string;
  lat: number;
  lon: number;
  precision_m: number | null;
  metodo_ubicacion: 'gps' | 'mapa' | 'enlace';
  capturado_en: string;
  momento: 'ahora' | 'hoy' | 'antes';
  magnitud: 'pequena' | 'mediana' | 'grande';
  zona: string | null;
  municipio: string | null;
  dentro_poligono: boolean;
  distancia_m: number | null;
  prioridad: number;
  confianza: number;
  foto_hash: string | null;
  foto_de_camara: boolean;
  foto_url: string | null;
  anonimo: boolean;
  reportante_id: string | null;
  sincronizado_tarde: boolean;
}

export interface ReporteCreado {
  id: string;
  /** false si ese id ya estaba (un reintento): el servidor no lo duplica ni lo cuenta otra vez. */
  nuevo: boolean;
  /** Id que sale en el mapa público y los datos abiertos; el id interno nunca se publica. */
  id_publico: string;
}

/**
 * Crea el reporte con la RPC crear_reporte, la única puerta de escritura del público. Es idempotente
 * por id. Si el servidor lo rechaza (400, «motivo: explicación») no se reintenta; un 429 (límite de
 * 10 por hora) o una caída sí.
 */
export async function crearReporte(fila: FilaReporte): Promise<ReporteCreado> {
  const res = await pedir('/rest/v1/rpc/crear_reporte', {
    method: 'POST',
    headers: encabezados({ 'Content-Type': 'application/json' }),
    body: JSON.stringify({ p: fila }),
  });
  return (await res.json()) as ReporteCreado;
}

/** Sube la foto al bucket privado como evidencias/<id>.jpg. Si ya estaba (reintento), se da por subida. */
export async function subirFoto(id: string, jpeg: Buffer): Promise<void> {
  try {
    await pedir(`/storage/v1/object/evidencias/${id}.jpg`, {
      method: 'POST',
      headers: encabezados({ 'Content-Type': 'image/jpeg' }),
      body: new Uint8Array(jpeg),
    });
  } catch (err) {
    if (err instanceof ErrorBackend && (err.status === 409 || (err.status === 400 && /duplicate|already exists/i.test(err.message)))) return;
    throw err;
  }
}

export interface EstadoServidor {
  id: string;
  estado: Estado;
  prioridad: number;
  confianza: number;
  nota_publica: string | null;
  actualizado_en: string;
  /** Solo en el esquema de main (vista con id_publico). */
  id_publico?: string;
}

/** Estado de varios reportes por su id (máximo 100), con la RPC pública estado_de_reportes. */
export async function estadoDeReportes(ids: string[]): Promise<EstadoServidor[]> {
  if (!ids.length) return [];
  const res = await pedir('/rest/v1/rpc/estado_de_reportes', {
    method: 'POST',
    headers: encabezados({ 'Content-Type': 'application/json' }),
    body: JSON.stringify({ ids: ids.slice(0, 100) }),
  });
  return (await res.json()) as EstadoServidor[];
}
