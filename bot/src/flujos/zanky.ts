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
import { backendActivo, estadoDeReportes } from '../backend/supabase';
import { buscarJornada, proximasJornadas } from '../jornadas/jornadas';
import { config as configBot } from '../config';
import * as T from './textos';
import { iaActiva, limpiarHistorial, responder, Turno } from '../ia/zanky';

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
  | 'jornadas'
  | 'confirmar';

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
  momento?: MomentoId;
  magnitud?: MagnitudId;
}

interface Sesion {
  paso: Paso;
  borrador: Borrador;
  registro?: Registro;
  /** Si dijo "Ahora no" al registro, no se le vuelve a ofrecer en esta conversación. */
  rechazoRegistro?: boolean;
  actualizada: number;
}

const sesiones = new Map<string, Sesion>();

function sesionDe(de: string): Sesion {
  const s = sesiones.get(de);
  if (s && Date.now() - s.actualizada < config.sesionTtlMs) return s;
  const nueva: Sesion = { paso: 'menu', borrador: {}, actualizada: Date.now() };
  sesiones.set(de, nueva);
  return nueva;
}

function ir(s: Sesion, paso: Paso): void {
  s.paso = paso;
  s.actualizada = Date.now();
}

const normalizar = (t: string) =>
  t.trim().toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9 ]/g, '').trim();

const COMANDOS_MENU = new Set(['menu', 'inicio', 'hola', 'buenas', 'buenos dias', 'buenas tardes', 'zanky', 'zanqui', 'empezar', 'start']);

async function enviarMenu(de: string, s: Sesion): Promise<void> {
  ir(s, 'menu');
  s.borrador = {};
  const u = almacen.usuario(almacen.hashDe(de));
  const cuerpo = u?.vigiaNumero ? T.saludoMenu(u.nombre) : T.MENU.cuerpo;
  await whatsapp.botones(de, cuerpo, T.MENU.botones, T.ENCABEZADO);
}

/** Primer contacto: a quien no está registrado se le ofrece ser vigía; a los demás, el menú. */
async function inicio(de: string, s: Sesion): Promise<void> {
  const u = almacen.usuario(almacen.hashDe(de));
  if (!u?.vigiaNumero && !s.rechazoRegistro) return empezarRegistro(de, s);
  return enviarMenu(de, s);
}

