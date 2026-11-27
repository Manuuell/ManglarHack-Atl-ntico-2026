import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../nucleo/web/puente_pwa.dart' as puente;

/// Estado pequeño y comprobable del aviso sobre la pantalla.
class EstadoAvisos {
  const EstadoAvisos({this.versionNueva = false, this.conexion = ''});
  final bool versionNueva;
  final String conexion;
}

class AvisosWeb extends StatefulWidget {
  const AvisosWeb({super.key, this.estado, this.alActualizar});

  final ValueListenable<EstadoAvisos>? estado;
  final VoidCallback? alActualizar;

  @override
  State<AvisosWeb> createState() => _AvisosWebState();
}

class _AvisosWebState extends State<AvisosWeb> {
  late final ValueNotifier<EstadoAvisos> _propio = ValueNotifier(
    const EstadoAvisos(),
  );
  Timer? _sondeo;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && widget.estado == null) {
      _leer();
      _sondeo = Timer.periodic(const Duration(seconds: 2), (_) => _leer());
    }
  }

  void _leer() {
    _propio.value = EstadoAvisos(
      versionNueva: puente.hayVersionNueva(),
      conexion: puente.estadoConexion(),
    );
  }

  @override
  void dispose() {
    _sondeo?.cancel();
    _propio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<EstadoAvisos>(
    valueListenable: widget.estado ?? _propio,
    builder: (context, estado, _) {
      if (!estado.versionNueva && estado.conexion.isEmpty) {
        return const SizedBox.shrink();
      }
      return Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Material(
              color: const Color(0xFF123C38),
              borderRadius: BorderRadius.circular(14),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      estado.versionNueva
                          ? Icons.system_update_rounded
                          : estado.conexion == 'Reconectado'
                          ? Icons.wifi_rounded
                          : Icons.wifi_off_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        estado.versionNueva
                            ? 'Hay una versión nueva'
                            : estado.conexion,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (estado.versionNueva)
                      TextButton(
                        onPressed:
                            widget.alActualizar ?? puente.actualizarVersion,
                        child: const Text(
                          'Actualizar',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
