// Genera zonas-N.sql y prioridades-N.sql a partir de los archivos de la app:
//   app/assets/datos/manglar_zonas.json   (manglar 1:5.000 de la CRA, 4 zonas)
//   app/assets/datos/prioridades_cra.json (prioridades de conservación de la CRA)
// Sin dependencias. Uso, desde cualquier carpeta:
//   node backend/supabase/generar_zonas.mjs
// Escribe backend/supabase/zonas-1.sql, zonas-2.sql... y prioridades-1.sql, prioridades-2.sql... en partes
// de a lo más 900 KB (el SQL Editor de Supabase no traga archivos más grandes). Se pegan una tras otra, en
// orden. Cada parte es SQL válido por sí sola. Se pueden volver a correr: el SQL es idempotente (zonas:
// upsert por id; prioridades: la parte 1 vacía la tabla y las demás solo insertan).
// Borra las partes viejas (y los zonas.sql / prioridades.sql de una sola pieza) antes de escribir.
//
// Los archivos de la app guardan cada anillo como enteros [x0, y0, dx1, dy1, ...] en unidades de
// 1/unidad grados y SIN repetir el primer punto; aquí se decodifican y se cierran (PostGIS lo exige).
import { readdirSync, readFileSync, unlinkSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const aqui = dirname(fileURLToPath(import.meta.url));
const datosApp = join(aqui, '..', '..', 'app', 'assets', 'datos');
const MAX_BYTES = 900 * 1000; // por archivo, bajo el límite de ~900 KB que aguanta el editor
const bytes = (t) => Buffer.byteLength(t, 'utf8');
/** Reparte bloques (cada uno entero, nunca partido) en archivos de a lo más MAX_BYTES; cabecera(n) es el encabezado de la parte n. */
function empaquetar(bloques, cabecera) {
  const partes = [];
  let actual = [], peso = 0;
  for (const b of bloques) {
    const n = partes.length + 1;
    const base = bytes(cabecera(n)) + 400; // 400 B de margen para el pie
    if (base + bytes(b) > MAX_BYTES) throw new Error('Un bloque solo pesa más de 900 KB: toca partir su geometría.');
    if (actual.length && base + peso + bytes(b) > MAX_BYTES) { partes.push(actual); actual = []; peso = 0; }
    actual.push(b);
    peso += bytes(b) + 1;
  }
  if (actual.length) partes.push(actual);
  return partes;
}
for (const f of readdirSync(aqui)) if (/^(zonas|prioridades)(-\d+)?\.sql$/.test(f)) unlinkSync(join(aqui, f));

const manglar = JSON.parse(readFileSync(join(datosApp, 'manglar_zonas.json'), 'utf8'));
const prior = JSON.parse(readFileSync(join(datosApp, 'prioridades_cra.json'), 'utf8'));
if (!Array.isArray(manglar.zonas) || manglar.zonas.length === 0) throw new Error('manglar_zonas.json no trae zonas');
if (!Array.isArray(prior.poligonos) || prior.poligonos.length === 0) throw new Error('prioridades_cra.json no trae polígonos');

/** [x0, y0, dx, dy, ...] -> anillo cerrado [[lon, lat], ...] con 5 decimales. */
function anillo(r, unidad) {
  const pts = [];
  let x = 0, y = 0;
  for (let i = 0; i < r.length; i += 2) {
    x += r[i];
    y += r[i + 1];
    pts.push([Number((x / unidad).toFixed(5)), Number((y / unidad).toFixed(5))]);
  }
  pts.push([pts[0][0], pts[0][1]]);
  return pts;
}

const esc = (s) => String(s).split("'").join("''");
const geomSql = (poligonos) =>
  // ST_MakeValid por si algún anillo se cruza; ST_CollectionExtract(…,3) deja solo polígonos.
  `ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_SetSRID(ST_GeomFromGeoJSON($geo$${JSON.stringify({ type: 'MultiPolygon', coordinates: poligonos })}$geo$), 4326)), 3))`;

// ---------- zonas-N.sql ----------
const PUNTOS = { alta: 5, media: 4, baja: 3 };
let totalHa = 0;
const bloquesZona = [];
for (const zona of manglar.zonas) {
  const poligonos = zona.poligonos.map((p) => p.map((r) => anillo(r, manglar.unidad)));
  const prioridad = PUNTOS[zona.prioridadCra] ?? 3;
  totalHa += zona.areaHa;
  bloquesZona.push([
    `-- ${zona.id}: sector CRA «${zona.sectorCra}», ${poligonos.length} polígonos, ${zona.areaHa} ha, prioridad dominante ${zona.prioridadCra}.`,
    'insert into public.zonas (id, nombre, municipio, prioridad_conservacion, geom)',
    'values (',
    `  '${esc(zona.id)}', '${esc(zona.nombre)}', '${esc(zona.municipio)}', ${prioridad},`,
    `  ${geomSql(poligonos)}`,
    ')',
    'on conflict (id) do update set',
    '  nombre = excluded.nombre, municipio = excluded.municipio,',
    '  prioridad_conservacion = excluded.prioridad_conservacion, geom = excluded.geom;',
    '',
  ].join('\n'));
}
const cabeceraZonas = (n, total = '?') => [
  '-- GENERADO por backend/supabase/generar_zonas.mjs desde app/assets/datos/manglar_zonas.json. No editar a mano.',
  `-- PARTE ${n} de ${total}. Pega todas las partes de zonas-N.sql, una tras otra y en orden, DESPUÉS de schema.sql.`,
  `-- Fuente: ${manglar.fuente}. Imágenes: ${manglar.fechaDatos}. Generado: ${manglar.generado}.`,
  '-- Idempotente: si ya hay zonas, las actualiza. Cada parte es SQL válido por sí sola.',
  '-- prioridad_conservacion es DERIVADA (alta 5, media 4, baja 3) de la prioridad dominante de la CRA en la zona;',
  '-- la fuente de verdad por punto es la tabla prioridades_cra (prioridades-N.sql).',
  'set search_path = public, extensions;',
  '',
].join('\n');
const partesZonas = empaquetar(bloquesZona, cabeceraZonas);
const pesosZonas = [];
partesZonas.forEach((bl, i) => {
  const ultima = i === partesZonas.length - 1;
  const texto = cabeceraZonas(i + 1, partesZonas.length) + bl.join('\n') + '\n' + (ultima
    ? `-- Comprobación (parte final): debe decir ${manglar.zonas.length} zonas y ~${manglar.areaTotalHa} ha en total.\n` +
      'select count(*) as zonas_cargadas, round((sum(ST_Area(geog)) / 10000)::numeric, 1) as hectareas from public.zonas;\n'
    : '-- (sigue en la parte siguiente)\n');
  writeFileSync(join(aqui, `zonas-${i + 1}.sql`), texto, 'utf8');
  pesosZonas.push(`zonas-${i + 1}.sql ${(bytes(texto) / 1000).toFixed(0)} KB`);
});

// ---------- prioridades-N.sql ----------
// Una fila por combinación (prioridad, acción, escenario, área protegida, unidad): su geometría es la
// unión de todos los polígonos de la capa con esos atributos (unos 450 inserts en vez de miles).
const grupos = new Map();
for (const [idx, anillos] of prior.poligonos) {
  if (!grupos.has(idx)) grupos.set(idx, []);
  grupos.get(idx).push(anillos.map((r) => anillo(r, prior.unidad)));
}
let filas = 0, vertices = 0;
const bloquesPrior = [];
for (const [idx, poligonos] of grupos) {
  const a = prior.atributos[idx];
  const nulo = (t) => (t ? `'${esc(t)}'` : 'null');
  for (const pol of poligonos) for (const r of pol) vertices += r.length;
  bloquesPrior.push([
    'insert into public.prioridades_cra (prioridad, accion, escenario, area_protegida, unidad, geom)',
    `values ('${esc(a.p)}', '${esc(a.a)}', '${esc(a.e)}', ${nulo(a.z)}, ${nulo(a.u)},`,
    `  ${geomSql(poligonos)});`,
    '',
  ].join('\n'));
  filas++;
}
// Misma estructura que schema.sql (create table if not exists: da igual cuál de los dos corra primero).
const crearTabla = [
  'create table if not exists public.prioridades_cra (',
  '  id             bigint generated always as identity primary key,',
  "  prioridad      text not null check (prioridad in ('alta','media','baja')),",
  '  accion         text not null,                 -- Preservación, Restauración, Recuperación, Rehabilitación',
  '  escenario      text not null,                 -- Escenario I, Escenario III…',
  '  area_protegida text,                          -- p. ej. Palmar Titi; null si no está en un área protegida',
  '  unidad         text,                          -- unidad hidrográfica',
  '  geom           geometry(MultiPolygon, 4326) not null',
  ');',
  'create index if not exists prioridades_cra_geom_gix on public.prioridades_cra using gist (geom);',
  '',
  'alter table public.prioridades_cra enable row level security;',
  'revoke all on public.prioridades_cra from public, anon, authenticated;',
  'grant select on public.prioridades_cra to anon, authenticated;',
  'drop policy if exists prioridades_cra_lectura_publica on public.prioridades_cra;',
  'create policy prioridades_cra_lectura_publica on public.prioridades_cra for select to anon, authenticated using (true);',
  '',
  '-- Vacía la tabla: esta parte 1 es la que reinicia la carga. Las demás solo insertan.',
  'delete from public.prioridades_cra;',
  '',
].join('\n');
const cabeceraPrior = (n, total = '?') => [
  '-- GENERADO por backend/supabase/generar_zonas.mjs desde app/assets/datos/prioridades_cra.json. No editar a mano.',
  `-- PARTE ${n} de ${total}. Pega todas las partes de prioridades-N.sql, una tras otra y en orden, DESPUÉS de schema.sql y zonas-N.sql.`,
  `-- Fuente: ${prior.fuente}. Generado: ${prior.generado}.`,
  n === 1 ? '-- La parte 1 crea la tabla (si no existe) y la vacía; si repites la carga, empieza SIEMPRE por la 1.'
          : '-- Esta parte solo inserta; la tabla la crea y vacía la parte 1 (schema.sql también la crea, vacía).',
  '-- Un punto está «fuera de la zonificación» si ningún polígono de esta tabla lo contiene; si lo contienen',
  '-- varios, vale el de prioridad más alta (misma regla que la app y la web).',
  'set search_path = public, extensions;',
  '',
].join('\n') + (n === 1 ? crearTabla : '');
const partesPrior = empaquetar(bloquesPrior, cabeceraPrior);
const pesosPrior = [];
partesPrior.forEach((bl, i) => {
  const ultima = i === partesPrior.length - 1;
  const texto = cabeceraPrior(i + 1, partesPrior.length) + bl.join('\n') + '\n' + (ultima
    ? `-- Comprobación (parte final): debe decir ${filas} filas y ${prior.poligonos.length} polígonos.\n` +
      'select count(*) as filas, sum(ST_NumGeometries(geom)) as poligonos from public.prioridades_cra;\n'
    : '-- (sigue en la parte siguiente)\n');
  writeFileSync(join(aqui, `prioridades-${i + 1}.sql`), texto, 'utf8');
  pesosPrior.push(`prioridades-${i + 1}.sql ${(bytes(texto) / 1000).toFixed(0)} KB`);
});

console.log(`zonas: ${manglar.zonas.length} zonas, ${totalHa.toFixed(2)} ha en ${partesZonas.length} partes: ${pesosZonas.join(', ')}.`);
console.log(`prioridades: ${filas} filas, ${prior.poligonos.length} polígonos, ${vertices} vértices en ${partesPrior.length} partes: ${pesosPrior.join(', ')}.`);
