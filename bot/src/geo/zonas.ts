import fs from 'fs';

type Anillo = [number, number][]; // [lon, lat]
type Poligono = Anillo[]; // el primero es el borde, los demás son huecos

interface Zona {
  /** Id del contrato (mallorquin, tubara, juan_de_acosta, piojo), si la fuente lo trae. */
  id?: string;
  nombre: string;
  municipio?: string;
  /** Prioridad de conservación 1-5 si el GeoJSON la trae (propiedad "prioridad"). */
  prioridad?: number;
  poligonos: Poligono[];
  bbox: [number, number, number, number]; // minLon, minLat, maxLon, maxLat
}

export interface ResultadoUbicacion {
  dentro: boolean;
  /** Metros al borde de manglar más cercano (0 si está dentro). */
  distanciaM: number;
  zona?: string;
  zonaId?: string;
  municipio?: string;
  prioridadZona?: number;
}

let zonas: Zona[] = [];

function nombreDe(props: Record<string, unknown>): string {
  const candidato = props.nombre ?? props.Name ?? props.name ?? props.NOMBRE;
  return typeof candidato === 'string' && candidato.trim() ? candidato.trim() : 'Manglar del Atlántico';
}

function cajaDe(poligonos: Poligono[]): [number, number, number, number] {
  let minLon = Infinity, minLat = Infinity, maxLon = -Infinity, maxLat = -Infinity;
  for (const p of poligonos) for (const [lon, lat] of p[0]) {
    minLon = Math.min(minLon, lon); maxLon = Math.max(maxLon, lon);
    minLat = Math.min(minLat, lat); maxLat = Math.max(maxLat, lat);
  }
  return [minLon, minLat, maxLon, maxLat];
}

/**
 * Carga las zonas de manglar. Acepta el archivo de la app (app/assets/datos/manglar_zonas.json:
 * { zonas: [{ id, nombre, municipio, prioridadConservacion, poligonos: [anillo, …] }] }), que es el mismo
 * del que sale backend/supabase/zonas.sql, o un GeoJSON de Polygon/MultiPolygon.
 */
export function cargarZonas(ruta: string): number {
  const geo = JSON.parse(fs.readFileSync(ruta, 'utf8'));
  zonas = [];
  if (Array.isArray(geo.zonas)) {
    for (const z of geo.zonas) {
      const poligonos: Poligono[] = (z.poligonos ?? []).map((anillo: Anillo) => [anillo]);
      if (!poligonos.length) continue;
      const prioridad = Number(z.prioridadConservacion);
      zonas.push({
        id: String(z.id),
        nombre: String(z.nombre ?? z.id),
        municipio: z.municipio ? String(z.municipio) : undefined,
        prioridad: Number.isFinite(prioridad) ? prioridad : undefined,
        poligonos,
        bbox: cajaDe(poligonos),
      });
    }
    return zonas.length;
  }
  for (const f of geo.features ?? []) {
    const g = f?.geometry;
    if (!g) continue;
    const poligonos: Poligono[] =
      g.type === 'Polygon' ? [g.coordinates] : g.type === 'MultiPolygon' ? g.coordinates : [];
    if (!poligonos.length) continue;
    let minLon = Infinity, minLat = Infinity, maxLon = -Infinity, maxLat = -Infinity;
    for (const p of poligonos) for (const [lon, lat] of p[0]) {
      minLon = Math.min(minLon, lon); maxLon = Math.max(maxLon, lon);
      minLat = Math.min(minLat, lat); maxLat = Math.max(maxLat, lat);
    }
    const props = f.properties ?? {};
    const prioridad = Number(props.prioridad);
    zonas.push({
      nombre: nombreDe(props),
      prioridad: Number.isFinite(prioridad) && prioridad >= 1 && prioridad <= 5 ? prioridad : undefined,
      poligonos,
      bbox: [minLon, minLat, maxLon, maxLat],
    });
  }
  return zonas.length;
}

function dentroDeAnillo(lon: number, lat: number, anillo: Anillo): boolean {
  let dentro = false;
  for (let i = 0, j = anillo.length - 1; i < anillo.length; j = i++) {
    const [xi, yi] = anillo[i];
    const [xj, yj] = anillo[j];
    if ((yi > lat) !== (yj > lat) && lon < ((xj - xi) * (lat - yi)) / (yj - yi) + xi) dentro = !dentro;
  }
  return dentro;
}

function dentroDePoligono(lon: number, lat: number, p: Poligono): boolean {
  if (!dentroDeAnillo(lon, lat, p[0])) return false;
  return !p.slice(1).some(hueco => dentroDeAnillo(lon, lat, hueco));
}

/** Distancia en metros de un punto a un segmento, en proyección local (suficiente a escala de kilómetros). */
function distanciaASegmento(lon: number, lat: number, a: [number, number], b: [number, number]): number {
  const kx = 111_320 * Math.cos((lat * Math.PI) / 180);
  const ky = 110_540;
  const ax = (a[0] - lon) * kx, ay = (a[1] - lat) * ky;
  const bx = (b[0] - lon) * kx, by = (b[1] - lat) * ky;
  const dx = bx - ax, dy = by - ay;
  const largo2 = dx * dx + dy * dy;
  const t = largo2 === 0 ? 0 : Math.max(0, Math.min(1, -(ax * dx + ay * dy) / largo2));
  const px = ax + t * dx, py = ay + t * dy;
  return Math.hypot(px, py);
}

/** Dice si el punto cae en el manglar y, si no, a qué distancia está del borde más cercano. */
export function ubicar(lat: number, lon: number): ResultadoUbicacion {
  let mejor: ResultadoUbicacion = { dentro: false, distanciaM: Infinity };
  for (const z of zonas) {
    for (const p of z.poligonos) {
      if (dentroDePoligono(lon, lat, p)) return { dentro: true, distanciaM: 0, zona: z.nombre, zonaId: z.id, municipio: z.municipio, prioridadZona: z.prioridad };
    }
    // Descarta rápido las zonas cuya caja está mucho más lejos que el mejor candidato.
    const margenGrados = Number.isFinite(mejor.distanciaM) ? mejor.distanciaM / 100_000 : Infinity;
    const [minLon, minLat, maxLon, maxLat] = z.bbox;
    if (lon < minLon - margenGrados || lon > maxLon + margenGrados || lat < minLat - margenGrados || lat > maxLat + margenGrados) continue;
    for (const p of z.poligonos) for (const anillo of p) {
      for (let i = 1; i < anillo.length; i++) {
        const d = distanciaASegmento(lon, lat, anillo[i - 1], anillo[i]);
        if (d < mejor.distanciaM) mejor = { dentro: false, distanciaM: d, zona: z.nombre, zonaId: z.id, municipio: z.municipio, prioridadZona: z.prioridad };
      }
    }
  }
  return { ...mejor, distanciaM: Math.round(mejor.distanciaM) };
}

export function zonasCargadas(): number {
  return zonas.length;
}
