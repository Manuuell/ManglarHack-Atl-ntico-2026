/**
 * Simula una conversación completa con Zanqui BOT sin enviar nada a WhatsApp.
 * Uso: npm run simular
 */
import fs from 'fs';
import os from 'os';
import path from 'path';

process.env.WHATSAPP_TOKEN = '';
process.env.DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'zanqui-sim-'));
process.env.HASH_SALT = 'simulacion';

async function main() {
  const { bandejaSimulada } = await import('../src/whatsapp/cloudApi');
  const { parsearWebhook } = await import('../src/whatsapp/parser');
  const { atender } = await import('../src/flujos/zanqui');
  const almacen = await import('../src/reportes/almacen');
  const { cargarZonas } = await import('../src/geo/zonas');
  const { aCSV } = await import('../src/reportes/datosAbiertos');
  const { config } = await import('../src/config');

  almacen.iniciarAlmacen();
  console.log(`Polígonos cargados: ${cargarZonas(config.zonasGeojson)}\n`);

  const persona = '573000000001';
  let n = 0;
  const webhook = (mensaje: Record<string, unknown>) => ({
    entry: [{ changes: [{ field: 'messages', value: {
      metadata: { phone_number_id: 'SIMULADO' },
      contacts: [{ wa_id: persona, profile: { name: 'Pescador de prueba' } }],
      messages: [{ from: persona, id: `wamid.sim${++n}`, timestamp: String(Math.floor(Date.now() / 1000)), ...mensaje }],
    } }] }],
  });

  const pasos: [string, Record<string, unknown>][] = [
    ['escribe "hola"', { type: 'text', text: { body: 'hola' } }],
    ['toca Reportar', { type: 'interactive', interactive: { type: 'button_reply', button_reply: { id: 'reportar', title: '🚨 Reportar' } } }],
    ['toca Anónimo', { type: 'interactive', interactive: { type: 'button_reply', button_reply: { id: 'anonimo', title: '🕶️ Anónimo' } } }],
    ['elige Tala', { type: 'interactive', interactive: { type: 'list_reply', list_reply: { id: 'tala', title: '🪓 Tala de mangle' } } }],
    ['manda su ubicación en la Ciénaga de Mallorquín', { type: 'location', location: { latitude: 11.0505, longitude: -74.8668 } }],
    ['manda una foto', { type: 'image', image: { id: 'media-sim-1', mime_type: 'image/jpeg', sha256: 'abc123' } }],
    ['describe', { type: 'text', text: { body: 'Dos señores con machete cortando mangle rojo cerca del caño' } }],
    ['toca Ahora mismo', { type: 'interactive', interactive: { type: 'button_reply', button_reply: { id: 'ahora', title: 'Ahora mismo' } } }],
    ['toca Enviar', { type: 'interactive', interactive: { type: 'button_reply', button_reply: { id: 'enviar', title: '✅ Enviar' } } }],
    ['toca Mis reportes', { type: 'interactive', interactive: { type: 'button_reply', button_reply: { id: 'mis_reportes', title: '📋 Mis reportes' } } }],
  ];

  for (const [accion, mensaje] of pasos) {
    console.log(`\n👤 La persona ${accion}`);
    bandejaSimulada.length = 0;
    for (const m of parsearWebhook(webhook(mensaje))) await atender(m);
    for (const salida of bandejaSimulada) {
      const s = salida as any;
      const cuerpo = s.text?.body ?? s.interactive?.body?.text ?? '';
      const opciones = s.interactive?.action?.buttons?.map((b: any) => b.reply.title) ?? s.interactive?.action?.sections?.[0]?.rows?.map((r: any) => r.title);
      const tipo = s.interactive?.type === 'location_request_message' ? ' [botón: Enviar ubicación]' : '';
      console.log(`🌿 Zanqui: ${cuerpo.replace(/\n/g, '\n           ')}${tipo}`);
      if (opciones) console.log(`           [${opciones.join(' | ')}]`);
    }
  }

  const [r] = almacen.todos();
  console.log('\n--- Reporte guardado ---');
  console.log(JSON.stringify({ ...r, reportanteHash: r.reportanteHash.slice(0, 12) + '…' }, null, 2));
  console.log('\n--- Datos abiertos (CSV) ---');
  console.log(aCSV(almacen.todos()));
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
