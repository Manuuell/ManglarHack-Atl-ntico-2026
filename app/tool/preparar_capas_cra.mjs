// Prepara las capas OFICIALES de la CRA para la app (sin conexión y sin dependencias):
//   1) assets/datos/manglar_zonas.json  - manglar a escala 1:5.000 agrupado en las 4 zonas de la CRA.
//   2) assets/datos/prioridades_cra.json - polígonos de «Prioridades de conservación» (alta/media/baja).
//
// Uso (desde app/):
//   node tool/preparar_capas_cra.mjs [manglar.geojson] [prioridades.kmz|.kml]
// Sin argumentos usa ../datos/cra/manglar_cra_escala_1-5000.geojson y
// ../datos/cra/prioridades_conservacion_cra.kmz (rama web; en main hay que traerlos con
// `git show origin/web:datos/cra/...`). El KMZ se abre con zlib de Node: no hace falta unzip.
//
// Formato de coordenadas: cada anillo es una lista plana de enteros en unidades de 1e-5 grados
// (~1,1 m): [x0, y0, dx1, dy1, ...] con el primero absoluto y el resto como diferencia con el
// punto anterior. El anillo va ABIERTO (el último punto no repite el primero). Orden: x = longitud,
// y = latitud.
import { readFileSync, writeFileSync } from 'node:fs';
import { inflateRawSync } from 'node:zlib';

const entradaManglar = process.argv[2] ?? '../datos/cra/manglar_cra_escala_1-5000.geojson';
const entradaPrioridades = process.argv[3] ?? '../datos/cra/prioridades_conservacion_cra.kmz';
const salidaManglar = 'assets/datos/manglar_zonas.json';
const salidaPrioridades = 'assets/datos/prioridades_cra.json';

// Tolerancias de Douglas-Peucker en metros. A zoom 17 un píxel mide ~1,2 m (256 px) o ~0,6 m
// (512 px): 1 m no se nota. La capa de prioridades es de planificación (unidades hidrográficas):
// admite más.
const TOL_MANGLAR_M = 1.0;
const TOL_PRIORIDADES_M = 2.5;
const MARGEN_RECORTE_M = 3000;
const UNIDAD = 1e5;

// Las 4 zonas que nombró la CRA. El id es el contrato común con el bot y el backend: NO cambiar.
// Se asignan por la longitud del centroide (la costa corre de noreste a suroeste). Los cortes caen
// en huecos de la capa y se verificaron contra los 4 sectores de la web (Mallorquín, Balboa,
// Manatíes, Totumo): ver el informe de esta tarea.
const ZONAS = [
  { id: 'mallorquin', sectorCra: 'Mallorquín', nombre: 'Ciénaga de Mallorquín', municipio: 'Barranquilla – Puerto Colombia', oesteDe: -74.94,
    nota: 'La mayor masa de manglar del departamento y la de más presión urbana.' },
  { id: 'tubara', sectorCra: 'Balboa', nombre: 'Costa de Tubará', municipio: 'Tubará', oesteDe: -75.059,
    nota: 'Manglares de borde en playas y desembocaduras de arroyos (Puerto Velero, Balboa).' },
  { id: 'juan_de_acosta', sectorCra: 'Manatíes', nombre: 'Costa de Juan de Acosta', municipio: 'Juan de Acosta', oesteDe: -75.148,
    nota: 'Parches pequeños cerca de Manatíes y Santa Verónica.' },
  { id: 'piojo', sectorCra: 'Totumo', nombre: 'Ciénaga del Totumo', municipio: 'Piojó', oesteDe: -999,
    nota: 'Límite con Bolívar; manglar de ciénaga muy sensible al agua dulce.' },
];
const PRIORIDADES = { Alto: 'alta', Medio: 'media', Bajo: 'baja' };
const RANGO = { alta: 3, media: 2, baja: 1 };
const A_PUNTOS = { alta: 5, media: 4, baja: 3 };

// ---------- geometría ----------
const LAT0 = 10.9;
const KX = 111320 * Math.cos((LAT0 * Math.PI) / 180);
const KY = 110574;
const aMetros = ([lon, lat]) => [lon * KX, lat * KY];

