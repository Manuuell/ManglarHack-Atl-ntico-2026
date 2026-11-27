import 'dart:ui';

import 'package:flutter/material.dart';

import '../../datos/prioridad.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/zanqui_mascota.dart';
import 'marcadores.dart';

/// Superficie de vidrio, igual que la barra de pestañas: se ve el mapa detrás.
class Vidrio extends StatelessWidget {
  const Vidrio({super.key, required this.child, this.radio = 22, this.relleno = EdgeInsets.zero});
  final Widget child;
  final double radio;
  final EdgeInsets relleno;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(radio);
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: forma,
                boxShadow: const [BoxShadow(color: Color(0x1F0B2E24), blurRadius: 18, offset: Offset(0, 6))],
              ),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: forma,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: relleno,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: forma,
                border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              ),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

/// Botón redondo de vidrio (48 px) con un puntito opcional de «hay algo activo».
class BotonRedondo extends StatelessWidget {
  const BotonRedondo({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.onTap,
    this.punto = false,
    this.ocupado = false,
    this.color = Zc.raiz,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback? onTap;
  final bool punto;
  final bool ocupado;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Presionable(
      escala: 0.9,
      etiqueta: etiqueta,
      onTap: onTap,
      child: SizedBox.square(
        dimension: 52,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Vidrio(
                radio: 26,
                child: Center(
                  child: ocupado
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.6, color: Zc.hoja),
                        )
                      : Icon(icono, color: color, size: 25),
                ),
              ),
            ),
            if (punto)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: Zc.sol,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Chip de zona: nombre corto, 44 px de alto como mínimo, al sol se lee.
class ChipZona extends StatelessWidget {
  const ChipZona({
    super.key,
    required this.texto,
    required this.seleccionado,
    required this.onTap,
    this.icono = Icons.eco_rounded,
    this.etiqueta,
  });

  final String? etiqueta;
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final tinta = seleccionado ? Colors.white : Zc.raiz;
    return Presionable(
      etiqueta: seleccionado ? '${etiqueta ?? texto}, elegida' : 'Ir a ${etiqueta ?? texto}',
      onTap: onTap,
      child: AnimatedContainer(
        duration: context.resolveDuration(Zm.corto),
        curve: Zm.entrar,
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: seleccionado ? Zc.hoja : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: seleccionado ? Zc.hoja : Colors.white),
          boxShadow: const [BoxShadow(color: Color(0x240B2E24), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 18, color: seleccionado ? Colors.white : Zc.hoja),
            const SizedBox(width: 7),
            Text(texto, maxLines: 1, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tinta)),
          ],
        ),
      ),
    );
  }
}

/// Aviso corto sobre el mapa (sin señal, permiso negado…), con una acción opcional.
class PildoraAviso extends StatelessWidget {
  const PildoraAviso({
    super.key,
    required this.texto,
    required this.icono,
    this.color = Zc.fango,
    this.accion,
    this.alAccion,
    this.alCerrar,
  });

