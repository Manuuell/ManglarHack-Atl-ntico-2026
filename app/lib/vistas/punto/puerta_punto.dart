import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../datos/estado.dart';
import '../../datos/punto/punto_zanky.dart';
import '../../datos/punto/servicio_punto.dart';
import 'pantalla_punto.dart';

/// Abre el QR del punto después de la carga inicial, respetando /app/ y la consulta del fragmento.
class PuertaPunto extends StatefulWidget {
  const PuertaPunto({super.key, required this.child, this.leerEnlace = kIsWeb});
  final Widget child;
  final bool leerEnlace;
  @override
  State<PuertaPunto> createState() => _PuertaPuntoState();
}

class _PuertaPuntoState extends State<PuertaPunto> {
  bool _abierto = false;
  final _servicio = ServicioPunto();
  StreamSubscription<List<ConnectivityResult>>? _conexion;
  Timer? _reintento;

  @override
  void initState() {
    super.initState();
    unawaited(_servicio.sincronizar());
    _conexion = Connectivity().onConnectivityChanged.listen((redes) {
      if (redes.any((r) => r != ConnectivityResult.none)) {
        unawaited(_servicio.sincronizar());
      }
    });
    _reintento = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_servicio.sincronizar());
    });
  }

  @override
  void dispose() {
    _conexion?.cancel();
    _reintento?.cancel();
    super.dispose();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Zanky.de(context);
    if (!widget.leerEnlace || _abierto || !Zanky.leer(context).listo) return;
    final codigo = leerCodigoPunto(Uri.base);
    if (codigo == null) return;
    _abierto = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) abrirPunto(context, codigo);
    });
  }
  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> abrirPunto(BuildContext context, String codigo) async {
  final valido = codigoPuntoValido(codigo);
  if (valido == null) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'punto'),
    builder: (_) => PantallaPunto(codigo: valido),
  ));
}