function distSeg(p, a, b) {
  const dx = b[0] - a[0], dy = b[1] - a[1];
  const l2 = dx * dx + dy * dy;
  let t = l2 === 0 ? 0 : ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy));
}

/** Douglas-Peucker iterativo sobre un camino abierto; devuelve los índices que se conservan. */
function dpCamino(m, tol) {
  const n = m.length;
  const keep = new Uint8Array(n);
  keep[0] = keep[n - 1] = 1;
  const pila = [[0, n - 1]];
  while (pila.length) {
    const [i, j] = pila.pop();
    let mejor = -1, d = tol;
    for (let k = i + 1; k < j; k++) {
      const dk = distSeg(m[k], m[i], m[j]);
      if (dk > d) { d = dk; mejor = k; }
    }
    if (mejor >= 0) { keep[mejor] = 1; pila.push([i, mejor], [mejor, j]); }
  }
  return keep;
}

/** Simplifica un anillo (sin repetir el primer punto): lo parte en el vértice más lejano al
 *  primero para que Douglas-Peucker no vea un segmento degenerado. */
function simplificarAnillo(pts, tol) {
  const n = pts.length;
  if (n <= 4) return pts;
  const m = pts.map(aMetros);
  let k = 0, dmax = -1;
  for (let i = 1; i < n; i++) {
    const d = Math.hypot(m[i][0] - m[0][0], m[i][1] - m[0][1]);
    if (d > dmax) { dmax = d; k = i; }
  }
  const a = m.slice(0, k + 1), b = [...m.slice(k), m[0]];
  const ka = dpCamino(a, tol), kb = dpCamino(b, tol);
  const salida = [];
  for (let i = 0; i <= k; i++) if (ka[i]) salida.push(pts[i]);
  for (let i = 1; i < b.length - 1; i++) if (kb[i]) salida.push(pts[k + i]);
  return salida;
}

const area2 = (r) => {
  let s = 0;
  for (let i = 0, j = r.length - 1; i < r.length; j = i++) s += r[j][0] * r[i][1] - r[i][0] * r[j][1];
  return s / 2;
};

/** Redondea a 1e-5, quita repetidos y el punto de cierre; null si el anillo se degenera. */
function limpiar(pts, areaMinM2) {
  const q = [];
  for (const [x, y] of pts) {
    const p = [Math.round(x * UNIDAD), Math.round(y * UNIDAD)];
    const u = q[q.length - 1];
    if (!u || u[0] !== p[0] || u[1] !== p[1]) q.push(p);
  }
  while (q.length > 1 && q[0][0] === q[q.length - 1][0] && q[0][1] === q[q.length - 1][1]) q.pop();
  if (q.length < 3) return null;
  const m = q.map(([x, y]) => aMetros([x / UNIDAD, y / UNIDAD]));
  if (Math.abs(area2(m)) < areaMinM2) return null;
  return q;
}

const codificar = (q) => {
  const r = [q[0][0], q[0][1]];
  for (let i = 1; i < q.length; i++) r.push(q[i][0] - q[i - 1][0], q[i][1] - q[i - 1][1]);
  return r;
};

/** Sutherland-Hodgman contra una caja [minX,minY,maxX,maxY]. */
function recortarAnillo(r, [x0, y0, x1, y1]) {
  const bordes = [
    [(p) => p[0] >= x0, (a, b) => [x0, a[1] + ((b[1] - a[1]) * (x0 - a[0])) / (b[0] - a[0])]],
    [(p) => p[0] <= x1, (a, b) => [x1, a[1] + ((b[1] - a[1]) * (x1 - a[0])) / (b[0] - a[0])]],
    [(p) => p[1] >= y0, (a, b) => [a[0] + ((b[0] - a[0]) * (y0 - a[1])) / (b[1] - a[1]), y0]],
    [(p) => p[1] <= y1, (a, b) => [a[0] + ((b[0] - a[0]) * (y1 - a[1])) / (b[1] - a[1]), y1]],
  ];
  let sal = r;
  for (const [dentro, cruce] of bordes) {
    const ent = sal;
    sal = [];
    for (let i = 0; i < ent.length; i++) {
      const a = ent[i], b = ent[(i + 1) % ent.length];
      const da = dentro(a), db = dentro(b);
      if (da) sal.push(a);
      if (da !== db) sal.push(cruce(a, b));
    }
    if (!sal.length) return [];
  }
  return sal;
}

