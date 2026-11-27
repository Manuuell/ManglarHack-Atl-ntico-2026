// Área donde se admiten denuncias: la cobertura de manglar de la C.R.A. a escala
// 1:5.000 (datos/cra/manglar_escala_1-5000.gdb.zip) más un área de influencia de
// 500 m, porque un vertimiento o un caño taponado pueden estar fuera del polígono y
// afectarlo igual (handoff/03). Fuera de esa área —por ejemplo, el casco urbano de
// Barranquilla— la denuncia no corresponde a esta herramienta.
//
// La regla definitiva la aplica el servidor al recibir el reporte; aquí se usa
// para no publicar lo que queda fuera y para avisar en los formularios.
import type { CapaManglarCRA, Reporte } from '../types/manglar';

export const RADIO_INFLUENCIA_M = 500;

/** Extensión de la cobertura de manglar con ~3 km de margen ([sur, oeste], [norte, este]).
 *  Los mapas no se salen de aquí. */
export const LIMITES_MANGLAR: [[number, number], [number, number]] = [[10.655, -75.285], [11.09, -74.795]];

type ConArea = Pick<Reporte, 'dentro_poligono' | 'distancia_m'>;

/** Con la distancia que calculó el servidor (o el mock): ¿está en el área de reporte? */
export function enAreaDeReporte(r: ConArea): boolean {
  return r.dentro_poligono || (r.distancia_m !== null && r.distancia_m <= RADIO_INFLUENCIA_M);
}

export function describirArea(r: ConArea): string {
  if (r.dentro_poligono) return 'Dentro del manglar';
  if (r.distancia_m === null) return 'Ubicación sin evaluar';
  const m = r.distancia_m.toLocaleString('es-CO');
  return r.distancia_m <= RADIO_INFLUENCIA_M ? `A ${m} m del manglar (área de influencia)` : `Fuera del área de reporte (a ${m} m del manglar)`;
}

// ---- Evaluación en vivo de un punto contra la capa (formularios) ----
type Anillo = number[][];
interface Indice { caja: [number, number, number, number]; anillos: Anillo[] }
const indices = new WeakMap<CapaManglarCRA, Indice[]>();

function indexar(capa: CapaManglarCRA): Indice[] {
  let lista = indices.get(capa);
  if (!lista) {
    lista = capa.features.flatMap((f) => (f.geometry.type === 'Polygon' ? [f.geometry.coordinates] : f.geometry.coordinates)).map((anillos) => {
      const xs = anillos[0].map((p) => p[0]); const ys = anillos[0].map((p) => p[1]);
      return { caja: [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)] as [number, number, number, number], anillos };
    });
    indices.set(capa, lista);
  }
  return lista;
}
function enAnillo(lat: number, lon: number, a: Anillo): boolean {
  let c = false;
  for (let i = 0, j = a.length - 1; i < a.length; j = i++) {
    if ((a[i][1] > lat) !== (a[j][1] > lat) && lon < ((a[j][0] - a[i][0]) * (lat - a[i][1])) / (a[j][1] - a[i][1]) + a[i][0]) c = !c;
  }
  return c;
}
function distanciaSegmento(lat: number, lon: number, a: number[], b: number[]): number {
  const k = 111320 * Math.cos((lat * Math.PI) / 180); const m = 110540;
  const ax = (a[0] - lon) * k, ay = (a[1] - lat) * m, bx = (b[0] - lon) * k, by = (b[1] - lat) * m;
  const dx = bx - ax, dy = by - ay;
  const t = Math.max(0, Math.min(1, -(ax * dx + ay * dy) / (dx * dx + dy * dy || 1)));
  return Math.hypot(ax + t * dx, ay + t * dy);
}

/** Distancia en metros a la cobertura de manglar (0 si está dentro) y si se admite la denuncia. */
export function evaluarUbicacion(lat: number, lon: number, capa: CapaManglarCRA): { dentro_poligono: boolean; distancia_m: number; admitido: boolean } {
  const margen = 0.02; // ≈ 2 km: polígonos más lejanos no pueden estar a menos de 500 m
  let distancia = Infinity;
  for (const { caja, anillos } of indexar(capa)) {
    if (lon < caja[0] - margen || lon > caja[2] + margen || lat < caja[1] - margen || lat > caja[3] + margen) continue;
    if (lon >= caja[0] && lon <= caja[2] && lat >= caja[1] && lat <= caja[3] && enAnillo(lat, lon, anillos[0]) && !anillos.slice(1).some((h) => enAnillo(lat, lon, h))) {
      return { dentro_poligono: true, distancia_m: 0, admitido: true };
    }
    for (const anillo of anillos) for (let i = 0; i < anillo.length - 1; i++) distancia = Math.min(distancia, distanciaSegmento(lat, lon, anillo[i], anillo[i + 1]));
  }
  const d = Number.isFinite(distancia) ? Math.round(distancia) : Infinity;
  return { dentro_poligono: false, distancia_m: d, admitido: d <= RADIO_INFLUENCIA_M };
}
