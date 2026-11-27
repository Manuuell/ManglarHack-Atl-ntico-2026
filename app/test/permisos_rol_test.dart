// Permisos por rol del panel: la matriz (pura), el controlador con caché y respaldo, el puente
// con la cuenta, y la pantalla (390 y 1280) con interruptores, casillas y mantener presionado.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/permisos/permisos_rol.dart';
import 'package:zanky/datos/permisos/repositorio_permisos.dart';
import 'package:zanky/nucleo/identidad.dart';
import 'package:zanky/nucleo/kit/interruptor.dart';
import 'package:zanky/datos/admin/controlador_admin.dart';
import 'package:zanky/datos/admin/reporte_admin.dart';
import 'package:zanky/datos/roles.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/datos/sensores/servicio_sensores.dart';
import 'package:zanky/vistas/admin/bandeja_admin.dart';
import 'package:zanky/vistas/admin/permisos/pantalla_permisos.dart';
import 'package:zanky/vistas/admin/sensores/seccion_sensores_admin.dart';

class _FuenteFalsa implements FuentePermisos {
  _FuenteFalsa({this.filas, this.sinTabla = false, this.sinRed = false});
  List<Map<String, dynamic>>? filas;
  bool sinTabla;
  bool sinRed;
  bool rechazar = false;
  final fijados = <(RolEquipo, Permiso, bool)>[];
  final asignados = <(String, RolEquipo)>[];

  @override
  Future<List<Map<String, dynamic>>> leer() async {
    if (sinTabla) throw const SinTablaPermisos();
    if (sinRed) throw const ErrorPermisos('Sin conexión con el servidor.', deRed: true);
    return filas ?? const [];
  }

  @override
  Future<void> fijar(RolEquipo rol, Permiso p, bool activo) async {
    if (rechazar) throw const ErrorPermisos('Tu rol no permite cambiar permisos.');
    fijados.add((rol, p, activo));
  }

