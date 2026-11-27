import fs from 'fs';

type Anillo = [number, number][]; // [lon, lat]
type Poligono = Anillo[]; // el primero es el borde, los demás son huecos

interface Zona {
  /** Id del contrato (mallorquin, tubara, juan_de_acosta, piojo), si la fuente lo trae. */
  id?: string;
  nombre: string;
  municipio?: string;
  /** Prioridad de conservación 1-5 si la fuente la trae. */
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

/** Zonas con nombre e id del contrato (para decirle a la persona dónde queda y mandar `zona`). */
let zonas: Zona[] = [];
/** Cobertura de manglar de la C.R.A. 1:5.000: decide si la denuncia se admite. */
let area: Zona[] = [];

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

/** Anillo codificado [x0, y0, dx1, dy1, …] en 1/unidad grados (versión 2 del archivo de la app). */
function decodificar(r: number[], unidad: number): Anillo {
  const anillo: Anillo = [];
  let x = 0, y = 0;
  for (let i = 0; i + 1 < r.length; i += 2) {
    x += r[i];
    y += r[i + 1];
    anillo.push([x / unidad, y / unidad]);
  }
  return anillo;
}

/**
 * Lee un archivo de zonas. Acepta:
 * - el de la app, versión 1 (app/assets/datos/manglar_zonas.json: { zonas: [{ id, nombre, poligonos: [anillo…] }] }),
 * - el de la app, versión 2 (con `unidad`: cada polígono es una lista de anillos codificados; es el de main, CRA 1:5.000),
 * - un GeoJSON de Polygon/MultiPolygon (por ejemplo datos/cra/manglar_cra_escala_1-5000.geojson).
 */
function leer(ruta: string): Zona[] {
  const geo = JSON.parse(fs.readFileSync(ruta, 'utf8'));
  const lista: Zona[] = [];
  if (Array.isArray(geo.zonas)) {
    const unidad = Number(geo.unidad);
    for (const z of geo.zonas) {
      const poligonos: Poligono[] = Number.isFinite(unidad) && unidad > 0
        ? (z.poligonos ?? []).map((p: number[][]) => p.map(r => decodificar(r, unidad)))
        : (z.poligonos ?? []).map((anillo: Anillo) => [anillo]);
      if (!poligonos.length) continue;
      const prioridad = Number(z.prioridadConservacion);
      lista.push({
        id: String(z.id),
        nombre: String(z.nombre ?? z.id),
        municipio: z.municipio ? String(z.municipio) : undefined,
        prioridad: Number.isFinite(prioridad) ? prioridad : undefined,
        poligonos,
        bbox: cajaDe(poligonos),
      });
    }
    return lista;
  }
  for (const f of geo.features ?? []) {
    const g = f?.geometry;
    if (!g) continue;
    const poligonos: Poligono[] =
      g.type === 'Polygon' ? [g.coordinates] : g.type === 'MultiPolygon' ? g.coordinates : [];
    if (!poligonos.length) continue;
    const props = f.properties ?? {};
    const prioridad = Number(props.prioridad);
    lista.push({
      nombre: nombreDe(props),
      prioridad: Number.isFinite(prioridad) && prioridad >= 1 && prioridad <= 5 ? prioridad : undefined,
      poligonos,
      bbox: cajaDe(poligonos),
    });
  }
  return lista;
}

/** Carga las zonas con nombre (ZONAS_GEOJSON). Devuelve cuántas quedaron. */
export function cargarZonas(ruta: string): number {
  zonas = leer(ruta);
  return zonas.length;
}

/**
 * Carga la cobertura que decide si una denuncia se admite (AREA_REPORTE_GEOJSON, la C.R.A. 1:5.000).
 * Si no se puede leer, el área de reporte se mide contra las zonas con nombre y se avisa en el log.
 */
export function cargarAreaReporte(ruta: string): number {
  try {
    area = leer(ruta);
  } catch (err) {
    area = [];
    console.warn(`[area] no se pudo leer ${ruta}: ${(err as Error).message}. Se usan las zonas de ZONAS_GEOJSON.`);
  }
  return area.length;
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

/** Zona más cercana de una capa: dentro (distancia 0) o la distancia en metros al borde más próximo. */
function masCercana(capa: Zona[], lat: number, lon: number): { zona?: Zona; dentro: boolean; distanciaM: number } {
  let mejor: { zona?: Zona; dentro: boolean; distanciaM: number } = { dentro: false, distanciaM: Infinity };
  for (const z of capa) {
    const [minLon, minLat, maxLon, maxLat] = z.bbox;
    const enCaja = lon >= minLon && lon <= maxLon && lat >= minLat && lat <= maxLat;
    if (enCaja) {
      for (const p of z.poligonos) if (dentroDePoligono(lon, lat, p)) return { zona: z, dentro: true, distanciaM: 0 };
    }
    // Descarta rápido las zonas cuya caja está mucho más lejos que el mejor candidato.
    const margenGrados = Number.isFinite(mejor.distanciaM) ? mejor.distanciaM / 100_000 : Infinity;
    if (lon < minLon - margenGrados || lon > maxLon + margenGrados || lat < minLat - margenGrados || lat > maxLat + margenGrados) continue;
    for (const p of z.poligonos) for (const anillo of p) {
      for (let i = 1; i < anillo.length; i++) {
        const d = distanciaASegmento(lon, lat, anillo[i - 1], anillo[i]);
        if (d < mejor.distanciaM) mejor = { zona: z, dentro: false, distanciaM: d };
      }
    }
  }
  return mejor;
}

/**
 * Dice si el punto cae en el manglar y, si no, a qué distancia está del borde más cercano.
 * Dentro/distancia salen de la cobertura C.R.A. (si está cargada); el nombre y el id de la zona, de ZONAS_GEOJSON.
 */
export function ubicar(lat: number, lon: number): ResultadoUbicacion {
  const z = masCercana(zonas, lat, lon);
  const a = area.length ? masCercana(area, lat, lon) : z;
  return {
    dentro: a.dentro,
    distanciaM: Number.isFinite(a.distanciaM) ? Math.round(a.distanciaM) : Infinity,
    zona: z.zona?.nombre,
    zonaId: z.zona?.id,
    municipio: z.zona?.municipio,
    prioridadZona: z.zona?.prioridad,
  };
}

/** La regla común (web y bot): se admite dentro de la cobertura o a menos del radio de influencia. */
export function enAreaDeReporte(u: Pick<ResultadoUbicacion, 'dentro' | 'distanciaM'>, radioM: number): boolean {
  return u.dentro || u.distanciaM <= radioM;
}

export function zonasCargadas(): number {
  return zonas.length;
}

export function areaCargada(): number {
  return area.length;
}
