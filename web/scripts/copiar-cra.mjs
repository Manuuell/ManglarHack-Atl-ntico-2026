#!/usr/bin/env node
// Copia los datos del workflow de la C.R.A. (manglarcra.netlify.app) para que
// la web los lea desde su propio dominio: el sitio de la C.R.A. no permite que
// otro dominio lea sus datos desde el navegador.
//
//   node scripts/copiar-cra.mjs                       → public/cra (desarrollo y build)
//   node scripts/copiar-cra.mjs /var/www/mimanglar/cra → copia publicada (temporizador del VPS)
//   --suave                                           → avisa pero nunca falla (para el build)
//
// Solo baja lo que cambió (ETag) y nunca deja una copia a medias: si core.json
// llega roto o el sitio no responde, se queda la última copia buena. Escribe
// espejo.json con la fecha de revisión, que la web muestra junto a las cifras.
// Solo usa módulos de Node (≥ 20), para correr igual en el VPS.

import { createHash } from 'node:crypto';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';

const ORIGEN = 'https://manglarcra.netlify.app/';
const args = process.argv.slice(2);
const suave = args.includes('--suave');
const destino = resolve(args.find((a) => !a.startsWith('--')) ?? 'public/cra');
const MAX_ARCHIVO = 25 * 1024 * 1024;
const MAX_TOTAL = 150 * 1024 * 1024;
// Las rutas salen de core.json, que viene de fuera: solo se aceptan rutas
// relativas simples a imágenes y audio, sin «..», para no escribir fuera de destino.
const RUTA_SEGURA = /^(?:img|audio)\/[a-z0-9_-]+(?:\/[a-z0-9_-]+)*\.(?:png|jpe?g|webp|mp3)$/i;

const sha256 = (buf) => createHash('sha256').update(buf).digest('hex');
const ahora = () => new Date().toISOString();

async function leerJSON(ruta) {
  try { return JSON.parse(await readFile(ruta, 'utf8')); } catch { return null; }
}
async function hashLocal(ruta) {
  try { return sha256(await readFile(ruta)); } catch { return null; }
}
async function escribir(ruta, buf) {
  await mkdir(dirname(ruta), { recursive: true });
  const temporal = `${ruta}.${process.pid}.tmp`;
  await writeFile(temporal, buf);
  await rename(temporal, ruta);
}

async function bajar(ruta, previo) {
  const local = join(destino, ruta);
  const intacto = previo?.sha256 && (await hashLocal(local)) === previo.sha256;
  const r = await fetch(new URL(ruta, ORIGEN), {
    headers: intacto && previo.etag ? { 'If-None-Match': previo.etag } : {},
    signal: AbortSignal.timeout(60_000),
  });
  if (r.status === 304) return { cambio: false, info: previo };
  if (!r.ok) throw new Error(`${ruta}: HTTP ${r.status}`);
  const largo = Number(r.headers.get('content-length') ?? 0);
  if (largo > MAX_ARCHIVO) throw new Error(`${ruta}: pesa ${largo} bytes, más del máximo`);
  const buf = Buffer.from(await r.arrayBuffer());
  if (buf.length > MAX_ARCHIVO) throw new Error(`${ruta}: pesa ${buf.length} bytes, más del máximo`);
  const hash = sha256(buf);
  const info = { etag: r.headers.get('etag'), sha256: hash, bytes: buf.length };
  if (intacto && hash === previo.sha256) return { cambio: false, info };
  return { cambio: true, info, buf };
}

