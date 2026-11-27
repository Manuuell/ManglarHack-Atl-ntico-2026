import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../datos/enlaces_mapa.dart';
import '../../datos/reporte.dart';
import '../../datos/zonas.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import 'borrador.dart';

/// Paso 2: ¿dónde? El GPS ya venía afinando desde que se abrió el flujo. Se puede
/// corregir tocando el mapa o pegando un enlace de Google Maps. Siempre se ve, en
/// palabras, si el punto cae dentro del manglar y en qué zona.
class PasoUbicacion extends StatefulWidget {
  const PasoUbicacion({super.key, required this.borrador});
  final Borrador borrador;

  @override
  State<PasoUbicacion> createState() => _PasoUbicacionState();
}

class _PasoUbicacionState extends State<PasoUbicacion> {
  final _mapa = MapController();
  bool _mapaListo = false;
  bool _tocadoPorPersona = false;
  LatLng? _ultimoCentrado;

  Borrador get b => widget.borrador;

  /// Los 144 polígonos se arman una sola vez (21 000 vértices: nunca en cada build).
  late final List<Polygon> _poligonos = [
    for (final z in b.estado.manglar.zonas)
      for (final p in z.poligonos)
        Polygon(
          points: p,
          color: Zc.hoja.withValues(alpha: 0.38),
          borderColor: const Color(0xFF1E7A50),
          borderStrokeWidth: 1.2,
        ),
  ];

  @override
  void initState() {
    super.initState();
    b.addListener(_seguirPunto);
  }

  @override
  void dispose() {
    b.removeListener(_seguirPunto);
    _mapa.dispose();
    super.dispose();
  }

  /// La cámara sigue al GPS mientras la persona no haya movido el mapa ella misma.
  void _seguirPunto() {
    final p = b.punto;
    if (p == null || !_mapaListo || _tocadoPorPersona || p == _ultimoCentrado) return;
    _ultimoCentrado = p;
    _mapa.move(p, b.metodo == MetodoUbicacion.gps ? 16 : _mapa.camera.zoom);
  }

  Future<void> _pegarEnlace() async {
    final portapapeles = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (!mounted) return;
    final punto = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HojaEnlace(inicial: portapapeles),
    );
    if (punto == null) return;
    b.desdeEnlace(punto);
    _tocadoPorPersona = false;
    _ultimoCentrado = null;
    _seguirPunto();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: b,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          _mapaDelPunto(),
          const SizedBox(height: 12),
          _Resultado(borrador: b),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BotonChico(
                  icono: Icons.my_location_rounded,
                  texto: b.gpsActivo ? 'Afinando GPS…' : 'Mi ubicación',
                  onTap: () {
                    _tocadoPorPersona = false;
                    _ultimoCentrado = null;
                    if (b.gps == EstadoGps.sinPermiso || b.gps == EstadoGps.apagado) {
                      b.abrirAjustesUbicacion();
                    } else {
                      b.reintentarGps();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BotonChico(icono: Icons.link_rounded, texto: 'Enlace de Maps', onTap: _pegarEnlace),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Si el punto no es exacto, toca el mapa donde está pasando.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _mapaDelPunto() {
    final p = b.punto;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Zr.l),
      child: SizedBox(
        height: 260,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapa,
              options: MapOptions(
                initialCenter: p ?? b.estado.manglar.zonas.first.centro,
                initialZoom: p == null ? 12.5 : 16,
                minZoom: 9,
                maxZoom: 18.5,
                backgroundColor: const Color(0xFFE9E3D6),
                onMapReady: () {
                  _mapaListo = true;
                  _seguirPunto();
                },
                onPositionChanged: (_, gesto) {
                  if (gesto) _tocadoPorPersona = true;
                },
                onTap: (_, punto) {
                  vibrar(Vibracion.seleccion);
                  b.marcarEnMapa(punto);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'co.zanky.app',
                ),
                PolygonLayer(polygons: _poligonos),
                if (p != null && b.precisionM != null)
                  CircleLayer(circles: [
                    CircleMarker(
                      point: p,
                      radius: b.precisionM!,
                      useRadiusInMeter: true,
                      color: Zc.cienaga.withValues(alpha: 0.14),
                      borderColor: Zc.cienaga.withValues(alpha: 0.5),
                      borderStrokeWidth: 1,
                    ),
                  ]),
                if (p != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: p,
                      width: 46,
                      height: 56,
                      alignment: Alignment.topCenter,
                      child: _Pin(color: b.tipo?.color ?? Zc.hoja, icono: b.tipo?.icono),
                    ),
                  ]),
              ],
            ),
            const Positioned(
              right: 8,
              bottom: 6,
              child: _Atribucion(),
            ),
            if (p == null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lo que dice el punto, en palabras: dentro o fuera, a cuánto, qué zona, qué tan preciso.
class _Resultado extends StatelessWidget {
  const _Resultado({required this.borrador});
  final Borrador borrador;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final u = borrador.ubicacion;
    final (IconData icono, Color color, String titulo, String detalle) = switch ((borrador.gps, u)) {
      (_, Ubicacion u) when u.dentro => (
          Icons.eco_rounded,
          Zc.hoja,
          'Dentro del manglar',
          '${u.zona.nombre} · ${u.zona.municipio}',
        ),
      (_, Ubicacion u) when u.enInfluencia => (
          Icons.radar_rounded,
          Zc.sol,
          'A ${u.distanciaM.round()} m del manglar',
          'Área de influencia de ${u.zona.nombre}: puede afectarlo igual.',
        ),
      (_, Ubicacion u) => (
          Icons.wrong_location_rounded,
          Zc.fango,
          u.distanciaM < 1000
              ? 'A ${u.distanciaM.round()} m del manglar'
              : 'A ${(u.distanciaM / 1000).toStringAsFixed(1)} km del manglar',
          'Lo más cercano es ${u.zona.nombre}. Si lo afecta, repórtalo igual; si no, revisa el punto.',
        ),
      (EstadoGps.sinPermiso, null) => (
          Icons.location_disabled_rounded,
          Zc.fango,
          'Sin permiso de ubicación',
          'Toca «Mi ubicación» para darlo, o marca el punto tocando el mapa.',
        ),
      (EstadoGps.apagado, null) => (
          Icons.location_off_rounded,
          Zc.fango,
          'El GPS está apagado',
          'Enciéndelo con «Mi ubicación», o marca el punto tocando el mapa.',
        ),
      (EstadoGps.noDisponible, null) => (
          Icons.location_searching_rounded,
          Zc.fango,
          'No pude leer el GPS',
          'Marca el punto tocando el mapa o pega un enlace de Google Maps.',
        ),
      _ => (
          Icons.satellite_alt_rounded,
          Zc.cienaga,
          'Buscando tu ubicación…',
          'El GPS funciona sin internet. Al aire libre tarda unos segundos.',
        ),
    };
    final precision = switch (borrador.metodo) {
      MetodoUbicacion.gps when borrador.precisionM != null => 'GPS ±${borrador.precisionM!.round()} m',
      MetodoUbicacion.mapa => 'Marcado en el mapa',
      MetodoUbicacion.enlace => 'Desde Google Maps',
      _ => null,
    };
    return AnimatedContainer(
      duration: Zm.medio,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Zr.m),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(icono, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: tt.titleSmall),
                const SizedBox(height: 2),
                Text(detalle, style: tt.bodySmall),
                if (precision != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                    child: Text(precision, style: tt.labelSmall?.copyWith(color: Zc.texto)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, this.icono});
  final Color color;
  final IconData? icono;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Icon(icono ?? Icons.place_rounded, color: Colors.white, size: 20),
          ),
          Container(width: 3, height: 12, color: color),
        ],
      );
}

