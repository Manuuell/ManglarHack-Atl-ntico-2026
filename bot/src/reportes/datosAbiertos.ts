import { ESTADOS, Reporte, TIPOS } from './modelo';

/**
 * Exportación en formatos abiertos (GeoJSON, CSV, KML) para Gobierno Digital.
 * Nunca incluye el contacto, el hash del reportante, las fotos ni la descripción libre,
 * y redondea las coordenadas a 3 decimales (~110 m) para proteger a quien denuncia.
 */

export interface FilaAbierta {
  codigo: string;
  fecha: string;
  tipo: string;
  zona: string;
  dentro_manglar: boolean;
  prioridad: number;
  estado: string;
  canal: string;
  lat: number;
  lon: number;
}

const r3 = (n: number) => Math.round(n * 1000) / 1000;

export function filasAbiertas(reportes: Reporte[]): FilaAbierta[] {
  return reportes
    .filter(r => r.estado !== 'descartado')
    .map(r => ({
      codigo: r.codigo,
      fecha: r.recibido_en,
      tipo: TIPOS[r.tipo].nombre,
      zona: r.zona ?? '',
      dentro_manglar: r.dentroPoligono,
      prioridad: r.prioridad,
      estado: ESTADOS[r.estado],
      canal: r.canal,
      lat: r3(r.lat),
      lon: r3(r.lon),
    }));
}

export function aGeoJSON(reportes: Reporte[]) {
  return {
    type: 'FeatureCollection',
    name: 'reportes_ciudadanos_manglar_atlantico',
    licencia: 'CC BY 4.0',
    features: filasAbiertas(reportes).map(({ lat, lon, ...props }) => ({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [lon, lat] },
      properties: props,
    })),
  };
}

function celdaCsv(v: unknown): string {
  let s = String(v ?? '');
  // Evita que una hoja de cálculo interprete el valor como fórmula.
  if (/^[=+\-@\t\r]/.test(s) && typeof v === 'string') s = `'${s}`;
  return /[",\n;]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export function aCSV(reportes: Reporte[]): string {
  const filas = filasAbiertas(reportes);
  const columnas: (keyof FilaAbierta)[] = ['codigo', 'fecha', 'tipo', 'zona', 'dentro_manglar', 'prioridad', 'estado', 'canal', 'lat', 'lon'];
  return [columnas.join(','), ...filas.map(f => columnas.map(c => celdaCsv(f[c])).join(','))].join('\n') + '\n';
}

function xml(s: string): string {
  return s.replace(/[<>&"']/g, c => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&apos;' })[c] as string);
}

export function aKML(reportes: Reporte[]): string {
  const marcas = filasAbiertas(reportes)
    .map(
      f => `    <Placemark>
      <name>${xml(f.codigo)} · ${xml(f.tipo)}</name>
      <description>${xml(`${f.estado} · prioridad ${f.prioridad}/5 · ${f.fecha}`)}</description>
      <Point><coordinates>${f.lon},${f.lat},0</coordinates></Point>
    </Placemark>`,
    )
    .join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Reportes ciudadanos del manglar del Atlántico</name>
${marcas}
  </Document>
</kml>
`;
}
