import actores from '../../data/plataforma/actores.json';
import acciones from '../../data/plataforma/acciones.json';
import cambios from '../../data/plataforma/cambiosAccion.json';
import jornadas from '../../data/plataforma/jornadas.json';
import monitoreos from '../../data/plataforma/monitoreos.json';
import type { Actor, Accion, CambioAccion, Jornada, ReporteMonitoreo } from '../../types/plataforma';

export const AVISO_DATOS_PLATAFORMA = 'Datos de ejemplo · Modo demostración · Se conectará al backend';
// Único lector de estos JSON. Aquí se conecta la API del backend.
// Los correos son privados: no pasar actores completos a vistas públicas.
export async function obtenerActores(): Promise<Actor[]> { return structuredClone(actores) as Actor[]; }
export async function obtenerAcciones(): Promise<Accion[]> { return structuredClone(acciones) as Accion[]; }
export async function obtenerCambiosAccion(): Promise<CambioAccion[]> { return structuredClone(cambios) as CambioAccion[]; }
export async function obtenerJornadas(): Promise<Jornada[]> { return structuredClone(jornadas) as Jornada[]; }
export async function obtenerMonitoreos(): Promise<ReporteMonitoreo[]> { return structuredClone(monitoreos) as ReporteMonitoreo[]; }
