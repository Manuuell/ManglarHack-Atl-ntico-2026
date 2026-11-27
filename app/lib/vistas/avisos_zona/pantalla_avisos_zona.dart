import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../datos/avisos_zona/reglas.dart';
import '../../datos/avisos_zona/repositorio.dart';
import '../../datos/zonas.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/kit/accion_gesto.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/boton_estado.dart';
import '../../nucleo/kit/confirmar.dart';
import '../../nucleo/kit/fila_deslizable.dart';
import '../../nucleo/kit/interruptor.dart';
import '../../nucleo/tema.dart';

class PantallaAvisosZona extends StatefulWidget {
  const PantallaAvisosZona({super.key, this.repositorio, this.zonaInicial, this.manglar});
  final RepositorioAvisosZona? repositorio;

  /// Zona desde la que se llegó («Avisarme de esta zona»): llega elegida en el alta.
  final String? zonaInicial;

  /// Zonas ya cargadas (pruebas); sin él se leen del recurso de la app.
  final Manglar? manglar;

  @override
  State<PantallaAvisosZona> createState() => _PantallaAvisosZonaState();
}

class _PantallaAvisosZonaState extends State<PantallaAvisosZona> {
  late final RepositorioAvisosZona repo;
  bool cargando = true, inscrito = false, ocupada = false;
  List<AvisoCercano> avisos = const [];

  @override
  void initState() {
    super.initState();
    repo = widget.repositorio ?? RepositorioAvisosZona();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final alta = await repo.inscrito();
      final lista = alta ? await repo.listar() : <AvisoCercano>[];
      if (mounted) setState(() { inscrito = alta; avisos = lista; cargando = false; });
    } catch (_) {
      if (mounted) { setState(() => cargando = false); _mensaje('No se pudieron cargar los avisos.'); }
    }
  }

  void _mensaje(String texto) {
    avisar(context, texto);
  }

  Future<void> _inscribir() async {
    final alta = await mostrarHojaZ<AltaVoluntario>(
      context, nombre: 'alta_voluntario',
      contenido: (_) => HojaVoluntario(zonaInicial: widget.zonaInicial, manglar: widget.manglar),
    );
    if (alta == null || !mounted) return;
    setState(() => ocupada = true);
    try {
      await repo.inscribir(alta);
      await _cargar();
      if (mounted) _mensaje('Ya eres voluntario de tu zona.');
    } catch (_) {
      if (mounted) _mensaje('No se pudo completar la inscripción. Revisa los datos e inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => ocupada = false);
    }
  }

  Future<void> _baja() async {
    final seguro = await confirmarEnHoja(context,
      titulo: 'Retirar mi autorización', destructivo: true, seguroPrimero: true,
      texto: 'Dejarás de recibir avisos de tu zona y se cancelan los que aún no salieron. '
          'Podrás volver a inscribirte cuando quieras.',
      textoConfirmar: 'Darme de baja', textoCancelar: 'Seguir recibiendo');
    if (!seguro || !mounted) return;
    setState(() => ocupada = true);
    try {
      await repo.baja();
      await _cargar();
      if (mounted) _mensaje('Te diste de baja de los avisos.');
    } catch (_) {
      if (mounted) _mensaje('No se pudo confirmar la baja. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => ocupada = false);
    }
  }

  Future<void> _ayudar(AvisoCercano aviso) async {
    setState(() => ocupada = true);
    try {
      await repo.ayudar(aviso.id);
      await _cargar();
      if (mounted) _mensaje('Tu participación quedó registrada y se avisó al encargado.');
    } catch (_) {
      if (mounted) _mensaje('No se pudo registrar tu ayuda.');
    } finally {
      if (mounted) setState(() => ocupada = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Avisos cerca de ti')),
        body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
          if (repo.demostracion) const Card(child: Padding(
            padding: EdgeInsets.all(12), child: Text('Demostración sin servidor · Los avisos son de ejemplo.'),
          )),
          if (cargando) const Center(child: CircularProgressIndicator())
          else if (!inscrito) ...[
            const Icon(Icons.volunteer_activism, size: 56, color: Zc.hoja),
            const SizedBox(height: 16),
            Text('Cuida el manglar desde tu zona', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Elige los avisos que quieres recibir. Puedes darte de baja cuando quieras.'),
            const SizedBox(height: 20),
            FilledButton(onPressed: ocupada ? null : _inscribir,
              child: const Text('Sé voluntario de tu zona')),
          ] else ...[
            const ListTile(leading: Icon(Icons.check_circle, color: Zc.hoja),
              title: Text('Eres voluntario'), subtitle: Text('Gracias por estar pendiente de tu zona.')),
            OutlinedButton(onPressed: ocupada ? null : _baja, child: const Text('Darme de baja')),
            const SizedBox(height: 16),
            Text('Avisos cerca de ti', style: Theme.of(context).textTheme.titleLarge),
            if (avisos.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Aún no hay avisos para ti.')),
            for (final a in avisos) Padding(padding: const EdgeInsets.only(top: 8),
              child: FilaDeslizable(
                etiquetaSemantica: '${a.tipo}, zona ${a.zona}',
                accionesFin: [if (!a.apoye && !ocupada) AccionGesto(
                  etiqueta: 'Voy a ayudar', icono: Icons.volunteer_activism_outlined,
                  alEjecutar: () => _ayudar(a))],
                hijo: Card(margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${a.tipo} · ${a.prioridad}', style: Theme.of(context).textTheme.titleMedium),
                    Text('Zona: ${a.zona}'),
                    Text('Recibido: ${a.creadoEn.toLocal()}'),
                    Align(alignment: Alignment.centerRight, child: TextButton.icon(
                      onPressed: ocupada || a.apoye ? null : () => _ayudar(a),
                      icon: Icon(a.apoye ? Icons.check : Icons.volunteer_activism_outlined),
                      label: Text(a.apoye ? 'Ya estás ayudando' : 'Voy a ayudar'),
                    )),
                  ])))),
            ),
          ],
        ])),
      );
}

