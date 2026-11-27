import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../datos/estado.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';
import '../raiz.dart';
import '../reporte/flujo_reporte.dart';
import 'piezas.dart';

/// Reportar / Mapa / Mi tarjeta, a un toque desde el evento.
class AtajosEvento extends StatelessWidget {
  const AtajosEvento({super.key, this.punto, this.zonaId});

  /// Ubicación del evento o del punto escaneado: el reporte empieza ya puesto ahí.
  final LatLng? punto;
  final String? zonaId;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Atajo(
              icono: Icons.add_a_photo_rounded,
              texto: punto == null ? 'Reportar' : 'Reportar aquí',
              color: Zc.prioridad[4]!,
              onTap: () => _ir(context, _Destino.reportar, punto: punto, zonaId: zonaId),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Atajo(
              icono: Icons.map_rounded,
              texto: 'Mapa',
              color: Zc.cienaga,
              onTap: () => _ir(context, _Destino.mapa),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Atajo(
              icono: Icons.badge_rounded,
              texto: 'Mi tarjeta',
              color: Zc.hoja,
              onTap: () => _ir(context, _Destino.tarjeta),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Destino { reportar, mapa, tarjeta }

bool _hayPerfil(BuildContext context) =>
    Zanky.leer(context).perfil?.consentimiento != null;

void _ir(BuildContext context, _Destino d, {LatLng? punto, String? zonaId}) {
  if (!_hayPerfil(context)) {
    explicarSinPerfil(
      context,
      d == _Destino.tarjeta ? 'tu tarjeta de guardián' : 'esto',
    );
    return;
  }
  switch (d) {
    case _Destino.reportar:
      abrirReporte(context, punto: punto, zonaId: zonaId);
    case _Destino.mapa:
      Navigator.of(context).popUntil((r) => r.isFirst);
      Raiz.irA(context, 1);
    case _Destino.tarjeta:
      Navigator.of(context).popUntil((r) => r.isFirst);
      Raiz.irA(context, 3);
  }
}

/// Sin perfil con consentimiento la app aún está en la Bienvenida: se explica y se vuelve a ella.
Future<void> explicarSinPerfil(BuildContext context, String paraQue) {
  return mostrarHojaZ<void>(
    context,
    nombre: 'evento_sin_perfil',
    contenido: (c) {
      final tt = Theme.of(c).textTheme;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: ZankyMascota(tamano: 96, animo: Animo.curioso)),
          const SizedBox(height: 12),
          Text(
            'Primero crea tu perfil',
            textAlign: TextAlign.center,
            style: tt.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Para usar $paraQue Zanky necesita tu perfil de guardián, que se guarda solo en tu teléfono. '
            'Toma un minuto en la bienvenida; después vuelves aquí cuando quieras.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium,
          ),
          const SizedBox(height: 18),
          BotonEstado(
            texto: 'Crear mi perfil',
            icono: Icons.arrow_forward_rounded,
            onTap: () {
              Navigator.of(c).pop();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
          const SizedBox(height: 10),
          BotonEstado(
            texto: 'Ahora no',
            secundario: true,
            color: Zc.textoSuave,
            onTap: () => Navigator.of(c).pop(),
          ),
        ],
      );
    },
  );
}

class _Atajo extends StatelessWidget {
  const _Atajo({
    required this.icono,
    required this.texto,
    required this.color,
    required this.onTap,
  });
  final IconData icono;
  final String texto;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Presionable(
      onTap: onTap,
      etiqueta: texto,
      escala: 0.95,
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: Zc.superficie,
          borderRadius: BorderRadius.circular(Zr.m),
          border: Border.all(color: Zc.linea.withValues(alpha: 0.8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: color, size: 26),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                texto,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
