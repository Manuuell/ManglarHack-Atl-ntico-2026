// Pantallas del panel de la CRA dentro de la app: sin desbordes a 360x800 y 390x844 con letra
// x1, x1,3 y x2, toques de al menos 44 px y los flujos que importan (decidir, deshacer,
// avisos de llegada y avisos al ciudadano). Sin red ni plugins.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/admin/controlador_admin.dart';
import 'package:zanky/datos/admin/reporte_admin.dart';
import 'package:zanky/datos/avisos_ciudadano.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/reporte.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/datos/tipos.dart';
import 'package:zanky/nucleo/kit/boton_estado.dart';
import 'package:zanky/nucleo/presionable.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/admin/acceso_admin.dart';
import 'package:zanky/vistas/admin/bandeja_admin.dart';
import 'package:zanky/vistas/admin/detalle_admin.dart';
import 'package:zanky/vistas/admin/entrada_panel.dart';
import 'package:zanky/vistas/admin/panel_cra.dart';
import 'package:zanky/vistas/admin/piezas_admin.dart';
import 'package:zanky/vistas/comun/capa_avisos.dart';

import 'apoyo_datos.dart';

const _tamanos = <(String, Size)>[('360x800', Size(360, 800)), ('390x844', Size(390, 844)), ('1280x800', Size(1280, 800))];
const _letras = [1.0, 1.3, 2.0];

ControladorAdmin _controlador({bool servidor = false, List<ReporteAdmin>? semilla, bool demo = false}) {
  final c = ControladorAdmin(
    servidor: servidor ? Servidor(base: 'https://x.supabase.co', anon: 'anon') : Servidor(base: '', anon: ''),
    cada: Duration.zero,
    plazoDeshacer: const Duration(seconds: 6),
  );
  if (demo) c.entrarDemo(semilla: semilla ?? reportesDemo(DateTime.now()));
  return c;
}

EstadoZanky _estado() => EstadoZanky()..listo = true;

Future<void> _montar(
  WidgetTester tester,
  Widget hijo, {
  Size tam = const Size(360, 800),
  double letra = 1.0,
  ControladorAdmin? admin,
  EstadoZanky? estado,
  bool sinAnimar = false,
}) async {
  tester.view.physicalSize = tam;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  Widget app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: temaZanky(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(letra), disableAnimations: sinAnimar),
      child: child!,
    ),
    home: hijo,
  );
  if (admin != null) app = AdminScope(controlador: admin, child: app);
  await tester.pumpWidget(Zanky(estado: estado ?? _estado(), child: app));
  await _avanzar(tester);
}

