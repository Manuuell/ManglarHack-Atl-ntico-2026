import fs from 'fs';
import path from 'path';
import { createHash } from 'crypto';
import { config } from '../config';
import { CambioEstado, Estado, Reporte, Usuario } from './modelo';

/**
 * Copia local en DATA_DIR: registro de vigías, cola de reintento de los reportes que todavía no llegan
 * al backend común y fotos. La fuente de verdad de los reportes es Supabase (backend/supabase).
 */

interface Datos {
  reportes: Reporte[];
  usuarios: Record<string, Usuario>;
}

let datos: Datos = { reportes: [], usuarios: {} };
let archivo = '';

export function iniciarAlmacen(): void {
  fs.mkdirSync(path.join(config.dataDir, 'fotos'), { recursive: true });
  archivo = path.join(config.dataDir, 'zanky.json');
  if (fs.existsSync(archivo)) {
    datos = JSON.parse(fs.readFileSync(archivo, 'utf8'));
    // Reportes de versiones anteriores, sin estado de envío: se tratan como pendientes.
    for (const r of datos.reportes) r.envio ??= { estado: 'pendiente', intentos: 0 };
  }
}

function guardar(): void {
  const tmp = `${archivo}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(datos, null, 2));
  fs.renameSync(tmp, archivo);
}

/** Hash con sal secreta: identifica a la persona sin guardar su número. 64 hex, cabe en reportante_id. */
export function hashDe(id: string): string {
  return createHash('sha256').update(`${config.hashSalt}:${id}`).digest('hex');
}

export function usuario(hash: string): Usuario | undefined {
  return datos.usuarios[hash];
}

export function guardarUsuario(hash: string, u: Usuario): void {
  datos.usuarios[hash] = u;
  guardar();
}

/** Número del próximo vigía registrado (1, 2, 3…). */
export function siguienteVigia(): number {
  return Object.values(datos.usuarios).reduce((max, u) => Math.max(max, u.vigiaNumero ?? 0), 0) + 1;
}

export function vigias(): Usuario[] {
  return Object.values(datos.usuarios).filter(u => u.vigiaNumero);
}

export function crearReporte(r: Reporte): Reporte {
  const existente = datos.reportes.find(x => x.id === r.id);
  if (existente) return existente;
  datos.reportes.push(r);
  guardar();
  return r;
}

/** Guarda los cambios hechos a un reporte que ya está en la lista. */
export function actualizar(_r: Reporte): void {
  guardar();
}

export function todos(): Reporte[] {
  return datos.reportes;
}

export function porCodigo(codigo: string): Reporte | undefined {
  return datos.reportes.find(r => r.codigo === codigo);
}

export function delReportante(hash: string): Reporte[] {
  return datos.reportes.filter(r => r.reportanteHash === hash);
}

export function pendientesDeEnvio(): Reporte[] {
  return datos.reportes.filter(r => r.envio.estado === 'pendiente');
}

export function cambiarEstado(codigo: string, estado: Estado, por: string, nota?: string): Reporte | undefined {
  const r = porCodigo(codigo);
  if (!r) return undefined;
  const cambio: CambioEstado = { estado, fecha: new Date().toISOString(), por, ...(nota ? { nota } : {}) };
  r.estado = estado;
  r.historial.push(cambio);
  guardar();
  return r;
}

export function guardarFoto(datosFoto: Buffer, hash: string, mime: string): string {
  const ext = mime.includes('png') ? 'png' : mime.includes('webp') ? 'webp' : 'jpg';
  const nombre = `${hash.replace(/[^a-zA-Z0-9]/g, '').slice(0, 64)}.${ext}`;
  fs.writeFileSync(path.join(config.dataDir, 'fotos', nombre), datosFoto);
  return nombre;
}

export function rutaFoto(nombre: string): string | null {
  if (!/^[a-zA-Z0-9]{1,64}\.(jpg|png|webp)$/.test(nombre)) return null;
  const ruta = path.join(config.dataDir, 'fotos', nombre);
  return fs.existsSync(ruta) ? ruta : null;
}

export function leerFoto(nombre: string): Buffer | null {
  const ruta = rutaFoto(nombre);
  return ruta ? fs.readFileSync(ruta) : null;
}
