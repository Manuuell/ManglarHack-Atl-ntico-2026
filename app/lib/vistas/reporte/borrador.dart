import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../datos/estado.dart';
import '../../datos/fotos.dart';
import '../../datos/metadatos_foto.dart';
import '../../datos/prioridad.dart';
import '../../datos/reporte.dart';
import '../../datos/reporte_canal.dart';
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

  /// Cuándo se abrió el flujo. Solo informativo: la «hora de captura» del contrato
  /// (`capturado_en`) es la de tocar «Enviar», cuando el reporte queda guardado en el
  /// teléfono (ver [Reporte.capturadoEn]). Así el servidor no marca «sincronizado tarde» a
  /// quien tardó en llenar el formulario con señal; cuándo pasó lo dice [momento].
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
    if (_cerrado || metodo != MetodoUbicacion.gps) return;
    final mejor = precisionM == null || p.accuracy <= precisionM! + 2;
    if (!mejor) return;
    _fijar(LatLng(p.latitude, p.longitude), p.accuracy, MetodoUbicacion.gps);
    gps = EstadoGps.listo;
    if (p.accuracy <= 10) _pararGps();
    _avisar();
  }

  void _pararGps() {
    _flujoGps?.cancel();
    _flujoGps = null;
    _corteGps?.cancel();
  }

  bool get gpsActivo => _flujoGps != null;

  void _gps(EstadoGps g) {
    gps = g;
    _avisar();
  }

  // El GPS responde tarde (permisos, primera lectura): si el flujo ya se cerró, no avisa.
  bool _cerrado = false;
  void _avisar() {
    if (!_cerrado) notifyListeners();
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

  /// La foto queda sin metadatos desde aquí (sin GPS, modelo ni hora del teléfono): es la
  /// que se ve, la que se guarda, la que da la huella y la que se sube.
  void ponerFoto(Uint8List bytes, {required bool deCamara}) {
    foto = quitarMetadatos(bytes);
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

  /// Con la misma regla del servidor: sin los propios con el mismo nombre ni descartados,
  /// y contando también los públicos de otras personas.
  int get corroboraciones => punto == null || tipo == null
      ? 0
      : contarCorroboraciones(
          tipo: tipo!,
          punto: punto!,
          cuando: DateTime.now(),
          otros: estado.reportes,
          publicos: estado.publicos,
          excluirId: id,
          reportanteId: anonimo ? null : estado.perfil?.id,
        );

  Prioridad? get prioridad => tipo == null || ubicacion == null
      ? null
      : Prioridad.calcular(
          tipo: tipo!,
          ubicacion: ubicacion!,
          momento: momento,
          magnitud: magnitud,
          // El viento de la zona del reporte, no el de Mallorquín. Si no se conoce, no se suma.
          vientoKmh: estado.climaDe(ubicacion!.zona.id)?.vientoKmh,
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

  /// ¿El servidor aceptará este punto? Fuera de la caja del Atlántico lo rechaza siempre
  /// (ver [AreaServidor]); la pantalla debe decir por qué no deja seguir.
  bool get puntoAceptado => punto != null && AreaServidor.contiene(punto!);

  bool get listoParaEnviar => tipo != null && puntoAceptado;

  /// Guarda en el teléfono y deja que la cola lo envíe. Devuelve el reporte creado.
  ///
  /// Si no se puede guardar lanza [ErrorAlGuardar], cuyo `mensaje` se le puede mostrar a la
  /// persona tal cual (`sinEspacio` dice si conviene ofrecer «guardar sin foto»). Nada
  /// queda a medias: si la foto se guardó y el reporte no, la foto se borra.
  Future<Reporte> enviar() async {
    if (!puntoAceptado) {
      throw const ErrorAlGuardar(
          'Ese punto queda fuera del Atlántico y el servidor no lo recibe. Marca en el mapa dónde lo viste.');
    }
    final p = prioridad!;
    enviando = true;
    notifyListeners();
    String? ref;
    try {
      String? huella;
      if (foto != null) {
        ref = await _guardarFoto();
        huella = Fotos.huella(foto!);
      }
      final u = ubicacion!;
      final r = Reporte(
        id: id,
        tipo: tipo!,
        // El servidor cuenta puntos de código, no letras visibles (un emoji de familia son 7).
        descripcion: recortarPuntosDeCodigo(descripcion.trim()),
        punto: punto!,
        precisionM: precisionM,
        metodo: metodo,
        capturadoEn: DateTime.now(),
        momento: momento,
        magnitud: magnitud,
        zonaId: u.zona.id,
        zonaNombre: u.zona.nombre,
        municipio: u.zona.municipio,
        dentroPoligono: u.dentro,
        distanciaM: u.distanciaM,
        prioridad: p.valor,
        prioridadLocal: p.valor,
        motivosPrioridad: p.motivos,
        // Con la regla del bot y de la web, para que el panel compare igual los tres canales.
        confianza: confianzaCanal(
          conFoto: foto != null,
          fotoHash: huella,
          metodo: metodo,
          dentro: u.dentro,
          distanciaM: u.distanciaM,
          momento: momento,
          descripcion: descripcion,
          corroborados: corroboraciones,
          propios: estado.reportes,
        ).puntaje,
        anonimo: anonimo,
        reportanteId: estado.perfil?.id,
        fotoRef: ref,
        fotoHash: huella,
        fotoDeCamara: fotoDeCamara,
        capturadoSinSenal: !estado.enLinea,
        canal: kIsWeb ? 'web' : 'app',
      );
      return await estado.agregar(r, foto);
    } catch (e) {
      // El reporte no quedó guardado: la foto suelta tampoco se queda ocupando espacio.
      if (ref != null && !estado.reportes.any((x) => x.id == id)) await Fotos.borrar(ref);
      throw ErrorAlGuardar.de(e, conFoto: foto != null);
    } finally {
      enviando = false;
      _avisar();
    }
  }

  /// Guarda la foto. En la web, si falta espacio, borra antes las fotos que ningún reporte
  /// usa y prueba una vez más.
  Future<String> _guardarFoto() async {
    try {
      return await Fotos.guardar(id, foto!);
    } on ErrorAlGuardar catch (e) {
      if (!e.sinEspacio || await estado.liberarEspacio(conservar: id) == 0) rethrow;
      return Fotos.guardar(id, foto!);
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    _pararGps();
    super.dispose();
  }
}
