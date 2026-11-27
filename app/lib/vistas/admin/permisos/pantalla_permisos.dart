import 'package:flutter/material.dart';

import '../../../datos/permisos/permisos_rol.dart';
import '../../../datos/permisos/repositorio_permisos.dart';
import '../../../nucleo/base/hoja.dart';
import '../../../nucleo/identidad.dart';
import '../../../nucleo/kit/accion_gesto.dart';
import '../../../nucleo/kit/anuncio.dart';
import '../../../nucleo/kit/aviso.dart';
import '../../../nucleo/kit/confirmar.dart';
import '../../../nucleo/kit/haptica.dart';
import '../../../nucleo/kit/interruptor.dart';
import '../../../nucleo/kit/menu_mantenido.dart';
import '../../../nucleo/kit/ruta_borde.dart';
import '../../../nucleo/presionable.dart';
import '../../../nucleo/tema.dart';
import '../piezas_admin.dart';

/// Da a las pantallas del panel el controlador de permisos (para mostrar u ocultar acciones).
class PermisosScope extends InheritedNotifier<ControladorPermisos> {
  const PermisosScope({super.key, required ControladorPermisos controlador, required super.child})
      : super(notifier: controlador);

  static ControladorPermisos? de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PermisosScope>()?.notifier;
}

/// ¿Puede quien tiene la sesión hacer [p]? Sin controlador (pantallas sueltas, pruebas viejas)
/// se usan las plantillas por defecto del rol del panel.
bool puedeEnPanel(BuildContext context, String? rolPanel, Permiso p) {
  final c = PermisosScope.de(context);
  if (c != null) return c.puede(p);
  return MatrizPermisos.porDefecto().puede(RolEquipo.deId(rolPanel), p);
}

Future<void> abrirPermisos(BuildContext context, ControladorPermisos c, {required bool demostracion}) {
  final tema = Theme.of(context);
  return Navigator.of(context).push(RutaBorde<void>(
    sinMovimiento: MediaQuery.disableAnimationsOf(context),
    settings: const RouteSettings(name: 'panel_cra/permisos'),
    builder: (_) => Theme(data: tema, child: PantallaPermisos(controlador: c, demostracion: demostracion)),
  ));
}

/// Matriz rol × permiso, plantillas y «dar rol a una persona».
/// En pantallas anchas la matriz entera; en el teléfono, un rol a la vez.
class PantallaPermisos extends StatefulWidget {
  const PantallaPermisos({super.key, required this.controlador, this.demostracion = false});
  final ControladorPermisos controlador;
  final bool demostracion;

  @override
  State<PantallaPermisos> createState() => _PantallaPermisosState();
}

class _PantallaPermisosState extends State<PantallaPermisos> {
  RolEquipo _rol = RolEquipo.moderador;

  ControladorPermisos get _c => widget.controlador;

  Future<void> _cambiar(RolEquipo rol, Permiso p, bool activo) async {
    if (!_c.editable || MatrizPermisos.bloqueado(rol, p)) return;
    if (activo && p.sensible) {
      final ok = await confirmarEnHoja(
        context,
        titulo: '¿Dar «${p.nombre}» a ${rol.nombre}?',
        texto: p == Permiso.verDatosPersonales
            ? 'Podrán ver nombre y contacto de quien reporta. Queda registrado en auditoría.'
            : 'Podrán cambiar esta matriz y dar roles a otras personas.',
        textoConfirmar: 'Dar permiso',
        seguroPrimero: true,
      );
      if (!ok || !mounted) return;
    }
    final antes = _c.matriz;
    vibrar(Vibracion.seleccion);
    final f = await _c.fijar(rol, p, activo);
    if (!mounted) return;
    _informar(f, '${activo ? 'Activado' : 'Quitado'}: ${p.nombre} · ${rol.nombre}', antes);
  }

  Future<void> _plantilla(RolEquipo rol, PlantillaRol t) async {
    if (!_c.editable) return;
    final antes = _c.matriz;
    final f = await _c.aplicarPlantilla(rol, t);
    if (!mounted) return;
    _informar(f, 'Plantilla «${t.nombre}» aplicada a ${rol.nombre}', antes);
  }

