import { useEffect } from 'react';
import type { Accion, SectorId, TipoAccion, TipoActor } from '../../types/plataforma';
import { pedirBot } from '../bot';
import { acciones } from './estado';

export interface PropuestaBot {
  id: string; codigo: string; canal: 'whatsapp';
  tipo: 'siembra' | 'restauracion' | 'limpieza' | 'monitoreo' | 'emprendimiento' | 'educacion' | 'otra';
  tipo_accion: TipoAccion; proponente: string;
  tipo_actor: Extract<TipoActor, 'comunidad' | 'academia' | 'empresa' | 'ciudadano' | 'entidad_publica'>;
  descripcion: string; lat: number; lon: number; zona: SectorId | null;
  zona_nombre: string | null; dentro_poligono: boolean; distancia_m: number | null;
  estado: 'propuesta'; creada_en: string;
}

const sectores: SectorId[] = ['mallorquin', 'balboa', 'manaties', 'totumo'];
const tipos: TipoAccion[] = ['siembra', 'restauracion_hidrologica', 'conservacion_vigilancia', 'sbn'];
const actores: PropuestaBot['tipo_actor'][] = ['comunidad', 'academia', 'empresa', 'ciudadano', 'entidad_publica'];
const nombres: Record<PropuestaBot['tipo'], string> = {
  siembra: 'Siembra', restauracion: 'Restauración', limpieza: 'Limpieza', monitoreo: 'Monitoreo',
  emprendimiento: 'Emprendimiento', educacion: 'Educación', otra: 'Acción',
};
const objeto = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null;

function leerPropuesta(v: unknown): PropuestaBot | null {
  if (!objeto(v) || typeof v.id !== 'string' || !v.id || typeof v.codigo !== 'string'
    || !/^PROP-[A-Z0-9]+$/i.test(v.codigo) || v.canal !== 'whatsapp'
    || typeof v.tipo !== 'string' || !Object.hasOwn(nombres, v.tipo)
    || typeof v.tipo_accion !== 'string' || !tipos.includes(v.tipo_accion as TipoAccion)
    || typeof v.tipo_actor !== 'string' || !actores.includes(v.tipo_actor as PropuestaBot['tipo_actor'])
    || typeof v.proponente !== 'string' || typeof v.descripcion !== 'string'
    || typeof v.lat !== 'number' || !Number.isFinite(v.lat) || Math.abs(v.lat) > 90
    || typeof v.lon !== 'number' || !Number.isFinite(v.lon) || Math.abs(v.lon) > 180
    || v.estado !== 'propuesta' || typeof v.creada_en !== 'string' || !Number.isFinite(Date.parse(v.creada_en))) return null;
  // El bot usa sus propias zonas (tubara, piojo, juan_de_acosta…): si no es un sector de la web, queda sin sector,
  // pero la propuesta no se pierde.
  const zona = typeof v.zona === 'string' && sectores.includes(v.zona as SectorId) ? (v.zona as SectorId) : null;
  return { ...(v as unknown as PropuestaBot), zona };
}

const PROPONENTES: Record<string, string> = {
  comunidad: 'Comunidad', universidad: 'Universidad o colegio', empresa: 'Empresa', persona: 'Persona', cra: 'C.R.A.',
};

/** La falta de conexión deja visibles las acciones que ya están en la página. */
export async function cargarPropuestasBot(): Promise<PropuestaBot[]> {
  try {
    const respuesta = await pedirBot<{ propuestas?: unknown }>('/api/propuestas');
    return Array.isArray(respuesta?.propuestas)
      ? respuesta.propuestas.map(leerPropuesta).filter((p): p is PropuestaBot => p !== null)
      : [];
  } catch { return []; }
}

export function propuestaBotAAccion(p: PropuestaBot): Accion {
  return {
    id: `bot-${p.id}`, nombre: `${nombres[p.tipo]} propuesta por WhatsApp · ${p.codigo}`,
    tipo: p.tipo_accion, actor_id: `bot-actor-${p.id}`, sector: p.zona,
    lat: p.lat, lon: p.lon, hectareas: 0, accion_plan: null, prioridad_plan: null,
    plan_aproximado: false, estado: 'propuesta', descripcion: p.descripcion,
    comunidad_coparticipante: '', requerimientos: [], observaciones: [], creada_en: p.creada_en,
    codigo_bot: p.codigo, canal: 'whatsapp', proponente: `${PROPONENTES[p.proponente] ?? 'Ciudadanía'} (por WhatsApp)`, tipo_actor: p.tipo_actor,
  };
}

let carga: Promise<void> | null = null;

/** Una descarga por visita; conserva los estados revisados en el almacén local. */
export function sincronizarPropuestasBot(): Promise<void> {
  if (typeof window === 'undefined') return Promise.resolve();
  if (carga) return carga;
  carga = cargarPropuestasBot().then((propuestas) => {
    if (!propuestas.length) return;
    const nuevas = propuestas.map(propuestaBotAAccion);
    try { acciones.obtener(); } catch { acciones.inicializar([]); }
    acciones.establecer((previas) => {
      const ids = new Set(previas.map((a) => a.id));
      const faltantes = nuevas.filter((a) => !ids.has(a.id));
      return faltantes.length ? [...previas, ...faltantes] : previas;
    });
  });
  return carga;
}

export function useSincronizarPropuestasBot(): void {
  useEffect(() => { void sincronizarPropuestasBot(); }, []);
}
