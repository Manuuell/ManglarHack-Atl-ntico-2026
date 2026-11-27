// Aquí se reemplaza el mock por la base de datos y el GeoJSON oficial de la C.R.A.
import reportes from '../data/mockReportes.json';
import poligonos from '../data/poligonosManglar.json';
import colegios from '../data/colegios.json';
import type { Colegio, Reporte, ZonasManglar } from '../types/manglar';

export async function obtenerReportes(): Promise<Reporte[]> {
  return structuredClone(reportes) as Reporte[];
}

export async function obtenerPoligonos(): Promise<ZonasManglar> {
  return structuredClone(poligonos) as unknown as ZonasManglar;
}

export async function obtenerColegios(): Promise<Colegio[]> {
  return structuredClone(colegios).sort((a, b) => b.puntos - a.puntos);
}
