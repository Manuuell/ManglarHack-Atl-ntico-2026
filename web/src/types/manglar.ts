import type { Feature, FeatureCollection, Polygon } from 'geojson';
export type Canal = 'app' | 'web' | 'whatsapp';
export type TipoReporte = 'tala' | 'quema' | 'relleno' | 'vertimiento' | 'basuras' | 'cano_taponado' | 'fauna' | 'otro';
export type EstadoReporte = 'recibido' | 'en_verificacion' | 'verificado' | 'alerta_oficial' | 'en_atencion' | 'cerrado' | 'descartado';
export type Prioridad = 1 | 2 | 3 | 4 | 5;
export type NivelPrioridad = 'alta' | 'media' | 'baja';
export type PrioridadZona = 'critica' | NivelPrioridad;
export interface Reporte {
 id: string; canal: Canal; tipo: TipoReporte; descripcion: string; lat: number; lon: number;
 precision_m: number | null; capturado_en: string; recibido_en: string; zona: string | null;
 municipio: string; dentro_poligono: boolean; distancia_m: number | null; prioridad: Prioridad;
 confianza: number; estado: EstadoReporte; ia_tipo_detectado: TipoReporte | null;
 ia_confianza: number | null; foto_url: string | null; foto_hash: string | null; reportante_id: string | null;
}
export interface CambioEstado { id: string; reporte_id: string; estado: EstadoReporte; usuario_id: string; nota: string; fecha: string; }
export type ReportePublico = Omit<Reporte, 'reportante_id' | 'foto_url' | 'foto_hash' | 'precision_m'> & { ubicacion_aproximada: true };
export interface PropiedadesZona {
 id: string; nombre: string; municipio: string; prioridad: PrioridadZona; area_ha: number | null;
 especies: string[]; amenazas: string[]; descripcion: string; fuente: string;
}
export interface PropiedadesInvemar { AREA_HA: number; COBERTURA: string; FECHA_IMAG: string; ESCALA: string; }
export type ZonaManglar = Feature<Polygon, PropiedadesZona>;
export type ZonasManglar = FeatureCollection<Polygon, PropiedadesZona>;
export interface Colegio {
  id: string;
  nombre: string;
  municipio: string;
  puntos: number;
  reportes_validados: number;
  estudiantes: number;
  guardian: boolean;
}
