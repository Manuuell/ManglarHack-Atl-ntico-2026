import 'package:flutter/material.dart';

/// Quién eres en el manglar. Se elige en la bienvenida, vive en el perfil del teléfono y se
/// puede cambiar en Guardián. NO da ningún permiso: los permisos del equipo (vigía, moderador,
/// administrador, aliado) los confirma el servidor al entrar al panel, nunca esta elección.
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

/// Los roles del servidor que resuelve el panel (`panel_roles`): se leen de la sesión, no se eligen.
abstract final class RolPanel {
  static const todos = ['admin', 'moderador_cra', 'vigia', 'aliado'];

  static bool esConocido(String? rol) => rol != null && todos.contains(rol);

  static String etiqueta(String? rol) => switch (rol) {
        'admin' => 'Administración',
        'moderador_cra' => 'Moderación CRA',
        'vigia' => 'Vigía',
        'aliado' => 'Aliado',
        _ => 'Equipo',
      };
}

/// Cada bloque que puede salir en Inicio. El orden en que se piden es el orden en pantalla.
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
  sabiasQue,
}

/// Las secciones de Inicio, de lo más útil a lo menos, según el rol. Con sesión del equipo
/// ([rolPanel] conocido) la bandeja del panel va arriba de todo.
List<SeccionInicio> seccionesDeInicio(RolUsuario rol, {String? rolPanel}) {
  final propias = switch (rol) {
    RolUsuario.ciudadano => [
        SeccionInicio.queHagoYa,
        SeccionInicio.reportar,
        SeccionInicio.estadoReportes,
        SeccionInicio.clima,
        SeccionInicio.reporteRapido,
        SeccionInicio.progreso,
        SeccionInicio.evento,
        SeccionInicio.mision,
        SeccionInicio.pronostico,
        SeccionInicio.sabiasQue,
      ],
    RolUsuario.estudiante => [
        SeccionInicio.queHagoYa,
        SeccionInicio.retoManglar,
        SeccionInicio.rankingColegio,
        SeccionInicio.mision,
        SeccionInicio.reportar,
        SeccionInicio.reporteRapido,
        SeccionInicio.progreso,
        SeccionInicio.evento,
        SeccionInicio.clima,
        SeccionInicio.pronostico,
        SeccionInicio.sabiasQue,
      ],
    RolUsuario.turista => [
        SeccionInicio.queHagoYa,
        SeccionInicio.pronostico,
        SeccionInicio.queVer,
        SeccionInicio.queNoHacer,
        SeccionInicio.reporteRapido,
        SeccionInicio.jornadasCerca,
        SeccionInicio.clima,
        SeccionInicio.sabiasQue,
      ],
    RolUsuario.organizador => [
        SeccionInicio.queHagoYa,
        SeccionInicio.pronostico,
        SeccionInicio.misJornadas,
        SeccionInicio.qrEvento,
        SeccionInicio.asistentes,
        SeccionInicio.reportar,
        SeccionInicio.clima,
        SeccionInicio.sabiasQue,
      ],
  };
  return [if (RolPanel.esConocido(rolPanel)) SeccionInicio.panel, ...propias];
}

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
    required this.rol,
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

  final RolUsuario rol;
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
  switch (c.rol) {
    case RolUsuario.estudiante:
      if (!c.tieneColegio) {
        return const AccionYa(
          clave: 'est_colegio',
          titulo: 'Agrega tu colegio',
          detalle: 'Así tus reportes validados suman para tu curso y tu PRAE.',
          boton: 'Agregar mi colegio',
          icono: Icons.school_rounded,
          destino: DestinoYa.perfil,
        );
      }
      if (c.enviados == 0) {
        return const AccionYa(
          clave: 'est_primero',
          titulo: 'Haz el primer reporte de tu colegio',
          detalle: 'Una foto y la ubicación bastan. Si lo validan, sube tu nivel.',
          boton: 'Reportar ahora',
          icono: Icons.add_a_photo_rounded,
          destino: DestinoYa.reportar,
        );
      }
      return const AccionYa(
        clave: 'est_mision',
        titulo: 'Cumple la misión de la semana',
        detalle: 'Es el motivo para volver al manglar con tu grupo.',
        boton: 'Reportar para la misión',
        icono: Icons.flag_rounded,
        destino: DestinoYa.reportar,
        tono: TonoYa.suave,
      );
    case RolUsuario.turista:
      if (c.hora >= 18 || c.hora < 5) {
        return const AccionYa(
          clave: 'tur_noche',
          titulo: 'Planea tu visita de mañana',
          detalle: 'El manglar se disfruta con luz: mira el mapa y elige por dónde ir.',
          boton: 'Abrir el mapa',
          icono: Icons.map_rounded,
          destino: DestinoYa.mapa,
          tono: TonoYa.suave,
        );
      }
      return const AccionYa(
        clave: 'tur_dia',
        titulo: 'Recorre con cuidado',
        detalle: 'Mira abajo qué ver y qué no hacer. Si ves algo raro, repórtalo.',
        boton: 'Reportar algo que vi',
        icono: Icons.hiking_rounded,
        destino: DestinoYa.reportar,
      );
    case RolUsuario.organizador:
      if (c.eventoAbierto) {
        return const AccionYa(
          clave: 'org_abierto',
          titulo: 'Tu jornada está abierta',
          detalle: 'Registra a quienes llegan y comparte el QR del evento.',
          boton: 'Abrir el evento',
          icono: Icons.qr_code_2_rounded,
          destino: DestinoYa.evento,
        );
      }
      return const AccionYa(
        clave: 'org_preparar',
        titulo: 'Prepara tu próxima jornada',
        detalle: 'Abre el evento con su código y comparte el QR para que la gente entre.',
        boton: 'Abrir un evento',
        icono: Icons.event_available_rounded,
        destino: DestinoYa.evento,
      );
    case RolUsuario.ciudadano:
      if (c.enviados == 0) {
        return const AccionYa(
          clave: 'ciu_primero',
          titulo: 'Haz tu primer reporte',
          detalle: 'Tala, fuego, un caño tapado… una foto y listo, aunque no haya señal.',
          boton: 'Reportar ahora',
          icono: Icons.add_a_photo_rounded,
          destino: DestinoYa.reportar,
        );
      }
      if (c.hora < 7) {
        return const AccionYa(
          clave: 'ciu_madrugada',
          titulo: 'Madrugaste: mira el manglar',
          detalle: 'Los pescadores salen ahora. Si ves algo raro, repórtalo con la luz del alba.',
          boton: 'Reportar',
          icono: Icons.wb_twilight_rounded,
          destino: DestinoYa.reportar,
        );
      }
      return const AccionYa(
        clave: 'ciu_mapa',
        titulo: 'Mira qué se ha reportado cerca',
        detalle: 'El mapa muestra lo que ya avisaron otras personas.',
        boton: 'Abrir el mapa',
        icono: Icons.map_rounded,
        destino: DestinoYa.mapa,
        tono: TonoYa.suave,
      );
  }
}

