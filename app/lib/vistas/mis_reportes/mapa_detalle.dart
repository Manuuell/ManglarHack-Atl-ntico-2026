import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../datos/reporte.dart';
import '../../datos/zonas.dart';
import '../../nucleo/tema.dart';

/// Mapa chico del reporte: el punto, el círculo de precisión del GPS y el polígono
/// de la zona de manglar. Solo se mueve con pellizco: un dedo sigue desplazando la
/// pantalla. Sin señal no hay mosaicos, pero el punto y el polígono se dibujan igual.
class MapaDetalle extends StatelessWidget {
  const MapaDetalle({super.key, required this.reporte, this.zona});
  final Reporte reporte;
  final ZonaManglar? zona;

  /// El vértice del polígono más cercano al punto: sirve para encuadrar a ambos
  /// cuando el reporte quedó fuera del manglar.
  LatLng? _verticeCercano() {
    final z = zona;
    if (z == null) return null;
    const d = Distance();
    LatLng? mejor;
    var menor = double.infinity;
    for (final anillo in z.poligonos) {
      for (final v in anillo) {
        final m = d.as(LengthUnit.Meter, reporte.punto, v);
        if (m < menor) {
          menor = m;
          mejor = v;
        }
      }
    }
    return mejor;
  }

  @override
  Widget build(BuildContext context) {
    final r = reporte;
    final cerca = !r.dentroPoligono ? _verticeCercano() : null;
    final tipo = r.tipo;
    final precision = r.precisionM;
    return SizedBox(
      height: 180,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              backgroundColor: Zc.cienagaClara,
              initialCenter: r.punto,
              initialZoom: 16,
              initialCameraFit: cerca == null
                  ? null
                  : CameraFit.coordinates(
                      coordinates: [r.punto, cerca],
                      padding: const EdgeInsets.all(36),
                      maxZoom: 17,
                    ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.pinchMove,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'co.zanqui.zanqui',
              ),
              if (zona != null)
                PolygonLayer(
                  polygons: [
                    for (final anillo in zona!.poligonos)
                      Polygon(
                        points: anillo,
                        color: Zc.hoja.withValues(alpha: 0.28),
                        borderColor: Zc.hoja,
                        borderStrokeWidth: 2,
                      ),
                  ],
                ),
              if (precision != null && precision > 0)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: r.punto,
                      radius: precision,
                      useRadiusInMeter: true,
                      color: tipo.color.withValues(alpha: 0.16),
                      borderColor: tipo.color.withValues(alpha: 0.6),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: r.punto,
                    width: 38,
                    height: 38,
                    child: Container(
                      decoration: BoxDecoration(
                        color: tipo.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Zc.superficie, width: 3),
                        boxShadow: const [BoxShadow(color: Color(0x330B2E24), blurRadius: 8, offset: Offset(0, 3))],
                      ),
                      child: Icon(tipo.icono, size: 18, color: Zc.superficie),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 6,
            bottom: 4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Zc.superficie.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('© OpenStreetMap', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
