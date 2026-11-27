import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../datos/avisos_ciudadano.dart';
import '../../datos/estado.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/kit/anuncio.dart';
import '../../nucleo/kit/haptica.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../admin/panel_cra.dart';
import '../admin/piezas_admin.dart';

/// Los avisos que caen desde arriba, sobre cualquier pestaña:
///
/// - **Para el ciudadano**: cuando su reporte cambió de estado (aprobado, rechazado, piden
///   más datos) desde la última vez que lo vio, al volver a abrir la app. Una sola vez.
/// - **Para el equipo de la CRA** (con la sesión del panel iniciada): cuando entra un
///   reporte nuevo. El mismo aviso sube el contador del ícono del panel.
///
/// Solo se ve uno a la vez; el del equipo tiene prioridad. Ninguno bloquea la pantalla.
class CapaAvisos extends StatefulWidget {
  const CapaAvisos({super.key, required this.child, required this.verMisReportes});
  final Widget child;

  /// Lleva a «Mis reportes» (la raíz sabe cambiar de pestaña).
  final VoidCallback verMisReportes;

  @override
  State<CapaAvisos> createState() => _CapaAvisosState();
}

class _CapaAvisosState extends State<CapaAvisos> {
  List<CambioDeReporte>? _cambios;
  bool _evaluando = false;
  Timer? _ocultar;
  int _versionAdminVista = 0;
  bool _adminOculto = false;
  Timer? _ocultarAdmin;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cada vez que EstadoZanky avisa (llegaron estados del servidor) se mira si hay cambios.
    final e = Zanky.de(context);
    if (e.listo) unawaited(_evaluar(e));
    final a = AdminScope.maybeDe(context)?.aviso;
    if (a != null && a.version != _versionAdminVista) {
      _versionAdminVista = a.version;
      _adminOculto = false;
      _ocultarAdmin?.cancel();
      _ocultarAdmin = Timer(const Duration(seconds: 9), () {
        if (mounted) setState(() => _adminOculto = true);
      });
      vibrarAviso();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) anunciar(context, '${a.titulo}. ${a.cuerpo}');
      });
    }
  }

  @override
  void dispose() {
    _ocultar?.cancel();
    _ocultarAdmin?.cancel();
    super.dispose();
  }

  Future<void> _evaluar(EstadoZanky e) async {
    if (_evaluando) return;
    _evaluando = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString(AvisosCiudadano.clave);
      if (guardado == null) {
        // Primera vez con esta función: lo que ya había se da por visto, sin avisar de todo.
        await prefs.setString(AvisosCiudadano.clave, jsonEncode(AvisosCiudadano.instantanea(e.reportes)));
        return;
      }
      final vistos = (jsonDecode(guardado) as Map).map((k, v) => MapEntry('$k', '$v'));
      final c = AvisosCiudadano.pendientes(e.reportes, vistos);
      if (c.isEmpty) return;
      // Se anota como visto ANTES de mostrarlo: un aviso no se repite aunque se cierre la app.
      await prefs.setString(AvisosCiudadano.clave, jsonEncode({...vistos, ...AvisosCiudadano.instantanea(e.reportes)}));
      if (!mounted) return;
      setState(() => _cambios = c);
      vibrarAviso();
      anunciar(context, '${AvisosCiudadano.titulo(c)}. ${AvisosCiudadano.cuerpo(c)}');
      _ocultar?.cancel();
      _ocultar = Timer(const Duration(seconds: 12), () {
        if (mounted) setState(() => _cambios = null);
      });
    } catch (_) {
      // Un aviso es un extra: si el teléfono no deja guardar, no pasa nada.
    } finally {
      _evaluando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminScope.maybeDe(context);
    final aviso = admin != null && admin.dentro && !_adminOculto ? admin.aviso : null;
    final cambios = _cambios;
    Widget? banner;
    if (aviso != null) {
      banner = _Banner(
        key: ValueKey('admin${aviso.version}'),
        icono: Icons.notification_important_rounded,
        color: Zc.sol,
        titulo: aviso.titulo,
        cuerpo: aviso.cuerpo,
        accion: 'Abrir panel',
        alAccion: () {
          admin.descartarAviso();
          abrirPanelCra(context);
        },
        alCerrar: admin!.descartarAviso,
      );
    } else if (cambios != null && cambios.isNotEmpty) {
      banner = _Banner(
        key: ValueKey('ciudadano${cambios.first.reporte.id}${cambios.length}'),
        icono: cambios.first.ahora.slug == 'descartado' ? Icons.info_outline_rounded : Icons.verified_rounded,
        color: cambios.first.ahora.slug == 'descartado' ? Zc.fango : Zc.hoja,
        titulo: AvisosCiudadano.titulo(cambios),
        cuerpo: AvisosCiudadano.cuerpo(cambios),
        accion: 'Ver',
        alAccion: () {
          setState(() => _cambios = null);
          widget.verMisReportes();
        },
        alCerrar: () => setState(() => _cambios = null),
      );
    }
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: context.resolveDuration(Zm.medio),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (hijo, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, -0.6), end: Offset.zero).animate(anim),
                  child: hijo,
                ),
              ),
              child: banner ?? const SizedBox(key: ValueKey('sin-aviso'), width: double.infinity),
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.cuerpo,
    required this.accion,
    required this.alAccion,
    required this.alCerrar,
  });
  final IconData icono;
  final Color color;
  final String titulo;
  final String cuerpo;
  final String accion;
  final VoidCallback alAccion;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: '$titulo. $cuerpo',
        child: Material(
          color: Zc.raiz,
          elevation: 8,
          shadowColor: const Color(0x660B2E24),
          borderRadius: BorderRadius.circular(Zr.m),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icono, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleSmall?.copyWith(color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(cuerpo, maxLines: 4, overflow: TextOverflow.ellipsis, style: tt.bodySmall?.copyWith(color: Zc.hojaClara)),
                      Presionable(
                        etiqueta: accion,
                        onTap: alAccion,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                          alignment: Alignment.centerLeft,
                          child: Text(accion, style: tt.labelLarge?.copyWith(color: color)),
                        ),
                      ),
                    ],
                  ),
                ),
                Presionable(
                  etiqueta: 'Cerrar aviso',
                  onTap: alCerrar,
                  child: const SizedBox(width: 48, height: 48, child: Icon(Icons.close_rounded, color: Colors.white70, size: 20)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
