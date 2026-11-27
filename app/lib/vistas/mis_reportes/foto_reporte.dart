import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../datos/fotos.dart';
import '../../datos/reporte.dart';
import '../../nucleo/base/esqueleto.dart';
import '../comun/comunes.dart';

/// Caché en memoria de las fotos de los reportes (por id): leer el archivo cada
/// vez que la lista se desplaza es lo que hace tironear. Guarda las últimas
/// [_tope] para no llenar la memoria con fotos grandes.
abstract final class CacheFotos {
  static const _tope = 24;
  static final LinkedHashMap<String, Uint8List?> _listas = LinkedHashMap();
  static final Map<String, Future<Uint8List?>> _enCurso = {};

  static bool tiene(String id) => _listas.containsKey(id);

  static Uint8List? sincrono(String id) {
    final tenia = _listas.containsKey(id);
    final b = _listas.remove(id);
    if (tenia) _listas[id] = b; // lo más usado queda al final
    return b;
  }

  static Future<Uint8List?> de(Reporte r) {
    if (r.fotoRef == null) return Future.value(null);
    if (_listas.containsKey(r.id)) return Future.value(sincrono(r.id));
    return _enCurso.putIfAbsent(r.id, () async {
      final bytes = await Fotos.leer(r.fotoRef);
      _listas[r.id] = bytes;
      if (_listas.length > _tope) _listas.remove(_listas.keys.first);
      _enCurso.remove(r.id);
      return bytes;
    });
  }
}

/// La foto del reporte: esqueleto mientras carga, silueta con el ícono del tipo si
/// no hay foto (o el archivo ya no está), y `Hero` opcional hacia el detalle.
class FotoReporte extends StatefulWidget {
  const FotoReporte({
    super.key,
    required this.reporte,
    this.ancho,
    this.alto,
    this.radio = 0,
    this.cacheAncho = 260,
    this.hero = false,
    this.fit = BoxFit.cover,
  });

  final Reporte reporte;
  final double? ancho;
  final double? alto;
  final double radio;

  /// Ancho al que se decodifica la imagen: una miniatura no necesita los 12 Mpx.
  final int cacheAncho;
  final bool hero;
  final BoxFit fit;

  static String etiquetaHero(Reporte r) => 'foto-${r.id}';

  @override
  State<FotoReporte> createState() => _FotoReporteState();
}

class _FotoReporteState extends State<FotoReporte> {
  Uint8List? _bytes;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  @override
  void didUpdateWidget(FotoReporte old) {
    super.didUpdateWidget(old);
    if (old.reporte.id != widget.reporte.id) _preparar();
  }

  void _preparar() {
    final r = widget.reporte;
    if (r.fotoRef == null) {
      _bytes = null;
      _cargando = false;
      return;
    }
    if (CacheFotos.tiene(r.id)) {
      _bytes = CacheFotos.sincrono(r.id);
      _cargando = false;
      return;
    }
    _bytes = null;
    _cargando = true;
    final id = r.id;
    CacheFotos.de(r).then((b) {
      if (!mounted || widget.reporte.id != id) return;
      setState(() {
        _bytes = b;
        _cargando = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reporte;
    final radio = BorderRadius.circular(widget.radio);
    final Widget contenido;
    if (r.fotoRef != null && _cargando) {
      contenido = Skeleton(
        width: widget.ancho ?? double.infinity,
        height: widget.alto ?? double.infinity,
        borderRadius: BorderRadius.zero,
      );
    } else if (_bytes == null) {
      contenido = _Silueta(r, widget.ancho, widget.alto);
    } else {
      contenido = Semantics(
        image: true,
        label: 'Foto del reporte ${r.caso}',
        child: Image.memory(
          _bytes!,
          fit: widget.fit,
          width: widget.ancho,
          height: widget.alto,
          cacheWidth: widget.cacheAncho,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      );
    }
    Widget caja = RepaintBoundary(
      child: ClipRRect(
        borderRadius: radio,
        child: SizedBox(width: widget.ancho, height: widget.alto, child: contenido),
      ),
    );
    if (widget.hero && r.fotoRef != null) {
      caja = Hero(tag: FotoReporte.etiquetaHero(r), child: caja);
    }
    return caja;
  }
}

class _Silueta extends StatelessWidget {
  const _Silueta(this.reporte, this.ancho, this.alto);
  final Reporte reporte;
  final double? ancho;
  final double? alto;

  @override
  Widget build(BuildContext context) {
    final lado = math.min(ancho ?? 84, alto ?? 84);
    return ExcludeSemantics(
      child: Container(
        color: reporte.tipo.color.withValues(alpha: 0.10),
        alignment: Alignment.center,
        child: IconoTipo(reporte.tipo, tamano: lado.isFinite ? lado * 0.58 : 48),
      ),
    );
  }
}
