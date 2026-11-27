import '../../nucleo/kit/ruta_borde.dart';
import '../contenido/entrada_contenido.dart';
import 'package:flutter/material.dart';

import '../../datos/admin/controlador_admin.dart';
import '../../datos/admin/reporte_admin.dart';
import '../../nucleo/kit/anuncio.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/tema.dart';
import '../../datos/roles.dart';
import '../sensores/pantalla_sensores.dart';
import 'sensores/seccion_sensores_admin.dart';
import 'acceso_admin.dart';
import 'bandeja_admin.dart';
import 'permisos/pantalla_permisos.dart';
import 'piezas_admin.dart';
import '../../datos/permisos/permisos_rol.dart';
import '../../datos/permisos/repositorio_permisos.dart';
import 'resumen_admin.dart';
import 'contenido/seccion_contenido_admin.dart';
import '../../datos/admin/contenido_panel.dart';

/// Abre el panel de la CRA como una pantalla aparte (no es una pestaña: los ciudadanos
/// no tienen por qué verlo). Le pasa el controlador a la ruta, que no hereda de la raíz.
Future<void> abrirPanelCra(BuildContext context) {
  final c = AdminScope.leer(context);
  return Navigator.of(context).push(
    RutaBorde<void>(
      sinMovimiento: MediaQuery.disableAnimationsOf(context),
      settings: const RouteSettings(name: 'panel_cra'),
      builder: (_) => Theme(data: temaCra(), child: AdminScope(controlador: c, child: const PanelCra())),
    ),
  );
}

enum _Vista { bandeja, resumen, sensores, contenido }

/// El panel: acceso → bandeja y resumen. Una sola pantalla con cabecera propia.
class PanelCra extends StatefulWidget {
  const PanelCra({super.key});

  @override
  State<PanelCra> createState() => _PanelCraState();
}

class _PanelCraState extends State<PanelCra> {
  _Vista _vista = _Vista.bandeja;
  ControladorAdmin? _c;

  /// Permisos del rol con sesión: se crean al entrar y se cambian si cambia la sesión.
  ControladorPermisos? _permisos;
  String? _clavePermisos;

  /// Contenido editable (portada, jornadas, noticias, puntos, umbrales). Se crea con la sesión.
  ControladorContenidoPanel? _contenido;

