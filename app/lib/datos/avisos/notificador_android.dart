import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../admin/aviso_navegador.dart';
import '../experiencia/jornada.dart';
import 'reglas_avisos.dart';

/// Avisos del sistema en el APK de Android (flutter_local_notifications).
///
/// - Dos canales: «Alertas del manglar» (importancia alta: suena y asoma arriba) y
///   «Jornadas y reportes» (normal).
/// - Ícono pequeño monocromo (`res/drawable/ic_aviso_zanky.xml`, hoja de mangle) y color CRA.
/// - El permiso `POST_NOTIFICATIONS` (Android 13+) solo se pide desde un toque: al activar los
///   avisos en la bandeja o en Configuración ([AvisoTelefono.pedirPermiso]). Nunca al abrir.
/// - Los recordatorios de jornada se **programan** (`zonedSchedule`) para la víspera a las
///   6:00 p. m. y 2 h antes, hora de Colombia: llegan aunque la app esté cerrada.
/// - Tocar el aviso abre la app con la misma clave que usa la bandeja: lleva al lugar exacto.
///
/// Todo pasa por [PluginAvisos]: las pruebas lo cambian por un doble y nunca tocan la plataforma.

// ------------------------------------------------------------------ canales

/// Un canal de Android: id estable (no se cambia nunca: el teléfono recuerda lo que la persona
/// eligió para él), nombre visible en Ajustes e importancia.
class CanalAviso {
  const CanalAviso(this.id, this.nombre, this.descripcion, {required this.alta});
  final String id, nombre, descripcion;
  final bool alta;
}

const canalAlertas = CanalAviso(
  'zanky_alertas',
  'Alertas del manglar',
  'Cuando una alerta sube a naranja o roja: lugar y qué hacer.',
  alta: true,
);

const canalJornadas = CanalAviso(
  'zanky_jornadas',
  'Jornadas y reportes',
  'Recordatorios de tus jornadas y novedades de tus reportes.',
  alta: false,
);

const canales = [canalAlertas, canalJornadas];

/// Ícono pequeño (silueta blanca; Android la tiñe con [colorAviso]).
const iconoAviso = '@drawable/ic_aviso_zanky';

/// Azul CRA.
const colorAviso = Color(0xFF0A2A47);

/// Las alertas van al canal alto; jornadas y reportes, al normal.
CanalAviso canalDe(String clave) => clave.startsWith('alerta|') ? canalAlertas : canalJornadas;

