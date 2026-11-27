import type { Actor, Accion, CambioAccion, Jornada, Inscripcion, ReporteMonitoreo, Rol, EstadoAccion, Requerimiento } from '../../types/plataforma';
import { crearAlmacen } from './almacen';
import { TIPOS_ACTOR, PAPELES, SECTORES, TIPOS_ACCION, TRANSICIONES_ACCION, REQUERIMIENTOS_POR_TIPO, puede } from './catalogos';
import { heredarPlan } from './geo';
import { useSincronizarJornadas } from './jornadasApi';

export const actores = crearAlmacen<Actor[]>('actores');
export const acciones = crearAlmacen<Accion[]>('acciones');
export const cambiosAccion = crearAlmacen<CambioAccion[]>('cambiosAccion');
export const jornadas = crearAlmacen<Jornada[]>('jornadas');
export const inscripciones = crearAlmacen<Inscripcion[]>('inscripciones');
export const monitoreos = crearAlmacen<ReporteMonitoreo[]>('monitoreos');
export const rolDemo = crearAlmacen<Rol>('rolDemo');
const SIN_INSCRIPCIONES: Inscripcion[] = [];
export const useActores = (iniciales: Actor[]) => actores.usar(iniciales);
export const useAcciones = (iniciales: Accion[]) => acciones.usar(iniciales);
export const useCambiosAccion = (iniciales: CambioAccion[]) => cambiosAccion.usar(iniciales);
// Las jornadas viven en el servidor de Zanky: quien las usa las recibe al día (ver jornadasApi.ts).
export const useJornadas = (iniciales: Jornada[]) => { useSincronizarJornadas(); return jornadas.usar(iniciales); };
export const useInscripciones = (iniciales: Inscripcion[] = SIN_INSCRIPCIONES) => inscripciones.usar(iniciales);
export const useMonitoreos = (iniciales: ReporteMonitoreo[]) => monitoreos.usar(iniciales);
export const useRolDemo = () => rolDemo.usar('moderador');

export type Resultado<T extends object> = ({ ok: true } & T) | { ok: false; errores: Record<string, string> };
type DatosActor = Omit<Actor, 'id' | 'verificado' | 'creado_en'>;
export type DatosAccion = Omit<Accion, 'id' | 'estado' | 'observaciones' | 'creada_en' | 'requerimientos' | 'accion_plan' | 'prioridad_plan' | 'plan_aproximado'> & {
  requerimientos?: Requerimiento[];
  requerimientos_cumplidos?: string[];
  /** Plan leído de la capa de la C.R.A. en el sitio; sin él se usa el respaldo por sector. */
  plan?: { accion_plan: Accion['accion_plan']; prioridad_plan: Accion['prioridad_plan']; plan_aproximado: boolean };
};
const tiene = (catalogo: object, valor: string) => Object.prototype.hasOwnProperty.call(catalogo, valor);
const nombreValido = (nombre: string) => typeof nombre === 'string' && nombre.trim().length >= 3;
const sitioValido = (lat: number, lon: number) => Number.isFinite(lat) && Number.isFinite(lon) && Math.abs(lat) <= 90 && Math.abs(lon) <= 180;
const fallar = (errores: Record<string, string>): { ok: false; errores: Record<string, string> } => ({ ok: false, errores });

/** Inicializar los almacenes necesarios con los datos de la página antes de operar.
 * Modo demostración: el servidor validará roles, cupos y transacciones en producción.
 */