  void _sincronizarPermisos() {
    final c = _c;
    if (c == null) return;
    final clave = c.dentro ? '${c.demostracion}|${c.rol}|${c.correo}' : null;
    if (clave == _clavePermisos) return;
    _clavePermisos = clave;
    _permisos?.dispose();
    _permisos = null;
    _contenido?.dispose();
    _contenido = null;
    if (clave == null) return;
    final p = ControladorPermisos(
      fuente: c.demostracion ? null : FuenteSupabase(c.servidor, c.tokenParaContenido),
      rolActual: RolEquipo.deId(c.rol),
    );
    _permisos = p;
    p.cargar();
    _contenido = ControladorContenidoPanel(
      fuente: c.demostracion ? null : FuenteContenidoSupabase(c.servidor, c.tokenParaContenido),
      puede: (permiso) => _permisos?.puede(permiso) ?? false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AdminScope.de(context);
    if (!identical(c, _c)) {
      _c?.removeListener(_alCambiar);
      _c = c..addListener(_alCambiar);
      _sincronizarPermisos();
    }
  }

  @override
  void dispose() {
    _c?.removeListener(_alCambiar);
    _permisos?.dispose();
    _contenido?.dispose();
    super.dispose();
  }

  /// Si el servidor no aceptó una decisión, se dice por qué (y el reporte ya volvió a como estaba).
  void _alCambiar() {
    _sincronizarPermisos();
    final c = _c;
    if (c == null || c.fallo == null || !mounted) return;
    final f = c.tomarFallo();
    if (f == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      anunciar(context, f);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(f), duration: const Duration(seconds: 6)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AdminScope.de(context);
    final permisos = _permisos;
    final pantalla = Scaffold(
      body: SafeArea(
        bottom: false,
        // La barra de «Deshacer» flota sobre la lista: no le quita alto con letra grande.
        child: Stack(
          children: [
            Column(
              children: [
                _Cabecera(controlador: c),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Zm.medio,
                    switchInCurve: Zm.entrar,
                    child: c.dentro
                        ? _Dentro(
                            key: const ValueKey('dentro'),
                            controlador: c,
                            contenido: _contenido,
                            vista: _vista,
                            alCambiarVista: (v) => setState(() => _vista = v),
                          )
                        : AccesoAdmin(key: const ValueKey('acceso'), controlador: c),
                  ),
                ),
              ],
            ),
            if (c.dentro)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(top: false, child: BarraDeshacer(controlador: c)),
              ),
          ],
        ),
      ),
    );
    return permisos == null ? pantalla : PermisosScope(controlador: permisos, child: pantalla);
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.controlador});
  final ControladorAdmin controlador;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final c = controlador;
    final rol = switch (c.rol) {
      'admin' => 'Administración',
      'moderador_cra' => 'Moderación CRA',
      'vigia' => 'Vigía',
      'aliado' => 'Aliado',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BotonIcono(
            icono: Icons.arrow_back_rounded,
            etiqueta: 'Volver',
            alTocar: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 6),
          const InsigniaCra(alto: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text('PANEL CRA', style: tt.titleLarge?.copyWith(color: Cra.dorado, letterSpacing: 1.4))),
                if (c.dentro)
                  Text(
                    c.demostracion ? 'Demostración · ${rol ?? ''}' : [?rol, ?c.correo].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall,
                  ),
              ],
            ),
          ),
          // Dentro del panel los sensores tienen su propio segmento (con permiso); fuera, el atajo público.
          if (!c.dentro)
            BotonIcono(
              icono: Icons.sensors_rounded,
              etiqueta: 'Sensores del manglar',
              alTocar: () => abrirSensores(context),
            ),
          if (c.dentro) ...[
            const SizedBox(width: 4),
            BotonIcono(
              icono: Icons.refresh_rounded,
              etiqueta: 'Actualizar reportes',
              alTocar: () => c.actualizar(),
            ),
            if (puedeEnPanel(context, c.rol, Permiso.editarContenido)) ...[
              const SizedBox(width: 4),
              BotonIcono(
                icono: Icons.edit_note_rounded,
                etiqueta: 'Editar contenido de la app',
                alTocar: () => abrirEditorContenido(context, c),
              ),
            ],
            if (PermisosScope.de(context) case final p? when p.puede(Permiso.administrarRoles) || c.demostracion) ...[
              const SizedBox(width: 4),
              BotonIcono(
                icono: Icons.admin_panel_settings_rounded,
                etiqueta: 'Permisos del equipo',
                alTocar: () => abrirPermisos(context, p, demostracion: c.demostracion),
              ),
            ],
            const SizedBox(width: 4),
            BotonIcono(
              icono: Icons.logout_rounded,
              etiqueta: 'Salir del panel',
              alTocar: () {
                c.salir();
                Navigator.of(context).maybePop();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Dentro extends StatelessWidget {
  const _Dentro({super.key, required this.controlador, required this.vista, required this.alCambiarVista, this.contenido});
  final ControladorAdmin controlador;
  final ControladorContenidoPanel? contenido;
  final _Vista vista;
  final ValueChanged<_Vista> alCambiarVista;

  @override
  Widget build(BuildContext context) {
    final c = controlador;
    // «Contenido» aparece con cualquiera de sus permisos (cada sección pide el suyo).
    final cont = contenido;
    PermisosScope.de(context); // se reconstruye si cambia la matriz
    final conContenido = cont != null && SeccionContenido.values.any(cont.puedeEditar);
    return Column(
      children: [
        const SizedBox(height: 4),
        SegmentosZ<_Vista>(
          // «Sensores y microcontroladores» solo con la gestión de sensores del rol.
          valores: [
            _Vista.bandeja,
            _Vista.resumen,
            if (RolPanel.puede(c.rol, Gestion.sensores)) _Vista.sensores,
            if (conContenido) _Vista.contenido,
          ],
          actual: vista,
          nombre: (v) => switch (v) { _Vista.bandeja => 'Bandeja', _Vista.resumen => 'Resumen', _Vista.sensores => 'Sensores', _Vista.contenido => 'Contenido' },
          cuenta: (v) => v == _Vista.bandeja ? c.conteos[FiltroBandeja.pendientes] : null,
          alCambiar: alCambiarVista,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: switch (vista) {
            _Vista.bandeja => BandejaAdmin(controlador: c),
            _Vista.resumen => ResumenAdmin(controlador: c),
            _Vista.sensores =>
              RolPanel.puede(c.rol, Gestion.sensores) ? const SeccionSensoresAdmin() : BandejaAdmin(controlador: c),
            _Vista.contenido => conContenido ? SeccionContenidoAdmin(controlador: cont) : BandejaAdmin(controlador: c),
          },
        ),
      ],
    );
  }
}
