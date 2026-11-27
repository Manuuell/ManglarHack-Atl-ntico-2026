// Servidor de Zanky (el mismo del bot de WhatsApp, zanqui.sentralabs.co): guarda las jornadas, las
// inscripciones y los contactos de WhatsApp de las cuentas, y atiende el panel de administración.
// Las rutas de administración piden el token de una cuenta con rol de administrador (lib/cuenta.ts).
export const URL_BOT = String(import.meta.env.PUBLIC_BOT_URL ?? 'https://zanqui.sentralabs.co').replace(/\/+$/, '');

export class ErrorBot extends Error {
  constructor(mensaje: string, readonly status: number, readonly codigo = '') { super(mensaje); }
  /** No hubo respuesta (sin red, servidor caído o el navegador bloqueó la petición). */
  get sinConexion(): boolean { return this.status === 0; }
}

const POR_ESTADO: Record<number, string> = {
  400: 'Revisa los datos: el servidor no los aceptó.',
  401: 'Inicia sesión para continuar.',
  403: 'Tu cuenta no tiene rol de administrador.',
  404: 'No se encontró en el servidor.',
  409: 'No se pudo: alguien más lo cambió o ya no hay cupo.',
  429: 'Demasiados intentos seguidos. Espera unos minutos e inténtalo de nuevo.',
};

interface Opciones { metodo?: 'GET' | 'POST' | 'PATCH' | 'DELETE'; cuerpo?: unknown; token?: string | null }

/** Petición al servidor de Zanky que devuelve la respuesta tal cual (para descargar archivos). */
export async function pedirBotCrudo(ruta: string, o: Opciones = {}): Promise<Response> {
  let res: Response;
  try {
    res = await fetch(`${URL_BOT}${ruta}`, {
      method: o.metodo ?? 'GET',
      headers: {
        Accept: 'application/json',
        ...(o.cuerpo === undefined ? {} : { 'Content-Type': 'application/json' }),
        ...(o.token ? { Authorization: `Bearer ${o.token}` } : {}),
      },
      body: o.cuerpo === undefined ? undefined : JSON.stringify(o.cuerpo),
      signal: AbortSignal.timeout(25_000),
    });
  } catch {
    throw new ErrorBot('No hay conexión con el servidor de Zanky. Revisa tu internet e inténtalo de nuevo.', 0);
  }
  if (!res.ok) {
    let codigo = '';
    let mensaje = '';
    try {
      const d = (await res.json()) as { error?: unknown; mensaje?: unknown };
      codigo = typeof d.error === 'string' ? d.error : '';
      mensaje = typeof d.mensaje === 'string' ? d.mensaje : '';
    } catch { /* sin cuerpo JSON */ }
    throw new ErrorBot(mensaje || POR_ESTADO[res.status] || `El servidor de Zanky respondió con un error (${res.status}).`, res.status, codigo);
  }
  return res;
}

/** Petición al servidor de Zanky que devuelve el JSON de la respuesta. */
export async function pedirBot<T>(ruta: string, o: Opciones = {}): Promise<T> {
  const res = await pedirBotCrudo(ruta, o);
  if (res.status === 204) return undefined as T;
  try { return (await res.json()) as T; } catch { throw new ErrorBot('El servidor de Zanky respondió algo inesperado.', res.status); }
}