class _Atribucion extends StatelessWidget {
  const _Atribucion();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(6)),
        child: Text('© OpenStreetMap', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9.5)),
      );
}

class _BotonChico extends StatelessWidget {
  const _BotonChico({required this.icono, required this.texto, required this.onTap});
  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Presionable(
        onTap: onTap,
        etiqueta: texto,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Zr.m),
            border: Border.all(color: Zc.linea),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 19, color: Zc.hoja),
              const SizedBox(width: 8),
              Flexible(
                child: Text(texto,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge),
              ),
            ],
          ),
        ),
      );
}

/// Hoja para pegar un enlace de Google Maps. Si el portapapeles ya trae uno, viene puesto.
class _HojaEnlace extends StatefulWidget {
  const _HojaEnlace({required this.inicial});
  final String inicial;

  @override
  State<_HojaEnlace> createState() => _HojaEnlaceState();
}

class _HojaEnlaceState extends State<_HojaEnlace> {
  late final _campo = TextEditingController(
    text: leerEnlaceMapa(widget.inicial).punto != null || leerEnlaceMapa(widget.inicial).corto ? widget.inicial : '',
  );

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final r = leerEnlaceMapa(_campo.text);
    final p = r.punto;
    final fuera = p != null && !enElAtlantico(p);
    final String? aviso = _campo.text.trim().isEmpty
        ? null
        : r.corto
            ? 'Ese enlace corto no trae la coordenada. En Google Maps, mantén presionado el punto y copia las coordenadas (los números de arriba).'
            : p == null
                ? 'No encuentro una ubicación en ese texto.'
                : fuera
                    ? 'Ese punto queda fuera del Atlántico. ¿Es el enlace correcto?'
                    : null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Zr.xl)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: Zc.linea, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Pega el enlace o las coordenadas', style: tt.titleLarge),
              const SizedBox(height: 4),
              Text('Sirve un enlace de Google Maps o algo como 11.0432, -74.8611.', style: tt.bodyMedium),
              const SizedBox(height: 14),
              TextField(
                controller: _campo,
                autofocus: _campo.text.isEmpty,
                minLines: 1,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'https://maps.google.com/…',
                  filled: true,
                  fillColor: Zc.arena,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Zr.m), borderSide: BorderSide.none),
                ),
              ),
              AnimatedSize(
                duration: Zm.corto,
                child: aviso == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(aviso, style: tt.bodySmall?.copyWith(color: Zc.fango)),
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: BotonZ(
                  texto: p == null ? 'Usar este punto' : 'Usar ${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}',
                  icono: Icons.check_rounded,
                  onTap: p == null ? null : () => Navigator.pop(context, p),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
