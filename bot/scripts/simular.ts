/**
 * Simula una conversación completa con Zanky BOT sin enviar nada a WhatsApp, contra un backend
 * de mentira que aplica las mismas reglas que backend/supabase/schema.sql (columnas permitidas,
 * valores aceptados, recuadro del Atlántico, foto en evidencias/<id>.jpg…).
 * Uso: npm run simular
 */
import fs from 'fs';
import http from 'http';
import os from 'os';
import path from 'path';

const COLUMNAS = new Set(['id', 'canal', 'tipo', 'descripcion', 'lat', 'lon', 'precision_m', 'metodo_ubicacion', 'capturado_en', 'momento',
  'magnitud', 'zona', 'municipio', 'dentro_poligono', 'distancia_m', 'prioridad', 'confianza', 'foto_hash', 'foto_de_camara', 'foto_url',
  'anonimo', 'reportante_id', 'sincronizado_tarde']);
const EN = (v: unknown, xs: string[]) => typeof v === 'string' && xs.includes(v);

/** Las restricciones de la tabla reportes; devuelve los errores encontrados. */
function validar(f: Record<string, any>): string[] {
  const e: string[] = [];
  for (const k of Object.keys(f)) if (!COLUMNAS.has(k)) e.push(`columna no permitida: ${k}`);
  if (!/^[0-9a-f-]{36}$/.test(f.id)) e.push('id no es UUID');
  if (f.canal !== 'whatsapp') e.push('canal');
  if (!EN(f.tipo, ['tala', 'quema', 'relleno', 'vertimiento', 'basuras', 'cano_taponado', 'fauna', 'otro'])) e.push(`tipo ${f.tipo}`);
  if (typeof f.descripcion !== 'string' || f.descripcion.length > 1000) e.push('descripcion');
  if (!(f.lat >= 10.2 && f.lat <= 11.4 && f.lon >= -75.7 && f.lon <= -74.4)) e.push('fuera del Atlántico');
  if (!EN(f.metodo_ubicacion, ['gps', 'mapa', 'enlace'])) e.push('metodo_ubicacion');
  if (!EN(f.momento, ['ahora', 'hoy', 'antes'])) e.push(`momento ${f.momento}`);
  if (!EN(f.magnitud, ['pequena', 'mediana', 'grande'])) e.push(`magnitud ${f.magnitud}`);
  if (!(f.prioridad >= 1 && f.prioridad <= 5)) e.push('prioridad');
  if (!(f.confianza >= 0 && f.confianza <= 100)) e.push('confianza');
  if (f.foto_hash !== null && !/^[0-9a-f]{64}$/.test(f.foto_hash)) e.push('foto_hash');
  if (f.foto_url !== null && f.foto_url !== `evidencias/${f.id}.jpg`) e.push('foto_url');
  if (f.reportante_id !== null && String(f.reportante_id).length > 64) e.push('reportante_id');
  if (Date.parse(f.capturado_en) > Date.now() + 10 * 60 * 1000) e.push('capturado_en en el futuro');
  return e;
}

const filas: Record<string, any>[] = [];
let fallarProximos = 0;

