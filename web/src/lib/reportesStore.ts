import { useSyncExternalStore } from 'react';
import type { CambioEstado, EstadoReporte, Reporte, ReportePublico } from '../types/manglar';
import { TRANSICIONES } from './catalogos';
import { aReportePublico } from './privacidad';
import { leerLocales, suscribirLocales } from './comunidad/reportesLocales';
import { backendActivo, leerReportesPublicos, type FilaPublica } from './backend/supabase';
import { obtenerPoligonos } from './datos';
import { sectorDePunto } from './plataforma/geo';
import type { ZonasManglar } from '../types/manglar';
let reportes: Reporte[] | null = null;
let publicos: ReportePublico[] | null = null;
let historial: CambioEstado[] | null = null;
const vacios: Reporte[] = [];
const historialVacio: CambioEstado[] = [];
const publicosVacios: ReportePublico[] = [];
const listeners = new Set<() => void>();
// Con el backend conectado, lo público (mapas y avisos) sale del servidor: reportes reales de la app, la web
// y WhatsApp. El panel sigue con sus datos de demostración hasta tener sesión con rol de la C.R.A.
let publicosServidor: ReportePublico[] | null = null;
let estadoServidor: 'apagado' | 'cargando' | 'listo' | 'error' = backendActivo ? 'cargando' : 'apagado';
const CINCO_MIN = 5 * 60 * 1000;
export function suscribir(listener: () => void): () => void { listeners.add(listener); return () => { listeners.delete(listener); }; }
function notificar(): void { listeners.forEach((listener) => listener()); }
export function inicializarReportes(iniciales: Reporte[]): void {
 if (reportes !== null) return;
 reportes = iniciales; publicos = backendActivo ? [] : iniciales.map(aReportePublico);
 if (typeof window === 'undefined') return;
 if (backendActivo) {
  // Lo recién enviado desde este navegador se ve al instante; el servidor lo confirma en la siguiente lectura.
  suscribirLocales(() => { recomponerConServidor(); notificar(); });
  void sincronizarConServidor();
  window.setInterval(() => { if (document.visibilityState === 'visible') void sincronizarConServidor(); }, 20_000);
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') void sincronizarConServidor(); });
  return;
 }
 // Modo demostración: los reportes que la comunidad hace desde la portada se suman en vivo.
 const sumarLocales = (): boolean => {
  const nuevos = leerLocales().filter((l) => !(reportes ?? []).some((r) => r.id === l.id));
  if (!nuevos.length) return false;
  reportes = [...(reportes ?? []), ...nuevos]; publicos = reportes.map(aReportePublico); return true;
 };
 sumarLocales();
 suscribirLocales(() => { if (sumarLocales()) notificar(); });
}

let sectores: ZonasManglar | null = null;
/** Fila de la vista pública → reporte público de la web. El sector sale del punto con los polígonos de la
 *  web (los mismos del mapa); lo que el servidor no publica (descripción, confianza) queda vacío. */
function deFila(f: FilaPublica): ReportePublico {
 const s = sectores ? sectorDePunto(f.lat, f.lon, sectores) : null;
 const sector = s?.sector ? sectores!.features.find((z) => z.properties.id === s.sector)?.properties : undefined;
 return {
  id: f.id_publico, canal: f.canal, tipo: f.tipo, descripcion: '', lat: f.lat, lon: f.lon,
  capturado_en: f.capturado_en, recibido_en: f.capturado_en,
  zona: sector?.nombre ?? null, municipio: sector?.municipio ?? f.municipio ?? 'Atlántico',
  dentro_poligono: s?.dentro ?? false, distancia_m: s && Number.isFinite(s.distancia_m) ? Math.round(s.distancia_m) : null,
  prioridad: f.prioridad, confianza: 0, estado: f.estado, ia_tipo_detectado: null, ia_confianza: null,
  ubicacion_aproximada: true, origen: 'servidor',
 };
}
function recomponerConServidor(): void {
 const delServidor = publicosServidor ?? [];
 const ids = new Set(delServidor.map((r) => r.id));
 // Los locales llevan el id público que devolvió el servidor: cuando la lectura los trae, no se duplican.
 const recientes = leerLocales().filter((l) => !ids.has(l.id) && Date.now() - Date.parse(l.recibido_en) < CINCO_MIN).map(aReportePublico);
 publicos = [...recientes, ...delServidor];
}
let sincronizando = false;
/** Relee los reportes públicos del servidor (la web no recibe Realtime: anon no tiene permiso). */
export async function sincronizarConServidor(): Promise<void> {
 if (!backendActivo || sincronizando) return;
 sincronizando = true;
 try {
  sectores ??= await obtenerPoligonos();
  publicosServidor = (await leerReportesPublicos()).map(deFila);
  estadoServidor = 'listo';
 } catch (err) {
  console.warn('[reportes] no se pudo leer el servidor:', (err as Error).message);
  if (estadoServidor !== 'listo') estadoServidor = 'error';
 } finally {
  sincronizando = false;
  recomponerConServidor(); notificar();
 }
}
/** 'apagado' (modo demostración), 'cargando', 'listo' o 'error' (no se pudo leer el servidor). */
export function estadoDelServidor(): typeof estadoServidor { return estadoServidor; }
export function obtenerPublicosActuales(): ReportePublico[] { return publicos ?? publicosVacios; }
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
