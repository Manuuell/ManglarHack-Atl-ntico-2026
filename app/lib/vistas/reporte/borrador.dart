import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../datos/estado.dart';
import '../../datos/fotos.dart';
import '../../datos/prioridad.dart';
import '../../datos/reporte.dart';
import '../../datos/tipos.dart';
import '../../datos/zonas.dart';

/// Qué pasa con el GPS ahora mismo, para decírselo a la persona sin jerga.
enum EstadoGps { buscando, listo, sinPermiso, apagado, noDisponible }

/// El reporte mientras se arma. Vive lo que dura el flujo.
///
/// El GPS arranca apenas se abre el flujo (no en el paso de ubicación): mientras la
/// persona elige el tipo, el receptor ya va afinando. Se queda con la lectura más
/// precisa y se detiene sola a los 25 s o al llegar a ±10 m, para no gastar batería.
class Borrador extends ChangeNotifier {
  Borrador(this.estado, {this.tipo})
      : id = estado.nuevoId(),
        anonimo = estado.perfil?.anonimoPorDefecto ?? false,
        visto = DateTime.now() {
    _iniciarGps();
  }

  final EstadoZanky estado;
  final String id;

  /// Cuándo lo vio: al abrir el flujo. Es la «hora de captura» del contrato.
  final DateTime visto;

  TipoAmenaza? tipo;

  // Ubicación
  LatLng? punto;
  double? precisionM;
  MetodoUbicacion metodo = MetodoUbicacion.gps;
  Ubicacion? ubicacion;
  EstadoGps gps = EstadoGps.buscando;
  StreamSubscription<Position>? _flujoGps;
  Timer? _corteGps;

  // Evidencia
  Uint8List? foto;
  bool fotoDeCamara = false;

  // Detalles
  Momento momento = Momento.ahora;
  Magnitud magnitud = Magnitud.pequena;
  String descripcion = '';
  bool anonimo;

  bool enviando = false;

  // ----------------------------------------------------------------- GPS

  Future<void> _iniciarGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _gps(EstadoGps.apagado);
        return;
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        _gps(EstadoGps.sinPermiso);
        return;
      }
      _gps(EstadoGps.buscando);
      await _flujoGps?.cancel();
      _flujoGps = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0),
      ).listen(_lectura, onError: (_) => _gps(EstadoGps.noDisponible));
      _corteGps?.cancel();
      _corteGps = Timer(const Duration(seconds: 25), _pararGps);
    } catch (_) {
      _gps(EstadoGps.noDisponible);
    }
  }

  void _lectura(Position p) {
    // Si la persona ya marcó a mano o pegó un enlace, el GPS no le pisa el punto.
    if (metodo != MetodoUbicacion.gps) return;
    final mejor = precisionM == null || p.accuracy <= precisionM! + 2;
    if (!mejor) return;
    _fijar(LatLng(p.latitude, p.longitude), p.accuracy, MetodoUbicacion.gps);
    gps = EstadoGps.listo;
    if (p.accuracy <= 10) _pararGps();
    notifyListeners();
  }

  void _pararGps() {
    _flujoGps?.cancel();
    _flujoGps = null;
    _corteGps?.cancel();
  }

  bool get gpsActivo => _flujoGps != null;

  void _gps(EstadoGps g) {
    gps = g;
    notifyListeners();
  }

  /// «Usar mi ubicación» otra vez (por ejemplo, tras moverse o dar el permiso).
  Future<void> reintentarGps() async {
    metodo = MetodoUbicacion.gps;
    precisionM = null;
    await _iniciarGps();
  }

  Future<bool> abrirAjustesUbicacion() async =>
      gps == EstadoGps.apagado ? Geolocator.openLocationSettings() : Geolocator.openAppSettings();

  void marcarEnMapa(LatLng p) {
    _pararGps();
    _fijar(p, null, MetodoUbicacion.mapa);
    notifyListeners();
  }

  void desdeEnlace(LatLng p) {
    _pararGps();
    _fijar(p, null, MetodoUbicacion.enlace);
    notifyListeners();
  }

  void _fijar(LatLng p, double? precision, MetodoUbicacion m) {
    punto = p;
    precisionM = precision;
    metodo = m;
    ubicacion = estado.manglar.ubicar(p);
  }

  // ----------------------------------------------------------------- foto

  void ponerFoto(Uint8List bytes, {required bool deCamara}) {
    foto = bytes;
    fotoDeCamara = deCamara;
    notifyListeners();
  }

  void quitarFoto() {
    foto = null;
    fotoDeCamara = false;
    notifyListeners();
  }

  // ----------------------------------------------------------------- detalles

  void cambiar(void Function() f) {
    f();
    notifyListeners();
  }

  bool get tieneAlgo => tipo != null || foto != null || descripcion.trim().isNotEmpty;

  int get corroboraciones => punto == null || tipo == null
      ? 0
      : contarCorroboraciones(tipo: tipo!, punto: punto!, cuando: visto, otros: estado.reportes, excluirId: id);

  Prioridad? get prioridad => tipo == null || ubicacion == null
      ? null
      : Prioridad.calcular(
          tipo: tipo!,
          ubicacion: ubicacion!,
          momento: momento,
          magnitud: magnitud,
          vientoKmh: estado.clima?.vientoKmh,
          corroboraciones: corroboraciones,
        );

  Solidez get solidez => Solidez.calcular(
        tieneFoto: foto != null,
        fotoDeCamara: fotoDeCamara,
        metodo: metodo,
        precisionM: precisionM,
        ubicacion: ubicacion,
        descripcion: descripcion,
        momento: momento,
        anonimo: anonimo,
      );

  bool get listoParaEnviar => tipo != null && punto != null;

  /// Guarda en el teléfono y deja que la cola lo envíe. Devuelve el reporte creado.
  Future<Reporte> enviar() async {
    final p = prioridad!;
    enviando = true;
    notifyListeners();
    try {
      String? ref, huella;
      if (foto != null) {
        ref = await Fotos.guardar(id, foto!);
        huella = Fotos.huella(foto!);
      }
      final u = ubicacion!;
      final r = Reporte(
        id: id,
        tipo: tipo!,
        descripcion: descripcion.trim(),
        punto: punto!,
        precisionM: precisionM,
        metodo: metodo,
        capturadoEn: visto,
        momento: momento,
        magnitud: magnitud,
        zonaId: u.zona.id,
        zonaNombre: u.zona.nombre,
        municipio: u.zona.municipio,
        dentroPoligono: u.dentro,
        distanciaM: u.distanciaM,
        prioridad: p.valor,
        motivosPrioridad: p.motivos,
        confianza: solidez.valor,
        anonimo: anonimo,
        reportanteId: estado.perfil?.id,
        fotoRef: ref,
        fotoHash: huella,
        fotoDeCamara: fotoDeCamara,
        capturadoSinSenal: !estado.enLinea,
        canal: kIsWeb ? 'web' : 'app',
      );
      return await estado.agregar(r, foto);
    } finally {
      enviando = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pararGps();
    super.dispose();
  }
}
