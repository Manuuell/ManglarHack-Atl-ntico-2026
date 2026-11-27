import { createHash } from 'crypto';
import { config } from '../config';
import { whatsapp } from '../whatsapp/cloudApi';
import { MensajeEntrante } from '../whatsapp/parser';
import { ubicar } from '../geo/zonas';
import { ubicacionDesdeTexto } from '../geo/ubicacionTexto';
import * as almacen from '../reportes/almacen';
import { confianza, corroboraciones, prioridad } from '../reportes/evaluacion';
import { CuandoId, FuenteUbicacion, TipoId, esTipo } from '../reportes/modelo';
import * as T from './textos';

type Paso = 'menu' | 'consentimiento' | 'tipo' | 'ubicacion' | 'confirmar_lejos' | 'foto' | 'descripcion' | 'cuando' | 'confirmar';

interface Borrador {
  tipo?: TipoId;
  lat?: number;
  lon?: number;
  fuenteUbicacion?: FuenteUbicacion;
  capturadoEn?: string;
  dentro?: boolean;
  distanciaM?: number;
  zona?: string;
  prioridadZona?: number;
  foto?: { archivo: string; hash: string };
  conFoto?: boolean;
  descripcion?: string;
  cuando?: CuandoId;
}

interface Sesion {
  paso: Paso;
  borrador: Borrador;
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
  t.trim().toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9 ]/g, '').trim();

const COMANDOS_MENU = new Set(['menu', 'inicio', 'hola', 'buenas', 'buenos dias', 'buenas tardes', 'zanqui', 'empezar', 'start']);

async function enviarMenu(de: string, s: Sesion): Promise<void> {
  ir(s, 'menu');
  s.borrador = {};
  await whatsapp.botones(de, T.MENU.cuerpo, T.MENU.botones, T.ENCABEZADO);
}

async function empezarReporte(de: string, s: Sesion): Promise<void> {
  const hash = almacen.hashDe(de);
  const recientes = almacen.delReportante(hash).filter(r => Date.now() - Date.parse(r.recibidoEn) < 3600 * 1000);
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
  const u = ubicar(lat, lon);
  Object.assign(s.borrador, {
    lat,
    lon,
    fuenteUbicacion: fuente,
    capturadoEn: new Date(ts * 1000).toISOString(),
    dentro: u.dentro,
    distanciaM: u.distanciaM,
    zona: u.zona,
    prioridadZona: u.prioridadZona,
  });
  if (!u.dentro && u.distanciaM > config.distanciaSospechosaM) {
    ir(s, 'confirmar_lejos');
    await whatsapp.botones(de, T.ubicacionLejana(u.distanciaM), T.BOTONES_LEJOS);
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
    T.resumen({ tipo: b.tipo!, zona: b.zona, dentro: !!b.dentro, distanciaM: b.distanciaM ?? 0, conFoto: !!b.conFoto, descripcion: b.descripcion, cuando: b.cuando! }),
    T.BOTONES_CONFIRMAR,
  );
}

