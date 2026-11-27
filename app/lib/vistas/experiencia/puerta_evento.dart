import '../../nucleo/kit/ruta_borde.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../datos/estado.dart';
import '../../datos/experiencia/entrada_evento.dart';
import 'pantalla_evento.dart';
import 'avisos_web.dart';

/// Abre el modo evento (una vez por código) cuando la app ya está lista.
/// Envuelve el `home` de la app. En la web lee el enlace al arrancar; en el teléfono solo reacciona a
/// [entradaEvento] (que llena el escáner con [abrirEvento]).
class PuertaEvento extends StatefulWidget {
  const PuertaEvento({
    super.key,
    required this.child,
    this.leerEnlace = kIsWeb,
  });
  final Widget child;

  /// Si lee `Uri.base` al arrancar. Solo tiene sentido en la web.
  final bool leerEnlace;

  /// Códigos ya abiertos en esta ejecución: recargar la pantalla de la app no vuelve a abrirlos.
  static final Set<String> _abiertos = {};

  @visibleForTesting
  static void olvidarAbiertos() => _abiertos.clear();

  @override
  State<PuertaEvento> createState() => _PuertaEventoState();
}

class _PuertaEventoState extends State<PuertaEvento> {
  @override
  void initState() {
    super.initState();
    if (widget.leerEnlace) registrarEntradaEvento();
    entradaEvento.addListener(_revisar);
  }

  @override
  void dispose() {
    entradaEvento.removeListener(_revisar);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Zanky.de(context); // se vuelve a revisar cuando la app esté lista
    _revisar();
  }

  void _revisar() {
    if (!mounted) return;
    final e = entradaEvento.value;
    if (e == null || PuertaEvento._abiertos.contains(e.codigo)) return;
    if (!Zanky.leer(context).listo) return;
    PuertaEvento._abiertos.add(e.codigo);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        abrirEvento(context, e.codigo, asistencia: e.accionAsistencia);
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      Stack(fit: StackFit.expand, children: [widget.child, const AvisosWeb()]);
}

/// Abre el modo evento de un código (lo usa el escáner y la puerta).
Future<void> abrirEvento(
  BuildContext context,
  String codigo, {
  bool asistencia = false,
}) {
  final c = codigoEventoValido(codigo);
  if (c == null) return Future.value();
  PuertaEvento._abiertos.add(c);
  return Navigator.of(context).push(
    RutaBorde<void>(
      sinMovimiento: MediaQuery.disableAnimationsOf(context),
      settings: const RouteSettings(name: 'evento'),
      builder: (_) =>
          PantallaEvento(codigo: c, abrirAsistenciaAlEntrar: asistencia),
    ),
  );
}
