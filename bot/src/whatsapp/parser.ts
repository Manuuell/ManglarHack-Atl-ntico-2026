/** Lo que escribió o envió la persona, ya normalizado. */
export type Entrada =
  | { tipo: 'texto'; texto: string }
  | { tipo: 'opcion'; id: string }
  | { tipo: 'ubicacion'; lat: number; lon: number; nombre?: string; direccion?: string }
  | { tipo: 'imagen'; mediaId: string; sha256?: string; mime?: string; caption?: string }
  | { tipo: 'otro'; clase: string };

export interface MensajeEntrante {
  /** Teléfono E.164 sin "+" o BSUID de WhatsApp. */
  de: string;
  nombrePerfil?: string;
  messageId: string;
  /** Segundos Unix, según WhatsApp. */
  timestamp: number;
  /** Número del negocio que recibió el mensaje. */
  phoneNumberId: string;
  entrada: Entrada;
}

type Obj = Record<string, any>;

function entradaDe(m: Obj): Entrada {
  switch (m.type) {
    case 'text':
      return { tipo: 'texto', texto: String(m.text?.body ?? '').slice(0, 2000) };
    case 'interactive': {
      const r = m.interactive?.button_reply ?? m.interactive?.list_reply;
      return r?.id ? { tipo: 'opcion', id: String(r.id) } : { tipo: 'otro', clase: 'interactive' };
    }
    case 'button':
      return { tipo: 'opcion', id: String(m.button?.payload || m.button?.text || '') };
    case 'location': {
      const lat = Number(m.location?.latitude);
      const lon = Number(m.location?.longitude);
      if (!Number.isFinite(lat) || !Number.isFinite(lon)) return { tipo: 'otro', clase: 'location' };
      return { tipo: 'ubicacion', lat, lon, nombre: m.location?.name, direccion: m.location?.address };
    }
    case 'image':
      return m.image?.id
        ? { tipo: 'imagen', mediaId: String(m.image.id), sha256: m.image.sha256, mime: m.image.mime_type, caption: m.image.caption }
        : { tipo: 'otro', clase: 'image' };
    default:
      return { tipo: 'otro', clase: String(m.type ?? 'desconocido') };
  }
}

/** Extrae los mensajes entrantes de un webhook de WhatsApp Cloud API. Ignora estados de envío. */
export function parsearWebhook(body: unknown): MensajeEntrante[] {
  const salida: MensajeEntrante[] = [];
  const entries = (body as Obj)?.entry;
  if (!Array.isArray(entries)) return salida;
  for (const entry of entries) {
    for (const change of entry?.changes ?? []) {
      if (change?.field !== 'messages') continue;
      const value: Obj = change.value ?? {};
      const phoneNumberId = String(value.metadata?.phone_number_id ?? '');
      for (const m of value.messages ?? []) {
        const de = m?.from ?? m?.from_user_id;
        if (!de || !m?.id) continue;
        if (m.type === 'reaction' || m.type === 'system') continue;
        const contacto = (value.contacts ?? []).find(
          (c: Obj) => c?.wa_id === m.from || (m.from_user_id && c?.user_id === m.from_user_id),
        );
        salida.push({
          de: String(de),
          nombrePerfil: contacto?.profile?.name,
          messageId: String(m.id),
          timestamp: Number(m.timestamp) || Math.floor(Date.now() / 1000),
          phoneNumberId,
          entrada: entradaDe(m),
        });
      }
    }
  }
  return salida;
}
