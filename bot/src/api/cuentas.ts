import { config } from '../config';

/**
 * Cuentas de la web (Supabase Auth). El servidor no confía en lo que diga el navegador: con el token de la
 * persona le pregunta a Supabase quién es y qué datos tiene, y su rol en panel_roles (panel_rol_de solo
 * responde por uno mismo). Así no hace falta la clave de servicio.
 */
export interface Cuenta {
  id: string;
  correo: string;
  nombre: string;
  /** Solo dígitos, con indicativo (573001234567), o null. */
  telefono: string | null;
  whatsappOk: boolean;
  whatsappConsentimientoEn: string | null;
}

const objeto = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null;

/** 3001234567 → 573001234567; +57 300 123 4567 → 573001234567. Null si no parece un celular. */
export function normalizarTelefono(valor: unknown): string | null {
  if (typeof valor !== 'string' && typeof valor !== 'number') return null;
  let d = String(valor).replace(/\D/g, '');
  if (d.length === 10 && d.startsWith('3')) d = `57${d}`;
  return d.length >= 10 && d.length <= 15 ? d : null;
}

/** 573001234567 → +57 300 •••• 567 (para mostrar en el panel sin exponer el número). */
export function mascara(telefono: string | null | undefined): string | null {
  if (!telefono) return null;
  const pais = telefono.startsWith('57') ? '57' : telefono.slice(0, telefono.length - 10);
  const local = telefono.slice(pais.length);
  return `+${pais} ${local.slice(0, 3)} •••• ${local.slice(-3)}`;
}

const cache = new Map<string, { cuando: number; cuenta: Cuenta | null; rol?: string | null }>();

async function supabase(ruta: string, token: string, init: RequestInit = {}): Promise<Response> {
  return fetch(`${config.supabaseUrl}${ruta}`, {
    ...init,
    headers: { apikey: config.supabaseAnon, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', ...(init.headers as Record<string, string> | undefined) },
    signal: AbortSignal.timeout(10_000),
  });
}

/** La cuenta dueña del token, o null si el token no sirve. Se recuerda un minuto. */
export async function verificarCuenta(token: string): Promise<Cuenta | null> {
  if (!token || !config.supabaseUrl || !config.supabaseAnon) return null;
  const previo = cache.get(token);
  if (previo && Date.now() - previo.cuando < 60_000) return previo.cuenta;
  const res = await supabase('/auth/v1/user', token).catch(() => null);
  let cuenta: Cuenta | null = null;
  if (res?.ok) {
    const u: unknown = await res.json().catch(() => null);
    if (objeto(u) && typeof u.id === 'string') {
      const meta = objeto(u.user_metadata) ? u.user_metadata : {};
      const correo = typeof u.email === 'string' ? u.email.toLowerCase() : '';
      const telefono = normalizarTelefono(meta.telefono);
      cuenta = {
        id: u.id,
        correo,
        nombre: (typeof meta.nombre === 'string' && meta.nombre.trim()) || correo.split('@')[0] || 'Vecino',
        telefono,
        whatsappOk: Boolean(telefono) && meta.whatsapp_ok === true,
        whatsappConsentimientoEn: typeof meta.whatsapp_consentimiento_en === 'string' ? meta.whatsapp_consentimiento_en : null,
      };
    }
  }
  cache.set(token, { cuando: Date.now(), cuenta });
  if (cache.size > 2000) for (const [k, v] of cache) if (Date.now() - v.cuando > 60_000) cache.delete(k);
  return cuenta;
}

/** Rol de la cuenta en panel_roles (admin, moderador_cra, vigia, aliado) o null. */
export async function rolDe(token: string, cuenta: Cuenta): Promise<string | null> {
  const previo = cache.get(token);
  if (previo && previo.rol !== undefined && Date.now() - previo.cuando < 60_000) return previo.rol;
  let rol: string | null = null;
  const res = await supabase('/rest/v1/rpc/panel_rol_de', token, { method: 'POST', body: JSON.stringify({ uid: cuenta.id }) }).catch(() => null);
  if (res?.ok) {
    const v: unknown = await res.json().catch(() => null);
    rol = typeof v === 'string' ? v : null;
  }
  if (!rol && config.adminCorreos.includes(cuenta.correo)) rol = 'admin';
  cache.set(token, { cuando: previo?.cuando ?? Date.now(), cuenta, rol });
  return rol;
}

export const ROLES_ADMIN = new Set(['admin', 'moderador_cra']);
