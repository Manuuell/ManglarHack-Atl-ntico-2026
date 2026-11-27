import 'package:flutter/material.dart';

import '../../datos/gestion/repositorio_puntos.dart';
import '../../datos/punto/punto_zanky.dart';
import '../../datos/roles.dart';
import '../../nucleo/tema.dart';
import '../admin/panel_cra.dart';
import '../admin/piezas_admin.dart';
import '../contenido/editor_contenido.dart';
import '../contenido/entrada_contenido.dart';
import '../contenido/repositorio_contenido.dart';
import '../gestion/entrada_gestor.dart';
import '../inicio/secciones_rol.dart';
import '../sensores/pantalla_sensores.dart';
import 'piezas_configuracion.dart';

/// «Gestión»: lo que el rol de la cuenta puede hacer. Sin sesión, o con una cuenta sin rol
/// en `panel_roles`, no se pinta nada (ni un hueco). Sale igual en Configuración y en Guardián.
class SeccionGestion extends StatelessWidget {
  const SeccionGestion({super.key, this.conNota = true});
  final bool conNota;

  @override
  Widget build(BuildContext context) {
    final cuenta = CuentaScope.maybeDe(context);
    if (cuenta == null || cuenta.gestiones.isEmpty) {
      return const SizedBox.shrink();
    }
    final admin = AdminScope.maybeDe(context);
    final rol = RolPanel.etiqueta(cuenta.rol);
    return GrupoAjustes(
      titulo: 'Gestión · $rol',
      nota: conNota
          ? (cuenta.demostracion
                ? 'Demostración: datos de ejemplo que no salen de este teléfono.'
                : 'Lo que ves depende del rol que te dio la administración. El servidor lo comprueba en cada cambio.')
          : null,
      filas: [
        for (final g in cuenta.gestiones)
          FilaAjustes(
            key: ValueKey('gestion_${g.name}'),
            icono: g.icono,
            titulo: g.nombre,
            detalle: g.detalle,
            color: switch (g) {
              Gestion.panelCra => Zc.raiz,
              Gestion.puntos => Zc.hoja,
              Gestion.jornadas => const Color(0xFF6A4FA3),
              Gestion.contenido => Zc.cienaga,
              Gestion.avisos => Zc.fango,
              Gestion.sensores => const Color(0xFF1F6FB2),
            },
            cuenta: g == Gestion.panelCra && admin != null && admin.dentro
                ? admin.sinVer
                : 0,
            alTocar: () => abrirGestion(context, g),
          ),
      ],
    );
  }
}

/// Abre la herramienta de [g] con la sesión de la cuenta (o con datos de ejemplo en la demostración).
Future<void> abrirGestion(BuildContext context, Gestion g) async {
  final cuenta = CuentaScope.leer(context);
  if (cuenta == null || !cuenta.puede(g)) return;
  switch (g) {
    case Gestion.panelCra:
      await abrirPanelCra(context);
    case Gestion.puntos:
      final s = cuenta.sesion;
      await abrirGestor(
        context,
        repositorio: cuenta.demostracion || s == null
            ? RepositorioPuntosDemo(puntosDemostracion)
            : RepositorioPuntosRemoto(cuenta.servidor, s),
      );
    case Gestion.jornadas:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'gestion_jornadas'),
          builder: (_) => const PantallaJornadasGestion(),
        ),
      );
    case Gestion.contenido:
      await abrirEditorContenido(context, null, tokenEditor: cuenta.token);
    case Gestion.avisos:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'gestion_avisos'),
          builder: (_) => EditorContenido(
            ambito: 'global',
            repositorio: RepositorioContenido(
              servidor: cuenta.servidor,
              tokenEditor: cuenta.token,
            ),
          ),
        ),
      );
    case Gestion.sensores:
      await abrirSensores(context);
  }
}

/// Las herramientas de quien organiza jornadas que antes salían en Inicio con el rol
/// «Organizador»: sus jornadas, el QR del evento y quiénes van.
class PantallaJornadasGestion extends StatelessWidget {
  const PantallaJornadasGestion({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Zc.arena,
      appBar: AppBar(title: const Text('Jornadas')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 40),
        children: const [
          SeccionJornadas(vista: VistaJornadas.organizador),
          SizedBox(height: 16),
          QrDelEvento(),
          SizedBox(height: 16),
          Asistentes(),
        ],
      ),
    );
  }
}
