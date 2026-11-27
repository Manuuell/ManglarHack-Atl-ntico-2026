import express, { NextFunction, Request, Response } from 'express';
import { timingSafeEqual } from 'crypto';
import { avisosDeConfiguracion, config } from './config';
import { parsearWebhook, MensajeEntrante } from './whatsapp/parser';
import { firmaValida } from './whatsapp/firma';
import { whatsapp } from './whatsapp/cloudApi';
import { cargarAreaReporte, cargarZonas } from './geo/zonas';
import * as almacen from './reportes/almacen';
import { aCSV, aGeoJSON, aKML } from './reportes/datosAbiertos';
import { esEstado } from './reportes/modelo';
import { atender, avisarCambio, guardarSesiones } from './flujos/zanky';
import { MapaPersistente } from './reportes/persistente';
import { enviarReporte } from './backend/envio';
import { backendActivo } from './backend/supabase';
import { sondearEstados } from './backend/avisos';
import { enviadoTarde } from './flujos/textos';
import { ErrorIA, iaActiva, responder, Turno } from './ia/zanky';
import path from 'path';
import { api } from './api/rutas';
import { iniciarJornadas } from './api/almacenJornadas';
import { atenderRespuestaInvitacion } from './api/respuestas';
import { escucharAudio } from './ia/audio';
import { alertasActuales, alertasSimulacro, iniciarAlertas } from './alertas/motor';

type ConCuerpoCrudo = Request & { cuerpoCrudo?: Buffer };

const app = express();
app.set('trust proxy', 1);
app.disable('x-powered-by');
app.use((_req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
  next();
});
app.use(
  express.json({
    limit: '1mb',
    verify: (req, _res, buf) => {
      (req as ConCuerpoCrudo).cuerpoCrudo = Buffer.from(buf);
    },
  }),
);

// API de la web y del panel admin (jornadas, inscripciones, cuentas, invitaciones) e imágenes de invitación.
app.use('/api', api);
app.use('/invitaciones', express.static(path.join(__dirname, '../publico/invitaciones'), { maxAge: '1h' }));

app.get('/health', (_req, res) => {
  res.json({ ok: true, simulacion: config.dryRun, reportes: almacen.todos().length });
});

// --- Webhook de WhatsApp ---------------------------------------------------

app.get('/webhook', (req, res) => {
  if (req.query['hub.mode'] === 'subscribe' && config.verifyToken && req.query['hub.verify_token'] === config.verifyToken) {
    res.status(200).send(String(req.query['hub.challenge'] ?? ''));
    return;
  }
  res.sendStatus(403);
});

// Ids de mensaje ya atendidos (una hora), guardados en DATA_DIR/vistos.json: si Meta reenvía un mensaje justo
// después de un reinicio, no se responde dos veces.
const vistos = new MapaPersistente<number>('vistos', t => Date.now() - t < 3600_000);
const colas = new Map<string, Promise<void>>();

/** Procesa los mensajes de una misma persona en orden, uno detrás de otro. */
function encolar(m: MensajeEntrante): void {
  const anterior = colas.get(m.de) ?? Promise.resolve();
  // En el log solo va un prefijo del hash de la persona y el tipo de mensaje, nunca el contenido.
  const quien = almacen.hashDe(m.de).slice(0, 8);
  const siguiente = anterior
    .then(async () => {
      console.log(`[entrante] ${quien} ${m.entrada.tipo}`);
      await whatsapp.marcarLeido(m.messageId).catch(err => console.warn(`[leido] ${(err as Error).message}`));
      // «No podré ir» de una invitación por plantilla: se atiende aparte del flujo de conversación.
      // Nota de voz: se transcribe y sigue como si la persona lo hubiera escrito (si falla, ya se le respondió).
      let mensaje = m;
      if (m.entrada.tipo === 'audio') {
        const texto = await escucharAudio(m.de, m.entrada.mediaId, m.entrada.mime);
        if (texto === null) return;
        mensaje = { ...m, entrada: { tipo: 'texto', texto } };
      }
      if (!(await atenderRespuestaInvitacion(mensaje))) await atender(mensaje);
      console.log(`[respondido] ${quien}`);
    })
    .catch(err => console.error(`[flujo] error atendiendo ${m.messageId}:`, (err as Error).message))
    .finally(() => {
      if (colas.get(m.de) === siguiente) colas.delete(m.de);
    });
  colas.set(m.de, siguiente);
}

