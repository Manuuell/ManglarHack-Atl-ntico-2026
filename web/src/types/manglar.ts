import type { Feature, FeatureCollection, Polygon } from 'geojson';

export type Origen = 'whatsapp' | 'app';
export type TipoReporte = 'amenaza' | 'siembra' | 'limpieza' | 'avistamiento';
export type PrioridadReporte = 'alta' | 'media' | 'baja';
export type PrioridadZona = 'critica' | 'alta' | 'media' | 'baja';
export type EstadoReporte = 'pendiente' | 'validado' | 'escalado';

export interface Reporte {
  id: string;
  origen: Origen;
  tipo: TipoReporte;
  titulo: string;
  descripcion: string;
  lat: number;
  lng: number;
  zona: string;
  prioridad: PrioridadReporte;
  confianza_ia: number;
  estado: EstadoReporte;
  autor: string;
  fecha: string;
  foto_url: string;
}

export interface PropiedadesZona {
  id: string;
  nombre: string;
  municipio: string;
  prioridad: PrioridadZona;
  area_ha: number;
  especies: string[];
  amenazas: string[];
  descripcion: string;
}

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
