#!/usr/bin/env node
// Muestras ficticias para demostrar cuatro zonas. Sin variables, solo imprime peticiones.
const sensores = [
  { id: '5e500000-0000-4000-8000-000000000001', zona: 'Mallorquín', tipo: 'nivel_agua', unidad: 'm', normal: 0.82, alerta: 1.72 },
  { id: '5e500000-0000-4000-8000-000000000002', zona: 'Tubará', tipo: 'salinidad', unidad: 'ppt', normal: 0.83 },
  { id: '5e500000-0000-4000-8000-000000000003', zona: 'Juan de Acosta', tipo: 'temperatura', unidad: '°C', normal: 29.7 },
  { id: '5e500000-0000-4000-8000-000000000004', zona: 'Ciénaga del Totumo', tipo: 'turbidez', unidad: 'NTU', normal: 72 },
];
const url = process.env.ZANKY_SENSOR_URL;
const tokenEntorno = process.env.ZANKY_SENSOR_TOKEN;
let tokens = {};
if (tokenEntorno) {
  try { tokens = JSON.parse(tokenEntorno); } catch { tokens = Object.fromEntries(sensores.map((s) => [s.id, tokenEntorno])); }
}
const seco = !url || !tokenEntorno;
if (seco) console.log('MODO SECO · DATOS FICTICIOS · No se envía ninguna lectura.');
if (!seco && !url.startsWith('https://')) throw new Error('ZANKY_SENSOR_URL debe ser HTTPS.');

for (const sensor of sensores) {
  const ahora = Date.now();
  const lecturas = [
    { tipo: sensor.tipo, valor: sensor.normal, unidad: sensor.unidad, medido_en: new Date(ahora - 60_000).toISOString() },
  ];
  if (sensor.alerta !== undefined) {
    // Dos lecturas del mismo sensor en un único lote para respetar 30 s de límite.
    lecturas.push({ tipo: sensor.tipo, valor: sensor.alerta, unidad: sensor.unidad, medido_en: new Date(ahora).toISOString() });
  }
  const cuerpo = { sensor_id: sensor.id, lecturas };
  if (seco) {
    console.log(JSON.stringify({ zona: sensor.zona, peticion: cuerpo }, null, 2));
    continue;
  }
  const token = tokens[sensor.id];
  if (typeof token !== 'string' || !token) throw new Error(`Falta token para ${sensor.zona}.`);
  const respuesta = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify(cuerpo),
  });
  const texto = await respuesta.text();
  console.log(`${sensor.zona}: HTTP ${respuesta.status} ${texto}`);
  if (!respuesta.ok) process.exitCode = 1;
}
