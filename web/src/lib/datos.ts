// Aquí se reemplaza el mock por la base de datos y el GeoJSON oficial de la C.R.A.
import reportes from '../data/mockReportes.json';
import poligonos from '../data/poligonosManglar.json';
import colegios from '../data/colegios.json';
import type { CambioEstado, CapaManglarCRA, CapaPrioridades, Colegio, PropiedadesInvemar, Reporte, ZonasManglar } from '../types/manglar';

export async function obtenerReportes(): Promise<Reporte[]> {
  return structuredClone(reportes) as Reporte[];
}

export async function obtenerPoligonos(): Promise<ZonasManglar> {
  return structuredClone(poligonos) as unknown as ZonasManglar;
}

export async function obtenerColegios(): Promise<Colegio[]> {
  return structuredClone(colegios).sort((a, b) => b.puntos - a.puntos);
}

import historial from '../data/historialEstados.json';
import urlCapaInvemar from '../../../datos/manglares_atlantico_invemar_2020.geojson?url';
import type { FeatureCollection, Polygon } from 'geojson';
export const URL_CAPA_INVEMAR = urlCapaInvemar;
export async function obtenerHistorial(): Promise<CambioEstado[]> { return structuredClone(historial) as CambioEstado[]; }
function objeto(v: unknown): v is Record<string, unknown> { return typeof v === 'object' && v !== null; }
function esCapa(v: unknown): v is FeatureCollection<Polygon, PropiedadesInvemar> {
 if (!objeto(v) || v.type !== 'FeatureCollection' || !Array.isArray(v.features)) return false;
 return v.features.every((f: unknown) => {
  if (!objeto(f) || f.type !== 'Feature' || !objeto(f.geometry) || f.geometry.type !== 'Polygon' || !objeto(f.properties)) return false;
  const p = f.properties; const anillos = f.geometry.coordinates;
  return typeof p.AREA_HA === 'number' && Number.isFinite(p.AREA_HA) && p.AREA_HA >= 0 && ['COBERTURA', 'FECHA_IMAG', 'ESCALA'].every((c) => typeof p[c] === 'string') &&
   Array.isArray(anillos) && anillos.length > 0 && anillos.every((anillo: unknown) => Array.isArray(anillo) && anillo.length >= 4 &&
    anillo.every((punto: unknown) => Array.isArray(punto) && punto.length >= 2 && punto.every((n: unknown) => typeof n === 'number' && Number.isFinite(n))) && JSON.stringify(anillo[0]) === JSON.stringify(anillo[anillo.length - 1]));
 });
}
export async function obtenerCapaManglar(): Promise<FeatureCollection<Polygon, PropiedadesInvemar>> {
 const respuesta = await fetch(URL_CAPA_INVEMAR);
 if (!respuesta.ok) throw new Error('No se pudo cargar la capa de INVEMAR');
 const capa: unknown = await respuesta.json();
 if (!esCapa(capa)) throw new Error('La capa de INVEMAR no contiene una colección válida de polígonos');
 return capa;
}

// Capa «Prioridades de conservación» de la C.R.A. (KMZ entregado por la
// Corporación), recortada a los sectores del manglar por scripts/prioridades-cra.mjs.
export const URL_CAPA_PRIORIDADES = '/datos/prioridades-cra.geojson';
export async function obtenerCapaPrioridades(): Promise<CapaPrioridades> {
 const respuesta = await fetch(URL_CAPA_PRIORIDADES);
 if (!respuesta.ok) throw new Error('No se pudo cargar la capa de prioridades de la C.R.A.');
 const capa: unknown = await respuesta.json();
 const acciones = ['preservacion', 'restauracion', 'recuperacion', 'rehabilitacion'];
 const niveles = ['alta', 'media', 'baja'];
 const valida = objeto(capa) && capa.type === 'FeatureCollection' && Array.isArray(capa.features) && capa.features.every((f: unknown) =>
  objeto(f) && objeto(f.geometry) && (f.geometry.type === 'Polygon' || f.geometry.type === 'MultiPolygon') && objeto(f.properties) &&
  acciones.includes(String(f.properties.accion)) && niveles.includes(String(f.properties.prioridad)));
 if (!valida) throw new Error('La capa de prioridades de la C.R.A. no tiene el formato esperado');
 return capa as unknown as CapaPrioridades;
}

// Cobertura de manglar de la C.R.A. a escala 1:5.000 (geodatabase entregada por
// la Corporación; copia ligera generada por scripts/manglar-cra.mjs).
export const URL_CAPA_MANGLAR_CRA = '/datos/manglar-cra.geojson';
export const FUENTE_MANGLAR_CRA = 'Cobertura de manglar del Atlántico, C.R.A., escala 1:5.000 (imágenes Maxar 2021–2022, verificación en campo)';
export async function obtenerCapaManglarCRA(): Promise<CapaManglarCRA> {
 const respuesta = await fetch(URL_CAPA_MANGLAR_CRA);
 if (!respuesta.ok) throw new Error('No se pudo cargar la cobertura de manglar de la C.R.A.');
 const capa: unknown = await respuesta.json();
 const valida = objeto(capa) && capa.type === 'FeatureCollection' && Array.isArray(capa.features) && capa.features.length > 0 && capa.features.every((f: unknown) =>
  objeto(f) && objeto(f.geometry) && (f.geometry.type === 'Polygon' || f.geometry.type === 'MultiPolygon') && objeto(f.properties) && typeof f.properties.area_ha === 'number');
 if (!valida) throw new Error('La cobertura de manglar de la C.R.A. no tiene el formato esperado');
 return capa as unknown as CapaManglarCRA;
}