  @override
  Future<void> asignarRol(String correo, RolEquipo rol) async => asignados.add((correo, rol));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    permisosConfigurados.value = null;
  });

  group('matriz', () {
    test('las plantillas por defecto: admin todo, voluntario solo mira', () {
      final m = MatrizPermisos.porDefecto();
      for (final p in Permiso.values) {
        expect(m.puede(RolEquipo.admin, p), isTrue, reason: p.id);
      }
      expect(m.de(RolEquipo.voluntario), {Permiso.verReportes});
      expect(m.puede(RolEquipo.vigia, Permiso.decidirReportes), isTrue);
      expect(m.puede(RolEquipo.vigia, Permiso.verDatosPersonales), isFalse);
      expect(m.puede(null, Permiso.verReportes), isFalse);
    });

    test('las cinco plantillas pedidas existen y coinciden con su rol', () {
      expect(Plantillas.todas.map((t) => t.id), ['admin', 'investigador', 'organizador', 'encargado_zona', 'voluntario']);
      final m = MatrizPermisos.porDefecto();
      expect(m.plantillaDe(RolEquipo.organizador), same(Plantillas.organizador));
      expect(m.plantillaDe(RolEquipo.moderador), isNull, reason: 'moderación es personalizada');
    });

    test('con() es inmutable y admin conserva «administrar roles»', () {
      final m = MatrizPermisos.porDefecto();
      final m2 = m.con(RolEquipo.vigia, Permiso.decidirReportes, false);
      expect(m.puede(RolEquipo.vigia, Permiso.decidirReportes), isTrue);
      expect(m2.puede(RolEquipo.vigia, Permiso.decidirReportes), isFalse);
      expect(identical(m.con(RolEquipo.admin, Permiso.administrarRoles, false), m), isTrue);
      final sinNada = m.conPlantilla(RolEquipo.admin, Plantillas.voluntario);
      expect(sinNada.puede(RolEquipo.admin, Permiso.administrarRoles), isTrue);
    });

    test('desde filas: ignora claves desconocidas y filas apagadas', () {
      final m = MatrizPermisos.deFilas([
        {'rol': 'vigia', 'permiso': 'ver_reportes', 'activo': true},
        {'rol': 'vigia', 'permiso': 'decidir_reportes', 'activo': false},
        {'rol': 'marciano', 'permiso': 'ver_reportes'},
        {'rol': 'vigia', 'permiso': 'volar'},
      ]);
      expect(m.de(RolEquipo.vigia), {Permiso.verReportes});
      expect(m.de(RolEquipo.admin), {Permiso.administrarRoles});
    });

    test('diferencias y aFilas hacen el viaje de ida y vuelta', () {
      final a = MatrizPermisos.porDefecto();
      final b = a.con(RolEquipo.aliado, Permiso.avisarZona, true).con(RolEquipo.vigia, Permiso.verReportes, false);
      expect(a.diferencias(b).toSet(), {(RolEquipo.aliado, Permiso.avisarZona, true), (RolEquipo.vigia, Permiso.verReportes, false)});
      expect(MatrizPermisos.deFilas(b.aFilas()).diferencias(b), isEmpty);
    });

    test('el puente con la cuenta traduce la matriz a gestiones', () {
      final g = gestionesDeMatriz(MatrizPermisos.porDefecto());
      expect(g['organizador'], containsAll([Gestion.jornadas, Gestion.puntos]));
      expect(g['voluntario'], isNot(contains(Gestion.panelCra)));
      expect(g['vigia'], contains(Gestion.panelCra));
      expect(g['admin'], containsAll(Gestion.values));
    });
  });

  group('controlador', () {
    test('sin la tabla en el servidor usa las plantillas y no toca la cuenta', () async {
      final c = ControladorPermisos(fuente: _FuenteFalsa(sinTabla: true), rolActual: RolEquipo.admin);
      await c.cargar();
      expect(c.origen, OrigenPermisos.plantillas);
      expect(c.editable, isFalse, reason: 'no se edita lo que no se puede guardar');
      expect(permisosConfigurados.value, isNull);
    });

    test('del servidor: edita, guarda copia y, sin señal, vuelve a la copia', () async {
      final f = _FuenteFalsa(filas: MatrizPermisos.porDefecto().aFilas());
      final c = ControladorPermisos(fuente: f, rolActual: RolEquipo.admin);
      await c.cargar();
      expect(c.origen, OrigenPermisos.servidor);
      expect(c.editable, isTrue);
      expect(await c.fijar(RolEquipo.voluntario, Permiso.avisarZona, true), isNull);
      expect(f.fijados, [(RolEquipo.voluntario, Permiso.avisarZona, true)]);
      expect(permisosConfigurados.value!['voluntario'], contains(Gestion.avisos));
      await Future<void>.delayed(Duration.zero);

      final otro = ControladorPermisos(fuente: _FuenteFalsa(sinRed: true), rolActual: RolEquipo.admin);
      await otro.cargar();
      expect(otro.origen, OrigenPermisos.copia);
      expect(otro.matriz.puede(RolEquipo.voluntario, Permiso.avisarZona), isTrue);
      expect(otro.editable, isFalse);
    });

    test('si el servidor rechaza, el cambio vuelve atrás y se dice por qué', () async {
      final f = _FuenteFalsa(filas: MatrizPermisos.porDefecto().aFilas())..rechazar = true;
      final c = ControladorPermisos(fuente: f, rolActual: RolEquipo.admin);
      await c.cargar();
      final r = await c.fijar(RolEquipo.vigia, Permiso.decidirReportes, false);
      expect(r, contains('no permite'));
      expect(c.matriz.puede(RolEquipo.vigia, Permiso.decidirReportes), isTrue);
    });

    test('quien no administra roles no edita; la demostración sí, en memoria', () async {
      final c = ControladorPermisos(fuente: _FuenteFalsa(filas: const []), rolActual: RolEquipo.vigia);
      await c.cargar();
      expect(c.editable, isFalse);
      final antes = permisosConfigurados.value;
      final demo = ControladorPermisos(rolActual: RolEquipo.moderador);
      expect(demo.editable, isTrue);
      await demo.fijar(RolEquipo.moderador, Permiso.decidirReportes, false);
      expect(demo.puede(Permiso.decidirReportes), isFalse);
      expect(permisosConfigurados.value, same(antes), reason: 'la demo no cambia la app real');
    });

    test('dar rol valida el correo', () async {
      final f = _FuenteFalsa(filas: const []);
      final c = ControladorPermisos(fuente: f, rolActual: RolEquipo.admin);
      expect(await c.asignarRol('no-es-correo', RolEquipo.vigia), isNotNull);
      expect(await c.asignarRol(' ana@cra.gov.co ', RolEquipo.vigia), isNull);
      expect(f.asignados, [('ana@cra.gov.co', RolEquipo.vigia)]);
    });
  });

  group('pantalla', () {
    Future<void> montar(WidgetTester tester, ControladorPermisos c, Size tam) async {
      tester.view.physicalSize = tam;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
        theme: temaCra(),
        home: PermisosScope(controlador: c, child: PantallaPermisos(controlador: c, demostracion: c.fuente == null)),
      ));
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> avanzar(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    Future<void> cerrar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    }

    testWidgets('390: un rol a la vez, el interruptor cambia el permiso y ofrece Deshacer', (tester) async {
      final c = ControladorPermisos(rolActual: RolEquipo.admin);
      await montar(tester, c, const Size(390, 844));
      expect(tester.takeException(), isNull);
      expect(find.text('Moderación CRA'), findsWidgets);
      expect(find.byType(InterruptorIos), findsNWidgets(Permiso.values.length));
      expect(find.textContaining('Demostración'), findsOneWidget);

      await tester.tap(find.text('Vigía'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Personalizado'), findsOneWidget);
      await tester.tap(find.text('Aprobar y rechazar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.matriz.puede(RolEquipo.vigia, Permiso.decidirReportes), isFalse);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Deshacer'), findsOneWidget);
      await tester.tap(find.text('Deshacer'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(c.matriz.puede(RolEquipo.vigia, Permiso.decidirReportes), isTrue);
      await cerrar(tester);
    });

    testWidgets('dar un permiso sensible pide confirmación', (tester) async {
      final c = ControladorPermisos(rolActual: RolEquipo.admin);
      await montar(tester, c, const Size(390, 844));
      await tester.tap(find.text('Voluntariado'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('Datos personales'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Datos personales'));
      await avanzar(tester);
      expect(find.text('Dar permiso'), findsOneWidget);
      expect(c.matriz.puede(RolEquipo.voluntario, Permiso.verDatosPersonales), isFalse);
      await tester.tap(find.text('Dar permiso'));
      await avanzar(tester);
      expect(c.matriz.puede(RolEquipo.voluntario, Permiso.verDatosPersonales), isTrue);
      await cerrar(tester);
    });

    testWidgets('mantener presionado un rol abre su resumen y aplica una plantilla', (tester) async {
      final c = ControladorPermisos(rolActual: RolEquipo.admin);
      await montar(tester, c, const Size(390, 844));
      await tester.longPress(find.text('Aliado'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Plantilla Organización'), findsOneWidget);
      await tester.tap(find.text('Plantilla Organización'));
      await avanzar(tester);
      expect(c.matriz.de(RolEquipo.aliado), Plantillas.organizador.permisos);
      await cerrar(tester);
    });

    testWidgets('1280: la matriz entera, con candado en lo que no se quita', (tester) async {
      final c = ControladorPermisos(rolActual: RolEquipo.admin);
      await montar(tester, c, const Size(1280, 800));
      expect(tester.takeException(), isNull);
      expect(find.byType(InterruptorIos), findsNothing);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Jornadas para Voluntariado'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.matriz.puede(RolEquipo.voluntario, Permiso.gestionarJornadas), isTrue);
      await cerrar(tester);
    });

    for (final tam in const [Size(360, 800), Size(390, 844), Size(1280, 800)]) {
      testWidgets('sin desbordes a ${tam.width.toInt()} con letra x2', (tester) async {
        final c = ControladorPermisos(rolActual: RolEquipo.admin);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await montar(tester, c, tam);
        expect(tester.takeException(), isNull);
        await cerrar(tester);
      });
    }

    testWidgets('sin la tabla en el servidor lo dice discreto y no deja editar', (tester) async {
      final c = ControladorPermisos(fuente: _FuenteFalsa(sinTabla: true), rolActual: RolEquipo.admin);
      await c.cargar();
      await montar(tester, c, const Size(390, 844));
      expect(find.textContaining('Plantillas por defecto'), findsOneWidget);
      await tester.tap(find.text('Aprobar y rechazar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.matriz.puede(RolEquipo.moderador, Permiso.decidirReportes), isTrue);
      await cerrar(tester);
    });
  });

  group('panel', () {
    Future<void> montarEn(WidgetTester tester, Widget w, Size tam) async {
      tester.view.physicalSize = tam;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(theme: temaCra(), home: Scaffold(body: w)));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    test('Sensores solo para los roles con la gestión de sensores', () {
      expect(RolPanel.puede('moderador_cra', Gestion.sensores), isTrue);
      expect(RolPanel.puede('voluntario', Gestion.sensores), isFalse);
      expect(RolPanel.puede(null, Gestion.sensores), isFalse);
    });

    for (final tam in const [Size(390, 844), Size(1280, 800)]) {
      testWidgets('Sensores y microcontroladores a ${tam.width.toInt()}: estaciones, alertas y rótulo de demostración',
          (tester) async {
        final servicio = ServicioSensores(servidor: Servidor(base: '', anon: ''));
        await montarEn(tester, SeccionSensoresAdmin(servicio: servicio), tam);
        expect(tester.takeException(), isNull);
        // Y con letra x2 tampoco se desborda.
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('demostración'), findsOneWidget);
        expect(find.text('Estaciones ESP32'), findsOneWidget);
        expect(find.text('Alertas de umbral'), findsOneWidget);
        expect(find.text('Pantalla completa'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      });
    }

    testWidgets('sin «Aprobar y rechazar» la tarjeta no ofrece decidir al mantener presionado', (tester) async {
      final semilla = reportesDemo(DateTime.now());
      final admin = ControladorAdmin(servidor: Servidor(base: '', anon: ''), cada: Duration.zero)..entrarDemo(semilla: semilla);
      final r = semilla.firstWhere((x) => x.pendiente);
      final permisos = ControladorPermisos(rolActual: RolEquipo.moderador);
      Widget tarjeta() => PermisosScope(
            controlador: permisos,
            child: ListView(children: [TarjetaAdminConGestos(controlador: admin, reporte: r)]),
          );
      await montarEn(tester, tarjeta(), const Size(390, 844));
      await tester.longPress(find.byType(TarjetaAdminConGestos));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('Aprobar'), findsWidgets);
      await tester.tapAt(const Offset(10, 10));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      await permisos.fijar(RolEquipo.moderador, Permiso.decidirReportes, false);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.longPress(find.byType(TarjetaAdminConGestos));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('Aprobar'), findsNothing);
      expect(find.text('Abrir detalle'), findsOneWidget);
      admin.salir();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
