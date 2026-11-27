// Inicio por cada rol, la elección de rol en la bienvenida y el cambio en Guardián, a 360x800 y
// 390x844 con letra x1 y x1,3. Falla ante cualquier excepción (incluido un desborde).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/admin/controlador_admin.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/experiencia/jornada.dart';
import 'package:zanky/datos/guardian.dart';
import 'package:zanky/datos/pronostico/servicio_pronostico.dart';
import 'package:zanky/datos/reporte.dart';
import 'package:zanky/datos/roles.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/datos/tipos.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/nucleo/presionable.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/admin/piezas_admin.dart';
import 'package:zanky/vistas/bienvenida/bienvenida.dart';
import 'package:zanky/vistas/bienvenida/formulario.dart';
import 'package:zanky/vistas/guardian/pantalla_guardian.dart';
import 'package:zanky/vistas/inicio/inicio.dart';
import 'package:zanky/vistas/inicio/pronostico_compacto.dart';
import 'package:zanky/vistas/inicio/secciones_rol.dart';
import 'package:zanky/vistas/roles/selector_rol.dart';

import 'apoyo_datos.dart';

const _tamanos = <(String, Size)>[('360x800', Size(360, 800)), ('390x844', Size(390, 844))];
const _letras = [1.0, 1.3];

late Manglar _manglar;

Jornada _jornada(String id, int dias) {
  final inicio = DateTime.now().add(Duration(days: dias));
  return Jornada(
    id: id,
    accionId: 'a',
    titulo: 'Siembra en el caño $id',
    tipo: 'siembra',
    inicio: inicio,
    fin: inicio.add(const Duration(hours: 3)),
    puntoEncuentro: 'Entrada principal',
    lat: 11,
    lon: -74.8,
    cupos: 40,
    inscritos: 23,
    queLlevar: const [],
    descripcion: 'Datos de ejemplo',
  );
}

EstadoZanky _estado(RolUsuario rol, {String colegio = 'Colegio Ciénaga de Mallorquín', bool conReportes = true}) {
  final e = EstadoZanky();
  e.manglar = _manglar;
  e.listo = true;
  e.perfil = Perfil(
    id: '123e4567-e89b-12d3-a456-426614174000',
    nombre: 'Ana Pérez',
    colegio: colegio,
    rol: rol,
    consentimiento: DateTime.now(),
    creado: DateTime.now(),
  );
  if (conReportes) {
    e.reportes.addAll([
      reporteDePrueba(idDePrueba(1), envio: Envio.enviado),
      reporteDePrueba(idDePrueba(2), envio: Envio.enviado, estado: EstadoReporte.verificado),
    ]);
  }
  return e;
}

Future<void> _avanzar(WidgetTester t, {int veces = 6}) async {
  for (var i = 0; i < veces; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _montar(WidgetTester t, EstadoZanky estado, Widget hijo, Size tam, double letra,
    {ControladorAdmin? admin}) async {
  t.view.physicalSize = tam;
  t.view.devicePixelRatio = 1;
  addTearDown(() {
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  Widget app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: temaZanky(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(letra)),
      child: child!,
    ),
    home: Scaffold(body: hijo),
  );
  if (admin != null) app = AdminScope(controlador: admin, child: app);
  await t.pumpWidget(Zanky(estado: estado, child: app));
  await _avanzar(t);
}

Future<void> _cerrar(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 30));
}

/// Baja la lista de Inicio hasta que [texto] se vea.
Future<void> _ver(WidgetTester t, String texto) async {
  await t.scrollUntilVisible(find.text(texto), 250, scrollable: find.byType(Scrollable).first, maxScrolls: 40);
  await _avanzar(t, veces: 2);
}

/// Corre [cuerpo] recogiendo TODAS las excepciones del marco (un desborde incluido).
Future<void> _sinErrores(WidgetTester t, Future<void> Function(List<String> errores) cuerpo) async {
  final errores = <String>[];
  final previo = FlutterError.onError;
  FlutterError.onError = (d) {
    final donde = RegExp(r'lib/[\w/]+\.dart:\d+').allMatches(d.toString()).map((m) => m.group(0)).toSet().join(', ');
    errores.add('${d.exceptionAsString().trim().split('\n').first} [$donde]');
  };
  try {
    await cuerpo(errores);
  } finally {
    FlutterError.onError = previo;
  }
  expect(errores.toSet().toList(), isEmpty);
}

void _tamanosYLetras(String nombre, Future<void> Function(WidgetTester t, Size tam, double letra, List<String> e) cuerpo) {
  for (final (tn, tam) in _tamanos) {
    for (final letra in _letras) {
      testWidgets('$nombre · $tn · letra x$letra', (t) async {
        SharedPreferences.setMockInitialValues({});
        await _sinErrores(t, (e) => cuerpo(t, tam, letra, e));
      });
    }
  }
}

