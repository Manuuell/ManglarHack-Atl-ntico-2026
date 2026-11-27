import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../datos/cra/modelos_cra.dart';
import '../../datos/cra/servicio_visores.dart';
import '../../datos/sensores/lecturas_sensor.dart' show haceCuanto, horaColombia;
import '../../nucleo/identidad.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';

/// Un punto del mapa de un visor: color, icono y qué hacer al tocarlo.
class PuntoMapa {
  const PuntoMapa({
    required this.clave,
    required this.lat,
    required this.lon,
    required this.color,
    required this.etiqueta,
    this.icono,
    this.alTocar,
  });
  final String clave;
  final double lat;
  final double lon;
  final Color color;
  final String etiqueta;
  final IconData? icono;
  final VoidCallback? alTocar;
}

/// Mapa de un visor, con la receta de `sensores/mapa_estaciones.dart`: mosaicos de OpenStreetMap,
/// solo pellizco (un dedo sigue desplazando la lista) y, sin señal, los puntos se dibujan igual
/// sobre el fondo de ciénaga. Encuadra la franja del manglar.
class MapaVisor extends StatelessWidget {
  const MapaVisor({super.key, required this.puntos, required this.descripcion, this.poligonos = const [], this.alto = 230});
  final List<PuntoMapa> puntos;
  final List<Polygon> poligonos;
  final String descripcion;
  final double alto;

  /// Encuadre de la franja costera del manglar (Bocas de Ceniza a El Totumo).
  static final franja = LatLngBounds(const LatLng(10.70, -75.28), const LatLng(11.10, -74.80));

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Zr.l),
      child: Container(
        height: alto,
        decoration: BoxDecoration(
          border: Border.all(color: Zc.linea),
          borderRadius: BorderRadius.circular(Zr.l),
        ),
        child: Semantics(
          label: '$descripcion La misma información está en la lista de abajo.',
          child: FlutterMap(
            options: MapOptions(
              backgroundColor: Zc.cienagaClara,
              initialCameraFit: CameraFit.bounds(bounds: franja, padding: const EdgeInsets.all(12)),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.pinchMove),
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'co.zanky.app'),
              if (poligonos.isNotEmpty) PolygonLayer(polygons: poligonos),
              MarkerLayer(
                markers: [
                  for (final p in puntos)
                    Marker(
                      point: LatLng(p.lat, p.lon),
                      width: 40,
                      height: 40,
                      child: _Marca(punto: p),
                    ),
                ],
              ),
              const Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('© OpenStreetMap', style: TextStyle(fontSize: 10, color: Zc.textoSuave)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca({required this.punto});
  final PuntoMapa punto;

  @override
  Widget build(BuildContext context) {
    final disco = Container(
      key: ValueKey('marca-${punto.clave}'),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: punto.color,
        shape: BoxShape.circle,
        border: Border.all(color: Zc.superficie, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x330B2E24), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: punto.icono == null ? null : Icon(punto.icono, size: 12, color: Zc.superficie),
    );
    if (punto.alTocar == null) return Center(child: disco);
    return Presionable(
      escala: 0.85,
      etiqueta: punto.etiqueta,
      onTap: punto.alTocar,
      child: Center(child: disco),
    );
  }
}

/// La franja que dice de dónde salen los datos y a qué hora: en vivo, copia sin señal o error.
class OrigenVisorBanda extends StatelessWidget {
  const OrigenVisorBanda({super.key, required this.origen, required this.leido, required this.fuente, required this.ahora});
  final OrigenVisor origen;
  final DateTime? leido;
  final String fuente;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final (IconData icono, Color color, String titulo) = switch (origen) {
      OrigenVisor.enVivo => (Icons.verified_rounded, Zc.hoja, 'Datos oficiales · leídos a las ${horaColombia(leido!)}'),
      OrigenVisor.copia => (
        Icons.cloud_off_rounded,
        Zc.fango,
        'Sin señal: copia de las ${horaColombia(leido!)} (${haceCuanto(leido, ahora)})',
      ),
      OrigenVisor.sinDatos => (Icons.wifi_off_rounded, Zc.dePrioridad(5), 'No pude leer la fuente'),
    };
    final texto = 'Fuente: $fuente.';
    return Semantics(
      container: true,
      label: '$titulo. $texto',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(Zr.m),
            border: Border.all(color: color.withValues(alpha: 0.40)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: tt.titleSmall),
                    const SizedBox(height: 2),
                    Text(texto, style: tt.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip de filtro con el color oficial del tipo (punto de color + nombre + cuántos hay).
class ChipTipo extends StatelessWidget {
  const ChipTipo({
    super.key,
    required this.texto,
    required this.color,
    required this.cuenta,
    required this.activo,
    required this.alTocar,
  });
  final String texto;
  final Color color;
  final int cuenta;
  final bool activo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      selected: activo,
      button: true,
      label: '$texto, $cuenta',
      child: ExcludeSemantics(
        child: Presionable(
          escala: 0.94,
          onTap: alTocar,
          child: AnimatedContainer(
            duration: Zm.corto,
            curve: Zm.entrar,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: activo ? color.withValues(alpha: 0.16) : Zc.superficie,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: activo ? color : Zc.linea, width: activo ? 1.5 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(texto, style: tt.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                Text('$cuenta', style: tt.labelMedium?.copyWith(color: Zc.textoSuave)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Número que cuenta al aparecer (salta directo con «reducir movimiento»).
class NumeroQueCuenta extends StatelessWidget {
  const NumeroQueCuenta({super.key, required this.valor, required this.formato, this.estilo});
  final double valor;
  final String Function(double v) formato;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    final sinMovimiento = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: formato(valor),
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: sinMovimiento ? valor : 0, end: valor),
          duration: sinMovimiento ? Duration.zero : const Duration(milliseconds: 900),
          curve: Zm.entrar,
          builder: (_, v, _) => Text(formato(v), style: estilo),
        ),
      ),
    );
  }
}

/// Tarjeta blanca de la casa.
class TarjetaVisor extends StatelessWidget {
  const TarjetaVisor({super.key, required this.child, this.borde, this.relleno = const EdgeInsets.all(14)});
  final Widget child;
  final Color? borde;
  final EdgeInsets relleno;

  @override
  Widget build(BuildContext context) => Container(
    padding: relleno,
    decoration: BoxDecoration(
      color: Zc.superficie,
      borderRadius: BorderRadius.circular(Zr.l),
      border: Border.all(color: borde ?? Zc.linea, width: borde == null ? 1 : 1.5),
    ),
    child: child,
  );
}

/// Sello «Datos oficiales C.R.A.» (coidentidad: azul y dorado de la Corporación).
class SelloCra extends StatelessWidget {
  const SelloCra({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Cra.azul, borderRadius: BorderRadius.circular(999)),
    child: const Text(
      'C.R.A.',
      style: TextStyle(color: Cra.dorado, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6),
    ),
  );
}

Color colorSemaforo(Semaforo s) => switch (s) {
  Semaforo.bien => const Color(0xFF16A34A),
  Semaforo.ojo => const Color(0xFFEAB308),
  Semaforo.mal => const Color(0xFFDC2626),
  Semaforo.sinDato => colorSinDato,
};

String textoSemaforo(Semaforo s) => switch (s) {
  Semaforo.bien => 'bien',
  Semaforo.ojo => 'ojo',
  Semaforo.mal => 'mal',
  Semaforo.sinDato => 'sin dato',
};
