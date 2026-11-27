export const TIPOS = {
  tala: { nombre: 'Tala de mangle', emoji: '🪓', gravedad: 5, descripcion: 'Están cortando o arrancando mangle' },
  quema: { nombre: 'Quema o incendio', emoji: '🔥', gravedad: 5, descripcion: 'Fuego o humo en el manglar o cerca' },
  relleno: { nombre: 'Relleno o construcción', emoji: '🚧', gravedad: 4, descripcion: 'Echan tierra o escombros, o construyen' },
  vertimiento: { nombre: 'Vertimiento', emoji: '🛢️', gravedad: 4, descripcion: 'Aguas negras, aceite o químicos al agua' },
  cano_taponado: { nombre: 'Caño tapado', emoji: '🚱', gravedad: 3, descripcion: 'Un caño o paso de agua está bloqueado' },
  fauna: { nombre: 'Fauna afectada', emoji: '🐟', gravedad: 3, descripcion: 'Caza, o peces o aves muertos' },
  basuras: { nombre: 'Basuras', emoji: '🗑️', gravedad: 2, descripcion: 'Residuos acumulados en el manglar o la orilla' },
  otro: { nombre: 'Otra amenaza', emoji: '❓', gravedad: 2, descripcion: 'Algo distinto que pone en riesgo el manglar' },
} as const;

export type TipoId = keyof typeof TIPOS;

export function esTipo(id: string): id is TipoId {
  return Object.prototype.hasOwnProperty.call(TIPOS, id);
}

export const CUANDO = {
  ahora: 'Ahora mismo',
  hoy: 'Hoy, más temprano',
  dias: 'Hace días',
} as const;

export type CuandoId = keyof typeof CUANDO;

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

export function esEstado(v: unknown): v is Estado {
  return typeof v === 'string' && Object.prototype.hasOwnProperty.call(ESTADOS, v);
}

export type FuenteUbicacion = 'gps' | 'enlace';

export interface CambioEstado {
  estado: Estado;
  fecha: string;
  por: string;
  nota?: string;
}

export interface Reporte {
  /** UUID del reporte (contrato común). Se deriva del mensaje de WhatsApp, así un reintento no lo duplica. */
  id: string;
  /** Código corto para la persona y la CRA, ej. ZQ-0001. */
  codigo: string;
  canal: 'whatsapp';
  tipo: TipoId;
  descripcion?: string;
  lat: number;
  lon: number;
  fuenteUbicacion: FuenteUbicacion;
  zona?: string;
  dentroPoligono: boolean;
  distanciaM: number;
  cuando: CuandoId;
  /** Hora en que la persona envió la ubicación, según WhatsApp. */
  capturado_en: string;
  /** Hora en que el reporte quedó guardado. */
  recibido_en: string;
  prioridad: number;
  confianza: number;
  motivosConfianza: string[];
  estado: Estado;
  foto?: { archivo: string; hash: string };
  /** Hash del número: permite contar reportes por persona sin guardar el número en claro. */
  reportanteHash: string;
  /** Solo si la persona aceptó reportar con su número. */
  contacto?: string;
  historial: CambioEstado[];
}

export interface Usuario {
  consentimiento: 'identificado' | 'anonimo';
  fecha: string;
}
