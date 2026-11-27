// Genera zonas.sql y prioridades.sql a partir de los archivos de la app:
//   app/assets/datos/manglar_zonas.json   (manglar 1:5.000 de la CRA, 4 zonas)
//   app/assets/datos/prioridades_cra.json (prioridades de conservación de la CRA)
// Sin dependencias. Uso, desde cualquier carpeta:
//   node backend/supabase/generar_zonas.mjs
// Escribe backend/supabase/zonas.sql y backend/supabase/prioridades.sql. Se pueden volver a correr:
// el SQL es idempotente (zonas: upsert por id; prioridades: vacía la tabla y la vuelve a llenar).
//
// Los archivos de la app guardan cada anillo como enteros [x0, y0, dx1, dy1, ...] en unidades de
// 1/unidad grados y SIN repetir el primer punto; aquí se decodifican y se cierran (PostGIS lo exige).
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const aqui = dirname(fileURLToPath(import.meta.url));
const datosApp = join(aqui, '..', '..', 'app', 'assets', 'datos');
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

// ---------- zonas.sql ----------
const PUNTOS = { alta: 5, media: 4, baja: 3 };
const z = [];
z.push('-- GENERADO por backend/supabase/generar_zonas.mjs desde app/assets/datos/manglar_zonas.json. No editar a mano.');
z.push(`-- Fuente: ${manglar.fuente}. Imágenes: ${manglar.fechaDatos}. Generado: ${manglar.generado}.`);
z.push('-- Correr DESPUÉS de schema.sql. Idempotente: si ya hay zonas, las actualiza.');
z.push('-- prioridad_conservacion es DERIVADA (alta 5, media 4, baja 3) de la prioridad dominante de la CRA en la zona;');
z.push('-- la fuente de verdad por punto es la tabla prioridades_cra (prioridades.sql).');
z.push('set search_path = public, extensions;');
z.push('');
let totalHa = 0;
for (const zona of manglar.zonas) {
  const poligonos = zona.poligonos.map((p) => p.map((r) => anillo(r, manglar.unidad)));
  const prioridad = PUNTOS[zona.prioridadCra] ?? 3;
  totalHa += zona.areaHa;
  z.push(`-- ${zona.id}: sector CRA «${zona.sectorCra}», ${poligonos.length} polígonos, ${zona.areaHa} ha, prioridad dominante ${zona.prioridadCra}.`);
  z.push('insert into public.zonas (id, nombre, municipio, prioridad_conservacion, geom)');
  z.push('values (');
  z.push(`  '${esc(zona.id)}', '${esc(zona.nombre)}', '${esc(zona.municipio)}', ${prioridad},`);
  z.push(`  ${geomSql(poligonos)}`);
  z.push(')');
  z.push('on conflict (id) do update set');
  z.push('  nombre = excluded.nombre, municipio = excluded.municipio,');
  z.push('  prioridad_conservacion = excluded.prioridad_conservacion, geom = excluded.geom;');
  z.push('');
}
z.push('-- Comprobación: debe decir 4 zonas y ~649,7 ha en total.');
z.push('select count(*) as zonas_cargadas, round((sum(ST_Area(geog)) / 10000)::numeric, 1) as hectareas from public.zonas;');
z.push('');
const textoZonas = z.join('\n');
writeFileSync(join(aqui, 'zonas.sql'), textoZonas, 'utf8');

// ---------- prioridades.sql ----------
// Una fila por combinación (prioridad, acción, escenario, área protegida, unidad): su geometría es la
// unión de todos los polígonos de la capa con esos atributos (unos 450 inserts en vez de miles).
const grupos = new Map();
for (const [idx, anillos] of prior.poligonos) {
  if (!grupos.has(idx)) grupos.set(idx, []);
  grupos.get(idx).push(anillos.map((r) => anillo(r, prior.unidad)));
}
const p = [];
p.push('-- GENERADO por backend/supabase/generar_zonas.mjs desde app/assets/datos/prioridades_cra.json. No editar a mano.');
p.push(`-- Fuente: ${prior.fuente}. Generado: ${prior.generado}.`);
p.push('-- Correr DESPUÉS de schema.sql y zonas.sql. Idempotente: vacía prioridades_cra y la vuelve a llenar.');
p.push('-- Un punto está «fuera de la zonificación» si ningún polígono de esta tabla lo contiene; si lo contienen');
p.push('-- varios, vale el de prioridad más alta (misma regla que la app y la web).');
p.push('-- Es grande (~4 MB): pégalo por partes en el SQL Editor (cada insert es independiente) o usa');
p.push('--   psql "$SUPABASE_DB_URL" -f prioridades.sql');
p.push('set search_path = public, extensions;');
p.push('');
p.push('create table if not exists public.prioridades_cra (');
p.push('  id             bigint generated always as identity primary key,');
p.push("  prioridad      text not null check (prioridad in ('alta','media','baja')),");
p.push('  accion         text not null,                 -- Preservación, Restauración, Recuperación, Rehabilitación');
p.push('  escenario      text not null,                 -- Escenario I, Escenario III…');
p.push('  area_protegida text,                          -- p. ej. Palmar Titi; null si no está en un área protegida');
p.push('  unidad         text,                          -- unidad hidrográfica');
p.push('  geom           geometry(MultiPolygon, 4326) not null');
p.push(');');
p.push('create index if not exists prioridades_cra_geom_gix on public.prioridades_cra using gist (geom);');
p.push('');
p.push('alter table public.prioridades_cra enable row level security;');
p.push('revoke all on public.prioridades_cra from public, anon, authenticated;');
p.push('grant select on public.prioridades_cra to anon, authenticated;');
p.push('drop policy if exists prioridades_cra_lectura_publica on public.prioridades_cra;');
p.push('create policy prioridades_cra_lectura_publica on public.prioridades_cra for select to anon, authenticated using (true);');
p.push('');
p.push('delete from public.prioridades_cra;');
p.push('');
let filas = 0, vertices = 0;
for (const [idx, poligonos] of grupos) {
  const a = prior.atributos[idx];
  const nulo = (t) => (t ? `'${esc(t)}'` : 'null');
  for (const pol of poligonos) for (const r of pol) vertices += r.length;
  p.push('insert into public.prioridades_cra (prioridad, accion, escenario, area_protegida, unidad, geom)');
  p.push(`values ('${esc(a.p)}', '${esc(a.a)}', '${esc(a.e)}', ${nulo(a.z)}, ${nulo(a.u)},`);
  p.push(`  ${geomSql(poligonos)});`);
  filas++;
}
p.push('');
p.push(`-- Comprobación: debe decir ${filas} filas y ${prior.poligonos.length} polígonos.`);
p.push('select count(*) as filas, sum(ST_NumGeometries(geom)) as poligonos from public.prioridades_cra;');
p.push('');
const textoPrior = p.join('\n');
writeFileSync(join(aqui, 'prioridades.sql'), textoPrior, 'utf8');

console.log(`zonas.sql: ${manglar.zonas.length} zonas, ${totalHa.toFixed(2)} ha (${(textoZonas.length / 1048576).toFixed(2)} MB).`);
console.log(`prioridades.sql: ${filas} filas, ${prior.poligonos.length} polígonos, ${vertices} vértices (${(textoPrior.length / 1048576).toFixed(2)} MB).`);
