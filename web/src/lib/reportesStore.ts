import { useSyncExternalStore } from 'react';
import type { CambioEstado, EstadoReporte, Reporte, ReportePublico } from '../types/manglar';
import { TRANSICIONES } from './catalogos';
import { aReportePublico } from './privacidad';
import { leerLocales, suscribirLocales } from './comunidad/reportesLocales';
let reportes: Reporte[] | null = null;
let publicos: ReportePublico[] | null = null;
let historial: CambioEstado[] | null = null;
const vacios: Reporte[] = [];
const historialVacio: CambioEstado[] = [];
const publicosVacios: ReportePublico[] = [];
const listeners = new Set<() => void>();
export function suscribir(listener: () => void): () => void { listeners.add(listener); return () => { listeners.delete(listener); }; }
function notificar(): void { listeners.forEach((listener) => listener()); }
export function inicializarReportes(iniciales: Reporte[]): void {
 if (reportes !== null) return;
 reportes = iniciales; publicos = iniciales.map(aReportePublico);
 // Los reportes que la comunidad hace desde la portada (modo demostración) se suman en vivo.
 if (typeof window === 'undefined') return;
 const sumarLocales = (): boolean => {
  const nuevos = leerLocales().filter((l) => !(reportes ?? []).some((r) => r.id === l.id));
  if (!nuevos.length) return false;
  reportes = [...(reportes ?? []), ...nuevos]; publicos = reportes.map(aReportePublico); return true;
 };
 sumarLocales();
 suscribirLocales(() => { if (sumarLocales()) notificar(); });
}
export function obtenerReportesActuales(): Reporte[] { return reportes ?? vacios; }
// En producción lo hace el servidor: permiso en un solo lugar y auditoría.
// Esta demostración solo modifica memoria; no equivale a una autorización real.
export function cambiarEstado(id: string, estado: EstadoReporte, auditoria: { usuario_id: string; nota: string }): boolean {
 const reporte = reportes?.find((r) => r.id === id);
 if (!reporte || !TRANSICIONES[reporte.estado].some((t) => t.a === estado)) return false;
 const cambio: CambioEstado = { id: crypto.randomUUID(), reporte_id: id, estado, ...auditoria, fecha: new Date().toISOString() };
 reportes = (reportes ?? []).map((r) => r.id === id ? { ...r, estado } : r);
 publicos = reportes.map(aReportePublico);
 historial = [...(historial ?? []), cambio];
 notificar(); return true;
}
export function reemplazarReportes(nuevos: Reporte[]): void { reportes = nuevos.map((r) => ({ ...r })); publicos = reportes.map(aReportePublico); notificar(); }
export function useReportes(iniciales: Reporte[]): Reporte[] {
 if (typeof window !== 'undefined') inicializarReportes(iniciales);
 return useSyncExternalStore(suscribir, obtenerReportesActuales, () => iniciales);
}
export function useHistorial(iniciales: CambioEstado[]): CambioEstado[] {
 if (typeof window !== 'undefined' && historial === null) historial = iniciales;
 return useSyncExternalStore(suscribir, () => historial ?? historialVacio, () => iniciales);
}
// El mapa se suscribe a una proyección pública estable, nunca al registro privado.
export function useReportesPublicos(iniciales: ReportePublico[]): ReportePublico[] {
 if (typeof window !== 'undefined' && publicos === null) inicializarReportes(iniciales as unknown as Reporte[]);
 return useSyncExternalStore(suscribir, () => publicos ?? publicosVacios, () => iniciales);
}
