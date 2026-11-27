import { config } from '../config';
import { enlaceEventoZanky, enlaceInvitacion, fmt, proximasJornadas } from '../jornadas/jornadas';

/**
 * El «cerebro» conversacional de Zanky (OpenAI), compartido por la burbuja de la web (POST /chat) y por
 * WhatsApp (preguntas libres en el menú). Reportar, registrarse y las jornadas siguen siendo flujos guiados:
 * aquí solo se conversa, se explica y se lleva a la persona hacia esos flujos. La clave vive solo en el
 * servidor (.env), nunca en la web.
 */

export interface Turno {
  rol: 'usuario' | 'zanky';
  texto: string;
}

export type Canal = 'web' | 'whatsapp';

export function iaActiva(): boolean {
  return Boolean(config.openaiKey);
}

export class ErrorIA extends Error {}

const PERSONALIDAD = `Eres Zanky, la mascota del monitoreo comunitario del manglar del Atlántico (Colombia), de la Corporación Autónoma Regional del Atlántico (C.R.A.). Tu nombre viene de los zancos del mangle rojo y de los zanqueros del Carnaval de Barranquilla.

Cómo hablas: español del Caribe colombiano, cálido y sencillo, como un vecino que sabe del manglar. Frases cortas, sin tecnicismos. Máximo un emoji por respuesta. Tuteas.

En qué ayudas:
- Explicar el manglar: mangle rojo, negro, blanco y zaragoza; protege la costa de la erosión y las marejadas, es vivero de peces, cangrejos y aves, y guarda mucho carbono (carbono azul).
- Reconocer amenazas: tala, quemas, rellenos o construcciones, vertimientos, basuras, caños taponados y fauna afectada.
- Llevar a la persona a reportar lo que ve. {COMO_REPORTAR}
- Contar las próximas jornadas comunitarias (siembras, limpiezas, recorridos de vigías) con los datos de abajo.

Datos con fuente que puedes usar (workflow de la C.R.A., manglarcra.netlify.app): en 2025 hay unas 775 ha de manglar probable en el Atlántico; sectores Mallorquín, Balboa, Manatíes y Totumo; entre 2016 y 2025 se perdieron unas 34,7 ha.

Reglas:
- No inventes cifras, fechas, lugares, nombres, leyes ni teléfonos. Si no lo sabes, dilo y sugiere consultar con la C.R.A.
- Si alguien describe algo que está pasando ahora (un incendio, gente talando), pídele que se ponga a salvo y que lo reporte; si hay fuego o peligro para las personas, que llame a la línea de emergencias 123.
- No pidas datos personales (cédula, dirección, teléfono). No des asesoría legal ni médica.
- Tú no cambias el estado de un reporte ni decides su prioridad: eso lo hace la C.R.A. y su servidor.
- Si te piden algo que no tiene que ver con el manglar, el ambiente o la comunidad, responde amable en una frase y vuelve al tema.
- Sé breve: {LARGO}.`;

const COMO_REPORTAR: Record<Canal, string> = {
  whatsapp: 'Aquí en WhatsApp basta con escribir «reportar» (o tocar el botón Reportar) y yo le pido el tipo, la ubicación y la foto.',
  web: 'En la página está el botón «Reportar un problema» (marca el sitio en el mapa y sube una foto); también se puede por WhatsApp con Zanky BOT o desde la app.',
};
const LARGO: Record<Canal, string> = {
  whatsapp: 'máximo unas 70 palabras, sin títulos ni listas largas',
  web: 'máximo unas 90 palabras; puedes usar una lista corta si ayuda',
};

async function contextoJornadas(canal: Canal): Promise<string> {
  try {
    const { jornadas } = await proximasJornadas();
    if (!jornadas.length) return 'Próximas jornadas: no hay jornadas publicadas por ahora.';
    const lineas = jornadas.slice(0, 4).map(j =>
      `- ${j.titulo}: ${fmt.larga(j.inicio)}, ${fmt.hora(j.inicio)} a ${fmt.hora(j.fin)}, en ${j.punto_encuentro}. ` +
      `Cupos libres: ${Math.max(0, j.cupos - j.inscritos)} de ${j.cupos}. Inscripción: ${enlaceInvitacion(j)} · Ese día, con Zanky: ${enlaceEventoZanky(j)}` +
      (canal === 'whatsapp' ? ' (o escribir «jornadas» aquí)' : ''),
    );
    return `Próximas jornadas (datos de la plataforma; si dicen «Datos de ejemplo», acláralo):\n${lineas.join('\n')}`;
  } catch {
    return 'Próximas jornadas: no se pudieron consultar ahora; sugiere verlas en mimanglar.sentralabs.co/plataforma/jornadas.';
  }
}

/** Recorta y limpia el historial: últimos 10 turnos, 800 caracteres por turno. */
export function limpiarHistorial(turnos: Turno[]): Turno[] {
  return turnos
    .filter(t => (t.rol === 'usuario' || t.rol === 'zanky') && typeof t.texto === 'string' && t.texto.trim())
    .slice(-10)
    .map(t => ({ rol: t.rol, texto: t.texto.trim().slice(0, 800) }));
}

/** La respuesta de Zanky a la conversación. El último turno debe ser de la persona. */
export async function responder(historial: Turno[], canal: Canal): Promise<string> {
  if (!iaActiva()) throw new ErrorIA('sin_ia');
  const turnos = limpiarHistorial(historial);
  if (!turnos.length || turnos[turnos.length - 1].rol !== 'usuario') throw new ErrorIA('sin_pregunta');
  const sistema =
    PERSONALIDAD.replace('{COMO_REPORTAR}', COMO_REPORTAR[canal]).replace('{LARGO}', LARGO[canal]) +
    `\n\nHoy es ${fmt.larga(new Date().toISOString())} (hora de Colombia).\n${await contextoJornadas(canal)}`;
  let res: Response;
  try {
    res = await fetch(`${config.openaiUrl}/chat/completions`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${config.openaiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: config.openaiModel,
        messages: [
          { role: 'system', content: sistema },
          ...turnos.map(t => ({ role: t.rol === 'usuario' ? 'user' : 'assistant', content: t.texto })),
        ],
        max_completion_tokens: 400,
      }),
      signal: AbortSignal.timeout(25_000),
    });
  } catch (err) {
    throw new ErrorIA(`sin conexión con OpenAI: ${(err as Error).message}`);
  }
  if (!res.ok) throw new ErrorIA(`OpenAI ${res.status}: ${(await res.text()).slice(0, 200)}`);
  const datos = (await res.json()) as { choices?: { message?: { content?: string } }[] };
  const texto = datos.choices?.[0]?.message?.content?.trim();
  if (!texto) throw new ErrorIA('OpenAI respondió vacío');
  return texto.slice(0, 1500);
}
