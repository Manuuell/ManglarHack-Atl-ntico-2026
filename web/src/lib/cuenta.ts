// Cuentas de la comunidad: iniciar sesión y crear cuenta con Supabase Auth (correo y contraseña),
// por REST y solo con la clave pública, igual que lib/backend/supabase.ts. La sesión vive en este
// navegador (localStorage) y se renueva sola. Reportar NO exige cuenta: la cuenta solo suma (seguir
// los reportes propios, el perfil). Sin web/.env no hay servidor y el panel lo dice.
import { useSyncExternalStore } from 'react';
import { pedirBot } from './bot';

const URL_BASE = String(import.meta.env.PUBLIC_SUPABASE_URL ?? '').replace(/\/+$/, '');
const CLAVE = String(import.meta.env.PUBLIC_SUPABASE_ANON_KEY ?? '');

/** true si hay servidor para las cuentas. */
export const cuentasActivas = Boolean(URL_BASE && CLAVE);

const CLAVE_SESION = 'zanky-web:v1:sesion';
const EVENTO = 'zanky-cuenta';

export const SECTORES_CUENTA = ['Mallorquín', 'Balboa', 'Manatíes', 'Totumo'] as const;

export interface Usuario {
  id: string;
  correo: string;
  nombre: string;
  sector: string | null;
  creado_en: string | null;
  /** Celular en dígitos (57…) y si aceptó recibir invitaciones por WhatsApp. */
  telefono: string | null;
  whatsapp_ok: boolean;
}
export interface Sesion { access_token: string; refresh_token: string; expira_en: number; usuario: Usuario }

export class ErrorCuenta extends Error {}

/** Normaliza un celular colombiano: 10 dígitos que empiezan por 3 → con 57 adelante. null si va vacío. */
export function normalizarCelular(texto: string): string | null | 'invalido' {
  const d = texto.replace(/\D/g, '');
  if (!d) return null;
  const n = d.length === 10 && d.startsWith('3') ? `57${d}` : d;
  return n.length >= 10 && n.length <= 15 ? n : 'invalido';
}

/** Celular para mostrarlo: 57 300 123 4567 → 300 123 4567. */
export function celularLegible(n: string | null): string {
  if (!n) return '';
  const local = n.startsWith('57') && n.length === 12 ? n.slice(2) : n;
  return local.length === 10 ? `${local.slice(0, 3)} ${local.slice(3, 6)} ${local.slice(6)}` : local;
}

const objeto = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null;

function aUsuario(u: unknown): Usuario {
  if (!objeto(u) || typeof u.id !== 'string') throw new ErrorCuenta('El servidor respondió algo inesperado. Inténtalo de nuevo.');
  const meta = objeto(u.user_metadata) ? u.user_metadata : {};
  const correo = typeof u.email === 'string' ? u.email : '';
  const nombre = typeof meta.nombre === 'string' && meta.nombre.trim() ? meta.nombre.trim() : correo.split('@')[0] ?? '';
  return {
    id: u.id, correo, nombre,
    sector: typeof meta.sector === 'string' && meta.sector ? meta.sector : null,
    creado_en: typeof u.created_at === 'string' ? u.created_at : null,
    telefono: typeof meta.telefono === 'string' && meta.telefono ? meta.telefono : null,
    whatsapp_ok: meta.whatsapp_ok === true && typeof meta.telefono === 'string' && meta.telefono !== '',
  };
}

// --- sesión en este navegador -------------------------------------------------------------------
let cache: Sesion | null | undefined;

function leer(): Sesion | null {
  if (cache !== undefined) return cache;
  try {
    const v: unknown = JSON.parse(localStorage.getItem(CLAVE_SESION) ?? 'null');
    cache = objeto(v) && typeof v.access_token === 'string' && typeof v.refresh_token === 'string' && typeof v.expira_en === 'number' && objeto(v.usuario) ? (v as unknown as Sesion) : null;
  } catch { cache = null; }
  return cache;
}
function guardar(s: Sesion | null) {
  cache = s;
  try { if (s) localStorage.setItem(CLAVE_SESION, JSON.stringify(s)); else localStorage.removeItem(CLAVE_SESION); } catch { /* sin almacenamiento: la sesión dura lo que la pestaña */ }
  window.dispatchEvent(new Event(EVENTO));
}

/** La sesión de este navegador, o null. */
export function sesionActual(): Sesion | null {
  return typeof window === 'undefined' ? null : leer();
}

function suscribir(fn: () => void) {
  const alAlmacenar = (e: StorageEvent) => { if (e.key === CLAVE_SESION || e.key === null) { cache = undefined; fn(); } };
  window.addEventListener(EVENTO, fn);
  window.addEventListener('storage', alAlmacenar);
  return () => { window.removeEventListener(EVENTO, fn); window.removeEventListener('storage', alAlmacenar); };
}

/** Sesión actual, al día en todas las pestañas. */
export function useSesion(): Sesion | null {
  return useSyncExternalStore(suscribir, sesionActual, () => null);
}

