import express, { NextFunction, Request, Response } from 'express';
import { timingSafeEqual } from 'crypto';
import { avisosDeConfiguracion, config } from './config';
import { parsearWebhook, MensajeEntrante } from './whatsapp/parser';
import { firmaValida } from './whatsapp/firma';
import { whatsapp } from './whatsapp/cloudApi';
import { cargarZonas } from './geo/zonas';
import * as almacen from './reportes/almacen';
import { aCSV, aGeoJSON, aKML } from './reportes/datosAbiertos';
import { esEstado } from './reportes/modelo';
import { atender, avisarCambio } from './flujos/zanky';
import { enviarReporte } from './backend/envio';
import { backendActivo } from './backend/supabase';
import { enviadoTarde } from './flujos/textos';

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

const vistos = new Map<string, number>();
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
      await atender(m);
      console.log(`[respondido] ${quien}`);
    })
    .catch(err => console.error(`[flujo] error atendiendo ${m.messageId}:`, (err as Error).message))
    .finally(() => {
      if (colas.get(m.de) === siguiente) colas.delete(m.de);
    });
  colas.set(m.de, siguiente);
}

app.post('/webhook', (req: ConCuerpoCrudo, res: Response) => {
  if (config.appSecret && !firmaValida(req.cuerpoCrudo, req.header('x-hub-signature-256'), config.appSecret)) {
    res.sendStatus(401);
    return;
  }
  // Se responde de inmediato: Meta reintenta si tardamos.
  res.sendStatus(200);
  const ahora = Date.now();
  for (const [id, t] of vistos) if (ahora - t > 3600_000) vistos.delete(id);
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
  await avisarCambio(r.contacto, r.codigo, estado);
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
  const n = cargarZonas(config.zonasGeojson);
  for (const aviso of avisosDeConfiguracion()) console.warn(`[config] ${aviso}`);
  setInterval(() => void reintentarPendientes(), 60_000);
  void reintentarPendientes();
  app.listen(config.port, () => {
    console.log(`Zanky BOT escuchando en el puerto ${config.port} · ${n} polígonos de manglar cargados`);
  });
}

if (require.main === module) iniciar();
