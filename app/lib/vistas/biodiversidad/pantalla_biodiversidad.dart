import 'package:flutter/material.dart';

import '../../datos/apis/biodiversidad.dart';
import '../../datos/apis/mareas.dart';
import '../../datos/zonas.dart';
import '../../nucleo/tema.dart';

/// Observaciones cercanas a una zona; la ficha indica siempre su procedencia.
class PantallaBiodiversidad extends StatefulWidget {
  const PantallaBiodiversidad({super.key, required this.zona, this.biodiversidad, this.mareas});
  final ZonaManglar zona;
  final ServicioBiodiversidad? biodiversidad;
  final ServicioMareas? mareas;

  @override
  State<PantallaBiodiversidad> createState() => _PantallaBiodiversidadState();
}

class _PantallaBiodiversidadState extends State<PantallaBiodiversidad> {
  late final ServicioBiodiversidad _biodiversidad = widget.biodiversidad ?? ServicioBiodiversidad();
  late final ServicioMareas _mareas = widget.mareas ?? ServicioMareas();
  ResultadoBiodiversidad? _resultado;
  NivelMar? _nivel;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant PantallaBiodiversidad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zona.id != widget.zona.id) {
      _resultado = null;
      _nivel = null;
      _cargar();
    }
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final id = widget.zona.id;
    try {
      final datos = await Future.wait<Object?>([
        _biodiversidad.cargar(widget.zona),
        _mareas.cargar(widget.zona),
      ]);
      if (mounted && id == widget.zona.id) {
        setState(() {
          _resultado = datos[0] as ResultadoBiodiversidad;
          _nivel = datos[1] as NivelMar?;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted && id == widget.zona.id) {
        setState(() {
          _resultado = const ResultadoBiodiversidad([], error: 'No hay datos disponibles.');
          _cargando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (widget.biodiversidad == null) _biodiversidad.cerrar();
    if (widget.mareas == null) _mareas.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final especies = _resultado?.especies ?? const <EspecieCercana>[];
    return Scaffold(
      backgroundColor: Zc.arena,
      appBar: AppBar(title: const Text('Especies del manglar en tu zona')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        Text(widget.zona.etiquetaSector, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Registros de observación cercanos; no prueban que una especie esté hoy en el lugar.'),
        const SizedBox(height: 12),
        if (_cargando) const Center(child: CircularProgressIndicator()),
        if (_resultado?.deCache == true) const Text('Datos guardados · pueden estar desactualizados',
          style: TextStyle(color: Zc.textoSuave)),
        if (_resultado?.error != null) Text(_resultado!.error!, style: const TextStyle(color: Zc.textoSuave)),
        if (!_cargando && especies.isEmpty) const Card(child: Padding(
          padding: EdgeInsets.all(16), child: Text('No hay observaciones disponibles para esta zona.'))),
        for (final especie in especies) _FichaEspecie(especie: especie),
        const SizedBox(height: 16),
        Text('Nivel del mar estimado', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: _nivel == null
          ? const Text('Sin estimación disponible para esta zona.')
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_nivel!.metros.toStringAsFixed(2)} m sobre el nivel medio global',
                style: Theme.of(context).textTheme.titleMedium),
              Text('Open-Meteo Marine · ${_nivel!.hora.toLocal()}${_nivel!.deCache ? ' · dato guardado' : ''}'),
            ]))),
        const Text('Fuentes del modelo: MeteoFrance/Copernicus Marine, ECMWF, NOAA y DWD según cobertura.',
          style: TextStyle(fontSize: 12, color: Zc.textoSuave)),
        const Text('Estimación de modelo; no sirve para navegación ni decisiones de seguridad costera.',
          style: TextStyle(color: Zc.textoSuave)),
      ])),
    );
  }
}

class _FichaEspecie extends StatelessWidget {
  const _FichaEspecie({required this.especie});
  final EspecieCercana especie;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    margin: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (especie.foto != null) Image.network(especie.foto!, height: 170,
        fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(
          height: 80, child: Center(child: Text('Foto no disponible')))),
      Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(especie.nombre, style: Theme.of(context).textTheme.titleMedium),
          Text(especie.cientifico, style: const TextStyle(fontStyle: FontStyle.italic)),
          Text(especie.fuente, style: const TextStyle(color: Zc.textoSuave)),
          if (especie.foto != null) Text('Foto: ${especie.credito ?? 'crédito no informado'} · ${especie.licencia ?? 'licencia no informada'}',
            style: const TextStyle(fontSize: 12, color: Zc.textoSuave)),
          SelectableText(especie.urlRegistro, style: const TextStyle(fontSize: 12, color: Zc.cienaga)),
        ])),
    ]),
  );
}
