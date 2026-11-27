// Jornadas comunitarias: invitar y compartir. Las jornadas y las inscripciones viven en el servidor de
// Zanky (jornadasApi.ts); se crean desde el panel de administración (/admin).
import type { Jornada } from '../../types/plataforma';

const zona = { timeZone: 'America/Bogota' } as const;
export const fmt = {
  dia: (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, day: 'numeric' }).format(new Date(iso)),
  mes: (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, month: 'short' }).format(new Date(iso)).replace('.', ''),
  diaSemana: (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, weekday: 'long' }).format(new Date(iso)),
  hora: (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, hour: 'numeric', minute: '2-digit' }).format(new Date(iso)),
  larga: (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }).format(new Date(iso)),
};

/** Enlace público de la invitación: abre la ficha de la jornada. */
export function urlInvitacion(id: string): string {
  const base = typeof window === 'undefined' ? '' : window.location.origin;
  return `${base}/plataforma/jornadas?jornada=${encodeURIComponent(id)}`;
}

// La experiencia «Interactúa con Zanky» es la versión web de la app (en /app/ del mismo sitio): en la
// jornada la gente registra su asistencia, habla con Zanky, hace el reto del manglar y reporta.
const URL_APP: string = import.meta.env.PUBLIC_URL_APP ?? 'https://mimanglar.sentralabs.co/app/';

/** Enlace del evento en la app: /app/?evento=<id>. Un código desconocido abre un evento genérico. */
export function urlEventoZanky(id: string): string {
  return `${URL_APP}?evento=${encodeURIComponent(id)}`;
}

const utc = (iso: string) => new Date(iso).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');

/** Agregar a Google Calendar (sin cuenta de la plataforma: lo abre el calendario de la persona). */
export function enlaceGoogleCalendar(j: Jornada, url: string): string {
  const p = new URLSearchParams({
    action: 'TEMPLATE',
    text: j.titulo,
    dates: `${utc(j.inicio)}/${utc(j.fin)}`,
    location: j.punto_encuentro,
    details: `${j.descripcion}\nQué llevar: ${j.que_llevar.join(', ')}\nInscripción: ${url}`,
    ctz: 'America/Bogota',
  });
  return `https://calendar.google.com/calendar/render?${p.toString()}`;
}

/** Cómo llegar al punto de encuentro (abre el mapa del teléfono). */
export function enlaceComoLlegar(j: Jornada): string {
  return `https://www.google.com/maps/dir/?api=1&destination=${j.lat},${j.lon}`;
}
