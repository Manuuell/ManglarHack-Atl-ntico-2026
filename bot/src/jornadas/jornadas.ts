import { config } from '../config';

/**
 * Jornadas comunitarias (siembras, limpiezas, recorridos de vigías, monitoreo). Las publica la web en
 * /datos/jornadas.json; el bot solo las lee y manda el enlace de la invitación, donde la persona se inscribe.
 */

export type TipoJornada = 'siembra' | 'limpieza' | 'recorrido_vigias' | 'monitoreo';

export interface Jornada {
  id: string;
  titulo: string;
  tipo: TipoJornada;
  inicio: string;
  fin: string;
  punto_encuentro: string;
  lat: number;
  lon: number;
  cupos: number;
  inscritos: number;
  que_llevar: string[];
  descripcion: string;
}

export const TIPOS_JORNADA: Record<TipoJornada, { nombre: string; emoji: string }> = {
  siembra: { nombre: 'Siembra', emoji: '🌱' },
  limpieza: { nombre: 'Limpieza', emoji: '🧹' },
  recorrido_vigias: { nombre: 'Recorrido de vigías', emoji: '👣' },
  monitoreo: { nombre: 'Monitoreo', emoji: '📏' },
};

let cache: { cuando: number; jornadas: Jornada[]; aviso: string } | null = null;
const CINCO_MIN = 5 * 60 * 1000;

function esJornada(x: any): x is Jornada {
  return x && typeof x.id === 'string' && typeof x.titulo === 'string' && typeof x.inicio === 'string' && typeof x.fin === 'string'
    && typeof x.punto_encuentro === 'string' && Number.isFinite(x.lat) && Number.isFinite(x.lon) && x.tipo in TIPOS_JORNADA;
}

/** Las jornadas que todavía no terminan, de la más próxima a la más lejana. */
export async function proximasJornadas(): Promise<{ jornadas: Jornada[]; aviso: string }> {
  if (!cache || Date.now() - cache.cuando > CINCO_MIN) {
    const res = await fetch(config.jornadasUrl, { signal: AbortSignal.timeout(8_000), headers: { Accept: 'application/json' } });
    if (!res.ok) throw new Error(`jornadas ${res.status}`);
    const datos = (await res.json()) as { aviso?: string; jornadas?: unknown[] };
    cache = { cuando: Date.now(), jornadas: (datos.jornadas ?? []).filter(esJornada), aviso: String(datos.aviso ?? '') };
  }
  const ahora = Date.now();
  return {
    aviso: cache.aviso,
    jornadas: cache.jornadas.filter(j => Date.parse(j.fin) > ahora).sort((a, b) => a.inicio.localeCompare(b.inicio)),
  };
}

export function buscarJornada(id: string): Jornada | undefined {
  return cache?.jornadas.find(j => j.id === id);
}

const zona = { timeZone: 'America/Bogota' } as const;
export const fmt = {
  corta: (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, day: 'numeric', month: 'short' }).format(new Date(iso)).replace('.', ''),
  larga: (iso: string) => {
    const t = new Intl.DateTimeFormat('es-CO', { ...zona, weekday: 'long', day: 'numeric', month: 'long' }).format(new Date(iso));
    return t.charAt(0).toUpperCase() + t.slice(1);
  },
  hora: (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, hour: 'numeric', minute: '2-digit' }).format(new Date(iso)),
};

/** Enlace de la invitación en la web, donde está la inscripción, el QR y el calendario. */
export function enlaceInvitacion(j: Jornada): string {
  return `${new URL(config.jornadasUrl).origin}/plataforma/jornadas?jornada=${encodeURIComponent(j.id)}`;
}

export function enlaceComoLlegar(j: Jornada): string {
  return `https://www.google.com/maps/dir/?api=1&destination=${j.lat},${j.lon}`;
}
