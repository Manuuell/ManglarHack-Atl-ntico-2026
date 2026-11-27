import { useSyncExternalStore } from 'react';
import type { EstadoReporte, Reporte } from '../types/manglar';

let reportes: Reporte[] | null = null;
const vacios: Reporte[] = [];
const listeners = new Set<() => void>();

export function inicializarReportes(iniciales: Reporte[]): void {
  if (reportes === null) reportes = iniciales;
}

export function obtenerReportesActuales(): Reporte[] {
  return reportes ?? vacios;
}

export function suscribir(listener: () => void): () => void {
  listeners.add(listener);
  return () => { listeners.delete(listener); };
}

function notificar(): void {
  listeners.forEach((listener) => listener());
}

export function actualizarEstado(id: string, estado: EstadoReporte): void {
  if (!reportes?.some((reporte) => reporte.id === id && reporte.estado !== estado)) return;
  reportes = reportes.map((reporte) => reporte.id === id ? { ...reporte, estado } : reporte);
  notificar();
}

export function reemplazarReportes(nuevos: Reporte[]): void {
  reportes = nuevos.map((reporte) => ({ ...reporte }));
  notificar();
}

export function useReportes(iniciales: Reporte[]): Reporte[] {
  // El servidor usa las props de cada render; el singleton pertenece al navegador.
  if (typeof window !== 'undefined') inicializarReportes(iniciales);
  return useSyncExternalStore(suscribir, obtenerReportesActuales, () => iniciales);
}