// --- llamadas a Supabase Auth -------------------------------------------------------------------
function traducir(status: number, codigo: string, mensaje: string): string {
  const m = mensaje.toLowerCase();
  if (codigo === 'invalid_credentials' || m.includes('invalid login credentials')) return 'Correo o contraseña incorrectos.';
  if (codigo === 'email_not_confirmed' || m.includes('email not confirmed')) return 'Falta confirmar tu correo: abre el enlace que te enviamos y vuelve a entrar.';
  if (codigo === 'user_already_exists' || m.includes('already registered')) return 'Ya hay una cuenta con ese correo. Inicia sesión.';
  if (codigo === 'weak_password' || m.includes('password should')) return 'La contraseña es muy débil: usa al menos 8 caracteres, con letras y números.';
  if (codigo === 'email_address_not_authorized') return 'El servidor todavía no puede enviar correos a esa dirección (falta configurar su correo de salida). Inténtalo más tarde.';
  if (codigo === 'signup_disabled' || m.includes('signups not allowed')) return 'Por ahora no se pueden crear cuentas nuevas.';
  if (codigo === 'email_address_invalid' || m.includes('invalid format') || m.includes('unable to validate email')) return 'Revisa el correo: no parece válido.';
  if (codigo === 'same_password') return 'La contraseña nueva debe ser distinta de la anterior.';
  if (status === 429 || codigo.startsWith('over_')) return 'Demasiados intentos seguidos. Espera unos minutos e inténtalo de nuevo.';
  if (status === 401 || status === 403) return 'Tu sesión venció. Vuelve a iniciar sesión.';
  return `El servidor respondió con un error (${status}). Inténtalo de nuevo.`;
}

async function auth(ruta: string, opciones: { metodo?: 'GET' | 'POST' | 'PUT'; cuerpo?: unknown; token?: string } = {}): Promise<unknown> {
  if (!cuentasActivas) throw new ErrorCuenta('Las cuentas se activan cuando la web está conectada al servidor.');
  let res: Response;
  try {
    res = await fetch(`${URL_BASE}/auth/v1/${ruta}`, {
      method: opciones.metodo ?? 'POST',
      headers: { apikey: CLAVE, 'Content-Type': 'application/json', ...(opciones.token ? { Authorization: `Bearer ${opciones.token}` } : {}) },
      body: opciones.cuerpo === undefined ? undefined : JSON.stringify(opciones.cuerpo),
      signal: AbortSignal.timeout(20_000),
    });
  } catch {
    throw new ErrorCuenta('No hay conexión con el servidor. Revisa tu internet e inténtalo de nuevo.');
  }
  let datos: unknown = null;
  try { datos = await res.json(); } catch { /* sin cuerpo */ }
  if (!res.ok) {
    const d = objeto(datos) ? datos : {};
    const codigo = String(d.error_code ?? d.code ?? d.error ?? '');
    const mensaje = String(d.msg ?? d.error_description ?? d.message ?? '');
    throw new ErrorCuenta(traducir(res.status, codigo, mensaje));
  }
  return datos;
}

function aSesion(d: unknown): Sesion {
  if (!objeto(d) || typeof d.access_token !== 'string' || typeof d.refresh_token !== 'string') throw new ErrorCuenta('El servidor no devolvió una sesión. Inténtalo de nuevo.');
  const expira = typeof d.expires_at === 'number' ? d.expires_at * 1000 : Date.now() + Number(d.expires_in ?? 3600) * 1000;
  return { access_token: d.access_token, refresh_token: d.refresh_token, expira_en: expira, usuario: aUsuario(d.user) };
}

const volver = () => `${location.origin}/`;

/** Crea la cuenta. «sesion» si el servidor la deja entrar ya; «confirmar» si antes hay que confirmar el correo. */
export async function registrarse(p: { nombre: string; correo: string; clave: string; sector: string | null; telefono: string | null; whatsappOk: boolean }): Promise<'sesion' | 'confirmar'> {
  const ahora = new Date().toISOString();
  const whatsapp = Boolean(p.telefono && p.whatsappOk);
  const d = await auth(`signup?redirect_to=${encodeURIComponent(volver())}`, {
    cuerpo: {
      email: p.correo.trim(), password: p.clave,
      data: { nombre: p.nombre.trim(), sector: p.sector, consentimiento_ley_1581: ahora, telefono: p.telefono, whatsapp_ok: whatsapp, whatsapp_consentimiento_en: whatsapp ? ahora : null },
    },
  });
  if (objeto(d) && typeof d.access_token === 'string') { guardar(aSesion(d)); void sincronizarContacto(); return 'sesion'; }
  return 'confirmar';
}

export async function iniciarSesion(correo: string, clave: string): Promise<void> {
  guardar(aSesion(await auth('token?grant_type=password', { cuerpo: { email: correo.trim(), password: clave } })));
  void sincronizarContacto();
}

