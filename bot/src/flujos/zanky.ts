import { createHash } from 'crypto';
import { config } from '../config';
import { whatsapp } from '../whatsapp/cloudApi';
import { MensajeEntrante } from '../whatsapp/parser';
import { enAreaDeReporte, ubicar } from '../geo/zonas';
import { ubicacionDesdeTexto } from '../geo/ubicacionTexto';
import * as almacen from '../reportes/almacen';
import { confianza, corroboraciones, prioridad } from '../reportes/evaluacion';
import { FuenteUbicacion, MagnitudId, MomentoId, RolId, TipoId, enAtlantico, esMagnitud, esMomento, esMunicipio, esRol, esTipo, numeroDeCaso } from '../reportes/modelo';
import { enviarReporte } from '../backend/envio';
import { enlaceSeguimiento } from '../reportes/seguimiento';
import { detectarAmenaza } from './amenaza';
import { opcionDesdeTexto } from './entender';
import { MapaPersistente } from '../reportes/persistente';
import { backendActivo, estadoDeReportes } from '../backend/supabase';
import { buscarJornada, enlaceInvitacion, proximasJornadas } from '../jornadas/jornadas';
import * as J from '../api/almacenJornadas';
import { normalizarTelefono } from '../api/cuentas';
import { PROPONENTES, Proponente, TIPOS_PROPUESTA, TipoPropuesta, crearPropuesta, esProponente, esTipoPropuesta, propuestaPorCodigo } from '../api/almacenPropuestas';
import { config as configBot } from '../config';
import * as T from './textos';
import { iaActiva, limpiarHistorial, responder, Turno } from '../ia/zanky';
import { alertasActuales, alertasSimulacro, textoWhatsApp } from '../alertas/motor';

type Paso =
  | 'menu'
  | 'registro_inicio'
  | 'registro_nombre'
  | 'registro_rol'
  | 'registro_municipio'
  | 'consentimiento'
  | 'tipo'
  | 'ubicacion'
  | 'fuera_area'
  | 'foto'
  | 'descripcion'
  | 'cuando'
  | 'magnitud'
  | 'confirmar'
  | 'corregir'
  | 'jornadas'
  | 'jornada_nombre'
  | 'jornada_confirmar'
  | 'prop_tipo'
  | 'prop_ubicacion'
  | 'prop_fuera_area'
  | 'prop_descripcion'
  | 'prop_quien'
  | 'prop_confirmar'
  | 'prop_corregir';

interface Registro {
  modo: 'identificado' | 'anonimo';
  nombre?: string;
  rol?: RolId;
}

interface Borrador {
  tipo?: TipoId;
  lat?: number;
  lon?: number;
  fuenteUbicacion?: FuenteUbicacion;
  capturado_en?: string;
  dentro?: boolean;
  distanciaM?: number;
  zona?: string;
  prioridadZona?: number;
  zonaId?: string;
  municipio?: string;
  foto?: { archivo: string; hash: string; jpeg: boolean };
  conFoto?: boolean;
  descripcion?: string;
  /** Tocó «Omitir» en la descripción. */
  descripcionOmitida?: boolean;
  momento?: MomentoId;
  magnitud?: MagnitudId;
}

interface BorradorPropuesta {
  tipo?: TipoPropuesta;
  lat?: number;
  lon?: number;
  dentro?: boolean;
  distanciaM?: number;
  zona?: string;
  zonaId?: string;
  descripcion?: string;
  proponente?: Proponente;
}

interface Sesion {
  paso: Paso;
  /** Qué sigue después del consentimiento. */
  flujo?: 'reporte' | 'propuesta';
  borrador: Borrador;
  propuesta?: BorradorPropuesta;
  inscripcion?: { jornadaId: string; nombre?: string };
  registro?: Registro;
  /** Si dijo "Ahora no" al registro, no se le vuelve a ofrecer en esta conversación. */
  rechazoRegistro?: boolean;
  /** Último botón tocado y cuándo: un doble toque no debe repetir el mismo mensaje. */
  ultimoBoton?: { id: string; t: number };
  /** Respuestas no entendidas seguidas en el mismo paso. */
  noEntendi?: number;
  actualizada: number;
}

/** Un mismo botón tocado otra vez dentro de este tiempo se toma como doble toque y se ignora. */
const DOBLE_TOQUE_MS = 15_000;

// La conversación en curso de cada persona se guarda en DATA_DIR/sesiones.json, con el hash del número como
// llave: así un reinicio o un despliegue no la corta a mitad de un reporte (antes vivía solo en memoria).
const sesiones = new MapaPersistente<Sesion>('sesiones', s => Date.now() - s.actualizada < config.sesionTtlMs);

/** Guarda en disco las sesiones pendientes (al apagar el proceso). */
export function guardarSesiones(): void {
  sesiones.guardarYa();
}

function sesionDe(de: string): Sesion {
  const llave = almacen.hashDe(de);
  const s = sesiones.get(llave);
  if (s && Date.now() - s.actualizada < config.sesionTtlMs) return s;
  const nueva: Sesion = { paso: 'menu', borrador: {}, actualizada: Date.now() };
  sesiones.set(llave, nueva);
  return nueva;
}

function ir(s: Sesion, paso: Paso): void {
  if (s.paso !== paso) s.noEntendi = 0;
  s.paso = paso;
  s.actualizada = Date.now();
}

const normalizar = (t: string) =>
  t.trim().toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9 ]/g, '').trim();

/** Cancelan lo que esté en curso y vuelven al menú, en cualquier paso. */
const SALIR = new Set(['salir', 'cancelar', 'menu', 'inicio', 'hola', 'buenas', 'buenos dias', 'buenas tardes', 'buenas noches', 'zanky', 'zanqui', 'empezar', 'start', 'volver', 'atras']);
const ES_SALUDO = /^(hola|buenas|buenos dias|buenas tardes|buenas noches)[ ,!.]*(zanky|zanqui)?[ !.]*$/;
const PIDE_SUS_REPORTES = /^(mis reportes|mis denuncias|consultar estado|consultar|estado|estado de mi reporte|estado de mis reportes|ver mis reportes|mi reporte)$/;
const CODIGO_CASO = /\bzk\s*-?\s*([0-9a-f]{4})\b/i;
const CODIGO_PROPUESTA = /\bprop\s*-?\s*([0-9a-f]{4})\b/i;

const PASOS_REPORTE = new Set<Paso>(['tipo', 'ubicacion', 'fuera_area', 'foto', 'descripcion', 'cuando', 'magnitud', 'confirmar', 'corregir']);
const PASOS_PROPUESTA = new Set<Paso>(['prop_tipo', 'prop_ubicacion', 'prop_fuera_area', 'prop_descripcion', 'prop_quien', 'prop_confirmar', 'prop_corregir']);

/** Qué tiene a medias la persona, si algo. */
function enCurso(s: Sesion): 'reporte' | 'propuesta' | 'registro' | 'inscripcion' | null {
  if (PASOS_REPORTE.has(s.paso)) return 'reporte';
  if (PASOS_PROPUESTA.has(s.paso)) return 'propuesta';
  if (s.paso === 'consentimiento') return s.flujo === 'propuesta' ? 'propuesta' : 'reporte';
  if (s.paso === 'registro_nombre' || s.paso === 'registro_rol' || s.paso === 'registro_municipio') return 'registro';
  if (s.paso === 'jornada_nombre' || s.paso === 'jornada_confirmar') return 'inscripcion';
  return null;
}

