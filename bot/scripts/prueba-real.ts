/**
 * Prueba de punta a punta contra el backend REAL (bot → Supabase → web). Crea UN reporte de prueba,
 * claramente marcado, en la Ciénaga de Mallorquín, recorriendo la conversación real de Zanky en modo
 * simulación de WhatsApp (no se manda nada a Meta). Después lo busca en la vista pública reportes_publicos,
 * que es lo que lee el mapa de https://mimanglar.sentralabs.co/.
 *
 * Uso (desde bot/, con SUPABASE_URL y SUPABASE_ANON_KEY en bot/.env, que git ignora):
 *   npm run prueba:real -- --si
 * Sin «--si» solo muestra lo que haría. El reporte queda en estado «recibido»: pide a la C.R.A. que lo
 * descarte en el panel (cambiar_estado → descartado) cuando termine la verificación.
 */
import 'dotenv/config';
import fs from 'fs';
import os from 'os';
import path from 'path';

const DESCRIPCION = 'PRUEBA de integración — descartar';
const PUNTO = { latitude: 11.0412, longitude: -74.8706 }; // Ciénaga de Mallorquín, dentro de la cobertura C.R.A.

async function main() {
  const url = (process.env.SUPABASE_URL ?? '').replace(/\/$/, '');
  const anon = process.env.SUPABASE_ANON_KEY ?? '';
  if (!url || !anon) {
    console.error('Faltan SUPABASE_URL o SUPABASE_ANON_KEY en bot/.env. No se crea nada.');
    process.exit(1);
  }
  if (!process.argv.includes('--si')) {
    console.log(`Crearía UN reporte «${DESCRIPCION}» (tala, sin foto) en ${PUNTO.latitude}, ${PUNTO.longitude} en ${new URL(url).host}.`);
    console.log('Para hacerlo de verdad: npm run prueba:real -- --si');
    return;
  }
  // Nada sale a WhatsApp; la copia local va a una carpeta temporal.
  process.env.WHATSAPP_TOKEN = '';
  process.env.OPENAI_API_KEY = '';
  process.env.DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'zanky-prueba-real-'));
  process.env.HASH_SALT ??= 'prueba-integracion';

  const { bandejaSimulada } = await import('../src/whatsapp/cloudApi');
  const { parsearWebhook } = await import('../src/whatsapp/parser');
  const { atender } = await import('../src/flujos/zanky');
  const almacen = await import('../src/reportes/almacen');
  const { cargarAreaReporte, cargarZonas } = await import('../src/geo/zonas');
  const { config } = await import('../src/config');
  almacen.iniciarAlmacen();
  cargarZonas(config.zonasGeojson);
  cargarAreaReporte(config.areaReporteGeojson);

  const persona = '570000000000'; // número ficticio: solo vive en la copia temporal (como hash)
  let n = 0;
  const marca = Date.now();
  const webhook = (mensaje: Record<string, unknown>) => ({
    entry: [{ changes: [{ field: 'messages', value: {
      metadata: { phone_number_id: 'PRUEBA' },
      contacts: [{ wa_id: persona, profile: { name: 'Prueba de integración' } }],
      messages: [{ from: persona, id: `wamid.prueba-integracion-${marca}-${++n}`, timestamp: String(Math.floor(Date.now() / 1000)), ...mensaje }],
    } }] }],
  });
  const boton = (id: string) => ({ type: 'interactive', interactive: { type: 'button_reply', button_reply: { id, title: id } } });
  const lista = (id: string) => ({ type: 'interactive', interactive: { type: 'list_reply', list_reply: { id, title: id } } });
  const pasos: Record<string, unknown>[] = [
    boton('reportar'), boton('anonimo'), lista('tala'),
    { type: 'location', location: PUNTO },
    boton('sin_foto'), { type: 'text', text: { body: DESCRIPCION } },
    boton('ahora'), boton('pequena'), boton('enviar'),
  ];
  for (const p of pasos) {
    bandejaSimulada.length = 0;
    for (const m of parsearWebhook(webhook(p))) await atender(m);
  }
  const ultimo = bandejaSimulada.map((s: any) => s.text?.body ?? s.interactive?.body?.text ?? '').join('\n---\n');
  const r = almacen.todos()[0];
  if (!r || r.envio.estado !== 'enviado') {
    console.error('El reporte NO llegó al backend:', r?.envio, '\n', ultimo);
    process.exit(1);
  }
  const hora = new Date().toISOString();
  console.log(`✅ ${hora} · ${r.codigo} creado por el bot en ${new URL(url).host}`);
  console.log(`   id interno ${r.id} · id público ${r.idPublico} · prioridad ${r.prioridad} · estado ${r.estado}`);
  console.log(`   Zanky respondió:\n${ultimo.replace(/^/gm, '   │ ')}`);

  // Lo mismo que lee la web: la vista pública.
  const res = await fetch(`${url}/rest/v1/reportes_publicos?select=id_publico,tipo,lat,lon,estado,canal,capturado_en,zona,municipio&id_publico=eq.${r.idPublico}`, {
    headers: { apikey: anon, Authorization: `Bearer ${anon}` },
  });
  const filas = (await res.json()) as Record<string, unknown>[];
  console.log(`\nreportes_publicos (lo que ve la web) → ${res.status}: ${JSON.stringify(filas)}`);
  if (!filas.length || filas[0].canal !== 'whatsapp') process.exit(1);
  console.log(`\nAhora búscalo en https://mimanglar.sentralabs.co/ (punto de tala en Mallorquín, canal WhatsApp) y pide a la C.R.A. que descarte ${r.codigo}.`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