/// Hoja de inscripción. El punto compartido se redondea a ~100 m.
class HojaVoluntario extends StatefulWidget {
  const HojaVoluntario({super.key, this.zonaInicial, this.manglar});
  final String? zonaInicial;
  final Manglar? manglar;
  @override
  State<HojaVoluntario> createState() => _HojaVoluntarioState();
}

class _HojaVoluntarioState extends State<HojaVoluntario> {
  final formulario = GlobalKey<FormState>();
  final nombre = TextEditingController(), telefono = TextEditingController();
  List<ZonaManglar> zonas = const [];
  String? zona;
  double? lat, lon;
  double radio = 2;
  bool whatsapp = true, app = true, consentimiento = false, gps = false;
  TimeOfDay? desde, hasta;

  @override
  void initState() { super.initState(); _zonas(); }
  @override
  void dispose() { nombre.dispose(); telefono.dispose(); super.dispose(); }

  Future<void> _zonas() async {
    try {
      final m = widget.manglar ?? await Manglar.cargar();
      if (mounted) {
        setState(() { zonas = m.zonas;
        zona = m.zonas.any((z) => z.id == widget.zonaInicial) ? widget.zonaInicial : zonas.first.id; });
      }
    } catch (_) { if (mounted) setState(() => zonas = const []); }
  }

