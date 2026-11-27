import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';
import { config } from '../config';
import { Jornada, TIPOS_JORNADA, TipoJornada } from '../jornadas/jornadas';

/**
 * Jornadas comunitarias, inscripciones, contactos de WhatsApp de las cuentas de la web e historial de
 * invitaciones, en DATA_DIR/jornadas.json. Es la fuente de verdad de las jornadas: la web, el bot y el
 * panel admin leen y escriben aquí.
 */
export interface JornadaGuardada extends Jornada {
  accion_id: string;
  imagen_url: string | null;
  ejemplo: boolean;
  estado: 'publicada' | 'cancelada';
  /** Inscritos que traían las jornadas de ejemplo antes de llegar al servidor. */
  inscritos_base: number;
  creada_en: string;
  creada_por: string | null;
}

export interface Inscripcion {
  id: string;
  jornada_id: string;
  nombre: string;
  telefono: string | null;
  cuenta_id: string | null;
  acepta_whatsapp: boolean;
  fecha: string;
  estado: 'inscrita' | 'cancelada';
}

export interface Contacto {
  cuenta_id: string;
  nombre: string;
  telefono: string | null;
  whatsapp_ok: boolean;
  consentimiento_en: string | null;
  actualizado_en: string;
}

export interface Envio {
  id: string;
  fecha: string;
  jornada_id: string;
  nombre: string;
  telefono: string;
  estado: 'enviado' | 'fallido';
  error?: string;
  wamid?: string;
  por: string;
}

interface Datos {
  sembrado: boolean;
  jornadas: JornadaGuardada[];
  inscripciones: Inscripcion[];
  contactos: Record<string, Contacto>;
  envios: Envio[];
}

let datos: Datos = { sembrado: false, jornadas: [], inscripciones: [], contactos: {}, envios: [] };
let archivo = '';

