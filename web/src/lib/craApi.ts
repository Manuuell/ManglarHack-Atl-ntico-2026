// Datos oficiales de la C.R.A. leídos en vivo desde el navegador:
// - la API pública de gestión del riesgo de la Corporación (la misma que alimenta
//   sus visores de puntos críticos y su geovisor ambiental), que acepta
//   peticiones desde cualquier origen;
// - las noticias de crautonoma.gov.co (WordPress), que aceptan el origen de esta web.
//
// Solo se leen (GET). Si la C.R.A. no responde, el mapa y la portada siguen
// funcionando sin estas capas y lo dicen.
import type { MultiPolygon, Polygon } from 'geojson';
import { LIMITES_MANGLAR } from './areaReporte';

export const API_CRA = 'https://api-791856053294.us-central1.run.app';
export const VISOR_PUNTOS_CRITICOS = 'https://www.crautonoma.gov.co/critical-points';
export const VISOR_GEOVISOR_CRA = 'https://www.crautonoma.gov.co/geovisor-ambiental/';
export const PAGINA_CALIDAD_AGUA = 'https://www.crautonoma.gov.co/ambiental/monitoreos-de-calidad-de-agua';
const NOTICIAS_CRA = 'https://www.crautonoma.gov.co/wp-json/wp/v2/posts';

const ESPERA_MS = 20000; // la API corre en Cloud Run y puede tardar en despertar

// Ids estables de la API (/cartography/municipalities). Se dejan aquí porque esa
// ruta trae los polígonos de los 23 municipios (más de 1 MB) y solo hace falta el nombre.
const MUNICIPIOS: Record<number, string> = {
  1: 'Barranquilla', 2: 'Puerto Colombia', 3: 'Galapa', 4: 'Soledad', 5: 'Tubará', 6: 'Malambo', 7: 'Baranoa',
  8: 'Juan de Acosta', 9: 'Polonuevo', 10: 'Sabanagrande', 11: 'Piojó', 12: 'Usiacurí', 13: 'Santo Tomás',
  14: 'Palmar de Varela', 15: 'Ponedera', 16: 'Sabanalarga', 17: 'Luruaco', 18: 'Repelón', 19: 'Manatí',
  20: 'Candelaria', 21: 'Campo de la Cruz', 22: 'Santa Lucía', 23: 'Suan',
};

// Cuerpos de agua (/water_bodies) con el nombre corregido; la ruta trae también sus polígonos.
const CUERPOS_DE_AGUA: Record<number, string> = {
  1: 'Río Magdalena', 2: 'Ciénaga Bartolo', 3: 'Ciénaga Las Cabezas', 4: 'Ciénaga La Viuda', 5: 'Ciénaga Caimanera',
  6: 'Ciénaga Calabacito', 7: 'Ciénaga Sábalo', 8: 'La Chacha', 9: 'Ciénaga Barba Rucia', 10: 'Ciénaga El Zabalo',
  11: 'Ciénaga de Balboa', 12: 'Ciénaga El Totumo', 13: 'Ciénaga El Salado', 14: 'Ciénaga Los Manatíes',
  15: 'Ciénaga de Mallorquín', 16: 'Ciénaga Bonga', 17: 'Ciénaga La Poza', 18: 'Ciénaga del Rosario', 19: 'Ciénaga El Uvero',
  20: 'Ciénaga de Malambo', 21: 'Ciénaga La Bahía', 22: 'Ciénaga El Convento', 23: 'Ciénaga de Zico', 24: 'Ciénaga de Sabanagrande',
  25: 'Caño Viejo', 26: 'Ciénaga Pescadero', 27: 'Ciénaga Roblá', 28: 'Ciénaga Poza de Jayo', 29: 'Embalse del Guájaro',
  30: 'Laguna de Luruaco', 31: 'Laguna San Juan de Tocagua', 32: 'La Cienaguita', 33: 'Laguna Puerto Caimán',
  34: 'Lago del Cisne', 35: 'Ciénaga de Santo Tomás', 36: 'Complejo cenagoso de Palmar de Varela',
};

/** Ciénagas rodeadas de manglar: sus puntos de muestreo se muestran aunque queden en medio del espejo de agua. */
export const CIENAGAS_CON_MANGLAR = [11, 12, 14, 15]; // Balboa, El Totumo, Los Manatíes, Mallorquín

