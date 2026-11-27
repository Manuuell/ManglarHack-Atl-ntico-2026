import '../../nucleo/kit/ruta_borde.dart';
import 'package:flutter/material.dart';

import '../../datos/admin/controlador_admin.dart';
import '../../datos/admin/reporte_admin.dart';
import '../../nucleo/kit/anuncio.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/tema.dart';
import 'acceso_admin.dart';
import 'bandeja_admin.dart';
import 'piezas_admin.dart';
import 'resumen_admin.dart';

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

enum _Vista { bandeja, resumen }

/// El panel: acceso → bandeja y resumen. Una sola pantalla con cabecera propia.
class PanelCra extends StatefulWidget {
  const PanelCra({super.key});

  @override
  State<PanelCra> createState() => _PanelCraState();
}

class _PanelCraState extends State<PanelCra> {
  _Vista _vista = _Vista.bandeja;
  ControladorAdmin? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AdminScope.de(context);
    if (!identical(c, _c)) {
      _c?.removeListener(_alCambiar);
      _c = c..addListener(_alCambiar);
    }
  }

  @override
  void dispose() {
    _c?.removeListener(_alCambiar);
    super.dispose();
  }

  /// Si el servidor no aceptó una decisión, se dice por qué (y el reporte ya volvió a como estaba).
  void _alCambiar() {
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
    return Scaffold(
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
          if (c.dentro) ...[
            BotonIcono(
              icono: Icons.refresh_rounded,
              etiqueta: 'Actualizar reportes',
              alTocar: () => c.actualizar(),
            ),
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
  const _Dentro({super.key, required this.controlador, required this.vista, required this.alCambiarVista});
  final ControladorAdmin controlador;
  final _Vista vista;
  final ValueChanged<_Vista> alCambiarVista;

  @override
  Widget build(BuildContext context) {
    final c = controlador;
    return Column(
      children: [
        const SizedBox(height: 4),
        SegmentosZ<_Vista>(
          valores: _Vista.values,
          actual: vista,
          nombre: (v) => v == _Vista.bandeja ? 'Bandeja' : 'Resumen',
          cuenta: (v) => v == _Vista.bandeja ? c.conteos[FiltroBandeja.pendientes] : null,
          alCambiar: alCambiarVista,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: vista == _Vista.bandeja ? BandejaAdmin(controlador: c) : ResumenAdmin(controlador: c),
        ),
      ],
    );
  }
}
