/**
 * Verificación de Zanky contra dist/, Supabase real y la API pública de jornadas.
 * Copiar junto a dist/, .env, data/ y datos/; ejecutar: node verificar-real.js
 */
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

const NUMERO = '570000000099';
const URL_JORNADAS = 'https://zanqui.sentralabs.co/api/jornadas';
const temporal = fs.mkdtempSync(path.join(os.tmpdir(), 'zanky-verif-'));
let correctos = 0;
let respuesta = '';
let secuencia = 0;
let codigoReporte;

const texto = body => ({ type: 'text', text: { body } });
const boton = id => ({ type: 'interactive', interactive: { type: 'button_reply', button_reply: { id, title: id } } });
const lista = id => ({ type: 'interactive', interactive: { type: 'list_reply', list_reply: { id, title: id } } });
const ubicacion = (latitude, longitude) => ({ type: 'location', location: { latitude, longitude } });
const exigir = (condicion, motivo) => { if (!condicion) throw new Error(motivo); };
const recortar = valor => String(valor || '(sin respuesta)').replace(/\s+/g, ' ').slice(0, 300);

async function main() {
  try {
    // Estas variables deben fijarse antes de que config y los módulos de dist/ se carguen.
    require('dotenv').config({ path: path.join(process.cwd(), '.env') });
    process.env.WHATSAPP_TOKEN = '';
    const origen = path.resolve('data');
    exigir(fs.existsSync(origen), `No existe ${origen}`);
    fs.cpSync(origen, temporal, { recursive: true });
    process.env.DATA_DIR = temporal;

    const { bandejaSimulada } = require('./dist/whatsapp/cloudApi');
    const { parsearWebhook } = require('./dist/whatsapp/parser');
    const { atender } = require('./dist/flujos/zanky');
    const almacen = require('./dist/reportes/almacen');
    const { cargarZonas, cargarAreaReporte } = require('./dist/geo/zonas');
    const jornadas = require('./dist/api/almacenJornadas');
    const { propuestasPublicas } = require('./dist/api/almacenPropuestas');
    const { config } = require('./dist/config');

    exigir(config.dryRun && config.dataDir === temporal, 'No se activó la simulación o la copia temporal de data.');
    almacen.iniciarAlmacen();
    cargarZonas(config.zonasGeojson);
    cargarAreaReporte(config.areaReporteGeojson);
    jornadas.iniciarJornadas();

    async function enviar(mensaje) {
      bandejaSimulada.length = 0;
      const webhook = { entry: [{ changes: [{ field: 'messages', value: {
        metadata: { phone_number_id: 'VERIFICACION' },
        contacts: [{ wa_id: NUMERO, profile: { name: 'Verificación' } }],
        messages: [{ from: NUMERO, id: `wamid.verif-${Date.now()}-${++secuencia}`,
          timestamp: String(Math.floor(Date.now() / 1000)), ...mensaje }],
      } }] }] };
      for (const m of parsearWebhook(webhook)) await atender(m);
      const salidas = bandejaSimulada.filter(s => s.type === 'text' || s.type === 'interactive');
      const partes = salidas.map(s => {
        const cuerpo = s.text?.body ?? s.interactive?.body?.text ?? '';
        const opciones = s.interactive?.action?.buttons?.map(b => b.reply.title)
          ?? s.interactive?.action?.sections?.flatMap(seccion => seccion.rows.map(f => f.title)) ?? [];
        return [cuerpo, ...opciones].filter(Boolean).join(' | ');
      });
      respuesta = partes.join(' || ');
      return respuesta;
    }

    async function punto(n, accion) {
      respuesta = '';
      try {
        await accion();
        correctos++;
        console.log(`PUNTO ${n} · OK`);
      } catch (err) {
        console.log(`PUNTO ${n} · FALLA: ${err.message}`);
      }
      console.log(`  Zanky: ${recortar(respuesta)}`);
    }

    await punto(1, async () => {
      const r = await enviar(texto('Hola'));
      exigir(/Reportar/i.test(r) && /Proponer/i.test(r), 'No apareció el menú principal.');
    });

    await punto(2, async () => {
      let r = await enviar(boton('reportar'));
      if (/an[oó]nim/i.test(r)) r = await enviar(boton('anonimo'));
      await enviar(lista('tala'));
      await enviar(ubicacion(11.0412, -74.8706));
      await enviar(boton('sin_foto'));
      await enviar(texto('PRUEBA de verificación — descartar'));
      await enviar(boton('ahora'));
      await enviar(boton('pequena'));
      r = await enviar(boton('enviar'));
      const codigo = r.match(/\bZK-[0-9A-F]{4}\b/i)?.[0].toUpperCase();
      exigir(codigo, 'El envío no devolvió un código ZK-XXXX.');
      codigoReporte = codigo;
      const guardado = almacen.delReportante(almacen.hashDe(NUMERO)).find(x => x.codigo === codigo);
      exigir(guardado?.tipo === 'tala' && guardado.envio?.estado === 'enviado',
        `${codigo} no figura como tala enviada a Supabase.`);
      r = await enviar(texto('mis reportes'));
      exigir(r.includes(codigo), `Mis reportes no muestra ${codigo}.`);
    });

    await punto(3, async () => {
      exigir(codigoReporte, 'El punto 2 no produjo un código para consultar.');
      const r = await enviar(texto(codigoReporte.toLowerCase()));
      exigir(r.includes(codigoReporte) && /Estado/i.test(r), 'La consulta no mostró el código y el estado.');
    });

    await punto(4, async () => {
      exigir(almacen.todos().some(x => x.codigo === 'ZK-16D1'), 'ZK-16D1 no está en la copia de data/zanky.json.');
      const r = await enviar(texto('ZK-16D1'));
      exigir(/Basuras/i.test(r) && /Recibido/i.test(r), 'El caso no mostró Basuras y Recibido.');
    });

    await punto(5, async () => {
      const hash = almacen.hashDe(NUMERO);
      const antes = almacen.delReportante(hash).map(x => x.codigo);
      await enviar(boton('reportar'));
      await enviar(lista('quema'));
      const r = await enviar(texto('salir'));
      exigir(/se cancel[oó], no qued[oó] guardado/i.test(r) && /Reportar/i.test(r) && /Proponer/i.test(r),
        'No confirmó la cancelación y el regreso al menú.');
      const despues = almacen.delReportante(hash);
      exigir(antes.length === 1 && antes[0] === codigoReporte && despues.length === 1
        && despues[0].codigo === codigoReporte && despues[0].tipo === 'tala',
      'Los reportes cambiaron tras cancelar la quema; debe quedar solo la tala del punto 2.');
      const listado = await enviar(texto('mis reportes'));
      exigir(listado.includes(codigoReporte) && !/Quema/i.test(listado), 'Mis reportes muestra una quema nueva o perdió la tala.');
    });

    await punto(6, async () => {
      await enviar(texto('proponer'));
      await enviar(lista('limpieza'));
      await enviar(ubicacion(11.0321, -74.8575));
      await enviar(texto('PRUEBA de verificación de propuesta — descartar'));
      await enviar(texto('comunidad'));
      const r = await enviar(boton('p_enviar'));
      const codigo = r.match(/\bPROP-[0-9A-F]{4}\b/i)?.[0].toUpperCase();
      exigir(codigo, 'La propuesta no devolvió un código PROP-XXXX.');
      const p = propuestasPublicas().find(x => x.codigo === codigo);
      exigir(p?.tipo === 'limpieza' && p.tipo_accion === 'conservacion_vigilancia'
        && p.tipo_actor === 'comunidad', 'La propuesta pública no tiene tipo_accion y tipo_actor esperados.');
      console.log(`  ${codigo} se guardó en la COPIA de data (${temporal}), no en la real.`);
    });

    await punto(7, async () => {
      const r = await enviar(boton('jornadas'));
      const salidas = bandejaSimulada.filter(s => s.interactive?.type === 'list');
      const filas = salidas.flatMap(s => s.interactive.action.sections.flatMap(seccion => seccion.rows));
      const res = await fetch(URL_JORNADAS, { signal: AbortSignal.timeout(15_000) });
      exigir(res.ok, `GET /api/jornadas respondió HTTP ${res.status}.`);
      const cuerpo = await res.json();
      exigir(Array.isArray(cuerpo.jornadas), 'La API no devolvió una lista de jornadas.');
      const remotas = cuerpo.jornadas.filter(j => Date.parse(j.fin) > Date.now())
        .sort((a, b) => a.inicio.localeCompare(b.inicio));
      const locales = jornadas.jornadasPublicadas().map(jornadas.publica)
        .filter(j => Date.parse(j.fin) > Date.now());
      const cupos = j => Math.max(0, j.cupos - j.inscritos);
      const fecha = j => new Intl.DateTimeFormat('es-CO', { timeZone: 'America/Bogota', day: 'numeric', month: 'short' })
        .format(new Date(j.inicio)).replace('.', '');
      const tabla = js => js.map(j => ({ id: j.id, fecha: fecha(j), titulo: j.titulo, cupos_libres: cupos(j) }));
      console.log('  API:');
      console.table(tabla(remotas));
      console.log('  Bot:');
      console.table(filas.map(f => ({
        id: f.id.replace(/^jor:/, ''),
        fecha: f.title.match(/\b\d{1,2} [\p{L}.]+/u)?.[0] ?? f.title,
        titulo: f.description.replace(/^(?:Sin cupos|\d+ cupos? libres?) · /i, ''),
        cupos_libres: /^Sin cupos/i.test(f.description) ? 0 : Number(f.description.match(/^\d+/)?.[0]),
      })));
      exigir(remotas.length === locales.length && remotas.every((j, i) => {
        const local = locales[i];
        return local?.id === j.id && local.inicio === j.inicio && local.titulo === j.titulo && cupos(local) === cupos(j);
      }), 'La copia local no coincide con la API pública.');
      exigir(remotas.length === filas.length, 'La lista del bot no contiene las mismas jornadas próximas que la API.');
      for (let i = 0; i < remotas.length; i++) {
        const j = remotas[i];
        const f = filas[i];
        const libres = cupos(j);
        exigir(f.id === `jor:${j.id}` && f.title.includes(fecha(j))
          && /cupo/i.test(f.description)
          && f.description.includes(libres ? String(libres) : 'Sin cupos'),
        `La fila ${j.id} no coincide en id, fecha o cupos libres.`);
      }
      exigir(remotas.length ? /Jornadas/i.test(r) : /no hay jornadas/i.test(r), 'El mensaje de jornadas no corresponde a la API.');
    });

    await punto(8, async () => {
      await enviar(boton('reportar'));
      await enviar(lista('basuras'));
      let r = await enviar(texto('asdfgh'));
      exigir(/No te entend[ií]/i.test(r) && /ubicaci[oó]n/i.test(r) && /salir/i.test(r),
        'La primera respuesta no recordó el paso de ubicación y la opción salir.');
      r = await enviar(texto('asdfgh'));
      exigir(/Ayuda/i.test(r) && /Salir/i.test(r), 'La segunda respuesta no ofreció Ayuda y Salir.');
      await enviar(texto('salir'));
    });
  } catch (err) {
    console.log(`Preparación fallida: ${err.message}`);
    for (let n = 1; n <= 8; n++) {
      console.log(`PUNTO ${n} · FALLA: no se pudo preparar la verificación.`);
      console.log('  Zanky: (sin respuesta)');
    }
  } finally {
    console.log(`${correctos}/8 OK`);
    console.log(`Carpeta temporal usada: ${temporal}`);
    fs.rmSync(temporal, { recursive: true, force: true });
    process.exit(0);
  }
}

main();
