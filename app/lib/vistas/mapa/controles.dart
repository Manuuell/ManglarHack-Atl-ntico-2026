import 'dart:ui';

import 'package:flutter/material.dart';

import '../../datos/prioridad.dart';
import '../../datos/zonas.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';
import 'capa_prioridad.dart';
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('CAPAS DE LA CRA', style: tt.seccion.copyWith(color: Cra.azul)),
                    ),
                    const _Capa(color: Cra.manglarProbable, texto: 'Manglar probable'),
                    for (final p in PrioridadCRA.values)
                      _Capa(color: colorPrioridadCra(p), texto: 'Zona de prioridad ${p.nombre.toLowerCase()}'),
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

/// Muestra de una capa de la CRA en la leyenda: cuadro con su color y su nombre.
class _Capa extends StatelessWidget {
  const _Capa({required this.color, required this.texto});
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 14,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color, width: 1.4),
              ),
            ),
            const SizedBox(width: 10),
            Text(texto, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Zc.texto)),
          ],
        ),
      );
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

/// Control segmentado «Manglar | Prioridad CRA» y, con la prioridad activa, su leyenda compacta
/// (Alta / Media / Baja) en la misma pieza de vidrio: no tapa más mapa que una píldora.
class SelectorCapa extends StatelessWidget {
  const SelectorCapa({
    super.key,
    required this.capa,
    required this.alElegir,
    this.cargando = false,
    this.fallo = false,
    this.alReintentar,
  });

  final CapaMapa capa;
  final ValueChanged<CapaMapa> alElegir;

  /// Se está leyendo la capa de prioridades de los assets.
  final bool cargando;

  /// La lectura falló (no debería: el archivo viene dentro de la app).
  final bool fallo;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final verPrioridad = capa == CapaMapa.prioridad;
    return Vidrio(
      radio: 22,
      relleno: const EdgeInsets.all(4),
      child: AnimatedSize(
        duration: context.resolveDuration(Zm.medio),
        curve: Zm.entrar,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              label: 'Capa del mapa',
              child: Row(
                children: [
                  for (final c in CapaMapa.values)
                    Expanded(
                      child: _Segmento(
                        texto: c.nombre,
                        icono: c == CapaMapa.manglar ? Icons.eco_rounded : Icons.layers_rounded,
                        elegido: capa == c,
                        ocupado: c == CapaMapa.prioridad && cargando && capa == c,
                        alTocar: () => alElegir(c),
                      ),
                    ),
                ],
              ),
            ),
            if (verPrioridad)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: fallo
                    ? Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 18, color: Zc.fango),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No pude leer la capa de prioridades.',
                              style: tt.bodySmall?.copyWith(color: Zc.texto),
                            ),
                          ),
                          if (alReintentar != null)
                            Presionable(
                              etiqueta: 'Reintentar la capa de prioridades',
                              onTap: alReintentar,
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('Reintentar', style: tt.labelMedium?.copyWith(color: Zc.hoja)),
                              ),
                            ),
                        ],
                      )
                    : Semantics(
                        container: true,
                        label: 'Leyenda de la prioridad de conservación de la CRA: '
                            'alta, media y baja. Toca una zona del mapa para ver su acción y escenario.',
                        excludeSemantics: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 14,
                              runSpacing: 4,
                              children: [
                                for (final p in PrioridadCRA.values) _MuestraPrioridad(p),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Toca una zona para ver su acción y escenario',
                              style: tt.bodySmall?.copyWith(color: Zc.textoSuave),
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

class _Segmento extends StatelessWidget {
  const _Segmento({
    required this.texto,
    required this.icono,
    required this.elegido,
    required this.alTocar,
    this.ocupado = false,
  });

  final String texto;
  final IconData icono;
  final bool elegido;
  final bool ocupado;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final tinta = elegido ? Colors.white : Zc.raiz;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: elegido,
      child: Presionable(
        etiqueta: elegido ? '$texto, capa activa' : 'Ver la capa $texto',
        onTap: elegido ? null : alTocar,
        child: AnimatedContainer(
          duration: context.resolveDuration(Zm.corto),
          curve: Zm.entrar,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: elegido ? Zc.hoja : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ocupado)
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: tinta),
                )
              else
                Icon(icono, size: 17, color: tinta),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tinta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MuestraPrioridad extends StatelessWidget {
  const _MuestraPrioridad(this.p);
  final PrioridadCRA p;

  @override
  Widget build(BuildContext context) {
    final color = colorPrioridadCra(p);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Color.lerp(color, Zc.raiz, 0.35)!, width: p == PrioridadCRA.alta ? 2 : 1.2),
          ),
        ),
        const SizedBox(width: 6),
        Text(p.nombre, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Zc.texto)),
      ],
    );
  }
}

/// Estado vacío honesto: nada inventado, con Zanky y la siguiente acción.
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
          const ZankyMascota(tamano: 64, animo: Animo.curioso),
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
