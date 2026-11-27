// Aquí se reemplaza el mock por la base de datos y el GeoJSON oficial de la C.R.A.
import reportes from '../data/mockReportes.json';
import poligonos from '../data/poligonosManglar.json';
import colegios from '../data/colegios.json';
import type { CambioEstado, Colegio, PropiedadesInvemar, Reporte, ZonasManglar } from '../types/manglar';

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