void _tocables(WidgetTester t, List<String> errores) {
  for (final el in t.elementList(find.byType(Presionable))) {
    final ro = el.renderObject;
    if (ro is! RenderBox || !ro.hasSize) continue;
    if (ro.size.width < 44 || ro.size.height < 44) {
      errores.add('Toque menor de 44 px: ${ro.size.width.toStringAsFixed(0)}x${ro.size.height.toStringAsFixed(0)} '
          '(${(el.widget as Presionable).etiqueta ?? 'sin etiqueta'})');
    }
  }
}

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter');
    for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      inter.addFont(Future.value(ByteData.sublistView(File('google_fonts/Inter-$f.ttf').readAsBytesSync())));
    }
    await inter.load();
    _manglar = Manglar.desdeJson(
        jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync()) as Map<String, dynamic>);
  });

  setUp(() {
    // Sin red: ni jornadas ni pronóstico salen del teléfono de la prueba.
    cargaJornadasInicio = () async => [_jornada('uno', 2), _jornada('dos', 9)];
    crearServicioPronosticoInicio =
        () => ServicioPronostico(cliente: MockClient((_) async => http.Response('', 500)));
  });

  group('Inicio por rol', () {
    _tamanosYLetras('Ciudadano', (t, tam, letra, errores) async {
      await _montar(t, _estado(RolUsuario.ciudadano), const Inicio(), tam, letra);
      expect(find.text('¿QUÉ HAGO YA?'), findsOneWidget);
      expect(find.text('Vecino o vecina'), findsOneWidget);
      await _ver(t, 'Estado de mis reportes');
      expect(find.text('Validados'), findsOneWidget);
      await _ver(t, 'Reporte rápido');
      await _ver(t, 'PRONÓSTICO DEL MANGLAR');
      if (letra == 1.0) _tocables(t, errores);
      await _cerrar(t);
    });

    _tamanosYLetras('Ciudadano sin reportes: estado vacío con Zanky', (t, tam, letra, errores) async {
      await _montar(t, _estado(RolUsuario.ciudadano, conReportes: false), const Inicio(), tam, letra);
      await _ver(t, 'Aún no has reportado');
      expect(find.text('Hacer mi primer reporte'), findsOneWidget);
      await _cerrar(t);
    });

    _tamanosYLetras('Estudiante', (t, tam, letra, errores) async {
      await _montar(t, _estado(RolUsuario.estudiante), const Inicio(), tam, letra);
      expect(find.text('¿QUÉ HAGO YA?'), findsOneWidget);
      await _ver(t, 'RETO DEL MANGLAR');
      await _ver(t, 'Ranking de tu colegio');
      expect(find.text('Colegio Ciénaga de Mallorquín'), findsWidgets);
      await _ver(t, 'MISIÓN DE LA SEMANA');
      if (letra == 1.0) _tocables(t, errores);
      await _cerrar(t);
    });

    _tamanosYLetras('Estudiante sin colegio pide agregarlo', (t, tam, letra, errores) async {
      await _montar(t, _estado(RolUsuario.estudiante, colegio: ''), const Inicio(), tam, letra);
      expect(find.text('Agrega tu colegio'), findsOneWidget);
      await _ver(t, 'Falta tu colegio');
      await _cerrar(t);
    });

    _tamanosYLetras('Visitante', (t, tam, letra, errores) async {
      await _montar(t, _estado(RolUsuario.turista), const Inicio(), tam, letra);
      expect(find.text('¿QUÉ HAGO YA?'), findsOneWidget);
      await _ver(t, 'PRONÓSTICO DEL MANGLAR');
      await _ver(t, 'Qué ver');
      await _ver(t, 'Qué no hacer');
      await _ver(t, 'Próximas jornadas');
      await _ver(t, 'Siembra en el caño uno');
      if (letra == 1.0) _tocables(t, errores);
      await _cerrar(t);
    });

    _tamanosYLetras('Organizador', (t, tam, letra, errores) async {
      await _montar(t, _estado(RolUsuario.organizador), const Inicio(), tam, letra);
      expect(find.text('¿QUÉ HAGO YA?'), findsOneWidget);
      await _ver(t, 'Mis jornadas');
      await _ver(t, 'QR del evento');
      expect(find.text('Para organizadores'), findsOneWidget);
      await _ver(t, 'Asistentes');
      expect(find.text('23'), findsOneWidget);
      if (letra == 1.0) _tocables(t, errores);
      await _cerrar(t);
    });

    _tamanosYLetras('Organizador sin jornadas', (t, tam, letra, errores) async {
      cargaJornadasInicio = () async => const [];
      await _montar(t, _estado(RolUsuario.organizador), const Inicio(), tam, letra);
      await _ver(t, 'Sin jornadas próximas');
      await _cerrar(t);
    });

    _tamanosYLetras('Equipo del servidor: la bandeja del panel va antes que «¿Qué hago ya?»', (t, tam, letra, errores) async {
      final admin = ControladorAdmin(servidor: Servidor(base: '', anon: ''), cada: Duration.zero)..entrarDemo();
      await _montar(t, _estado(RolUsuario.turista), const Inicio(), tam, letra, admin: admin);
      final panel = find.textContaining('PANEL · ');
      expect(panel, findsOneWidget);
      expect(find.text('PANEL · MODERACIÓN CRA'), findsOneWidget);
      expect(t.getTopLeft(panel).dy, lessThan(t.getTopLeft(find.text('¿QUÉ HAGO YA?')).dy));
      admin.salir();
      await _cerrar(t);
    });

    testWidgets('«¿Qué hago ya?» cambia al cambiar el rol', (t) async {
      SharedPreferences.setMockInitialValues({});
      await _sinErrores(t, (_) async {
        final estado = _estado(RolUsuario.ciudadano, conReportes: false);
        await _montar(t, estado, const Inicio(), _tamanos[0].$2, 1.0);
        expect(find.text('Haz tu primer reporte'), findsOneWidget);
        estado.perfil!.rol = RolUsuario.organizador;
        estado.guardarPerfil(estado.perfil!);
        await _avanzar(t, veces: 4);
        expect(find.text('Prepara tu próxima jornada'), findsOneWidget);
        await _cerrar(t);
      });
    });
  });

  group('Elegir el rol', () {
    _tamanosYLetras('Las cuatro tarjetas y la elección', (t, tam, letra, errores) async {
      final datos = DatosPerfil();
      addTearDown(datos.dispose);
      await _montar(
        t,
        _estado(RolUsuario.ciudadano),
        ListenableBuilder(
          listenable: datos,
          builder: (_, _) => SingleChildScrollView(child: SelectorRol(valor: datos.rol, alCambiar: datos.elegirRol)),
        ),
        tam,
        letra,
      );
      for (final r in RolUsuario.values) {
        expect(find.text(r.nombre), findsOneWidget);
      }
      await t.tap(find.text('Estudiante'));
      await _avanzar(t, veces: 3);
      expect(datos.rol, RolUsuario.estudiante);
      await t.ensureVisible(find.text('Organizador de jornadas'));
      await t.tap(find.text('Organizador de jornadas'));
      await _avanzar(t, veces: 3);
      expect(datos.rol, RolUsuario.organizador);
      await _cerrar(t);
    });

    testWidgets('en la bienvenida: cuarta página, se elige y queda en el perfil guardado', (t) async {
      SharedPreferences.setMockInitialValues({});
      await _sinErrores(t, (_) async {
        final estado = EstadoZanky()
          ..manglar = _manglar
          ..listo = true;
        await _montar(t, estado, const Bienvenida(), _tamanos[1].$2, 1.0);
        for (var i = 0; i < 3; i++) {
          await t.tap(find.text('Siguiente'));
          await _avanzar(t, veces: 8);
        }
        expect(find.text('¿Cómo participas?'), findsOneWidget);
        await t.tap(find.text('Estudiante'));
        await _avanzar(t, veces: 3);
        await t.tap(find.text('Siguiente'));
        await _avanzar(t, veces: 8);
        await t.ensureVisible(find.textContaining('Acepto el tratamiento'));
        await _avanzar(t, veces: 2);
        await t.tap(find.textContaining('Acepto el tratamiento'));
        await _avanzar(t, veces: 3);
        await t.tap(find.textContaining('Empezar a cuidar'));
        await _avanzar(t, veces: 10);
        expect(estado.perfil?.rol, RolUsuario.estudiante);
        await _cerrar(t);
      });
    });

    testWidgets('en Guardián: la tarjeta de rol abre la hoja y cambiar guarda el rol', (t) async {
      SharedPreferences.setMockInitialValues({});
      await _sinErrores(t, (_) async {
        final estado = _estado(RolUsuario.ciudadano);
        await _montar(t, estado, const PantallaGuardian(), _tamanos[0].$2, 1.0);
        await t.scrollUntilVisible(find.text('TU ROL'), 200, scrollable: find.byType(Scrollable).first);
        expect(find.text('Vecino o vecina'), findsWidgets);
        // El toque de la tarjeta abre esta misma hoja.
        mostrarCambiarRol(t.element(find.byType(PantallaGuardian)));
        await _avanzar(t, veces: 8);
        expect(find.text('¿Cómo participas?'), findsOneWidget);
        await t.tap(find.text('Organizador de jornadas').last);
        await _avanzar(t, veces: 10);
        expect(estado.perfil?.rol, RolUsuario.organizador);
        // El resto del perfil no se toca.
        expect(estado.perfil?.nombre, 'Ana Pérez');
        await _cerrar(t);
      });
    });
  });
}
