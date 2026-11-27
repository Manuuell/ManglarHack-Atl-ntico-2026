import { config } from '../config';
import { CuandoId, FuenteUbicacion, Reporte, TIPOS, TipoId } from './modelo';

export interface DatosEvaluacion {
  tipo: TipoId;
  lat: number;
  lon: number;
  fuenteUbicacion: FuenteUbicacion;
  dentroPoligono: boolean;
  distanciaM: number;
  prioridadZona?: number;
  cuando: CuandoId;
  tieneFoto: boolean;
  fotoHash?: string;
  descripcion?: string;
  reportanteHash: string;
}

function distanciaM(aLat: number, aLon: number, bLat: number, bLon: number): number {
  const kx = 111_320 * Math.cos((aLat * Math.PI) / 180);
  return Math.hypot((bLon - aLon) * kx, (bLat - aLat) * 110_540);
}

/** Reportes de otras personas a menos de 500 m en las últimas 24 horas. */
export function corroboraciones(d: Pick<DatosEvaluacion, 'lat' | 'lon' | 'reportanteHash'>, existentes: Reporte[]): number {
  const limite = Date.now() - 24 * 3600 * 1000;
  return existentes.filter(
    r =>
      r.reportanteHash !== d.reportanteHash &&
      r.estado !== 'descartado' &&
      Date.parse(r.recibidoEn) >= limite &&
      distanciaM(d.lat, d.lon, r.lat, r.lon) <= 500,
  ).length;
}

/**
 * Prioridad 1-5: gravedad del tipo de amenaza ajustada por la zona, la distancia
 * al manglar, si está pasando ahora y si otras personas reportan lo mismo.
 */
export function prioridad(d: DatosEvaluacion, corroborados: number): number {
  let p: number = TIPOS[d.tipo].gravedad;
  if ((d.prioridadZona ?? 0) >= 4) p += 1;
  if (!d.dentroPoligono && d.distanciaM > config.radioInfluenciaM) p -= 1;
  if (d.cuando === 'dias') p -= 1;
  if (corroborados > 0) p += 1;
  return Math.max(1, Math.min(5, p));
}

/**
 * Confianza 0-100 por capas: evidencia, coherencia geográfica, oportunidad,
 * corroboración y antecedentes. Cada punto deja un motivo legible para el panel.
 * La decisión final la toma una persona de la CRA o un vigía comunitario.
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

  if (d.cuando === 'ahora') sumar(10, 'está pasando ahora');
  else if (d.cuando === 'hoy') sumar(5, 'pasó hoy');

  if (corroborados > 0) sumar(Math.min(20, corroborados * 10), `${corroborados} reporte(s) cercano(s) de otras personas`);

  if ((d.descripcion ?? '').trim().length >= 15) sumar(5, 'descripción con detalle');

  const previos = existentes.filter(r => r.reportanteHash === d.reportanteHash);
  if (previos.some(r => ['verificado', 'alerta_oficial', 'en_atencion', 'cerrado'].includes(r.estado))) sumar(10, 'reportante con reportes verificados');
  if (previos.filter(r => r.estado === 'descartado').length >= 2) sumar(-20, 'reportante con varios reportes descartados');

  return { puntaje: Math.max(0, Math.min(100, puntaje)), motivos };
}
