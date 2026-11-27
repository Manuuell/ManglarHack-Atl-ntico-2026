import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../servidor.dart';
import '../tipos.dart';
import 'aviso_navegador.dart';
import 'repositorio_admin.dart';
import 'reporte_admin.dart';

enum FaseAdmin { fuera, entrando, dentro }

/// Qué se decidió sobre un reporte (para el aviso con «Deshacer»).
enum AccionAdmin { aprobar, rechazar, pedirDatos }

/// Una decisión que todavía no salió al servidor: durante [ControladorAdmin.plazoDeshacer]
/// se puede deshacer sin que el servidor se entere (el esquema no permite volver atrás).
class DecisionPendiente {
  DecisionPendiente(this.accion, this.antes, this.despues, this.texto);
  final AccionAdmin accion;
  final ReporteAdmin antes;
  final ReporteAdmin despues;
  final String? texto;

  String get resumen => switch (accion) {
        AccionAdmin.aprobar => 'Reporte aprobado',
        AccionAdmin.rechazar => 'Reporte rechazado',
        AccionAdmin.pedirDatos => 'Se pidieron más datos',
      };
}

/// Todo el estado del panel de la CRA dentro de la app: sesión, bandeja, avisos de
/// reportes nuevos y decisiones con «Deshacer». Un solo lugar, sin saber de pantallas.
///
/// - Sin servidor configurado solo se puede entrar en demostración (datos locales).
/// - Con la app abierta y la sesión iniciada consulta cada [cada] (30 s) lo que llegó;
///   se detiene al irse a segundo plano y al salir.
/// - Los reportes que aparecen en una consulta (no la primera) son «nuevos»: suben el
///   contador, disparan [aviso] y, si el admin lo activó, un aviso del navegador.
class ControladorAdmin extends ChangeNotifier with WidgetsBindingObserver {
  ControladorAdmin({
    Servidor? servidor,
    DateTime Function()? reloj,
    this.cada = const Duration(seconds: 30),
    this.plazoDeshacer = const Duration(seconds: 6),
    AvisoNavegador? avisoNavegador,
  })  : servidor = servidor ?? Servidor(),
        reloj = reloj ?? DateTime.now,
        navegador = avisoNavegador ?? AvisoNavegador();

  final Servidor servidor;
  final DateTime Function() reloj;
  final Duration cada;
  final Duration plazoDeshacer;
  final AvisoNavegador navegador;

  FaseAdmin fase = FaseAdmin.fuera;
  RepositorioAdmin? _repo;
  SesionAdmin? _sesion;
  String? rol;
  String? correo;

  /// El texto de error del último intento de entrar o de consultar (nulo si todo bien).
  String? error;

  List<ReporteAdmin> reportes = const [];
  bool cargando = false;
  bool cargado = false;
  DateTime? ultimaConsulta;
  FiltroBandeja filtro = FiltroBandeja.pendientes;

  /// Ids que el equipo ya vio (al abrir la bandeja): lo demás pendiente cuenta como «nuevo».
  final Set<String> _vistos = {};
  Set<String> _conocidos = {};

  /// El último aviso de llegada, para el banner dentro de la app. Se limpia al descartarlo.
  AvisoLlegada? aviso;
  int _versionAviso = 0;

  DecisionPendiente? pendiente;
  Timer? _plazo;
  Timer? _reloj;
  bool _desechado = false;
  bool _primerPlano = true;
  bool _consultando = false;

  bool get configurado => servidor.configurado;
  bool get dentro => fase == FaseAdmin.dentro;
  bool get demostracion => _repo?.demostracion ?? false;

  /// Token de la sesión del panel para editores adicionales. Nunca se persiste.
  Future<String?> tokenParaContenido() async {
    if (!dentro || demostracion || _sesion == null) return null;
    await _renovarSesion();
    return _sesion?.token;
  }

  /// Reportes pendientes que el equipo aún no ha visto: el número del ícono.
  int get sinVer => reportes.where((r) => r.estado == EstadoReporte.recibido && !_vistos.contains(r.id)).length;

  // ---------------------------------------------------------------- sesión

  /// Entra con correo y contraseña. Lanza [ErrorPanel] si no puede (y deja [error]).
  Future<void> entrar(String correoIngresado, String clave) async {
    if (!configurado) throw const ErrorPanel('Este teléfono no tiene servidor configurado. Usa la demostración.');
    fase = FaseAdmin.entrando;
    error = null;
    _avisar();
    try {
      final (sesion, r) = await RepositorioRemoto.entrar(servidor, correoIngresado, clave, reloj());
      _sesion = sesion;
      rol = r;
      correo = sesion.correo;
      _repo = RepositorioRemoto(servidor, sesion);
      _abrir();
    } on ErrorPanel catch (e) {
      fase = FaseAdmin.fuera;
      error = e.mensaje;
      _avisar();
      rethrow;
    } catch (e) {
      fase = FaseAdmin.fuera;
      error = 'No se pudo entrar. Revisa tu conexión.';
      _avisar();
      throw ErrorPanel(error!);
    }
  }

