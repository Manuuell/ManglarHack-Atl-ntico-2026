// Tipos, estados y número de caso del contrato común (handoff/05 y backend/supabase/schema.sql).
// La gravedad es la misma que usan la app y el servidor (app/lib/datos/tipos.dart).

export const TIPOS = {
  tala: { nombre: 'Tala de mangle', emoji: '🪓', gravedad: 5, descripcion: 'Están cortando o arrancando mangle' },
  quema: { nombre: 'Quema o incendio', emoji: '🔥', gravedad: 5, descripcion: 'Fuego o humo en el manglar o cerca' },
  relleno: { nombre: 'Relleno o construcción', emoji: '🚧', gravedad: 4, descripcion: 'Echan tierra o escombros, o construyen' },
  vertimiento: { nombre: 'Vertimiento', emoji: '🛢️', gravedad: 4, descripcion: 'Aguas negras, aceite o químicos al agua' },
  cano_taponado: { nombre: 'Caño tapado', emoji: '🚱', gravedad: 4, descripcion: 'Un caño o paso de agua está bloqueado' },
  fauna: { nombre: 'Fauna afectada', emoji: '🐟', gravedad: 4, descripcion: 'Caza, o peces o aves muertos' },
  basuras: { nombre: 'Basuras', emoji: '🗑️', gravedad: 2, descripcion: 'Residuos acumulados en el manglar o la orilla' },
  otro: { nombre: 'Otra amenaza', emoji: '❓', gravedad: 2, descripcion: 'Algo distinto que pone en riesgo el manglar' },
} as const;

export type TipoId = keyof typeof TIPOS;

export function esTipo(id: string): id is TipoId {
  return Object.prototype.hasOwnProperty.call(TIPOS, id);
}

/** `momento` del contrato: cuándo está pasando. */
export const MOMENTOS = {
  ahora: 'Ahora mismo',
  hoy: 'Hoy, más temprano',
  antes: 'Antes de hoy',
} as const;

export type MomentoId = keyof typeof MOMENTOS;

export function esMomento(id: string): id is MomentoId {
  return Object.prototype.hasOwnProperty.call(MOMENTOS, id);
}

/** `magnitud` del contrato, con los mismos ejemplos que la app. */
export const MAGNITUDES = {
  pequena: { nombre: 'Pequeña', ejemplo: 'Unos metros' },
  mediana: { nombre: 'Mediana', ejemplo: 'Como una cancha' },
  grande: { nombre: 'Grande', ejemplo: 'Más que una cancha' },
} as const;

export type MagnitudId = keyof typeof MAGNITUDES;

export function esMagnitud(id: string): id is MagnitudId {
  return Object.prototype.hasOwnProperty.call(MAGNITUDES, id);
}

export type Estado = 'recibido' | 'en_verificacion' | 'verificado' | 'alerta_oficial' | 'en_atencion' | 'cerrado' | 'descartado';

export const ESTADOS: Record<Estado, string> = {
  recibido: 'Recibido',
  en_verificacion: 'En verificación',
  verificado: 'Verificado',
  alerta_oficial: 'Alerta oficial (expediente abierto)',
  en_atencion: 'En atención',
  cerrado: 'Cerrado',
  descartado: 'Descartado',
};

/** Qué significa cada estado para el ciudadano: las mismas descripciones de la web (web/src/lib/catalogos.ts). */
export const DESCRIPCION_ESTADO: Record<Estado, string> = {
  recibido: 'Recibido para revisión.',
  en_verificacion: 'Una persona de la C.R.A. revisa la evidencia.',
  verificado: 'Hallazgo confirmado por una persona.',
  alerta_oficial: 'Alerta emitida con apertura de expediente.',
  en_atencion: 'Caso en atención por el equipo.',
  cerrado: 'Seguimiento finalizado.',
  descartado: 'La evidencia no confirma el reporte.',
};

export function esEstado(v: unknown): v is Estado {
  return typeof v === 'string' && Object.prototype.hasOwnProperty.call(ESTADOS, v);
}

/** Número de caso común a la app, el bot y el panel: ZK- + 4 primeros hex del UUID. */
export function numeroDeCaso(id: string): string {
  return 'ZK-' + id.replace(/-/g, '').slice(0, 4).toUpperCase();
}

/** Recuadro del Atlántico ampliado que acepta el servidor (schema.sql). */
export const ATLANTICO = { latMin: 10.2, latMax: 11.4, lonMin: -75.7, lonMax: -74.4 };

export function enAtlantico(lat: number, lon: number): boolean {
  return lat >= ATLANTICO.latMin && lat <= ATLANTICO.latMax && lon >= ATLANTICO.lonMin && lon <= ATLANTICO.lonMax;
}