const caja = (r) => {
  let a = 1e9, b = 1e9, c = -1e9, d = -1e9;
  for (const [x, y] of r) { a = Math.min(a, x); b = Math.min(b, y); c = Math.max(c, x); d = Math.max(d, y); }
  return [a, b, c, d];
};

function enAnillo(x, y, r) {
  let dentro = false;
  for (let i = 0, j = r.length - 1; i < r.length; j = i++) {
    const xi = r[i][0], yi = r[i][1], xj = r[j][0], yj = r[j][1];
    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) dentro = !dentro;
  }
  return dentro;
}

// ---------- zip mínimo (KMZ) ----------
function leerKmz(ruta) {
  const buf = readFileSync(ruta);
  if (ruta.toLowerCase().endsWith('.kml')) return buf.toString('utf8');
  let eocd = -1;
  for (let i = buf.length - 22; i >= 0; i--) if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  if (eocd < 0) throw new Error('El KMZ no es un zip válido.');
  const n = buf.readUInt16LE(eocd + 10);
  let p = buf.readUInt32LE(eocd + 16);
  for (let e = 0; e < n; e++) {
    if (buf.readUInt32LE(p) !== 0x02014b50) throw new Error('Directorio central del zip dañado.');
    const metodo = buf.readUInt16LE(p + 10), csize = buf.readUInt32LE(p + 20);
    const nl = buf.readUInt16LE(p + 28), el = buf.readUInt16LE(p + 30), cl = buf.readUInt16LE(p + 32);
    const off = buf.readUInt32LE(p + 42);
    const nombre = buf.toString('utf8', p + 46, p + 46 + nl);
    p += 46 + nl + el + cl;
    if (!nombre.toLowerCase().endsWith('.kml')) continue;
    const ini = off + 30 + buf.readUInt16LE(off + 26) + buf.readUInt16LE(off + 28);
    const datos = buf.subarray(ini, ini + csize);
    return (metodo === 8 ? inflateRawSync(datos) : datos).toString('utf8');
  }
  throw new Error('El KMZ no contiene ningún .kml.');
}

// ---------- manglar 1:5.000 ----------
const geo = JSON.parse(readFileSync(entradaManglar, 'utf8'));
const zonas = ZONAS.map(({ oesteDe, ...z }) => ({ ...z, areaHa: 0, poligonosOriginales: 0, vertOriginales: 0, poligonos: [], _cent: [] }));
let vertManglar = 0, vertManglarOrig = 0;
const fechas = [];
const cajaManglar = [1e9, 1e9, -1e9, -1e9];
for (const f of geo.features) {
  if (f.properties.fecha) fechas.push(f.properties.fecha);
  const partes = f.geometry.type === 'Polygon' ? [f.geometry.coordinates] : f.geometry.coordinates;
  for (const poli of partes) {
    const ex = poli[0];
    const cx = ex.reduce((s, p) => s + p[0], 0) / ex.length;
    const cy = ex.reduce((s, p) => s + p[1], 0) / ex.length;
    const z = zonas[ZONAS.findIndex((q) => cx > q.oesteDe)];
    z.areaHa += (f.properties.area_ha ?? 0) / partes.length;
    z.poligonosOriginales++;
    for (const anillo of poli) { vertManglarOrig += anillo.length - 1; z.vertOriginales += anillo.length - 1; }
    // Si el anillo exterior se degeneró, el polígono se descarta (con sus huecos).
    const ext = limpiar(simplificarAnillo(poli[0].slice(0, -1), TOL_MANGLAR_M), 0.5);
    if (!ext) continue;
    const huecos = poli.slice(1).map((h) => limpiar(simplificarAnillo(h.slice(0, -1), TOL_MANGLAR_M), 0.5)).filter(Boolean);
    const todos = [ext, ...huecos];
    vertManglar += todos.reduce((s, r) => s + r.length, 0);
    z.poligonos.push(todos.map(codificar));
    z._cent.push({ x: cx, y: cy, ha: f.properties.area_ha ?? 0, ext });
    for (const [x, y] of ex) {
      cajaManglar[0] = Math.min(cajaManglar[0], x); cajaManglar[1] = Math.min(cajaManglar[1], y);
      cajaManglar[2] = Math.max(cajaManglar[2], x); cajaManglar[3] = Math.max(cajaManglar[3], y);
    }
  }
}

