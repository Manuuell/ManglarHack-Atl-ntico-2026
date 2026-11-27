import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../datos/admin/repositorio_admin.dart';
import '../../datos/cuenta/cuenta.dart';
import '../../datos/roles.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/boton_estado.dart';
import '../../nucleo/kit/confirmar.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../admin/panel_cra.dart';
import '../admin/piezas_admin.dart';
import 'pantalla_configuracion.dart';
import 'piezas_configuracion.dart';

/// La cuenta a la vista: el formulario para entrar (Configuración y la hoja), la tarjeta de
/// Guardián y el avatar del encabezado de Inicio. Una sola pieza para las tres: la cuenta es la
/// MISMA de la web (Supabase Auth) y el rol sale solo de la sesión, nunca de un selector.

/// Iniciales para el avatar a partir del correo: «ana.perez@…» → «AP», «manuel@…» → «MA».
String inicialesDeCorreo(String? correo) {
  final usuario = (correo ?? '').split('@').first.trim();
  final partes = usuario
      .split(RegExp(r'[._\-+\s]+'))
      .where((p) => p.isNotEmpty && RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]').hasMatch(p[0]))
      .toList();
  if (partes.isEmpty) return 'Z';
  if (partes.length == 1) {
    final p = partes.first;
    return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
  }
  return (partes[0][0] + partes[1][0]).toUpperCase();
}

/// Abre la hoja «Entra con tu cuenta de Zanky». Al entrar, el botón dibuja su ✓ con háptica,
/// la hoja se cierra sola y sale un aviso de éxito. La cuenta va explícita: las rutas apiladas
/// no heredan el [CuentaScope] de la raíz.
Future<void> mostrarHojaEntrar(BuildContext context, {ControladorCuenta? cuenta}) async {
  final c = cuenta ?? CuentaScope.leer(context);
  if (c == null) return;
  final dentro = await mostrarHojaZ<bool>(
    context,
    nombre: 'entrar_cuenta',
    contenido: (hoja) => FormularioEntrar(
      cuenta: c,
      enHoja: true,
      alEntrar: () => Navigator.of(hoja).pop(true),
    ),
  );
  if (dentro == true && context.mounted) {
    avisar(
      context,
      c.demostracion ? 'Estás en la demostración del equipo' : 'Entraste como ${c.correo ?? 'tu cuenta'}',
      tipo: TipoAviso.exito,
    );
  }
}

/// Pide confirmación en hoja y cierra la sesión. Verdadero si se cerró.
Future<bool> confirmarCerrarSesion(BuildContext context, ControladorCuenta cuenta) async {
  final si = await confirmarEnHoja(
    context,
    titulo: 'Cerrar sesión',
    texto: 'Se borra la sesión de este teléfono. Tus reportes y tu perfil se quedan.',
    textoConfirmar: 'Cerrar sesión',
    destructivo: true,
  );
  if (!si) return false;
  await cuenta.salir();
  if (context.mounted) avisar(context, 'Sesión cerrada');
  return true;
}

/// Con un rol que modera, el panel CRA; con otro rol de gestión, Configuración (donde está
/// «Gestión» con lo que ese rol puede hacer).
Future<void> abrirPanelDeCuenta(BuildContext context) {
  if (AdminScope.maybeDe(context)?.dentro ?? false) return abrirPanelCra(context);
  return abrirConfiguracion(context);
}

// ------------------------------------------------------------------ formulario

/// Correo, contraseña con «ver», «¿Olvidaste tu contraseña?» y el botón con estados
/// (cargando, ✓ con háptica, error con sacudida). Los errores salen en palabras claras
/// (correo o clave incorrectos, sin señal) debajo de los campos.
///
/// [enHoja]: con título grande y sin la tarjeta de Configuración. [alEntrar] se llama cuando
/// el ✓ ya se dibujó, para cerrar la hoja sin cortar el gesto.
class FormularioEntrar extends StatefulWidget {
  const FormularioEntrar({super.key, required this.cuenta, this.enHoja = false, this.alEntrar});
  final ControladorCuenta cuenta;
  final bool enHoja;
  final VoidCallback? alEntrar;

  @override
  State<FormularioEntrar> createState() => _FormularioEntrarState();
}

