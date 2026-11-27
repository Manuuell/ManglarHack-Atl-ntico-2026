import 'package:flutter/material.dart';

import 'cuenta/permisos.dart';

export 'cuenta/permisos.dart' show Gestion, gestionesDe, permisosConfigurados, permisosPorDefecto, rolesQueModeran;

/// Perfil heredado de versiones anteriores, cuando la bienvenida pedía elegir «Vecino»,
/// «Estudiante», «Visitante» u «Organizador». Ya NO cambia nada de lo que se ve: una persona
/// puede ser todo eso a la vez, así que Inicio y Guardián muestran lo mismo a todos. Se conserva
/// solo para leer perfiles guardados sin romperlos. Los permisos del equipo los da el servidor
/// (`panel_roles`) al entrar con la cuenta en Configuración.
enum RolUsuario {
  ciudadano('ciudadano', 'Vecino o vecina', 'Vivo o trabajo cerca del manglar', Icons.home_work_rounded,
      Color(0xFF2E9E6A)),
  estudiante('estudiante', 'Estudiante', 'Participo con mi colegio o PRAE', Icons.school_rounded, Color(0xFF1FA2A6)),
  turista('turista', 'Visitante', 'Vengo a conocer el manglar', Icons.hiking_rounded, Color(0xFFF2A33A)),
  organizador('organizador', 'Organizador de jornadas', 'Convoco siembras, limpiezas y recorridos',
      Icons.event_available_rounded, Color(0xFF6A4FA3));

  const RolUsuario(this.id, this.nombre, this.lema, this.icono, this.color);

  /// Lo que se guarda en el perfil.
  final String id;
  final String nombre;
  final String lema;
  final IconData icono;
  final Color color;

  /// Un id desconocido o ausente (perfiles de versiones anteriores) vale «ciudadano».
  static RolUsuario deId(Object? id) => values.firstWhere((r) => r.id == id, orElse: () => ciudadano);
}

/// Los roles del servidor (`panel_roles`): se leen de la sesión, no se eligen.
abstract final class RolPanel {
  static const todos = ['admin', 'moderador_cra', 'vigia', 'aliado', 'investigador', 'organizador'];

  static bool esConocido(String? rol) => rol != null && todos.contains(rol);

  /// Lo que [rol] puede gestionar (vacío sin rol). Ver `cuenta/permisos.dart`: la tabla se
  /// puede reemplazar con `permisosConfigurados` cuando llegue la del panel de administración.
  static List<Gestion> permisos(String? rol) => gestionesDe(rol);

  /// ¿Puede [rol] usar [g]? Esto decide qué se MUESTRA; el servidor lo vuelve a comprobar.
  static bool puede(String? rol, Gestion g) => gestionesDe(rol).contains(g);

  static String etiqueta(String? rol) => switch (rol) {
        'admin' => 'Administración',
        'moderador_cra' => 'Moderación CRA',
        'vigia' => 'Vigía',
        'aliado' => 'Aliado',
        'investigador' => 'Investigación',
        'organizador' => 'Organización de jornadas',
        _ => 'Equipo',
      };
}

/// Cada bloque que puede salir en Inicio. El orden en que se piden es el orden en pantalla.
/// `misJornadas`, `qrEvento` y `asistentes` ya no salen en Inicio: son herramientas de quien
/// organiza y viven en Configuración › Gestión (con su cuenta).
enum SeccionInicio {
  panel,
  queHagoYa,
  reportar,
  reporteRapido,
  estadoReportes,
  progreso,
  retoManglar,
  rankingColegio,
  mision,
  queVer,
  queNoHacer,
  jornadasCerca,
  misJornadas,
  qrEvento,
  asistentes,
  evento,
  clima,
  pronostico,
  sensores,
  sabiasQue,
}

