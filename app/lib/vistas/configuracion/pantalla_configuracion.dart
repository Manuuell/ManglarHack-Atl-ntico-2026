import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../datos/admin/repositorio_admin.dart';
import '../../datos/cuenta/cuenta.dart';
import '../../datos/estado.dart';
import '../../datos/guardian.dart';
import '../../datos/roles.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/boton_estado.dart';
import '../../nucleo/kit/confirmar.dart';
import '../../nucleo/kit/interruptor.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../admin/piezas_admin.dart';
import '../guardian/borrar_datos.dart';
import '../guardian/editar_perfil.dart';
import 'piezas_configuracion.dart';
import 'seccion_gestion.dart';
import '../avisos/bandeja_avisos.dart';

/// El engranaje de Inicio y Guardián: abre Configuración. 48 px de toque.
class BotonConfiguracion extends StatelessWidget {
  const BotonConfiguracion({super.key});

  @override
  Widget build(BuildContext context) {
    final cuenta = CuentaScope.maybeDe(context);
    final conGestion = cuenta != null && cuenta.gestiones.isNotEmpty;
    return Presionable(
      etiqueta: conGestion ? 'Configuración y gestión' : 'Configuración',
      onTap: () => abrirConfiguracion(context),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Zc.superficie,
          shape: BoxShape.circle,
          border: Border.all(
            color: conGestion ? Zc.hoja : Zc.linea,
            width: conGestion ? 1.5 : 1,
          ),
        ),
        child: const Icon(Icons.settings_rounded, size: 23, color: Zc.raiz),
      ),
    );
  }
}

/// Abre Configuración como pantalla aparte, con la cuenta y el panel de la raíz.
Future<void> abrirConfiguracion(BuildContext context) {
  final cuenta = CuentaScope.leer(context);
  final admin =
      context.getElementForInheritedWidgetOfExactType<AdminScope>() == null
      ? null
      : AdminScope.leer(context);
  Widget pantalla = const PantallaConfiguracion();
  if (admin != null) pantalla = AdminScope(controlador: admin, child: pantalla);
  if (cuenta != null) pantalla = CuentaScope(cuenta: cuenta, child: pantalla);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'configuracion'),
      builder: (_) => pantalla,
    ),
  );
}

