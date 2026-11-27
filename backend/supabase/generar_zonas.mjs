// Genera zonas.sql a partir de app/assets/datos/manglar_zonas.json (fuente: INVEMAR 2020, provisional).
// Sin dependencias. Uso, desde cualquier carpeta:
//   node backend/supabase/generar_zonas.mjs
// Escribe backend/supabase/zonas.sql. Se puede volver a correr: el SQL es idempotente (upsert por id).
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const aqui = dirname(fileURLToPath(import.meta.url));
const entrada = join(aqui, '..', '..', 'app', 'assets', 'datos', 'manglar_zonas.json');
const salida = join(aqui, 'zonas.sql');

const datos = JSON.parse(readFileSync(entrada, 'utf8'));
if (!Array.isArray(datos.zonas) || datos.zonas.length === 0) {
  throw new Error('manglar_zonas.json no trae zonas');
}

// Quita puntos consecutivos repetidos y cierra el anillo (PostGIS lo exige cerrado).
function cerrar(anillo) {
  const a = [];
  for (const p of anillo) {
    const q = a[a.length - 1];
    if (!q || q[0] !== p[0] || q[1] !== p[1]) a.push([p[0], p[1]]);
  }
  const f = a[0];
  const u = a[a.length - 1];
  if (f && (f[0] !== u[0] || f[1] !== u[1])) a.push([f[0], f[1]]);
  return a;
}

const esc = (s) => String(s).split("'").join("''");
const lineas = [];
lineas.push('-- GENERADO por backend/supabase/generar_zonas.mjs desde app/assets/datos/manglar_zonas.json. No editar a mano.');
lineas.push(`-- Fuente: ${datos.fuente}${datos.provisional ? ' (PROVISIONAL: se valida con la CRA)' : ''}.`);
lineas.push('-- Correr DESPUÉS de schema.sql. Idempotente: si ya hay zonas, las actualiza.');
lineas.push('set search_path = public, extensions;');
lineas.push('');

let total = 0;
for (const z of datos.zonas) {
  const poligonos = [];
  for (const anillo of z.poligonos) {
    const c = cerrar(anillo);
    if (c.length >= 4) poligonos.push([c]); // un anillo exterior por polígono
  }
  if (poligonos.length === 0) throw new Error(`La zona ${z.id} no tiene polígonos válidos`);
  const geo = JSON.stringify({ type: 'MultiPolygon', coordinates: poligonos });
  // ST_MakeValid por si algún anillo se cruza; ST_CollectionExtract(…,3) deja solo polígonos.
  lineas.push('insert into public.zonas (id, nombre, municipio, prioridad_conservacion, geom)');
  lineas.push('values (');
  lineas.push(`  '${esc(z.id)}', '${esc(z.nombre)}', '${esc(z.municipio)}', ${Number(z.prioridadConservacion)},`);
  lineas.push(`  ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_SetSRID(ST_GeomFromGeoJSON($geo$${geo}$geo$), 4326)), 3))`);
  lineas.push(')');
  lineas.push('on conflict (id) do update set');
  lineas.push('  nombre = excluded.nombre, municipio = excluded.municipio,');
  lineas.push('  prioridad_conservacion = excluded.prioridad_conservacion, geom = excluded.geom;');
  lineas.push('');
  total++;
}

lineas.push('-- Comprobación: debe decir 4.');
lineas.push('select count(*) as zonas_cargadas from public.zonas;');
lineas.push('');

const texto = lineas.join('\n');
writeFileSync(salida, texto, 'utf8');
console.log(`zonas.sql escrito con ${total} zonas (${(texto.length / 1024).toFixed(0)} KB).`);