/** Descarta lo que esté a medias y lo dice explícitamente (solo si había algo). */
async function cancelarEnCurso(de: string, s: Sesion): Promise<void> {
  const que = enCurso(s);
  s.borrador = {};
  s.propuesta = undefined;
  s.inscripcion = undefined;
  s.registro = undefined;
  s.flujo = undefined;
  ir(s, 'menu');
  if (que) await whatsapp.texto(de, `🛑 ${T.cancelado(que)}`);
}

/** El menú principal: lista con las 6 opciones (WhatsApp solo admite 3 botones). */
async function menuLista(de: string, cuerpo: string): Promise<void> {
  await whatsapp.lista(de, cuerpo.length > 1000 ? `${cuerpo.slice(0, 997)}…` : cuerpo, T.MENU.boton, T.MENU.filas);
}

async function enviarMenu(de: string, s: Sesion): Promise<void> {
  ir(s, 'menu');
  s.borrador = {};
  s.propuesta = undefined;
  s.inscripcion = undefined;
  const u = almacen.usuario(almacen.hashDe(de));
  await menuLista(de, u?.vigiaNumero ? T.saludoMenu(u.nombre) : T.MENU.cuerpo);
}

async function empezarRegistro(de: string, s: Sesion, cuerpo: string = T.BIENVENIDA.cuerpo): Promise<void> {
  s.borrador = {};
  s.registro = undefined;
  ir(s, 'registro_inicio');
  await whatsapp.botones(de, cuerpo, T.BIENVENIDA.botones, T.ENCABEZADO);
}

/** Tras un envío: a quien todavía no es vigía (y no dijo «Ahora no») se le ofrece registrarse. */
async function ofrecerRegistroTrasEnvio(de: string, s: Sesion): Promise<void> {
  if (s.rechazoRegistro || almacen.usuario(almacen.hashDe(de))?.vigiaNumero) return;
  await empezarRegistro(de, s, T.OFRECER_REGISTRO);
}

