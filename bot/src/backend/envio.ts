import * as almacen from '../reportes/almacen';
import { Reporte } from '../reportes/modelo';
import { ErrorBackend, FilaReporte, backendActivo, crearReporte, estadoDeReportes, subirFoto } from './supabase';

const HEX64 = /^[0-9a-f]{64}$/;
const DIEZ_MIN = 10 * 60 * 1000;

/** Traduce el reporte del bot a la fila del contrato común. */
export function aFila(r: Reporte, fotoUrl: string | null): FilaReporte {
  return {
    id: r.id,
    canal: 'whatsapp',
    tipo: r.tipo,
    descripcion: (r.descripcion ?? '').slice(0, 1000),
    lat: r.lat,
    lon: r.lon,
    precision_m: null,
    metodo_ubicacion: r.fuenteUbicacion === 'gps' ? 'gps' : 'enlace',
    capturado_en: r.capturado_en,
    momento: r.momento,
    magnitud: r.magnitud,
    zona: r.zona ?? null,
    municipio: r.municipio ?? null,
    dentro_poligono: r.dentroPoligono,
    distancia_m: Number.isFinite(r.distanciaM) ? Math.round(r.distanciaM) : null,
    prioridad: r.prioridad,
    confianza: Math.min(80, r.confianza),
    foto_hash: r.foto && HEX64.test(r.foto.hash) ? r.foto.hash : null,
    // WhatsApp no dice si la foto salió de la cámara o de la galería.
    foto_de_camara: false,
    foto_url: fotoUrl,
    anonimo: r.anonimo,
    reportante_id: r.reportanteHash,
    sincronizado_tarde: Date.now() - Date.parse(r.capturado_en) > DIEZ_MIN,
  };
}

export type ResultadoEnvio = 'enviado' | 'pendiente' | 'rechazado' | 'sin_backend';

/**
 * Manda el reporte (y su foto) al backend común. Solo devuelve «enviado» cuando el servidor lo guardó:
 * el bot no le promete a nadie que algo está en el panel si no está (vara §8).
 */
export async function enviarReporte(r: Reporte): Promise<ResultadoEnvio> {
  if (!backendActivo()) {
    r.envio = { estado: 'sin_backend', intentos: r.envio?.intentos ?? 0 };
    almacen.actualizar(r);
    return 'sin_backend';
  }
  const intentos = (r.envio?.intentos ?? 0) + 1;
  try {
    let fotoUrl: string | null = null;
    if (r.foto?.jpeg && r.foto.archivo) {
      const jpeg = almacen.leerFoto(r.foto.archivo);
      if (jpeg) {
        await subirFoto(r.id, jpeg);
        fotoUrl = `evidencias/${r.id}.jpg`;
      }
    }
    const creado = await crearReporte(aFila(r, fotoUrl));
    r.envio = { estado: 'enviado', intentos, enviadoEn: new Date().toISOString() };
    // La prioridad y la confianza que valen son las del servidor (zona y prioridad oficial de la C.R.A.,
    // corroboraciones): se leen apenas se crea. Si esa lectura falla, el reporte igual quedó guardado.
    try {
      const [e] = await estadoDeReportes([r.id]);
      if (e) { r.prioridad = e.prioridad; r.confianza = e.confianza; r.estado = e.estado; }
    } catch { /* se actualiza la próxima vez que la persona pida «Mis reportes» */ }
    almacen.actualizar(r);
    console.log(`[backend] ${r.codigo} guardado en el backend común (intento ${intentos}${creado.nuevo ? '' : ', ya estaba'}) · prioridad ${r.prioridad}`);
    return 'enviado';
  } catch (err) {
    const reintentable = !(err instanceof ErrorBackend) || err.reintentable;
    const mensaje = (err as Error).message.slice(0, 300);
    r.envio = { estado: reintentable ? 'pendiente' : 'rechazado', intentos, ultimoError: mensaje };
    almacen.actualizar(r);
    console.warn(`[backend] ${r.codigo} ${reintentable ? 'queda pendiente' : 'RECHAZADO'}: ${mensaje}`);
    return reintentable ? 'pendiente' : 'rechazado';
  }
}
