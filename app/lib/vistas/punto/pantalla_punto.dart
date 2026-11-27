import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../datos/punto/punto_zanky.dart';
import '../../datos/punto/servicio_punto.dart';
import '../../datos/estado.dart';
import '../../nucleo/kit/boton_estado.dart';
import '../../nucleo/kit/estado_vacio.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/tema.dart';
import '../../nucleo/identidad.dart';
import '../bienvenida/fotos.dart';
import '../comun/zanky_mascota.dart';
import '../../datos/experiencia/jornada.dart';
import '../experiencia/puerta_evento.dart';
import '../experiencia/sigue_visitante.dart';
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
  final _jornadas = FuenteJornadas();
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
    final lat = punto.lat, lon = punto.lon;
    return abrirReporte(
      context,
      zonaId: punto.zona.isEmpty ? null : punto.zona,
      punto: lat == null || lon == null ? null : LatLng(lat, lon),
    );
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
    final foto = fotoDelPunto(p);
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Zc.arena,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Punto Zanky'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _cargando
          ? Column(children: [_CabeceraPunto(foto: foto, cargando: true), const Spacer()])
          : p == null
              ? Column(children: [
                  _CabeceraPunto(foto: foto),
                  Expanded(child: EstadoVacio(titulo: 'Punto no disponible', texto: _error ?? '',
                    textoAccion: 'Reintentar', alAccion: () { setState(() => _cargando = true); _cargar(); })),
                ])
              : ListView(padding: EdgeInsets.zero, children: [
                  _CabeceraPunto(foto: foto, punto: p),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (!_servicio.servidor.configurado)
                        Semantics(label: 'Demostración sin servidor',
                          child: const _Nota(icono: Icons.science_outlined,
                            texto: 'DEMOSTRACIÓN · esta visita no se publicará.')),
                      if (_pendiente) Semantics(liveRegion: true,
                        child: const _Nota(icono: Icons.cloud_off_rounded,
                          texto: 'Visita guardada en este teléfono. Se enviará cuando vuelva la señal.')),
                      if (_fotoPendiente) Semantics(liveRegion: true,
                        child: const _Nota(icono: Icons.link_off_rounded,
                          texto: 'La foto quedó pendiente de vinculación. Se reintentará cuando llegue el reporte al servidor.')),
                      if (p.descripcion.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(p.descripcion, style: tt.bodyLarge),
                      ],
                      const SizedBox(height: 18),
                      ..._contenido(p),
                      ProximoEvento(fuente: _jornadas, actual: p.eventoId),
                      const SigueConZanky(),
                    ]),
                  ),
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


/// La foto del punto: el lugar del manglar más parecido entre las fotos con licencia que van en la app
/// (créditos en `assets/fotos/CREDITOS.md`). Funciona sin señal.
FotoManglar fotoDelPunto(PuntoZanky? p) {
  if (p == null) return FotoManglar.raices;
  final zona = p.zona.toLowerCase();
  if (p.tipo == TipoPunto.fotoFija) return FotoManglar.sendero;
  if (zona.contains('mallorqu')) {
    return p.tipo == TipoPunto.asistenciaEvento ? FotoManglar.sendero : FotoManglar.garza;
  }
  if (p.tipo == TipoPunto.sensor) return FotoManglar.cano;
  return FotoManglar.raices;
}

/// Cabecera con identidad CRA: foto del manglar, velo azul para leer, sello dorado y Zanky asomado.
class _CabeceraPunto extends StatelessWidget {
  const _CabeceraPunto({required this.foto, this.punto, this.cargando = false});
  final FotoManglar foto;
  final PuntoZanky? punto;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final tt = Theme.of(context).textTheme;
    final arriba = mq.padding.top + kToolbarHeight;
    final p = punto;
    final caja = Size(mq.size.width, 300);
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 250 + mq.padding.top),
      color: Cra.azul,
      child: Stack(children: [
        Positioned.fill(
          child: Image(
            image: foto.proveedor(caja, mq.devicePixelRatio),
            fit: BoxFit.cover,
            alignment: foto.foco,
            excludeFromSemantics: true,
            frameBuilder: (context, hijo, cuadro, sincrono) => AnimatedOpacity(
              opacity: sincrono || cuadro != null ? 1 : 0,
              duration: Zm.medio,
              curve: Zm.entrar,
              child: hijo,
            ),
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.35, 1],
                colors: [Color(0x99061E35), Color(0x44061E35), Color(0xF2061E35)],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, arriba + 4, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Cra.dorado, borderRadius: BorderRadius.circular(99)),
              child: Text('PUNTO ZANKY · CRA ATLÁNTICO',
                style: tt.labelSmall?.copyWith(color: Cra.hero, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            ),
            const SizedBox(height: 48),
            if (cargando)
              Semantics(
                label: 'Cargando el punto',
                child: const SizedBox(width: 26, height: 26,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Cra.dorado)),
              )
            else if (p != null) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Semantics(header: true,
                    child: Text(p.titulo,
                      style: tt.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 8),
                const ZankyMascota(tamano: 72, animo: Animo.curioso),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _Chip(icono: _iconoTipo(p.tipo), texto: p.tipo.nombre),
                if (p.zona.isNotEmpty) _Chip(icono: Icons.place_rounded, texto: p.zona),
              ]),
            ],
            const SizedBox(height: 10),
            Text(foto.credito, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(color: Cra.textoSuave, fontSize: 10)),
          ]),
        ),
      ]),
    );
  }

  static IconData _iconoTipo(TipoPunto t) => switch (t) {
    TipoPunto.asistenciaEvento => Icons.how_to_reg_rounded,
    TipoPunto.estacionEducativa => Icons.school_rounded,
    TipoPunto.fotoFija => Icons.photo_camera_rounded,
    TipoPunto.sensor => Icons.sensors_rounded,
  };
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icono, required this.texto});
  final IconData icono;
  final String texto;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Cra.hero.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 15, color: Cra.dorado),
          const SizedBox(width: 6),
          Flexible(child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white))),
        ]),
      );
}

class _Nota extends StatelessWidget {
  const _Nota({required this.icono, required this.texto});
  final IconData icono;
  final String texto;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Zc.solClaro, borderRadius: BorderRadius.circular(Zr.m)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icono, size: 18, color: Zc.fango),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}
