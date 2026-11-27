export type SectorId = 'mallorquin' | 'balboa' | 'manaties' | 'totumo';
export type TipoActor = 'comunidad' | 'entidad_publica' | 'academia' | 'empresa' | 'ong' | 'ciudadano';
export type Papel = 'proponer_ejecutar' | 'coparticipar' | 'monitorear_reportar' | 'financiar_cooperar';
export type TipoAccion = 'siembra' | 'restauracion_hidrologica' | 'sbn' | 'conservacion_vigilancia';
export type EstadoAccion = 'propuesta' | 'en_revision' | 'con_observaciones' | 'aprobada' | 'en_ejecucion' | 'cerrada';
export type AccionPlan = 'preservacion' | 'restauracion' | 'recuperacion' | 'rehabilitacion' | 'fuera_zonificacion';
export type NivelPlan = 'alta' | 'media' | 'baja';
export type TipoJornada = 'siembra' | 'limpieza' | 'recorrido_vigias' | 'monitoreo';
export type Rol = 'administrador' | 'moderador' | 'vigia' | 'colegio';

export interface Actor {
  id: string; nombre: string; tipo: TipoActor;
  /** Privado: nunca incluir en vistas o exportaciones públicas. */
  correo: string;
  sector: SectorId; papeles: Papel[]; verificado: boolean; acepta_datos: boolean; creado_en: string;
}
export interface Requerimiento { id: string; texto: string; cumplido: boolean }
export interface Accion {
  id: string; nombre: string; tipo: TipoAccion; actor_id: string; sector: SectorId | null;
  lat: number; lon: number; hectareas: number; accion_plan: AccionPlan | null;
  prioridad_plan: NivelPlan | null; plan_aproximado: boolean; estado: EstadoAccion;
  descripcion: string; comunidad_coparticipante: string; requerimientos: Requerimiento[];
  observaciones: string[]; creada_en: string;
  /** Datos públicos de origen para propuestas recibidas por Zanky. */
  codigo_bot?: string; canal?: 'whatsapp'; proponente?: string; tipo_actor?: TipoActor;
}
export interface CambioAccion {
  id: string; accion_id: string; estado: EstadoAccion; usuario_id: string;
  rol: Rol | 'sistema'; nota: string; fecha: string;
}
export interface Jornada {
  id: string; accion_id: string; titulo: string; tipo: TipoJornada; inicio: string; fin: string;
  punto_encuentro: string; lat: number; lon: number; cupos: number; inscritos: number;
  que_llevar: string[]; descripcion: string;
  /** Del servidor de Zanky: imagen de la invitación y si es una jornada de ejemplo de la demostración. */
  imagen_url?: string | null; ejemplo?: boolean;
}
/** Sin teléfono ni correo: esos datos se guardan exclusivamente en el servidor. */
export interface Inscripcion { id: string; jornada_id: string; nombre: string; fecha: string }
export interface FotoUbicada { url: string; lat: number; lon: number; tomada_en: string }
export interface ReporteMonitoreo {
  id: string; accion_id: string; fecha: string; vivas_pct: number; altura_cm: number;
  fotos: FotoUbicada[]; observaciones: string; autor_id: string;
}
