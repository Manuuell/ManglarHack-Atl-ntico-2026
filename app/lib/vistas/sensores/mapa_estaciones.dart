import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../datos/sensores/lecturas_sensor.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import 'pantalla_sensores.dart' show colorEstado, iconoEstado;

/// Mapa chico de las estaciones, con la misma receta que `mis_reportes/mapa_detalle.dart`:
/// mosaicos de OpenStreetMap, solo pellizco (un dedo sigue desplazando la lista) y, sin señal,
/// los puntos se dibujan igual sobre el fondo de ciénaga. Cada punto lleva el color de riesgo y
/// abre el detalle de su estación.
class MapaEstaciones extends StatelessWidget {
  const MapaEstaciones({super.key, required this.estaciones, required this.ahora, required this.alTocar, this.alto = 210});

  final List<Estacion> estaciones;
  final DateTime ahora;
  final ValueChanged<Estacion> alTocar;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final con = [for (final e in estaciones) if (e.punto != null) e];
    if (con.isEmpty) return const SizedBox.shrink();
    final puntos = [for (final e in con) LatLng(e.punto!.$1, e.punto!.$2)];
    return ClipRRect(
      borderRadius: BorderRadius.circular(Zr.l),
      child: Container(
        height: alto,
        decoration: BoxDecoration(border: Border.all(color: Zc.linea), borderRadius: BorderRadius.circular(Zr.l)),
        child: Semantics(
          label: 'Mapa de ${con.length} estaciones de sensores. Las estaciones también están en la lista de abajo.',
          child: FlutterMap(
            options: MapOptions(
              backgroundColor: Zc.cienagaClara,
              initialCenter: puntos.first,
              initialZoom: 10,
              initialCameraFit: puntos.length < 2
                  ? null
                  : CameraFit.coordinates(coordinates: puntos, padding: const EdgeInsets.all(40), maxZoom: 13),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.pinchMove,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'co.zanky.app',
              ),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < con.length; i++)
                    Marker(
                      point: puntos[i],
                      width: 48,
                      height: 48,
                      child: _Punto(estacion: con[i], ahora: ahora, alTocar: () => alTocar(con[i])),
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

class _Punto extends StatelessWidget {
  const _Punto({required this.estacion, required this.ahora, required this.alTocar});
  final Estacion estacion;
  final DateTime ahora;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final estado = estacion.estado(ahora);
    final c = colorEstado(estado, estacion.riesgo(ahora));
    return Presionable(
      escala: 0.88,
      etiqueta: 'Estación ${estacion.zonaNombre}',
      onTap: alTocar,
      child: Center(
        child: Container(
          key: ValueKey('punto-${estacion.zonaId}'),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: Zc.superficie, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x330B2E24), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Icon(estado == EstadoLectura.alerta ? iconoEstado(estado) : Icons.sensors_rounded, size: 16, color: Zc.superficie),
        ),
      ),
    );
  }
}