  /// Demostración: datos locales, sin servidor. Es la única entrada sin servidor.
  void entrarDemo({List<ReporteAdmin>? semilla}) {
    _repo = RepositorioDemo(reloj, semilla: semilla);
    _sesion = null;
    rol = 'moderador_cra';
    correo = null;
    error = null;
    _abrir();
  }

  void _abrir() {
    fase = FaseAdmin.dentro;
    reportes = const [];
    cargado = false;
    _vistos.clear();
    _conocidos = {};
    aviso = null;
    WidgetsBinding.instance.addObserver(this);
    _arrancarReloj();
    _avisar();
    unawaited(actualizar());
  }

  void salir() {
    _plazo?.cancel();
    final p = pendiente;
    pendiente = null;
    // Lo decidido no se pierde al salir: se manda ya.
    if (p != null) unawaited(_enviar(p));
    _reloj?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    fase = FaseAdmin.fuera;
    _repo = null;
    _sesion = null;
    rol = null;
    correo = null;
    reportes = const [];
    cargado = false;
    aviso = null;
    error = null;
    _avisar();
  }

  void _arrancarReloj() {
    _reloj?.cancel();
    if (cada <= Duration.zero) return;
    _reloj = Timer.periodic(cada, (_) {
      if (_primerPlano) unawaited(actualizar(silencioso: true));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final antes = _primerPlano;
    _primerPlano = state == AppLifecycleState.resumed;
    if (!antes && _primerPlano && dentro) unawaited(actualizar(silencioso: true));
  }

  @override
  void dispose() {
    _desechado = true;
    _plazo?.cancel();
    _reloj?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _avisar() {
    if (!_desechado) notifyListeners();
  }

  // ---------------------------------------------------------------- bandeja

  /// Trae los reportes. En la primera carga nada es «nuevo»; en las siguientes, lo que
  /// no estaba. [silencioso]: sin esqueleto ni error visible si falla (consulta periódica).
  Future<void> actualizar({bool silencioso = false}) async {
    final repo = _repo;
    if (repo == null || _consultando) return;
    _consultando = true;
    if (!silencioso && !cargado) {
      cargando = true;
      _avisar();
    }
    try {
      await _renovarSesion();
      final lista = await repo.listar();
      if (_repo != repo) return; // salió o cambió mientras esperaba
      final llegaron = cargado ? [for (final r in lista) if (!_conocidos.contains(r.id)) r] : <ReporteAdmin>[];
      // Lo que el equipo decidió y aún no salió al servidor se sigue viendo como decidido.
      final p = pendiente;
      reportes = [for (final r in lista) (p != null && r.id == p.antes.id) ? p.despues : r];
      _conocidos = {for (final r in lista) r.id};
      cargado = true;
      error = null;
      ultimaConsulta = reloj();
      if (llegaron.isNotEmpty) _avisarLlegada(llegaron);
    } on ErrorPanel catch (e) {
      if (e.sinSesion) {
        salir();
        error = e.mensaje;
      } else if (!silencioso || !cargado) {
        error = e.mensaje;
      }
    } catch (_) {
      if (!silencioso || !cargado) error = 'No se pudieron traer los reportes.';
    } finally {
      cargando = false;
      _consultando = false;
      _avisar();
    }
  }

  Future<void> _renovarSesion() async {
    final s = _sesion;
    if (s != null && s.porVencer(reloj())) await RepositorioRemoto.refrescar(servidor, s, reloj());
  }

  /// Bandeja propia del encargado; usa la sesión del panel sin guardarla en disco.
  Future<List<Map<String, dynamic>>> avisosZona() async {
    final repo = _repo;
    if (repo is! RepositorioRemoto) return const [];
    await _renovarSesion();
    if (_repo != repo) return const [];
    return repo.avisosZona();
  }

  void _avisarLlegada(List<ReporteAdmin> nuevos) {
    nuevos.sort((a, b) => b.prioridad.compareTo(a.prioridad));
    final a = AvisoLlegada(nuevos, ++_versionAviso);
    aviso = a;
    if (navegador.activo) navegador.mostrar(a.titulo, a.cuerpo);
  }

  void descartarAviso() {
    if (aviso == null) return;
    aviso = null;
    _avisar();
  }

  /// El equipo abrió la bandeja: lo que había deja de contar como nuevo.
  void marcarVistos() {
    final antes = sinVer;
    _vistos.addAll(reportes.map((r) => r.id));
    aviso = null;
    if (antes != 0) _avisar();
  }

  void cambiarFiltro(FiltroBandeja f) {
    if (f == filtro) return;
    filtro = f;
    _avisar();
  }

  List<ReporteAdmin> get visibles => bandeja(reportes, filtro);
  Map<FiltroBandeja, int> get conteos => contarPorFiltro(reportes);

  /// Solo demostración: hace llegar un reporte para ver el aviso y el contador.
  void simularLlegada() {
    final r = _repo;
    if (r is RepositorioDemo) {
      r.simularLlegada();
      unawaited(actualizar(silencioso: true));
    }
  }

  Future<Uint8List?> foto(ReporteAdmin r) => _repo?.foto(r) ?? Future.value(null);

  // ---------------------------------------------------------------- decisiones

  /// Decide sobre un reporte. Se ve al instante y sale al servidor pasados
  /// [plazoDeshacer], a menos que se llame a [deshacer]. Si ya había una decisión
  /// esperando, esa sale primero.
  Future<void> decidir(AccionAdmin accion, ReporteAdmin r, {String? texto}) async {
    final repo = _repo;
    if (repo == null) return;
    final previa = pendiente;
    if (previa != null) {
      _plazo?.cancel();
      pendiente = null;
      await _enviar(previa);
    }
    final despues = switch (accion) {
      AccionAdmin.aprobar => r.conEstado(EstadoReporte.verificado),
      AccionAdmin.rechazar => r.conEstado(EstadoReporte.descartado, notaPublica: texto),
      AccionAdmin.pedirDatos => r.conEstado(EstadoReporte.enVerificacion, notaPublica: texto),
    };
    final d = DecisionPendiente(accion, r, despues, texto);
    pendiente = d;
    reportes = [for (final x in reportes) x.id == r.id ? despues : x];
    _avisar();
    _plazo = Timer(plazoDeshacer, () {
      if (pendiente == d) {
        pendiente = null;
        unawaited(_enviar(d));
      }
    });
  }

  /// Le quita la decisión a un reporte que aún no salió al servidor.
  void deshacer() {
    final d = pendiente;
    if (d == null) return;
    _plazo?.cancel();
    pendiente = null;
    reportes = [for (final x in reportes) x.id == d.antes.id ? d.antes : x];
    _avisar();
  }

  /// Si el servidor rechaza la decisión, se deja el motivo aquí para mostrarlo.
  String? fallo;

  Future<void> _enviar(DecisionPendiente d) async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final ReporteAdmin nuevo = switch (d.accion) {
        AccionAdmin.aprobar => await repo.aprobar(d.antes),
        AccionAdmin.rechazar => await repo.rechazar(d.antes, d.texto ?? ''),
        AccionAdmin.pedirDatos => await repo.pedirDatos(d.antes, d.texto ?? ''),
      };
      reportes = [for (final x in reportes) x.id == nuevo.id ? nuevo : x];
      fallo = null;
    } on ErrorPanel catch (e) {
      // El servidor no la aceptó: vuelve a como estaba y se dice por qué.
      reportes = [for (final x in reportes) x.id == d.antes.id ? d.antes : x];
      fallo = e.mensaje;
      if (e.sinSesion) {
        salir();
        error = e.mensaje;
      }
    } catch (_) {
      reportes = [for (final x in reportes) x.id == d.antes.id ? d.antes : x];
      fallo = 'No se pudo guardar el cambio. Intenta de nuevo.';
    }
    _avisar();
  }

  /// Quita el aviso de fallo (ya se mostró).
  String? tomarFallo() {
    final f = fallo;
    fallo = null;
    return f;
  }

  // ---------------------------------------------------------------- avisos del navegador

  /// El admin activa (o apaga) los avisos del navegador. Pide permiso al activar.
  Future<bool> activarAvisosNavegador(bool activar) async {
    if (!activar) {
      navegador.activo = false;
      _avisar();
      return false;
    }
    final ok = await navegador.pedirPermiso();
    navegador.activo = ok;
    _avisar();
    return ok;
  }
}

/// Lo que llegó en una consulta: para el banner de la app y el aviso del navegador.
class AvisoLlegada {
  AvisoLlegada(this.reportes, this.version);
  final List<ReporteAdmin> reportes;
  final int version;

  int get cantidad => reportes.length;

  String get titulo => cantidad == 1 ? 'Reporte nuevo' : '$cantidad reportes nuevos';

  String get cuerpo {
    final r = reportes.first;
    final zona = r.zona.isEmpty ? '' : ' · ${r.zona}';
    final extra = cantidad > 1 ? ' y ${cantidad - 1} más' : '';
    return '${r.tipo.nombre}$zona$extra';
  }
}