export function registrarActor(datos: DatosActor): Resultado<{ actor: Actor }> {
  const errores: Record<string, string> = {};
  if (!nombreValido(datos.nombre)) errores.nombre = 'Escribe un nombre de al menos 3 caracteres.';
  if (typeof datos.correo !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(datos.correo.trim())) errores.correo = 'Escribe un correo válido; no se mostrará en público.';
  if (!tiene(TIPOS_ACTOR, datos.tipo)) errores.tipo = 'Selecciona un tipo de actor.';
  if (!tiene(SECTORES, datos.sector)) errores.sector = 'Selecciona un sector.';
  if (!Array.isArray(datos.papeles) || !datos.papeles.length || datos.papeles.some((papel) => !tiene(PAPELES, papel))) errores.papeles = 'Selecciona al menos un papel válido.';
  if (datos.acepta_datos !== true) errores.acepta_datos = 'Debes aceptar el tratamiento de datos para registrarte.';
  if (Object.keys(errores).length) return fallar(errores);
  const actor: Actor = { id: crypto.randomUUID(), nombre: datos.nombre.trim(), correo: datos.correo.trim(), tipo: datos.tipo, sector: datos.sector, papeles: [...new Set(datos.papeles)], acepta_datos: true, verificado: false, creado_en: new Date().toISOString() };
  actores.establecer((previo) => [...previo, actor]);
  return { ok: true, actor };
}
export function proponerAccion(datos: DatosAccion): Resultado<{ accion: Accion; cambio: CambioAccion }> {
  const errores: Record<string, string> = {};
  if (!actores.obtener().some((actor) => actor.id === datos.actor_id)) errores.actor_id = 'Selecciona un actor registrado.';
  if (!nombreValido(datos.nombre)) errores.nombre = 'Escribe un nombre de al menos 3 caracteres.';
  if (!tiene(TIPOS_ACCION, datos.tipo)) errores.tipo = 'Selecciona un tipo de acción.';
  if (!tiene(SECTORES, datos.sector)) errores.sector = 'Selecciona un sector válido.';
  if (!sitioValido(datos.lat, datos.lon)) errores.sitio = 'Marca un sitio con latitud y longitud válidas.';
  if (!Number.isFinite(datos.hectareas) || datos.hectareas <= 0) errores.hectareas = 'El área debe ser mayor que cero.';
  if (Object.keys(errores).length) return fallar(errores);
  cambiosAccion.obtener(); // Comprobar inicialización antes de modificar otros almacenes.
  const requerimientos = REQUERIMIENTOS_POR_TIPO[datos.tipo].map((texto, i) => {
    const id = `${datos.tipo}-${i + 1}`;
    return { id, texto, cumplido: datos.requerimientos_cumplidos?.includes(id) === true || datos.requerimientos?.some((r) => r.id === id && r.cumplido === true) === true };
  });
  const accion: Accion = {
    id: crypto.randomUUID(), nombre: datos.nombre.trim(), tipo: datos.tipo, actor_id: datos.actor_id,
    sector: datos.sector, lat: datos.lat, lon: datos.lon, hectareas: datos.hectareas,
    ...(datos.plan ?? heredarPlan(datos.sector)), estado: 'propuesta', descripcion: datos.descripcion.trim(),
    comunidad_coparticipante: datos.comunidad_coparticipante.trim(), requerimientos, observaciones: [], creada_en: new Date().toISOString(),
  };
  const cambio: CambioAccion = { id: crypto.randomUUID(), accion_id: accion.id, estado: 'propuesta', usuario_id: datos.actor_id, rol: 'sistema', nota: 'Propuesta registrada por el actor en modo demostración.', fecha: accion.creada_en };
  acciones.establecer((previo) => [...previo, accion]);
  cambiosAccion.establecer((previo) => [...previo, cambio]);
  return { ok: true, accion, cambio };
}
export function cambiarEstadoAccion(id: string, a: EstadoAccion, contexto: { usuario_id: string; rol: Rol; nota: string }): Resultado<{ accion: Accion; cambio: CambioAccion }> {
  const accion = acciones.obtener().find((item) => item.id === id);
  if (!accion) return fallar({ accion: 'No se encontró la acción.' });
  if (!puede(contexto.rol, 'revisar_acciones')) return fallar({ rol: 'Este rol no puede revisar acciones.' });
  if (!TRANSICIONES_ACCION[accion.estado].some((transicion) => transicion.a === a)) return fallar({ estado: 'Este cambio de estado no está permitido.' });
  const nota = contexto.nota.trim();
  if (!contexto.usuario_id.trim()) return fallar({ usuario_id: 'Identifica a quien realiza la revisión.' });
  if (a === 'con_observaciones' && !nota) return fallar({ nota: 'Describe las observaciones que debe resolver el actor.' });
  cambiosAccion.obtener();
  const actualizada: Accion = { ...accion, estado: a, observaciones: a === 'con_observaciones' ? [...accion.observaciones, nota] : accion.observaciones };
  const cambio: CambioAccion = { id: crypto.randomUUID(), accion_id: id, estado: a, usuario_id: contexto.usuario_id, rol: contexto.rol, nota, fecha: new Date().toISOString() };
  acciones.establecer((previo) => previo.map((item) => item.id === id ? actualizada : item));
  cambiosAccion.establecer((previo) => [...previo, cambio]);
  return { ok: true, accion: actualizada, cambio };
}
export function inscribirseEnJornada(jornada_id: string, nombre: string): Resultado<{ inscripcion: Inscripcion }> {
  if (!nombreValido(nombre)) return fallar({ nombre: 'Escribe un nombre de al menos 3 caracteres.' });
  const jornada = jornadas.obtener().find((item) => item.id === jornada_id);
  if (!jornada) return fallar({ jornada_id: 'No se encontró la jornada.' });
  inscripciones.inicializar(SIN_INSCRIPCIONES);
  if (inscripciones.obtener().some((item) => item.jornada_id === jornada_id)) return fallar({ jornada_id: 'Ya estás inscrito en esta jornada desde este navegador. ¡Te esperamos!' });
  if (jornada.inscritos >= jornada.cupos) return fallar({ cupos: 'Esta jornada ya no tiene cupos disponibles.' });
  const inscripcion: Inscripcion = { id: crypto.randomUUID(), jornada_id, nombre: nombre.trim(), fecha: new Date().toISOString() };
  jornadas.establecer((previo) => previo.map((item) => item.id === jornada_id ? { ...item, inscritos: item.inscritos + 1 } : item));
  inscripciones.establecer((previo) => [...previo, inscripcion]);
  return { ok: true, inscripcion };
}
export function registrarMonitoreo(datos: Omit<ReporteMonitoreo, 'id'>): Resultado<{ monitoreo: ReporteMonitoreo }> {
  const errores: Record<string, string> = {};
  const accion = acciones.obtener().find((item) => item.id === datos.accion_id);
  if (!accion || !['en_ejecucion', 'cerrada'].includes(accion.estado)) errores.accion_id = 'Selecciona una acción en ejecución o cerrada.';
  if (!Number.isFinite(datos.vivas_pct) || datos.vivas_pct < 0 || datos.vivas_pct > 100) errores.vivas_pct = 'El porcentaje debe estar entre 0 y 100.';
  if (!Number.isFinite(datos.altura_cm) || datos.altura_cm <= 0) errores.altura_cm = 'La altura debe ser mayor que cero.';
  const fecha = Date.parse(datos.fecha);
  const hoyBogota = new Date().toLocaleDateString('en-CA', { timeZone: 'America/Bogota' });
  const soloFecha = /^\d{4}-\d{2}-\d{2}$/.test(datos.fecha);
  if (!Number.isFinite(fecha) || (soloFecha && new Date(fecha).toISOString().slice(0, 10) !== datos.fecha) || (soloFecha ? datos.fecha > hoyBogota : fecha > Date.now())) errores.fecha = 'Selecciona una fecha válida que no sea futura.';
  if (!datos.autor_id.trim()) errores.autor_id = 'Identifica al autor del monitoreo.';
  if (!Array.isArray(datos.fotos) || datos.fotos.some((foto) => !sitioValido(foto.lat, foto.lon) || !/^(https?:\/\/|data:image\/)/.test(foto.url) || !Number.isFinite(Date.parse(foto.tomada_en)))) errores.fotos = 'Cada foto necesita un enlace válido, ubicación y fecha de captura.';
  if (Object.keys(errores).length) return fallar(errores);
  const monitoreo: ReporteMonitoreo = { ...structuredClone(datos), id: crypto.randomUUID(), observaciones: datos.observaciones.trim() };
  monitoreos.establecer((previo) => [...previo, monitoreo]);
  return { ok: true, monitoreo };
}
export function restablecerDemostracion(): void {
  for (const almacen of [actores, acciones, cambiosAccion, jornadas, inscripciones, monitoreos, rolDemo]) almacen.restablecer();
}