async function empezarRegistro(de: string, s: Sesion): Promise<void> {
  s.borrador = {};
  s.registro = undefined;
  ir(s, 'registro_inicio');
  await whatsapp.botones(de, T.BIENVENIDA.cuerpo, T.BIENVENIDA.botones, T.ENCABEZADO);
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

async function empezarReporte(de: string, s: Sesion): Promise<void> {
  const hash = almacen.hashDe(de);
  const recientes = almacen.delReportante(hash).filter(r => Date.now() - Date.parse(r.recibido_en) < 3600 * 1000);
  if (recientes.length >= config.maxReportesPorHora) {
    await whatsapp.texto(de, T.DEMASIADOS);
    return;
  }
  s.borrador = {};
  if (!almacen.usuario(hash)) {
    ir(s, 'consentimiento');
    await whatsapp.botones(de, T.CONSENTIMIENTO.cuerpo, T.CONSENTIMIENTO.botones, undefined, T.CONSENTIMIENTO.pie);
    return;
  }
  await pedirTipo(de, s);
}

async function pedirTipo(de: string, s: Sesion): Promise<void> {
  ir(s, 'tipo');
  await whatsapp.lista(de, T.TIPO.cuerpo, T.TIPO.boton, T.TIPO.filas);
}

async function pedirUbicacion(de: string, s: Sesion): Promise<void> {
  ir(s, 'ubicacion');
  await whatsapp.pedirUbicacion(de, T.PEDIR_UBICACION);
}

async function pedirFoto(de: string, s: Sesion): Promise<void> {
  ir(s, 'foto');
  await whatsapp.botones(de, T.PEDIR_FOTO, T.BOTON_SIN_FOTO);
}

async function registrarUbicacion(de: string, s: Sesion, lat: number, lon: number, fuente: FuenteUbicacion, ts: number): Promise<void> {
  if (!enAtlantico(lat, lon)) {
    ir(s, 'ubicacion');
    await whatsapp.texto(de, T.FUERA_DEL_ATLANTICO);
    await whatsapp.pedirUbicacion(de, T.PEDIR_UBICACION);
    return;
  }
  const u = ubicar(lat, lon);
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
  // Regla común con la web: dentro de la cobertura C.R.A. 1:5.000 o a menos de RADIO_INFLUENCIA_M. Más lejos
  // (por ejemplo, el casco urbano de Barranquilla) la denuncia no corresponde y no se crea el reporte.
  if (!enAreaDeReporte(u, config.radioInfluenciaM)) {
    ir(s, 'fuera_area');
    await whatsapp.botones(de, T.fueraDelArea(config.radioInfluenciaM), T.BOTONES_FUERA_DEL_AREA);
    return;
  }
  await whatsapp.texto(de, T.ubicacionRecibida(u.dentro, u.distanciaM, u.zona));
  await pedirFoto(de, s);
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
  if (!b.tipo || b.lat === undefined || b.lon === undefined || !b.momento || !b.magnitud || !b.fuenteUbicacion) {
    await whatsapp.texto(de, T.NO_ENTENDI);
    await enviarMenu(de, s);
    return;
  }
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
  // Solo se dice «ya está en el panel» cuando el backend común lo guardó.
  const resultado = await enviarReporte(reporte);
  if (resultado === 'enviado') await whatsapp.texto(de, T.enviado(reporte.codigo));
  else if (resultado === 'sin_backend') await whatsapp.texto(de, T.guardadoSinBackend(reporte.codigo));
  else if (resultado === 'rechazado') await whatsapp.texto(de, T.ENVIO_RECHAZADO);
  else {
    reporte.avisarA = de;
    almacen.actualizar(reporte);
    await whatsapp.texto(de, T.ENVIO_PENDIENTE);
  }
}

async function recibirFoto(de: string, s: Sesion, mediaId: string, sha256Meta?: string): Promise<void> {
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
  } catch (err) {
    console.error('[foto] no se pudo descargar:', (err as Error).message);
    s.borrador.conFoto = false;
  }
  ir(s, 'descripcion');
  await whatsapp.botones(de, `${s.borrador.conFoto ? '📸 ¡Foto recibida!' : 'No pude guardar la foto, sigamos sin ella.'}\n\n${T.PEDIR_DESCRIPCION}`, T.BOTON_OMITIR);
}

const webJornadas = () => `${new URL(configBot.jornadasUrl).origin}/plataforma/jornadas`;

/** Lista las próximas jornadas comunitarias que publica la web. */
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

/** Manda la invitación de una jornada con el enlace de inscripción de la web. */
async function enviarInvitacion(de: string, s: Sesion, id: string): Promise<void> {
  const { aviso } = await proximasJornadas().catch(() => ({ aviso: '' }));
  const j = buscarJornada(id);
  if (!j) return mostrarJornadas(de, s);
  await whatsapp.texto(de, T.invitacionJornada(j, aviso));
  await whatsapp.botones(de, '¿Qué más quieres hacer?', T.BOTONES_DESPUES_DE_JORNADA);
}

