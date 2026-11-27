// Jornadas en el servidor de Zanky: la lista y las inscripciones viven allí (como en una plataforma de
// eventos), y todos los componentes que usan useJornadas las reciben al día. Si el servidor no responde,
// se queda lo que hay en el almacén local (datos de ejemplo y lo guardado en este navegador) y se avisa.
import { useEffect, useSyncExternalStore } from 'react';
import type { Inscripcion, Jornada, TipoJornada } from '../../types/plataforma';
import { ErrorBot, pedirBot } from '../bot';
import { renovarSesion } from '../cuenta';
export { normalizarCelular } from '../cuenta';
import { inscribirseEnJornada, inscripciones, jornadas, type Resultado } from './estado';

export type OrigenJornadas = 'cargando' | 'servidor' | 'respaldo';
interface EstadoSync { origen: OrigenJornadas; aviso: string }

const TIPOS: TipoJornada[] = ['siembra', 'limpieza', 'recorrido_vigias', 'monitoreo'];
const INICIAL: EstadoSync = { origen: 'cargando', aviso: '' };
let estado: EstadoSync = INICIAL;
const oyentes = new Set<() => void>();
let carga: Promise<void> | null = null;
let reloj: number | null = null;

const objeto = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null;
const num = (v: unknown) => typeof v === 'number' && Number.isFinite(v);

/** Normaliza una jornada de la API; descarta la que venga incompleta. */
function aJornada(v: unknown): Jornada | null {
  if (!objeto(v)) return null;
  const { id, titulo, tipo, inicio, fin, punto_encuentro, lat, lon, cupos, inscritos } = v;
  if (typeof id !== 'string' || typeof titulo !== 'string' || typeof tipo !== 'string' || !TIPOS.includes(tipo as TipoJornada)
    || typeof inicio !== 'string' || typeof fin !== 'string' || typeof punto_encuentro !== 'string'
    || !num(lat) || !num(lon) || !num(cupos) || !num(inscritos)) return null;
  if (v.estado === 'cancelada') return null;
  return {
    id, titulo, tipo: tipo as TipoJornada, inicio, fin, punto_encuentro,
    lat: lat as number, lon: lon as number, cupos: cupos as number, inscritos: inscritos as number,
    accion_id: typeof v.accion_id === 'string' ? v.accion_id : '',
    que_llevar: Array.isArray(v.que_llevar) ? v.que_llevar.filter((x): x is string => typeof x === 'string') : [],
    descripcion: typeof v.descripcion === 'string' ? v.descripcion : '',
    imagen_url: typeof v.imagen_url === 'string' && /^https:\/\//.test(v.imagen_url) ? v.imagen_url : null,
    ejemplo: v.ejemplo === true,
  };
}

function cambiar(nuevo: EstadoSync) {
  estado = nuevo;
  oyentes.forEach((o) => o());
}

/** Trae las jornadas del servidor y las pone en el almacén que leen todas las islas. */
export function sincronizarJornadas(forzar = false): Promise<void> {
  if (typeof window === 'undefined') return Promise.resolve();
  if (carga && !forzar) return carga;
  carga = (async () => {
    try {
      const r = await pedirBot<{ aviso?: unknown; jornadas?: unknown }>('/api/jornadas');
      if (!Array.isArray(r?.jornadas)) throw new ErrorBot('Respuesta sin jornadas.', 200);
      const lista = r.jornadas.map(aJornada).filter((j): j is Jornada => j !== null);
      try { jornadas.obtener(); } catch { jornadas.inicializar(lista); }
      jornadas.establecer(() => lista);
      cambiar({ origen: 'servidor', aviso: typeof r.aviso === 'string' ? r.aviso : '' });
    } catch {
      // Si ya había datos del servidor, un fallo pasajero no cambia el aviso.
      if (estado.origen !== 'servidor') cambiar({ origen: 'respaldo', aviso: '' });
    }
  })();
  return carga;
}

/** De dónde salen las jornadas que se ven (servidor o respaldo local) y el aviso del servidor. */
export function useOrigenJornadas(): EstadoSync {
  return useSyncExternalStore((o) => { oyentes.add(o); return () => { oyentes.delete(o); }; }, () => estado, () => INICIAL);
}

/** Lo llama useJornadas: una sola descarga por página y una revisión cada minuto. */
export function useSincronizarJornadas(): void {
  useEffect(() => {
    void sincronizarJornadas();
    if (reloj === null) reloj = window.setInterval(() => { void sincronizarJornadas(true); }, 60_000);
  }, []);
}

export interface DatosInscripcion { nombre: string; telefono: string | null; acepta_whatsapp: boolean }

/**
 * Inscribe en el servidor (ligado a la cuenta si hay sesión). Si el servidor no está disponible, la
 * inscripción queda solo en este navegador y `enServidor` es false.
 */
export async function inscribirseEnServidor(j: Jornada, d: DatosInscripcion): Promise<Resultado<{ enServidor: boolean }>> {
  const nombre = d.nombre.trim();
  if (nombre.length < 3) return { ok: false, errores: { nombre: 'Escribe un nombre de al menos 3 caracteres.' } };
  inscripciones.inicializar([]);
  if (inscripciones.obtener().some((i) => i.jornada_id === j.id)) return { ok: false, errores: { jornada_id: 'Ya estás inscrito en esta jornada desde este navegador. ¡Te esperamos!' } };
  const local = () => {
    const r = inscribirseEnJornada(j.id, nombre);
    return r.ok ? { ok: true as const, enServidor: false } : r;
  };
  if (estado.origen !== 'servidor') return local();
  try {
    const sesion = await renovarSesion().catch(() => null);
    const r = await pedirBot<{ ok: boolean; inscritos: number; id: string }>(`/api/jornadas/${encodeURIComponent(j.id)}/inscripciones`, {
      metodo: 'POST', token: sesion?.access_token,
      cuerpo: { nombre, ...(d.telefono ? { telefono: d.telefono } : {}), acepta_datos: true, acepta_whatsapp: Boolean(d.telefono && d.acepta_whatsapp) },
    });
    const inscripcion: Inscripcion = { id: String(r?.id ?? crypto.randomUUID()), jornada_id: j.id, nombre, fecha: new Date().toISOString() };
    inscripciones.establecer((previo) => [...previo, inscripcion]);
    if (num(r?.inscritos)) jornadas.establecer((previo) => previo.map((x) => (x.id === j.id ? { ...x, inscritos: r.inscritos } : x)));
    return { ok: true, enServidor: true };
  } catch (e) {
    if (e instanceof ErrorBot && e.sinConexion) return local();
    return { ok: false, errores: { servidor: e instanceof Error ? e.message : 'No se pudo inscribir. Inténtalo de nuevo.' } };
  }
}