// ---------- prioridades de conservación ----------
const margenLat = MARGEN_RECORTE_M / KY;
const margenLon = MARGEN_RECORTE_M / KX;
const cajaRecorte = [cajaManglar[0] - margenLon, cajaManglar[1] - margenLat, cajaManglar[2] + margenLon, cajaManglar[3] + margenLat];
const kml = leerKmz(entradaPrioridades);
const placemarks = kml.split('<Placemark').slice(1);
if (!placemarks.length) throw new Error('El KML no tiene elementos <Placemark>.');
const decodificarEntidades = (s) => s.replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'");
const atributos = [];
const indiceAtributo = new Map();
const poligonosPrior = [];
let totalPlacemarks = 0, fuera = 0, vertPriorOrig = 0, vertPrior = 0;
const conteoPrioridad = { alta: 0, media: 0, baja: 0 };
for (const p of placemarks) {
  totalPlacemarks++;
  const a = {};
  for (const m of p.matchAll(/<td>([^<]+)<\/td>\s*<td>([^<]*)<\/td>/g)) a[m[1]] = decodificarEntidades(m[2].trim());
  const prioridad = PRIORIDADES[a.Val_Priori];
  if (!prioridad || !a.AccionGen) throw new Error(`Atributos inesperados (Val_Priori «${a.Val_Priori}», AccionGen «${a.AccionGen}»). Revise el KMZ.`);
  const attr = {
    p: prioridad,
    a: a.AccionGen,
    e: a.Escenari_1 || a.Escenarios || '',
    f: a.Descripcio || '',
    z: a.Zona || a.NOM_APC || '',
    u: a.NOMUH || '',
  };
  const clave = JSON.stringify(attr);
  let idx = indiceAtributo.get(clave);
  let usado = false;
  for (const poli of p.matchAll(/<Polygon>([\s\S]*?)<\/Polygon>/g)) {
    const anillos = [...poli[1].matchAll(/<coordinates>([\s\S]*?)<\/coordinates>/g)].map((m) =>
      m[1].trim().split(/\s+/).map((t) => t.split(',').slice(0, 2).map(Number)),
    );
    if (!anillos.length) continue;
    vertPriorOrig += anillos.reduce((s, r) => s + r.length, 0);
    const cb = caja(anillos[0]);
    if (cb[2] < cajaRecorte[0] || cb[0] > cajaRecorte[2] || cb[3] < cajaRecorte[1] || cb[1] > cajaRecorte[3]) { fuera++; continue; }
    const dentroTotal = cb[0] >= cajaRecorte[0] && cb[1] >= cajaRecorte[1] && cb[2] <= cajaRecorte[2] && cb[3] <= cajaRecorte[3];
    // El primer anillo debe ser el exterior: si se degeneró, se descarta el polígono.
    const ext = anillos[0];
    const extOk = limpiar(simplificarAnillo(dentroTotal ? ext.slice(0, -1) : recortarAnillo(ext.slice(0, -1), cajaRecorte), TOL_PRIORIDADES_M), 2);
    if (!extOk) continue;
    const huecos = anillos.slice(1).map((r) => {
      const ab = dentroTotal ? r.slice(0, -1) : recortarAnillo(r.slice(0, -1), cajaRecorte);
      return ab.length < 3 ? null : limpiar(simplificarAnillo(ab, TOL_PRIORIDADES_M), 2);
    }).filter(Boolean);
    if (idx === undefined) { idx = atributos.length; atributos.push(attr); indiceAtributo.set(clave, idx); }
    const todos = [extOk, ...huecos];
    vertPrior += todos.reduce((s, r) => s + r.length, 0);
    poligonosPrior.push({ idx, rings: todos });
    usado = true;
  }
  if (usado) conteoPrioridad[prioridad]++;
}