app.post('/webhook', (req: ConCuerpoCrudo, res: Response) => {
  // Modo prueba: antes de exigir la firma se comprueba que el secreto sea el de esta app de Meta.
  if (!config.appSecret && config.appSecretPrueba) {
    const firma = req.header('x-hub-signature-256');
    const ok = firmaValida(req.cuerpoCrudo, firma, config.appSecretPrueba);
    console.log(`[firma] modo prueba: ${ok ? 'COINCIDE' : 'NO coincide'} (${firma ? 'llegó con firma' : 'llegó sin firma'})`);
  }
  if (config.appSecret && !firmaValida(req.cuerpoCrudo, req.header('x-hub-signature-256'), config.appSecret)) {
    res.sendStatus(401);
    return;
  }
  // Se responde de inmediato: Meta reintenta si tardamos.
  res.sendStatus(200);
  const ahora = Date.now();
  vistos.limpiar();
  for (const m of parsearWebhook(req.body)) {
    // El número puede compartir cuenta con otros bots: solo se atiende el de Zanky.
    if (config.phoneNumberId && m.phoneNumberId !== config.phoneNumberId) {
      console.warn(`[webhook] mensaje para otro número (${m.phoneNumberId}), ignorado`);
      continue;
    }
    if (vistos.has(m.messageId)) continue;
    vistos.set(m.messageId, ahora);
    encolar(m);
  }
});

// --- Conversación con Zanky para la burbuja de la web -----------------------

const usosPorIp = new Map<string, number[]>();
let usosHora: number[] = [];

app.use('/chat', (req, res, next) => {
  const origen = req.header('origin') ?? '';
  if (config.chatOrigenes.includes(origen)) {
    res.setHeader('Access-Control-Allow-Origin', origen);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    res.setHeader('Access-Control-Max-Age', '600');
  }
  if (req.method === 'OPTIONS') {
    res.sendStatus(config.chatOrigenes.includes(origen) ? 204 : 403);
    return;
  }
  next();
});

app.post('/chat', async (req, res) => {
  if (!config.chatWeb) {
    res.sendStatus(404);
    return;
  }
  if (!iaActiva()) {
    res.status(503).json({ error: 'sin_ia', mensaje: 'Zanky está descansando un momento. Mientras tanto puedes reportar o ver las jornadas.' });
    return;
  }
  const ahora = Date.now();
  const ip = req.ip ?? 'desconocida';
  const propios = (usosPorIp.get(ip) ?? []).filter(t => ahora - t < 10 * 60_000);
  usosHora = usosHora.filter(t => ahora - t < 60 * 60_000);
  if (propios.length >= config.chatPorIp || usosHora.length >= config.chatPorHora) {
    res.status(429).json({ error: 'limite', mensaje: 'Me has preguntado mucho seguido 😅. Dame unos minutos y seguimos.' });
    return;
  }
  const mensajes = (req.body as { mensajes?: unknown })?.mensajes;
  const turnos: Turno[] = Array.isArray(mensajes)
    ? mensajes.slice(-12).map(m => ({ rol: (m as Turno)?.rol === 'zanky' ? 'zanky' : 'usuario', texto: String((m as Turno)?.texto ?? '') }))
    : [];
  if (!turnos.length || turnos[turnos.length - 1].rol !== 'usuario' || !turnos[turnos.length - 1].texto.trim()) {
    res.status(400).json({ error: 'sin_pregunta', mensaje: 'Escríbeme tu pregunta.' });
    return;
  }
  propios.push(ahora);
  usosPorIp.set(ip, propios);
  if (usosPorIp.size > 5000) for (const [k, v] of usosPorIp) if (!v.some(t => ahora - t < 10 * 60_000)) usosPorIp.delete(k);
  usosHora.push(ahora);
  try {
    res.json({ respuesta: await responder(turnos, 'web') });
  } catch (err) {
    // En el log va el error, nunca lo que escribió la persona.
    console.warn(`[chat] ${(err as Error).message.slice(0, 200)}`);
    res.status(err instanceof ErrorIA ? 502 : 500).json({ error: 'fallo', mensaje: 'Se me enredó la respuesta. ¿Me lo preguntas otra vez?' });
  }
});

// --- Alertas del manglar (públicas: datos del IDEAM, DIMAR, la C.R.A. y la comunidad) ---------

app.get('/alertas', async (req, res) => {
  // Datos públicos y sin nada personal: cualquier sitio puede mostrarlos.
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Cache-Control', 'public, max-age=60');
  try {
    res.json(req.query.simulacro === '1' ? await alertasSimulacro() : await alertasActuales());
  } catch (err) {
    console.warn(`[alertas] ${(err as Error).message}`);
    res.status(502).json({ error: 'sin_datos', mensaje: 'No pudimos leer las fuentes en este momento.' });
  }
});

// --- Datos abiertos (públicos, anonimizados) -------------------------------

app.get('/datos-abiertos/reportes.geojson', (_req, res) => {
  res.type('application/geo+json').send(JSON.stringify(aGeoJSON(almacen.todos())));
});
app.get('/datos-abiertos/reportes.csv', (_req, res) => {
  res.type('text/csv; charset=utf-8').attachment('reportes_manglar_atlantico.csv').send(aCSV(almacen.todos()));
});
app.get('/datos-abiertos/reportes.kml', (_req, res) => {
  res.type('application/vnd.google-earth.kml+xml').attachment('reportes_manglar_atlantico.kml').send(aKML(almacen.todos()));
});