// Respaldo por si /critical_points/attributes no responde (mismos ids y colores de la API).
const TIPOS_RESPALDO: TipoEventoCRA[] = [
  { id: 1, nombre: 'Inundación', color: '#386cb0' },
  { id: 2, nombre: 'Remoción en masa', color: '#7fc97f' },
  { id: 3, nombre: 'Erosión costera', color: '#dada3a' },
  { id: 4, nombre: 'Incendio forestal', color: '#f0027f' },
  { id: 5, nombre: 'Socavamiento', color: '#b600c7' },
  { id: 6, nombre: 'Proceso erosivo', color: '#e68a00' },
];
const ZONAS_RESPALDO: Record<number, string> = { 1: 'Urbana', 2: 'Costera', 3: 'Rural' };

export interface TipoEventoCRA { id: number; nombre: string; color: string }

export interface PuntoCriticoCRA {
  id: number;
  tipo: TipoEventoCRA;
  zona: string;
  municipio: string;
  descripcion: string;
  registrado_en: string;
  confirmado: boolean;
  lat: number;
  lon: number;
}

export interface FocoIncendioCRA {
  id: number;
  municipio: string;
  desde: string;
  hasta: string;
  focos: number;
  satelites: string;
  confianza: string;
  geometria: Polygon | MultiPolygon;
  lat: number; // centro aproximado, para el marcador
  lon: number;
}

export interface CalidadAguaCRA {
  id: number;
  codigo: string;
  cuerpo_id: number;
  cuerpo: string;
  lat: number;
  lon: number;
  muestreado_en: string | null;
  ica: number | null;
  od_mg_l: number | null;
  ph: number | null;
  temperatura_c: number | null;
  coliformes_nmp_100ml: number | null;
}

export interface CapasCRA {
  puntos: PuntoCriticoCRA[];
  incendios: FocoIncendioCRA[];
  agua: CalidadAguaCRA[];
  tipos: TipoEventoCRA[];
}

export interface NoticiaCRA { id: number; fecha: string; titulo: string; resumen: string; enlace: string; imagen: string | null }

// ---- Utilidades ----
async function pedir<T>(url: string): Promise<T> {
  const respuesta = await fetch(url, { signal: AbortSignal.timeout(ESPERA_MS) });
  if (!respuesta.ok) throw new Error(`La C.R.A. respondió ${respuesta.status}`);
  return (await respuesta.json()) as T;
}

const numero = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) ? v : null);
const texto = (v: unknown): string => (typeof v === 'string' ? v.trim() : '');
const [[SUR, OESTE], [NORTE, ESTE]] = LIMITES_MANGLAR;
/** Solo lo que cae en la franja costera del manglar (los mapas no se salen de ahí). */
export const enFranjaManglar = (lat: number, lon: number) => lat >= SUR && lat <= NORTE && lon >= OESTE && lon <= ESTE;

/** Quita etiquetas y entidades HTML sin insertar nada en la página. */
function textoPlano(html: string): string {
  if (typeof DOMParser === 'undefined') return html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
  return (new DOMParser().parseFromString(html, 'text/html').body.textContent ?? '').replace(/\s+/g, ' ').trim();
}

function centro(g: Polygon | MultiPolygon): [number, number] {
  const anillo = g.type === 'Polygon' ? g.coordinates[0] : g.coordinates[0][0];
  const n = anillo.length || 1;
  const lon = anillo.reduce((s, p) => s + p[0], 0) / n;
  const lat = anillo.reduce((s, p) => s + p[1], 0) / n;
  return [lat, lon];
}

// ---- Capas del mapa ----
interface Coleccion<P, G> { features: { id?: number | string; properties: P; geometry: G }[] }

async function tiposDeEvento(): Promise<{ tipos: TipoEventoCRA[]; zonas: Record<number, string> }> {
  try {
    const [tipos, zonas] = await Promise.all([
      pedir<{ id: number; event_type: string; color: string }[]>(`${API_CRA}/critical_points/attributes/event_types/items`),
      pedir<{ id: number; event_zone: string }[]>(`${API_CRA}/critical_points/attributes/event_zones/items`),
    ]);
    return {
      // La API manda algunos colores con canal alfa (#b600c7ff): se deja el color sólido.
      tipos: tipos.map((t) => ({ id: t.id, nombre: t.event_type, color: t.color.slice(0, 7) })),
      zonas: Object.fromEntries(zonas.map((z) => [z.id, z.event_zone])),
    };
  } catch {
    return { tipos: TIPOS_RESPALDO, zonas: ZONAS_RESPALDO };
  }
}