/// Sin pumpAndSettle: Zanky respira para siempre.
Future<void> _avanzar(WidgetTester tester, {int veces = 6, int ms = 250}) async {
  for (var i = 0; i < veces; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

Future<void> _cerrar(WidgetTester tester, [ControladorAdmin? c]) async {
  c?.salir();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
}

void _probar(String nombre, Widget Function(ControladorAdmin) fabrica,
    {bool demo = true, bool servidor = false, List<ReporteAdmin>? semilla, Future<void> Function(WidgetTester, ControladorAdmin)? despues}) {
  for (final (tn, tam) in _tamanos) {
    for (final letra in _letras) {
      testWidgets('$nombre · $tn · letra x$letra', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final errores = <String>[];
        final previo = FlutterError.onError;
        FlutterError.onError = (d) {
          final donde = RegExp(r'lib/[\w/]+\.dart:\d+').allMatches(d.toString()).map((m) => m.group(0)).toSet().join(', ');
          errores.add('${d.exceptionAsString().trim().split('\n').first} [$donde]');
        };
        final c = _controlador(demo: demo, servidor: servidor, semilla: semilla);
        try {
          await _montar(tester, fabrica(c), tam: tam, letra: letra, admin: c);
          if (despues != null) {
            await despues(tester, c);
            await _avanzar(tester);
          }
          if (letra == 1.0) {
            for (final el in tester.elementList(find.byType(Presionable, skipOffstage: false))) {
              final ro = el.renderObject;
              if (ro is! RenderBox || !ro.hasSize) continue;
              final p = el.widget as Presionable;
              if (ro.size.width < 44 || ro.size.height < 44) {
                errores.add('Toque menor de 44 px: ${ro.size.width.toStringAsFixed(0)}x${ro.size.height.toStringAsFixed(0)} (${p.etiqueta})');
              }
            }
          }
          await _cerrar(tester, c);
        } finally {
          FlutterError.onError = previo;
          c.dispose();
        }
        expect(errores.toSet().toList(), isEmpty, reason: '$nombre a $tn con letra x$letra');
      });
    }
  }
}

Future<void> _tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f, warnIfMissed: false);
  await _avanzar(tester, veces: 4);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Pantallas del panel', () {
    _probar('Acceso sin servidor (demostración)', (_) => const PanelCra(), demo: false);
    _probar('Acceso con servidor', (_) => const PanelCra(), demo: false, servidor: true);
    _probar('Bandeja', (_) => const PanelCra());
    _probar('Bandeja vacía (todo al día)', (_) => const PanelCra(), semilla: const []);
    _probar('Bandeja · Rechazados', (_) => const PanelCra(), despues: (t, c) => _tocar(t, find.text('Rechazados')));
    _probar('Bandeja · Todos', (_) => const PanelCra(), despues: (t, c) => _tocar(t, find.text('Todos')));
    _probar('Resumen · hoy', (_) => const PanelCra(), despues: (t, c) => _tocar(t, find.text('Resumen')));
    _probar('Resumen · 7 días', (_) => const PanelCra(), despues: (t, c) async {
      await _tocar(t, find.text('Resumen'));
      await _tocar(t, find.text('7 días'));
    });
    _probar('Resumen vacío', (_) => const PanelCra(), semilla: const [], despues: (t, c) => _tocar(t, find.text('Resumen')));
    _probar('Detalle (pendiente)', (_) => const DetalleAdmin(id: 'demo-01'));
    _probar('Detalle (ya resuelto)', (_) => const DetalleAdmin(id: 'demo-08'));
    _probar('Detalle de un reporte que ya no está', (_) => const DetalleAdmin(id: 'no-existe'));
    _probar('Hoja · rechazar', (_) => const DetalleAdmin(id: 'demo-01'), despues: (t, c) async {
      await t.scrollUntilVisible(find.text('Rechazar'), 300, scrollable: find.byType(Scrollable).first);
      await _tocar(t, find.text('Rechazar'));
    });
    _probar('Hoja · pedir datos', (_) => const DetalleAdmin(id: 'demo-01'), despues: (t, c) async {
      await t.scrollUntilVisible(find.text('Pedir más datos'), 300, scrollable: find.byType(Scrollable).first);
      await _tocar(t, find.text('Pedir más datos'));
    });
    _probar('Hoja · aprobar', (_) => const DetalleAdmin(id: 'demo-01'), despues: (t, c) async {
      await t.scrollUntilVisible(find.text('Aprobar'), 300, scrollable: find.byType(Scrollable).first);
      await _tocar(t, find.text('Aprobar'));
    });
    _probar('Entrada en Guardián', (_) => const Scaffold(body: SafeArea(child: EntradaPanelCra())), demo: false);
    _probar('Bandeja con «Deshacer»', (_) => const PanelCra(), despues: (t, c) async {
      await c.decidir(AccionAdmin.aprobar, c.reportes.first);
      await _avanzar(t);
    });
  });

  group('Con movimiento reducido', () {
    testWidgets('la bandeja y el resumen se pintan sin animaciones ni errores', (tester) async {
      final c = _controlador(demo: true);
      await _montar(tester, const PanelCra(), admin: c, sinAnimar: true);
      expect(find.text('Pendientes'), findsOneWidget);
      await _tocar(tester, find.text('Resumen'));
      expect(find.text('Nuevos'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _cerrar(tester, c);
      c.dispose();
    });
  });

  group('Flujos del panel', () {
    testWidgets('la bandeja arranca en pendientes, con los más urgentes arriba y el conteo en el segmento', (tester) async {
      final c = _controlador(demo: true);
      await _montar(tester, const PanelCra(), admin: c);
      expect(find.textContaining('Demostración'), findsWidgets);
      expect(find.text('Tala o corte de mangle'), findsWidgets);
      expect(find.text('Aprobados'), findsOneWidget);
      // Lo ya aprobado no está en «Pendientes».
      expect(find.text('Aves muertas'), findsNothing);
      await _cerrar(tester, c);
      c.dispose();
    });

    testWidgets('los filtros cambian la lista', (tester) async {
      final c = _controlador(demo: true);
      await _montar(tester, const PanelCra(), admin: c);
      expect(c.visibles.every((r) => r.pendiente), isTrue);
      await _tocar(tester, find.text('Rechazados'));
      expect(c.filtro, FiltroBandeja.rechazados);
      expect(c.visibles.length, 2);
      expect(find.text('Descartado'), findsWidgets);
      await _cerrar(tester, c);
      c.dispose();
    });

    testWidgets('rechazar exige el motivo, se confirma, se ve al instante y se puede deshacer', (tester) async {
      final c = _controlador(demo: true);
      await _montar(tester, const DetalleAdmin(id: 'demo-01'), admin: c);
      await tester.scrollUntilVisible(find.text('Rechazar'), 300, scrollable: find.byType(Scrollable).first);
      await _tocar(tester, find.text('Rechazar'));
      final hoja = find.byType(HojaDecision);
      expect(hoja, findsOneWidget);
      final confirmar = find.descendant(of: hoja, matching: find.text('Rechazar'));
      // Sin motivo, el botón está apagado.
      await tester.tap(confirmar, warnIfMissed: false);
      await _avanzar(tester, veces: 2);
      expect(find.byType(HojaDecision), findsOneWidget);
      expect(c.pendiente, isNull);

      await tester.enterText(find.descendant(of: hoja, matching: find.byType(TextField)), 'Foto repetida');
      await _avanzar(tester, veces: 2);
      await tester.tap(confirmar);
      await _avanzar(tester);
      expect(c.pendiente, isNotNull);
      expect(c.reportes.firstWhere((r) => r.id == 'demo-01').estado, EstadoReporte.descartado);
      expect(c.reportes.firstWhere((r) => r.id == 'demo-01').notaPublica, 'Foto repetida');
      expect(find.byType(HojaDecision), findsNothing);

      c.deshacer();
      await _avanzar(tester);
      expect(c.reportes.firstWhere((r) => r.id == 'demo-01').estado, EstadoReporte.recibido);
      await _cerrar(tester, c);
      c.dispose();
    });

    testWidgets('aprobar muestra «Deshacer» y se confirma pasado el plazo', (tester) async {
      final c = _controlador(demo: true);
      await _montar(tester, const PanelCra(), admin: c);
      await _tocar(tester, find.byType(TarjetaAdmin).first);
      await tester.scrollUntilVisible(find.text('Aprobar'), 300, scrollable: find.byType(Scrollable).first);
      await _tocar(tester, find.text('Aprobar'));
      await tester.tap(find.descendant(of: find.byType(HojaDecision), matching: find.text('Sí, aprobar')));
      await _avanzar(tester);
      // Volvió a la bandeja y ahí está la barra.
      expect(find.text('Reporte aprobado'), findsOneWidget);
      expect(find.text('Deshacer'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      expect(c.pendiente, isNull);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Reporte aprobado'), findsNothing);
      await _cerrar(tester, c);
      c.dispose();
    });

    testWidgets('con servidor configurado sin sesión pide correo y contraseña, y no ofrece la demostración', (tester) async {
      final c = _controlador(servidor: true);
      await _montar(tester, const PanelCra(), admin: c);
      expect(find.text('Correo'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Ver la demostración'), findsNothing);
      await _cerrar(tester, c);
      c.dispose();
    });

    testWidgets('sin servidor solo se ofrece la demostración y se entra con un toque', (tester) async {
      final c = _controlador();
      await _montar(tester, const PanelCra(), admin: c);
      expect(find.text('Correo'), findsNothing);
      expect(find.text('Ver la demostración'), findsWidgets);
      await tester.tap(find.byType(BotonEstado).first);
      await _avanzar(tester, veces: 8);
      expect(c.dentro, isTrue);
      expect(c.demostracion, isTrue);
      expect(find.textContaining('Datos de ejemplo'), findsOneWidget);
      await _cerrar(tester, c);
      c.dispose();
    });

    testWidgets('el acceso tiene un campo de correo y otro de contraseña oculto', (tester) async {
      final c = _controlador(servidor: true);
      await _montar(tester, Scaffold(body: AccesoAdmin(controlador: c)), admin: c);
      final campos = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(campos.length, 2);
      expect(campos[1].obscureText, isTrue);
      await _cerrar(tester, c);
      c.dispose();
    });
  });

  group('Entrada desde Guardián', () {
    testWidgets('la fila discreta abre el panel y, con sesión, muestra cuántos hay por revisar', (tester) async {
      final c = _controlador();
      await _montar(tester, const Scaffold(body: SafeArea(child: EntradaPanelCra())), admin: c);
      expect(find.text('Panel CRA'), findsOneWidget);
      expect(find.textContaining('Ver cómo se verifican'), findsOneWidget);
      await tester.tap(find.text('Panel CRA'));
      await _avanzar(tester);
      expect(find.byType(PanelCra), findsOneWidget);
      c.entrarDemo();
      await _avanzar(tester);
      expect(c.dentro, isTrue);
      await _cerrar(tester, c);
      c.dispose();
    });

    testWidgets('sin panel en el árbol (pantallas sueltas) la fila no aparece', (tester) async {
      await _montar(tester, const Scaffold(body: EntradaPanelCra()));
      expect(find.text('Panel CRA'), findsNothing);
      await _cerrar(tester);
    });
  });

  group('Avisos', () {
    testWidgets('al llegar un reporte nuevo cae un aviso arriba y el contador del ícono sube', (tester) async {
      final c = _controlador(demo: true);
      final e = _estado();
      await _montar(
        tester,
        CapaAvisos(verMisReportes: () {}, child: Scaffold(body: Center(child: Builder(builder: (ctx) => Text('Sin ver: ${AdminScope.de(ctx).sinVer}'))))),
        admin: c,
        estado: e,
      );
      c.marcarVistos();
      await _avanzar(tester, veces: 2);
      expect(find.text('Sin ver: 0'), findsOneWidget);
      expect(find.text('Reporte nuevo'), findsNothing);
      c.simularLlegada();
      await _avanzar(tester);
      expect(find.text('Reporte nuevo'), findsOneWidget);
      expect(find.text('Abrir panel'), findsOneWidget);
      expect(find.text('Sin ver: 1'), findsOneWidget);

      await tester.tap(find.text('Abrir panel'));
      await _avanzar(tester);
      expect(find.byType(PanelCra), findsOneWidget);
      expect(c.aviso, isNull);
      await _cerrar(tester, c);
      c.dispose();
    });

    testWidgets('el aviso del equipo no sale si no hay sesión del panel', (tester) async {
      final c = _controlador();
      await _montar(tester, CapaAvisos(verMisReportes: () {}, child: const Scaffold(body: SizedBox())), admin: c);
      expect(find.text('Reporte nuevo'), findsNothing);
      await _cerrar(tester, c);
      c.dispose();
    });

    testWidgets('la bandeja abierta no suma al contador: lo que llega ya se ve', (tester) async {
      final c = _controlador(demo: true);
      await _montar(tester, const PanelCra(), admin: c);
      c.simularLlegada();
      await _avanzar(tester);
      expect(c.sinVer, 0);
      await _cerrar(tester, c);
      c.dispose();
    });

    testWidgets('al ciudadano le avisan una sola vez cuando su reporte cambia de estado', (tester) async {
      final e = _estado();
      final r = reporteDePrueba(idDePrueba(1), envio: Envio.enviado, estado: EstadoReporte.verificado);
      e.reportes.add(r);
      SharedPreferences.setMockInitialValues({
        AvisosCiudadano.clave: jsonEncode({r.id: 'recibido'}),
      });
      var fue = 0;
      await _montar(tester, CapaAvisos(verMisReportes: () => fue++, child: const Scaffold(body: SizedBox())), estado: e);
      await _avanzar(tester);
      expect(find.text('Tu reporte cambió'), findsOneWidget);
      expect(find.textContaining('Aprobaron tu reporte'), findsOneWidget);
      // Quedó anotado como visto: no se repite al reabrir.
      final prefs = await SharedPreferences.getInstance();
      expect((jsonDecode(prefs.getString(AvisosCiudadano.clave)!) as Map)[r.id], 'verificado');

      await tester.tap(find.text('Ver'));
      await _avanzar(tester);
      expect(fue, 1);
      expect(find.text('Tu reporte cambió'), findsNothing);
      await _cerrar(tester);
    });

    testWidgets('la primera vez no avisa de lo que ya estaba, y un rechazo trae el motivo', (tester) async {
      final e = _estado();
      final r = reporteDePrueba(idDePrueba(2), envio: Envio.enviado, estado: EstadoReporte.descartado)
        ..historial.add(CambioEstado(EstadoReporte.descartado, DateTime.now(), 'La foto es de otro lugar'));
      e.reportes.add(r);
      SharedPreferences.setMockInitialValues({}); // sin la clave: primera vez
      await _montar(tester, CapaAvisos(verMisReportes: () {}, child: const Scaffold(body: SizedBox())), estado: e);
      await _avanzar(tester);
      expect(find.text('Tu reporte cambió'), findsNothing);

      // Después, algo cambia de verdad: ahora sí.
      final r2 = reporteDePrueba(idDePrueba(3), envio: Envio.enviado, estado: EstadoReporte.descartado)
        ..historial.add(CambioEstado(EstadoReporte.descartado, DateTime.now(), 'La foto es de otro lugar'));
      e.reportes.add(r2);
      e.cambioDeRed(true);
      await _avanzar(tester);
      expect(find.text('Tu reporte cambió'), findsOneWidget);
      expect(find.textContaining('La foto es de otro lugar'), findsOneWidget);
      await _cerrar(tester);
    });
  });
}