  void _informar(String? fallo, String hecho, MatrizPermisos antes) {
    if (fallo != null) {
      vibrarError();
      avisar(context, fallo, tipo: TipoAviso.error);
      return;
    }
    vibrarExito();
    anunciar(context, hecho);
    avisar(context, hecho,
        tipo: TipoAviso.exito,
        accion: AccionAviso('Deshacer', () async {
          final f = await _c.restaurar(antes);
          if (f != null && mounted) avisar(context, f, tipo: TipoAviso.error);
        }));
  }

  Future<void> _elegirPlantilla(RolEquipo rol) async {
    final t = await mostrarHojaZ<PlantillaRol>(
      context,
      nombre: 'panel_cra/plantillas',
      contenido: (ctx) => _HojaPlantillas(rol: rol, actual: _c.matriz.plantillaDe(rol)),
    );
    if (t != null) await _plantilla(rol, t);
  }

  Future<void> _darRol() async {
    await mostrarHojaZ<void>(
      context,
      nombre: 'panel_cra/dar_rol',
      contenido: (ctx) => _HojaDarRol(controlador: _c, demostracion: widget.demostracion),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final ancha = MediaQuery.sizeOf(context).width >= 900;
        return Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Cabecera(alDarRol: _c.puede(Permiso.administrarRoles) ? _darRol : null),
                _Origen(controlador: _c, demostracion: widget.demostracion),
                Expanded(
                  child: _c.cargando && _c.origen != OrigenPermisos.servidor
                      ? const Center(
                          child: SizedBox.square(
                              dimension: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: Cra.dorado)))
                      : ancha
                          ? _MatrizAncha(
                              controlador: _c,
                              alCambiar: _cambiar,
                              alPlantilla: _elegirPlantilla,
                            )
                          : _PorRol(
                              controlador: _c,
                              rol: _rol,
                              alElegirRol: (r) => setState(() => _rol = r),
                              alCambiar: _cambiar,
                              alPlantilla: _elegirPlantilla,
                              alAplicar: _plantilla,
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.alDarRol});
  final VoidCallback? alDarRol;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Row(
        children: [
          BotonIcono(icono: Icons.arrow_back_rounded, etiqueta: 'Volver', alTocar: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text('PERMISOS DEL EQUIPO',
                      style: tt.titleLarge?.copyWith(color: Cra.dorado, letterSpacing: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Text('Qué puede hacer cada rol en el panel', style: tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (alDarRol != null) BotonIcono(icono: Icons.person_add_alt_1_rounded, etiqueta: 'Dar rol a una persona', alTocar: alDarRol!),
        ],
      ),
    );
  }
}

/// De dónde salen los permisos, en una línea discreta (solo si no es el servidor).
class _Origen extends StatelessWidget {
  const _Origen({required this.controlador, required this.demostracion});
  final ControladorPermisos controlador;
  final bool demostracion;

  @override
  Widget build(BuildContext context) {
    final c = controlador;
    final (icono, texto) = demostracion
        ? (Icons.science_outlined, 'Demostración: los cambios no salen de este teléfono.')
        : switch (c.origen) {
            OrigenPermisos.servidor => (null, ''),
            OrigenPermisos.copia => (Icons.cloud_off_rounded, 'Sin conexión: copia guardada. Para cambiar, vuelve a tener señal.'),
            OrigenPermisos.plantillas =>
              (Icons.info_outline_rounded, 'Plantillas por defecto: el servidor aún no tiene la tabla de permisos.'),
          };
    if (icono == null) return const SizedBox(height: 6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Icon(icono, size: 16, color: Cra.textoTenue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texto, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Cra.textoTenue)),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _AlCambiar = Future<void> Function(RolEquipo rol, Permiso p, bool activo);

// ------------------------------------------------------------------ teléfono: un rol a la vez

class _PorRol extends StatelessWidget {
  const _PorRol({
    required this.controlador,
    required this.rol,
    required this.alElegirRol,
    required this.alCambiar,
    required this.alPlantilla,
    required this.alAplicar,
  });
  final ControladorPermisos controlador;
  final RolEquipo rol;
  final ValueChanged<RolEquipo> alElegirRol;
  final _AlCambiar alCambiar;
  final ValueChanged<RolEquipo> alPlantilla;
  final Future<void> Function(RolEquipo, PlantillaRol) alAplicar;

  @override
  Widget build(BuildContext context) {
    final c = controlador;
    final tt = Theme.of(context).textTheme;
    final m = c.matriz;
    final plantilla = m.plantillaDe(rol);
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final r in RolEquipo.values)
                _ChipRol(
                  rol: r,
                  activo: r == rol,
                  cuenta: m.de(r).length,
                  alTocar: () => alElegirRol(r),
                  acciones: c.editable
                      ? [
                          for (final t in Plantillas.todas)
                            AccionGesto(
                              etiqueta: 'Plantilla ${t.nombre}',
                              icono: Icons.auto_awesome_rounded,
                              alEjecutar: () => alAplicar(r, t),
                            ),
                        ]
                      : const [],
                  vistaPrevia: _ResumenRol(rol: r, permisos: m.de(r)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Cra.superficie,
              borderRadius: BorderRadius.circular(Zr.l),
              border: Border.all(color: Cra.linea),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                  child: Row(
                    children: [
                      Icon(rol.icono, color: Cra.dorado),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rol.nombre, style: tt.titleMedium),
                            Text(plantilla == null ? 'Personalizado' : 'Plantilla: ${plantilla.nombre}', style: tt.bodySmall),
                          ],
                        ),
                      ),
                      if (c.editable)
                        BotonIcono(
                          icono: Icons.auto_awesome_rounded,
                          etiqueta: 'Aplicar una plantilla a ${rol.nombre}',
                          alTocar: () => alPlantilla(rol),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Cra.linea),
                for (final p in Permiso.values)
                  _FilaPermiso(
                    permiso: p,
                    activo: m.puede(rol, p),
                    bloqueado: MatrizPermisos.bloqueado(rol, p),
                    alCambiar: c.editable ? (v) => alCambiar(rol, p, v) : null,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('Mantén presionado un rol para ver su resumen y aplicarle una plantilla.',
              style: tt.bodySmall?.copyWith(color: Cra.textoTenue)),
        ),
      ],
    );
  }
}

class _ChipRol extends StatelessWidget {
  const _ChipRol({
    required this.rol,
    required this.activo,
    required this.cuenta,
    required this.alTocar,
    required this.acciones,
    required this.vistaPrevia,
  });
  final RolEquipo rol;
  final bool activo;
  final int cuenta;
  final VoidCallback alTocar;
  final List<AccionGesto> acciones;
  final Widget vistaPrevia;

  @override
  Widget build(BuildContext context) {
    final chip = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Zm.corto,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: activo ? Cra.dorado : Cra.superficie,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: activo ? Cra.dorado : Cra.linea),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(rol.icono, size: 18, color: activo ? Cra.azul : Cra.blanco),
          const SizedBox(width: 6),
          Flexible(
            child: Text(rol.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: activo ? Cra.azul : Cra.blanco, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          const SizedBox(width: 6),
          Text('$cuenta', style: TextStyle(color: activo ? Cra.azul : Cra.textoTenue, fontSize: 13)),
        ],
      ),
    );
    return Semantics(
      selected: activo,
      button: true,
      label: '${rol.nombre}, $cuenta permisos',
      excludeSemantics: true,
      child: MenuMantenido(
        etiqueta: rol.nombre,
        radio: BorderRadius.circular(999),
        alTocar: alTocar,
        acciones: acciones,
        vistaPrevia: (_) => vistaPrevia,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 44), child: chip)),
      ),
    );
  }
}