async function puntosCriticos(tipos: TipoEventoCRA[], zonas: Record<number, string>): Promise<PuntoCriticoCRA[]> {
  type P = { event_type_id: number; event_zone_id: number; municipality_id: number; description: string; datetime: string; confirmed: number };
  const datos = await pedir<Coleccion<P, { type: 'Point'; coordinates: number[] }>>(`${API_CRA}/critical_points/items?format=geojson`);
  const porId = new Map(tipos.map((t) => [t.id, t]));
  return datos.features.flatMap((f) => {
    const [lon, lat] = f.geometry?.coordinates ?? [];
    if (typeof lat !== 'number' || typeof lon !== 'number' || !enFranjaManglar(lat, lon)) return [];
    const p = f.properties;
    return [{
      id: Number(f.id),
      tipo: porId.get(p.event_type_id) ?? { id: p.event_type_id, nombre: 'Otro evento', color: '#94a3b8' },
      zona: zonas[p.event_zone_id] ?? '',
      municipio: MUNICIPIOS[p.municipality_id] ?? '',
      descripcion: texto(p.description),
      registrado_en: p.datetime,
      confirmado: p.confirmed === 1,
      lat, lon,
    }];
  });
}

async function focosDeIncendio(): Promise<FocoIncendioCRA[]> {
  type P = { oldest_acquisition: string; newest_acquisition: string; satellites: string; fire_confidence: string; num_fires: number; municipality_id: number };
  const datos = await pedir<Coleccion<P, Polygon | MultiPolygon>>(`${API_CRA}/wildfire-clusters/items?format=geojson`);
  return datos.features.flatMap((f) => {
    if (!f.geometry || (f.geometry.type !== 'Polygon' && f.geometry.type !== 'MultiPolygon')) return [];
    const [lat, lon] = centro(f.geometry);
    if (!enFranjaManglar(lat, lon)) return [];
    const p = f.properties;
    return [{
      id: Number(f.id), municipio: MUNICIPIOS[p.municipality_id] ?? '', desde: p.oldest_acquisition, hasta: p.newest_acquisition,
      focos: p.num_fires, satelites: texto(p.satellites).replaceAll(',', ', '), confianza: p.fire_confidence, geometria: f.geometry, lat, lon,
    }];
  });
}

async function calidadDelAgua(): Promise<CalidadAguaCRA[]> {
  type P = { water_body_id: number; code: string };
  type M = { sampling_point_id: number; sampled_at: string; ica: number | null; od_mg_l: number | null; ph: number | null; temperature_c: number | null; coliforms_nmp_100ml: number | null };
  const [puntos, mediciones] = await Promise.all([
    pedir<Coleccion<P, { type: 'Point'; coordinates: number[] }>>(`${API_CRA}/water_bodies/sampling_points/items?format=geojson`),
    pedir<M[]>(`${API_CRA}/water_bodies/measurements/items`),
  ]);
  // La medición más reciente de cada punto de muestreo.
  const ultima = new Map<number, M>();
  for (const m of mediciones) {
    const previa = ultima.get(m.sampling_point_id);
    if (!previa || m.sampled_at > previa.sampled_at) ultima.set(m.sampling_point_id, m);
  }
  return puntos.features.flatMap((f) => {
    const [lon, lat] = f.geometry?.coordinates ?? [];
    if (typeof lat !== 'number' || typeof lon !== 'number' || !enFranjaManglar(lat, lon)) return [];
    const id = Number(f.id); const m = ultima.get(id);
    return [{
      id, codigo: texto(f.properties.code), cuerpo_id: f.properties.water_body_id, cuerpo: CUERPOS_DE_AGUA[f.properties.water_body_id] ?? 'Cuerpo de agua', lat, lon,
      muestreado_en: m?.sampled_at ?? null, ica: numero(m?.ica), od_mg_l: numero(m?.od_mg_l), ph: numero(m?.ph),
      temperatura_c: numero(m?.temperature_c), coliformes_nmp_100ml: numero(m?.coliforms_nmp_100ml),
    }];
  });
}

