import { Sprout, Waves, Leaf, ShieldCheck, Trash2, Footprints, Ruler, Users, Landmark, GraduationCap, Building2, HeartHandshake, User, Handshake, Eye, Wallet } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import type { TipoActor, Papel, SectorId, TipoAccion, EstadoAccion, AccionPlan, NivelPlan, TipoJornada, Rol } from '../../types/plataforma';

interface Opcion { etiqueta: string; icono: LucideIcon; clase: string }
export const TIPOS_ACTOR: Record<TipoActor, Opcion> = {
  comunidad: { etiqueta: 'Comunidad u organización de base', icono: Users, clase: 'bg-white/10 text-suave' },
  entidad_publica: { etiqueta: 'Entidad pública', icono: Landmark, clase: 'bg-white/10 text-cra-100' },
  academia: { etiqueta: 'Academia', icono: GraduationCap, clase: 'bg-white/10 text-cra-100' },
  empresa: { etiqueta: 'Empresa', icono: Building2, clase: 'bg-white/10 text-suave' },
  ong: { etiqueta: 'Organización no gubernamental', icono: HeartHandshake, clase: 'bg-white/10 text-dorado-300' },
  ciudadano: { etiqueta: 'Ciudadano', icono: User, clase: 'bg-white/10 text-suave' },
};
export const PAPELES: Record<Papel, Opcion> = {
  proponer_ejecutar: { etiqueta: 'Proponer y ejecutar acciones', icono: Sprout, clase: 'text-dorado-300' },
  coparticipar: { etiqueta: 'Coparticipar en acciones de otros', icono: Handshake, clase: 'text-cra-100' },
  monitorear_reportar: { etiqueta: 'Monitorear y reportar', icono: Eye, clase: 'text-cra-100' },
  financiar_cooperar: { etiqueta: 'Financiar o cooperar', icono: Wallet, clase: 'text-dorado-300' },
};
export const SECTORES: Record<SectorId, { nombre: string; largo: string; nota?: string }> = {
  mallorquin: { nombre: 'Mallorquín', largo: 'Mallorquín – Bocas de Ceniza' },
  balboa: { nombre: 'Balboa', largo: 'Puerto Colombia – Balboa – Puerto Velero' },
  manaties: { nombre: 'Manatíes', largo: 'Tubará – Juan de Acosta', nota: 'correspondencia con «Manatíes» por confirmar con la C.R.A.' },
  totumo: { nombre: 'Totumo', largo: 'Totumo – Astilleros – Galerazamba' },
};
export const TIPOS_ACCION: Record<TipoAccion, Opcion> = {
  siembra: { etiqueta: 'Siembra', icono: Sprout, clase: 'text-plan-preservacion bg-white/10' },
  restauracion_hidrologica: { etiqueta: 'Restauración hidrológica', icono: Waves, clase: 'text-capa-agua bg-white/10' },
  sbn: { etiqueta: 'Solución basada en la naturaleza', icono: Leaf, clase: 'text-capa-dosel bg-white/10' },
  conservacion_vigilancia: { etiqueta: 'Conservación y vigilancia', icono: ShieldCheck, clase: 'text-dorado-300 bg-white/10' },
};
export const ESTADOS_ACCION: Record<EstadoAccion, { etiqueta: string; clase: string }> = {
  propuesta: { etiqueta: 'PROPUESTA', clase: 'border border-white/50 text-suave' },
  en_revision: { etiqueta: 'EN REVISIÓN', clase: 'border border-cra-300 text-cra-100' },
  con_observaciones: { etiqueta: 'CON OBSERVACIONES', clase: 'border border-capa-recuperacion text-orange-200' },
  aprobada: { etiqueta: 'APROBADA', clase: 'border border-plan-preservacion text-emerald-200' },
  en_ejecucion: { etiqueta: 'EN EJECUCIÓN', clase: 'border border-dorado-300 text-dorado-300' },
  cerrada: { etiqueta: 'CERRADA', clase: 'border border-white/10 bg-white/10 text-suave' },
};
export const LISTA_ESTADOS_ACCION = Object.keys(ESTADOS_ACCION) as EstadoAccion[];
export const TRANSICIONES_ACCION: Record<EstadoAccion, { a: EstadoAccion; etiqueta: string }[]> = {
  propuesta: [{ a: 'en_revision', etiqueta: 'Iniciar revisión' }],
  en_revision: [{ a: 'aprobada', etiqueta: 'Aprobar' }, { a: 'con_observaciones', etiqueta: 'Enviar observaciones' }],
  con_observaciones: [{ a: 'en_revision', etiqueta: 'Reenviar corregida' }],
  aprobada: [{ a: 'en_ejecucion', etiqueta: 'Iniciar ejecución' }],
  en_ejecucion: [{ a: 'cerrada', etiqueta: 'Cerrar acción' }],
  cerrada: [],
};
// Hex correspondientes a los tokens plan-* de global.css.
export const ACCIONES_PLAN: Record<AccionPlan, { etiqueta: string; color: string }> = {
  preservacion: { etiqueta: 'Preservación', color: '#34d399' },
  restauracion: { etiqueta: 'Restauración', color: '#60a5fa' },
  recuperacion: { etiqueta: 'Recuperación', color: '#f97316' },
  rehabilitacion: { etiqueta: 'Rehabilitación', color: '#facc15' },
  fuera_zonificacion: { etiqueta: 'Fuera de zonificación', color: '#9ca3af' },
};
export const NIVELES_PLAN: Record<NivelPlan, { etiqueta: string; clase: string }> = {
  alta: { etiqueta: 'Alta', clase: 'text-dorado-300' },
  media: { etiqueta: 'Media', clase: 'text-cra-100' },
  baja: { etiqueta: 'Baja', clase: 'text-suave' },
};
export const NOTA_REQUERIMIENTOS_PROPUESTOS = 'propuesta del equipo: la C.R.A. define las listas';
export const REQUERIMIENTOS_POR_TIPO: Record<TipoAccion, string[]> = {
  siembra: [
    'Especie y procedencia del material vegetal',
    'Sitio dentro del manglar probable, áreas por revisar o zona de restauración del plan',
    'Temporada de lluvias con salinidad y marea verificadas',
    'Permiso o concepto de la Corporación según la Resolución 1263 de 2018',
    'Participación comunitaria acordada por escrito',
    'Plan de monitoreo a 3, 6 y 12 meses con fotografías ubicadas',
  ],
  restauracion_hidrologica: [
    'Diagnóstico de conectividad hídrica, salinidad y mareas',
    'Diseño de intervención y manejo de sedimentos',
    'Permiso o concepto de la Corporación antes de intervenir',
    'Acuerdo comunitario y medidas de seguridad',
    'Plan de seguimiento de caudales y recuperación del manglar',
  ],
  sbn: [
    'Diagnóstico del problema y justificación de la solución natural',
    'Diseño con especies nativas y evaluación de riesgos',
    'Concepto de la Corporación y autorizaciones aplicables',
    'Acuerdo comunitario de implementación y mantenimiento',
    'Indicadores y plan de monitoreo de beneficios ambientales',
  ],
  conservacion_vigilancia: [
    'Delimitación del recorrido y objetivos de conservación',
    'Acuerdo con la comunidad y responsables de los recorridos',
    'Protocolo de seguridad sin confrontación y aviso a autoridades',
    'Registro ubicado de observaciones y protección de datos personales',
    'Calendario de seguimiento y entrega de reportes a la Corporación',
  ],
};
export const TIPOS_JORNADA: Record<TipoJornada, Opcion> = {
  siembra: { etiqueta: 'Siembra', icono: Sprout, clase: 'text-plan-preservacion' },
  limpieza: { etiqueta: 'Limpieza', icono: Trash2, clase: 'text-cra-100' },
  recorrido_vigias: { etiqueta: 'Recorrido de vigías', icono: Footprints, clase: 'text-dorado-300' },
  monitoreo: { etiqueta: 'Monitoreo', icono: Ruler, clase: 'text-capa-agua' },
};
export const ROLES: Record<Rol, { etiqueta: string; descripcion: string }> = {
  administrador: { etiqueta: 'Administrador', descripcion: 'Gestiona capas, auditoría y reaperturas en modo demostración.' },
  moderador: { etiqueta: 'Moderador C.R.A.', descripcion: 'Revisa acciones y gestiona reportes en modo demostración.' },
  vigia: { etiqueta: 'Vigía comunitario', descripcion: 'Verifica en campo: solo pasa reportes a en verificación o verificado.' },
  colegio: { etiqueta: 'Colegio o aliado', descripcion: 'Participa y aporta monitoreos en modo demostración.' },
};
export type Permiso = 'revisar_acciones' | 'gestionar_reportes' | 'verificar_en_campo' | 'cargar_capas' | 'ver_auditoria' | 'reabrir';
export const PERMISOS: Record<Rol, readonly Permiso[]> = {
  administrador: ['revisar_acciones', 'gestionar_reportes', 'verificar_en_campo', 'cargar_capas', 'ver_auditoria', 'reabrir'],
  moderador: ['revisar_acciones', 'gestionar_reportes', 'verificar_en_campo', 'ver_auditoria'],
  vigia: ['verificar_en_campo'], colegio: [],
};
/** Demostración de interfaz; en producción lo decide el servidor en un solo lugar.
 * verificar_en_campo solo autoriza destinos en_verificacion y verificado;
 * el consumidor debe comprobar además las transiciones del reporte.
 */
export function puede(rol: Rol, permiso: Permiso): boolean {
  return Object.hasOwn(PERMISOS, rol) && PERMISOS[rol].includes(permiso);
}