export type FuenteUbicacion = 'gps' | 'enlace';

export interface CambioEstado {
  estado: Estado;
  fecha: string;
  por: string;
  nota?: string;
}

/** Cómo va el envío del reporte al backend común (Supabase). */
export interface Envio {
  estado: 'pendiente' | 'enviado' | 'rechazado' | 'sin_backend';
  intentos: number;
  ultimoError?: string;
  enviadoEn?: string;
}

export interface Reporte {
  /** UUID del reporte (contrato común). Sale del id del mensaje de WhatsApp: un reintento no lo duplica. */
  id: string;
  /** Número de caso: ZK- + 4 hex del UUID. */
  codigo: string;
  canal: 'whatsapp';
  tipo: TipoId;
  descripcion?: string;
  lat: number;
  lon: number;
  fuenteUbicacion: FuenteUbicacion;
  /** Id de la zona del contrato (mallorquin, tubara, juan_de_acosta, piojo). El servidor la recalcula. */
  zona?: string;
  zonaNombre?: string;
  municipio?: string;
  dentroPoligono: boolean;
  distanciaM: number;
  momento: MomentoId;
  magnitud: MagnitudId;
  /** Hora en que la persona envió la ubicación, según WhatsApp. */
  capturado_en: string;
  /** Hora en que el bot armó el reporte. */
  recibido_en: string;
  prioridad: number;
  confianza: number;
  motivosConfianza: string[];
  estado: Estado;
  foto?: { archivo: string; hash: string; jpeg: boolean };
  /** Hash del número: cuenta reportes por persona sin guardar el número en claro. Va como reportante_id. */
  reportanteHash: string;
  anonimo: boolean;
  /** Solo si la persona aceptó reportar con su número. */
  contacto?: string;
  /** A quién avisar cuando un envío pendiente por fin llegue al servidor; se borra al avisar. */
  avisarA?: string;
  envio: Envio;
  historial: CambioEstado[];
  /** Id que publica la vista reportes_publicos (el del mapa de la web). Lo devuelve crear_reporte. */
  idPublico?: string;
  /** Último estado del que ya se avisó por WhatsApp (sin valor: «recibido», que se dice al enviar). */
  estadoAvisado?: Estado;
  /** Intentos fallidos de avisar el estado actual (fuera de la ventana de 24 h de WhatsApp, por ejemplo). */
  avisoFallidos?: number;
}

/** Estados en los que el caso ya no cambia: tras avisarlos no se vuelve a preguntar por ese reporte. */
export const ESTADOS_FINALES: ReadonlySet<Estado> = new Set(['cerrado', 'descartado']);

export const ROLES = {
  pescador: { nombre: 'Pescador/a', emoji: '🎣', descripcion: 'Vivo de la ciénaga o del mar' },
  habitante: { nombre: 'Habitante de la zona', emoji: '🏠', descripcion: 'Vivo cerca del manglar' },
  estudiante: { nombre: 'Estudiante o colegio', emoji: '🎒', descripcion: 'Vengo de un colegio o universidad' },
  turista: { nombre: 'Turista o visitante', emoji: '🧳', descripcion: 'Estoy de paso por la zona' },
  organizacion: { nombre: 'Organización', emoji: '🌱', descripcion: 'Fundación, empresa o grupo ambiental' },
  entidad: { nombre: 'Entidad pública', emoji: '🏛️', descripcion: 'Trabajo en una entidad del Estado' },
  otro: { nombre: 'Otro', emoji: '🙋', descripcion: 'Ninguna de las anteriores' },
} as const;

export type RolId = keyof typeof ROLES;

export const MUNICIPIOS = {
  barranquilla: 'Barranquilla',
  puerto_colombia: 'Puerto Colombia',
  tubara: 'Tubará',
  juan_de_acosta: 'Juan de Acosta',
  piojo: 'Piojó',
  otro_atlantico: 'Otro del Atlántico',
  fuera: 'Fuera del Atlántico',
} as const;

export type MunicipioId = keyof typeof MUNICIPIOS;

export function esRol(id: string): id is RolId {
  return Object.prototype.hasOwnProperty.call(ROLES, id);
}

export function esMunicipio(id: string): id is MunicipioId {
  return Object.prototype.hasOwnProperty.call(MUNICIPIOS, id);
}

export interface Usuario {
  consentimiento: 'identificado' | 'anonimo';
  fecha: string;
  /** Datos del registro de vigías. El nombre y el contacto solo si eligió registrarse con su número. */
  nombre?: string;
  contacto?: string;
  rol?: RolId;
  municipio?: MunicipioId;
  vigiaNumero?: number;
  registradoEn?: string;
}
