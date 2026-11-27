import { config } from '../config';
import { FuenteUbicacion, MagnitudId, MomentoId, Reporte, TIPOS, TipoId } from './modelo';

/**
 * Prioridad y confianza que el bot calcula para responderle a la persona y guardar en su copia local.
 * El servidor (trigger de recepción en backend/supabase/schema.sql) las vuelve a calcular con PostGIS:
 * lo que vale en el panel y en la app es lo del servidor. Las reglas son las mismas que las de la app.
 */

export interface DatosEvaluacion {
  tipo: TipoId;
  lat: number;
  lon: number;
  capturado_en: string;
  fuenteUbicacion: FuenteUbicacion;
  dentroPoligono: boolean;
  distanciaM: number;
  prioridadZona?: number;
  momento: MomentoId;
  magnitud: MagnitudId;
  tieneFoto: boolean;
  fotoHash?: string;
  descripcion?: string;
  reportanteHash: string;
}

function distanciaM(aLat: number, aLon: number, bLat: number, bLon: number): number {
  const kx = 111_320 * Math.cos((aLat * Math.PI) / 180);
  return Math.hypot((bLon - aLon) * kx, (bLat - aLat) * 110_540);
}

/** Como el servidor: mismo tipo, a 1 km o menos, ±3 horas y de otra persona. */
export function corroboraciones(d: Pick<DatosEvaluacion, 'tipo' | 'lat' | 'lon' | 'capturado_en' | 'reportanteHash'>, existentes: Reporte[]): number {
  const t = Date.parse(d.capturado_en);
  return existentes.filter(
    r =>
      r.tipo === d.tipo &&
      r.reportanteHash !== d.reportanteHash &&
      r.estado !== 'descartado' &&
      Math.abs(Date.parse(r.capturado_en) - t) <= 3 * 3600 * 1000 &&
      distanciaM(d.lat, d.lon, r.lat, r.lon) <= 1000,
  ).length;
}

/** Prioridad 1-5, con la misma regla que la app y el trigger del servidor. */
export function prioridad(d: DatosEvaluacion, corroborados: number): number {
  let p: number = TIPOS[d.tipo].gravedad;
  if (d.dentroPoligono) {
    if ((d.prioridadZona ?? 0) >= 5) p += 1;
  } else if (d.distanciaM > config.radioInfluenciaM) {
    p -= 1;
  }
  if (d.momento === 'antes') p -= 1;
  if (d.magnitud === 'grande') p += 1;
  if (corroborados > 0) p += 1;
  return Math.max(1, Math.min(5, p));
}

/**
 * Confianza 0-100 por capas: evidencia, coherencia geográfica, oportunidad, corroboración y antecedentes.
 * El servidor acepta del cliente como máximo 80; de ahí para arriba lo suben la IA y las personas.
 */
export function confianza(d: DatosEvaluacion, existentes: Reporte[], corroborados: number): { puntaje: number; motivos: string[] } {
  let puntaje = 20;
  const motivos: string[] = ['+20 base'];
  const sumar = (n: number, motivo: string) => {
    puntaje += n;
    motivos.push(`${n >= 0 ? '+' : ''}${n} ${motivo}`);
  };

  if (d.tieneFoto) {
    const repetida = d.fotoHash && existentes.some(r => r.foto?.hash === d.fotoHash);
    if (repetida) sumar(-30, 'foto repetida de otro reporte');
    else sumar(25, 'trae foto');
  } else {
    motivos.push('+0 sin foto');
  }

  sumar(d.fuenteUbicacion === 'gps' ? 20 : 10, d.fuenteUbicacion === 'gps' ? 'ubicación del GPS' : 'ubicación por enlace o coordenadas');

  if (d.dentroPoligono) sumar(15, 'dentro del manglar');
  else if (d.distanciaM <= config.radioInfluenciaM) sumar(10, `a ${d.distanciaM} m del manglar`);
  else motivos.push(`+0 lejos del manglar (${d.distanciaM} m)`);

  if (d.momento === 'ahora') sumar(10, 'está pasando ahora');
  else if (d.momento === 'hoy') sumar(5, 'pasó hoy');

  if (corroborados > 0) sumar(Math.min(20, corroborados * 10), `${corroborados} reporte(s) cercano(s) de otras personas`);

  if ((d.descripcion ?? '').trim().length >= 15) sumar(5, 'descripción con detalle');

  const previos = existentes.filter(r => r.reportanteHash === d.reportanteHash);
  if (previos.some(r => ['verificado', 'alerta_oficial', 'en_atencion', 'cerrado'].includes(r.estado))) sumar(10, 'reportante con reportes verificados');
  if (previos.filter(r => r.estado === 'descartado').length >= 2) sumar(-20, 'reportante con varios reportes descartados');

  return { puntaje: Math.max(0, Math.min(80, puntaje)), motivos };
}
