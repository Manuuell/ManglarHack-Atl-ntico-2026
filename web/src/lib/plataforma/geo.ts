import type { Position, Polygon } from 'geojson';
import type { ZonasManglar } from '../../types/manglar';
import type { SectorId, AccionPlan, NivelPlan } from '../../types/plataforma';

function distanciaSegmento(lat: number, lon: number, a: Position, b: Position): number {
  const escala = Math.PI * 6371000 / 180;
  const coseno = Math.cos(lat * Math.PI / 180);
  const ax = (a[0] - lon) * escala * coseno, ay = (a[1] - lat) * escala;
  const bx = (b[0] - lon) * escala * coseno, by = (b[1] - lat) * escala;
  const dx = bx - ax, dy = by - ay;
  const t = dx === 0 && dy === 0 ? 0 : Math.max(0, Math.min(1, -(ax * dx + ay * dy) / (dx * dx + dy * dy)));
  return Math.hypot(ax + t * dx, ay + t * dy);
}
function enAnillo(lat: number, lon: number, anillo: Position[]): boolean {
  let dentro = false;
  for (let i = 0, j = anillo.length - 1; i < anillo.length; j = i++) {
    const a = anillo[i], b = anillo[j];
    if ((a[1] > lat) !== (b[1] > lat) && lon < (b[0] - a[0]) * (lat - a[1]) / (b[1] - a[1]) + a[0]) dentro = !dentro;
  }
  return dentro;
}
/** Coordenadas GeoJSON [longitud, latitud]; incluye el borde y respeta huecos. */
export function puntoEnPoligono(lat: number, lon: number, poligono: Polygon | Position[][]): boolean {
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return false;
  const anillos = Array.isArray(poligono) ? poligono : poligono.coordinates;
  if (!anillos.length) return false;
  for (const anillo of anillos) {
    for (let i = 0; i < anillo.length; i++) {
      if (distanciaSegmento(lat, lon, anillo[i], anillo[(i + 1) % anillo.length]) < 0.001) return true;
    }
  }
  return enAnillo(lat, lon, anillos[0]) && !anillos.slice(1).some((anillo) => enAnillo(lat, lon, anillo));
}
const sectores: readonly string[] = ['mallorquin', 'balboa', 'manaties', 'totumo'];
export function sectorDePunto(lat: number, lon: number, zonas: ZonasManglar): { sector: SectorId | null; dentro: boolean; distancia_m: number } {
  let distancia = Infinity;
  if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) return { sector: null, dentro: false, distancia_m: distancia };
  for (const zona of zonas.features) {
    if (!sectores.includes(zona.properties.id)) continue;
    if (puntoEnPoligono(lat, lon, zona.geometry)) return { sector: zona.properties.id as SectorId, dentro: true, distancia_m: 0 };
    for (const anillo of zona.geometry.coordinates) {
      for (let i = 0; i < anillo.length; i++) distancia = Math.min(distancia, distanciaSegmento(lat, lon, anillo[i], anillo[(i + 1) % anillo.length]));
    }
  }
  // Fuera de los polígonos no se atribuye un sector; sin geometrías, Infinity.
  return { sector: null, dentro: false, distancia_m: distancia };
}
// Mapeo provisional: se reemplaza por la capa «Prioridades de conservación» de la C.R.A.
export function heredarPlan(sector: SectorId | null): { accion_plan: AccionPlan; prioridad_plan: NivelPlan | null; plan_aproximado: true } {
  const planes: Record<SectorId, [AccionPlan, NivelPlan]> = {
    mallorquin: ['restauracion', 'alta'], balboa: ['recuperacion', 'media'],
    manaties: ['preservacion', 'media'], totumo: ['preservacion', 'alta'],
  };
  const [accion_plan, prioridad_plan] = sector === null ? ['fuera_zonificacion' as const, null] : planes[sector];
  return { accion_plan, prioridad_plan, plan_aproximado: true };
}