const servidor = http.createServer((req, res) => {
  let cuerpo = '';
  req.on('data', c => (cuerpo += c));
  req.on('end', () => {
    if (req.method === 'GET' && req.url === '/datos/jornadas.json') {
      const en = (dias: number, h: number) => new Date(Date.now() + dias * 86_400_000 + h * 3_600_000).toISOString();
      return res.writeHead(200, { 'Content-Type': 'application/json' }).end(JSON.stringify({
        aviso: 'Datos de ejemplo · Modo demostración',
        jornadas: [
          { id: 'jornada-1', titulo: 'Jornada de siembra en el caño', tipo: 'siembra', inicio: en(2, 0), fin: en(2, 4), punto_encuentro: 'Ecoparque Ciénaga de Mallorquín, entrada principal', lat: 11.03217, lon: -74.85755, cupos: 40, inscritos: 23, que_llevar: ['Agua', 'Gorra'], descripcion: 'Datos de ejemplo.' },
          { id: 'jornada-2', titulo: 'Recorrido de vigías del Totumo', tipo: 'recorrido_vigias', inicio: en(9, 0), fin: en(9, 3), punto_encuentro: 'Muelle de pescadores del Totumo', lat: 10.74, lon: -75.24, cupos: 15, inscritos: 9, que_llevar: [], descripcion: 'Datos de ejemplo.' },
          { id: 'jornada-vieja', titulo: 'Jornada que ya pasó', tipo: 'limpieza', inicio: en(-3, 0), fin: en(-3, 2), punto_encuentro: 'Playa', lat: 11, lon: -74.9, cupos: 10, inscritos: 10, que_llevar: [], descripcion: '' },
        ],
      }));
    }
    if (req.headers.apikey !== 'anon-de-prueba') return res.writeHead(401).end();
    if (fallarProximos > 0) {
      fallarProximos--;
      return res.writeHead(503).end('{"message":"caído a propósito"}');
    }
    if (req.method === 'POST' && req.url === '/rest/v1/reportes') {
      const fila = JSON.parse(cuerpo);
      const errores = validar(fila);
      if (errores.length) return res.writeHead(400).end(JSON.stringify({ message: errores.join('; ') }));
      if (!filas.some(f => f.id === fila.id)) filas.push(fila); // ignore-duplicates
      return res.writeHead(201).end();
    }
    if (req.method === 'POST' && req.url?.startsWith('/storage/v1/object/evidencias/')) {
      return res.writeHead(req.headers['content-type'] === 'image/jpeg' ? 200 : 400).end('{}');
    }
    if (req.method === 'POST' && req.url === '/rest/v1/rpc/estado_de_reportes') {
      const { ids } = JSON.parse(cuerpo);
      const filasEstado = filas.filter(f => ids.includes(f.id)).map(f => ({ id: f.id, estado: 'verificado', prioridad: f.prioridad, confianza: 85, nota_publica: null, actualizado_en: new Date().toISOString() }));
      return res.writeHead(200, { 'Content-Type': 'application/json' }).end(JSON.stringify(filasEstado));
    }
    res.writeHead(404).end();
  });
});