  Future<void> _ubicacion() async {
    setState(() => gps = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw StateError('gps');
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        throw StateError('permiso');
      }
      final p = await Geolocator.getCurrentPosition(locationSettings:
        const LocationSettings(accuracy: LocationAccuracy.low));
      final m = await Manglar.cargar();
      if (mounted) {
        setState(() {
        lat = (p.latitude * 1000).round() / 1000;
        lon = (p.longitude * 1000).round() / 1000;
        zona = m.ubicar(LatLng(p.latitude, p.longitude)).zona.id;
      });
      }
    } catch (_) {
      if (mounted) {
        avisar(context, 'No se pudo usar la ubicación. Elige una zona manualmente.', tipo: TipoAviso.error);
      }
    } finally { if (mounted) setState(() => gps = false); }
  }

  String _hora(TimeOfDay? h) => h == null ? 'Elegir' :
    '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
  String? _sqlHora(TimeOfDay? h) => h == null ? null : '${_hora(h)}:00';

  void _guardar() {
    if (!(formulario.currentState?.validate() ?? false)) return;
    if (!consentimiento || (!whatsapp && !app) || zona == null ||
        (desde == null) != (hasta == null)) {
      avisar(context, 'Acepta el consentimiento, elige un canal y completa el horario.', tipo: TipoAviso.error);
      return;
    }
    final z = zonas.firstWhere((z) => z.id == zona);
    // La selección manual usa el centro aproximado de la zona.
    final punto = z.centro;
    Navigator.pop(context, AltaVoluntario(
      nombre: nombre.text.trim(), telefono: normalizarTelefono(telefono.text) ?? telefono.text.trim(), zona: zona!,
      lat: lat ?? (punto.latitude * 1000).round() / 1000,
      lon: lon ?? (punto.longitude * 1000).round() / 1000,
      radioKm: radio,
      canales: [if (whatsapp) 'whatsapp', if (app) 'app'],
      tipos: const ['tala','quema','relleno','vertimiento','basuras','cano_taponado','fauna','otro','sensor'],
      silencioDesde: _sqlHora(desde), silencioHasta: _sqlHora(hasta), consentimiento: true,
    ));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: Form(key: formulario, child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Sé voluntario de tu zona', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextFormField(controller: nombre, decoration: const InputDecoration(labelText: 'Tu nombre'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Escribe tu nombre' : null),
            TextFormField(controller: telefono, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono de WhatsApp (ej. 300 123 4567)'),
              validator: (v) => normalizarTelefono(v ?? '') != null
                ? null : 'Escribe un teléfono válido (ej. 300 123 4567)'),
            DropdownButtonFormField<String>(initialValue: zona, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Zona'),
              items: [for (final z in zonas) DropdownMenuItem(value: z.id, child: Text(z.nombre, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() { zona = v; lat = null; lon = null; })),
            TextButton.icon(onPressed: gps ? null : _ubicacion, icon: const Icon(Icons.my_location),
              label: Text(gps ? 'Ubicando…' : 'Detectar mi zona con ubicación')),
            Text('Radio: ${radio.round()} km'),
            Slider(value: radio, min: 1, max: 20, divisions: 19,
              label: '${radio.round()} km', onChanged: (v) => setState(() => radio = v)),
            const Text('Canales de aviso'),
            _FilaCanal(titulo: 'WhatsApp', valor: whatsapp, alCambiar: (v) => setState(() => whatsapp = v)),
            _FilaCanal(titulo: 'En la app', valor: app, alCambiar: (v) => setState(() => app = v)),
            const _FilaCanal(titulo: 'Correo (próximamente)', valor: false, alCambiar: null),
            const Text('Horario silencioso (opcional, hora de Colombia)'),
            Wrap(spacing: 8, children: [
              OutlinedButton(onPressed: () async { final v = await showTimePicker(context: context,
                initialTime: desde ?? const TimeOfDay(hour: 22, minute: 0));
                if (mounted && v != null) setState(() => desde = v); }, child: Text('Desde: ${_hora(desde)}')),
              OutlinedButton(onPressed: () async { final v = await showTimePicker(context: context,
                initialTime: hasta ?? const TimeOfDay(hour: 7, minute: 0));
                if (mounted && v != null) setState(() => hasta = v); }, child: Text('Hasta: ${_hora(hasta)}')),
              if (desde != null || hasta != null) TextButton(onPressed: () => setState(() {
                desde = null; hasta = null; }), child: const Text('Quitar horario')),
            ]),
            const SizedBox(height: 8),
            Material(
              color: Zc.hojaClara, borderRadius: BorderRadius.circular(Zr.s),
              child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tus datos y tu autorización', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                const Text(textoConsentimientoAvisos),
                const SizedBox(height: 4),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
                  value: consentimiento,
                  onChanged: (v) => setState(() => consentimiento = v ?? false),
                  title: const Text('Sí, autorizo recibir avisos de mi zona'),
                ),
              ])),
            ),
            const SizedBox(height: 12),
            BotonEstado(texto: 'Inscribirme', icono: Icons.volunteer_activism_outlined,
              alPresionar: zonas.isEmpty || !consentimiento ? null : () async => _guardar()),
          ])),
      );
}

/// Canal de aviso con interruptor estilo iOS (kit/interruptor.dart).
class _FilaCanal extends StatelessWidget {
  const _FilaCanal({required this.titulo, required this.valor, required this.alCambiar});
  final String titulo;
  final bool valor;
  final ValueChanged<bool>? alCambiar;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(titulo)),
          InterruptorIos(valor: valor, alCambiar: alCambiar, etiqueta: titulo),
        ]),
      );
}
