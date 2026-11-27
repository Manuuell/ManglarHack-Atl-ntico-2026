import 'package:flutter/material.dart';

import '../cuenta/permisos.dart';

/// Lo que alguien del equipo puede hacer en el panel. El id es el mismo de
/// `backend/supabase/permisos_rol.sql` (tabla `permisos_rol`, función `tengo_permiso`).
enum Permiso {
  verReportes('ver_reportes', 'Ver reportes', 'Abre la bandeja y el resumen', Icons.inbox_rounded),
  decidirReportes('decidir_reportes', 'Aprobar y rechazar', 'Decide los reportes pendientes', Icons.verified_rounded),
  editarContenido('editar_contenido', 'Editar contenido', 'Textos y avisos destacados de la app', Icons.edit_note_rounded),
  gestionarPuntos('gestionar_puntos', 'Puntos QR y NFC', 'Crea e imprime puntos del manglar', Icons.qr_code_2_rounded),
  gestionarJornadas('gestionar_jornadas', 'Jornadas', 'Convoca siembras, limpiezas y recorridos', Icons.event_available_rounded),
  avisarZona('avisar_zona', 'Avisos por zona', 'Escribe a encargados y voluntarios de una zona', Icons.campaign_rounded),
  verDatosPersonales('ver_datos_personales', 'Datos personales', 'Ve quién reportó y cómo contactarlo',
      Icons.badge_rounded, sensible: true),
  administrarRoles('administrar_roles', 'Administrar roles', 'Cambia esta matriz y da roles a personas',
      Icons.admin_panel_settings_rounded, sensible: true);

  const Permiso(this.id, this.nombre, this.pista, this.icono, {this.sensible = false});
  final String id;
  final String nombre;
  final String pista;
  final IconData icono;

  /// Dar este permiso pide confirmación (expone datos o el control del equipo).
  final bool sensible;

