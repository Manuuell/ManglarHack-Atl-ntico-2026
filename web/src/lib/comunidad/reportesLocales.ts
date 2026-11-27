// Reportes que la comunidad hace desde la web en este navegador (modo demostración).
// Se guardan en localStorage y se avisan en tiempo real a las otras pestañas abiertas
// (BroadcastChannel + evento storage). Con el backend, esto lo reemplaza la suscripción
// en tiempo real de Supabase y el reporte viaja al servidor.
import { useSyncExternalStore } from 'react';
import type { Reporte } from '../../types/manglar';

const CLAVE = 'zanky-web:v1:reportesComunidad';
const CANAL = 'zanky-comunidad';
const oyentes = new Set<() => void>();
let cache: Reporte[] | null = null;
let canal: BroadcastChannel | null = null;
let escuchando = false;
const VACIO: Reporte[] = [];

function leer(): Reporte[] {
  if (typeof window === 'undefined') return VACIO;
  try {
    const texto = window.localStorage.getItem(CLAVE);
    const datos = texto ? (JSON.parse(texto) as Reporte[]) : [];
    return Array.isArray(datos) ? datos : [];
  } catch {
    return [];
  }
}

function avisar(): void {
  cache = leer();
  oyentes.forEach((o) => o());
}

function escuchar(): void {
  if (escuchando || typeof window === 'undefined') return;
  escuchando = true;
  window.addEventListener('storage', (e) => { if (e.key === CLAVE || e.key === null) avisar(); });
  if ('BroadcastChannel' in window) {
    canal = new BroadcastChannel(CANAL);
    canal.onmessage = () => avisar();
  }
}

export function leerLocales(): Reporte[] {
  if (cache === null) cache = leer();
  return cache;
}

export function suscribirLocales(oyente: () => void): () => void {
  escuchar();
  oyentes.add(oyente);
  return () => { oyentes.delete(oyente); };
}

/** Guarda un reporte nuevo y lo avisa a esta pestaña y a las demás. */
export function agregarReporteLocal(r: Reporte): void {
  const lista = [...leerLocales().filter((x) => x.id !== r.id), r].slice(-200);
  try { window.localStorage.setItem(CLAVE, JSON.stringify(lista)); } catch { /* sin almacenamiento: queda en memoria */ }
  cache = lista;
  oyentes.forEach((o) => o());
  canal?.postMessage({ tipo: 'nuevo-reporte', id: r.id });
}

export function useReportesLocales(): Reporte[] {
  return useSyncExternalStore(suscribirLocales, leerLocales, () => VACIO);
}

/** Número de caso común a la app, el bot y el panel: ZK- + 4 hex del UUID. */
export function numeroDeCaso(id: string): string {
  return 'ZK-' + id.replace(/-/g, '').slice(0, 4).toUpperCase();
}
