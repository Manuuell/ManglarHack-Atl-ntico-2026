import { config } from '../config';

/**
 * Fuentes públicas que alimentan las alertas del manglar. Todas se leen sin clave:
 * - IDEAM (WIS2, OGC API): lo que miden ahora las estaciones automáticas del Atlántico.
 * - DIMAR (SIPSEM): pronóstico de 5 días (WRF y WW3) y tablas de pleamar y bajamar del CIOH.
 * - C.R.A. (API de gestión del riesgo): focos de calor detectados por satélite.
 * - Backend común (vista reportes_publicos): lo que reporta la comunidad.
 */

export const FUENTES = {
  ideam: { nombre: 'IDEAM · estaciones automáticas (WIS2)', url: 'https://wis.ideam.gov.co/oapi/collections/urn:wmo:md:co-ideam:automaticas' },
  dimar: { nombre: 'DIMAR · pronóstico meteomarino (SIPSEM)', url: 'https://meteorologia.dimar.mil.co/sipsem-web/' },
  mareas: { nombre: 'DIMAR · CIOH, tablas de pleamar y bajamar', url: 'https://meteorologia.dimar.mil.co/sipsem-web/' },
  cra: { nombre: 'C.R.A. · focos de calor por satélite', url: 'https://api-791856053294.us-central1.run.app/docs' },
  comunidad: { nombre: 'Reportes de la comunidad (Zanky)', url: 'https://mimanglar.sentralabs.co/#monitoreo' },
} as const;

export type IdFuente = keyof typeof FUENTES;

const IDEAM = 'https://wis.ideam.gov.co/oapi/collections';
const DIMAR = 'https://meteorologia.dimar.mil.co/api';
const CRA = 'https://api-791856053294.us-central1.run.app';
/** Caja del Atlántico (lon, lat): todas las estaciones automáticas del departamento. */
const CAJA_ATLANTICO = '-75.4,10.2,-74.6,11.2';

async function pedirJson<T>(url: string, ms = 25_000, cabeceras: Record<string, string> = {}): Promise<T> {
  const res = await fetch(url, {
    signal: AbortSignal.timeout(ms),
    headers: { Accept: 'application/json', 'User-Agent': 'ZankyAlertas/1.0 (+https://mimanglar.sentralabs.co)', ...cabeceras },
  });
  if (!res.ok) throw new Error(`${new URL(url).host} respondió ${res.status}`);
  return (await res.json()) as T;
}

// --- IDEAM -------------------------------------------------------------------

export interface Estacion {
  id: string;
  nombre: string;
  lat: number;
  lon: number;
}

export interface Lectura {
  estacion: string;
  variable: string;
  valor: number;
  unidad: string;
  /** Inicio y fin del periodo medido (en lluvia, la hora acumulada; en lo demás, el mismo instante). */
  inicio: string;
  fin: string;
}

let estacionesCache: { cuando: number; lista: Map<string, Estacion> } | null = null;

export async function estacionesIdeam(): Promise<Map<string, Estacion>> {
  if (estacionesCache && Date.now() - estacionesCache.cuando < 24 * 3600_000) return estacionesCache.lista;
  const d = await pedirJson<{ features?: any[] }>(`${IDEAM}/stations/items?f=json&bbox=${CAJA_ATLANTICO}&limit=200`);
  const lista = new Map<string, Estacion>();
  for (const f of d.features ?? []) {
    const [lon, lat] = f?.geometry?.coordinates ?? [];
    if (typeof f?.id === 'string' && Number.isFinite(lat) && Number.isFinite(lon)) {
      lista.set(f.id, { id: f.id, nombre: limpiarNombre(String(f.properties?.name ?? f.id)), lat, lon });
    }
  }
  estacionesCache = { cuando: Date.now(), lista };
  return lista;
}

function limpiarNombre(n: string): string {
  const t = n.replace(/\s*-?\s*(AUT|MAG)\b/g, '').replace(/\s+/g, ' ').trim().toLowerCase();
  return t
    .replace(/(^|[\s(/.-])(\p{L})/gu, (_m, a: string, b: string) => a + b.toUpperCase())
    .replace(/ (De|Del|La|Las|Los|Y)(?= )/g, (_m, p: string) => ` ${p.toLowerCase()}`);
}

/** Lecturas de las últimas `horas` en todo el Atlántico (lluvia, viento, temperatura, humedad, presión). */
export async function lecturasIdeam(horas: number): Promise<Lectura[]> {
  const desde = new Date(Date.now() - horas * 3600_000).toISOString().slice(0, 19) + 'Z';
  const d = await pedirJson<{ features?: any[] }>(
    `${IDEAM}/urn:wmo:md:co-ideam:automaticas/items?f=json&bbox=${CAJA_ATLANTICO}&datetime=${desde}/..&limit=10000`,
    40_000,
  );
  const lecturas: Lectura[] = [];
  for (const f of d.features ?? []) {
    const p = f?.properties ?? {};
    if (typeof p.value !== 'number' || typeof p.wigos_station_identifier !== 'string') continue;
    const [inicio, fin] = String(p.phenomenonTime ?? '').split('/');
    if (!inicio) continue;
    lecturas.push({ estacion: p.wigos_station_identifier, variable: String(p.name), valor: p.value, unidad: String(p.units ?? ''), inicio, fin: fin ?? inicio });
  }
  return lecturas;
}

// --- DIMAR -------------------------------------------------------------------

export interface HoraPronostico {
  hora: string;
  temperatura: number;
  humedad: number;
  /** mm en la hora. */
  lluvia: number;
  /** m/s */
  viento: number;
  /** Altura significativa de ola (m), del modelo WW3. */
  ola: number | null;
}

const num = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? v : NaN);