/// Id numérico estable de una clave (FNV-1a de 31 bits): el mismo aviso reemplaza al anterior en
/// la barra en vez de apilarse, y el programado y el de la app comparten id.
int idDeAviso(String clave) {
  var h = 0x811c9dc5;
  for (final c in clave.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h & 0x7FFFFFFF;
}

// ------------------------------------------------------------------ programación

/// Un aviso para más tarde: [cuando] en UTC.
class AvisoProgramado {
  const AvisoProgramado({required this.aviso, required this.cuando});
  final AvisoApp aviso;
  final DateTime cuando;
}

/// Los recordatorios de una jornada que aún están por delante: la víspera (6:00 p. m. de
/// Colombia del día anterior) y 2 h antes. Los textos y las claves son los mismos que da la
/// bandeja ([recordatoriosJornadas]), así el aviso programado y el de la app son uno solo.
List<AvisoProgramado> programacionesJornada(Jornada j, DateTime ahora) {
  final t = ahora.toUtc();
  final inicio = j.inicio.toUtc();
  if (!inicio.isAfter(t)) return const [];
  final momentos = [momentoVispera(j.inicio), inicio.subtract(const Duration(hours: 2))];
  return [
    for (final m in momentos)
      if (m.isAfter(t))
        for (final a in recordatoriosJornadas([j], const {}, m)) AvisoProgramado(aviso: a, cuando: m),
  ];
}

/// Claves de los recordatorios de una jornada (para cancelarlos si se desactivan).
List<String> clavesJornada(String id) => ['jornada|$id|vispera', 'jornada|$id|2h'];

// ------------------------------------------------------------------ plugin

/// Lo poco que se usa del plugin. [PluginSistema] es la capa real; las pruebas usan un doble.
abstract class PluginAvisos {
  /// Inicializa y crea los canales. [alTocar] recibe la clave del aviso tocado con la app viva.
  Future<void> iniciar(void Function(String clave) alTocar);

  /// La clave del aviso que abrió la app (con la app cerrada), si fue así.
  Future<String?> claveDeArranque();

  /// Pide `POST_NOTIFICATIONS` (Android 13+; antes, siempre verdadero).
  Future<bool> pedirPermiso();

  Future<void> mostrar(int id, String titulo, String cuerpo, CanalAviso canal, String clave);
  Future<void> programar(int id, DateTime cuandoUtc, String titulo, String cuerpo, CanalAviso canal, String clave);
  Future<void> cancelar(int id);
}

/// El notificador: decide canal, id y programación; el plugin solo entrega.
class NotificadorAndroid {
  NotificadorAndroid(this.plugin, {DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now;

  final PluginAvisos plugin;
  final DateTime Function() _reloj;
  Future<void>? _inicio;
  void Function(String)? _alTocar;

  /// Inicializa una sola vez (no pide permisos).
  Future<void> iniciar([void Function(String)? alTocar]) {
    if (alTocar != null) _alTocar = alTocar;
    return _inicio ??= plugin.iniciar((c) => _alTocar?.call(c));
  }

  /// Escucha los toques y, si la app se abrió desde un aviso, avisa su clave.
  Future<void> escuchar(void Function(String) alTocar) async {
    await iniciar(alTocar);
    final c = await plugin.claveDeArranque();
    if (c != null && c.isNotEmpty) alTocar(c);
  }

  Future<bool> pedirPermiso() async {
    await iniciar();
    return plugin.pedirPermiso();
  }

  Future<void> mostrar(String titulo, String cuerpo, String clave) async {
    await iniciar();
    await plugin.mostrar(idDeAviso(clave), titulo, cuerpo, canalDe(clave), clave);
  }

  /// Programa los recordatorios que quedan de [j]. Devuelve las claves programadas.
  Future<List<String>> programarJornada(Jornada j) async {
    await iniciar();
    final lista = programacionesJornada(j, _reloj());
    for (final p in lista) {
      final a = p.aviso;
      await plugin.programar(idDeAviso(a.clave), p.cuando, a.titulo, a.cuerpo, canalDe(a.clave), a.clave);
    }
    return [for (final p in lista) p.aviso.clave];
  }

  Future<void> cancelarJornada(String id) async {
    await iniciar();
    for (final c in clavesJornada(id)) {
      await plugin.cancelar(idDeAviso(c));
    }
  }
}

/// La capa real sobre flutter_local_notifications. No se prueba (necesita el teléfono).
class PluginSistema implements PluginAvisos {
  final _p = FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> iniciar(void Function(String clave) alTocar) async {
    await _p.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings(iconoAviso)),
      onDidReceiveNotificationResponse: (r) {
        final c = r.payload;
        if (c != null && c.isNotEmpty) alTocar(c);
      },
    );
    for (final c in canales) {
      await _android?.createNotificationChannel(AndroidNotificationChannel(
        c.id,
        c.nombre,
        description: c.descripcion,
        importance: c.alta ? Importance.high : Importance.defaultImportance,
      ));
    }
  }

  @override
  Future<String?> claveDeArranque() async {
    final d = await _p.getNotificationAppLaunchDetails();
    if (d == null || !d.didNotificationLaunchApp) return null;
    return d.notificationResponse?.payload;
  }

  @override
  Future<bool> pedirPermiso() async => await _android?.requestNotificationsPermission() ?? false;

  NotificationDetails _detalles(CanalAviso c, String cuerpo) => NotificationDetails(
        android: AndroidNotificationDetails(
          c.id,
          c.nombre,
          channelDescription: c.descripcion,
          icon: iconoAviso,
          color: colorAviso,
          importance: c.alta ? Importance.high : Importance.defaultImportance,
          priority: c.alta ? Priority.high : Priority.defaultPriority,
          category: c.alta ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
          // El cuerpo entero (lugar y qué hacer), no cortado en una línea.
          styleInformation: BigTextStyleInformation(cuerpo),
          // Si el mismo aviso vuelve a salir (programado y luego desde la app), no suena dos veces.
          onlyAlertOnce: true,
        ),
      );

  @override
  Future<void> mostrar(int id, String titulo, String cuerpo, CanalAviso canal, String clave) =>
      _p.show(id: id, title: titulo, body: cuerpo, notificationDetails: _detalles(canal, cuerpo), payload: clave);

  @override
  Future<void> programar(int id, DateTime cuandoUtc, String titulo, String cuerpo, CanalAviso canal, String clave) =>
      _p.zonedSchedule(
        id: id,
        // Un instante absoluto en UTC: Colombia no tiene horario de verano y el momento ya viene
        // calculado en hora de Colombia ([momentoVispera]).
        scheduledDate: tz.TZDateTime.from(cuandoUtc.toUtc(), tz.UTC),
        notificationDetails: _detalles(canal, cuerpo),
        // Inexacto: no pide el permiso de alarmas exactas; Android lo entrega en minutos.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: titulo,
        body: cuerpo,
        payload: clave,
      );

  @override
  Future<void> cancelar(int id) => _p.cancel(id: id);
}

/// Los avisos del teléfono con la misma cara que los del navegador: la bandeja y Configuración
/// los encienden con el mismo interruptor ([CentroAvisos.activarNavegador]).
class AvisoTelefono extends AvisoNavegador {
  AvisoTelefono(this.n);
  final NotificadorAndroid n;

  @override
  bool get disponible => Platform.isAndroid;

  /// Android no dice «bloqueado» sin preguntar: si la persona lo negó, [pedirPermiso] da falso.
  @override
  bool get bloqueado => false;

  @override
  Future<bool> pedirPermiso() async {
    try {
      return await n.pedirPermiso();
    } catch (_) {
      return false;
    }
  }

  @override
  void mostrar(String titulo, String cuerpo) => unawaited(n.mostrar(titulo, cuerpo, titulo).catchError((_) {}));
}

// ------------------------------------------------------------------ interfaz común (ver notificador_web.dart)

/// Interruptor general: apagado, el APK se queda como antes (campana y píldora).
const avisosDelSistemaAndroid = true;

final _n = NotificadorAndroid(PluginSistema());
bool get _activo => avisosDelSistemaAndroid && Platform.isAndroid;

bool concedido() => false;

Future<void> mostrar(String titulo, String cuerpo, String clave, void Function(String) alTocar) async {
  if (!_activo) return;
  try {
    await _n.mostrar(titulo, cuerpo, clave);
  } catch (_) {}
}

void escucharToques(void Function(String) alTocar) {
  if (!_activo) return;
  unawaited(_n.escuchar(alTocar).catchError((_) {}));
}

String? avisoDeLaDireccion() => null;

AvisoNavegador crearAvisoSistema() => _activo ? AvisoTelefono(_n) : AvisoNavegador();

Future<List<String>> programarJornada(Jornada j) async {
  if (!_activo) return const [];
  try {
    return await _n.programarJornada(j);
  } catch (_) {
    return const [];
  }
}

Future<void> cancelarJornada(String id) async {
  if (!_activo) return;
  try {
    await _n.cancelarJornada(id);
  } catch (_) {}
}
