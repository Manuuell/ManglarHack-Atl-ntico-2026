import 'package:flutter/material.dart';

import '../../datos/punto/punto_zanky.dart';
import '../../datos/punto/servicio_punto.dart';
import '../../datos/estado.dart';
import '../../nucleo/kit/boton_estado.dart';
import '../../nucleo/kit/estado_vacio.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';
import '../experiencia/puerta_evento.dart';
import '../experiencia/atajos_evento.dart';
import '../reporte/flujo_reporte.dart';

class PantallaPunto extends StatefulWidget {
  const PantallaPunto({super.key, required this.codigo, this.servicio});
  final String codigo;
  final ServicioPunto? servicio;
  @override
  State<PantallaPunto> createState() => _PantallaPuntoState();
}

class _PantallaPuntoState extends State<PantallaPunto> {
  late final ServicioPunto _servicio = widget.servicio ?? ServicioPunto();
  PuntoZanky? _punto;
  bool _cargando = true;
  bool _pendiente = false;
  bool _fotoPendiente = false;
  bool _visitaSinFicha = false;
  String? _error;
  List<Map<String, dynamic>> _lecturas = [];

  Future<void> _abrirReportePunto(PuntoZanky punto) {
    if (Zanky.leer(context).perfil?.consentimiento == null) {
      return explicarSinPerfil(context, 'un reporte');
    }
    return abrirReporte(context, zonaId: punto.zona.isEmpty ? null : punto.zona);
  }

