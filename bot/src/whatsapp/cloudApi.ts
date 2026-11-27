import { config } from '../config';

export interface Boton {
  id: string;
  titulo: string;
}

export interface Fila {
  id: string;
  titulo: string;
  descripcion?: string;
}

const BSUID = /^[A-Z]{2}\.(ENT\.)?[A-Za-z0-9]{1,128}$/;

/** Meta espera `to` para teléfonos y `recipient` para usuarios sin teléfono (BSUID). */
function destinatario(id: string): { to: string } | { recipient: string } {
  return BSUID.test(id) ? { recipient: id } : { to: id };
}

const graph = () => `https://graph.facebook.com/${config.graphVersion}`;

/** En modo simulación los mensajes se guardan aquí además de imprimirse. */
export const bandejaSimulada: Record<string, unknown>[] = [];

async function enviar(payload: Record<string, unknown>): Promise<void> {
  const cuerpo = { messaging_product: 'whatsapp', ...payload };
  if (config.dryRun) {
    bandejaSimulada.push(cuerpo);
    // En un servidor sin token la bandeja no debe crecer sin límite.
    if (bandejaSimulada.length > 200) bandejaSimulada.splice(0, bandejaSimulada.length - 200);
    return;
  }
  const res = await fetch(`${graph()}/${config.phoneNumberId}/messages`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${config.token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(cuerpo),
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) {
    throw new Error(`Meta respondió ${res.status}: ${(await res.text()).slice(0, 300)}`);
  }
}

export const whatsapp = {
  texto(to: string, texto: string) {
    return enviar({ ...destinatario(to), type: 'text', text: { body: texto.slice(0, 4096), preview_url: false } });
  },

  /** Hasta 3 botones; títulos de máximo 20 caracteres. */
  botones(to: string, cuerpo: string, botones: Boton[], encabezado?: string, pie?: string) {
    return enviar({
      ...destinatario(to),
      type: 'interactive',
      interactive: {
        type: 'button',
        header: encabezado ? { type: 'text', text: encabezado.slice(0, 60) } : undefined,
        body: { text: cuerpo.slice(0, 1024) },
        footer: pie ? { text: pie.slice(0, 60) } : undefined,
        action: {
          buttons: botones.slice(0, 3).map(b => ({ type: 'reply', reply: { id: b.id, title: b.titulo.slice(0, 20) } })),
        },
      },
    });
  },

  /** Lista desplegable: hasta 10 filas, título de fila de máximo 24 caracteres. */
  lista(to: string, cuerpo: string, textoBoton: string, filas: Fila[], encabezado?: string, pie?: string) {
    return enviar({
      ...destinatario(to),
      type: 'interactive',
      interactive: {
        type: 'list',
        header: encabezado ? { type: 'text', text: encabezado.slice(0, 60) } : undefined,
        body: { text: cuerpo.slice(0, 1024) },
        footer: pie ? { text: pie.slice(0, 60) } : undefined,
        action: {
          button: textoBoton.slice(0, 20),
          sections: [
            {
              title: 'Opciones',
              rows: filas.slice(0, 10).map(f => ({
                id: f.id,
                title: f.titulo.slice(0, 24),
                description: (f.descripcion ?? '').slice(0, 72),
              })),
            },
          ],
        },
      },
    });
  },

  /** Muestra el botón nativo "Enviar ubicación" de WhatsApp. */
  pedirUbicacion(to: string, cuerpo: string) {
    return enviar({
      ...destinatario(to),
      type: 'interactive',
      interactive: { type: 'location_request_message', body: { text: cuerpo.slice(0, 1024) }, action: { name: 'send_location' } },
    });
  },

  /** Marca como leído y muestra "escribiendo…" mientras el bot responde. */
  marcarLeido(messageId: string) {
    return enviar({ status: 'read', message_id: messageId, typing_indicator: { type: 'text' } });
  },

  /** Descarga una foto enviada por la persona. Devuelve null en modo simulación. */
  async descargarMedia(mediaId: string): Promise<{ datos: Buffer; mime: string; sha256?: string } | null> {
    if (config.dryRun) return null;
    const auth = { Authorization: `Bearer ${config.token}` };
    const meta = await fetch(`${graph()}/${encodeURIComponent(mediaId)}`, { headers: auth, signal: AbortSignal.timeout(15_000) });
    if (!meta.ok) throw new Error(`Media ${mediaId}: ${meta.status}`);
    const info = (await meta.json()) as { url?: string; mime_type?: string; sha256?: string; file_size?: number };
    if (!info.url) throw new Error(`Media ${mediaId} sin url`);
    if ((info.file_size ?? 0) > 16 * 1024 * 1024) throw new Error('Foto demasiado grande');
    const archivo = await fetch(info.url, { headers: auth, signal: AbortSignal.timeout(60_000) });
    if (!archivo.ok) throw new Error(`Descarga ${mediaId}: ${archivo.status}`);
    return { datos: Buffer.from(await archivo.arrayBuffer()), mime: info.mime_type ?? 'image/jpeg', sha256: info.sha256 };
  },
};
