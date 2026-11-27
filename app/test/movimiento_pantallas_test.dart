// Pantallas con el kit de movimiento aplicado: «Mis reportes» (vacío con Zanky, esqueletos,
// quitar con confirmar en hoja y «Deshacer» en el aviso), la confirmación del reporte
// (un solo ✓) y el último paso del flujo (botón con ciclo cargando → ✓). Cada una a
// 360x800 y 390x844, con letra x1 y x1,3, y con «reducir movimiento».
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zanky/nucleo/presionable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/reporte.dart';
import 'package:zanky/datos/tipos.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/nucleo/base/esqueleto.dart';
import 'package:zanky/nucleo/kit/boton_estado.dart';
import 'package:zanky/nucleo/kit/celebracion.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/datos/guardian.dart';
import 'package:zanky/nucleo/kit/interruptor.dart';
import 'package:zanky/vistas/guardian/editar_perfil.dart';
import 'package:zanky/vistas/guardian/pantalla_guardian.dart';
import 'package:zanky/vistas/mis_reportes/pantalla_mis_reportes.dart';
import 'package:zanky/vistas/mis_reportes/tarjeta_reporte.dart';
import 'package:zanky/vistas/reporte/enviado.dart';
import 'package:zanky/vistas/reporte/flujo_reporte.dart';

import 'apoyo_datos.dart';

late Manglar _manglar;

const _pantallas = <(String, Size)>[
  ('360x800', Size(360, 800)),
  ('390x844', Size(390, 844)),
  ('1280x800', Size(1280, 800)),
];
const _letras = [1.0, 1.3];

Future<void> _montar(
  WidgetTester t,
  EstadoZanky estado,
  Widget hijo, {
  Size tam = const Size(390, 844),
  double letra = 1,
  bool reducir = false,
  bool conScaffold = true,
}) async {
  t.view.physicalSize = tam;
  t.view.devicePixelRatio = 1;
  addTearDown(() {
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  await t.pumpWidget(Zanky(
    estado: estado,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaZanky(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducir, textScaler: TextScaler.linear(letra)),
        child: child!,
      ),
      home: conScaffold ? Scaffold(body: hijo) : hijo,
    ),
  ));
  await _avanzar(t, 8);
}

/// Sin pumpAndSettle: Zanky respira para siempre.
Future<void> _avanzar(WidgetTester t, [int veces = 6, int ms = 100]) async {
  for (var i = 0; i < veces; i++) {
    await t.pump(Duration(milliseconds: ms));
  }
}

