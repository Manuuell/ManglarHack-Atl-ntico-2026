// Convierte la capa de manglares (GeoJSON) en el archivo compacto que usa la app sin conexión.
//
// Uso (desde app/):  node tool/preparar_zonas.mjs [entrada.geojson]
// Sin argumento usa ../datos/manglares_atlantico_invemar_2020.geojson.
// Cuando llegue el KMZ de la CRA: convertirlo a GeoJSON y pasarlo como argumento.
//
// La capa de INVEMAR no trae municipio, así que cada polígono se asigna a una de las
// cuatro zonas que nombró la CRA según la longitud de su centroide (la costa del
// Atlántico corre de noreste a suroeste, así que la longitud ordena las zonas).
import { readFileSync, writeFileSync } from 'node:fs';

const entrada = process.argv[2] ?? '../datos/manglares_atlantico_invemar_2020.geojson';
const salida = 'assets/datos/manglar_zonas.json';

// Cortes por longitud, revisados contra el mapa (OpenStreetMap) el 27-11-2026.
// `prioridadConservacion` es PROVISIONAL (1-5): se valida con los mentores ambientales.
const ZONAS = [
  {
    id: 'mallorquin',
    nombre: 'Ciénaga de Mallorquín',
    municipio: 'Barranquilla – Puerto Colombia',
    oesteDe: -75.0,
    prioridadConservacion: 5,
    nota: 'La mayor masa de manglar del departamento y la de más presión urbana.',
  },
  {
    id: 'tubara',
    nombre: 'Costa de Tubará',
    municipio: 'Tubará',
    oesteDe: -75.06,
    prioridadConservacion: 4,
    nota: 'Manglares de borde en playas y desembocaduras de arroyos.',
  },
  {
    id: 'juan_de_acosta',
    nombre: 'Costa de Juan de Acosta',
    municipio: 'Juan de Acosta',
    oesteDe: -75.16,
    prioridadConservacion: 4,
    nota: 'Parches pequeños cerca de Santa Verónica y Salinas del Rey.',
  },
  {
    id: 'piojo',
    nombre: 'Ciénaga del Totumo',
    municipio: 'Piojó',
    oesteDe: -999,
    prioridadConservacion: 5,
    nota: 'Límite con Bolívar; manglar de ciénaga muy sensible al agua dulce.',
  },
];

const r6 = (n) => Math.round(n * 1e6) / 1e6;
const geo = JSON.parse(readFileSync(entrada, 'utf8'));
const zonas = ZONAS.map(({ oesteDe, ...z }) => ({ ...z, areaHa: 0, poligonos: [] }));

for (const f of geo.features) {
  const anillos =
    f.geometry.type === 'Polygon' ? [f.geometry.coordinates] : f.geometry.coordinates;
  for (const poli of anillos) {
    const exterior = poli[0];
    const lon = exterior.reduce((s, p) => s + p[0], 0) / exterior.length;
    const i = ZONAS.findIndex((z) => lon > z.oesteDe);
    const z = zonas[i];
    z.areaHa += f.properties?.AREA_HA ?? 0;
    // [lon, lat] redondeado a ~10 cm; solo el anillo exterior (la capa no tiene huecos útiles).
    z.poligonos.push(exterior.map(([x, y]) => [r6(x), r6(y)]));
  }
}

for (const z of zonas) z.areaHa = Math.round(z.areaHa * 10) / 10;
const total = zonas.reduce((s, z) => s + z.areaHa, 0);
writeFileSync(
  salida,
  JSON.stringify({
    fuente: 'Capa Nacional de Manglares, INVEMAR (2020, 1:25.000), filtrada al Atlántico',
    provisional: true,
    areaTotalHa: Math.round(total * 10) / 10,
    zonas,
  }),
);
console.log(zonas.map((z) => `${z.id}: ${z.poligonos.length} polígonos, ${z.areaHa} ha`).join('\n'));
console.log(`total ${total.toFixed(1)} ha -> ${salida}`);
