import fs from 'fs';
import path from 'path';
import { createHash } from 'crypto';
import { config } from '../config';
import { CambioEstado, Estado, Reporte, Usuario } from './modelo';

/**
 * Almacenamiento en archivos JSON dentro de DATA_DIR. Alcanza para el prototipo;
 * la interfaz es pequeña para poder cambiarla por una base de datos sin tocar los flujos.
 */

interface Datos {
  reportes: Reporte[];
  usuarios: Record<string, Usuario>;
}

let datos: Datos = { reportes: [], usuarios: {} };
let archivo = '';

export function iniciarAlmacen(): void {
  fs.mkdirSync(path.join(config.dataDir, 'fotos'), { recursive: true });
  archivo = path.join(config.dataDir, 'zanqui.json');
  if (fs.existsSync(archivo)) datos = JSON.parse(fs.readFileSync(archivo, 'utf8'));
}

function guardar(): void {
  const tmp = `${archivo}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(datos, null, 2));
  fs.renameSync(tmp, archivo);
}

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

export function siguienteCodigo(): string {
  return `ZQ-${String(datos.reportes.length + 1).padStart(4, '0')}`;
}

export function crearReporte(r: Reporte): Reporte {
  datos.reportes.push(r);
  guardar();
  return r;
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