function nombreValido(texto: string): string | null {
  const limpio = texto.trim().replace(/\s+/g, ' ');
  if (limpio.length < 2 || limpio.length > 60) return null;
  if (!/^[\p{L}][\p{L} .'-]*$/u.test(limpio)) return null;
  return limpio
    .split(' ')
    .map(p => (p ? p[0].toLocaleUpperCase('es') + p.slice(1).toLocaleLowerCase('es') : p))
    .join(' ');
}

async function terminarRegistro(de: string, s: Sesion, municipio: Parameters<typeof T.registrado>[3]): Promise<void> {
  const r = s.registro;
  if (!r?.rol) return empezarRegistro(de, s);
  const hash = almacen.hashDe(de);
  const anterior = almacen.usuario(hash);
  const numero = anterior?.vigiaNumero ?? almacen.siguienteVigia();
  const ahora = new Date().toISOString();
  almacen.guardarUsuario(hash, {
    consentimiento: r.modo,
    fecha: anterior?.fecha ?? ahora,
    ...(r.modo === 'identificado' ? { nombre: r.nombre, contacto: de } : {}),
    rol: r.rol,
    municipio,
    vigiaNumero: numero,
    registradoEn: ahora,
  });
  console.log(`[registro] vigía #${numero} ${r.rol} ${municipio}${r.modo === 'anonimo' ? ' (anónimo)' : ''}`);
  s.registro = undefined;
  await whatsapp.texto(de, T.registrado(r.modo === 'identificado' ? r.nombre : undefined, numero, r.rol, municipio));
  await enviarMenu(de, s);
}

// --- Reporte ----------------------------------------------------------------------------------------

async function pedirConsentimiento(de: string, s: Sesion, flujo: 'reporte' | 'propuesta'): Promise<void> {
  s.flujo = flujo;
  ir(s, 'consentimiento');
  await whatsapp.botones(de, T.CONSENTIMIENTO.cuerpo, T.CONSENTIMIENTO.botones, undefined, T.CONSENTIMIENTO.pie);
}

/**
 * Empieza un reporte. `previo` trae lo que ya se sabe (el tipo y la descripción si el primer mensaje describía la
 * amenaza, o la foto si llegó primero): esos pasos no se vuelven a preguntar.
 */
async function empezarReporte(de: string, s: Sesion, previo: Partial<Borrador> = {}): Promise<boolean> {
  const hash = almacen.hashDe(de);
  const recientes = almacen.delReportante(hash).filter(r => Date.now() - Date.parse(r.recibido_en) < 3600 * 1000);
  if (recientes.length >= config.maxReportesPorHora) {
    await menuLista(de, T.DEMASIADOS);
    ir(s, 'menu');
    return false;
  }
  s.flujo = 'reporte';
  s.borrador = { ...previo };
  // Solo cuando el tipo salió del texto de la persona (si tocó un tipo de la lista, ya sabe cuál eligió).
  if (previo.tipo && previo.descripcion && !previo.conFoto) await whatsapp.texto(de, T.amenazaReconocida(previo.tipo));
  return true;
}

/**
 * Pregunta lo primero que falte del reporte, en el orden de siempre: consentimiento, tipo, ubicación, foto,
 * descripción, cuándo, tamaño y resumen. Sirve igual para seguir, para lo que llegó antes de tiempo y para corregir
 * un solo campo (los demás ya están, así que vuelve al resumen).
 */
async function continuar(de: string, s: Sesion, prefijo = ''): Promise<void> {
  const b = s.borrador;
  const conPrefijo = async () => {
    if (prefijo) await whatsapp.texto(de, prefijo.trim());
  };
  if (!almacen.usuario(almacen.hashDe(de))) {
    await conPrefijo();
    return pedirConsentimiento(de, s, 'reporte');
  }
  if (!b.tipo) {
    await conPrefijo();
    ir(s, 'tipo');
    return void (await whatsapp.lista(de, T.TIPO.cuerpo, T.TIPO.boton, T.TIPO.filas));
  }
  if (b.lat === undefined) {
    ir(s, 'ubicacion');
    return void (await whatsapp.texto(de, `${prefijo}${T.PEDIR_UBICACION}`));
  }
  if (b.conFoto === undefined) {
    ir(s, 'foto');
    return void (await whatsapp.botones(de, `${prefijo}${T.PEDIR_FOTO}`, T.BOTON_SIN_FOTO));
  }
  if (!b.descripcion && !b.descripcionOmitida) {
    ir(s, 'descripcion');
    return void (await whatsapp.botones(de, `${prefijo}${T.PEDIR_DESCRIPCION}`, T.BOTON_OMITIR));
  }
  if (!b.momento) {
    ir(s, 'cuando');
    return void (await whatsapp.botones(de, `${prefijo}${T.PEDIR_CUANDO}`, T.BOTONES_CUANDO));
  }
  if (!b.magnitud) {
    ir(s, 'magnitud');
    return void (await whatsapp.botones(de, `${prefijo}${T.PEDIR_MAGNITUD}`, T.BOTONES_MAGNITUD));
  }
  await conPrefijo();
  return enviarResumen(de, s);
}

/** Valida el punto; si sirve lo guarda en el borrador y devuelve el resultado, si no, ya respondió. */
async function evaluarPunto(de: string, s: Sesion, lat: number, lon: number, pasoFuera: Paso): Promise<ReturnType<typeof ubicar> | null> {
  if (!enAtlantico(lat, lon)) {
    await whatsapp.texto(de, T.FUERA_DEL_ATLANTICO);
    return null;
  }
  const u = ubicar(lat, lon);
  // Regla común con la web: dentro de la cobertura C.R.A. 1:5.000 o a menos de RADIO_INFLUENCIA_M. Más lejos
  // (por ejemplo, el casco urbano de Barranquilla) no corresponde y no se crea nada.
  if (!enAreaDeReporte(u, config.radioInfluenciaM)) {
    ir(s, pasoFuera);
    await whatsapp.botones(de, T.fueraDelArea(config.radioInfluenciaM), T.BOTONES_FUERA_DEL_AREA);
    return null;
  }
  return u;
}

async function registrarUbicacion(de: string, s: Sesion, lat: number, lon: number, fuente: FuenteUbicacion, ts: number): Promise<void> {
  const u = await evaluarPunto(de, s, lat, lon, 'fuera_area');
  if (!u) return;
  Object.assign(s.borrador, {
    lat,
    lon,
    fuenteUbicacion: fuente,
    capturado_en: new Date(ts * 1000).toISOString(),
    dentro: u.dentro,
    distanciaM: u.distanciaM,
    zona: u.zona,
    zonaId: u.zonaId,
    municipio: u.municipio,
    prioridadZona: u.prioridadZona,
  });
  await whatsapp.texto(de, T.ubicacionRecibida(u.dentro, u.distanciaM, u.zona));
  await continuar(de, s);
}

async function enviarResumen(de: string, s: Sesion): Promise<void> {
  const b = s.borrador;
  ir(s, 'confirmar');
  await whatsapp.botones(
    de,
    T.resumen({ tipo: b.tipo!, zona: b.zona, dentro: !!b.dentro, distanciaM: b.distanciaM ?? 0, conFoto: !!b.conFoto, descripcion: b.descripcion, momento: b.momento!, magnitud: b.magnitud! }),
    T.BOTONES_CONFIRMAR,
  );
}

/** UUID estable a partir del id del mensaje de WhatsApp que confirmó el envío. */
function uuidDesde(messageId: string): string {
  const h = createHash('sha256').update(`zanky:${messageId}`).digest('hex');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-5${h.slice(13, 16)}-${((parseInt(h[16], 16) & 0x3) | 0x8).toString(16)}${h.slice(17, 20)}-${h.slice(20, 32)}`;
}

async function guardarReporte(de: string, s: Sesion, messageId: string): Promise<void> {
  const b = s.borrador;
  if (!b.tipo || b.lat === undefined || b.lon === undefined || !b.momento || !b.magnitud || !b.fuenteUbicacion) return continuar(de, s);
  const hash = almacen.hashDe(de);
  const existentes = almacen.todos();
  const ahora = new Date().toISOString();
  const datos = {
    tipo: b.tipo,
    lat: b.lat,
    lon: b.lon,
    capturado_en: b.capturado_en ?? ahora,
    fuenteUbicacion: b.fuenteUbicacion,
    dentroPoligono: !!b.dentro,
    distanciaM: b.distanciaM ?? 0,
    prioridadZona: b.prioridadZona,
    momento: b.momento,
    magnitud: b.magnitud,
    tieneFoto: !!b.conFoto,
    fotoHash: b.foto?.hash,
    descripcion: b.descripcion,
    reportanteHash: hash,
  };
  const corroborados = corroboraciones(datos, existentes);
  const conf = confianza(datos, existentes, corroborados);
  const u = almacen.usuario(hash);
  const id = uuidDesde(messageId);
  const reporte = almacen.crearReporte({
    id,
    codigo: numeroDeCaso(id),
    canal: 'whatsapp',
    tipo: b.tipo,
    descripcion: b.descripcion,
    lat: b.lat,
    lon: b.lon,
    fuenteUbicacion: b.fuenteUbicacion,
    zona: b.zonaId,
    zonaNombre: b.zona,
    municipio: b.municipio,
    dentroPoligono: !!b.dentro,
    distanciaM: b.distanciaM ?? 0,
    momento: b.momento,
    magnitud: b.magnitud,
    capturado_en: datos.capturado_en,
    recibido_en: ahora,
    prioridad: prioridad(datos, corroborados),
    confianza: conf.puntaje,
    motivosConfianza: conf.motivos,
    estado: 'recibido',
    foto: b.foto,
    reportanteHash: hash,
    anonimo: u?.consentimiento !== 'identificado',
    ...(u?.consentimiento === 'identificado' ? { contacto: de } : {}),
    envio: { estado: 'pendiente', intentos: 0 },
    historial: [{ estado: 'recibido', fecha: ahora, por: 'zanky-bot' }],
  });
  console.log(`[reporte] ${reporte.codigo} ${reporte.tipo} prioridad ${reporte.prioridad} confianza ${reporte.confianza}`);
  ir(s, 'menu');
  s.borrador = {};
  s.flujo = undefined;
  // Solo se dice «ya está en el panel» cuando el backend común lo guardó.
  const resultado = await enviarReporte(reporte);
  if (resultado === 'enviado') await whatsapp.texto(de, T.enviado(reporte.codigo, enlaceSeguimiento(reporte.id), !!reporte.contacto));
  else if (resultado === 'sin_backend') await whatsapp.texto(de, T.guardadoSinBackend(reporte.codigo));
  else if (resultado === 'rechazado') await menuLista(de, T.ENVIO_RECHAZADO);
  else {
    reporte.avisarA = de;
    almacen.actualizar(reporte);
    await whatsapp.texto(de, T.ENVIO_PENDIENTE);
  }
  if (resultado !== 'rechazado') await ofrecerRegistroTrasEnvio(de, s);
}

/** Descarga la foto al borrador. Devuelve false si no se pudo. El pie de foto sirve de descripción. */
async function guardarFoto(s: Sesion, mediaId: string, sha256Meta?: string, pie?: string): Promise<boolean> {
  try {
    const media = await whatsapp.descargarMedia(mediaId);
    if (media) {
      // Hash propio en hex (el de Meta viene en base64): así lo pide foto_hash en el backend.
      const hash = createHash('sha256').update(media.datos).digest('hex');
      const jpeg = /jpe?g/i.test(media.mime);
      s.borrador.foto = { archivo: almacen.guardarFoto(media.datos, hash, media.mime), hash, jpeg };
    } else {
      // Modo simulación: no hay archivo, pero sí el hash que reporta WhatsApp.
      s.borrador.foto = { archivo: '', hash: sha256Meta ?? mediaId, jpeg: false };
    }
    s.borrador.conFoto = true;
    if (pie && pie.trim().length >= 2 && !s.borrador.descripcion) s.borrador.descripcion = pie.trim().slice(0, 500);
    return true;
  } catch (err) {
    console.error('[foto] no se pudo descargar:', (err as Error).message);
    return false;
  }
}

async function recibirFoto(de: string, s: Sesion, mediaId: string, sha256Meta?: string, pie?: string): Promise<void> {
  const ok = await guardarFoto(s, mediaId, sha256Meta, pie);
  if (!ok) s.borrador.conFoto = false;
  await continuar(de, s, `${ok ? '📸 ¡Foto recibida!' : 'No pude guardar la foto, sigamos sin ella.'}\n\n`);
}

const CAMPOS_A_CORREGIR: Record<string, (b: Borrador) => void> = {
  c_tipo: b => { delete b.tipo; },
  c_ubicacion: b => { for (const k of ['lat', 'lon', 'fuenteUbicacion', 'capturado_en', 'dentro', 'distanciaM', 'zona', 'zonaId', 'municipio', 'prioridadZona'] as const) delete b[k]; },
  c_foto: b => { delete b.foto; delete b.conFoto; },
  c_descripcion: b => { delete b.descripcion; delete b.descripcionOmitida; },
  c_cuando: b => { delete b.momento; },
  c_magnitud: b => { delete b.magnitud; },
};

// --- Propuestas ---------------------------------------------------------------------------------------

async function empezarPropuesta(de: string, s: Sesion, previo: BorradorPropuesta = {}): Promise<void> {
  s.flujo = 'propuesta';
  s.borrador = {};
  s.propuesta = { ...previo };
  await continuarPropuesta(de, s);
}

async function continuarPropuesta(de: string, s: Sesion): Promise<void> {
  const p = (s.propuesta ??= {});
  if (!almacen.usuario(almacen.hashDe(de))) return pedirConsentimiento(de, s, 'propuesta');
  if (!p.tipo) {
    ir(s, 'prop_tipo');
    const filas = (Object.keys(TIPOS_PROPUESTA) as TipoPropuesta[]).map(id => ({ id, titulo: `${TIPOS_PROPUESTA[id].emoji} ${TIPOS_PROPUESTA[id].nombre}`, descripcion: TIPOS_PROPUESTA[id].descripcion }));
    return void (await whatsapp.lista(de, T.PROPUESTA_TIPO.cuerpo, T.PROPUESTA_TIPO.boton, filas));
  }
  if (p.lat === undefined) {
    ir(s, 'prop_ubicacion');
    return void (await whatsapp.texto(de, T.PROPUESTA_UBICACION));
  }
  if (!p.descripcion) {
    ir(s, 'prop_descripcion');
    return void (await whatsapp.texto(de, T.PROPUESTA_DESCRIPCION));
  }
  if (!p.proponente) {
    ir(s, 'prop_quien');
    const filas = (Object.keys(PROPONENTES) as Proponente[]).map(id => ({ id, titulo: `${PROPONENTES[id].emoji} ${PROPONENTES[id].nombre}` }));
    return void (await whatsapp.lista(de, T.PROPUESTA_QUIEN.cuerpo, T.PROPUESTA_QUIEN.boton, filas));
  }
  ir(s, 'prop_confirmar');
  const lugar = p.dentro ? `Dentro del manglar${p.zona ? ` (${p.zona})` : ''}` : `A ${p.distanciaM} m del manglar${p.zona ? ` (${p.zona})` : ''}`;
  await whatsapp.botones(
    de,
    '*Revisa tu propuesta*\n\n' +
      `${TIPOS_PROPUESTA[p.tipo].emoji} ${TIPOS_PROPUESTA[p.tipo].nombre}\n` +
      `📍 ${lugar}\n` +
      `✍️ ${p.descripcion.slice(0, 300)}\n` +
      `👥 ${PROPONENTES[p.proponente].nombre}\n\n` +
      '¿La envío a la CRA?',
    T.BOTONES_CONFIRMAR_PROPUESTA,
  );
}

async function registrarUbicacionPropuesta(de: string, s: Sesion, lat: number, lon: number): Promise<void> {
  const u = await evaluarPunto(de, s, lat, lon, 'prop_fuera_area');
  if (!u) return;
  Object.assign((s.propuesta ??= {}), { lat, lon, dentro: u.dentro, distanciaM: u.distanciaM, zona: u.zona, zonaId: u.zonaId });
  await whatsapp.texto(de, T.ubicacionRecibida(u.dentro, u.distanciaM, u.zona));
  await continuarPropuesta(de, s);
}

/** Guarda la propuesta; solo confirma con código si quedó escrita en disco. */
async function guardarPropuesta(de: string, s: Sesion): Promise<void> {
  const p = s.propuesta ?? {};
  if (!p.tipo || p.lat === undefined || p.lon === undefined || !p.descripcion || !p.proponente) return continuarPropuesta(de, s);
  const hash = almacen.hashDe(de);
  try {
    const nueva = crearPropuesta({
      tipo: p.tipo,
      proponente: p.proponente,
      descripcion: p.descripcion,
      lat: p.lat,
      lon: p.lon,
      zona: p.zonaId ?? null,
      zona_nombre: p.zona ?? null,
      dentro_poligono: !!p.dentro,
      distancia_m: p.distanciaM ?? 0,
      proponente_hash: hash,
      ...(almacen.usuario(hash)?.consentimiento === 'identificado' ? { contacto: de } : {}),
    });
    console.log(`[propuesta] ${nueva.codigo} ${nueva.tipo} ${nueva.proponente}`);
    s.propuesta = undefined;
    s.flujo = undefined;
    ir(s, 'menu');
    await menuLista(de, T.propuestaEnviada(nueva.codigo));
  } catch (err) {
    console.error(`[propuesta] no se pudo guardar: ${(err as Error).message}`);
    await whatsapp.texto(de, T.PROPUESTA_NO_GUARDADA);
  }
}

const CAMPOS_PROPUESTA: Record<string, (p: BorradorPropuesta) => void> = {
  pc_tipo: p => { delete p.tipo; },
  pc_ubicacion: p => { for (const k of ['lat', 'lon', 'dentro', 'distanciaM', 'zona', 'zonaId'] as const) delete p[k]; },
  pc_descripcion: p => { delete p.descripcion; },
  pc_quien: p => { delete p.proponente; },
};

// --- Jornadas -----------------------------------------------------------------------------------------

const webJornadas = () => `${new URL(configBot.jornadasUrl).origin}/plataforma/jornadas`;

/** Alertas del manglar: oleaje, pleamar, lluvia, viento, riesgo de incendio y reportes que coinciden. */
async function mostrarAlertas(de: string, s: Sesion, simulacro: boolean): Promise<void> {
  ir(s, 'menu');
  try {
    const r = simulacro ? await alertasSimulacro() : await alertasActuales();
    await whatsapp.texto(de, textoWhatsApp(r, new URL(configBot.jornadasUrl).origin));
  } catch (err) {
    console.warn(`[alertas] ${(err as Error).message}`);
    await whatsapp.texto(de, 'No pude leer las alertas en este momento 😕. Intenta de nuevo en unos minutos.');
  }
  await menuLista(de, '¿Qué más quieres hacer?');
}

/** Lista las próximas jornadas (la misma fuente que la web: el almacén del bot, /api/jornadas). */
async function mostrarJornadas(de: string, s: Sesion): Promise<void> {
  ir(s, 'jornadas');
  try {
    const { jornadas } = await proximasJornadas();
    if (!jornadas.length) {
      await whatsapp.texto(de, T.sinJornadas(webJornadas()));
      return enviarMenu(de, s);
    }
    await whatsapp.lista(de, T.JORNADAS.cuerpo, T.JORNADAS.boton, T.JORNADAS.filas(jornadas));
  } catch (err) {
    console.warn('[jornadas] no se pudieron leer:', (err as Error).message);
    await whatsapp.texto(de, T.jornadasNoDisponibles(webJornadas()));
    await enviarMenu(de, s);
  }
}

/** Manda la invitación de una jornada, con «Inscribirme» aquí mismo y el enlace de la web. */
async function enviarInvitacion(de: string, s: Sesion, id: string): Promise<void> {
  const { aviso } = await proximasJornadas().catch(() => ({ aviso: '' }));
  const j = buscarJornada(id);
  if (!j) return mostrarJornadas(de, s);
  ir(s, 'jornadas');
  // Las jornadas del almacén dicen una por una si son de ejemplo; las reales van sin el aviso.
  await whatsapp.texto(de, T.invitacionJornada(j, j.ejemplo === false ? '' : aviso));
  await whatsapp.botones(de, '¿Qué quieres hacer?', T.botonesInvitacion(j));
}

async function empezarInscripcion(m: MensajeEntrante, s: Sesion, id: string): Promise<void> {
  const { de } = m;
  const j = J.jornada(id);
  if (!j || j.estado !== 'publicada' || Date.parse(j.fin) < Date.now()) {
    await whatsapp.texto(de, `Esa jornada ya no está disponible para inscribirse aquí. Mira las demás o la cartelera: ${webJornadas()}`);
    return mostrarJornadas(de, s);
  }
  const publica = J.publica(j);
  const nombre = almacen.usuario(almacen.hashDe(de))?.nombre ?? (m.nombrePerfil ? nombreValido(m.nombrePerfil) ?? undefined : undefined);
  s.inscripcion = { jornadaId: j.id, nombre };
  if (!nombre) {
    ir(s, 'jornada_nombre');
    return void (await whatsapp.texto(de, T.PEDIR_NOMBRE_INSCRIPCION));
  }
  ir(s, 'jornada_confirmar');
  await whatsapp.botones(de, T.confirmarInscripcion(publica, nombre), T.BOTONES_CONFIRMAR_INSCRIPCION);
}

async function confirmarInscripcion(de: string, s: Sesion): Promise<void> {
  const ins = s.inscripcion;
  const j = ins ? J.jornada(ins.jornadaId) : undefined;
  if (!ins?.nombre || !j) return mostrarJornadas(de, s);
  const r = J.inscribir(j, { nombre: ins.nombre, telefono: normalizarTelefono(de), cuenta_id: null, acepta_whatsapp: true });
  s.inscripcion = undefined;
  ir(s, 'menu');
  const publica = J.publica(j);
  console.log(`[jornadas] inscripción por WhatsApp en ${j.id} (${publica.inscritos} inscritos, inscripción ${r.id})`);
  await menuLista(de, T.inscrito(publica, enlaceInvitacion(publica)));
}

/** «No podré ir» escrito: cancela la inscripción en la próxima jornada donde está inscrito este número. */
async function noPodreIr(de: string, s: Sesion): Promise<void> {
  const tel = normalizarTelefono(de);
  const proxima = J.jornadasPublicadas()
    .filter(j => Date.parse(j.fin) > Date.now())
    .sort((a, b) => a.inicio.localeCompare(b.inicio))
    .find(j => J.inscripcionesDe(j.id).some(i => i.estado === 'inscrita' && i.telefono === tel));
  ir(s, 'menu');
  if (!proxima || !tel) return menuLista(de, 'No encontré una inscripción tuya en las próximas jornadas.');
  await menuLista(de, T.inscripcionCancelada(proxima, J.cancelarPorTelefono(proxima.id, tel)));
}

// --- Mis reportes, código de caso e IA -----------------------------------------------------------------

/** Los reportes de la persona con el estado que tiene hoy en el backend común (lo cambia la CRA en el panel). */
async function conEstadoActual(reportes: ReturnType<typeof almacen.todos>): Promise<void> {
  const enviados = reportes.filter(r => r.envio?.estado === 'enviado').slice(-20);
  if (!backendActivo() || !enviados.length) return;
  try {
    const estados = await estadoDeReportes(enviados.map(r => r.id));
    for (const e of estados) {
      const r = reportes.find(x => x.id === e.id);
      if (r && r.estado !== e.estado) {
        r.estado = e.estado;
        r.prioridad = e.prioridad;
        almacen.actualizar(r);
      }
    }
  } catch (err) {
    console.warn('[backend] no se pudo leer el estado:', (err as Error).message);
  }
}

async function mostrarMisReportes(de: string): Promise<void> {
  const propios = almacen.delReportante(almacen.hashDe(de));
  await conEstadoActual(propios);
  await menuLista(de, T.misReportes(propios));
}

/**
 * «ZK-16D1» escrito: el estado de ese caso, de la misma fuente que «Mis reportes» (los reportes que entraron por
 * WhatsApp, con el estado del servidor). Solo dice tipo, estado, fecha y zona, que ya son públicos en el mapa.
 */
async function consultarCaso(de: string, codigo: string): Promise<void> {
  const casos = almacen.todos().filter(r => r.codigo === codigo);
  if (!casos.length) return menuLista(de, T.casoNoEncontrado(codigo));
  await conEstadoActual(casos);
  await menuLista(de, casos.map(T.estadoDeCaso).join('\n\n'));
}

async function consultarPropuesta(de: string, codigo: string): Promise<void> {
  const p = propuestaPorCodigo(codigo);
  if (!p) return menuLista(de, `🔎 No encontré una propuesta con el código *${codigo}*.`);
  const fecha = new Intl.DateTimeFormat('es-CO', { timeZone: 'America/Bogota', day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(p.creada_en));
  await menuLista(de, `💡 *${p.codigo}* · ${TIPOS_PROPUESTA[p.tipo].emoji} ${TIPOS_PROPUESTA[p.tipo].nombre}\nEstado: *Propuesta* (la CRA la revisa)\nFecha: ${fecha}${p.zona_nombre ? ` · ${p.zona_nombre}` : ''}`);
}

// Lo último que se habló con cada persona (solo en memoria, 30 minutos), para que Zanky siga el hilo.
const charlas = new Map<string, { turnos: Turno[]; hasta: number }>();

async function conversar(de: string, texto: string): Promise<void> {
  const ahora = Date.now();
  for (const [k, v] of charlas) if (v.hasta < ahora) charlas.delete(k);
  const previa = charlas.get(de);
  const turnos: Turno[] = [...(previa && previa.hasta > ahora ? previa.turnos : []), { rol: 'usuario', texto }];
  try {
    const respuesta = await responder(turnos, 'whatsapp');
    charlas.set(de, { turnos: limpiarHistorial([...turnos, { rol: 'zanky', texto: respuesta }]).slice(-8), hasta: ahora + config.sesionTtlMs });
    // La respuesta va con el menú en el mismo mensaje.
    await menuLista(de, respuesta);
  } catch (err) {
    console.warn(`[ia] ${(err as Error).message.slice(0, 200)}`);
    await menuLista(de, T.IA_NO_DISPONIBLE);
  }
}

// --- Entrada no reconocida --------------------------------------------------------------------------------

/** Nombre del paso y la pregunta corta que se le recuerda a la persona. */
const PASOS: Partial<Record<Paso, [string, string]>> = {
  consentimiento: ['Antes de reportar', '¿quieres reportar con tu número o anónimo?'],
  tipo: ['Qué está pasando', 'elige el tipo de amenaza en la lista.'],
  ubicacion: ['Ubicación', 'toca el clip 📎 → *Ubicación* o pega un enlace de Google Maps.'],
  fuera_area: ['Ubicación', 'manda la ubicación del manglar afectado o vuelve al menú.'],
  foto: ['Foto', 'envíame una foto o toca *Sin foto*.'],
  descripcion: ['Descripción', 'cuéntame qué viste o toca *Omitir*.'],
  cuando: ['Cuándo', '¿está pasando ahora, hoy más temprano o antes de hoy?'],
  magnitud: ['Tamaño', '¿es pequeño, mediano o grande?'],
  confirmar: ['Resumen del reporte', 'toca *Enviar*, *Corregir* o *Cancelar*.'],
  corregir: ['Corregir el reporte', 'elige en la lista qué quieres corregir.'],
  registro_inicio: ['Registro de vigía', 'toca *Registrarme*, *Sin mi nombre* o *Ahora no*.'],
  registro_nombre: ['Registro de vigía', 'escribe tu nombre, por ejemplo *María Pérez*.'],
  registro_rol: ['Registro de vigía', 'elige en la lista qué te une al manglar.'],
  registro_municipio: ['Registro de vigía', 'elige tu municipio en la lista.'],
  jornada_nombre: ['Inscripción a la jornada', 'escribe tu nombre y apellido.'],
  jornada_confirmar: ['Inscripción a la jornada', 'toca *Confirmo* o *Cancelar*.'],
  prop_tipo: ['Proponer', 'elige en la lista qué quieres proponer.'],
  prop_ubicacion: ['Proponer · dónde', 'toca el clip 📎 → *Ubicación* o pega un enlace de Google Maps.'],
  prop_fuera_area: ['Proponer · dónde', 'manda una ubicación en el manglar o vuelve al menú.'],
  prop_descripcion: ['Proponer · descripción', 'cuéntame la propuesta en una frase o más.'],
  prop_quien: ['Proponer · quién', 'elige en la lista quién propone.'],
  prop_confirmar: ['Resumen de la propuesta', 'toca *Enviar*, *Corregir* o *Cancelar*.'],
  prop_corregir: ['Corregir la propuesta', 'elige en la lista qué quieres corregir.'],
};

/** Vuelve a mandar la pregunta del paso en curso. */
async function reenviarPaso(m: MensajeEntrante, s: Sesion): Promise<void> {
  const { de } = m;
  switch (s.paso) {
    case 'consentimiento':
      return pedirConsentimiento(de, s, s.flujo ?? 'reporte');
    case 'tipo': case 'ubicacion': case 'foto': case 'descripcion': case 'cuando': case 'magnitud': case 'confirmar':
      return continuar(de, s);
    case 'fuera_area': case 'prop_fuera_area':
      return void (await whatsapp.botones(de, T.fueraDelArea(config.radioInfluenciaM), T.BOTONES_FUERA_DEL_AREA));
    case 'corregir':
      return void (await whatsapp.lista(de, T.CORREGIR.cuerpo, T.CORREGIR.boton, T.CORREGIR.filas));
    case 'prop_corregir':
      return void (await whatsapp.lista(de, T.CORREGIR_PROPUESTA.cuerpo, T.CORREGIR_PROPUESTA.boton, T.CORREGIR_PROPUESTA.filas));
    case 'registro_inicio':
      return void (await whatsapp.botones(de, T.BIENVENIDA.cuerpo, T.BIENVENIDA.botones, T.ENCABEZADO));
    case 'registro_nombre':
      return void (await whatsapp.texto(de, T.PEDIR_NOMBRE));
    case 'registro_rol':
      return void (await whatsapp.lista(de, T.ROL.cuerpo, T.ROL.boton, T.ROL.filas));
    case 'registro_municipio':
      return void (await whatsapp.lista(de, T.MUNICIPIO.cuerpo, T.MUNICIPIO.boton, T.MUNICIPIO.filas));
    case 'jornada_nombre':
      return void (await whatsapp.texto(de, T.PEDIR_NOMBRE_INSCRIPCION));
    case 'jornada_confirmar':
      return s.inscripcion ? empezarInscripcion(m, s, s.inscripcion.jornadaId) : mostrarJornadas(de, s);
    default:
      if (PASOS_PROPUESTA.has(s.paso)) return continuarPropuesta(de, s);
      return enviarMenu(de, s);
  }
}

/**
 * Algo que no encaja en el paso: la primera vez se explica dónde está y se repite la pregunta; la segunda se ofrecen
 * Ayuda y Salir en vez de repetir otra vez lo mismo.
 */
async function noEntendido(m: MensajeEntrante, s: Sesion): Promise<void> {
  const [paso, pregunta] = PASOS[s.paso] ?? ['el menú', 'elige una opción.'];
  s.noEntendi = (s.noEntendi ?? 0) + 1;
  s.actualizada = Date.now();
  if (s.noEntendi === 1) {
    await whatsapp.texto(m.de, T.noEntendi(paso, pregunta));
    const n = s.noEntendi;
    await reenviarPaso(m, s);
    s.noEntendi = n;
    return;
  }
  await whatsapp.botones(m.de, T.noEntendi(paso, pregunta), T.BOTONES_NO_ENTENDI);
}

// --- Botones de mensajes viejos ------------------------------------------------------------------------

const BOTONES_DE_REPORTE = new Set(['sin_foto', 'omitir', 'ahora', 'hoy', 'antes', 'pequena', 'mediana', 'grande', 'enviar', 'reiniciar', 'otra_ubicacion', 'p_enviar', 'p_corregir', 'ins_si', 'ins_nombre', 'ayuda_paso', ...Object.keys(CAMPOS_A_CORREGIR), 'c_todo', ...Object.keys(CAMPOS_PROPUESTA)]);

/**
 * Un botón de un mensaje anterior que llega cuando la conversación ya está en el menú (la persona volvió a un
 * mensaje viejo, o lo que tenía a medias venció tras 30 minutos). Se atiende con sentido en vez de repetir el menú.
 */
async function botonDeOtroPaso(m: MensajeEntrante, s: Sesion, opcion: string): Promise<void> {
  const { de } = m;
  // Un tipo de la lista «¿Qué está pasando?»: sigue el reporte con ese tipo.
  if (esTipo(opcion)) {
    if (await empezarReporte(de, s, { tipo: opcion })) await continuar(de, s);
    return;
  }
  if (esTipoPropuesta(opcion)) return empezarPropuesta(de, s, { tipo: opcion });
  // Los botones del consentimiento y del registro siguen valiendo.
  if (opcion === 'acepto' || opcion === 'anonimo' || opcion === 'no_acepto') {
    s.flujo ??= 'reporte';
    ir(s, 'consentimiento');
    return atenderPaso(m, s);
  }
  if (opcion === 'registrarme' || opcion === 'reg_anonimo' || opcion === 'ahora_no') {
    ir(s, 'registro_inicio');
    return atenderPaso(m, s);
  }
  if (BOTONES_DE_REPORTE.has(opcion)) return menuLista(de, T.REPORTE_VENCIDO);
  return enviarMenu(de, s);
}

// --- Entrada ------------------------------------------------------------------------------------------

/** Atiende un mensaje entrante según el paso en que va la conversación. */
export async function atender(m: MensajeEntrante): Promise<void> {
  const s = sesionDe(m.de);
  if (m.entrada.tipo === 'opcion') {
    const previo = s.ultimoBoton;
    const ahora = Date.now();
    if (previo && previo.id === m.entrada.id && ahora - previo.t < DOBLE_TOQUE_MS) {
      console.log(`[flujo] doble toque de «${m.entrada.id}» ignorado`);
      return;
    }
    s.ultimoBoton = { id: m.entrada.id, t: ahora };
  }
  try {
    await atenderPaso(m, s);
  } finally {
    s.actualizada = Date.now();
    sesiones.set(almacen.hashDe(m.de), s);
  }
}

async function atenderPaso(m: MensajeEntrante, s: Sesion): Promise<void> {
  const { de, entrada } = m;
  const original = entrada.tipo === 'texto' ? entrada.texto : '';
  const texto = normalizar(original);
  let opcion = entrada.tipo === 'opcion' ? entrada.id : '';

  // 1) Salir, cancelar, menú y saludos: cancelan lo que esté en curso (y lo dicen) y muestran el menú. Tienen
  //    prioridad sobre el paso en curso.
  if (SALIR.has(texto) || ES_SALUDO.test(texto) || opcion === 'salir' || opcion === 'cancelar' || opcion === 'menu') {
    await cancelarEnCurso(de, s);
    return enviarMenu(de, s);
  }

  // 2) Un código de caso o de propuesta escrito: su estado, sin tocar lo que esté en curso.
  const caso = original.match(CODIGO_CASO);
  if (caso) {
    await consultarCaso(de, `ZK-${caso[1].toUpperCase()}`);
    if (enCurso(s)) await reenviarPaso(m, s);
    return;
  }
  const prop = original.match(CODIGO_PROPUESTA);
  if (prop) {
    await consultarPropuesta(de, `PROP-${prop[1].toUpperCase()}`);
    if (enCurso(s)) await reenviarPaso(m, s);
    return;
  }

  // 3) «Mis reportes», «estado», «consultar estado»: la lista de la persona, nunca un reporte nuevo.
  if (PIDE_SUS_REPORTES.test(texto) || opcion === 'mis_reportes') {
    await mostrarMisReportes(de);
    if (enCurso(s)) await reenviarPaso(m, s);
    else ir(s, 'menu');
    return;
  }

  // 4) Los demás comandos cambian de tema: si había algo a medias, se cancela con aviso.
  const comando =
    texto === 'registro' || texto === 'registrarme' ? 'registro'
      : texto === 'jornadas' || texto === 'jornada' || texto === 'eventos' ? 'jornadas'
        : /^(alertas?|alerta del manglar|clima|mar de leva|oleaje|calamidad(es)?)$/.test(texto) || opcion === 'alertas' ? 'alertas'
          : texto === 'simulacro' || texto === 'alertas simulacro' ? 'simulacro'
            : texto === 'ayuda' || texto === 'como funciona' || opcion === 'como_funciona' ? 'ayuda'
              : /^(proponer|propuesta|quiero proponer|hacer una propuesta)$/.test(texto) || opcion === 'proponer' ? 'proponer'
                : /^(no podre ir|no voy a ir|no puedo ir|cancelar inscripcion)$/.test(texto) ? 'no_ire'
                  : null;
  if (comando) {
    await cancelarEnCurso(de, s);
    if (comando === 'registro') return empezarRegistro(de, s);
    if (comando === 'jornadas') return mostrarJornadas(de, s);
    if (comando === 'alertas' || comando === 'simulacro') return mostrarAlertas(de, s, comando === 'simulacro');
    if (comando === 'proponer') return empezarPropuesta(de, s);
    if (comando === 'no_ire') return noPodreIr(de, s);
    await whatsapp.texto(de, T.COMO_FUNCIONA);
    return enviarMenu(de, s);
  }

  // 5) Inscribirse a una jornada desde su invitación (vale aunque el mensaje sea viejo).
  if (opcion.startsWith('ins:')) return empezarInscripcion(m, s, opcion.slice(4));

  // 6) «Ayuda» del mensaje de no entendido: explica el paso y lo repite.
  if (opcion === 'ayuda_paso' && PASOS[s.paso]) {
    const [paso, pregunta] = PASOS[s.paso]!;
    await whatsapp.texto(de, `ℹ️ Estás en *${paso}*: ${pregunta}\n\nSi quieres dejarlo, escribe *salir*. Si hay peligro para las personas, llama al *123*.`);
    s.noEntendi = 0;
    return reenviarPaso(m, s);
  }

  // 7) Una respuesta escrita (o dictada) que equivale al botón del paso: «sí», «quema», «ahora», «grande»…
  if (!opcion && entrada.tipo === 'texto') opcion = opcionDesdeTexto(s.paso, texto, original) ?? '';

  switch (s.paso) {
    case 'registro_inicio': {
      if (opcion === 'registrarme') {
        s.registro = { modo: 'identificado' };
        ir(s, 'registro_nombre');
        await whatsapp.texto(de, T.PEDIR_NOMBRE);
        return;
      }
      if (opcion === 'reg_anonimo') {
        s.registro = { modo: 'anonimo' };
        ir(s, 'registro_rol');
        await whatsapp.lista(de, T.ROL.cuerpo, T.ROL.boton, T.ROL.filas);
        return;
      }
      if (opcion === 'ahora_no') {
        s.rechazoRegistro = true;
        return enviarMenu(de, s);
      }
      // Escribió otra cosa (una pregunta, otra denuncia) o tocó otro botón: no se le insiste con el registro.
      if (entrada.tipo !== 'otro') {
        s.rechazoRegistro = true;
        ir(s, 'menu');
        return atenderPaso(m, s);
      }
      return noEntendido(m, s);
    }

    case 'registro_nombre': {
      const nombre = entrada.tipo === 'texto' ? nombreValido(entrada.texto) : null;
      if (!nombre || !s.registro) {
        if (s.registro && opcion === '') return void (await whatsapp.botones(de, `${T.NOMBRE_INVALIDO}\n\nSi prefieres no dar tu nombre, toca *Sin mi nombre*.`, [{ id: 'reg_anonimo_ya', titulo: '👤 Sin mi nombre' }, { id: 'salir', titulo: '🏠 Salir al menú' }]));
        if (opcion === 'reg_anonimo_ya' && s.registro) {
          s.registro = { modo: 'anonimo' };
          ir(s, 'registro_rol');
          return void (await whatsapp.lista(de, T.ROL.cuerpo, T.ROL.boton, T.ROL.filas));
        }
        return noEntendido(m, s);
      }
      s.registro.nombre = nombre;
      ir(s, 'registro_rol');
      await whatsapp.lista(de, `Mucho gusto, *${nombre}* 🤝\n\n${T.ROL.cuerpo}`, T.ROL.boton, T.ROL.filas);
      return;
    }

    case 'registro_rol': {
      if (esRol(opcion) && s.registro) {
        s.registro.rol = opcion;
        ir(s, 'registro_municipio');
        await whatsapp.lista(de, T.MUNICIPIO.cuerpo, T.MUNICIPIO.boton, T.MUNICIPIO.filas);
        return;
      }
      return noEntendido(m, s);
    }

    case 'registro_municipio': {
      if (esMunicipio(opcion)) return terminarRegistro(de, s, opcion);
      return noEntendido(m, s);
    }

    case 'menu':
    case 'jornadas': {
      if (opcion.startsWith('jor:')) return enviarInvitacion(de, s, opcion.slice(4));
      if (opcion === 'jornadas' || (s.paso === 'menu' && /jornad|siembra|voluntari|limpieza de/.test(texto))) return mostrarJornadas(de, s);
      // Si el texto ya describe una amenaza («están talando mangle en la ciénaga»), directo a reportar.
      if (entrada.tipo === 'texto') {
        const tipo = detectarAmenaza(entrada.texto);
        if (tipo) {
          if (await empezarReporte(de, s, { tipo, descripcion: entrada.texto.trim().slice(0, 500) })) await continuar(de, s);
          return;
        }
      }
      // Llegó primero la foto o la ubicación: se empieza el reporte con ella ya guardada.
      if (entrada.tipo === 'imagen') {
        if (!(await empezarReporte(de, s))) return;
        const ok = await guardarFoto(s, entrada.mediaId, entrada.sha256, entrada.caption);
        return continuar(de, s, ok ? `${T.FOTO_PRIMERO}\n\n` : 'No pude guardar la foto; sigamos y me la mandas después.\n\n');
      }
      if (entrada.tipo === 'ubicacion') {
        if (!(await empezarReporte(de, s))) return;
        await whatsapp.texto(de, T.UBICACION_PRIMERO);
        return registrarUbicacion(de, s, entrada.lat, entrada.lon, 'gps', m.timestamp);
      }
      if (opcion === 'reportar' || texto.includes('report') || texto.includes('denunci')) {
        if (await empezarReporte(de, s)) await continuar(de, s);
        return;
      }
      if (/propon|propuesta/.test(texto)) return empezarPropuesta(de, s);
      if (opcion) return botonDeOtroPaso(m, s, opcion);
      // Una pregunta o comentario libre: Zanky conversa (OpenAI) y deja a mano el menú.
      if (entrada.tipo === 'texto' && iaActiva() && entrada.texto.trim().length >= 2) return conversar(de, entrada.texto);
      if (entrada.tipo === 'otro') return menuLista(de, 'Por ahora recibo texto, notas de voz, fotos y ubicaciones 🙂. ¿Qué quieres hacer?');
      return enviarMenu(de, s);
    }

    case 'consentimiento': {
      if (opcion === 'acepto' || opcion === 'anonimo') {
        almacen.guardarUsuario(almacen.hashDe(de), {
          consentimiento: opcion === 'acepto' ? 'identificado' : 'anonimo',
          fecha: new Date().toISOString(),
        });
        return s.flujo === 'propuesta' ? continuarPropuesta(de, s) : continuar(de, s);
      }
      if (opcion === 'no_acepto') {
        s.borrador = {};
        s.propuesta = undefined;
        s.flujo = undefined;
        ir(s, 'menu');
        return menuLista(de, T.SIN_CONSENTIMIENTO);
      }
      return noEntendido(m, s);
    }

    case 'tipo': {
      if (esTipo(opcion)) {
        s.borrador.tipo = opcion;
        return continuar(de, s);
      }
      return noEntendido(m, s);
    }

    case 'ubicacion':
    case 'fuera_area': {
      if (entrada.tipo === 'ubicacion') return registrarUbicacion(de, s, entrada.lat, entrada.lon, 'gps', m.timestamp);
      if (opcion === 'otra_ubicacion') {
        ir(s, 'ubicacion');
        return void (await whatsapp.texto(de, T.PEDIR_UBICACION));
      }
      if (entrada.tipo === 'texto') {
        const coords = await ubicacionDesdeTexto(entrada.texto);
        if (coords) return registrarUbicacion(de, s, coords.lat, coords.lon, 'enlace', m.timestamp);
      }
      // La foto antes que la ubicación: se guarda y se sigue pidiendo la ubicación.
      if (entrada.tipo === 'imagen' && s.borrador.conFoto === undefined) {
        const ok = await guardarFoto(s, entrada.mediaId, entrada.sha256, entrada.caption);
        return void (await whatsapp.texto(de, `${ok ? '📸 ¡Foto recibida! Ahora la ubicación.' : 'No pude guardar la foto; sigamos con la ubicación.'}\n\n${T.PEDIR_UBICACION}`));
      }
      return noEntendido(m, s);
    }

    case 'foto': {
      if (entrada.tipo === 'imagen') return recibirFoto(de, s, entrada.mediaId, entrada.sha256, entrada.caption);
      if (opcion === 'sin_foto') {
        s.borrador.conFoto = false;
        return continuar(de, s);
      }
      // Contó lo que pasa en vez de mandar la foto: se anota como descripción y se sigue pidiendo la foto.
      if (entrada.tipo === 'texto' && !s.borrador.descripcion && entrada.texto.trim().length >= 2) {
        s.borrador.descripcion = entrada.texto.trim().slice(0, 500);
        return void (await whatsapp.botones(de, `${T.DESCRIPCION_ANOTADA}\n\n${T.PEDIR_FOTO}`, T.BOTON_SIN_FOTO));
      }
      return noEntendido(m, s);
    }

    case 'descripcion': {
      if (opcion === 'omitir') {
        s.borrador.descripcionOmitida = true;
        return continuar(de, s);
      }
      if (entrada.tipo === 'texto' && entrada.texto.trim().length >= 2) {
        s.borrador.descripcion = entrada.texto.trim().slice(0, 500);
        return continuar(de, s);
      }
      return noEntendido(m, s);
    }

    case 'cuando': {
      if (esMomento(opcion)) {
        s.borrador.momento = opcion;
        return continuar(de, s);
      }
      return noEntendido(m, s);
    }

    case 'magnitud': {
      if (esMagnitud(opcion)) {
        s.borrador.magnitud = opcion;
        return continuar(de, s);
      }
      return noEntendido(m, s);
    }

    case 'confirmar': {
      if (opcion === 'enviar') return guardarReporte(de, s, m.messageId);
      if (opcion === 'reiniciar') {
        ir(s, 'corregir');
        return void (await whatsapp.lista(de, T.CORREGIR.cuerpo, T.CORREGIR.boton, T.CORREGIR.filas));
      }
      return noEntendido(m, s);
    }

    case 'corregir': {
      if (opcion === 'c_todo') {
        s.borrador = {};
        return continuar(de, s);
      }
      const borrar = CAMPOS_A_CORREGIR[opcion];
      if (borrar) {
        borrar(s.borrador);
        return continuar(de, s);
      }
      return noEntendido(m, s);
    }

    case 'prop_tipo': {
      if (esTipoPropuesta(opcion)) {
        (s.propuesta ??= {}).tipo = opcion;
        return continuarPropuesta(de, s);
      }
      return noEntendido(m, s);
    }

    case 'prop_ubicacion':
    case 'prop_fuera_area': {
      if (entrada.tipo === 'ubicacion') return registrarUbicacionPropuesta(de, s, entrada.lat, entrada.lon);
      if (opcion === 'otra_ubicacion') {
        ir(s, 'prop_ubicacion');
        return void (await whatsapp.texto(de, T.PROPUESTA_UBICACION));
      }
      if (entrada.tipo === 'texto') {
        const coords = await ubicacionDesdeTexto(entrada.texto);
        if (coords) return registrarUbicacionPropuesta(de, s, coords.lat, coords.lon);
      }
      return noEntendido(m, s);
    }

    case 'prop_descripcion': {
      if (entrada.tipo === 'texto') {
        const t = entrada.texto.trim();
        if (t.length >= 10) {
          (s.propuesta ??= {}).descripcion = t.slice(0, 1000);
          return continuarPropuesta(de, s);
        }
        if (t.length >= 2) return void (await whatsapp.texto(de, T.PROPUESTA_DESCRIPCION_CORTA));
      }
      return noEntendido(m, s);
    }

    case 'prop_quien': {
      if (esProponente(opcion)) {
        (s.propuesta ??= {}).proponente = opcion;
        return continuarPropuesta(de, s);
      }
      return noEntendido(m, s);
    }

    case 'prop_confirmar': {
      if (opcion === 'p_enviar') return guardarPropuesta(de, s);
      if (opcion === 'p_corregir') {
        ir(s, 'prop_corregir');
        return void (await whatsapp.lista(de, T.CORREGIR_PROPUESTA.cuerpo, T.CORREGIR_PROPUESTA.boton, T.CORREGIR_PROPUESTA.filas));
      }
      return noEntendido(m, s);
    }

    case 'prop_corregir': {
      const borrar = CAMPOS_PROPUESTA[opcion];
      if (borrar) {
        borrar((s.propuesta ??= {}));
        return continuarPropuesta(de, s);
      }
      return noEntendido(m, s);
    }

    case 'jornada_nombre': {
      const nombre = entrada.tipo === 'texto' ? nombreValido(entrada.texto) : null;
      if (nombre && s.inscripcion) {
        s.inscripcion.nombre = nombre;
        const j = J.jornada(s.inscripcion.jornadaId);
        if (!j) return mostrarJornadas(de, s);
        ir(s, 'jornada_confirmar');
        return void (await whatsapp.botones(de, T.confirmarInscripcion(J.publica(j), nombre), T.BOTONES_CONFIRMAR_INSCRIPCION));
      }
      return noEntendido(m, s);
    }

    case 'jornada_confirmar': {
      if (opcion === 'ins_si') return confirmarInscripcion(de, s);
      if (opcion === 'ins_nombre') {
        ir(s, 'jornada_nombre');
        return void (await whatsapp.texto(de, T.PEDIR_NOMBRE_INSCRIPCION));
      }
      return noEntendido(m, s);
    }
  }
}

/** Avisa a la persona cuando la CRA cambia el estado de su reporte (solo si reportó con su número). */
export async function avisarCambio(contacto: string | undefined, codigo: string, estado: Parameters<typeof T.cambioDeEstado>[1], nota?: string): Promise<boolean> {
  if (!contacto) return false;
  try {
    await whatsapp.texto(contacto, T.cambioDeEstado(codigo, estado, nota));
    return true;
  } catch (err) {
    // Fuera de la ventana de 24 horas WhatsApp exige una plantilla aprobada.
    console.warn(`[aviso] no se pudo avisar ${codigo}:`, (err as Error).message);
    return false;
  }
}
