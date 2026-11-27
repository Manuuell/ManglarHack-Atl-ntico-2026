// Jornadas comunitarias en JSON para otros canales (la app de Zanky y la página de /app/ validan el ?evento=).
// Solo datos públicos de la convocatoria: nunca inscripciones ni datos de personas.
// La fuente de verdad es el servidor de Zanky (GET /api/jornadas del bot): este archivo se genera al construir
// con lo que hay ahí en ese momento. Si el servidor no responde, quedan las de ejemplo, marcadas como tales.
// Para datos al minuto, leer directamente https://zanqui.sentralabs.co/api/jornadas.
import type { APIRoute } from 'astro';
import { AVISO_DATOS_PLATAFORMA, obtenerJornadas } from '../../lib/plataforma/datos';
import { URL_BOT } from '../../lib/bot';
import type { Jornada } from '../../types/plataforma';

export const prerender = true;

type JornadaPublica = Jornada & { imagen_url?: string | null; ejemplo?: boolean };

const publica = ({ id, accion_id, titulo, tipo, inicio, fin, punto_encuentro, lat, lon, cupos, inscritos, que_llevar, descripcion, imagen_url, ejemplo }: JornadaPublica) => ({
  id, accion_id, titulo, tipo, inicio, fin, punto_encuentro, lat, lon, cupos, inscritos, que_llevar, descripcion,
  imagen_url: imagen_url ?? null, ejemplo: ejemplo ?? false,
});

async function delServidor(): Promise<{ aviso: string; jornadas: JornadaPublica[] } | null> {
  try {
    const res = await fetch(`${URL_BOT}/api/jornadas`, { signal: AbortSignal.timeout(10_000), headers: { Accept: 'application/json' } });
    if (!res.ok) return null;
    const datos = (await res.json()) as { aviso?: unknown; jornadas?: unknown };
    if (!Array.isArray(datos.jornadas) || !datos.jornadas.length) return null;
    return { aviso: typeof datos.aviso === 'string' ? datos.aviso : '', jornadas: datos.jornadas as JornadaPublica[] };
  } catch {
    return null;
  }
}

export const GET: APIRoute = async () => {
  const servidor = await delServidor();
  const cuerpo = servidor
    ? { aviso: servidor.aviso, fuente: `${URL_BOT}/api/jornadas`, jornadas: servidor.jornadas.map(publica) }
    : { aviso: AVISO_DATOS_PLATAFORMA, fuente: 'respaldo local (datos de ejemplo)', jornadas: (await obtenerJornadas()).map(j => publica({ ...j, ejemplo: true })) };
  if (!servidor) console.warn('[jornadas.json] el servidor de Zanky no respondió: se publican las de ejemplo');
  return new Response(JSON.stringify(cuerpo), { headers: { 'Content-Type': 'application/json; charset=utf-8' } });
};