  static Permiso? deId(Object? id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Un rol del equipo (los de `panel_roles`). No es el rol que la persona elige en la bienvenida.
enum RolEquipo {
  admin('admin', 'Administración', Icons.shield_rounded),
  moderador('moderador_cra', 'Moderación CRA', Icons.fact_check_rounded),
  vigia('vigia', 'Vigía', Icons.visibility_rounded),
  aliado('aliado', 'Aliado', Icons.handshake_rounded),
  investigador('investigador', 'Investigación', Icons.science_rounded),
  organizador('organizador', 'Organización', Icons.groups_rounded),
  encargadoZona('encargado_zona', 'Encargado de zona', Icons.place_rounded),
  voluntario('voluntario', 'Voluntariado', Icons.volunteer_activism_rounded);

  const RolEquipo(this.id, this.nombre, this.icono);
  final String id;
  final String nombre;
  final IconData icono;

  static RolEquipo? deId(Object? id) {
    for (final r in values) {
      if (r.id == id) return r;
    }
    return null;
  }
}

/// Una plantilla: un juego de permisos con nombre que se copia a un rol con un toque (luego se
/// ajusta a mano). Son también los permisos por defecto de cada rol.
class PlantillaRol {
  const PlantillaRol(this.id, this.nombre, this.descripcion, this.permisos);
  final String id;
  final String nombre;
  final String descripcion;
  final Set<Permiso> permisos;
}

abstract final class Plantillas {
  static const admin = PlantillaRol('admin', 'Administración', 'Todo, incluido dar roles', {...Permiso.values});
  static const investigador = PlantillaRol('investigador', 'Investigación', 'Lee reportes y gestiona puntos de muestreo',
      {Permiso.verReportes, Permiso.gestionarPuntos});
  static const organizador = PlantillaRol('organizador', 'Organización', 'Jornadas y sus puntos QR',
      {Permiso.verReportes, Permiso.gestionarJornadas, Permiso.gestionarPuntos});
  static const encargadoZona = PlantillaRol('encargado_zona', 'Encargado de zona', 'Decide y avisa en su zona',
      {Permiso.verReportes, Permiso.decidirReportes, Permiso.avisarZona});
  static const voluntario = PlantillaRol('voluntario', 'Voluntariado', 'Solo mira la bandeja', {Permiso.verReportes});

  /// Las cinco que se ofrecen en el panel.
  static const todas = [admin, investigador, organizador, encargadoZona, voluntario];

  /// Lo que trae cada rol si el servidor aún no tiene la tabla (idéntico al SQL).
  static const porDefecto = <RolEquipo, Set<Permiso>>{
    RolEquipo.admin: {...Permiso.values},
    RolEquipo.moderador: {Permiso.verReportes, Permiso.decidirReportes, Permiso.avisarZona, Permiso.verDatosPersonales},
    RolEquipo.vigia: {Permiso.verReportes, Permiso.decidirReportes},
    RolEquipo.aliado: {Permiso.verReportes},
    RolEquipo.investigador: {Permiso.verReportes, Permiso.gestionarPuntos},
    RolEquipo.organizador: {Permiso.verReportes, Permiso.gestionarJornadas, Permiso.gestionarPuntos},
    RolEquipo.encargadoZona: {Permiso.verReportes, Permiso.decidirReportes, Permiso.avisarZona},
    RolEquipo.voluntario: {Permiso.verReportes},
  };
}

/// La matriz rol × permiso. Inmutable: cada cambio devuelve otra.
class MatrizPermisos {
  MatrizPermisos(Map<RolEquipo, Set<Permiso>> datos)
      : _datos = {for (final r in RolEquipo.values) r: Set.unmodifiable(datos[r] ?? const <Permiso>{})};

  factory MatrizPermisos.porDefecto() => MatrizPermisos(Plantillas.porDefecto);

  /// Desde las filas de la tabla `permisos_rol` (`rol`, `permiso`, `activo`). Las claves que la app
  /// no conoce se ignoran; un rol sin filas queda vacío, salvo el admin, que nunca se deja fuera.
  factory MatrizPermisos.deFilas(Iterable<Map<String, dynamic>> filas) {
    final datos = <RolEquipo, Set<Permiso>>{};
    for (final f in filas) {
      final r = RolEquipo.deId(f['rol']);
      final p = Permiso.deId(f['permiso']);
      if (r == null || p == null || f['activo'] == false) continue;
      datos.putIfAbsent(r, () => {}).add(p);
    }
    datos.putIfAbsent(RolEquipo.admin, () => {}).add(Permiso.administrarRoles);
    return MatrizPermisos(datos);
  }

  final Map<RolEquipo, Set<Permiso>> _datos;

  Set<Permiso> de(RolEquipo rol) => _datos[rol]!;

  bool puede(RolEquipo? rol, Permiso p) => rol != null && _datos[rol]!.contains(p);

  /// Este interruptor no se puede apagar: el administrador conserva «administrar roles».
  static bool bloqueado(RolEquipo rol, Permiso p) => rol == RolEquipo.admin && p == Permiso.administrarRoles;

  MatrizPermisos con(RolEquipo rol, Permiso p, bool activo) {
    if (bloqueado(rol, p) && !activo) return this;
    final nuevo = {..._datos};
    nuevo[rol] = activo ? {...de(rol), p} : ({...de(rol)}..remove(p));
    return MatrizPermisos(nuevo);
  }

  MatrizPermisos conPlantilla(RolEquipo rol, PlantillaRol plantilla) {
    final nuevo = {..._datos};
    nuevo[rol] = {...plantilla.permisos, if (rol == RolEquipo.admin) Permiso.administrarRoles};
    return MatrizPermisos(nuevo);
  }

  /// La plantilla que coincide exacto con el rol (para marcarla en pantalla), o nula.
  PlantillaRol? plantillaDe(RolEquipo rol) {
    for (final t in Plantillas.todas) {
      if (t.permisos.length == de(rol).length && t.permisos.containsAll(de(rol))) return t;
    }
    return null;
  }

  /// Los cambios para llevar esta matriz a [otra]: (rol, permiso, activo).
  List<(RolEquipo, Permiso, bool)> diferencias(MatrizPermisos otra) => [
        for (final r in RolEquipo.values)
          for (final p in Permiso.values)
            if (puede(r, p) != otra.puede(r, p)) (r, p, otra.puede(r, p)),
      ];

  List<Map<String, dynamic>> aFilas() => [
        for (final r in RolEquipo.values)
          for (final p in Permiso.values) {'rol': r.id, 'permiso': p.id, 'activo': puede(r, p)},
      ];
}

/// Puente con la cuenta (Configuración › Gestión): la matriz decide también qué gestiones se
/// muestran. «Sensores» no está en la matriz (es lectura pública del equipo): se conserva el
/// valor de fábrica de cada rol.
Map<String, List<Gestion>> gestionesDeMatriz(MatrizPermisos m) => {
      for (final r in RolEquipo.values)
        r.id: [
          if (m.puede(r, Permiso.verReportes) && m.puede(r, Permiso.decidirReportes)) Gestion.panelCra,
          if (m.puede(r, Permiso.gestionarPuntos)) Gestion.puntos,
          if (m.puede(r, Permiso.gestionarJornadas)) Gestion.jornadas,
          if (m.puede(r, Permiso.editarContenido)) Gestion.contenido,
          if (m.puede(r, Permiso.avisarZona)) Gestion.avisos,
          if (permisosPorDefecto(r.id).contains(Gestion.sensores)) Gestion.sensores,
        ],
    };