  final String texto;
  final IconData icono;
  final Color color;
  final String? accion;
  final VoidCallback? alAccion;
  final VoidCallback? alCerrar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      label: texto,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(Zr.m),
          border: Border.all(color: color.withValues(alpha: 0.45)),
          boxShadow: const [BoxShadow(color: Color(0x240B2E24), blurRadius: 14, offset: Offset(0, 5))],
        ),
        child: Row(
          children: [
            Icon(icono, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(texto, style: tt.bodySmall?.copyWith(color: Zc.texto))),
            if (accion != null && alAccion != null)
              Presionable(
                onTap: alAccion,
                etiqueta: accion,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(accion!, style: tt.labelMedium?.copyWith(color: Zc.hoja)),
                ),
              ),
            if (alCerrar != null)
              Presionable(
                onTap: alCerrar,
                etiqueta: 'Cerrar aviso',
                child: const SizedBox.square(
                  dimension: 44,
                  child: Icon(Icons.close_rounded, size: 20, color: Zc.textoSuave),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Leyenda de prioridad 1-5 y de cómo se leen los marcadores. Plegada ocupa lo de una píldora.
class LeyendaMapa extends StatefulWidget {
  const LeyendaMapa({super.key});

  @override
  State<LeyendaMapa> createState() => _LeyendaMapaState();
}

class _LeyendaMapaState extends State<LeyendaMapa> {
  bool _abierta = false;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Vidrio(
      radio: 20,
      child: AnimatedSize(
        duration: context.resolveDuration(Zm.medio),
        curve: Zm.entrar,
        alignment: Alignment.bottomLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_abierta)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var p = 5; p >= 1; p--)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: Zc.dePrioridad(p), shape: BoxShape.circle),
                              child: Text(
                                '$p',
                                style: tt.labelSmall?.copyWith(color: tintaSobre(Zc.dePrioridad(p)), height: 1),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(Prioridad.nombres[p]!, style: tt.labelMedium?.copyWith(color: Zc.texto)),
                          ],
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: SizedBox(width: 168, child: Divider(height: 1, color: Zc.linea)),
                    ),
                    _Clave(
                      muestra: DiscoPainter(color: Zc.dePrioridad(3), mio: true),
                      texto: 'Borde blanco grueso: tuyo',
                    ),
                    _Clave(
                      muestra: DiscoPainter(color: Zc.dePrioridad(3), mio: true, enCola: true),
                      texto: 'Borde punteado: aún no enviado',
                    ),
                    const _Clave(muestra: null, texto: 'Late: pasó hace menos de 3 h'),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            Presionable(
              etiqueta: _abierta ? 'Cerrar la leyenda de prioridad' : 'Abrir la leyenda de prioridad',
              onTap: () => setState(() => _abierta = !_abierta),
              child: Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.layers_rounded, size: 19, color: Zc.hoja),
                    const SizedBox(width: 8),
                    Text('Prioridad', style: tt.labelMedium?.copyWith(color: Zc.raiz)),
                    const SizedBox(width: 6),
                    Icon(
                      _abierta ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                      size: 20,
                      color: Zc.textoSuave,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Clave extends StatelessWidget {
  const _Clave({required this.muestra, required this.texto});
  final DiscoPainter? muestra;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 22,
              child: muestra == null
                  ? const Icon(Icons.radio_button_checked_rounded, size: 20, color: Zc.hoja)
                  : CustomPaint(painter: muestra),
            ),
            const SizedBox(width: 10),
            Text(texto, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Zc.texto)),
          ],
        ),
      );
}

/// Estado vacío honesto: nada inventado, con Zanqui y la siguiente acción.
class TarjetaVaciaMapa extends StatelessWidget {
  const TarjetaVaciaMapa({
    super.key,
    required this.titulo,
    required this.boton,
    required this.onBoton,
    this.icono = Icons.add_a_photo_rounded,
  });

  final String titulo;
  final String boton;
  final VoidCallback onBoton;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Vidrio(
      radio: Zr.l,
      relleno: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      child: Row(
        children: [
          const ZanquiMascota(tamano: 64, animo: Animo.curioso),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(titulo, style: tt.titleSmall?.copyWith(color: Zc.texto)),
                const SizedBox(height: 8),
                Presionable(
                  etiqueta: boton,
                  onTap: onBoton,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Zc.hoja, borderRadius: BorderRadius.circular(Zr.s)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icono, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            boton,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelMedium?.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «© OpenStreetMap»: obligatoria con las teselas de OSM.
class AtribucionOsm extends StatelessWidget {
  const AtribucionOsm({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '© OpenStreetMap',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Zc.texto, letterSpacing: 0),
        ),
      );
}

/// «Ciénaga de Mallorquín» → «Mallorquín»: cabe en el chip sin cortarse.
String nombreCorto(String n) {
  for (final p in const ['Ciénaga de ', 'Ciénaga del ', 'Costa de ']) {
    if (n.startsWith(p)) return n.substring(p.length);
  }
  return n;
}
