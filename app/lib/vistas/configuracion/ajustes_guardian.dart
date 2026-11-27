import 'package:flutter/material.dart';

import '../../datos/estado.dart';
import '../../datos/roles.dart';
import '../../nucleo/kit/interruptor.dart';
import '../../nucleo/tema.dart';
import '../avisos/bandeja_avisos.dart';
import '../guardian/borrar_datos.dart';
import '../guardian/editar_perfil.dart';
import 'cuenta_entrar.dart';
import 'pantalla_configuracion.dart';
import 'piezas_configuracion.dart';

/// Configuración dentro de Guardián, como Ajustes de iOS: debajo de la tarjeta de la cuenta,
/// los grupos «Cuenta», «Avisos», «Privacidad» y «Acerca de». Reutiliza las filas, el
/// interruptor de anonimato, las preferencias de avisos y el borrado de datos de Configuración;
/// «Configuración completa» abre esa misma pantalla.
class SeccionAjustesGuardian extends StatelessWidget {
  const SeccionAjustesGuardian({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = Zanky.de(context).perfil;
    final cuenta = CuentaScope.maybeDe(context);
    final nombre = perfil?.nombre.trim() ?? '';
    return Column(
      key: const ValueKey('ajustes_guardian'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GrupoAjustes(
          titulo: 'Cuenta',
          filas: [
            FilaAjustes(
              icono: Icons.badge_rounded,
              titulo: nombre.isEmpty ? 'Crear mi perfil' : 'Mi perfil: $nombre',
              detalle: 'Nombre, colegio y cédula, solo en este teléfono',
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
            if (cuenta != null && cuenta.gestiones.isNotEmpty)
              FilaAjustes(
                icono: Icons.shield_rounded,
                color: Zc.raiz,
                titulo: 'Gestión · ${RolPanel.etiqueta(cuenta.rol)}',
                detalle: 'Lo que tu rol puede hacer',
                alTocar: () => abrirPanelDeCuenta(context),
              ),
          ],
        ),
        const SeccionPreferenciasAvisos(),
        GrupoAjustes(
          titulo: 'Privacidad',
          filas: [
            const FilaAjustes(
              icono: Icons.lock_rounded,
              color: Zc.raizSuave,
              titulo: 'Tus datos',
              detalle: 'Las fotos salen sin ubicación EXIF; la cédula se guarda como huella, nunca en claro. '
                  'Tratamiento según la Ley 1581 de 2012.',
            ),
            FilaAjustes(
              icono: Icons.delete_forever_rounded,
              titulo: 'Borrar mis datos de este teléfono',
              detalle: 'Perfil, reportes guardados y progreso',
              destructiva: true,
              alTocar: () => confirmarYBorrarDatos(context),
            ),
          ],
        ),
        GrupoAjustes(
          titulo: 'Acerca de',
          filas: [
            FilaAjustes(
              key: const ValueKey('configuracion_completa'),
              icono: Icons.settings_rounded,
              color: Zc.raiz,
              titulo: 'Configuración completa',
              detalle: 'Todo junto en una pantalla',
              alTocar: () => abrirConfiguracion(context),
            ),
            const FilaAjustes(
              icono: Icons.eco_rounded,
              titulo: 'Zanky',
              detalle: 'Corporación Autónoma Regional del Atlántico · Manglar Hack Atlántico 2026',
            ),
          ],
        ),
      ],
    );
  }
}