export async function cerrarSesion(): Promise<void> {
  const s = leer();
  guardar(null);
  if (s) await auth('logout', { token: s.access_token }).catch(() => undefined);
}

export async function recuperarClave(correo: string): Promise<void> {
  await auth(`recover?redirect_to=${encodeURIComponent(volver())}`, { cuerpo: { email: correo.trim() } });
}

/** Renueva el token si vence en menos de dos minutos. Si ya no sirve, cierra la sesión. */
export async function renovarSesion(): Promise<Sesion | null> {
  const s = leer();
  if (!s || s.expira_en - Date.now() > 120_000) return s;
  try {
    const nueva = aSesion(await auth('token?grant_type=refresh_token', { cuerpo: { refresh_token: s.refresh_token } }));
    guardar(nueva);
    return nueva;
  } catch (e) {
    // Sin red se conserva la sesión para reintentar; si el servidor la rechaza, se cierra.
    if (!(e instanceof ErrorCuenta) || !e.message.startsWith('No hay conexión')) guardar(null);
    return leer();
  }
}

async function conSesion(): Promise<Sesion> {
  const s = await renovarSesion();
  if (!s) throw new ErrorCuenta('Tu sesión venció. Vuelve a iniciar sesión.');
  return s;
}

export async function actualizarPerfil(p: { nombre: string; sector: string | null; telefono: string | null; whatsappOk: boolean }): Promise<void> {
  const s = await conSesion();
  const whatsapp = Boolean(p.telefono && p.whatsappOk);
  // La fecha del consentimiento de WhatsApp se fija al aceptarlo y se borra al retirarlo.
  const consentimiento = whatsapp ? (s.usuario.whatsapp_ok && s.usuario.telefono === p.telefono ? undefined : new Date().toISOString()) : null;
  const data: Record<string, unknown> = { nombre: p.nombre.trim(), sector: p.sector, telefono: p.telefono, whatsapp_ok: whatsapp };
  if (consentimiento !== undefined) data.whatsapp_consentimiento_en = consentimiento;
  const u = aUsuario(await auth('user', { metodo: 'PUT', token: s.access_token, cuerpo: { data } }));
  guardar({ ...s, usuario: u });
  void sincronizarContacto();
}

/**
 * Avisa al servidor de Zanky que la cuenta cambió: él lee de Supabase (no de este navegador) el nombre,
 * el celular y el permiso de WhatsApp, para las invitaciones del panel de administración. Si falla, no
 * bloquea nada: se reintenta en el próximo inicio de sesión o cambio de perfil.
 */
export async function sincronizarContacto(): Promise<void> {
  try {
    const s = await renovarSesion();
    if (s) await pedirBot('/api/cuenta/contacto', { metodo: 'POST', token: s.access_token, cuerpo: {} });
  } catch { /* sin servidor de Zanky: se reintenta después */ }
}

let adminCache: { token: string; yo: { correo: string; rol: string } | null } | null = null;

/** Rol de administración de la cuenta según el servidor de Zanky, o null si no tiene (o no hay servidor). */
export async function rolDeAdmin(): Promise<{ correo: string; rol: string } | null> {
  const s = await renovarSesion().catch(() => null);
  if (!s) return null;
  if (adminCache?.token === s.access_token) return adminCache.yo;
  let yo: { correo: string; rol: string } | null = null;
  try { yo = await pedirBot<{ correo: string; rol: string }>('/api/admin/yo', { token: s.access_token }); } catch { yo = null; }
  adminCache = { token: s.access_token, yo };
  return yo;
}

export async function cambiarClave(clave: string): Promise<void> {
  const s = await conSesion();
  await auth('user', { metodo: 'PUT', token: s.access_token, cuerpo: { password: clave } });
}

/**
 * Los enlaces del correo (confirmar cuenta o recuperar contraseña) vuelven a la web con la sesión en
 * el fragmento (#access_token=…). Se toma, se guarda y se limpia la barra de direcciones.
 */
export async function tomarSesionDelEnlace(): Promise<{ tipo: string } | { error: string } | null> {
  const hash = location.hash.slice(1);
  if (!hash.includes('access_token=') && !hash.includes('error_description=')) return null;
  const p = new URLSearchParams(hash);
  history.replaceState(null, '', location.pathname + location.search);
  if (p.get('error_description')) {
    const vencido = p.get('error_code') === 'otp_expired';
    return { error: vencido ? 'El enlace del correo venció o ya se usó. Pide uno nuevo.' : 'No se pudo usar el enlace del correo. Pide uno nuevo.' };
  }
  const access = p.get('access_token') ?? '';
  const refresh = p.get('refresh_token') ?? '';
  const usuario = aUsuario(await auth('user', { metodo: 'GET', token: access }));
  guardar({ access_token: access, refresh_token: refresh, expira_en: Date.now() + Number(p.get('expires_in') ?? 3600) * 1000, usuario });
  void sincronizarContacto();
  return { tipo: p.get('type') ?? 'signup' };
}
