// Jornadas comunitarias en JSON para otros canales (el bot de WhatsApp de Zanky las ofrece por chat).
// Solo datos públicos de la convocatoria: nunca inscripciones ni datos de personas.
import type { APIRoute } from 'astro';
import { AVISO_DATOS_PLATAFORMA, obtenerJornadas } from '../../lib/plataforma/datos';

export const prerender = true;

export const GET: APIRoute = async () => {
  const jornadas = (await obtenerJornadas()).map(({ id, accion_id, titulo, tipo, inicio, fin, punto_encuentro, lat, lon, cupos, inscritos, que_llevar, descripcion }) => ({
    id, accion_id, titulo, tipo, inicio, fin, punto_encuentro, lat, lon, cupos, inscritos, que_llevar, descripcion,
  }));
  return new Response(JSON.stringify({ aviso: AVISO_DATOS_PLATAFORMA, jornadas }), {
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
};