async function guardarReporte(de: string, s: Sesion): Promise<void> {
  const b = s.borrador;
  if (!b.tipo || b.lat === undefined || b.lon === undefined || !b.cuando || !b.fuenteUbicacion) {
    await whatsapp.texto(de, T.NO_ENTENDI);
    await enviarMenu(de, s);
    return;
  }
  const hash = almacen.hashDe(de);
  const existentes = almacen.todos();
  const datos = {
    tipo: b.tipo,
    lat: b.lat,
    lon: b.lon,
    fuenteUbicacion: b.fuenteUbicacion,
    dentroPoligono: !!b.dentro,
    distanciaM: b.distanciaM ?? 0,
    prioridadZona: b.prioridadZona,
    cuando: b.cuando,
    tieneFoto: !!b.conFoto,
    fotoHash: b.foto?.hash,
    descripcion: b.descripcion,
    reportanteHash: hash,
  };
  const corroborados = corroboraciones(datos, existentes);
  const conf = confianza(datos, existentes, corroborados);
  const ahora = new Date().toISOString();
  const u = almacen.usuario(hash);
  const reporte = almacen.crearReporte({
    codigo: almacen.siguienteCodigo(),
    canal: 'whatsapp',
    tipo: b.tipo,
    descripcion: b.descripcion,
    lat: b.lat,
    lon: b.lon,
    fuenteUbicacion: b.fuenteUbicacion,
    zona: b.zona,
    dentroPoligono: !!b.dentro,
    distanciaM: b.distanciaM ?? 0,
    cuando: b.cuando,
    capturadoEn: b.capturadoEn ?? ahora,
    recibidoEn: ahora,
    prioridad: prioridad(datos, corroborados),
    confianza: conf.puntaje,
    motivosConfianza: conf.motivos,
    estado: 'recibido',
    foto: b.foto,
    reportanteHash: hash,
    ...(u?.consentimiento === 'identificado' ? { contacto: de } : {}),
    historial: [{ estado: 'recibido', fecha: ahora, por: 'zanqui-bot' }],
  });
  console.log(`[reporte] ${reporte.codigo} ${reporte.tipo} prioridad ${reporte.prioridad} confianza ${reporte.confianza}`);
  ir(s, 'menu');
  s.borrador = {};
  await whatsapp.texto(de, T.enviado(reporte.codigo));
}

async function recibirFoto(de: string, s: Sesion, mediaId: string, sha256Meta?: string): Promise<void> {
  try {
    const media = await whatsapp.descargarMedia(mediaId);
    if (media) {
      const hash = media.sha256 ?? createHash('sha256').update(media.datos).digest('hex');
      s.borrador.foto = { archivo: almacen.guardarFoto(media.datos, hash, media.mime), hash };
    } else {
      // Modo simulación: no hay archivo, pero sí el hash que reporta WhatsApp.
      s.borrador.foto = { archivo: '', hash: sha256Meta ?? mediaId };
    }
    s.borrador.conFoto = true;
  } catch (err) {
    console.error('[foto] no se pudo descargar:', (err as Error).message);
    s.borrador.conFoto = false;
  }
  ir(s, 'descripcion');
  await whatsapp.botones(de, `${s.borrador.conFoto ? '📸 ¡Foto recibida!' : 'No pude guardar la foto, sigamos sin ella.'}\n\n${T.PEDIR_DESCRIPCION}`, T.BOTON_OMITIR);
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
  if (COMANDOS_MENU.has(texto)) {
    await enviarMenu(de, s);
    return;
  }

  switch (s.paso) {
    case 'menu': {
      if (opcion === 'reportar' || texto.includes('report') || texto.includes('denunci')) return empezarReporte(de, s);
      if (opcion === 'mis_reportes' || texto.includes('mis reportes')) {
        await whatsapp.texto(de, T.misReportes(almacen.delReportante(almacen.hashDe(de))));
        return;
      }
      if (opcion === 'como_funciona') {
        await whatsapp.texto(de, T.COMO_FUNCIONA);
        await whatsapp.botones(de, '¿Qué quieres hacer?', T.MENU.botones);
        return;
      }
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

    case 'confirmar_lejos': {
      if (opcion === 'seguir') return pedirFoto(de, s);
      if (opcion === 'otra_ubicacion') return pedirUbicacion(de, s);
      if (entrada.tipo === 'ubicacion') return registrarUbicacion(de, s, entrada.lat, entrada.lon, 'gps', m.timestamp);
      await whatsapp.botones(de, T.ubicacionLejana(s.borrador.distanciaM ?? 0), T.BOTONES_LEJOS);
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
      if (opcion === 'ahora' || opcion === 'hoy' || opcion === 'dias') {
        s.borrador.cuando = opcion;
        return enviarResumen(de, s);
      }
      await whatsapp.botones(de, T.PEDIR_CUANDO, T.BOTONES_CUANDO);
      return;
    }

    case 'confirmar': {
      if (opcion === 'enviar') return guardarReporte(de, s);
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
