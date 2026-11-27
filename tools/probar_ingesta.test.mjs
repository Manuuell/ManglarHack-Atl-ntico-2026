import test from 'node:test';
import assert from 'node:assert/strict';

let manejar;
globalThis.Deno = {
  env: { get: (nombre) => ({ SUPABASE_URL: 'https://ejemplo.invalid', SUPABASE_SERVICE_ROLE_KEY: 'clave_ficticia' })[nombre] },
  serve: (funcion) => { manejar = funcion; },
};
await import('../backend/supabase/functions/lectura-sensor/index.ts');
const id = '5e500000-0000-4000-8000-000000000001';
const token = 't'.repeat(64);
const lectura = { tipo: 'nivel_agua', valor: 1.72, unidad: 'm', medido_en: new Date().toISOString() };
const peticion = (lecturas, autorizacion = `Bearer ${token}`) => new Request('https://ejemplo.invalid/functions/v1/lectura-sensor', {
  method: 'POST', headers: { authorization: autorizacion, 'content-type': 'application/json' },
  body: JSON.stringify({ sensor_id: id, lecturas }),
});
const respuesta = (cuerpo, estado = 200) => new Response(JSON.stringify(cuerpo), {
  status: estado, headers: { 'content-type': 'application/json' },
});

test('rechaza ausencia de token antes de consultar la base', async () => {
  globalThis.fetch = () => { throw new Error('No debe consultar la base'); };
  const salida = await manejar(peticion([lectura], ''));
  assert.equal(salida.status, 401);
});

test('valida rango y tipo antes de registrar', async () => {
  let registros = 0;
  globalThis.fetch = async (url) => {
    if (url.includes('sensor_tokens')) return respuesta([{ sensor_id: id }]);
    if (url.includes('sensores?')) return respuesta([{ tipo: 'nivel_agua', activo: true }]);
    registros++;
    return respuesta({ nuevas: 1 });
  };
  const salida = await manejar(peticion([{ ...lectura, valor: 11 }]));
  assert.equal(salida.status, 422);
  assert.equal(registros, 0);
});

test('registra un lote válido y conserva el resultado de la RPC', async () => {
  globalThis.fetch = async (url) => {
    if (url.includes('sensor_tokens')) return respuesta([{ sensor_id: id }]);
    if (url.includes('sensores?')) return respuesta([{ tipo: 'nivel_agua', activo: true }]);
    return respuesta({ recibidas: 1, nuevas: 1, alertas: 1 });
  };
  const salida = await manejar(peticion([lectura]));
  assert.equal(salida.status, 200);
  assert.deepEqual(await salida.json(), { recibidas: 1, nuevas: 1, alertas: 1 });
});

test('comunica el límite de tasa del servidor', async () => {
  globalThis.fetch = async (url) => {
    if (url.includes('sensor_tokens')) return respuesta([{ sensor_id: id }]);
    if (url.includes('sensores?')) return respuesta([{ tipo: 'nivel_agua', activo: true }]);
    return respuesta({ code: 'P0001', message: 'limite_de_tasa' }, 400);
  };
  const salida = await manejar(peticion([lectura]));
  assert.equal(salida.status, 429);
  assert.equal(salida.headers.get('retry-after'), '30');
});
