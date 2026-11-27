// Jornadas comunitarias: crear, invitar y compartir. Usa el mismo almacén de demostración que el
// seguimiento (lib/plataforma/estado.ts); en producción, crear y confirmar pasan por el backend.
import type { Accion, Jornada, TipoJornada } from '../../types/plataforma';
import { jornadas } from './estado';
import type { Resultado } from './estado';

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

export interface DatosJornada {
  titulo: string;
  tipo: TipoJornada;
  accion_id: string;
  fecha: string; // AAAA-MM-DD
  hora_inicio: string; // HH:MM
  hora_fin: string; // HH:MM
  punto_encuentro: string;
  cupos: number;
  que_llevar: string;
  descripcion: string;
}

/** Crea una jornada ligada a una acción; el punto del mapa es el de la acción. */
export function crearJornada(datos: DatosJornada, accionesDisponibles: Accion[]): Resultado<{ jornada: Jornada }> {
  const errores: Record<string, string> = {};
  const titulo = datos.titulo.trim();
  if (titulo.length < 5) errores.titulo = 'Escribe un nombre de al menos 5 letras.';
  if (titulo.length > 90) errores.titulo = 'El nombre es muy largo (máximo 90).';
  const accion = accionesDisponibles.find(a => a.id === datos.accion_id);
  if (!accion) errores.accion_id = 'Elige la acción a la que pertenece la jornada.';
  if (!/^\d{4}-\d{2}-\d{2}$/.test(datos.fecha)) errores.fecha = 'Elige la fecha.';
  if (!/^\d{2}:\d{2}$/.test(datos.hora_inicio) || !/^\d{2}:\d{2}$/.test(datos.hora_fin)) errores.hora_inicio = 'Elige la hora de inicio y de fin.';
  const inicio = `${datos.fecha}T${datos.hora_inicio}:00-05:00`;
  const fin = `${datos.fecha}T${datos.hora_fin}:00-05:00`;
  if (!errores.fecha && !errores.hora_inicio) {
    if (Date.parse(fin) <= Date.parse(inicio)) errores.hora_fin = 'La hora de fin debe ser después de la de inicio.';
    if (Date.parse(inicio) < Date.now() - 60 * 60 * 1000) errores.fecha = 'La jornada no puede quedar en el pasado.';
  }
  const punto = datos.punto_encuentro.trim();
  if (punto.length < 5) errores.punto_encuentro = 'Indica dónde se encuentran (al menos 5 letras).';
  if (!Number.isInteger(datos.cupos) || datos.cupos < 1 || datos.cupos > 500) errores.cupos = 'Los cupos van de 1 a 500.';
  if (datos.descripcion.length > 600) errores.descripcion = 'La descripción es muy larga (máximo 600).';
  if (Object.keys(errores).length || !accion) return { ok: false, errores };

  const jornada: Jornada = {
    id: `jornada-${crypto.randomUUID().slice(0, 8)}`,
    accion_id: accion.id,
    titulo,
    tipo: datos.tipo,
    inicio,
    fin,
    punto_encuentro: punto,
    lat: accion.lat,
    lon: accion.lon,
    cupos: datos.cupos,
    inscritos: 0,
    que_llevar: datos.que_llevar.split(/[,\n]/).map(x => x.trim()).filter(Boolean).slice(0, 12),
    descripcion: datos.descripcion.trim() || 'Jornada creada en esta demostración.',
  };
  jornadas.establecer(previo => [...previo, jornada]);
  return { ok: true, jornada };
}