class _FormularioEntrarState extends State<FormularioEntrar> {
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
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo entrar. Revisa tu internet e inténtalo de nuevo.');
      }
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
          () => _nota = 'Si hay una cuenta con ese correo, te llegó un enlace para elegir otra contraseña.',
        );
      }
    } on ErrorCuenta catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No hay conexión con el servidor. Inténtalo de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: widget.cuenta,
      builder: (context, _) {
        final campos = _campos(context, widget.cuenta);
        if (widget.enHoja) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const _Circulo(tamano: 48, child: Icon(Icons.person_rounded, color: Colors.white, size: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text('Entra con tu cuenta de Zanky', style: tt.headlineSmall),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              campos,
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Semantics(
                  header: true,
                  child: Text('ENTRAR CON TU CUENTA', style: tt.seccion.copyWith(color: Zc.textoSuave)),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Zc.superficie,
                  borderRadius: BorderRadius.circular(Zr.m),
                  border: Border.all(color: Zc.linea),
                ),
                child: campos,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _campos(BuildContext context, ControladorCuenta c) {
    final tt = Theme.of(context).textTheme;
    return Column(
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
            child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
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
                  pistas: const [AutofillHints.email, AutofillHints.username],
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
                    etiqueta: _ver ? 'Ocultar contraseña' : 'Mostrar contraseña',
                    onTap: () => setState(() => _ver = !_ver),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        _ver ? Icons.visibility_off_rounded : Icons.visibility_rounded,
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
                            _error != null ? Icons.error_outline_rounded : Icons.mark_email_read_rounded,
                            size: 18,
                            color: _error != null ? Zc.prioridad[5] : Zc.hoja,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error ?? _nota!,
                              key: const ValueKey('mensaje_cuenta'),
                              style: tt.bodySmall?.copyWith(color: _error != null ? Zc.prioridad[5] : Zc.texto),
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
              alHecho: widget.alEntrar,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: _recuperar,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ),
        ] else
          BotonEstado(
            texto: 'Ver la demostración de gestión',
            textoHecho: 'Listo',
            icono: Icons.play_circle_outline_rounded,
            alPresionar: () async => c.entrarDemo(),
            alHecho: widget.alEntrar,
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ avatar y tarjeta

class _Circulo extends StatelessWidget {
  const _Circulo({required this.tamano, required this.child, this.color = Cra.azul, this.borde});
  final double tamano;
  final Widget child;
  final Color color;
  final Color? borde;

  @override
  Widget build(BuildContext context) => Container(
        width: tamano,
        height: tamano,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: borde == null ? null : Border.all(color: borde!, width: 2),
        ),
        child: child,
      );
}

/// Las iniciales en un círculo azul CRA; con rol de gestión, aro dorado.
class AvatarIniciales extends StatelessWidget {
  const AvatarIniciales({super.key, required this.cuenta, this.tamano = 52});
  final ControladorCuenta cuenta;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final texto = cuenta.demostracion ? 'DE' : inicialesDeCorreo(cuenta.correo);
    return ExcludeSemantics(
      child: _Circulo(
        tamano: tamano,
        borde: cuenta.rol != null ? Cra.dorado : null,
        child: Text(
          texto,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: tamano * 0.36,
            letterSpacing: 0.5,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// El sello del rol: dorado con el nombre del rol, o gris «Ciudadano» sin rol de gestión.
class SelloRol extends StatelessWidget {
  const SelloRol({super.key, required this.rol});
  final String? rol;

  @override
  Widget build(BuildContext context) {
    final conRol = rol != null;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: conRol ? Cra.dorado.withValues(alpha: 0.22) : Zc.linea.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: conRol ? Cra.dorado : Zc.linea),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            conRol ? Icons.verified_rounded : Icons.person_outline_rounded,
            size: 15,
            color: conRol ? const Color(0xFF7A4800) : Zc.textoSuave,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              conRol ? RolPanel.etiqueta(rol) : 'Ciudadano',
              key: const ValueKey('sello_rol'),
              overflow: TextOverflow.ellipsis,
              style: tt.labelMedium?.copyWith(
                color: conRol ? const Color(0xFF7A4800) : Zc.texto,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La tarjeta de la cuenta arriba de Guardián.
/// Sin sesión: «Entra con tu cuenta de Zanky» y el botón que abre la hoja.
/// Con sesión: avatar, correo, sello del rol, «Abrir panel» si tiene gestión y «Cerrar sesión».
class TarjetaCuenta extends StatelessWidget {
  const TarjetaCuenta({super.key, required this.cuenta, this.alAbrirPanel, this.alCerrar});
  final ControladorCuenta cuenta;

  /// Nulo: no se ofrece «Abrir panel».
  final VoidCallback? alAbrirPanel;

  /// Se llama al tocar «Cerrar sesión» (quien la usa confirma y cierra).
  final VoidCallback? alCerrar;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cuenta,
      builder: (context, _) => AnimatedSwitcher(
        duration: context.resolveDuration(Zm.medio),
        switchInCurve: Zm.entrar,
        child: cuenta.restaurando
            ? _cargando(context)
            : cuenta.conSesion
                ? _conSesion(context)
                : _sinSesion(context),
      ),
    );
  }

  BoxDecoration get _caja => BoxDecoration(
        color: Zc.superficie,
        borderRadius: BorderRadius.circular(Zr.l),
        border: Border.all(color: Zc.linea),
      );

  Widget _cargando(BuildContext context) => Container(
        key: const ValueKey('cuenta_cargando'),
        padding: const EdgeInsets.all(18),
        decoration: _caja,
        child: Row(
          children: [
            const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 14),
            Expanded(child: Text('Revisando tu sesión…', style: Theme.of(context).textTheme.bodyLarge)),
          ],
        ),
      );

  Widget _sinSesion(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('cuenta_sin_sesion'),
      padding: const EdgeInsets.all(18),
      decoration: _caja,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Circulo(
                tamano: 52,
                color: Zc.arena,
                child: Icon(Icons.person_outline_rounded, color: Cra.azul, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Entra con tu cuenta de Zanky', style: tt.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'La misma de la web. Si el equipo te dio un rol, aquí se desbloquea lo tuyo. '
                      'Para reportar no la necesitas.',
                      style: tt.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          BotonZ(
            key: const ValueKey('cuenta_entrar'),
            texto: 'Entrar con mi cuenta',
            icono: Icons.login_rounded,
            color: Cra.azul,
            onTap: () => mostrarHojaEntrar(context, cuenta: cuenta),
          ),
        ],
      ),
    );
  }

  Widget _conSesion(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final correo = cuenta.demostracion ? 'Demostración del equipo' : (cuenta.correo ?? 'Tu cuenta');
    final conGestion = cuenta.gestiones.isNotEmpty;
    return Container(
      key: const ValueKey('cuenta_con_sesion'),
      padding: const EdgeInsets.all(18),
      decoration: _caja,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: 'Sesión iniciada: $correo. '
                '${cuenta.rol == null ? 'Ciudadano' : 'Rol ${RolPanel.etiqueta(cuenta.rol)}'}',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  AvatarIniciales(cuenta: cuenta),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(correo, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleMedium),
                        const SizedBox(height: 6),
                        SelloRol(rol: cuenta.rol),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (conGestion && alAbrirPanel != null) ...[
                Expanded(
                  child: BotonZ(
                    key: const ValueKey('cuenta_abrir_panel'),
                    texto: 'Abrir panel',
                    icono: Icons.shield_rounded,
                    color: Cra.azul,
                    onTap: alAbrirPanel,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: BotonZ(
                  key: const ValueKey('cuenta_cerrar_sesion'),
                  texto: 'Cerrar sesión',
                  icono: Icons.logout_rounded,
                  secundario: true,
                  onTap: alCerrar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// El avatar pequeño del encabezado de Inicio (48 px de toque).
/// Sin sesión: ícono de persona que abre la hoja de entrar. Con sesión: iniciales y, si
/// tiene rol de gestión, un punto dorado; al tocarlo abre una hoja con la tarjeta de la cuenta.
class AvatarCuenta extends StatelessWidget {
  const AvatarCuenta({super.key});

  @override
  Widget build(BuildContext context) {
    final cuenta = CuentaScope.maybeDe(context);
    if (cuenta == null) return const SizedBox.shrink();
    final con = cuenta.conSesion;
    return Presionable(
      key: const ValueKey('avatar_cuenta'),
      etiqueta: con
          ? 'Tu cuenta: ${cuenta.demostracion ? 'demostración' : cuenta.correo ?? ''}'
              '${cuenta.rol == null ? '' : ', ${RolPanel.etiqueta(cuenta.rol)}'}'
          : 'Entrar con tu cuenta',
      onTap: () => con ? _hojaCuenta(context, cuenta) : mostrarHojaEntrar(context, cuenta: cuenta),
      child: SizedBox.square(
        dimension: 48,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (con)
              AvatarIniciales(cuenta: cuenta, tamano: 42)
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Zc.superficie,
                  shape: BoxShape.circle,
                  border: Border.all(color: Zc.linea),
                ),
                child: const Icon(Icons.person_outline_rounded, size: 24, color: Zc.raiz),
              ),
            if (con && cuenta.rol != null)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  key: const ValueKey('punto_rol'),
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: Cra.dorado,
                    shape: BoxShape.circle,
                    border: Border.all(color: Zc.arena, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _hojaCuenta(BuildContext context, ControladorCuenta cuenta) async {
    final accion = await mostrarHojaZ<String>(
      context,
      nombre: 'tu_cuenta',
      contenido: (hoja) => TarjetaCuenta(
        cuenta: cuenta,
        alAbrirPanel: () => Navigator.of(hoja).pop('panel'),
        alCerrar: () => Navigator.of(hoja).pop('salir'),
      ),
    );
    if (!context.mounted) return;
    if (accion == 'panel') return abrirPanelDeCuenta(context);
    if (accion == 'salir') await confirmarCerrarSesion(context, cuenta);
  }
}