  Future<void> _reportarFoto(PuntoZanky punto) async {
    final estado = Zanky.leer(context);
    if (estado.perfil?.consentimiento == null) {
      await explicarSinPerfil(context, 'un reporte con foto');
      return;
    }
    final antes = {for (final r in estado.reportes) r.id};
    await _abrirReportePunto(punto);
    final nuevos = estado.reportes.where((r) => !antes.contains(r.id) &&
      (r.fotoRef != null || r.fotoUrl != null)).toList();
    if (nuevos.isEmpty) {
      if (mounted) avisar(context, 'Para crear la serie de seguimiento, añade una foto al reporte.');
      return;
    }
    if (!mounted) return;
    final vinculada = await _servicio.vincularFoto(punto.codigo, nuevos.first.id);
    if (mounted) setState(() => _fotoPendiente = !vinculada);
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final p = await _servicio.cargar(widget.codigo);
      if (!mounted) return;
      if (p == null) {
        setState(() { _cargando = false; _error = _servicio.servidor.configurado
            ? 'Este punto no está activo o no existe.' : 'No hay servidor configurado para consultar este punto.'; });
        return;
      }
      setState(() { _punto = p; _cargando = false; _visitaSinFicha = false; });
      if (_servicio.servidor.configurado) {
        try {
          final enviada = await _servicio.registrar(p.codigo);
          if (mounted) setState(() => _pendiente = !enviada);
        } catch (_) {
          if (mounted) setState(() => _pendiente = true);
        }
      }
      if (p.tipo == TipoPunto.sensor) {
        try {
          final lecturas = await _servicio.lecturas();
          if (mounted) setState(() => _lecturas = lecturas.where((l) => '${l['sensor_id']}' == p.sensorId).toList());
        } catch (_) {}
      }
    } catch (_) {
      if (_servicio.servidor.configurado) {
        try {
          await _servicio.guardarPendiente(widget.codigo);
          _visitaSinFicha = true;
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = _visitaSinFicha
              ? 'Visita guardada en este teléfono. Se enviará cuando vuelva la señal. La ficha aparecerá al reintentar.'
              : 'No se pudo cargar el punto. Revisa la señal e inténtalo de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _punto;
    return Scaffold(
      backgroundColor: Zc.arena,
      appBar: AppBar(title: const Text('Punto Zanky')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : p == null
              ? EstadoVacio(titulo: 'Punto no disponible', texto: _error ?? '',
                  textoAccion: 'Reintentar', alAccion: () { setState(() => _cargando = true); _cargar(); })
              : ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 36), children: [
                  Center(child: ZankyMascota(tamano: 120, animo: Animo.curioso)),
                  const SizedBox(height: 12),
                  if (!_servicio.servidor.configurado)
                    Semantics(label: 'Demostración sin servidor',
                      child: Text('DEMOSTRACIÓN · esta visita no se publicará.')),
                  Semantics(header: true, child: Text(p.titulo, style: Theme.of(context).textTheme.headlineSmall)),
                  const SizedBox(height: 8),
                  Text(p.tipo.nombre),
                  if (p.zona.isNotEmpty) Text(p.zona),
                  if (_pendiente) Semantics(liveRegion: true,
                    child: Padding(padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Visita guardada en este teléfono. Se enviará cuando vuelva la señal.'))),
                  if (_fotoPendiente) Semantics(liveRegion: true,
                    child: Padding(padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('La foto quedó pendiente de vinculación. Se reintentará cuando llegue el reporte al servidor.'))),
                  const SizedBox(height: 16),
                  if (p.descripcion.isNotEmpty) Text(p.descripcion),
                  const SizedBox(height: 22),
                  ..._contenido(p),
                ]),
    );
  }

  List<Widget> _contenido(PuntoZanky p) => switch (p.tipo) {
    TipoPunto.asistenciaEvento => [
      const Text('Tu visita a este punto quedó registrada. Entra al modo evento para confirmar tu asistencia.'),
      const SizedBox(height: 14),
      BotonEstado(texto: 'Abrir jornada', icono: Icons.event_rounded,
        alPresionar: () => abrirEvento(context, p.eventoId ?? p.codigo, asistencia: true)),
    ],
    TipoPunto.estacionEducativa => [
      const Text('Dato del manglar', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('Las raíces de los mangles retienen sedimentos y dan refugio a peces jóvenes.'),
      const SizedBox(height: 16),
      const Text('Reto corto', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('Observa alrededor: ¿ves raíces, hojas o animales? Describe lo que encuentras en tu próximo reporte.'),
      const SizedBox(height: 14),
      BotonEstado(texto: 'Reportar mi observación', icono: Icons.eco_rounded,
        alPresionar: () => _abrirReportePunto(p)),
    ],
    TipoPunto.fotoFija => [
      const Text('Serie de fotografías del mismo lugar', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('Párate en la marca del punto. Alinea el horizonte y el tronco principal con la guía antes de fotografiar. Incluye una foto en el reporte: quedará vinculada a este punto para comparar cambios con el tiempo.'),
      const SizedBox(height: 14),
      Semantics(label: 'Guía de encuadre: horizonte horizontal y tronco al centro',
        child: Container(height: 190, decoration: BoxDecoration(border: Border.all(color: Zc.hoja, width: 3), borderRadius: BorderRadius.circular(12)),
          child: CustomPaint(painter: _SiluetaEncuadre(), child: const Center(child: Text('Alinea el paisaje con esta silueta'))))),
      const SizedBox(height: 14),
      BotonEstado(texto: 'Tomar foto y enviar reporte de monitoreo', icono: Icons.camera_alt_rounded,
        alPresionar: () => _reportarFoto(p)),
    ],
    TipoPunto.sensor => [
      const Text('Última lectura del sensor', style: TextStyle(fontWeight: FontWeight.bold)),
      if (_lecturas.isEmpty) const Text('Todavía no hay una lectura disponible para este sensor.'),
      for (final l in _lecturas) Text('${l['nombre'] ?? 'Sensor'}: ${l['valor'] ?? 'sin lectura'} ${l['unidad'] ?? ''}\n'
        '${l['vigente'] == true ? 'Lectura vigente' : 'Lectura antigua'} · ${l['medido_en'] ?? 'sin fecha'}'),
      const SizedBox(height: 8),
      const Text('Las lecturas orientan la observación; cualquier alerta requiere revisión humana.'),
    ],
  };
}

class _SiluetaEncuadre extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final trazo = Paint()..color = Zc.hoja.withValues(alpha: 0.65)..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height * .55), Offset(size.width, size.height * .55), trazo);
    final camino = Path()
      ..moveTo(size.width * .5, size.height)
      ..quadraticBezierTo(size.width * .52, size.height * .57, size.width * .5, size.height * .17)
      ..moveTo(size.width * .5, size.height * .42)
      ..quadraticBezierTo(size.width * .3, size.height * .2, size.width * .2, size.height * .17)
      ..moveTo(size.width * .5, size.height * .35)
      ..quadraticBezierTo(size.width * .68, size.height * .13, size.width * .78, size.height * .17);
    canvas.drawPath(camino, trazo);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