let capasEnCurso: Promise<CapasCRA> | null = null;

/** Las tres capas oficiales, recortadas a la franja del manglar. Una capa que falla queda vacía;
 *  si fallan todas, la promesa se rechaza. */
export function obtenerCapasCRA(): Promise<CapasCRA> {
  capasEnCurso ??= (async () => {
    const { tipos, zonas } = await tiposDeEvento();
    const [puntos, incendios, agua] = await Promise.allSettled([puntosCriticos(tipos, zonas), focosDeIncendio(), calidadDelAgua()]);
    if (puntos.status === 'rejected' && incendios.status === 'rejected' && agua.status === 'rejected') {
      capasEnCurso = null; // permite reintentar
      throw new Error('La API de la C.R.A. no respondió');
    }
    const valor = <T,>(r: PromiseSettledResult<T[]>): T[] => (r.status === 'fulfilled' ? r.value : []);
    return { puntos: valor(puntos), incendios: valor(incendios), agua: valor(agua), tipos };
  })();
  return capasEnCurso;
}

// ---- Calidad del agua: escala del ICA del IDEAM (0 a 1) ----
export interface CategoriaICA { etiqueta: string; color: string; desde: number }
export const ESCALA_ICA: CategoriaICA[] = [
  { etiqueta: 'Buena', color: '#2563eb', desde: 0.91 },
  { etiqueta: 'Aceptable', color: '#16a34a', desde: 0.71 },
  { etiqueta: 'Regular', color: '#eab308', desde: 0.51 },
  { etiqueta: 'Mala', color: '#f97316', desde: 0.26 },
  { etiqueta: 'Muy mala', color: '#dc2626', desde: 0 },
];
export function categoriaICA(ica: number | null): CategoriaICA | null {
  return ica === null ? null : ESCALA_ICA.find((c) => ica >= c.desde) ?? ESCALA_ICA[ESCALA_ICA.length - 1];
}

// ---- Noticias ----
type PostWP = {
  id: number; date: string; link: string; title: { rendered: string }; excerpt: { rendered: string };
  _embedded?: { 'wp:featuredmedia'?: { media_details?: { sizes?: Record<string, { source_url: string }> } }[] };
};

/** Las noticias de la C.R.A. sobre el manglar y la ciénaga de Mallorquín, de la más reciente a la más vieja. */
export async function obtenerNoticiasCRA(cantidad = 6): Promise<NoticiaCRA[]> {
  const campos = '_fields=id,date,title,link,excerpt,_links,_embedded&_embed=wp:featuredmedia';
  const busquedas = ['manglar', 'Mallorquín'].map((q) =>
    pedir<PostWP[]>(`${NOTICIAS_CRA}?search=${encodeURIComponent(q)}&per_page=${cantidad}&${campos}`));
  const resultados = await Promise.allSettled(busquedas);
  const posts = resultados.flatMap((r) => (r.status === 'fulfilled' ? r.value : []));
  if (!posts.length && resultados.every((r) => r.status === 'rejected')) throw new Error('No se pudieron leer las noticias de la C.R.A.');
  const unicos = [...new Map(posts.map((p) => [p.id, p])).values()].sort((a, b) => b.date.localeCompare(a.date));
  return unicos.slice(0, cantidad).map((p) => {
    const tamanos = p._embedded?.['wp:featuredmedia']?.[0]?.media_details?.sizes;
    const imagen = tamanos?.medium_large?.source_url ?? tamanos?.medium?.source_url ?? tamanos?.large?.source_url ?? null;
    return {
      id: p.id, fecha: p.date, titulo: textoPlano(p.title.rendered), resumen: textoPlano(p.excerpt.rendered),
      // Solo enlaces e imágenes del propio sitio de la C.R.A.
      enlace: p.link.startsWith('https://www.crautonoma.gov.co/') ? p.link : 'https://www.crautonoma.gov.co/prensa/noticias',
      imagen: imagen?.startsWith('https://www.crautonoma.gov.co/') ? imagen : null,
    };
  });
}

export const formatoFechaCRA = (iso: string | null, conAnio = true) => iso
  ? new Date(iso).toLocaleDateString('es-CO', { day: 'numeric', month: 'short', ...(conAnio ? { year: 'numeric' } : {}) })
  : 'sin fecha';
