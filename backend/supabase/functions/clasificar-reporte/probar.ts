// Prueba local SIN Supabase: clasifica fotos de tu disco con el mismo prompt y el mismo modelo de la Edge Function
// e imprime el JSON. Sirve para demostrar la IA en el pitch con fotos de prueba.
//
//   Deno : ANTHROPIC_API_KEY=... deno run -A probar.ts foto1.jpg foto2.jpg
//   Node : npm i --no-save @anthropic-ai/sdk@1.14.0   (una vez, en esta carpeta)
//          ANTHROPIC_API_KEY=... node probar.ts foto1.jpg foto2.jpg
//
// Opciones (antes o después de las fotos):
//   --tipo=quema        el tipo que «reportó el ciudadano» (por defecto «otro»; slugs: tala, quema, relleno,
//                       vertimiento, basuras, cano_taponado, fauna, otro)
//   --desc="texto"      la descripción del ciudadano (opcional)
//
// NO uses fotos de personas reales: usa fotos tuyas del manglar o de internet con licencia libre.
import { readFileSync } from "node:fs";
import process from "node:process";
import Anthropic from "@anthropic-ai/sdk";
import { clasificarConClaude } from "./modelo.ts";
import {
  aColumnas,
  detectarTipoImagen,
  FOTO_MAX_BYTES,
  parsearSalida,
  quitarMetadatosJpeg,
  reconciliar,
  TIPOS,
} from "./nucleo.ts";

const clave = process.env.ANTHROPIC_API_KEY;
if (!clave) {
  console.error("Falta ANTHROPIC_API_KEY en el entorno. Ejemplo:\n  ANTHROPIC_API_KEY=sk-ant-... node probar.ts foto.jpg\nNo se llamó al modelo.");
  process.exit(1);
}

let tipo = "otro";
let desc = "";
const archivos: string[] = [];
for (const a of process.argv.slice(2)) {
  if (a.startsWith("--tipo=")) tipo = a.slice(7);
  else if (a.startsWith("--desc=")) desc = a.slice(7);
  else archivos.push(a);
}
if (!(TIPOS as readonly string[]).includes(tipo)) {
  console.error(`--tipo inválido: ${tipo}. Opciones: ${TIPOS.join(", ")}`);
  process.exit(1);
}
if (archivos.length === 0) {
  console.error("Pásame al menos una imagen (jpg, png o webp). Ejemplo: node probar.ts foto.jpg --tipo=quema");
  process.exit(1);
}

const claude = new Anthropic({ apiKey: clave });
let fallos = 0;
for (const archivo of archivos) {
  try {
    const bytes = quitarMetadatosJpeg(new Uint8Array(readFileSync(archivo)));
    const mediaType = detectarTipoImagen(bytes);
    if (!mediaType) throw new Error("no es jpg, png ni webp");
    if (bytes.length > FOTO_MAX_BYTES) throw new Error("pesa más de 4.5 MB: redúcela");
    const r = await clasificarConClaude(claude, { foto: bytes, mediaType, tipoReportado: tipo, descripcion: desc });
    const salida = reconciliar(parsearSalida(r.texto), tipo); // misma validación que en producción
    console.log(JSON.stringify({
      archivo,
      tipo_reportado: tipo,
      ia: salida,
      columnas_que_se_guardarian: aColumnas(salida),
      modelo: r.modelo,
      uso: r.uso,
    }, null, 2));
  } catch (e) {
    fallos++;
    console.error(JSON.stringify({ archivo, error: e instanceof Error ? e.message : String(e) }));
  }
}
process.exit(fallos ? 2 : 0);