const numero = (v) => typeof v === 'number' && Number.isFinite(v);
// Lo mínimo que la web necesita; si falta, no se reemplaza la copia buena.
function validarCore(c) {
  const errores = [];
  if (!c || typeof c !== 'object') return ['no es un objeto'];
  if (!Array.isArray(c.resumen) || c.resumen.length !== 4) errores.push('resumen: se esperaban 4 sectores');
  else for (const s of c.resumen) {
    for (const k of ['zona', 'referencia_ha', 'segura_ha', 'media_ha', 'intermedia_ha', 'perdida_ha', 'ganancia_ha', 'altura_mediana_m']) if (!numero(s?.[k])) errores.push(`resumen.${k}`);
  }
  if (!Array.isArray(c.seco?.sect) || !c.seco.sect.every((s) => numero(s.zona) && numero(s.ha_seco_010))) errores.push('seco.sect');
  if (!Array.isArray(c.riesgo?.sect) || !c.riesgo.sect.every((s) => numero(s.zona) && numero(s.riesgo_medio) && numero(s.ha_muy_alto))) errores.push('riesgo.sect');
  if (!numero(c.carb?.reserva_tC) || !numero(c.carb?.c_ha) || !numero(c.carb?.comp?.suelo) || !Array.isArray(c.carb?.sect)) errores.push('carb');
  if (!Array.isArray(c.t_agua) || !Array.isArray(c.t_area)) errores.push('series t_agua / t_area');
  if (!c.audio || typeof c.audio !== 'object') errores.push('audio');
  return [...new Set(errores)];
}

// Imágenes y audio que nombra core.json.
function recursos(c) {
  const rutas = [c.relieve, c.agua, c.plan?.img];
  for (const v of Object.values(c.pres ?? {})) rutas.push(v);
  for (const z of Object.values(c.zonas ?? {})) for (const k of ['img', 'altura', 'biomasa', 'seco', 'riesgo']) rutas.push(z?.[k]);
  for (const a of Object.values(c.audio ?? {})) rutas.push(a?.src);
  const validas = new Set();
  for (const r of rutas) {
    if (typeof r !== 'string') continue;
    if (RUTA_SEGURA.test(r) && !r.includes('..')) validas.add(r);
    else console.warn(`[cra] ruta ignorada: ${JSON.stringify(r).slice(0, 80)}`);
  }
  return [...validas];
}

async function main() {
  const rutaEstado = join(destino, 'espejo.json');
  const estado = (await leerJSON(rutaEstado)) ?? { archivos: {} };
  const archivos = { ...(estado.archivos ?? {}) };
  let cambios = 0;
  let total = 0;

  const core = await bajar('data/core.json', archivos['data/core.json']);
  let datos;
  if (core.cambio) {
    try { datos = JSON.parse(core.buf.toString('utf8')); } catch { throw new Error('data/core.json no es JSON válido'); }
    const errores = validarCore(datos);
    if (errores.length) throw new Error(`data/core.json cambió de forma (${errores.join(', ')}): se conserva la copia anterior`);
  } else {
    datos = await leerJSON(join(destino, 'data/core.json'));
  }
  total += core.info.bytes ?? 0;

  // Seis descargas a la vez.
  const pendientes = recursos(datos);
  async function trabajador() {
    for (let ruta = pendientes.shift(); ruta; ruta = pendientes.shift()) {
      try {
        const r = await bajar(ruta, archivos[ruta]);
        total += r.info.bytes ?? 0;
        if (total > MAX_TOTAL) throw new Error('la copia supera el máximo total');
        if (r.cambio) { await escribir(join(destino, ruta), r.buf); cambios++; }
        archivos[ruta] = r.info;
      } catch (e) {
        // Un recurso que falla no tumba la copia: queda el anterior, si lo hay.
        console.warn(`[cra] ${ruta}: ${e.message}`);
        if (String(e.message).includes('máximo total')) throw e;
      }
    }
  }
  await Promise.all(Array.from({ length: 6 }, trabajador));

  // core.json va de último: así la web nunca ve cifras nuevas con audios viejos a medias.
  if (core.cambio) { await escribir(join(destino, 'data/core.json'), core.buf); cambios++; }
  archivos['data/core.json'] = core.info;

  const fecha = ahora();
  await escribir(rutaEstado, Buffer.from(JSON.stringify({
    origen: ORIGEN,
    revisado_en: fecha,
    actualizado_en: cambios ? fecha : (estado.actualizado_en ?? fecha),
    archivos,
  }, null, 1)));
  console.log(`[cra] ${cambios ? `${cambios} archivo(s) actualizados` : 'sin cambios'} · ${(total / 1048576).toFixed(1)} MB en ${destino}`);
}

main().catch((e) => {
  console.error(`[cra] no se actualizó la copia: ${e.message}`);
  process.exit(suave ? 0 : 1);
});