/** Los reportes de la persona con el estado que tiene hoy en el backend común (lo cambia la CRA en el panel). */
async function misReportesConEstado(de: string) {
  const propios = almacen.delReportante(almacen.hashDe(de));
  const enviados = propios.filter(r => r.envio?.estado === 'enviado').slice(-20);
  if (backendActivo() && enviados.length) {
    try {
      const estados = await estadoDeReportes(enviados.map(r => r.id));
      for (const e of estados) {
        const r = propios.find(x => x.id === e.id);
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
  return propios;
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
    // La respuesta va con los botones del menú en el mismo mensaje (el cuerpo admite hasta 1024 caracteres).
    await whatsapp.botones(de, respuesta.length > 1000 ? `${respuesta.slice(0, 997)}…` : respuesta, T.MENU.botones);
  } catch (err) {
    console.warn(`[ia] ${(err as Error).message.slice(0, 200)}`);
    await whatsapp.botones(de, T.IA_NO_DISPONIBLE, T.MENU.botones);
  }
}

/** Atiende un mensaje entrante según el paso en que va la conversación. */
export async function atender(m: MensajeEntrante): Promise<void> {
  const { de, entrada } = m;
  const s = sesionDe(de);
  const texto = entrada.tipo === 'texto' ? normalizar(entrada.texto) : '';
  const opcion = entrada.tipo === 'opcion' ? entrada.id : '';

  // Comandos que funcionan en cualquier paso.
  if (texto === 'cancelar' || opcion === 'cancelar') {
    await whatsapp.texto(de, T.CANCELADO);
    await enviarMenu(de, s);
    return;
  }
  if (texto === 'registro' || texto === 'registrarme') return empezarRegistro(de, s);
  if (texto === 'jornadas' || texto === 'jornada' || texto === 'eventos') return mostrarJornadas(de, s);
  if (texto === 'ayuda' || texto === 'como funciona') {
    await whatsapp.texto(de, T.COMO_FUNCIONA);
    return enviarMenu(de, s);
  }
  // Un saludo («hola zanky», el que trae el botón de la web) abre el menú; no gasta una pregunta de la IA.
  if (COMANDOS_MENU.has(texto) || /^(hola|buenas|buenos dias|buenas tardes|buenas noches)[ ,!.]*(zanky|zanqui)?[ !.]*$/.test(texto)) return inicio(de, s);

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
      await whatsapp.botones(de, T.BIENVENIDA.cuerpo, T.BIENVENIDA.botones, T.ENCABEZADO);
      return;
    }

    case 'registro_nombre': {
      const nombre = entrada.tipo === 'texto' ? nombreValido(entrada.texto) : null;
      if (!nombre || !s.registro) {
        await whatsapp.texto(de, T.NOMBRE_INVALIDO);
        return;
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
      await whatsapp.lista(de, T.ROL.cuerpo, T.ROL.boton, T.ROL.filas);
      return;
    }

    case 'registro_municipio': {
      if (esMunicipio(opcion)) return terminarRegistro(de, s, opcion);
      await whatsapp.lista(de, T.MUNICIPIO.cuerpo, T.MUNICIPIO.boton, T.MUNICIPIO.filas);
      return;
    }

    case 'menu': {
      // Primer mensaje de alguien nuevo (cualquier texto): se le ofrece el registro.
      if (!opcion && !s.rechazoRegistro && !almacen.usuario(almacen.hashDe(de))?.vigiaNumero && entrada.tipo === 'texto' && !texto.includes('report') && !/jornad/.test(texto)) {
        return empezarRegistro(de, s);
      }
      if (opcion === 'reportar' || texto.includes('report') || texto.includes('denunci')) return empezarReporte(de, s);
      if (opcion === 'mis_reportes' || texto.includes('mis reportes')) {
        await whatsapp.texto(de, T.misReportes(await misReportesConEstado(de)));
        return;
      }
      if (opcion === 'jornadas' || /jornad|siembra|voluntari|limpieza de/.test(texto)) return mostrarJornadas(de, s);
      if (opcion === 'como_funciona') {
        await whatsapp.texto(de, T.COMO_FUNCIONA);
        await whatsapp.botones(de, '¿Qué quieres hacer?', T.MENU.botones);
        return;
      }
      // Una pregunta o comentario libre: Zanky conversa (OpenAI) y deja a mano el menú.
      if (entrada.tipo === 'texto' && iaActiva() && entrada.texto.trim().length >= 2) return conversar(de, entrada.texto);
      return enviarMenu(de, s);
    }

    case 'consentimiento': {
      if (opcion === 'acepto' || opcion === 'anonimo') {
        almacen.guardarUsuario(almacen.hashDe(de), {
          consentimiento: opcion === 'acepto' ? 'identificado' : 'anonimo',
          fecha: new Date().toISOString(),
        });
        return pedirTipo(de, s);
      }
      if (opcion === 'no_acepto') {
        await whatsapp.texto(de, T.SIN_CONSENTIMIENTO);
        ir(s, 'menu');
        return;
      }
      await whatsapp.botones(de, T.CONSENTIMIENTO.cuerpo, T.CONSENTIMIENTO.botones, undefined, T.CONSENTIMIENTO.pie);
      return;
    }

    case 'tipo': {
      if (esTipo(opcion)) {
        s.borrador.tipo = opcion;
        return pedirUbicacion(de, s);
      }
      await whatsapp.lista(de, T.TIPO.cuerpo, T.TIPO.boton, T.TIPO.filas);
      return;
    }

    case 'ubicacion': {
      if (entrada.tipo === 'ubicacion') return registrarUbicacion(de, s, entrada.lat, entrada.lon, 'gps', m.timestamp);
      if (entrada.tipo === 'texto') {
        const coords = await ubicacionDesdeTexto(entrada.texto);
        if (coords) return registrarUbicacion(de, s, coords.lat, coords.lon, 'enlace', m.timestamp);
      }
      await whatsapp.texto(de, T.UBICACION_NO_LEIDA);
      await whatsapp.pedirUbicacion(de, T.PEDIR_UBICACION);
      return;
    }

    case 'fuera_area': {
      if (opcion === 'otra_ubicacion') return pedirUbicacion(de, s);
      if (opcion === 'menu') return enviarMenu(de, s);
      if (entrada.tipo === 'ubicacion') return registrarUbicacion(de, s, entrada.lat, entrada.lon, 'gps', m.timestamp);
      if (entrada.tipo === 'texto') {
        const coords = await ubicacionDesdeTexto(entrada.texto);
        if (coords) return registrarUbicacion(de, s, coords.lat, coords.lon, 'enlace', m.timestamp);
      }
      await whatsapp.botones(de, T.fueraDelArea(config.radioInfluenciaM), T.BOTONES_FUERA_DEL_AREA);
      return;
    }

    case 'foto': {
      if (entrada.tipo === 'imagen') return recibirFoto(de, s, entrada.mediaId, entrada.sha256);
      if (opcion === 'sin_foto') {
        s.borrador.conFoto = false;
        ir(s, 'descripcion');
        await whatsapp.botones(de, T.PEDIR_DESCRIPCION, T.BOTON_OMITIR);
        return;
      }
      await whatsapp.botones(de, T.PEDIR_FOTO, T.BOTON_SIN_FOTO);
      return;
    }

    case 'descripcion': {
      if (entrada.tipo === 'texto' && entrada.texto.trim().length >= 2) s.borrador.descripcion = entrada.texto.trim().slice(0, 500);
      else if (opcion !== 'omitir') {
        await whatsapp.botones(de, T.PEDIR_DESCRIPCION, T.BOTON_OMITIR);
        return;
      }
      ir(s, 'cuando');
      await whatsapp.botones(de, T.PEDIR_CUANDO, T.BOTONES_CUANDO);
      return;
    }

    case 'cuando': {
      if (esMomento(opcion)) {
        s.borrador.momento = opcion;
        ir(s, 'magnitud');
        await whatsapp.botones(de, T.PEDIR_MAGNITUD, T.BOTONES_MAGNITUD);
        return;
      }
      await whatsapp.botones(de, T.PEDIR_CUANDO, T.BOTONES_CUANDO);
      return;
    }

    case 'magnitud': {
      if (esMagnitud(opcion)) {
        s.borrador.magnitud = opcion;
        return enviarResumen(de, s);
      }
      await whatsapp.botones(de, T.PEDIR_MAGNITUD, T.BOTONES_MAGNITUD);
      return;
    }

    case 'jornadas': {
      if (opcion.startsWith('jor:')) return enviarInvitacion(de, s, opcion.slice(4));
      if (opcion === 'jornadas') return mostrarJornadas(de, s);
      if (opcion === 'menu') return enviarMenu(de, s);
      if (opcion === 'reportar' || texto.includes('report')) return empezarReporte(de, s);
      return mostrarJornadas(de, s);
    }

    case 'confirmar': {
      if (opcion === 'enviar') return guardarReporte(de, s, m.messageId);
      if (opcion === 'reiniciar') return pedirTipo(de, s);
      return enviarResumen(de, s);
    }
  }
}

/** Avisa a la persona cuando la CRA cambia el estado de su reporte (solo si reportó con su número). */
export async function avisarCambio(contacto: string | undefined, codigo: string, estado: Parameters<typeof T.cambioDeEstado>[1]): Promise<void> {
  if (!contacto) return;
  try {
    await whatsapp.texto(contacto, T.cambioDeEstado(codigo, estado));
  } catch (err) {
    // Fuera de la ventana de 24 horas WhatsApp exige una plantilla aprobada.
    console.warn(`[aviso] no se pudo avisar ${codigo}:`, (err as Error).message);
  }
}