class _ResumenRol extends StatelessWidget {
  const _ResumenRol({required this.rol, required this.permisos});
  final RolEquipo rol;
  final Set<Permiso> permisos;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(rol.icono, color: Cra.dorado),
            const SizedBox(width: 8),
            Text(rol.nombre, style: tt.titleMedium),
          ]),
          const SizedBox(height: 10),
          if (permisos.isEmpty) Text('Sin permisos: no entra al panel.', style: tt.bodySmall),
          for (final p in Permiso.values.where(permisos.contains))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(p.icono, size: 16, color: Cra.textoSuave),
                const SizedBox(width: 8),
                Flexible(child: Text(p.nombre, style: tt.bodyMedium)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _FilaPermiso extends StatelessWidget {
  const _FilaPermiso({required this.permiso, required this.activo, required this.bloqueado, required this.alCambiar});
  final Permiso permiso;
  final bool activo;
  final bool bloqueado;
  final ValueChanged<bool>? alCambiar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final p = permiso;
    final cambiar = bloqueado ? null : alCambiar;
    return Presionable(
      onTap: cambiar == null ? null : () => cambiar(!activo),
      escala: 0.99,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
        child: Row(
          children: [
            Icon(p.icono, size: 22, color: activo ? Cra.dorado : Cra.textoTenue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(p.nombre, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700))),
                    if (p.sensible) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.lock_outline_rounded, size: 14, color: Cra.textoTenue),
                    ],
                  ]),
                  Text(bloqueado ? 'Administración lo conserva siempre' : p.pista, style: tt.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InterruptorIos(
              valor: activo,
              etiqueta: p.nombre,
              colorActivo: Cra.dorado,
              alCambiar: cambiar,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ pantalla ancha: la matriz entera

class _MatrizAncha extends StatelessWidget {
  const _MatrizAncha({required this.controlador, required this.alCambiar, required this.alPlantilla});
  final ControladorPermisos controlador;
  final _AlCambiar alCambiar;
  final ValueChanged<RolEquipo> alPlantilla;

  static const _ancho = 104.0;

  @override
  Widget build(BuildContext context) {
    final c = controlador;
    final m = c.matriz;
    final tt = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            decoration: BoxDecoration(
              color: Cra.superficie,
              borderRadius: BorderRadius.circular(Zr.l),
              border: Border.all(color: Cra.linea),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: Text('Permiso', style: tt.labelLarge?.copyWith(color: Cra.textoTenue))),
                      for (final r in RolEquipo.values)
                        SizedBox(
                          width: _ancho,
                          child: MenuMantenido(
                            etiqueta: r.nombre,
                            alTocar: c.editable ? () => alPlantilla(r) : null,
                            acciones: [
                              if (c.editable)
                                AccionGesto(
                                  etiqueta: 'Aplicar plantilla',
                                  icono: Icons.auto_awesome_rounded,
                                  alEjecutar: () => alPlantilla(r),
                                ),
                            ],
                            vistaPrevia: (_) => _ResumenRol(rol: r, permisos: m.de(r)),
                            child: Tooltip(
                              message: c.editable ? 'Tocar: aplicar plantilla' : r.nombre,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                child: Column(children: [
                                  Icon(r.icono, size: 20, color: Cra.dorado),
                                  const SizedBox(height: 4),
                                  Text(r.nombre,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Cra.linea),
                for (final p in Permiso.values)
                  Container(
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x333A6286)))),
                    padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
                    child: Row(
                      children: [
                        Icon(p.icono, size: 20, color: Cra.textoSuave),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.nombre, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                              Text(p.pista, style: tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        for (final r in RolEquipo.values)
                          SizedBox(
                            width: _ancho,
                            child: Center(
                              child: _Celda(
                                activo: m.puede(r, p),
                                bloqueado: MatrizPermisos.bloqueado(r, p),
                                etiqueta: '${p.nombre} para ${r.nombre}',
                                alCambiar: c.editable ? (v) => alCambiar(r, p, v) : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Una casilla de la matriz: dorada si el rol tiene el permiso, candado si no se puede quitar.
class _Celda extends StatelessWidget {
  const _Celda({required this.activo, required this.bloqueado, required this.etiqueta, required this.alCambiar});
  final bool activo;
  final bool bloqueado;
  final String etiqueta;
  final ValueChanged<bool>? alCambiar;

  @override
  Widget build(BuildContext context) {
    final cambiar = bloqueado ? null : alCambiar;
    return Semantics(
      checked: activo,
      enabled: cambiar != null,
      label: etiqueta,
      excludeSemantics: true,
      child: Presionable(
        onTap: cambiar == null ? null : () => cambiar(!activo),
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Zm.corto,
              curve: Zm.entrar,
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: activo ? Cra.dorado : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: activo ? Cra.dorado : Cra.borde, width: 2),
              ),
              child: activo
                  ? Icon(bloqueado ? Icons.lock_rounded : Icons.check_rounded, size: 18, color: Cra.azul)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ hojas

class _HojaPlantillas extends StatelessWidget {
  const _HojaPlantillas({required this.rol, required this.actual});
  final RolEquipo rol;
  final PlantillaRol? actual;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Plantilla para ${rol.nombre}', style: tt.titleLarge),
        const SizedBox(height: 4),
        Text('Copia sus permisos; después puedes ajustarlos uno por uno.', style: tt.bodySmall),
        const SizedBox(height: 14),
        for (final t in Plantillas.todas)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Presionable(
              etiqueta: 'Plantilla ${t.nombre}${identical(t, actual) ? ', actual' : ''}',
              onTap: () => Navigator.of(context).pop(t),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Cra.superficie,
                  borderRadius: BorderRadius.circular(Zr.m),
                  border: Border.all(color: identical(t, actual) ? Cra.dorado : Cra.linea, width: identical(t, actual) ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.nombre, style: tt.titleSmall),
                          Text(t.descripcion, style: tt.bodySmall),
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, children: [
                            for (final p in Permiso.values.where(t.permisos.contains))
                              Icon(p.icono, size: 16, color: Cra.textoSuave, semanticLabel: p.nombre),
                          ]),
                        ],
                      ),
                    ),
                    if (identical(t, actual)) const Icon(Icons.check_circle_rounded, color: Cra.dorado),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HojaDarRol extends StatefulWidget {
  const _HojaDarRol({required this.controlador, required this.demostracion});
  final ControladorPermisos controlador;
  final bool demostracion;

  @override
  State<_HojaDarRol> createState() => _HojaDarRolState();
}

class _HojaDarRolState extends State<_HojaDarRol> {
  final _correo = TextEditingController();
  final _foco = FocusNode();
  RolEquipo _rol = RolEquipo.voluntario;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _foco.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_rol == RolEquipo.admin) {
      final ok = await confirmarEnHoja(context,
          titulo: '¿Dar Administración?',
          texto: 'Tendrá todos los permisos, también el de quitarte el tuyo.',
          textoConfirmar: 'Dar Administración',
          seguroPrimero: true);
      if (!ok || !mounted) return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final f = await widget.controlador.asignarRol(_correo.text, _rol);
    if (!mounted) return;
    if (f != null) {
      vibrarError();
      setState(() {
        _enviando = false;
        _error = f;
      });
      return;
    }
    vibrarExito();
    final hecho = widget.demostracion
        ? 'Demostración: ${_correo.text.trim()} sería ${_rol.nombre}'
        : '${_correo.text.trim()} ahora es ${_rol.nombre}';
    anunciar(context, hecho);
    avisar(context, hecho, tipo: TipoAviso.exito);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Dar rol a una persona', style: tt.titleLarge),
        const SizedBox(height: 4),
        Text('La persona debe tener cuenta en Zanky. El rol vale desde su próxima acción.', style: tt.bodySmall),
        const SizedBox(height: 14),
        CampoAdmin(
          etiqueta: 'Correo',
          controlador: _correo,
          foco: _foco,
          icono: Icons.alternate_email_rounded,
          teclado: TextInputType.emailAddress,
          accion: TextInputAction.done,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in RolEquipo.values)
              ChoiceChip(
                label: Text(r.nombre),
                avatar: Icon(r.icono, size: 18),
                selected: r == _rol,
                onSelected: (_) {
                  vibrar(Vibracion.seleccion);
                  setState(() => _rol = r);
                },
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Semantics(liveRegion: true, child: Text(_error!, style: tt.bodyMedium?.copyWith(color: Cra.riesgo))),
        ],
        const SizedBox(height: 16),
        BotonZ(
          texto: 'Dar rol de ${_rol.nombre}',
          icono: Icons.how_to_reg_rounded,
          color: Cra.dorado,
          colorTexto: Cra.azul,
          cargando: _enviando,
          onTap: _enviar,
        ),
      ],
    );
  }
}
