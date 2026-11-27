import { BadgeCheck, Bird, Clock, FileWarning, MessageCircle, Smartphone, Sprout, Trash2, TriangleAlert, type LucideIcon } from 'lucide-react';
import type { EstadoReporte, Origen, PrioridadReporte, PrioridadZona, Reporte, TipoReporte } from '../types/manglar';

export const UMBRAL_IA = 80;

export const TIPOS: Record<TipoReporte, { etiqueta: string; icono: LucideIcon; descripcion: string }> = {
  amenaza: { etiqueta: 'Amenaza', icono: TriangleAlert, descripcion: 'Actividades que ponen en riesgo el manglar y su fauna.' },
  siembra: { etiqueta: 'Siembra', icono: Sprout, descripcion: 'Jornadas de siembra para recuperar el manglar.' },
  limpieza: { etiqueta: 'Limpieza', icono: Trash2, descripcion: 'Recolección comunitaria de residuos en el manglar.' },
  avistamiento: { etiqueta: 'Avistamiento', icono: Bird, descripcion: 'Observaciones de fauna en su hábitat natural.' },
};

export const PRIORIDADES: Record<PrioridadReporte, { etiqueta: string; color: string; chip: string; punto: string }> = {
  alta: { etiqueta: 'Alta', color: '#dc2626', chip: 'bg-alta-suave text-alta-texto ring-1 ring-inset ring-alta/25', punto: 'bg-alta' },
  media: { etiqueta: 'Media', color: '#d97706', chip: 'bg-media-suave text-media-texto ring-1 ring-inset ring-media/25', punto: 'bg-media' },
  baja: { etiqueta: 'Baja', color: '#16a34a', chip: 'bg-baja-suave text-baja-texto ring-1 ring-inset ring-baja/25', punto: 'bg-baja' },
};

export const PRIORIDADES_ZONA: Record<PrioridadZona, { etiqueta: string; color: string; relleno: string; opacidadRelleno: number; chip: string }> = {
  critica: { etiqueta: 'Crítica', color: '#7f1d1d', relleno: '#dc2626', opacidadRelleno: 0.32, chip: 'bg-critica-suave text-critica-texto ring-1 ring-inset ring-critica/25' },
  alta: { etiqueta: 'Alta', color: '#dc2626', relleno: '#f87171', opacidadRelleno: 0.24, chip: 'bg-alta-suave text-alta-texto ring-1 ring-inset ring-alta/25' },
  media: { etiqueta: 'Media', color: '#d97706', relleno: '#fbbf24', opacidadRelleno: 0.24, chip: 'bg-media-suave text-media-texto ring-1 ring-inset ring-media/25' },
  baja: { etiqueta: 'Baja', color: '#16a34a', relleno: '#4ade80', opacidadRelleno: 0.22, chip: 'bg-baja-suave text-baja-texto ring-1 ring-inset ring-baja/25' },
};

export const ESTADOS: Record<EstadoReporte, { etiqueta: string; chip: string; icono: LucideIcon }> = {
  pendiente: { etiqueta: 'Pendiente', chip: 'bg-fondo-alt text-suave ring-1 ring-inset ring-linea', icono: Clock },
  validado: { etiqueta: 'Validado', chip: 'bg-agua-50 text-agua-700 ring-1 ring-inset ring-agua-500/30', icono: BadgeCheck },
  escalado: { etiqueta: 'Escalado a expediente', chip: 'bg-manglar-900 text-white ring-1 ring-inset ring-manglar-900', icono: FileWarning },
};

export const ORIGENES: Record<Origen, { etiqueta: string; icono: LucideIcon }> = {
  whatsapp: { etiqueta: 'WhatsApp · Sanky', icono: MessageCircle },
  app: { etiqueta: 'App móvil', icono: Smartphone },
};

export const LISTA_TIPOS: TipoReporte[] = ['amenaza', 'siembra', 'limpieza', 'avistamiento'];
export const LISTA_PRIORIDADES: PrioridadReporte[] = ['alta', 'media', 'baja'];
export const LISTA_ESTADOS: EstadoReporte[] = ['pendiente', 'validado', 'escalado'];

export function esAmenazaCritica(r: Reporte): boolean {
  return r.tipo === 'amenaza' && r.prioridad === 'alta';
}

export function esValidadoPorIA(r: Reporte): boolean {
  return r.confianza_ia >= UMBRAL_IA;
}

export function nivelConfianza(n: number): PrioridadReporte {
  return n >= UMBRAL_IA ? 'alta' : n >= 60 ? 'media' : 'baja';
}

export function formatearFecha(iso: string, conHora = true): string {
  return new Intl.DateTimeFormat('es-CO', {
    timeZone: 'America/Bogota', day: 'numeric', month: 'short', year: 'numeric',
    ...(conHora ? { hour: 'numeric', minute: '2-digit', hour12: true } as const : {}),
  }).format(new Date(iso));
}
