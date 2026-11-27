import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../datos/gestion/repositorio_puntos.dart';
import '../../datos/punto/punto_zanky.dart';
import '../../nucleo/kit/boton_estado.dart';
import '../../nucleo/kit/aviso.dart';

class EditorPunto extends StatefulWidget {
  const EditorPunto({super.key, required this.repositorio, this.punto});
  final RepositorioPuntos repositorio;
  final PuntoZanky? punto;
  @override
  State<EditorPunto> createState() => _EditorPuntoState();
}

class _EditorPuntoState extends State<EditorPunto> {
  final _forma = GlobalKey<FormState>();
  late final _codigo = TextEditingController(text: widget.punto?.codigo ?? '');
  late final _titulo = TextEditingController(text: widget.punto?.titulo ?? '');
  late final _descripcion = TextEditingController(text: widget.punto?.descripcion ?? '');
  late final _zona = TextEditingController(text: widget.punto?.zona ?? '');
  late final _evento = TextEditingController(text: widget.punto?.eventoId ?? '');
  late final _sensor = TextEditingController(text: widget.punto?.sensorId ?? '');
  late TipoPunto _tipo = widget.punto?.tipo ?? TipoPunto.estacionEducativa;
  late bool _activo = widget.punto?.activo ?? true;
  late LatLng? _lugar = widget.punto?.lat == null || widget.punto?.lon == null
    ? null : LatLng(widget.punto!.lat!, widget.punto!.lon!);

  @override
  void dispose() {
    for (final c in [_codigo, _titulo, _descripcion, _zona, _evento, _sensor]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _ubicacionActual() async {
    try {
      final permiso = await Geolocator.checkPermission();
      final concedido = permiso == LocationPermission.denied
        ? await Geolocator.requestPermission() : permiso;
      if (concedido == LocationPermission.denied || concedido == LocationPermission.deniedForever) {
        if (mounted) avisar(context, 'Activa el permiso de ubicación para usar tu posición.');
        return;
      }
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) setState(() => _lugar = LatLng(posicion.latitude, posicion.longitude));
    } catch (_) {
      if (mounted) avisar(context, 'No se pudo obtener la ubicación. Selecciónala en el mapa.');
    }
  }

  Future<void> _guardar() async {
    if (!_forma.currentState!.validate()) return;
    if (_tipo == TipoPunto.fotoFija && _lugar == null) {
      avisar(context, 'La fotografía fija necesita una ubicación para vincular los reportes.');
      return;
    }
    final p = PuntoZanky(codigo: codigoPuntoValido(_codigo.text)!, tipo: _tipo,
      titulo: _titulo.text.trim(), descripcion: _descripcion.text.trim(), zona: _zona.text.trim(),
      lat: _lugar?.latitude, lon: _lugar?.longitude,
      eventoId: _evento.text.trim().isEmpty ? null : _evento.text.trim(),
      sensorId: _sensor.text.trim().isEmpty ? null : _sensor.text.trim(), activo: _activo);
    await widget.repositorio.guardar(p);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final centro = _lugar ?? const LatLng(10.99, -74.91);
    return Scaffold(appBar: AppBar(title: Text(widget.punto == null ? 'Crear punto' : 'Editar punto')),
      body: Form(key: _forma, child: ListView(padding: const EdgeInsets.all(20), children: [
        if (widget.repositorio.demostracion) const Text('DEMOSTRACIÓN · solo en esta sesión'),
        TextFormField(controller: _codigo, readOnly: widget.punto != null,
          decoration: const InputDecoration(labelText: 'Código para QR y NFC', helperText: '3 a 40 caracteres: letras minúsculas, números y guiones'),
          validator: (v) => codigoPuntoValido(v) == null ? 'Usa 3 a 40 letras, números o guiones.' : null),
        const SizedBox(height: 12),
        DropdownButtonFormField<TipoPunto>(initialValue: _tipo, decoration: const InputDecoration(labelText: 'Tipo'),
          items: [for (final t in TipoPunto.values) DropdownMenuItem(value: t, child: Text(t.nombre))],
          onChanged: (t) { if (t != null) setState(() => _tipo = t); }),
        const SizedBox(height: 12),
        TextFormField(controller: _titulo, decoration: const InputDecoration(labelText: 'Título'),
          validator: (v) => (v?.trim().length ?? 0) < 3 || (v?.trim().length ?? 0) > 120
            ? 'Escribe entre 3 y 120 caracteres.' : null),
        const SizedBox(height: 12),
        TextFormField(controller: _descripcion, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Descripción o dato del manglar')),
        const SizedBox(height: 12),
        TextFormField(controller: _zona, decoration: const InputDecoration(labelText: 'Zona')),
        if (_tipo == TipoPunto.asistenciaEvento)
          TextFormField(controller: _evento, decoration: const InputDecoration(labelText: 'Código del evento')),
        if (_tipo == TipoPunto.sensor)
          TextFormField(controller: _sensor, decoration: const InputDecoration(labelText: 'ID del sensor (UUID)'),
            validator: (v) => v != null && RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$').hasMatch(v.trim())
              ? null : 'Escribe un UUID válido.'),
        const SizedBox(height: 16),
        Text('Ubicación: ${_lugar == null ? 'sin seleccionar' : '${_lugar!.latitude.toStringAsFixed(5)}, ${_lugar!.longitude.toStringAsFixed(5)}'}'),
        TextButton.icon(onPressed: _ubicacionActual, icon: const Icon(Icons.my_location_rounded),
          label: const Text('Usar ubicación actual')),
        const Text('También puedes tocar el mapa para situar el punto.'),
        const SizedBox(height: 8),
        SizedBox(height: 240, child: FlutterMap(
          key: ValueKey('${centro.latitude},${centro.longitude}'),
          options: MapOptions(initialCenter: centro, initialZoom: 13,
            onTap: (_, lugar) => setState(() => _lugar = lugar)),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'co.zanky.app'),
            if (_lugar != null) MarkerLayer(markers: [Marker(point: _lugar!, width: 44, height: 44,
              child: const Icon(Icons.place_rounded, color: Colors.red, size: 40))]),
          ],
        )),
        SwitchListTile(value: _activo, onChanged: (v) => setState(() => _activo = v),
          title: const Text('Punto activo'), subtitle: const Text('Visible al público cuando está activo')),
        const SizedBox(height: 16),
        BotonEstado(texto: 'Guardar punto', icono: Icons.save_rounded, alPresionar: _guardar),
      ])));
  }
}
