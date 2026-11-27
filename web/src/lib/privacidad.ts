import type { Reporte, ReportePublico } from '../types/manglar';

// Regla del equipo: difuminar la ubicación pública para proteger a quien denuncia,
// con mayor distancia en hallazgos sensibles; nunca publicar fotos ni identidad.
export function aReportePublico(r: Reporte | ReportePublico): ReportePublico {
  const { reportante_id: _identidad, foto_url: _foto, foto_hash: _hash, precision_m: _precision, ...publico } = r as Reporte;
  const decimales = ['tala', 'quema', 'relleno', 'vertimiento', 'fauna'].includes(r.tipo) ? 2 : 3;
  return { ...publico, lat: Number(r.lat.toFixed(decimales)), lon: Number(r.lon.toFixed(decimales)), ubicacion_aproximada: true };
}