/// Configuración: perfil local, anonimato, privacidad y la cuenta. Con una cuenta del equipo
/// aparece «Gestión» con lo que su rol puede hacer.
class PantallaConfiguracion extends StatelessWidget {
  const PantallaConfiguracion({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = Zanky.de(context);
    final perfil = estado.perfil;
    final cuenta = CuentaScope.maybeDe(context);
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Zc.arena,
      appBar: AppBar(
        backgroundColor: Zc.arena,
        surfaceTintColor: Colors.transparent,
        title: const Text('Configuración'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 48),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (cuenta != null) _BloqueCuenta(cuenta: cuenta),
          const SeccionGestion(),
          const SeccionPreferenciasAvisos(),
          GrupoAjustes(
            titulo: 'En este teléfono',
            nota:
                'Tu perfil vive solo en este teléfono; no necesitas cuenta para reportar.',
            filas: [
              FilaAjustes(
                icono: Icons.badge_rounded,
                titulo: perfil == null || perfil.nombre.trim().isEmpty
                    ? 'Crear mi perfil'
                    : perfil.nombre.trim(),
                detalle: perfil == null
                    ? 'Nombre y colegio, si quieres'
                    : (perfil.colegio.trim().isEmpty
                          ? 'Nombre, colegio y cédula'
                          : perfil.colegio.trim()),
                alTocar: () => mostrarEditarPerfil(context),
              ),
              FilaAjustes(
                icono: Icons.visibility_off_rounded,
                color: Zc.cienaga,
                titulo: 'Reportar en anónimo',
                detalle: 'Tus reportes no llevan tu nombre ni tu id',
                fin: InterruptorIos(
                  etiqueta: 'Reportar en anónimo',
                  valor: perfil?.anonimoPorDefecto ?? false,
                  alCambiar: (v) => _cambiarAnonimo(context, v),
                ),
              ),
            ],
          ),
          GrupoAjustes(
            titulo: 'Privacidad',
            filas: [
              const FilaAjustes(
                icono: Icons.lock_rounded,
                color: Zc.raizSuave,
                titulo: 'Tus datos',
                detalle:
                    'Las fotos salen sin ubicación EXIF; la cédula se guarda como huella, nunca en claro. '
                    'Tratamiento según la Ley 1581 de 2012.',
              ),
              FilaAjustes(
                icono: Icons.delete_forever_rounded,
                titulo: 'Borrar mis datos de este teléfono',
                detalle: 'Perfil, reportes guardados y progreso',
                destructiva: true,
                alTocar: () async {
                  final ok = await confirmarYBorrarDatos(context);
                  if (ok && context.mounted) Navigator.of(context).maybePop();
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Zanky · Manglar Hack Atlántico 2026',
              textAlign: TextAlign.center,
              style: tt.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cambiarAnonimo(BuildContext context, bool valor) async {
    final estado = Zanky.leer(context);
    final base = estado.perfil ?? estado.perfilNuevo();
    final nuevo = Perfil(
      id: base.id,
      creado: base.creado,
      sal: base.sal,
      consentimiento: base.consentimiento,
      nombre: base.nombre,
      colegio: base.colegio,
      anonimoPorDefecto: valor,
      rol: base.rol,
      cedulaHash: base.cedulaHash,
    );
    try {
      await estado.guardarPerfil(nuevo);
      vibrar(Vibracion.seleccion);
    } catch (_) {
      if (context.mounted) {
        avisar(
          context,
          'No se pudo guardar. Revisa el espacio del teléfono.',
          tipo: TipoAviso.error,
        );
      }
    }
  }
}

/// La cuenta: sin sesión, el formulario para entrar; con sesión, quién eres y cerrar sesión.
class _BloqueCuenta extends StatelessWidget {
  const _BloqueCuenta({required this.cuenta});
  final ControladorCuenta cuenta;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Zm.medio,
      switchInCurve: Zm.entrar,
      child: cuenta.conSesion
          ? GrupoAjustes(
              key: const ValueKey('con_sesion'),
              titulo: 'Tu cuenta',
              filas: [
                FilaAjustes(
                  icono: Icons.account_circle_rounded,
                  color: Zc.raiz,
                  titulo: cuenta.demostracion
                      ? 'Demostración del equipo'
                      : (cuenta.correo ?? 'Cuenta'),
                  detalle: cuenta.rol == null
                      ? 'Cuenta de ciudadano · sin rol de gestión'
                      : 'Rol: ${RolPanel.etiqueta(cuenta.rol)}',
                ),
                FilaAjustes(
                  key: const ValueKey('cerrar_sesion'),
                  icono: Icons.logout_rounded,
                  titulo: 'Cerrar sesión',
                  destructiva: true,
                  alTocar: () async {
                    final si = await confirmarEnHoja(
                      context,
                      titulo: 'Cerrar sesión',
                      texto:
                          'Se borra la sesión de este teléfono. Tus reportes y tu perfil se quedan.',
                      textoConfirmar: 'Cerrar sesión',
                      destructivo: true,
                    );
                    if (!si) return;
                    await cuenta.salir();
                    if (context.mounted) avisar(context, 'Sesión cerrada');
                  },
                ),
              ],
            )
          : _FormularioCuenta(
              key: const ValueKey('sin_sesion'),
              cuenta: cuenta,
            ),
    );
  }
}

class _FormularioCuenta extends StatefulWidget {
  const _FormularioCuenta({super.key, required this.cuenta});
  final ControladorCuenta cuenta;

  @override
  State<_FormularioCuenta> createState() => _FormularioCuentaState();
}

class _FormularioCuentaState extends State<_FormularioCuenta> {
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _focoCorreo = FocusNode();
  final _focoClave = FocusNode();
  bool _ver = false;
  String? _error;
  String? _nota;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    _focoCorreo.dispose();
    _focoClave.dispose();
    super.dispose();
  }

  bool get _completo => _correo.text.contains('@') && _clave.text.isNotEmpty;

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _nota = null;
    });
    try {
      await widget.cuenta.entrar(_correo.text, _clave.text);
      TextInput.finishAutofillContext();
    } on ErrorCuenta catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
      rethrow; // el botón lo muestra como error
    } on ErrorPanel catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
      rethrow;
    }
  }

  Future<void> _recuperar() async {
    setState(() {
      _error = null;
      _nota = null;
    });
    try {
      await widget.cuenta.recuperarClave(_correo.text);
      if (mounted) {
        setState(
          () => _nota =
              'Si hay una cuenta con ese correo, te llegó un enlace para elegir otra contraseña.',
        );
      }
    } on ErrorCuenta catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cuenta;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                'ENTRAR CON TU CUENTA',
                style: tt.seccion.copyWith(color: Zc.textoSuave),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Zc.superficie,
              borderRadius: BorderRadius.circular(Zr.m),
              border: Border.all(color: Zc.linea),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  c.configurado
                      ? 'La misma cuenta de la web. Si el equipo te dio un rol (administración, moderación, '
                            'investigación u organización), aquí se desbloquea lo tuyo.'
                      : 'Este teléfono no está conectado al servidor, así que no hay cuentas. '
                            'Puedes ver la demostración de la gestión con datos de ejemplo.',
                  style: tt.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (c.restaurando)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (c.configurado) ...[
                  AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CampoAdmin(
                          etiqueta: 'Correo',
                          icono: Icons.alternate_email_rounded,
                          controlador: _correo,
                          foco: _focoCorreo,
                          teclado: TextInputType.emailAddress,
                          pistas: const [
                            AutofillHints.email,
                            AutofillHints.username,
                          ],
                          alEnviar: _focoClave.requestFocus,
                        ),
                        const SizedBox(height: 14),
                        CampoAdmin(
                          etiqueta: 'Contraseña',
                          icono: Icons.lock_outline_rounded,
                          controlador: _clave,
                          foco: _focoClave,
                          oculto: !_ver,
                          accion: TextInputAction.done,
                          pistas: const [AutofillHints.password],
                          alEnviar: () {
                            if (_completo) _entrar().catchError((_) {});
                          },
                          sufijo: Presionable(
                            etiqueta: _ver
                                ? 'Ocultar contraseña'
                                : 'Mostrar contraseña',
                            onTap: () => setState(() => _ver = !_ver),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(
                                _ver
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 22,
                                color: Zc.textoSuave,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: context.resolveDuration(Zm.corto),
                    curve: Zm.entrar,
                    child: (_error ?? _nota) == null
                        ? const SizedBox(width: double.infinity)
                        : Semantics(
                            liveRegion: true,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12, left: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _error != null
                                        ? Icons.error_outline_rounded
                                        : Icons.mark_email_read_rounded,
                                    size: 18,
                                    color: _error != null
                                        ? Zc.prioridad[5]
                                        : Zc.hoja,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error ?? _nota!,
                                      key: const ValueKey('mensaje_cuenta'),
                                      style: tt.bodySmall?.copyWith(
                                        color: _error != null
                                            ? Zc.prioridad[5]
                                            : Zc.texto,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  ListenableBuilder(
                    listenable: Listenable.merge([_correo, _clave]),
                    builder: (context, _) => BotonEstado(
                      texto: 'Entrar',
                      textoCargando: 'Entrando',
                      textoHecho: 'Dentro',
                      textoError: 'No se pudo entrar',
                      icono: Icons.login_rounded,
                      alPresionar: _completo ? _entrar : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: _recuperar,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text('¿Olvidaste tu contraseña?'),
                    ),
                  ),
                ] else
                  BotonEstado(
                    texto: 'Ver la demostración de gestión',
                    textoHecho: 'Listo',
                    icono: Icons.play_circle_outline_rounded,
                    alPresionar: () async => c.entrarDemo(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
