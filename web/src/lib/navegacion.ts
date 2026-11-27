// Enlaces de la navegación que comparten la portada, la cabecera de las demás
// páginas y sus menús desplegables. Un solo lugar para no repetir rutas.

export interface EnlaceNav { id: string; href: string; texto: string; detalle?: string }

/** Visores: cada mapa en su propia página. */
export const VISORES: EnlaceNav[] = [
  { id: 'reportes', href: '/visores/reportes', texto: 'Reportes de la comunidad', detalle: 'Lo que reporta la gente, con filtros y datos abiertos' },
  { id: 'riesgo', href: '/visores/riesgo', texto: 'Puntos críticos y focos de calor', detalle: 'Riesgos que registra la C.R.A. cerca del manglar' },
  { id: 'agua', href: '/visores/agua', texto: 'Calidad del agua', detalle: 'Índice de calidad de las ciénagas con manglar' },
  { id: 'workflow', href: '/workflow', texto: 'Estado del manglar', detalle: 'Extensión, cambios, altura y carbono, según la C.R.A.' },
];

/** Secciones de la plataforma abierta (también son las pestañas de PlataformaLayout). */
export const PLATAFORMA: EnlaceNav[] = [
  { id: 'inicio', href: '/plataforma', texto: 'Inicio' },
  { id: 'registro', href: '/plataforma/registro', texto: 'Registro de actor' },
  { id: 'proponer', href: '/plataforma/proponer', texto: 'Proponer acción' },
  { id: 'seguimiento', href: '/plataforma/seguimiento', texto: 'Seguimiento' },
  { id: 'jornadas', href: '/plataforma/jornadas', texto: 'Jornadas comunitarias' },
  { id: 'monitoreo', href: '/#monitoreo', texto: 'Monitoreo comunitario' },
  { id: 'proyectos', href: '/plataforma/proyectos', texto: 'Proyectos' },
  { id: 'panel', href: '/plataforma/panel', texto: 'Panel de la Corporación' },
];