/// Los bloques de Guardián, en orden, según el rol.
enum SeccionGuardian { tarjeta, rol, nivel, puntos, participacion, mision, insignias, colegios, panel }

List<SeccionGuardian> seccionesDeGuardian(RolUsuario rol, {bool conPerfil = true}) {
  final base = switch (rol) {
    RolUsuario.estudiante => [
        SeccionGuardian.tarjeta,
        SeccionGuardian.colegios,
        SeccionGuardian.nivel,
        SeccionGuardian.mision,
        SeccionGuardian.insignias,
        SeccionGuardian.puntos,
        SeccionGuardian.participacion,
      ],
    RolUsuario.organizador => [
        SeccionGuardian.tarjeta,
        SeccionGuardian.participacion,
        SeccionGuardian.nivel,
        SeccionGuardian.insignias,
        SeccionGuardian.puntos,
        SeccionGuardian.mision,
      ],
    _ => [
        SeccionGuardian.tarjeta,
        SeccionGuardian.nivel,
        SeccionGuardian.puntos,
        SeccionGuardian.participacion,
        SeccionGuardian.mision,
        SeccionGuardian.insignias,
        if (rol == RolUsuario.ciudadano) SeccionGuardian.colegios,
      ],
  };
  // El rol se cambia justo debajo de la tarjeta; sin perfil no hay nada que cambiar.
  return [
    base.first,
    if (conPerfil) SeccionGuardian.rol,
    ...base.skip(1),
    SeccionGuardian.panel,
  ];
}

/// «AP» de «Ana Pérez»; vacío sin nombre (el carné pone entonces el ícono del rol).
String inicialesDe(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (partes.isEmpty) return '';
  if (partes.length == 1) return partes.first[0].toUpperCase();
  return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
}
