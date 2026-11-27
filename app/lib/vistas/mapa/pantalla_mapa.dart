import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../datos/estado.dart';
import '../../datos/zonas.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../../nucleo/base/transicion_pestanas.dart';
import '../mis_reportes/detalle_reporte.dart';
import '../reporte/flujo_reporte.dart';
import 'capa_prioridad.dart';
import 'controles.dart';
import 'hojas.dart';
import 'marcadores.dart';
import 'modelo.dart';

/// El mapa: responde de un vistazo «¿dónde pasa ahora y con qué prioridad?».
///
/// Zonas de manglar (polígonos de la CRA, creados una sola vez), mis reportes y los
/// públicos, coloreados por prioridad. Lo propio de Zanky se dibuja sin red: si las
/// teselas de OpenStreetMap no cargan, el mapa base queda en color arena y las zonas y los
/// reportes se ven igual.
class PantallaMapa extends StatefulWidget {
  const PantallaMapa({super.key});

  @override
  State<PantallaMapa> createState() => _PantallaMapaState();
}

class _Aviso {
  const _Aviso(this.texto, this.icono, {this.accion, this.alAccion});
  final String texto;
  final IconData icono;
  final String? accion;
  final VoidCallback? alAccion;
}

class _PantallaMapaState extends State<PantallaMapa>
    with TickerProviderStateMixin {
  // Región de las cuatro zonas (costa del Atlántico), por si los datos no dieran caja.
  static final _regionInicial = LatLngBounds(
    const LatLng(10.68, -75.27),
    const LatLng(11.07, -74.82),
  );
  static const _zoomMax = 18.5;
  static const _zoomMin = 8.5;

  final _mapa = MapController();
  bool _mapaListo = false;
  bool _pestanaVisible = false;

  /// Reloj único del latido de todos los marcadores recientes.
  late final AnimationController _latido = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  /// Vuelo de la cámara.
  late final AnimationController _camara = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  LatLng _vueloDesde = const LatLng(0, 0);
  LatLng _vueloHasta = const LatLng(0, 0);
  double _zoomDesde = 0;
  double _zoomHasta = 0;

  /// Nivel de zoom entero: solo cuando cambia se reagrupan los marcadores.
  final _nivel = ValueNotifier<int>(10);
  final _sinBase = ValueNotifier<bool>(false);
  final _aviso = ValueNotifier<_Aviso?>(null);

  Timer? _relojBase;
  Timer? _relojAviso;
  Timer? _relojMinuto;
  int _erroresTesela = 0;
  bool _enLineaAntes = true;

  // Capas que no cambian: se construyen una vez y se reusan (el mismo widget no se
  // reconstruye).
  late Manglar _manglar;
  bool _preparado = false;
  late final Widget _capaTeselas;
  late final Widget _capaZonas;
  late final Widget _capaContorno;
  final _capaResalte = <String, Widget>{};
  final _limitesZona = <String, LatLngBounds>{};
  late LatLngBounds _limitesTodo;
  late MapOptions _opciones;

  // Capa de prioridades de conservación de la CRA: se lee de los assets la primera vez que se
  // pide y se queda en memoria (sin red). El manglar sigue siendo la capa por defecto.
  CapaMapa _capa = CapaMapa.manglar;
  CapaPrioridadMapa? _prioridad;
  bool _cargandoPrioridad = false;
  bool _falloPrioridad = false;
  PoligonoPrioridad? _prioridadSel;

  // Datos del mapa.
  int _firma = 0;
  int _versionPuntos = 0;
  List<PuntoMapa> _puntos = const [];
  FiltroMapa _filtro = const FiltroMapa();
  int _versionFiltro = 0;
  int _tic = 0;
  DateTime _ahora = DateTime.now();

  List<PuntoMapa> _visibles = const [];
  String _claveVisibles = '';
  List<Marker> _marcadores = const [];
  String _claveMarcadores = '';

  String? _zonaSel;
  LatLng? _yo;
  double _precisionYo = 0;
  bool _buscandoYo = false;

  @override
  void initState() {
    super.initState();
    // Cada minuto se revisa qué reportes dejan de ser «recientes».
    _relojMinuto = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _tic++);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_preparado) {
      _preparado = true;
      _prepararCapas(Zanky.leer(context));
    }
    // «Reducir movimiento»: el anillo queda quieto.
    if (context.animationsDisabled && _latido.isAnimating) _latido.stop();
  }

  @override
  void dispose() {
    _relojBase?.cancel();
    _relojAviso?.cancel();
    _relojMinuto?.cancel();
    _latido.dispose();
    _camara.dispose();
    _nivel.dispose();
    _sinBase.dispose();
    _aviso.dispose();
    _mapa.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ capas

  void _prepararCapas(EstadoZanky e) {
    _manglar = e.manglar;
    _limitesTodo = _manglar.zonas.isEmpty
        ? _regionInicial
        : limitesDe(_manglar.zonas.expand((z) => z.cajas));
    final relleno = Zc.hoja.withValues(alpha: 0.35);
    final borde = Color.lerp(Zc.hoja, Zc.raiz, 0.5)!;

    // Los 144 polígonos (~21 000 vértices) se crean aquí, una sola vez. flutter_map los
    // simplifica según el zoom y deja de dibujar los que quedan fuera de la pantalla.
    final base = <Polygon>[];
    final contorno = <Polygon>[];
    final bordeContorno = Zc.raiz.withValues(alpha: 0.85);
    for (final z in _manglar.zonas) {
      _limitesZona[z.id] = limitesDe(z.cajas);
      for (final anillo in z.poligonos) {
        base.add(
          Polygon(
            points: anillo,
            color: relleno,
            borderColor: borde,
            borderStrokeWidth: 1.4,
          ),
        );
        contorno.add(Polygon(points: anillo, borderColor: bordeContorno, borderStrokeWidth: 1.2));
      }
      _capaResalte[z.id] = PolygonLayer(
        polygons: [
          for (final anillo in z.poligonos)
            Polygon(
              points: anillo,
              color: Zc.hoja.withValues(alpha: 0.22),
              borderColor: Zc.raiz,
              borderStrokeWidth: 3,
            ),
        ],
        polygonCulling: true,
      );
    }
    _capaZonas = PolygonLayer(polygons: base, polygonCulling: true);
    // Con la capa de prioridades, el manglar queda solo como contorno (sin relleno que mezcle).
    _capaContorno = PolygonLayer(polygons: contorno, polygonCulling: true);

    _capaTeselas = TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'co.zanky.app',
      maxNativeZoom: 19,
      // Una tesela que falló se vuelve a pedir cuando se la mira de nuevo.
      evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
      errorTileCallback: _errorTesela,
    );

    final arriba = MediaQuery.viewPaddingOf(context).top;
    _opciones = MapOptions(
      // Cámara de partida DENTRO de la restricción: con un MapController propio,
      // flutter_map (en depuración) comprueba esa cámara antes de aplicar el ajuste
      // a los límites, y el (0, 0) por defecto cae fuera de la costa.
      initialCenter: _limitesTodo.center,
      initialZoom: 10,
      initialCameraFit: CameraFit.bounds(
        bounds: _limitesTodo,
        padding: EdgeInsets.fromLTRB(44, arriba + 110, 44, 200),
        maxZoom: 13,
      ),
      minZoom: _zoomMin,
      maxZoom: _zoomMax,
      // El mapa no se sale de la costa y sus alrededores.
      cameraConstraint: CameraConstraint.containCenter(
        bounds: LatLngBounds(
          LatLng(_limitesTodo.south - 0.6, _limitesTodo.west - 0.6),
          LatLng(_limitesTodo.north + 0.6, _limitesTodo.east + 0.6),
        ),
      ),
      // Sin rotación: los marcadores y el norte siempre derechos.
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
      ),
      backgroundColor: Zc.arena,
      onMapReady: _alEstarListo,
      onPositionChanged: (camara, _) => _fijarNivel(camara.zoom.floor()),
      onPointerDown: (_, _) {
        // El dedo manda: si la cámara volaba, se detiene.
        if (_camara.isAnimating) _camara.stop();
      },
      onTap: _alTocarMapa,
      // Mantener presionado (o clic derecho en la web): «Reportar aquí» con el punto ya marcado.
      onLongPress: (_, p) => _reportarAqui(p),
      onSecondaryTap: (_, p) => _reportarAqui(p),
    );
  }

  void _alEstarListo() {
    _mapaListo = true;
    _fijarNivel(_mapa.camera.zoom.floor());
    if (_pestanaVisible) _empujarTeselas();
  }

  /// Una pestaña precargada se arma escondida y el TileLayer no pide teselas hasta que
  /// la cámara se mueve. Un movimiento de una millonésima de zoom, invisible, lo despierta.
  void _empujarTeselas() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapaListo || !_pestanaVisible) return;
      final c = _mapa.camera;
      _mapa.move(c.center, c.zoom + 1e-6);
    });
  }

  /// Cambia el nivel de zoom sin tocar un notificador mientras Flutter construye.
  void _fijarNivel(int n) {
    if (n == _nivel.value) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nivel.value = n;
      });
    } else {
      _nivel.value = n;
    }
  }

  void _errorTesela(TileImage tesela, Object error, StackTrace? traza) {
    // Una tesela que dejó de pedirse porque ya no se ve no es un fallo de red.
    if (tesela.cancelLoading.isCompleted) return;
    _erroresTesela++;
    _relojBase?.cancel();
    // Si pasan 15 s sin nuevos fallos, la nota se quita sola.
    _relojBase = Timer(const Duration(seconds: 15), () {
      _erroresTesela = 0;
      if (mounted) _sinBase.value = false;
    });
    // Con un par de fallos seguidos ya no es casualidad.
    if (_erroresTesela >= 2 && !_sinBase.value) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sinBase.value = true;
      });
    }
  }

  // ------------------------------------------------------------------ datos

  void _actualizarDatos(EstadoZanky e) {
    // Al volver la señal, la nota del mapa base se limpia: si sigue fallando, reaparece.
    if (e.enLinea && !_enLineaAntes) {
      _erroresTesela = 0;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sinBase.value = false;
      });
    }
    _enLineaAntes = e.enLinea;

    final firma = firmaPuntos(e);
    if (firma != _firma) {
      _firma = firma;
      _puntos = construirPuntos(e);
      _versionPuntos++;
    }
    final clave = '$_versionPuntos/$_versionFiltro/$_tic';
    if (clave != _claveVisibles) {
      _claveVisibles = clave;
      _ahora = DateTime.now();
      _visibles = [
        for (final p in _puntos)
          if (_filtro.pasa(p, _ahora)) p,
      ];
    }
    final debeLatir =
        !context.animationsDisabled &&
        _visibles.any((p) => p.esReciente(_ahora));
    if (debeLatir && !_latido.isAnimating) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_latido.isAnimating) _latido.repeat();
      });
    } else if (!debeLatir && _latido.isAnimating) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _latido.stop();
      });
    }
  }

  List<Marker> _marcadoresPara(int nivel) {
    final clave = '$nivel/$_claveVisibles/${context.animationsDisabled}';
    if (clave == _claveMarcadores) return _marcadores;
    _claveMarcadores = clave;
    final latir = !context.animationsDisabled;
    _marcadores = [
      for (final g in agrupar(_visibles, nivel))
        if (g.esUno)
          Marker(
            key: ValueKey('p-${g.puntos.first.id}'),
            point: g.centro,
            width: cajaMarcador,
            height: cajaMarcador,
            child: MarcadorPunto(
              punto: g.puntos.first,
              latido: _latido,
              latir: latir,
              reciente: g.puntos.first.esReciente(_ahora),
              alTocar: () => _abrirPunto(g.puntos.first),
            ),
          )
        else
          Marker(
            key: ValueKey('g-${g.puntos.first.id}-${g.puntos.length}'),
            point: g.centro,
            width: cajaMarcador,
            height: cajaMarcador,
            child: MarcadorGrupo(grupo: g, alTocar: () => _acercarAGrupo(g)),
          ),
    ];
    return _marcadores;
  }

  // ------------------------------------------------------------------ cámara

  /// Vuelo suave: interpola centro y zoom con la curva de entrada de la app. Devuelve
  /// false si el dedo lo interrumpió (o si el mapa aún no está listo).
  Future<bool> _volar(LatLng centro, double zoom) async {
    if (!_mapaListo || !mounted) return false;
    _camara.stop();
    final z = zoom.clamp(_zoomMin, _zoomMax).toDouble();
    if (context.animationsDisabled) {
      _mapa.move(centro, z);
      return true;
    }
    final cam = _mapa.camera;
    _vueloDesde = cam.center;
    _zoomDesde = cam.zoom;
    _vueloHasta = centro;
    _zoomHasta = z;
    _camara.removeListener(_pasoVuelo);
    _camara.addListener(_pasoVuelo);
    _camara.value = 0;
    try {
      await _camara.animateTo(1, curve: Zm.entrar).orCancel;
      return true;
    } on TickerCanceled {
      return false;
    }
  }

  void _pasoVuelo() {
    final t = _camara.value;
    _mapa.move(
      LatLng(
        _vueloDesde.latitude +
            (_vueloHasta.latitude - _vueloDesde.latitude) * t,
        _vueloDesde.longitude +
            (_vueloHasta.longitude - _vueloDesde.longitude) * t,
      ),
      _zoomDesde + (_zoomHasta - _zoomDesde) * t,
    );
  }

  /// Encuadra unos límites dejando libre lo que tapan los controles y la hoja.
  Future<bool> _encuadrar(LatLngBounds limites, {double zoomMax = 16}) {
    final arriba = MediaQuery.viewPaddingOf(context).top;
    final ajuste = CameraFit.bounds(
      bounds: limites,
      padding: EdgeInsets.fromLTRB(36, arriba + 96, 36, 300),
      maxZoom: zoomMax,
    ).fit(_mapa.camera);
    return _volar(ajuste.center, ajuste.zoom);
  }

  void _verTodo() {
    setState(() => _zonaSel = null);
    _encuadrar(_limitesTodo, zoomMax: 13);
  }

  Future<void> _irAZona(ZonaManglar z) async {
    setState(() => _zonaSel = z.id);
    final llego = await _encuadrar(_limitesZona[z.id]!);
    if (llego && mounted && _zonaSel == z.id) _abrirZona(z);
  }

  void _acercarAGrupo(GrupoMapa g) {
    final lat = g.puntos.map((p) => p.punto.latitude);
    final lon = g.puntos.map((p) => p.punto.longitude);
    final minLat = lat.reduce(math.min), maxLat = lat.reduce(math.max);
    final minLon = lon.reduce(math.min), maxLon = lon.reduce(math.max);
    // Puntos casi encimados: no hay caja que encuadrar, basta con acercar.
    if ((maxLat - minLat).abs() < 1e-5 && (maxLon - minLon).abs() < 1e-5) {
      _volar(g.centro, math.max(_mapa.camera.zoom + 2, nivelSinAgrupar + 0.5));
      return;
    }
    final ajuste = CameraFit.bounds(
      bounds: LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon)),
      padding: const EdgeInsets.all(80),
      maxZoom: nivelSinAgrupar + 1.5,
    ).fit(_mapa.camera);
    // Siempre se acerca al menos un nivel, para que el grupo se abra.
    _volar(ajuste.center, math.max(ajuste.zoom, _mapa.camera.zoom + 1));
  }

  // ------------------------------------------------------------------ capa de prioridades

  void _elegirCapa(CapaMapa c) {
    if (c == _capa) return;
    setState(() {
      _capa = c;
      _prioridadSel = null;
    });
    if (c == CapaMapa.prioridad && _prioridad == null) _cargarPrioridad();
  }

  Future<void> _cargarPrioridad() async {
    if (_cargandoPrioridad) return;
    setState(() {
      _cargandoPrioridad = true;
      _falloPrioridad = false;
    });
    try {
      final capa = await CapaPrioridadMapa.cargador();
      if (!mounted) return;
      setState(() => _prioridad = capa);
    } catch (_) {
      if (mounted) setState(() => _falloPrioridad = true);
    } finally {
      if (mounted) setState(() => _cargandoPrioridad = false);
    }
  }

  /// Hoja del polígono de prioridad tocado; mientras está abierta, queda resaltado.
  Future<void> _abrirPrioridad(PoligonoPrioridad q) async {
    setState(() => _prioridadSel = q);
    await abrirHojaPrioridad(context, poligono: q);
    if (mounted && _prioridadSel == q) setState(() => _prioridadSel = null);
  }

  /// El polígono resaltado: un solo `Polygon` con el borde gordo (se arma al tocar).
  Widget _capaPrioridadSel() {
    final q = _prioridadSel;
    if (q == null) return const SizedBox.shrink();
    List<LatLng> pts(Float64List r) => [for (var i = 0; i < r.length; i += 2) LatLng(r[i + 1], r[i])];
    return PolygonLayer(
      polygons: [
        Polygon(
          points: pts(q.anillos.first),
          holePointsList: q.anillos.length > 1 ? [for (var h = 1; h < q.anillos.length; h++) pts(q.anillos[h])] : null,
          color: colorPrioridadCra(q.prioridad).withValues(alpha: 0.2),
          borderColor: Zc.raiz,
          borderStrokeWidth: 3,
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ toques y hojas

  /// El punto donde se mantuvo presionado pasa al flujo de reporte ya marcado. Antes se
  /// confirma en una hoja con el botón visible: nada ocurre por un gesto accidental.
  Future<void> _reportarAqui(LatLng p) async {
    vibrar(Vibracion.media);
    final u = _manglar.ubicar(p);
    final dentro = u.dentro;
    final ok = await mostrarHojaZ<bool>(
      context,
      nombre: 'mapa/reportar_aqui',
      contenido: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(header: true, child: Text('¿Reportar aquí?', style: Theme.of(ctx).textTheme.titleLarge)),
          const SizedBox(height: 6),
          Text(
            dentro
                ? 'Este punto está dentro de ${u.zona.nombre}. Lo dejo marcado y tú cuentas qué viste.'
                : 'Este punto queda fuera del manglar, cerca de ${u.zona.nombre}. Lo dejo marcado y puedes moverlo después.',
            style: Theme.of(ctx).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          BotonZ(texto: 'Reportar aquí', icono: Icons.add_a_photo_rounded, onTap: () => Navigator.pop(ctx, true)),
          const SizedBox(height: 8),
          BotonZ(texto: 'Cancelar', secundario: true, color: Zc.textoSuave, onTap: () => Navigator.pop(ctx, false)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    abrirReporte(context, punto: p);
  }

  void _alTocarMapa(TapPosition posicion, LatLng p) {
    if (_capa == CapaMapa.prioridad) {
      final q = _prioridad?.en(p);
      if (q != null) {
        _abrirPrioridad(q);
        return;
      }
    }
    final u = _manglar.ubicar(p);
    // Un poco de margen para el dedo: los bordes del manglar son finos.
    final margen = metrosPorPixel(p.latitude, _mapa.camera.zoom) * 18;
    if (u.dentro || u.distanciaM <= margen) {
      setState(() => _zonaSel = u.zona.id);
      _abrirZona(u.zona);
    } else if (_zonaSel != null) {
      setState(() => _zonaSel = null);
    }
  }

  void _abrirZona(ZonaManglar z) {
    final aqui = _puntos.where((p) => p.zonaId == z.id).toList();
    final ahora = DateTime.now();
    abrirHojaZona(
      context,
      zona: z,
      reportes: aqui.length,
      ultimas24h: aqui
          .where(
            (p) => ahora.difference(p.capturadoEn) < const Duration(hours: 24),
          )
          .length,
      mios: aqui.where((p) => p.esMio).length,
      textoVacio: _textoVacio(Zanky.leer(context), enZona: true),
      alReportar: () => _reportar(zonaId: z.id),
    );
  }

  void _abrirPunto(PuntoMapa p) {
    final propia = p.mio?.zonaNombre ?? '';
    abrirHojaPunto(
      context,
      punto: p,
      zonaNombre: propia.isNotEmpty ? propia : nombreDeZona(_manglar, p.zonaId),
      alVerDetalle: () {
        final r = p.mio;
        if (!mounted || r == null) return;
        abrirDetalleReporte(context, r);
      },
    );
  }

  void _reportar({String? zonaId}) {
    if (!mounted) return;
    abrirReporte(context, zonaId: zonaId);
  }

  /// Qué decir cuando no hay reportes de otras personas: la verdad sobre por qué.
  /// «Todavía no hay» solo si el servidor respondió con la lista vacía.
  static String _textoVacio(EstadoZanky e, {bool enZona = false}) {
    if (!e.servidor.configurado) {
      return enZona
          ? 'Modo demostración: aquí solo ves tus reportes; los de otras personas llegan con la versión conectada.'
          : 'Modo demostración: aquí solo ves tus reportes. Los de otras personas llegan con la versión conectada.';
    }
    if (!e.enLinea || e.ultimaSincronizacion == null) {
      return 'No pude traer los reportes de otras personas. Se actualizan solos cuando hay señal.';
    }
    return enZona
        ? 'Todavía no hay reportes en esta zona.'
        : 'Todavía no hay reportes aquí. Si ves algo, sé el primero.';
  }

  void _abrirFiltro() {
    abrirHojaFiltro(
      context,
      inicial: _filtro,
      total: _puntos.length,
      contar: (f) {
        final ahora = DateTime.now();
        return _puntos.where((p) => f.pasa(p, ahora)).length;
      },
      alCambiar: (f) {
        if (!mounted) return;
        setState(() {
          _filtro = f;
          _versionFiltro++;
        });
      },
    );
  }

  // ------------------------------------------------------------------ mi ubicación

  void _mostrarAviso(_Aviso a) {
    _aviso.value = a;
    _relojAviso?.cancel();
    _relojAviso = Timer(const Duration(seconds: 8), () => _aviso.value = null);
  }

  Future<void> _miUbicacion() async {
    if (_buscandoYo) return;
    setState(() => _buscandoYo = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _mostrarAviso(
          const _Aviso(
            'El GPS del teléfono está apagado. Enciéndelo para ver dónde estás.',
            Icons.location_disabled_rounded,
            accion: 'Abrir ajustes',
            alAccion: Geolocator.openLocationSettings,
          ),
        );
        return;
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.unableToDetermine) {
        if (!mounted) return;
        // Primero se explica para qué; después sale el permiso del sistema.
        if (!await explicarUbicacion(context) || !mounted) return;
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.deniedForever) {
        _mostrarAviso(
          const _Aviso(
            'La ubicación está bloqueada para Zanky. Puedes activarla en los ajustes del teléfono.',
            Icons.location_off_rounded,
            accion: 'Abrir ajustes',
            alAccion: Geolocator.openAppSettings,
          ),
        );
        return;
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.unableToDetermine) {
        _mostrarAviso(
          const _Aviso(
            'Sin permiso no puedo mostrarte dónde estás. El mapa y los reportes siguen funcionando igual.',
            Icons.location_off_rounded,
          ),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final aqui = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _yo = aqui;
        _precisionYo = pos.accuracy;
      });
      await _volar(aqui, math.max(_mapa.camera.zoom, 15.5));
    } on TimeoutException {
      _mostrarAviso(
        const _Aviso(
          'No logré ubicarte a tiempo. Sal a un sitio abierto y vuelve a intentar.',
          Icons.gps_not_fixed_rounded,
        ),
      );
    } catch (_) {
      _mostrarAviso(
        const _Aviso(
          'No pude obtener tu ubicación ahora. Inténtalo otra vez en un momento.',
          Icons.gps_not_fixed_rounded,
        ),
      );
    } finally {
      if (mounted) setState(() => _buscandoYo = false);
    }
  }

  // ------------------------------------------------------------------ pantalla

  @override
  Widget build(BuildContext context) {
    final estado = Zanky.de(context);
    _actualizarDatos(estado);

    // Solo al pasar de escondida a visible (nunca mientras está escondida).
    final visible = PestanaVisible.de(context);
    if (visible != _pestanaVisible) {
      _pestanaVisible = visible;
      if (visible && _mapaListo) _empujarTeselas();
    }

    final vista = MediaQuery.viewPaddingOf(context);
    // La barra de pestañas mide 72 px y flota a 12 px del borde (o sobre el gesto del sistema).
    final base = (vista.bottom > 0 ? vista.bottom : 12.0) + 72 + 8;
    final escala = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, 1.6).toDouble();
    final yo = _yo;

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapa,
            options: _opciones,
            children: [
              _capaTeselas,
              _capa == CapaMapa.manglar ? _capaZonas : const SizedBox.shrink(),
              if (_capa == CapaMapa.prioridad) ...[
                _prioridad?.capa ?? const SizedBox.shrink(),
                _capaPrioridadSel(),
                _capaContorno,
              ],
              _capaResalte[_zonaSel] ?? const SizedBox.shrink(),
              // Con el mapa lejos, el nombre de cada zona (de cerca, el polígono habla solo).
              ValueListenableBuilder<int>(
                valueListenable: _nivel,
                builder: (_, nivel, _) => MarkerLayer(
                  markers: nivel > 12
                      ? const []
                      : [
                          for (final z in _manglar.zonas)
                            Marker(
                              key: ValueKey('z-${z.id}'),
                              point: z.centro,
                              width: 44,
                              height: 44,
                              child: EtiquetaZona(
                                nombre: z.nombre,
                                alTocar: () => _irAZona(z),
                              ),
                            ),
                        ],
                ),
              ),
              CircleLayer(
                circles: [
                  if (yo != null)
                    CircleMarker(
                      point: yo,
                      radius: math.max(_precisionYo, 8),
                      useRadiusInMeter: true,
                      color: PuntoYo.azul.withValues(alpha: 0.14),
                      borderColor: PuntoYo.azul.withValues(alpha: 0.5),
                      borderStrokeWidth: 1.5,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (yo != null)
                    Marker(
                      point: yo,
                      width: 36,
                      height: 36,
                      child: const PuntoYo(),
                    ),
                ],
              ),
              ValueListenableBuilder<int>(
                valueListenable: _nivel,
                builder: (_, nivel, _) =>
                    MarkerLayer(markers: _marcadoresPara(nivel)),
              ),
            ],
          ),
        ),
        // Arriba: filtro, zonas y avisos.
        Positioned(
          top: vista.top + 10,
          left: 0,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 52 * escala,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    BotonRedondo(
                      icono: Icons.tune_rounded,
                      etiqueta: _filtro.activo
                          ? 'Filtrar reportes, hay un filtro activo'
                          : 'Filtrar reportes',
                      punto: _filtro.activo,
                      onTap: _abrirFiltro,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ShaderMask(
                        // Desvanecido a la derecha: avisa que la fila sigue.
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (r) => const LinearGradient(
                          colors: [
                            Colors.black,
                            Colors.black,
                            Colors.transparent,
                          ],
                          stops: [0, 0.88, 1],
                        ).createShader(r),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(0, 3, 28, 3),
                          clipBehavior: Clip.none,
                          children: [
                            ChipZona(
                              texto: 'Todo',
                              icono: Icons.zoom_out_map_rounded,
                              seleccionado: false,
                              onTap: _verTodo,
                            ),
                            for (final z in _manglar.zonas) ...[
                              const SizedBox(width: 8),
                              ChipZona(
                                texto: nombreCorto(z.nombre),
                                etiqueta: z.nombre,
                                seleccionado: _zonaSel == z.id,
                                onTap: () => _irAZona(z),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _sinBase,
                builder: (_, sinBase, _) => _Aparece(
                  visible: sinBase,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: PildoraAviso(
                      texto:
                          'Sin señal: el mapa base no carga, pero las zonas del manglar y tus reportes sí.',
                      icono: Icons.signal_cellular_off_rounded,
                    ),
                  ),
                ),
              ),
              ValueListenableBuilder<_Aviso?>(
                valueListenable: _aviso,
                builder: (_, aviso, _) => _Aparece(
                  visible: aviso != null,
                  child: aviso == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          child: PildoraAviso(
                            texto: aviso.texto,
                            icono: aviso.icono,
                            accion: aviso.accion,
                            alAccion: aviso.alAccion,
                            alCerrar: () => _aviso.value = null,
                          ),
                        ),
                ),
              ),
              _Aparece(
                visible: estado.pendientes > 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: PildoraAviso(
                    texto: _textoPendientes(estado),
                    icono: estado.servidor.configurado && !estado.enLinea
                        ? Icons.signal_cellular_off_rounded
                        : Icons.cloud_upload_rounded,
                    color: Zc.cienaga,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Abajo: estado vacío, leyenda, ubicación y atribución.
        Positioned(
          left: 16,
          right: 16,
          bottom: base,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_puntos.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TarjetaVaciaMapa(
                    titulo: _textoVacio(estado),
                    boton: 'Reportar',
                    onBoton: _reportar,
                  ),
                )
              else if (_visibles.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TarjetaVaciaMapa(
                    titulo: 'Ningún reporte coincide con este filtro.',
                    boton: 'Quitar filtros',
                    icono: Icons.filter_alt_off_rounded,
                    onBoton: () => setState(() {
                      _filtro = const FiltroMapa();
                      _versionFiltro++;
                    }),
                  ),
                ),
              Align(
                alignment: Alignment.bottomLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SelectorCapa(
                      capa: _capa,
                      alElegir: _elegirCapa,
                      cargando: _cargandoPrioridad,
                      fallo: _falloPrioridad,
                      alReintentar: _cargarPrioridad,
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Expanded + Align: la leyenda toma el ancho que sobra junto al botón
                  // (con Flexible y Spacer solo le tocaba la mitad y se desbordaba).
                  const Expanded(
                    child: Align(alignment: Alignment.bottomLeft, child: LeyendaMapa()),
                  ),
                  BotonRedondo(
                    icono: Icons.my_location_rounded,
                    etiqueta: 'Mi ubicación',
                    ocupado: _buscandoYo,
                    color: yo == null ? Zc.raiz : PuntoYo.azul,
                    onTap: _miUbicacion,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: AtribucionOsm(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _textoPendientes(EstadoZanky e) {
    final n = e.pendientes;
    final reportes = n == 1 ? 'tu reporte' : 'tus $n reportes';
    if (!e.servidor.configurado) {
      return 'Modo demostración: $reportes ${n == 1 ? 'queda' : 'quedan'} en este teléfono.';
    }
    if (!e.enLinea) {
      return 'Sin señal: $reportes ${n == 1 ? 'espera' : 'esperan'} para enviarse.';
    }
    return e.sincronizando
        ? 'Enviando $reportes…'
        : 'Reintentando el envío de $reportes…';
  }
}

/// Aparece y se va con un fundido y un cambio de tamaño suave, sin saltos bajo el dedo.
class _Aparece extends StatelessWidget {
  const _Aparece({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: context.resolveDuration(Zm.medio),
    curve: Zm.entrar,
    alignment: Alignment.topCenter,
    child: AnimatedSwitcher(
      duration: context.resolveDuration(Zm.corto),
      child: visible ? child : const SizedBox(width: double.infinity),
    ),
  );
}