Future<void> _cerrar(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 30));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final j = jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync());
    _manglar = Manglar.desdeJson(j as Map<String, dynamic>);
  });

  setUp(() {
    SharedPreferencesStorePlatform.instance = AlmacenDePrueba();
    SharedPreferences.resetStatic();
  });

  group('Quitar un reporte del teléfono (estado)', () {
    test('quitar y restaurar: el disco no lo trae de vuelta', () async {
      final e = EstadoZanky()..manglar = _manglar;
      final r = reporteDePrueba(idDePrueba(1), envio: Envio.enCola);
      await e.agregar(r, null);
      expect(e.reportes.map((x) => x.id), [r.id]);

      await e.quitarReporte(r);
      expect(e.reportes, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(EstadoZanky.claveReportes), isEmpty, reason: 'también salió del disco');

      // Otra copia del disco (otra pestaña) no lo resucita.
      await e.liberarEspacio();
      expect(e.reportes, isEmpty);

      await e.restaurarReporte(r);
      expect(e.reportes.map((x) => x.id), [r.id]);
      expect(prefs.getStringList(EstadoZanky.claveReportes), hasLength(1));
      e.dispose();
    });

    test('lo que ya llegó a la CRA o va en camino no se quita', () async {
      final e = EstadoZanky()..manglar = _manglar;
      for (final envio in [Envio.enviado, Envio.enviando]) {
        final r = reporteDePrueba(idDePrueba(2 + envio.index), envio: envio);
        e.reportes.add(r);
        await e.quitarReporte(r);
        expect(e.reportes.contains(r), isTrue, reason: '$envio se queda');
        expect(EstadoZanky.sePuedeQuitar(r), isFalse);
      }
      expect(EstadoZanky.sePuedeQuitar(reporteDePrueba(idDePrueba(9), envio: Envio.rechazado)), isTrue);
      e.dispose();
    });
  });

  for (final (nombre, tam) in _pantallas) {
    for (final letra in _letras) {
      group('Mis reportes · $nombre · letra x$letra', () {
        testWidgets('vacío: Zanky invita al primer reporte', (t) async {
          final e = EstadoZanky()..manglar = _manglar;
          await _montar(t, e, const PantallaMisReportes(), tam: tam, letra: letra);
          expect(find.text('Aún no has reportado nada'), findsOneWidget);
          expect(find.text('Hacer mi primer reporte'), findsOneWidget);
          expect(t.takeException(), isNull);
          await _cerrar(t);
          e.dispose();
        });

        testWidgets('con reportes: sin desbordes, con segmentado y tarjetas', (t) async {
          final e = EstadoZanky()..manglar = _manglar;
          e.reportes.addAll([
            reporteDePrueba(idDePrueba(11), envio: Envio.enCola),
            reporteDePrueba(idDePrueba(12), envio: Envio.enviado, estado: EstadoReporte.verificado),
          ]);
          await _montar(t, e, const PantallaMisReportes(), tam: tam, letra: letra);
          expect(find.byType(TarjetaReporte), findsWidgets);
          expect(find.text('Pendientes'), findsOneWidget);
          await t.tap(find.text('Validados'));
          await _avanzar(t, 8);
          expect(find.byType(TarjetaReporte), findsOneWidget);
          await t.tap(find.text('Pendientes'));
          await _avanzar(t, 8);
          expect(find.byType(TarjetaReporte), findsOneWidget);
          expect(t.takeException(), isNull);
          await _cerrar(t);
          e.dispose();
        });
      });
    }
  }

  testWidgets('filtro sin resultados: Zanky lo dice con su estado vacío', (t) async {
    final e = EstadoZanky()..manglar = _manglar;
    e.reportes.add(reporteDePrueba(idDePrueba(13), envio: Envio.enviado, estado: EstadoReporte.verificado));
    await _montar(t, e, const PantallaMisReportes());
    await t.tap(find.text('Pendientes'));
    await _avanzar(t, 8);
    expect(find.text('Nada pendiente'), findsOneWidget);
    await _cerrar(t);
    e.dispose();
  });

  testWidgets('primera vuelta con el servidor y nada guardado: esqueletos, no vacío', (t) async {
    final s = ServidorFalso();
    final e = EstadoZanky(servidor: s.servidor)
      ..manglar = _manglar
      ..sincronizando = true;
    await _montar(t, e, const PantallaMisReportes());
    expect(find.byType(Skeleton), findsWidgets);
    expect(find.text('Aún no has reportado nada'), findsNothing);
    await _cerrar(t);
    e.dispose();
  });

  for (final reducir in [false, true]) {
    group('Quitar con confirmar + Deshacer (reducir=$reducir)', () {
      testWidgets('deslizar → hoja → confirmar → aviso → Deshacer lo trae de vuelta', (t) async {
        final e = EstadoZanky()..manglar = _manglar;
        final r = reporteDePrueba(idDePrueba(21), envio: Envio.enCola);
        await t.runAsync(() => e.agregar(r, null));
        await _montar(t, e, const PantallaMisReportes(), reducir: reducir);
        expect(find.byType(TarjetaReporte), findsOneWidget);

        // Deslizar revela la baldosa «Quitar»; tocarla confirma en una hoja.
        await t.fling(find.byType(TarjetaReporte), const Offset(-400, 0), 1800);
        await _avanzar(t, 10);
        await t.tap(find.byKey(const Key('accion-Quitar del teléfono')));
        await _avanzar(t, 10);
        expect(find.text('¿Quitar este reporte?'), findsOneWidget, reason: 'confirma en una hoja');
        await t.tap(find.widgetWithText(BotonZ, 'Quitar del teléfono'));
        await _avanzar(t, 14);

        expect(e.reportes, isEmpty);
        expect(find.byType(TarjetaReporte), findsNothing);
        expect(find.text('Reporte quitado'), findsOneWidget, reason: 'aviso en píldora');

        await t.tap(find.text('Deshacer'));
        await _avanzar(t, 14);
        expect(e.reportes.map((x) => x.id), [r.id]);
        expect(find.byType(TarjetaReporte), findsOneWidget);
        await _avanzar(t, 80);
        await _cerrar(t);
        e.dispose();
      });

      testWidgets('si se cancela en la hoja, el reporte se queda', (t) async {
        final e = EstadoZanky()..manglar = _manglar;
        final r = reporteDePrueba(idDePrueba(22), envio: Envio.enCola);
        e.reportes.add(r);
        await _montar(t, e, const PantallaMisReportes(), reducir: reducir);
        await t.fling(find.byType(TarjetaReporte), const Offset(-400, 0), 1800);
        await _avanzar(t, 10);
        await t.tap(find.byKey(const Key('accion-Quitar del teléfono')));
        await _avanzar(t, 10);
        await t.tap(find.text('Cancelar'));
        await _avanzar(t, 14);
        expect(e.reportes, [r]);
        expect(find.byType(TarjetaReporte), findsOneWidget);
        expect(find.text('Reporte quitado'), findsNothing);
        await _cerrar(t);
        e.dispose();
      });

      testWidgets('mantener pulsada la tarjeta hace lo mismo', (t) async {
        final e = EstadoZanky()..manglar = _manglar;
        final r = reporteDePrueba(idDePrueba(23), envio: Envio.error);
        await t.runAsync(() => e.agregar(r, null));
        await _montar(t, e, const PantallaMisReportes(), reducir: reducir);
        await t.longPress(find.byType(TarjetaReporte));
        await _avanzar(t, 10);
        await t.tap(find.byKey(const Key('menu-Quitar del teléfono')));
        await _avanzar(t, 10);
        expect(find.text('¿Quitar este reporte?'), findsOneWidget);
        await t.tap(find.widgetWithText(BotonZ, 'Quitar del teléfono'));
        await _avanzar(t, 14);
        expect(e.reportes, isEmpty);
        expect(find.text('Reporte quitado'), findsOneWidget);
        await _avanzar(t, 80);
        await _cerrar(t);
        e.dispose();
      });
    });
  }

  testWidgets('un reporte ya enviado a la CRA no se desliza ni se quita', (t) async {
    final e = EstadoZanky()..manglar = _manglar;
    e.reportes.add(reporteDePrueba(idDePrueba(24), envio: Envio.enviado));
    await _montar(t, e, const PantallaMisReportes());
    await t.fling(find.byType(TarjetaReporte), const Offset(-400, 0), 1800);
    await _avanzar(t, 10);
    expect(find.text('¿Quitar este reporte?'), findsNothing);
    expect(find.byType(TarjetaReporte), findsOneWidget);
    await _cerrar(t);
    e.dispose();
  });

  for (final (nombre, tam) in _pantallas) {
    for (final letra in _letras) {
      for (final reducir in [false, true]) {
        testWidgets('Reporte enviado · $nombre · x$letra · reducir=$reducir: un solo ✓ y sin desbordes', (t) async {
          final e = EstadoZanky()..manglar = _manglar;
          final r = reporteDePrueba(idDePrueba(31), envio: Envio.enCola);
          e.reportes.add(r);
          await _montar(t, e, ReporteEnviado(reporteId: r.id), tam: tam, letra: letra, reducir: reducir, conScaffold: false);
          await _avanzar(t, 14); // pasa el arranque (Zm.corto) y se dibuja
          expect(find.byType(CheckDibujado), findsOneWidget, reason: 'el ✓ de la pantalla; el overlay no pone otro');
          expect(t.takeException(), isNull);
          await _avanzar(t, 30);
          await _cerrar(t);
          e.dispose();
        });
      }
    }
  }

  testWidgets('la celebración trae confeti pero no un segundo ✓', (t) async {
    final e = EstadoZanky()..manglar = _manglar;
    final r = reporteDePrueba(idDePrueba(32), envio: Envio.enCola);
    e.reportes.add(r);
    await _montar(t, e, ReporteEnviado(reporteId: r.id), conScaffold: false);
    await _avanzar(t, 10);
    expect(find.byType(Celebracion), findsOneWidget, reason: 'confeti en el overlay raíz');
    expect(find.byType(CheckDibujado), findsOneWidget);
    await _avanzar(t, 30);
    await _cerrar(t);
    e.dispose();
  });

  testWidgets('copiar el número de caso sale en un aviso en píldora, no en SnackBar', (t) async {
    final e = EstadoZanky()..manglar = _manglar;
    final r = reporteDePrueba(idDePrueba(33), envio: Envio.enCola);
    e.reportes.add(r);
    await _montar(t, e, ReporteEnviado(reporteId: r.id), conScaffold: false);
    await t.tap(find.textContaining('NÚMERO DE CASO'));
    await _avanzar(t, 8);
    expect(find.textContaining('Copiado: '), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await _avanzar(t, 60);
    await _cerrar(t);
    e.dispose();
  });

  group('Último paso del flujo', () {
    testWidgets('el botón Enviar muestra cargando → ✓ y pasa a la confirmación', (t) async {
      const canal = MethodChannel('plugins.flutter.io/path_provider');
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, (_) async => Directory.systemTemp.path);
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, null));
      final e = EstadoZanky()..manglar = _manglar;
      await _montar(t, e, FlujoReporte(estado: e, tipo: TipoAmenaza.quema), conScaffold: false);
      await t.tapAt(t.getCenter(find.byType(FlujoReporte)).translate(0, 40));
      await _avanzar(t, 3);
      await t.tap(find.text('Usar este punto'));
      await _avanzar(t, 8);
      await t.tap(find.text('Seguir sin foto'));
      await _avanzar(t, 8);
      expect(find.byType(BotonEstado), findsOneWidget);
      await t.tap(find.textContaining('Guardar reporte'));
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await _avanzar(t, 2);
      expect(find.byType(CheckDibujado), findsOneWidget, reason: 'el ✓ del botón');
      await _avanzar(t, 14);
      expect(find.byType(ReporteEnviado), findsOneWidget);
      expect(e.reportes, hasLength(1));
      await _avanzar(t, 30);
      await _cerrar(t);
      e.dispose();
    });

    testWidgets('cerrar con algo escrito pregunta en una hoja, con lo seguro como principal', (t) async {
      final e = EstadoZanky()..manglar = _manglar;
      await _montar(t, e, FlujoReporte(estado: e, tipo: TipoAmenaza.quema), conScaffold: false);
      await t.tapAt(t.getCenter(find.byType(FlujoReporte)).translate(0, 40));
      await _avanzar(t, 3);
      await t.tap(find.bySemanticsLabel('Cerrar el reporte'));
      await _avanzar(t, 10);
      expect(find.text('¿Descartar este reporte?'), findsOneWidget);
      await t.tap(find.text('Seguir reportando'));
      await _avanzar(t, 10);
      expect(find.text('¿Descartar este reporte?'), findsNothing);
      expect(find.byType(FlujoReporte), findsOneWidget);
      await _cerrar(t);
      e.dispose();
    });
  });

  group('Guardián', () {
    EstadoZanky conNivel() {
      final e = EstadoZanky()..manglar = _manglar;
      e.perfil = Perfil(id: 'yo', creado: DateTime(2026, 11, 1));
      for (var i = 0; i < 12; i++) {
        e.reportes.add(reporteDePrueba(idDePrueba(100 + i), envio: Envio.enviado, estado: EstadoReporte.verificado));
      }
      return e;
    }

    for (final (nombre, tam) in _pantallas) {
      for (final letra in _letras) {
        testWidgets('subir de nivel se celebra una vez · $nombre · x$letra', (t) async {
          final e = conNivel();
          expect(e.progreso.nivel.numero, greaterThan(1));
          await _montar(t, e, const PantallaGuardian(), tam: tam, letra: letra);
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await _avanzar(t, 6);
          expect(find.byType(CheckDibujado), findsWidgets, reason: 'el ✓ grande de la celebración');
          expect(find.textContaining('Nivel ${e.progreso.nivel.numero}: '), findsOneWidget);
          expect(t.takeException(), isNull);
          final prefs = await t.runAsync(SharedPreferences.getInstance);
          expect(prefs!.getInt('guardian.nivel.v1'), e.progreso.nivel.numero, reason: 'queda anotado para no repetir');
          await _avanzar(t, 90);
          await _cerrar(t);
          e.dispose();
        });
      }
    }

    testWidgets('el interruptor de anónimo cambia con la fila entera', (t) async {
      final e = EstadoZanky()..manglar = _manglar;
      e.perfil = Perfil(id: 'yo', creado: DateTime(2026, 11, 1));
      await _montar(
        t,
        e,
        Builder(builder: (c) => Center(child: TextButton(onPressed: () => mostrarEditarPerfil(c), child: const Text('abrir')))),
      );
      await t.tap(find.text('abrir'));
      await _avanzar(t, 10);
      expect(t.widget<InterruptorIos>(find.byType(InterruptorIos)).valor, isFalse);
      await t.tap(find.text('Reportar en anónimo'));
      await _avanzar(t, 6);
      expect(t.widget<InterruptorIos>(find.byType(InterruptorIos)).valor, isTrue);
      await _cerrar(t);
      e.dispose();
    });
  });
}
