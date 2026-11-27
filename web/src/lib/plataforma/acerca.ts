// Contenido de «Acerca de la plataforma», transcrito de la página de la C.R.A.
// (https://manglarcra.netlify.app/plataforma) el 27 de noviembre de 2026, más lo
// que el equipo SENTRALABS · UTB agregó en esta web. El plan de manejo vive en
// `PLAN_MANEJO` de ../workflow.ts.

export const URL_ACERCA_CRA = 'https://manglarcra.netlify.app/plataforma';
export const FUENTE_ACERCA = 'Plataforma abierta de la C.R.A., página «Acerca de la plataforma» (manglarcra.netlify.app/plataforma), consultada el 27 de noviembre de 2026';

export const QUE_HARA_LA_PLATAFORMA: { titulo: string; texto: string; enlace?: string }[] = [
  { titulo: 'Registro de actores', texto: 'Comunidades, organizaciones, entidades, academia y empresas, con perfil y área de interés en el mapa.', enlace: '/plataforma/registro' },
  { titulo: 'Propuesta de acciones', texto: 'Sobre el mapa del manglar y de las áreas por revisar: siembra, restauración, soluciones basadas en la naturaleza y conservación.', enlace: '/plataforma/proponer' },
  { titulo: 'Listas de chequeo por tipo de acción', texto: 'Definidas por la Corporación: permisos, especies, sitio, temporada, origen del material vegetal y participación comunitaria.', enlace: '/plataforma/proponer' },
  { titulo: 'Flujo con la autoridad ambiental', texto: 'Propuesta, revisión, observaciones, aprobación, ejecución y cierre, con el estado visible para quien propuso.', enlace: '/plataforma/seguimiento' },
  { titulo: 'Coparticipación de las comunidades locales', texto: 'En cada acción, con su papel y su aporte registrados.', enlace: '/plataforma/seguimiento' },
  { titulo: 'Monitoreo y reporte a la Corporación', texto: 'Fotografías ubicadas, supervivencia de plántulas, altura e indicadores, en las fechas que la Corporación defina.', enlace: '/plataforma/monitoreo' },
  { titulo: 'Formulación de proyectos', texto: 'Plantillas guiadas para la Metodología General Ajustada del Departamento Nacional de Planeación y para convocatorias de cooperación internacional, con los datos del manglar del sitio.', enlace: '/plataforma/proyectos' },
  { titulo: 'Actualización trimestral automática', texto: 'El workflow corre con las nuevas imágenes Sentinel-2 y renueva cifras, mapas y escena 3D. Cada actualización se publica como provisional hasta que la regla de persistencia la confirme.', enlace: '/workflow' },
];

export const DEVUELVE_AL_WORKFLOW = 'Las acciones registradas aparecen como capa en el workflow, y el workflow mide si el manglar responde en esos sitios. Los reportes de monitoreo con fotografías ubicadas son las etiquetas independientes que el modelo necesita para dejar de depender de las capas de referencia.';

export const CONDICIONES_FASE_2: string[] = [
  'Alojamiento con servidor, base de datos y almacenamiento de archivos, por decidir con la Corporación.',
  'Protección de datos personales según la Ley 1581 de 2012 y lineamientos de seguridad de la información del Ministerio de Tecnologías de la Información y las Comunicaciones.',
  'Adopción formal por la Corporación, que aprueba las listas de chequeo y el uso de su identidad.',
  'Verificación de consulta previa con comunidades étnicas cuando aplique.',
];

/** Lo que agregó el equipo SENTRALABS · UTB (ManglarHack Atlántico 2026). Cada punto dice qué funciona hoy y qué falta. */
export const LO_QUE_AGREGO_EL_EQUIPO: { titulo: string; texto: string; estado: string; enlace: string; textoEnlace: string }[] = [
  { titulo: 'Reportes de Zanky por app, bot y web', texto: 'La ciudadanía reporta tala, quemas, rellenos, vertimientos, basuras, caños taponados o fauna desde la app móvil, el bot de WhatsApp de Zanky o la web. Los reportes llegan al mismo mapa con su canal, su prioridad propuesta y su estado, y lo público se muestra sin foto, sin reportante y con la ubicación difuminada.', estado: 'Funciona con datos de ejemplo; se conectará al backend.', enlace: '/plataforma/monitoreo', textoEnlace: 'Ver el monitoreo comunitario' },
  { titulo: 'Área de reporte', texto: 'Solo se admiten denuncias dentro de la cobertura de manglar de la C.R.A. a escala 1:5.000 o a menos de 500 m de ella. Lo de fuera, como el casco urbano de Barranquilla, no se publica y el panel lo marca para descartar.', estado: 'Regla aplicada en la web; el servidor, la app y el bot deben aplicar la misma.', enlace: '/plataforma/monitoreo', textoEnlace: 'Reportar en el mapa' },
  { titulo: 'Capas oficiales de la C.R.A. en los mapas', texto: 'La cobertura de manglar 1:5.000 (886 polígonos, 649,7 ha; imágenes Maxar 2021–2022, verificada en campo) y la zonificación de prioridades de conservación, recortada a los cuatro sectores, de la que cada acción propuesta hereda su acción y su prioridad.', estado: 'Integradas desde los archivos entregados por la Corporación.', enlace: '/plataforma/proponer', textoEnlace: 'Proponer una acción' },
  { titulo: 'Jornadas comunitarias', texto: 'Cartelera de siembras, limpiezas, recorridos de vigías y monitoreos ligados a una acción, con inscripción y consentimiento, invitación por WhatsApp, calendario, QR y cartel imprimible.', estado: 'Funciona con datos de ejemplo.', enlace: '/plataforma/jornadas', textoEnlace: 'Ver las jornadas' },
  { titulo: 'Roles y auditoría', texto: 'El panel de la Corporación separa lo que puede hacer cada rol (administración, moderación, vigía comunitario, colegio o aliado) y deja una línea de auditoría por cada cambio de estado de acciones y reportes.', estado: 'Modo demostración: en producción el rol lo decide el servidor.', enlace: '/plataforma/panel', textoEnlace: 'Abrir el panel' },
  { titulo: 'Datos abiertos', texto: 'Los reportes públicos se descargan en CSV, GeoJSON y KML, y las jornadas se publican en JSON para otros canales. Licencia CC BY 4.0, sin datos personales.', estado: 'Exportación disponible; lo rotulado «Datos de ejemplo» es de demostración.', enlace: '/datos/jornadas.json', textoEnlace: 'Jornadas en JSON' },
];