function guardar(): void {
  const tmp = `${archivo}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(datos, null, 1));
  fs.renameSync(tmp, archivo);
}

export function iniciarJornadas(): void {
  fs.mkdirSync(config.dataDir, { recursive: true });
  archivo = path.join(config.dataDir, 'jornadas.json');
  if (fs.existsSync(archivo)) datos = { ...datos, ...JSON.parse(fs.readFileSync(archivo, 'utf8')) };
  if (!datos.sembrado) void sembrar();
}

/** La primera vez se traen las jornadas que publicaba la web (datos de ejemplo) para no perderlas. */
async function sembrar(): Promise<void> {
  try {
    const res = await fetch(config.jornadasUrl, { signal: AbortSignal.timeout(10_000) });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const j = (await res.json()) as { aviso?: string; jornadas?: Partial<Jornada & { accion_id: string }>[] };
    const ejemplo = /ejemplo/i.test(String(j.aviso ?? ''));
    for (const x of j.jornadas ?? []) {
      if (!x.id || datos.jornadas.some(y => y.id === x.id)) continue;
      const limpia = validarJornada(x);
      if ('error' in limpia) continue;
      datos.jornadas.push({ ...limpia, id: String(x.id), ejemplo, estado: 'publicada', inscritos: 0, inscritos_base: Number(x.inscritos) || 0, creada_en: new Date().toISOString(), creada_por: null });
    }
    datos.sembrado = true;
    guardar();
    console.log(`[jornadas] sembradas ${datos.jornadas.length} desde la web`);
  } catch (err) {
    console.warn(`[jornadas] no se pudieron sembrar: ${(err as Error).message}`);
  }
}

// --- jornadas -------------------------------------------------------------------------------------

export function activas(id: string): number {
  return datos.inscripciones.filter(i => i.jornada_id === id && i.estado === 'inscrita').length;
}

/** Vista pública: inscritos = base de ejemplo + inscripciones activas. */
export function publica(j: JornadaGuardada): JornadaGuardada {
  return { ...j, inscritos: j.inscritos_base + activas(j.id) };
}

export function todasLasJornadas(): JornadaGuardada[] {
  return datos.jornadas.map(publica).sort((a, b) => a.inicio.localeCompare(b.inicio));
}

export function jornadasPublicadas(): JornadaGuardada[] {
  return todasLasJornadas().filter(j => j.estado === 'publicada');
}

export function jornada(id: string): JornadaGuardada | undefined {
  const j = datos.jornadas.find(x => x.id === id);
  return j && publica(j);
}

type CamposJornada = Omit<JornadaGuardada, 'id' | 'ejemplo' | 'estado' | 'inscritos' | 'inscritos_base' | 'creada_en' | 'creada_por'>;

const texto = (v: unknown, max: number) => (typeof v === 'string' ? v.trim().replace(/\s+/g, ' ').slice(0, max) : '');

/** Valida lo que llega del panel. Devuelve los campos limpios o el primer error en español. */
export function validarJornada(x: Record<string, unknown> | Partial<JornadaGuardada>, base?: JornadaGuardada): CamposJornada | { error: string } {
  const v = { ...(base ?? {}), ...x } as Record<string, unknown>;
  const titulo = texto(v.titulo, 120);
  const tipo = String(v.tipo ?? '') as TipoJornada;
  const inicio = String(v.inicio ?? '');
  const fin = String(v.fin ?? '');
  const lat = Number(v.lat);
  const lon = Number(v.lon);
  // Las jornadas no tienen límite de cupos. El campo se conserva por compatibilidad (0 = sin límite):
  // el panel viejo manda un número y se acepta, pero ya no se usa para cerrar inscripciones.
  const cupos = v.cupos === undefined || v.cupos === null || v.cupos === '' ? 0 : Math.round(Number(v.cupos));
  const imagen = texto(v.imagen_url, 500);
  if (titulo.length < 4) return { error: 'Escribe el título de la jornada.' };
  if (!(tipo in TIPOS_JORNADA)) return { error: 'Elige el tipo de jornada.' };
  if (Number.isNaN(Date.parse(inicio)) || Number.isNaN(Date.parse(fin))) return { error: 'Revisa la fecha y la hora de inicio y de fin.' };
  if (Date.parse(fin) <= Date.parse(inicio)) return { error: 'La hora de fin debe ser después del inicio.' };
  if (!texto(v.punto_encuentro, 160)) return { error: 'Escribe el punto de encuentro.' };
  if (!Number.isFinite(lat) || !Number.isFinite(lon) || lat < 10 || lat > 11.6 || lon < -75.6 || lon > -74.5) return { error: 'Marca el punto de encuentro en el Atlántico.' };
  if (!Number.isFinite(cupos) || cupos < 0) return { error: 'Los cupos no son válidos.' };
  if (imagen && !/^https:\/\/[^\s]+$/i.test(imagen)) return { error: 'La imagen debe ser una dirección https.' };
  const queLlevar = Array.isArray(v.que_llevar) ? v.que_llevar.map(q => texto(q, 80)).filter(Boolean).slice(0, 12) : [];
  return {
    titulo, tipo, inicio: new Date(inicio).toISOString(), fin: new Date(fin).toISOString(),
    punto_encuentro: texto(v.punto_encuentro, 160), lat, lon, cupos,
    descripcion: texto(v.descripcion, 1200), que_llevar: queLlevar,
    accion_id: texto(v.accion_id, 80), imagen_url: imagen || null,
  };
}

export function crearJornada(campos: CamposJornada, por: string): JornadaGuardada {
  const base = campos.titulo.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40);
  const id = `${base || 'jornada'}-${randomUUID().slice(0, 6)}`;
  const j: JornadaGuardada = { ...campos, id, ejemplo: false, estado: 'publicada', inscritos: 0, inscritos_base: 0, creada_en: new Date().toISOString(), creada_por: por };
  datos.jornadas.push(j);
  guardar();
  return publica(j);
}

export function editarJornada(id: string, campos: CamposJornada): JornadaGuardada | undefined {
  const j = datos.jornadas.find(x => x.id === id);
  if (!j) return undefined;
  Object.assign(j, campos);
  guardar();
  return publica(j);
}

export function cancelarJornada(id: string): boolean {
  const j = datos.jornadas.find(x => x.id === id);
  if (!j) return false;
  j.estado = 'cancelada';
  guardar();
  return true;
}

// --- inscripciones ------------------------------------------------------------------------------

export function inscribir(j: JornadaGuardada, p: { nombre: string; telefono: string | null; cuenta_id: string | null; acepta_whatsapp: boolean }): Inscripcion {
  const previa = datos.inscripciones.find(i => i.jornada_id === j.id && i.estado === 'inscrita'
    && ((p.cuenta_id && i.cuenta_id === p.cuenta_id) || (p.telefono && i.telefono === p.telefono)));
  if (previa) return previa;
  // Sin límite de cupos: se inscribe quien quiera ir.
  const i: Inscripcion = { id: randomUUID(), jornada_id: j.id, ...p, fecha: new Date().toISOString(), estado: 'inscrita' };
  datos.inscripciones.push(i);
  guardar();
  return i;
}

export function inscripcionesDe(jornadaId: string): Inscripcion[] {
  return datos.inscripciones.filter(i => i.jornada_id === jornadaId);
}

/** «No podré ir» desde WhatsApp: cancela la inscripción de ese número (o de su cuenta) en la jornada. */
export function cancelarPorTelefono(jornadaId: string, telefono: string): number {
  const cuentas = new Set(Object.values(datos.contactos).filter(c => c.telefono === telefono).map(c => c.cuenta_id));
  let n = 0;
  for (const i of datos.inscripciones) {
    if (i.jornada_id === jornadaId && i.estado === 'inscrita' && (i.telefono === telefono || (i.cuenta_id && cuentas.has(i.cuenta_id)))) {
      i.estado = 'cancelada';
      n++;
    }
  }
  if (n) guardar();
  return n;
}

export function totalInscripciones(): number {
  return datos.inscripciones.filter(i => i.estado === 'inscrita').length;
}

// --- contactos de las cuentas -------------------------------------------------------------------

export function guardarContacto(c: Omit<Contacto, 'actualizado_en'>): Contacto {
  const nuevo = { ...c, actualizado_en: new Date().toISOString() };
  datos.contactos[c.cuenta_id] = nuevo;
  guardar();
  return nuevo;
}

export function contactos(): Contacto[] {
  return Object.values(datos.contactos).sort((a, b) => b.actualizado_en.localeCompare(a.actualizado_en));
}

export function contacto(cuentaId: string): Contacto | undefined {
  return datos.contactos[cuentaId];
}

// --- envíos -------------------------------------------------------------------------------------

export function registrarEnvio(e: Omit<Envio, 'id' | 'fecha'>): Envio {
  const envio = { ...e, id: randomUUID(), fecha: new Date().toISOString() };
  datos.envios.push(envio);
  if (datos.envios.length > 2000) datos.envios.splice(0, datos.envios.length - 2000);
  guardar();
  return envio;
}

export function envios(): Envio[] {
  return [...datos.envios].reverse();
}
