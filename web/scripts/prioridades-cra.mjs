// Convierte el KMZ «Prioridades de conservación» de la C.R.A. en una capa
// GeoJSON ligera para la web, recortada a los cuatro sectores del manglar.
//
//   npm run capas:prioridades
//
// Entrada:  ../datos/cra/prioridades_conservacion_cra.kmz (exportación de ArcGIS:
//           los atributos vienen en una tabla HTML dentro de <description>).
// Salida:   public/datos/prioridades-cra.geojson (simplificada con mapshaper)
//
// Ante un formato inesperado el script se detiene y lo dice: no inventa datos.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { unzipSync, strFromU8 } from 'fflate';

const web = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ENTRADA = path.resolve(web, '../datos/cra/prioridades_conservacion_cra.kmz');
const SECTORES = path.resolve(web, 'src/data/poligonosManglar.json');
const SALIDA = path.resolve(web, 'public/datos/prioridades-cra.geojson');
const TEMPORAL = path.resolve(web, 'node_modules/.cache/prioridades-cra-completa.geojson');
const MARGEN = 0.01; // ≈ 1,1 km alrededor de cada sector

if (!fs.existsSync(ENTRADA)) {
  console.log(`No está el KMZ de la C.R.A. en ${ENTRADA}. Nada que convertir.`);
  process.exit(0);
}

const zip = unzipSync(new Uint8Array(fs.readFileSync(ENTRADA)));
const nombreKml = Object.keys(zip).find((n) => n.toLowerCase().endsWith('.kml'));
if (!nombreKml) throw new Error('El KMZ no contiene ningún .kml.');
const kml = strFromU8(zip[nombreKml]);

const ACCIONES = { 'Preservación': 'preservacion', 'Restauración': 'restauracion', 'Recuperación': 'recuperacion', 'Rehabilitación': 'rehabilitacion' };
const PRIORIDADES = { Alto: 'alta', Medio: 'media', Bajo: 'baja' };

// Sectores con margen: un polígono entra si algún vértice cae dentro.
const sectores = JSON.parse(fs.readFileSync(SECTORES, 'utf8')).features.map((f) => {
  const anillo = f.geometry.coordinates[0];
  const cx = anillo.reduce((s, p) => s + p[0], 0) / anillo.length;
  const cy = anillo.reduce((s, p) => s + p[1], 0) / anillo.length;
  const ampliado = anillo.map(([x, y]) => { const d = Math.hypot(x - cx, y - cy) || 1; return [x + ((x - cx) / d) * MARGEN, y + ((y - cy) / d) * MARGEN]; });
  const xs = ampliado.map((p) => p[0]); const ys = ampliado.map((p) => p[1]);
  return { id: f.properties.id, anillo: ampliado, caja: [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)] };
});
const dentro = (x, y, anillo) => {
  let c = false;
  for (let i = 0, j = anillo.length - 1; i < anillo.length; j = i++) {
    const [xi, yi] = anillo[i]; const [xj, yj] = anillo[j];
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) c = !c;
  }
  return c;
};
const sectorDe = (anillos) => {
  for (const s of sectores) {
    for (const anillo of anillos) {
      for (let k = 0; k < anillo.length; k += 4) {
        const [x, y] = anillo[k];
        if (x >= s.caja[0] && x <= s.caja[2] && y >= s.caja[1] && y <= s.caja[3] && dentro(x, y, s.anillo)) return s.id;
      }
    }
  }
  return null;
};
const anilloDe = (texto) => texto.trim().split(/\s+/).map((t) => { const [x, y] = t.split(',').map(Number); return [Math.round(x * 1e6) / 1e6, Math.round(y * 1e6) / 1e6]; });

const placemarks = kml.split('<Placemark').slice(1);
if (!placemarks.length) throw new Error('El KML no tiene elementos <Placemark>.');
const features = [];
let descartados = 0;
for (const p of placemarks) {
  const a = {};
  for (const m of p.matchAll(/<td>([^<]+)<\/td>\s*<td>([^<]*)<\/td>/g)) a[m[1]] = m[2].trim();
  const accion = ACCIONES[a.AccionGen];
  const prioridad = PRIORIDADES[a.Val_Priori];
  if (!accion || !prioridad) throw new Error(`Atributos inesperados (AccionGen «${a.AccionGen}», Val_Priori «${a.Val_Priori}»). Revise el KMZ.`);
  const poligonos = [];
  for (const poli of p.matchAll(/<Polygon>([\s\S]*?)<\/Polygon>/g)) {
    const exterior = poli[1].match(/<outerBoundaryIs>[\s\S]*?<coordinates>([\s\S]*?)<\/coordinates>/);
    if (!exterior) continue;
    const huecos = [...poli[1].matchAll(/<innerBoundaryIs>[\s\S]*?<coordinates>([\s\S]*?)<\/coordinates>/g)].map((h) => anilloDe(h[1]));
    poligonos.push([anilloDe(exterior[1]), ...huecos]);
  }
  if (!poligonos.length) continue;
  const sector = sectorDe(poligonos.map((pol) => pol[0]));
  if (!sector) { descartados++; continue; }
  features.push({
    type: 'Feature',
    properties: {
      sector,
      accion,
      prioridad,
      unidad: a.NOMUH || null,
      subzona: a.NOMSZH || null,
      escenario: a.Escenari_1 || null,
      accion_regional: a.AccRegiona || null,
      figura: a.Descripcio || null,
      area_protegida: a.Zona || null,
    },
    geometry: { type: 'MultiPolygon', coordinates: poligonos },
  });
}

fs.mkdirSync(path.dirname(TEMPORAL), { recursive: true });
fs.mkdirSync(path.dirname(SALIDA), { recursive: true });
fs.writeFileSync(TEMPORAL, JSON.stringify({ type: 'FeatureCollection', features }));

// Simplificación que conserva la topología y las formas pequeñas.
const mapshaper = path.resolve(web, 'node_modules/mapshaper/bin/mapshaper');
execFileSync(process.execPath, [mapshaper, TEMPORAL, '-simplify', '8%', 'keep-shapes', '-o', 'format=geojson', 'precision=0.00001', `${SALIDA}`, 'force'], { stdio: 'inherit' });

// La simplificación puede colapsar polígonos diminutos a geometría nula: fuera.
const simplificada = JSON.parse(fs.readFileSync(SALIDA, 'utf8'));
const valida = (f) => f.geometry && Array.isArray(f.geometry.coordinates) && f.geometry.coordinates.length > 0;
const nulos = simplificada.features.filter((f) => !valida(f)).length;
simplificada.features = simplificada.features.filter(valida);
simplificada.name = 'prioridades_conservacion_cra_sectores_manglar';
simplificada.fuente = 'Capa «Prioridades de conservación» entregada por la C.R.A. (KMZ), recortada a los sectores del manglar y simplificada para la web.';
fs.writeFileSync(SALIDA, JSON.stringify(simplificada));

const resumen = {};
for (const f of simplificada.features) { const k = `${f.properties.sector}`; resumen[k] = (resumen[k] || 0) + 1; }
console.log(`Polígonos de la C.R.A. en los sectores del manglar: ${simplificada.features.length} (fuera de sectores: ${descartados}; colapsados al simplificar: ${nulos}).`);
console.log('Por sector:', resumen);
console.log(`Escrito ${path.relative(web, SALIDA)} (${(fs.statSync(SALIDA).size / 1048576).toFixed(2)} MB).`);
