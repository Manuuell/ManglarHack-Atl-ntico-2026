import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';
import { config } from '../config';

/**
 * Propuestas de la comunidad hechas por WhatsApp («💡 Proponer»). Se guardan en DATA_DIR/propuestas.json, junto a
 * las jornadas del bot, y se publican en GET /api/propuestas sin datos personales, con los mismos tipos de acción y
 * de actor de la plataforma web (web/src/types/plataforma.ts: TipoAccion, TipoActor, estado «propuesta»), para que
 * el catálogo de Soluciones y el panel de la CRA las muestren. Supabase todavía no tiene tabla de propuestas
 * (handoff/13): cuando la tenga, se envían allá como los reportes.
 */

export const TIPOS_PROPUESTA = {
  siembra: { nombre: 'Siembra', emoji: '🌱', descripcion: 'Sembrar mangle en un sitio', accion: 'siembra' },
  restauracion: { nombre: 'Restauración', emoji: '💧', descripcion: 'Recuperar caños y el paso del agua', accion: 'restauracion_hidrologica' },
  limpieza: { nombre: 'Limpieza', emoji: '🧹', descripcion: 'Recoger basura del manglar o la orilla', accion: 'conservacion_vigilancia' },
  monitoreo: { nombre: 'Monitoreo', emoji: '📏', descripcion: 'Medir y vigilar el manglar con la comunidad', accion: 'conservacion_vigilancia' },
  emprendimiento: { nombre: 'Emprendimiento', emoji: '🧺', descripcion: 'Producto o servicio sostenible del manglar', accion: 'sbn' },
  educacion: { nombre: 'Educación', emoji: '🎒', descripcion: 'Talleres, colegios, recorridos educativos', accion: 'conservacion_vigilancia' },
  otra: { nombre: 'Otra', emoji: '💡', descripcion: 'Otra idea para cuidar el manglar', accion: 'sbn' },
} as const;

export type TipoPropuesta = keyof typeof TIPOS_PROPUESTA;

export const PROPONENTES = {
  comunidad: { nombre: 'Comunidad', emoji: '🏘️', actor: 'comunidad' },
  universidad: { nombre: 'Universidad o colegio', emoji: '🎓', actor: 'academia' },
  empresa: { nombre: 'Empresa', emoji: '🏢', actor: 'empresa' },
  persona: { nombre: 'Persona', emoji: '🙋', actor: 'ciudadano' },
  cra: { nombre: 'CRA', emoji: '🏛️', actor: 'entidad_publica' },
} as const;

export type Proponente = keyof typeof PROPONENTES;

export const esTipoPropuesta = (x: string): x is TipoPropuesta => Object.prototype.hasOwnProperty.call(TIPOS_PROPUESTA, x);
export const esProponente = (x: string): x is Proponente => Object.prototype.hasOwnProperty.call(PROPONENTES, x);

export interface Propuesta {
  id: string;
  /** PROP- + 4 hex del id, como el ZK- de los reportes. */
  codigo: string;
  canal: 'whatsapp';
  tipo: TipoPropuesta;
  /** Tipo de acción de la plataforma web. */
  tipo_accion: (typeof TIPOS_PROPUESTA)[TipoPropuesta]['accion'];
  proponente: Proponente;
  /** Tipo de actor de la plataforma web. */
  tipo_actor: (typeof PROPONENTES)[Proponente]['actor'];
  descripcion: string;
  lat: number;
  lon: number;
  zona: string | null;
  zona_nombre: string | null;
  dentro_poligono: boolean;
  distancia_m: number;
  estado: 'propuesta';
  creada_en: string;
  /** Privado (no sale por la API): hash del número y el número si aceptó que lo contacten. */
  proponente_hash: string;
  contacto?: string;
}

let datos: Propuesta[] | null = null;

function archivo(): string {
  return path.join(config.dataDir, 'propuestas.json');
}

function todas(): Propuesta[] {
  if (datos) return datos;
  try {
    datos = JSON.parse(fs.readFileSync(archivo(), 'utf8')) as Propuesta[];
  } catch {
    datos = [];
  }
  return datos;
}

/** Guarda la propuesta en disco antes de responder: si la escritura falla, lanza y no se confirma nada. */
export function crearPropuesta(p: Omit<Propuesta, 'id' | 'codigo' | 'canal' | 'tipo_accion' | 'tipo_actor' | 'estado' | 'creada_en'>): Propuesta {
  const id = randomUUID();
  const nueva: Propuesta = {
    ...p,
    id,
    codigo: 'PROP-' + id.replace(/-/g, '').slice(0, 4).toUpperCase(),
    canal: 'whatsapp',
    tipo_accion: TIPOS_PROPUESTA[p.tipo].accion,
    tipo_actor: PROPONENTES[p.proponente].actor,
    estado: 'propuesta',
    creada_en: new Date().toISOString(),
  };
  const lista = [...todas(), nueva];
  fs.mkdirSync(config.dataDir, { recursive: true });
  const tmp = `${archivo()}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(lista, null, 1));
  fs.renameSync(tmp, archivo());
  datos = lista;
  return nueva;
}

/** Lo público: sin hash ni número. Coordenadas a 3 decimales (~110 m), como la vista pública de reportes. */
export function propuestasPublicas(): Omit<Propuesta, 'proponente_hash' | 'contacto'>[] {
  return todas().map(({ proponente_hash: _h, contacto: _c, ...p }) => ({
    ...p,
    lat: Math.round(p.lat * 1000) / 1000,
    lon: Math.round(p.lon * 1000) / 1000,
  }));
}

export function propuestaPorCodigo(codigo: string): Propuesta | undefined {
  return todas().find(p => p.codigo === codigo);
}
