import { Router, NextFunction, Request, Response } from 'express';
import { timingSafeEqual } from 'crypto';
import { config } from '../config';
import * as almacen from '../reportes/almacen';
import { iaActiva } from '../ia/zanky';
import * as J from './almacenJornadas';
import { Cuenta, ROLES_ADMIN, mascara, normalizarTelefono, rolDe, verificarCuenta } from './cuentas';
import { enviarInvitacion, imagenDe } from './plantilla';

/**
 * API de la web y del panel admin:
 *   públicos   GET /api/jornadas, GET /api/jornadas/:id, POST /api/jornadas/:id/inscripciones
 *   cuenta     POST /api/cuenta/contacto (token de Supabase)
 *   admin      /api/admin/… (cuenta con rol admin o moderador_cra, o x-api-key = PANEL_API_KEY desde el servidor)
 */
export const api = Router();

const origenes = () => new Set([...config.chatOrigenes, config.webUrl]);

api.use((req, res, next) => {
  const origen = req.header('origin') ?? '';
  if (origenes().has(origen)) {
    res.setHeader('Access-Control-Allow-Origin', origen);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.setHeader('Access-Control-Max-Age', '600');
  }
  if (req.method === 'OPTIONS') {
    res.sendStatus(origenes().has(origen) ? 204 : 403);
    return;
  }
  res.setHeader('Cache-Control', 'no-store');
  next();
});

const falla = (res: Response, status: number, error: string, mensaje: string) => res.status(status).json({ error, mensaje });
const tokenDe = (req: Request) => (req.header('authorization') ?? '').replace(/^Bearer\s+/i, '').trim();

const AVISO_EJEMPLO = 'Algunas jornadas son datos de ejemplo de la demostración.';
const avisoDe = (lista: J.JornadaGuardada[]) => (lista.some(j => j.ejemplo) ? AVISO_EJEMPLO : '');

// --- públicos -----------------------------------------------------------------------------------

api.get('/jornadas', (_req, res) => {
  const jornadas = J.jornadasPublicadas();
  res.json({ aviso: avisoDe(jornadas), jornadas });
});

api.get('/jornadas/:id', (req, res) => {
  const j = J.jornada(String(req.params.id));
  if (!j || j.estado !== 'publicada') return falla(res, 404, 'no_existe', 'No encontramos esa jornada.');
  res.json(j);
});

const intentos = new Map<string, number[]>();
function frenar(ip: string, max: number, ventanaMs: number): boolean {
  const ahora = Date.now();
  const propios = (intentos.get(ip) ?? []).filter(t => ahora - t < ventanaMs);
  if (propios.length >= max) return true;
  propios.push(ahora);
  intentos.set(ip, propios);
  if (intentos.size > 5000) for (const [k, v] of intentos) if (!v.some(t => ahora - t < ventanaMs)) intentos.delete(k);
  return false;
}

api.post('/jornadas/:id/inscripciones', async (req, res) => {
  if (frenar(`ins:${req.ip}`, 10, 10 * 60_000)) return falla(res, 429, 'limite', 'Hiciste varias inscripciones seguidas. Espera unos minutos.');
  const j = J.jornada(String(req.params.id));
  if (!j || j.estado !== 'publicada') return falla(res, 404, 'no_existe', 'No encontramos esa jornada.');
  if (Date.parse(j.fin) < Date.now()) return falla(res, 400, 'terminada', 'Esa jornada ya terminó.');
  const b = (req.body ?? {}) as Record<string, unknown>;
  const cuenta = await verificarCuenta(tokenDe(req));
  const nombre = (typeof b.nombre === 'string' ? b.nombre.trim().replace(/\s+/g, ' ') : '') || cuenta?.nombre || '';
  if (nombre.length < 2 || nombre.length > 80) return falla(res, 400, 'nombre', 'Escribe tu nombre.');
  if (b.acepta_datos !== true) return falla(res, 400, 'consentimiento', 'Para inscribirte hay que aceptar el tratamiento de datos.');
  const telefono = b.telefono ? normalizarTelefono(b.telefono) : cuenta?.telefono ?? null;
  if (b.telefono && !telefono) return falla(res, 400, 'telefono', 'Revisa el celular: escribe los 10 dígitos.');
  const r = J.inscribir(j, { nombre, telefono, cuenta_id: cuenta?.id ?? null, acepta_whatsapp: Boolean(telefono) && (b.acepta_whatsapp === true || Boolean(cuenta?.whatsappOk)) });
  res.status(201).json({ ok: true, id: r.id, inscritos: J.jornada(j.id)?.inscritos ?? 0 });
});

// --- cuenta -------------------------------------------------------------------------------------

api.post('/cuenta/contacto', async (req, res) => {
  const cuenta = await verificarCuenta(tokenDe(req));
  if (!cuenta) return falla(res, 401, 'sin_sesion', 'Tu sesión venció. Vuelve a iniciar sesión.');
  const c = J.guardarContacto({ cuenta_id: cuenta.id, nombre: cuenta.nombre, telefono: cuenta.telefono, whatsapp_ok: cuenta.whatsappOk, consentimiento_en: cuenta.whatsappConsentimientoEn });
  res.json({ ok: true, whatsapp_ok: c.whatsapp_ok, telefono_mascara: mascara(c.telefono) });
});