async function main() {
  await new Promise<void>(ok => servidor.listen(0, '127.0.0.1', () => ok()));
  const puerto = (servidor.address() as { port: number }).port;

  process.env.WHATSAPP_TOKEN = '';
  process.env.DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'zanky-sim-'));
  process.env.HASH_SALT = 'simulacion';
  process.env.SUPABASE_URL = `http://127.0.0.1:${puerto}`;
  process.env.SUPABASE_ANON_KEY = 'anon-de-prueba';
  process.env.JORNADAS_URL = `http://127.0.0.1:${puerto}/datos/jornadas.json`;
  process.env.ZONAS_GEOJSON = path.resolve(__dirname, '../../app/assets/datos/manglar_zonas.json');

  const { bandejaSimulada } = await import('../src/whatsapp/cloudApi');
  const { parsearWebhook } = await import('../src/whatsapp/parser');
  const { atender } = await import('../src/flujos/zanky');
  const almacen = await import('../src/reportes/almacen');
  const { cargarZonas } = await import('../src/geo/zonas');
  const { enviarReporte } = await import('../src/backend/envio');
  const { config } = await import('../src/config');

  almacen.iniciarAlmacen();
  console.log(`Zonas cargadas: ${cargarZonas(config.zonasGeojson)} · backend de prueba en ${process.env.SUPABASE_URL}\n`);

  const persona = '573000000001';
  let n = 0;
  const webhook = (mensaje: Record<string, unknown>) => ({
    entry: [{ changes: [{ field: 'messages', value: {
      metadata: { phone_number_id: 'SIMULADO' },
      contacts: [{ wa_id: persona, profile: { name: 'Pescador de prueba' } }],
      messages: [{ from: persona, id: `wamid.sim${++n}`, timestamp: String(Math.floor(Date.now() / 1000)), ...mensaje }],
    } }] }],
  });
  const boton = (id: string) => ({ type: 'interactive', interactive: { type: 'button_reply', button_reply: { id, title: id } } });
  const lista = (id: string) => ({ type: 'interactive', interactive: { type: 'list_reply', list_reply: { id, title: id } } });

  const reporte: [string, Record<string, unknown>][] = [
    ['toca Reportar', boton('reportar')],
    ['elige Tala', lista('tala')],
    ['manda su ubicación en la Ciénaga de Mallorquín', { type: 'location', location: { latitude: 11.0412, longitude: -74.8706 } }],
    ['toca Sin foto', boton('sin_foto')],
    ['describe', { type: 'text', text: { body: 'Dos señores con machete cortando mangle rojo cerca del caño' } }],
    ['toca Ahora mismo', boton('ahora')],
    ['toca Grande', boton('grande')],
    ['toca Enviar', boton('enviar')],
  ];
  const pasos: [string, Record<string, unknown>][] = [
    ['escribe "hola"', { type: 'text', text: { body: 'hola' } }],
    ['toca Registrarme', boton('registrarme')],
    ['escribe su nombre', { type: 'text', text: { body: 'vigía de prueba' } }],
    ['elige Pescador/a', lista('pescador')],
    ['elige Puerto Colombia', lista('puerto_colombia')],
    ...reporte,
    ['toca Mis reportes', boton('mis_reportes')],
    ['toca Jornadas', boton('jornadas')],
    ['elige la siembra', lista('jor:jornada-1')],
    ['toca Menú', boton('menu')],
    ['manda una ubicación fuera del Atlántico', { type: 'location', location: { latitude: 6.2442, longitude: -75.5812 } }],
  ];

  async function correr(lista: [string, Record<string, unknown>][]) {
    for (const [accion, mensaje] of lista) {
      console.log(`\n👤 La persona ${accion}`);
      bandejaSimulada.length = 0;
      for (const m of parsearWebhook(webhook(mensaje))) await atender(m);
      for (const salida of bandejaSimulada) {
        const s = salida as any;
        const cuerpo = s.text?.body ?? s.interactive?.body?.text ?? '';
        const opciones = s.interactive?.action?.buttons?.map((b: any) => b.reply.title) ?? s.interactive?.action?.sections?.[0]?.rows?.map((r: any) => r.title);
        const tipo = s.interactive?.type === 'location_request_message' ? ' [botón: Enviar ubicación]' : '';
        console.log(`🌿 Zanky: ${cuerpo.replace(/\n/g, '\n           ')}${tipo}`);
        if (opciones) console.log(`           [${opciones.join(' | ')}]`);
      }
    }
  }

  // 1) Todo bien: el reporte llega al backend.
  await correr(pasos.slice(0, -1).concat([['vuelve a reportar (para probar la ubicación fuera)', boton('menu')], ['toca Reportar', boton('reportar')], ['elige Quema', lista('quema')], pasos[pasos.length - 1]]));

  // 2) El backend se cae: el reporte queda pendiente y se reintenta después.
  console.log('\n\n=== El backend se cae durante el envío ===');
  fallarProximos = 1;
  await correr([['escribe "menu"', { type: 'text', text: { body: 'menu' } }], ...reporte]);
  const pendiente = almacen.pendientesDeEnvio()[0];
  console.log(`\nPendientes: ${almacen.pendientesDeEnvio().length} · reintento → ${pendiente ? await enviarReporte(pendiente) : 'nada'}`);

  console.log('\n--- Filas que recibió el backend de prueba (todas pasaron las reglas del esquema) ---');
  for (const f of filas) console.log(JSON.stringify({ ...f, reportante_id: String(f.reportante_id).slice(0, 12) + '…' }));
  servidor.close();
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