/// Las secciones de Inicio, iguales para todos, en cuatro bloques:
/// 1. Actuar: «¿Qué hago ya?» y UN solo llamado a reportar (`reportar` lleva dentro el
///    reporte rápido).
/// 2. Lo tuyo: Zanky creciendo (arte oficial por etapas), tus reportes y la misión.
/// 3. El manglar hoy: sensores, pronóstico y clima; después «Comunidad» (alertas y noticias).
/// 4. Participar y aprender: jornadas, modo evento, reto, colegio, qué ver, qué no hacer y
///    el dato curioso.
/// Con sesión del equipo que modera ([rolPanel] conocido) la bandeja del panel va arriba.
///
/// `reporteRapido` ya no sale suelto (va dentro del héroe). La sección «Comunidad» se inserta
/// después de [SeccionInicio.clima] y antes de [SeccionInicio.jornadasCerca].
List<SeccionInicio> seccionesDeInicio({String? rolPanel}) => [
      if (RolPanel.esConocido(rolPanel)) SeccionInicio.panel,
      SeccionInicio.queHagoYa,
      SeccionInicio.reportar,
      SeccionInicio.progreso,
      SeccionInicio.estadoReportes,
      SeccionInicio.mision,
      SeccionInicio.sensores,
      SeccionInicio.pronostico,
      SeccionInicio.clima,
      // Aquí va «Comunidad».
      SeccionInicio.jornadasCerca,
      SeccionInicio.evento,
      SeccionInicio.retoManglar,
      SeccionInicio.rankingColegio,
      SeccionInicio.queVer,
      SeccionInicio.queNoHacer,
      SeccionInicio.sabiasQue,
    ];

/// A dónde lleva «¿Qué hago ya?».
enum DestinoYa { reportar, mapa, misReportes, guardian, perfil, evento, panel }

enum TonoYa { urgente, normal, suave }

class AccionYa {
  const AccionYa({
    required this.clave,
    required this.titulo,
    required this.detalle,
    required this.boton,
    required this.icono,
    required this.destino,
    this.tono = TonoYa.normal,
  });

  /// Cambia cuando cambia la sugerencia (para animar el cambio, no el texto).
  final String clave;
  final String titulo;
  final String detalle;
  final String boton;
  final IconData icono;
  final DestinoYa destino;
  final TonoYa tono;
}

/// Lo que se sabe en este momento para decidir qué sugerir. Es todo lo que la regla necesita:
/// no lee el reloj ni el estado de la app, así se puede probar con cualquier hora.
class ContextoYa {
  const ContextoYa({
    required this.hora,
    this.rolPanel,
    this.sinVerPanel = 0,
    this.porEnviar = 0,
    this.rechazados = 0,
    this.enLinea = true,
    this.enviados = 0,
    this.tieneColegio = false,
    this.eventoAbierto = false,
  });

  final int hora;
  final String? rolPanel;
  final int sinVerPanel;
  final int porEnviar;
  final int rechazados;
  final bool enLinea;
  final int enviados;
  final bool tieneColegio;
  final bool eventoAbierto;
}

String _plural(int n, String uno, String varios) => n == 1 ? uno : varios;