/** Pronóstico horario de 5 días en un punto (lon, lat). */
export async function pronosticoDimar(lat: number, lon: number): Promise<HoraPronostico[]> {
  const d = await pedirJson<{ listFecha?: any[] }>(`${DIMAR}/Forecast/meteograma/${lon}/${lat}`);
  return (d.listFecha ?? [])
    .map(x => ({
      hora: String(x?.hora ?? ''),
      temperatura: num(x?.temperature),
      humedad: num(x?.relative_humidity),
      lluvia: num(x?.precipitation),
      viento: num(x?.wind_speed),
      ola: Number.isFinite(num(x?.wave_height)) ? num(x?.wave_height) : null,
    }))
    .filter(h => h.hora);
}

export interface EventoMarea {
  t: string;
  tipo: 'PLEAMAR' | 'BAJAMAR';
  m: number;
}

/** Pleamares y bajamares predichas (tablas astronómicas del CIOH) para los próximos días. */
export async function mareasDimar(codigo: string, dias: number): Promise<EventoMarea[]> {
  const d = await pedirJson<{ eventos?: any[] }>(`${DIMAR}/Mareas/${encodeURIComponent(codigo)}?dias=${dias}`);
  return (d.eventos ?? [])
    .filter(e => (e?.tipo === 'PLEAMAR' || e?.tipo === 'BAJAMAR') && typeof e?.t === 'string' && Number.isFinite(e?.m))
    .map(e => ({ t: e.t, tipo: e.tipo, m: e.m }));
}

// --- C.R.A. ------------------------------------------------------------------

export interface FocoCalor {
  lat: number;
  lon: number;
  desde: string;
  hasta: string;
  focos: number;
  confianza: string;
  satelites: string;
}

export async function focosCra(): Promise<FocoCalor[]> {
  const d = await pedirJson<{ features?: any[] }>(`${CRA}/wildfire-clusters/items?format=geojson`);
  const focos: FocoCalor[] = [];
  for (const f of d.features ?? []) {
    const p = f?.properties ?? {};
    const anillo: number[][] | undefined = f?.geometry?.type === 'MultiPolygon' ? f.geometry.coordinates?.[0]?.[0] : f?.geometry?.coordinates?.[0];
    if (!Array.isArray(anillo) || !anillo.length || typeof p.newest_acquisition !== 'string') continue;
    const lon = anillo.reduce((s, c) => s + c[0], 0) / anillo.length;
    const lat = anillo.reduce((s, c) => s + c[1], 0) / anillo.length;
    focos.push({
      lat, lon,
      desde: aIsoBogota(String(p.oldest_acquisition ?? p.newest_acquisition)),
      hasta: aIsoBogota(p.newest_acquisition),
      focos: Number(p.num_fires) || 1,
      confianza: String(p.fire_confidence ?? ''),
      satelites: String(p.satellites ?? ''),
    });
  }
  return focos;
}

/** La API de la C.R.A. da la hora sin zona; se toma como UTC, que es como la entregan los satélites. */
function aIsoBogota(t: string): string {
  return /[zZ]|[+-]\d\d:?\d\d$/.test(t) ? t : `${t}Z`;
}

// --- Comunidad (backend común) ----------------------------------------------

export interface ReportePublico {
  tipo: string;
  zona: string | null;
  municipio: string | null;
  estado: string;
  capturado_en: string;
  lat: number;
  lon: number;
}

export function comunidadActiva(): boolean {
  return Boolean(config.supabaseUrl && config.supabaseAnon);
}

/** Reportes de la vista pública (sin descripción, foto ni reportante) de las últimas `horas`. */
export async function reportesRecientes(horas: number): Promise<ReportePublico[]> {
  const desde = new Date(Date.now() - horas * 3600_000).toISOString();
  const url = `${config.supabaseUrl}/rest/v1/reportes_publicos?select=tipo,zona,municipio,estado,capturado_en,lat,lon`
    + `&capturado_en=gte.${encodeURIComponent(desde)}&order=capturado_en.desc&limit=1000`;
  return pedirJson<ReportePublico[]>(url, 20_000, { apikey: config.supabaseAnon, Authorization: `Bearer ${config.supabaseAnon}` });
}