// --- API del panel de la CRA (requiere x-api-key) --------------------------

function exigirClave(req: Request, res: Response, next: NextFunction): void {
  const clave = req.header('x-api-key') ?? '';
  const esperada = config.panelApiKey;
  const ok = esperada.length >= 16 && clave.length === esperada.length && timingSafeEqual(Buffer.from(clave), Buffer.from(esperada));
  if (!ok) {
    res.sendStatus(401);
    return;
  }
  next();
}

app.get('/api/reportes', exigirClave, (_req, res) => {
  // Ni el número ni a quién avisar salen por aquí: el panel los pide aparte y queda auditado (backend: ver_reportante).
  res.json(almacen.todos().map(({ reportanteHash, contacto, avisarA, ...r }) => ({ ...r, reportante: reportanteHash.slice(0, 12) })));
});

app.patch('/api/reportes/:codigo/estado', exigirClave, async (req, res) => {
  // Con el backend común conectado, el estado vive en Supabase: la C.R.A. lo cambia en el panel web con la RPC
  // cambiar_estado (rol y transiciones válidas, auditoría) y el bot se entera por el sondeo (backend/avisos.ts).
  // Cambiarlo aquí dejaría la copia del bot distinta de lo que ven la web y la app.
  if (backendActivo()) {
    res.status(409).json({ error: 'estado_en_backend', mensaje: 'El estado se cambia en el panel con cambiar_estado (Supabase); el bot avisa al ciudadano solo.' });
    return;
  }
  const { estado, por, nota } = req.body ?? {};
  if (!esEstado(estado)) {
    res.status(400).json({ error: 'estado_invalido' });
    return;
  }
  const r = almacen.cambiarEstado(
    String(req.params.codigo),
    estado,
    typeof por === 'string' && por.trim() ? por.trim().slice(0, 80) : 'panel-cra',
    typeof nota === 'string' ? nota.slice(0, 500) : undefined,
  );
  if (!r) {
    res.status(404).json({ error: 'no_existe' });
    return;
  }
  if (await avisarCambio(r.contacto, r.codigo, estado, typeof nota === 'string' ? nota.slice(0, 500) : undefined)) {
    r.estadoAvisado = estado;
    almacen.actualizar(r);
  }
  res.json(r);
});

app.get('/api/fotos/:archivo', exigirClave, (req, res) => {
  const ruta = almacen.rutaFoto(String(req.params.archivo));
  if (!ruta) {
    res.sendStatus(404);
    return;
  }
  res.sendFile(ruta);
});

// ---------------------------------------------------------------------------

/** Reintenta los reportes que el backend no recibió (caída, límite, sin señal del servidor). */
async function reintentarPendientes(): Promise<void> {
  if (!backendActivo()) return;
  for (const r of almacen.pendientesDeEnvio()) {
    if (r.envio.intentos >= 50) continue;
    const resultado = await enviarReporte(r);
    if (resultado === 'enviado' && r.avisarA) {
      await whatsapp.texto(r.avisarA, enviadoTarde(r.codigo)).catch(err => console.warn(`[aviso] ${(err as Error).message}`));
      delete r.avisarA;
      almacen.actualizar(r);
    }
  }
}

export function iniciar(): void {
  almacen.iniciarAlmacen();
  iniciarJornadas();
  const n = cargarZonas(config.zonasGeojson);
  const nArea = cargarAreaReporte(config.areaReporteGeojson);
  for (const aviso of avisosDeConfiguracion()) console.warn(`[config] ${aviso}`);
  iniciarAlertas();
  setInterval(() => void reintentarPendientes(), 60_000);
  void reintentarPendientes();
  // Aviso al ciudadano cuando la C.R.A. cambia el estado en el panel (sondeo de estado_de_reportes).
  if (backendActivo()) {
    setInterval(() => void sondearEstados().catch(err => console.warn(`[avisos] ${(err as Error).message}`)), config.sondeoEstadosMs);
    console.log(`[avisos] se pregunta por cambios de estado cada ${Math.round(config.sondeoEstadosMs / 1000)} s`);
  }
  // systemd manda SIGTERM al reiniciar: se guarda lo pendiente para que la conversación siga después.
  for (const senal of ['SIGTERM', 'SIGINT'] as const) {
    process.once(senal, () => {
      guardarSesiones();
      vistos.guardarYa();
      process.exit(0);
    });
  }
  app.listen(config.port, () => {
    console.log(`Zanky BOT escuchando en el puerto ${config.port} · ${n} zonas de manglar · ${nArea} polígonos de la cobertura C.R.A. (área de reporte)`);
  });
}

if (require.main === module) iniciar();