// ---------- prioridad dominante por zona (por hectáreas de manglar con centroide dentro) ----------
const aGrados = (q) => q.map(([x, y]) => [x / UNIDAD, y / UNIDAD]);
const polisPrior = poligonosPrior.map((p) => ({ ...p, ext: aGrados(p.rings[0]), huecos: p.rings.slice(1).map(aGrados) }));
for (const p of polisPrior) p.caja = caja(p.ext);
function prioridadEn(x, y) {
  let mejor = null;
  for (const p of polisPrior) {
    const c = p.caja;
    if (x < c[0] || x > c[2] || y < c[1] || y > c[3]) continue;
    if (enAnillo(x, y, p.ext) && !p.huecos.some((h) => enAnillo(x, y, h))) {
      const pr = atributos[p.idx].p;
      if (!mejor || RANGO[pr] > RANGO[mejor]) mejor = pr;
    }
  }
  return mejor;
}
let centroidesFuera = 0, centroidesTotal = 0;
const porZona = {};
for (const z of zonas) {
  const ha = { alta: 0, media: 0, baja: 0 };
  let fz = 0;
  for (const c of z._cent) {
    centroidesTotal++;
    // El centroide del anillo simplificado cae en la misma zona; se usa un punto interior sencillo:
    const pr = prioridadEn(c.x, c.y);
    if (!pr) { fz++; centroidesFuera++; } else ha[pr] += c.ha;
  }
  porZona[z.id] = { ha, fuera: fz };
}

for (const z of zonas) {
  z.areaHa = Math.round(z.areaHa * 100) / 100;
  const h = porZona[z.id].ha;
  const dom = Object.keys(h).sort((a, b) => h[b] - h[a] || RANGO[b] - RANGO[a])[0];
  z.prioridadCra = h[dom] > 0 ? dom : null;
  z.prioridadConservacion = A_PUNTOS[z.prioridadCra] ?? 3;
  z.poligonosCount = z.poligonos.length;
  delete z._cent;
  delete z.poligonosOriginales;
  delete z.vertOriginales;
}
const areaTotalHa = Math.round(zonas.reduce((s, z) => s + z.areaHa, 0) * 100) / 100;
const fechasOrd = fechas.sort();
const hoy = new Date().toISOString().slice(0, 10);

writeFileSync(
  salidaManglar,
  JSON.stringify({
    version: 2,
    fuente: 'Cobertura de manglar del Atlántico, C.R.A., escala 1:5.000 (imágenes Maxar 2021-2022, verificación en campo)',
    fechaDatos: `${fechasOrd[0]} a ${fechasOrd[fechasOrd.length - 1]}`,
    generado: hoy,
    provisional: false,
    unidad: UNIDAD,
    areaTotalHa,
    zonas: zonas.map(({ poligonosCount, ...z }) => z),
  }),
);
writeFileSync(
  salidaPrioridades,
  JSON.stringify({
    version: 1,
    fuente: 'Capa «Prioridades de conservación» de la C.R.A. (KMZ), recortada a la costa del manglar y simplificada',
    generado: hoy,
    unidad: UNIDAD,
    cajaRecorte: cajaRecorte.map((v) => Math.round(v * UNIDAD) / UNIDAD),
    atributos,
    poligonos: poligonosPrior.map((p) => [p.idx, p.rings.map(codificar)]),
  }),
);

const kb = (f) => (readFileSync(f).length / 1048576).toFixed(2) + ' MB';
console.log(zonas.map((z) => `${z.id} (${z.sectorCra}): ${z.poligonos.length} polígonos, ${z.areaHa} ha, prioridad dominante ${z.prioridadCra}, centroides fuera de la zonificación ${porZona[z.id].fuera}`).join('\n'));
console.log(`manglar: ${vertManglarOrig} -> ${vertManglar} vértices, ${areaTotalHa} ha, ${kb(salidaManglar)}`);
console.log(`prioridades: ${totalPlacemarks} placemarks, ${polisPrior.length} polígonos tras recorte (${fuera} fuera de la caja), ${vertPriorOrig} -> ${vertPrior} vértices, ${atributos.length} combinaciones de atributos, ${kb(salidaPrioridades)}`);
console.log(`centroides de manglar fuera de la zonificación: ${centroidesFuera} de ${centroidesTotal} (capa simplificada)`);