/// «¿Qué hago ya?»: UNA sola cosa, la más importante ahora. Primero lo del equipo, luego lo
/// que se perdería si no se atiende (reportes guardados o rechazados) y por último lo propio
/// del rol y de la hora.
AccionYa queHagoYa(ContextoYa c) {
  if (RolPanel.esConocido(c.rolPanel) && c.sinVerPanel > 0) {
    final n = c.sinVerPanel;
    return AccionYa(
      clave: 'panel',
      titulo: '$n ${_plural(n, 'reporte nuevo', 'reportes nuevos')} por revisar',
      detalle: 'Entra a la bandeja: lo más grave sale primero.',
      boton: 'Abrir el panel',
      icono: Icons.shield_rounded,
      destino: DestinoYa.panel,
      tono: TonoYa.urgente,
    );
  }
  if (c.rechazados > 0) {
    final n = c.rechazados;
    return AccionYa(
      clave: 'rechazados',
      titulo: '$n ${_plural(n, 'reporte rechazado', 'reportes rechazados')}',
      detalle: 'El servidor no lo aceptó. Míralo y corrige lo que falte.',
      boton: 'Ver mis reportes',
      icono: Icons.error_outline_rounded,
      destino: DestinoYa.misReportes,
      tono: TonoYa.urgente,
    );
  }
  if (c.porEnviar > 0) {
    final n = c.porEnviar;
    return AccionYa(
      clave: c.enLinea ? 'enviando' : 'sin_senal',
      titulo: c.enLinea
          ? 'Enviando $n ${_plural(n, 'reporte', 'reportes')}'
          : '$n ${_plural(n, 'reporte espera', 'reportes esperan')} señal',
      detalle: c.enLinea
          ? 'Zanky los manda solo; no hace falta que hagas nada.'
          : 'Están a salvo en tu teléfono y salen apenas vuelva la conexión.',
      boton: 'Ver mis reportes',
      icono: c.enLinea ? Icons.cloud_upload_rounded : Icons.cloud_off_rounded,
      destino: DestinoYa.misReportes,
      tono: TonoYa.suave,
    );
  }
  if (c.eventoAbierto) {
    return const AccionYa(
      clave: 'evento_abierto',
      titulo: 'Estás en una jornada',
      detalle: 'Mira el evento: qué llevar, el punto de encuentro y registra tu llegada.',
      boton: 'Abrir el evento',
      icono: Icons.event_available_rounded,
      destino: DestinoYa.evento,
    );
  }
  if (c.enviados == 0) {
    return const AccionYa(
      clave: 'primero',
      titulo: 'Haz tu primer reporte',
      detalle: 'Tala, fuego, un caño tapado… una foto y listo, aunque no haya señal.',
      boton: 'Reportar ahora',
      icono: Icons.add_a_photo_rounded,
      destino: DestinoYa.reportar,
    );
  }
  if (c.hora >= 19 || c.hora < 5) {
    return const AccionYa(
      clave: 'noche',
      titulo: 'Planea tu próxima visita',
      detalle: 'El manglar se recorre con luz: mira el mapa y elige por dónde ir.',
      boton: 'Abrir el mapa',
      icono: Icons.map_rounded,
      destino: DestinoYa.mapa,
      tono: TonoYa.suave,
    );
  }
  if (c.hora < 7) {
    return const AccionYa(
      clave: 'madrugada',
      titulo: 'Madrugaste: mira el manglar',
      detalle: 'Los pescadores salen ahora. Si ves algo raro, repórtalo con la luz del alba.',
      boton: 'Reportar',
      icono: Icons.wb_twilight_rounded,
      destino: DestinoYa.reportar,
    );
  }
  if (!c.tieneColegio && c.enviados < 3) {
    return const AccionYa(
      clave: 'colegio',
      titulo: '¿Estudias? Agrega tu colegio',
      detalle: 'Tus reportes validados suman para tu curso y tu PRAE. Si no estudias, sigue reportando.',
      boton: 'Agregar mi colegio',
      icono: Icons.school_rounded,
      destino: DestinoYa.perfil,
      tono: TonoYa.suave,
    );
  }
  return const AccionYa(
    clave: 'mapa',
    titulo: 'Mira qué se ha reportado cerca',
    detalle: 'El mapa muestra lo que ya avisaron otras personas.',
    boton: 'Abrir el mapa',
    icono: Icons.map_rounded,
    destino: DestinoYa.mapa,
    tono: TonoYa.suave,
  );
}

/// Los bloques de Guardián, en orden, iguales para todos. `rol` queda por compatibilidad y
/// ya no se pinta; `panel` es la sección «Gestión», que solo aparece con una cuenta del
/// equipo ([conGestion]).
enum SeccionGuardian { tarjeta, rol, nivel, puntos, participacion, mision, insignias, colegios, panel }

List<SeccionGuardian> seccionesDeGuardian({bool conGestion = false}) => [
      SeccionGuardian.tarjeta,
      if (conGestion) SeccionGuardian.panel,
      SeccionGuardian.nivel,
      SeccionGuardian.mision,
      SeccionGuardian.puntos,
      SeccionGuardian.participacion,
      SeccionGuardian.insignias,
      SeccionGuardian.colegios,
    ];

/// «AP» de «Ana Pérez»; vacío sin nombre (el carné pone entonces un ícono).
String inicialesDe(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (partes.isEmpty) return '';
  if (partes.length == 1) return partes.first[0].toUpperCase();
  return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
}
