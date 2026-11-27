import 'package:flutter/material.dart';

import '../../datos/cuenta/cuenta.dart';
import '../../datos/estado.dart';
import '../../datos/guardian.dart';
import '../../datos/roles.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/confirmar.dart';
import '../../nucleo/kit/interruptor.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../admin/piezas_admin.dart';
import '../guardian/borrar_datos.dart';
import '../guardian/editar_perfil.dart';
import 'cuenta_entrar.dart';
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
                  alCambiar: (v) => cambiarAnonimo(context, v),
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
          const SeccionPreferenciasAvisos(),
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
}

/// Guarda «Reportar en anónimo» en el perfil local. Lo usan Configuración y Guardián.
Future<void> cambiarAnonimo(BuildContext context, bool valor) async {
  {
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
          : FormularioEntrar(
              key: const ValueKey('sin_sesion'),
              cuenta: cuenta,
            ),
    );
  }
}
