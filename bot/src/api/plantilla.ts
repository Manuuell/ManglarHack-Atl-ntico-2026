import { config } from '../config';
import { bandejaSimulada } from '../whatsapp/cloudApi';
import type { JornadaGuardada } from './almacenJornadas';

/**
 * Invitación a una jornada con la plantilla aprobada de WhatsApp (por defecto nodo_recordatorio_evento):
 *   [imagen]  Hola {{1}}, mañana es tu evento.  *{{2}}*  🗓 {{3}}  📍 {{4}}
 *   Botones: «Ver el evento» (URL …/eventos/{{1}} → sufijo zanky-<id>, que nginx redirige a la web)
 *            «No podré ir» (respuesta rápida; llega al webhook con la carga no_ire:<id>)
 * Una plantilla sí llega fuera de la ventana de 24 horas desde el último mensaje de la persona.
 */
const zona = { timeZone: 'America/Bogota' } as const;

export function fechaInvitacion(j: JornadaGuardada): string {
  const dia = new Intl.DateTimeFormat('es-CO', { ...zona, weekday: 'long', day: 'numeric', month: 'long' }).format(new Date(j.inicio));
  const hora = new Intl.DateTimeFormat('es-CO', { ...zona, hour: 'numeric', minute: '2-digit' }).format(new Date(j.inicio));
  // «sábado, 28 de noviembre» → «Sábado 28 de noviembre», igual que la vista previa del panel.
  const sinComa = dia.replace(/^([^,]+),\s*/, '$1 ');
  return `${sinComa.charAt(0).toUpperCase()}${sinComa.slice(1)}, ${hora}`;
}

/** Meta rechaza parámetros con saltos de línea, tabulaciones o más de 4 espacios seguidos. */
const param = (s: string, max = 200) => s.replace(/[\n\r\t]+/g, ' ').replace(/ {2,}/g, ' ').trim().slice(0, max) || '-';

export function textoInvitacion(nombre: string, j: JornadaGuardada): string {
  return `Hola ${param(nombre, 60)}, mañana es tu evento.\n\n*${param(j.titulo)}*\n🗓 ${fechaInvitacion(j)}\n📍 ${param(j.punto_encuentro)}\n\nSi ya no puedes ir, retira tu asistencia para dejarle el lugar a alguien más.`;
}

export function imagenDe(j: JornadaGuardada): string {
  return j.imagen_url || config.imagenInvitacion;
}

export function payloadInvitacion(to: string, nombre: string, j: JornadaGuardada): Record<string, unknown> {
  return {
    messaging_product: 'whatsapp',
    to,
    type: 'template',
    template: {
      name: config.plantillaInvitacion,
      language: { code: config.plantillaIdioma },
      components: [
        { type: 'header', parameters: [{ type: 'image', image: { link: imagenDe(j) } }] },
        {
          type: 'body',
          parameters: [
            { type: 'text', text: param(nombre, 60) },
            { type: 'text', text: param(j.titulo) },
            { type: 'text', text: fechaInvitacion(j) },
            { type: 'text', text: param(j.punto_encuentro) },
          ],
        },
        { type: 'button', sub_type: 'url', index: '0', parameters: [{ type: 'text', text: `${config.prefijoBotonEvento}${j.id}` }] },
        { type: 'button', sub_type: 'quick_reply', index: '1', parameters: [{ type: 'payload', payload: `no_ire:${j.id}` }] },
      ],
    },
  };
}

/** Envía la invitación y devuelve el id del mensaje de WhatsApp. Lanza con el error de Meta en texto. */
export async function enviarInvitacion(to: string, nombre: string, j: JornadaGuardada): Promise<string> {
  const cuerpo = payloadInvitacion(to, nombre, j);
  if (config.dryRun) {
    bandejaSimulada.push(cuerpo);
    return `simulado-${Date.now()}`;
  }
  const res = await fetch(`https://graph.facebook.com/${config.graphVersion}/${config.phoneNumberId}/messages`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${config.token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(cuerpo),
    signal: AbortSignal.timeout(15_000),
  });
  const datos = (await res.json().catch(() => ({}))) as { messages?: { id?: string }[]; error?: { message?: string; code?: number; error_data?: { details?: string } } };
  if (!res.ok) {
    const e = datos.error;
    throw new Error(`${e?.code ?? res.status}: ${e?.error_data?.details ?? e?.message ?? 'Meta rechazó el envío'}`.slice(0, 300));
  }
  return datos.messages?.[0]?.id ?? '';
}