// --- admin --------------------------------------------------------------------------------------

type ConAdmin = Request & { admin?: { correo: string; rol: string } };

async function exigirAdmin(req: ConAdmin, res: Response, next: NextFunction): Promise<void> {
  const clave = req.header('x-api-key') ?? '';
  const esperada = config.panelApiKey;
  if (clave && esperada.length >= 16 && clave.length === esperada.length && timingSafeEqual(Buffer.from(clave), Buffer.from(esperada))) {
    req.admin = { correo: 'servidor', rol: 'admin' };
    return next();
  }
  const token = tokenDe(req);
  const cuenta: Cuenta | null = await verificarCuenta(token);
  if (!cuenta) {
    falla(res, 401, 'sin_sesion', 'Inicia sesión con tu cuenta para entrar al panel.');
    return;
  }
  const rol = await rolDe(token, cuenta);
  if (!rol || !ROLES_ADMIN.has(rol)) {
    falla(res, 403, 'sin_rol', 'Tu cuenta no tiene rol de administrador.');
    return;
  }
  req.admin = { correo: cuenta.correo, rol };
  next();
}

api.use('/admin', (req, res, next) => void exigirAdmin(req as ConAdmin, res, next));

api.get('/admin/yo', (req: ConAdmin, res) => res.json(req.admin));

const contar = <T>(lista: T[], clave: (x: T) => string | undefined) =>
  lista.reduce<Record<string, number>>((acc, x) => {
    const k = clave(x) ?? 'sin_dato';
    acc[k] = (acc[k] ?? 0) + 1;
    return acc;
  }, {});

api.get('/admin/resumen', (_req, res) => {
  const vigias = almacen.vigias();
  const reportes = almacen.todos();
  const publicadas = J.jornadasPublicadas();
  const todosLosEnvios = J.envios();
  const cuentas = J.contactos();
  res.json({
    bot: {
      simulacion: config.dryRun,
      ia: iaActiva(),
      vigias: vigias.length,
      vigias_por_municipio: contar(vigias, v => v.municipio),
      vigias_por_rol: contar(vigias, v => v.rol),
      reportes: {
        total: reportes.length,
        por_estado: contar(reportes, r => r.estado),
        por_tipo: contar(reportes, r => r.tipo),
        pendientes_envio: almacen.pendientesDeEnvio().length,
      },
    },
    cuentas: { con_whatsapp: cuentas.filter(c => c.whatsapp_ok).length, total_sincronizadas: cuentas.length },
    jornadas: { publicadas: publicadas.length, proximas: publicadas.filter(j => Date.parse(j.fin) > Date.now()).length, inscripciones: J.totalInscripciones() },
    envios: { total: todosLosEnvios.length, enviados: todosLosEnvios.filter(e => e.estado === 'enviado').length, fallidos: todosLosEnvios.filter(e => e.estado === 'fallido').length },
    plantilla: { nombre: config.plantillaInvitacion, idioma: config.plantillaIdioma, imagen_por_defecto: config.imagenInvitacion },
  });
});

api.get('/admin/jornadas', (_req, res) => {
  res.json({ jornadas: J.todasLasJornadas().map(j => ({ ...j, inscripciones_activas: J.activas(j.id) })) });
});

api.post('/admin/jornadas', (req: ConAdmin, res) => {
  const campos = J.validarJornada((req.body ?? {}) as Record<string, unknown>);
  if ('error' in campos) return falla(res, 400, 'invalida', campos.error);
  res.status(201).json(J.crearJornada(campos, req.admin?.correo ?? 'admin'));
});

api.patch('/admin/jornadas/:id', (req, res) => {
  const actual = J.jornada(String(req.params.id));
  if (!actual) return falla(res, 404, 'no_existe', 'No encontramos esa jornada.');
  const campos = J.validarJornada((req.body ?? {}) as Record<string, unknown>, actual);
  if ('error' in campos) return falla(res, 400, 'invalida', campos.error);
  const b = (req.body ?? {}) as Record<string, unknown>;
  const j = J.editarJornada(actual.id, campos);
  if (j && (b.estado === 'publicada' || b.estado === 'cancelada') && b.estado !== j.estado) {
    if (b.estado === 'cancelada') J.cancelarJornada(j.id);
  }
  res.json(J.jornada(actual.id));
});

api.delete('/admin/jornadas/:id', (req, res) => {
  if (!J.cancelarJornada(String(req.params.id))) return falla(res, 404, 'no_existe', 'No encontramos esa jornada.');
  res.json({ ok: true });
});

const csv = (v: unknown) => `"${String(v ?? '').replace(/"/g, '""')}"`;

