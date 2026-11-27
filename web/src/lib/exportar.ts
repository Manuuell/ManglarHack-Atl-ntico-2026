import type { FeatureCollection, Point } from 'geojson';
import type { Reporte, ReportePublico } from '../types/manglar';
import { aReportePublico } from './privacidad';
import { TIPOS } from './catalogos';
const CAMPOS = ['id', 'capturado_en', 'tipo', 'municipio', 'zona', 'prioridad', 'estado', 'lat', 'lon', 'canal'] as const;
type DatosAbiertos = Pick<ReportePublico, typeof CAMPOS[number]>;
type Entrada = (Reporte | ReportePublico)[];
const LICENCIA = 'CC BY 4.0';
const AVISO = 'Datos de ejemplo';
function camposPublicos(reporte: Reporte | ReportePublico): DatosAbiertos {
 const r = aReportePublico(reporte);
 return { id: r.id, capturado_en: r.capturado_en, tipo: r.tipo, municipio: r.municipio, zona: r.zona, prioridad: r.prioridad, estado: r.estado, lat: r.lat, lon: r.lon, canal: r.canal };
}
function escaparCSV(valor: unknown): string {
 const texto = String(valor ?? '');
 // Evita interpretar como fórmula un texto procedente de un reporte.
 const seguro = typeof valor === 'string' && /^[=+@\-\t\r]/.test(texto) ? "'" + texto : texto;
 return '"' + seguro.replace(/"/g, '""') + '"';
}
export function reportesACSV(reportes: Entrada): string {
 // Licencia y carácter de ejemplo en la cabecera, sin filas adicionales.
 const cabecera = CAMPOS.map((campo) => escaparCSV(campo === 'id' ? `id · ${LICENCIA} · ${AVISO}` : campo));
 return [cabecera.join(','), ...reportes.map(camposPublicos).map((r) => CAMPOS.map((c) => escaparCSV(r[c])).join(','))].join('\r\n') + '\r\n';
}
export function reportesAGeoJSON(reportes: Entrada): FeatureCollection<Point, DatosAbiertos> & { licencia: string; aviso: string } {
 return { type: 'FeatureCollection', licencia: LICENCIA, aviso: AVISO, features: reportes.map(camposPublicos).map((r) => ({ type: 'Feature', geometry: { type: 'Point', coordinates: [r.lon, r.lat] }, properties: r })) };
}
function escaparXML(valor: unknown): string { return String(valor ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&apos;'); }
export function reportesAKML(reportes: Entrada): string {
 const marcas = reportes.map(camposPublicos).map((r) => `<Placemark><name>${escaparXML(TIPOS[r.tipo].etiqueta + ' · ' + (r.zona ?? 'Fuera de zona'))}</name><description>${escaparXML(CAMPOS.map((c) => `${c}: ${r[c] ?? ''}`).join('\n'))}</description><Point><coordinates>${r.lon},${r.lat},0</coordinates></Point></Placemark>`).join('');
 return `<?xml version="1.0" encoding="UTF-8"?><kml xmlns="http://www.opengis.net/kml/2.2"><Document><name>Reportes de manglar</name><description>${LICENCIA} · ${AVISO}</description>${marcas}</Document></kml>`;
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


function nombre(extension: string): string { return `reportes-manglares-datos-de-ejemplo-CC-BY-4.0-${fechaHoy()}.${extension}`; }
export function exportarCSV(reportes: Entrada): void { descargarArchivo('\uFEFF' + reportesACSV(reportes), nombre('csv'), 'text/csv;charset=utf-8'); }
export function exportarGeoJSON(reportes: Entrada): void { descargarArchivo(JSON.stringify(reportesAGeoJSON(reportes), null, 2), nombre('geojson'), 'application/geo+json'); }
export function exportarKML(reportes: Entrada): void { descargarArchivo(reportesAKML(reportes), nombre('kml'), 'application/vnd.google-earth.kml+xml'); }
