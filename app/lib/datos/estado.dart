import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'clima.dart';
import 'fotos.dart';
import 'guardian.dart';
import 'reporte.dart';
import 'servidor.dart';
import 'tipos.dart';
import 'zonas.dart';

/// Todo lo que la app sabe, en un solo lugar.
///
/// Offline primero: un reporte se guarda en el teléfono ANTES de intentar enviarlo, y
/// la cola se vacía sola cuando vuelve la señal (al cambiar la conectividad, al volver
/// a la app y cada 45 s mientras quede algo pendiente). Reintentar nunca duplica: el
/// id lo pone el teléfono.
class EstadoZanqui extends ChangeNotifier with WidgetsBindingObserver {
  EstadoZanqui({Servidor? servidor}) : servidor = servidor ?? Servidor();

  final Servidor servidor;
  static const _uuid = Uuid();
  static const _claveReportes = 'reportes.v1';
  static const _clavePerfil = 'perfil.v1';

  late final Manglar manglar;
  Perfil? perfil;
  final List<Reporte> reportes = [];
  List<ReportePublico> publicos = const [];
  Clima? clima;
  bool climaDeCache = false;

  bool listo = false;
  bool enLinea = true;
  bool sincronizando = false;
  DateTime? ultimaSincronizacion;

  StreamSubscription<List<ConnectivityResult>>? _red;
  Timer? _reintento;
  int _fallosSeguidos = 0;

  // ---------------------------------------------------------------- arranque

  Future<void> iniciar() async {
    manglar = await Manglar.cargar();
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getString(_clavePerfil);
    if (p != null) perfil = Perfil.fromJson(jsonDecode(p) as Map<String, dynamic>);
    final rs = prefs.getStringList(_claveReportes) ?? const [];
    for (final s in rs) {
      try {
        final r = Reporte.fromJson(jsonDecode(s) as Map<String, dynamic>);
        // Un envío que quedó «enviando» al cerrarse la app vuelve a la cola.
        if (r.envio == Envio.enviando) r.envio = Envio.enCola;
        reportes.add(r);
      } catch (_) {
        // Un registro dañado no tumba la app; se descarta solo ese.
      }
    }
    reportes.sort((a, b) => b.capturadoEn.compareTo(a.capturadoEn));

    final c = Connectivity();
    enLinea = _hayRed(await c.checkConnectivity());
    _red = c.onConnectivityChanged.listen((r) {
      final antes = enLinea;
      enLinea = _hayRed(r);
      notifyListeners();
      if (!antes && enLinea) sincronizar();
    });
    WidgetsBinding.instance.addObserver(this);

    listo = true;
    notifyListeners();

    unawaited(cargarClima());
    unawaited(sincronizar());
  }

  static bool _hayRed(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      sincronizar();
      cargarClima();
    }
  }

  @override
  void dispose() {
    _red?.cancel();
    _reintento?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ---------------------------------------------------------------- perfil

  Future<void> guardarPerfil(Perfil p) async {
    perfil = p;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clavePerfil, jsonEncode(p.toJson()));
    notifyListeners();
  }

  Perfil perfilNuevo() => Perfil(id: _uuid.v4(), creado: DateTime.now());

  Progreso get progreso => Progreso.de(reportes);

  // ---------------------------------------------------------------- reportes

  String nuevoId() => _uuid.v4();

  int get pendientes => reportes.where((r) => r.envio != Envio.enviado).length;

  /// Guarda primero (en el teléfono) y después intenta enviar.
  Future<Reporte> agregar(Reporte r, Uint8List? foto) async {
    reportes.insert(0, r);
    r.historial.add(CambioEstado(EstadoReporte.recibido, r.capturadoEn, 'Creado en el teléfono'));
    await _guardar();
    notifyListeners();
    unawaited(sincronizar());
    return r;
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_claveReportes, [for (final r in reportes) jsonEncode(r.toJson())]);
  }

  Completer<void>? _enCurso;

  /// Vacía la cola y trae el estado de lo enviado. Si ya hay una vuelta en curso,
  /// espera esa en vez de lanzar otra (dos vueltas a la vez enviarían dos veces).
  Future<void> sincronizar() async {
    if (_enCurso != null) return _enCurso!.future;
    final vuelta = _enCurso = Completer<void>();
    sincronizando = true;
    notifyListeners();
    try {
      if (!servidor.configurado) return;
      var fallo = false;
      for (final r in reportes.where((r) => r.envio != Envio.enviado).toList().reversed) {
        r.envio = Envio.enviando;
        notifyListeners();
        try {
          await servidor.enviar(r, await Fotos.leer(r.fotoRef));
          r
            ..envio = Envio.enviado
            ..enviadoEn = DateTime.now()
            ..ultimoError = null;
        } catch (e) {
          r
            ..envio = Envio.error
            ..intentos += 1
            ..ultimoError = e.toString();
          fallo = true;
        }
        await _guardar();
        notifyListeners();
      }
      await _traerEstados();
      try {
        publicos = await servidor.publicos();
      } catch (_) {
        // El mapa público es un extra: sin él la app sigue.
      }
      ultimaSincronizacion = DateTime.now();
      _fallosSeguidos = fallo ? _fallosSeguidos + 1 : 0;
    } finally {
      sincronizando = false;
      _programarReintento();
      notifyListeners();
      _enCurso = null;
      vuelta.complete();
    }
  }

  Future<void> _traerEstados() async {
    final ids = [for (final r in reportes) if (r.envio == Envio.enviado) r.id];
    if (ids.isEmpty) return;
    final List<EstadoRemoto> remotos;
    try {
      remotos = await servidor.estados(ids.take(100).toList());
    } catch (_) {
      return;
    }
    var cambio = false;
    for (final e in remotos) {
      final r = reportes.where((x) => x.id == e.id).firstOrNull;
      if (r == null) continue;
      if (e.prioridad != null) r.prioridad = e.prioridad!;
      if (e.confianza != null) r.confianza = e.confianza!;
      if (r.estado != e.estado) {
        r.estado = e.estado;
        r.historial.add(CambioEstado(e.estado, e.actualizado ?? DateTime.now(), e.nota));
        cambio = true;
      }
    }
    if (cambio) await _guardar();
  }

  /// Con algo pendiente, reintenta con espera creciente (45 s, 90 s… hasta 5 min).
  void _programarReintento() {
    _reintento?.cancel();
    if (pendientes == 0 || !servidor.configurado) return;
    final s = math.min(300, 45 * math.pow(2, math.min(_fallosSeguidos, 3)).toInt());
    _reintento = Timer(Duration(seconds: s), sincronizar);
  }

  // ---------------------------------------------------------------- clima

  Future<void> cargarClima() async {
    final z = manglar.zonas.first; // Mallorquín: la prioridad del equipo
    final nuevo = await Clima.leer(z.id, z.centro);
    if (nuevo != null) {
      clima = nuevo;
      climaDeCache = false;
    } else {
      clima ??= await Clima.ultimo(z.id);
      climaDeCache = clima != null;
    }
    notifyListeners();
  }
}

/// Publica el estado al árbol de widgets sin dependencias extra.
class Zanqui extends InheritedNotifier<EstadoZanqui> {
  const Zanqui({super.key, required EstadoZanqui estado, required super.child}) : super(notifier: estado);

  static EstadoZanqui de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Zanqui>()!.notifier!;

  static EstadoZanqui leer(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<Zanqui>()!.widget as Zanqui).notifier!;
}
