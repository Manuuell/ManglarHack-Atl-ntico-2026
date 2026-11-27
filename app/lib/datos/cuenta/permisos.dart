import 'package:flutter/material.dart';

/// Lo que se gestiona desde Configuración › Gestión. Cada rol del servidor (`panel_roles`)
/// desbloquea solo lo suyo; el servidor vuelve a comprobarlo en cada llamada (RLS y funciones),
/// así que esto decide qué se MUESTRA, no qué se permite.
enum Gestion {
  panelCra(
    'Panel CRA',
    'Verifica los reportes que llegan',
    Icons.shield_rounded,
  ),
  puntos(
    'Puntos Zanky',
    'Crea QR, imprime carteles y graba NFC',
    Icons.qr_code_2_rounded,
  ),
  jornadas(
    'Jornadas',
    'Tus jornadas, su QR y quiénes van',
    Icons.event_available_rounded,
  ),
  contenido(
    'Contenido de la app',
    'Lo que ve el público en Inicio y en cada evento',
    Icons.edit_note_rounded,
  ),
  avisos(
    'Avisos al público',
    'Publica un aviso en la portada',
    Icons.campaign_rounded,
  ),
  sensores(
    'Sensores del manglar',
    'Lecturas, umbrales y alertas',
    Icons.sensors_rounded,
  );

  const Gestion(this.nombre, this.detalle, this.icono);
  final String nombre;
  final String detalle;
  final IconData icono;
}

/// Roles que leen la bandeja de reportes (RLS `reportes_panel_lee`).
const rolesQueModeran = {'admin', 'moderador_cra', 'vigia'};

/// Permisos por rol configurados en el servidor (panel de administración). Mientras sea nulo
/// rige la tabla de [permisosPorDefecto]. Quien cargue la tabla editable la pone aquí
/// (`permisosConfigurados.value = {'organizador': [Gestion.jornadas], ...}`) y la cuenta
/// avisa a las pantallas. Un rol que no esté en el mapa usa su valor por defecto.
final permisosConfigurados = ValueNotifier<Map<String, List<Gestion>>?>(null);

/// Lo que ve cada rol, en el orden en que sale. Sin rol (cuenta de ciudadano) o sin sesión: nada.
List<Gestion> gestionesDe(String? rol) {
  if (rol == null) return const [];
  final c = permisosConfigurados.value;
  if (c != null && c.containsKey(rol)) {
    // Se respeta el orden de [Gestion] para que la lista no salte.
    return [for (final g in Gestion.values) if (c[rol]!.contains(g)) g];
  }
  return permisosPorDefecto(rol);
}

/// La tabla de fábrica (la misma que aplica el servidor si nadie la cambió).
List<Gestion> permisosPorDefecto(String? rol) => switch (rol) {
  'admin' => Gestion.values,
  'moderador_cra' => const [Gestion.panelCra, Gestion.sensores],
  'vigia' => const [Gestion.panelCra, Gestion.sensores],
  'investigador' => const [Gestion.puntos, Gestion.sensores],
  'organizador' => const [Gestion.jornadas, Gestion.puntos, Gestion.contenido],
  'aliado' => const [Gestion.sensores],
  _ => const [],
};
