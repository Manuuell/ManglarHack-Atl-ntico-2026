import type { FeatureCollection, Point } from 'geojson';
import type { Reporte } from '../types/manglar';

const CAMPOS: (keyof Reporte)[] = [
  'id', 'origen', 'tipo', 'titulo', 'descripcion', 'lat', 'lng', 'zona',
  'prioridad', 'confianza_ia', 'estado', 'autor', 'fecha', 'foto_url',
];

function escaparCSV(valor: string | number): string {
  const texto = String(valor);
  return /[",\r\n]/.test(texto) ? `"${texto.replace(/"/g, '""')}"` : texto;
}

export function reportesACSV(reportes: Reporte[]): string {
  return [CAMPOS.join(','), ...reportes.map((reporte) => CAMPOS.map((campo) => escaparCSV(reporte[campo])).join(','))].join('\r\n') + '\r\n';
}

export function reportesAGeoJSON(reportes: Reporte[]): FeatureCollection<Point, Omit<Reporte, 'lat' | 'lng'>> & { name: string } {
  return {
    type: 'FeatureCollection',
    name: 'Reportes ciudadanos de manglar — Atlántico',
    features: reportes.map(({ lat, lng, ...properties }) => ({
      type: 'Feature', geometry: { type: 'Point', coordinates: [lng, lat] }, properties,
    })),
  };
}

export function descargarArchivo(contenido: string, nombreArchivo: string, mime: string): void {
  const url = URL.createObjectURL(new Blob([contenido], { type: mime }));
  const enlace = document.createElement('a');
  enlace.href = url;
  enlace.download = nombreArchivo;
  document.body.appendChild(enlace);
  try {
    enlace.click();
  } finally {
    enlace.remove();
    // Permite que el navegador inicie la descarga antes de liberar el recurso.
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
}

function fechaHoy(): string {
  const partes = new Intl.DateTimeFormat('es-CO', {
    timeZone: 'America/Bogota', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(new Date());
  return ['year', 'month', 'day'].map((tipo) => partes.find((parte) => parte.type === tipo)?.value).join('-');
}

export function exportarCSV(reportes: Reporte[]): void {
  descargarArchivo('\uFEFF' + reportesACSV(reportes), `reportes-manglares-atlantico-${fechaHoy()}.csv`, 'text/csv;charset=utf-8');
}

export function exportarGeoJSON(reportes: Reporte[]): void {
  descargarArchivo(JSON.stringify(reportesAGeoJSON(reportes), null, 2), `reportes-manglares-atlantico-${fechaHoy()}.geojson`, 'application/geo+json');
}