api.get('/admin/jornadas/:id/inscritos', (req: ConAdmin, res) => {
  const j = J.jornada(String(req.params.id));
  if (!j) return falla(res, 404, 'no_existe', 'No encontramos esa jornada.');
  const lista = J.inscripcionesDe(j.id);
  if (req.query.formato === 'csv') {
    // El CSV es para organizar la jornada: lleva el celular completo. Queda registro de quién lo bajó.
    console.log(`[admin] ${req.admin?.correo} descargó inscritos de ${j.id}`);
    const filas = [['nombre', 'celular', 'acepta_whatsapp', 'con_cuenta', 'fecha', 'estado'].join(','),
      ...lista.map(i => [i.nombre, i.telefono ? `+${i.telefono}` : '', i.acepta_whatsapp ? 'si' : 'no', i.cuenta_id ? 'si' : 'no', i.fecha, i.estado].map(csv).join(','))];
    res.type('text/csv; charset=utf-8').attachment(`inscritos-${j.id}.csv`).send(`﻿${filas.join('\n')}`);
    return;
  }
  res.json({ inscritos: lista.map(i => ({ id: i.id, nombre: i.nombre, telefono_mascara: mascara(i.telefono), acepta_whatsapp: i.acepta_whatsapp, cuenta: Boolean(i.cuenta_id), fecha: i.fecha, estado: i.estado })) });
});

api.get('/admin/contactos', (_req, res) => {
  res.json({ contactos: J.contactos().map(c => ({ cuenta_id: c.cuenta_id, nombre: c.nombre, telefono_mascara: mascara(c.telefono), whatsapp_ok: c.whatsapp_ok, actualizado_en: c.actualizado_en })) });
});

let enviando = false;

api.post('/admin/invitaciones', async (req: ConAdmin, res) => {
  const b = (req.body ?? {}) as Record<string, unknown>;
  const j = J.jornada(String(b.jornada_id ?? ''));
  if (!j || j.estado !== 'publicada') return falla(res, 404, 'no_existe', 'Elige una jornada publicada.');
  const destino = String(b.destino ?? '');
  let lista: { nombre: string; telefono: string }[] = [];
  if (destino === 'cuentas') {
    lista = J.contactos().filter(c => c.whatsapp_ok && c.telefono).map(c => ({ nombre: c.nombre, telefono: c.telefono! }));
  } else if (destino === 'inscritos') {
    lista = J.inscripcionesDe(j.id).filter(i => i.estado === 'inscrita' && i.acepta_whatsapp && i.telefono).map(i => ({ nombre: i.nombre, telefono: i.telefono! }));
  } else if (destino === 'uno') {
    const c = J.contacto(String(b.cuenta_id ?? ''));
    if (c?.whatsapp_ok && c.telefono) lista = [{ nombre: c.nombre, telefono: c.telefono }];
  } else {
    return falla(res, 400, 'destino', 'Elige a quién enviar la invitación.');
  }
  // Un número recibe una sola invitación por envío.
  lista = [...new Map(lista.map(x => [x.telefono, x])).values()].slice(0, 300);
  if (!lista.length) return falla(res, 400, 'sin_destinatarios', 'No hay personas con WhatsApp autorizado para ese envío.');
  if (enviando) return falla(res, 409, 'ocupado', 'Ya hay un envío en curso. Espera a que termine.');
  enviando = true;
  const resultados: { nombre: string; telefono_mascara: string | null; estado: 'enviado' | 'fallido'; error?: string }[] = [];
  try {
    for (const p of lista) {
      try {
        const wamid = await enviarInvitacion(p.telefono, p.nombre, j);
        J.registrarEnvio({ jornada_id: j.id, nombre: p.nombre, telefono: p.telefono, estado: 'enviado', wamid, por: req.admin?.correo ?? 'admin' });
        resultados.push({ nombre: p.nombre, telefono_mascara: mascara(p.telefono), estado: 'enviado' });
      } catch (err) {
        const error = (err as Error).message;
        J.registrarEnvio({ jornada_id: j.id, nombre: p.nombre, telefono: p.telefono, estado: 'fallido', error, por: req.admin?.correo ?? 'admin' });
        resultados.push({ nombre: p.nombre, telefono_mascara: mascara(p.telefono), estado: 'fallido', error });
      }
      // Ritmo suave: WhatsApp limita los envíos por segundo.
      await new Promise(r => setTimeout(r, 250));
    }
  } finally {
    enviando = false;
  }
  console.log(`[invitaciones] ${req.admin?.correo} invitó a ${lista.length} a ${j.id}: ${resultados.filter(r => r.estado === 'enviado').length} enviadas`);
  res.json({ enviados: resultados.filter(r => r.estado === 'enviado').length, fallidos: resultados.filter(r => r.estado === 'fallido').length, imagen: imagenDe(j), resultados });
});

api.get('/admin/envios', (_req, res) => {
  const titulos = new Map(J.todasLasJornadas().map(j => [j.id, j.titulo]));
  res.json({ envios: J.envios().slice(0, 200).map(e => ({ fecha: e.fecha, jornada_id: e.jornada_id, jornada_titulo: titulos.get(e.jornada_id) ?? e.jornada_id, nombre: e.nombre, telefono_mascara: mascara(e.telefono), estado: e.estado, error: e.error, por: e.por })) });
});
