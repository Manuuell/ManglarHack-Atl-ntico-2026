// Contenido editable del panel: modelo (fábrica, ida y vuelta), controlador (servidor, copia, fábrica,
// permisos, vuelta atrás si el servidor no acepta, historial) y la pantalla a 390 y 1280.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/admin/contenido_panel.dart';
import 'package:zanky/datos/admin/contenido_publico.dart';
import 'package:zanky/vistas/admin/contenido/franja_portada.dart';
import 'package:zanky/datos/comunidad/comunidad.dart';
import 'package:zanky/datos/permisos/permisos_rol.dart';
import 'package:zanky/datos/sensores/lecturas_sensor.dart';
import 'package:zanky/nucleo/identidad.dart';
import 'package:zanky/vistas/admin/contenido/seccion_contenido_admin.dart';

class _Falsa implements FuenteContenidoPanel {
  List<Map<String, dynamic>> filas = [];
  bool sinTabla = false, sinRed = false, rechazar = false;
  final guardados = <(String, Map<String, dynamic>, String)>[];

  @override
  Future<List<Map<String, dynamic>>> leer() async {
    if (sinTabla) throw const SinTablaContenido();
    if (sinRed) throw const ErrorContenido('Sin conexión con el servidor.', deRed: true);
    return filas;
  }

  @override
  Future<void> guardar(String clave, Map<String, dynamic> valor, String resumen) async {
    if (rechazar) throw const ErrorContenido('Tu rol no tiene permiso para este cambio.');
    guardados.add((clave, valor, resumen));
  }

  @override
  Future<List<Map<String, dynamic>>> historial() async => [
        {'creado_en': '2026-11-27T20:00:00Z', 'correo': 'ana@cra.gov.co', 'rol': 'admin', 'clave': 'portada', 'resumen': 'Cambió la portada'},
      ];

  @override
  Future<List<Map<String, dynamic>>> puntos() async => [
        {'codigo': 'muelle-1', 'titulo': 'Muelle', 'zona': 'Bocana', 'activo': false},
      ];
}

final _jornada = JornadaPanel(id: 'j-1', titulo: 'Siembra en Bocana', fecha: DateTime(2026, 11, 28, 7), lugar: 'Muelle', cupos: 30);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('modelo', () {
    test('fábrica: portada vacía, umbrales de referencia', () {
      const c = ContenidoPanel.fabrica;
      expect(c.portada.mensaje, isEmpty);
      for (final t in TipoSensor.values) {
        expect(c.umbral(t), t.umbralReferencia);
      }
    });

    test('ida y vuelta por filas, cupos «sin límite» como nulo', () {
      final c = ContenidoPanel.fabrica.copiar(
        portada: const PortadaPanel(mensaje: 'Hola', aviso: 'Marea alta', avisoActivo: true),
        jornadas: [_jornada, _jornada.copiar(sinLimite: true).copiarId('j-2')],
        fijadas: {3},
        ocultas: {5},
        puntosInactivos: {'muelle-1'},
        umbrales: {'salinidad': 40},
      );
      final v = ContenidoPanel.deFilas(c.aFilas());
      expect(v.portada, c.portada);
      expect(v.jornadas.map((j) => j.cupos), [30, null]);
      expect(v.jornadas.last.textoCupos, 'Sin límite de cupos');
      expect(v.fijadas, {3});
      expect(v.ocultas, {5});
      expect(v.puntosInactivos, {'muelle-1'});
      expect(v.umbral(TipoSensor.salinidad), 40);
      expect(v.umbral(TipoSensor.turbidez), TipoSensor.turbidez.umbralReferencia);
    });

    test('lo que no se entiende se ignora', () {
      final v = ContenidoPanel.deFilas([
        {'clave': 'otra', 'valor': {}},
        {'clave': 'jornadas', 'valor': {'lista': [{'id': 1}, 'x']}},
        {'clave': 'umbrales_sensores', 'valor': {'umbrales': {'inventado': 3, 'salinidad': 'mucho'}}},
      ]);
      expect(v.jornadas, isEmpty);
      expect(v.umbrales, isEmpty);
    });
  });

  group('controlador', () {
    test('servidor: guarda la sección con su clave y deja historial', () async {
      final f = _Falsa();
      final c = ControladorContenidoPanel(fuente: f);
      await c.cargar();
      expect(c.origen, OrigenContenido.servidor);
      final fallo = await c.guardar(SeccionContenido.jornadas, c.contenido.copiar(jornadas: [_jornada]), 'Creó la jornada');
      expect(fallo, isNull);
      expect(f.guardados.single.$1, 'jornadas');
      expect((f.guardados.single.$2['lista'] as List).single['cupos'], 30);
      expect(c.historial.first.resumen, 'Creó la jornada');
    });

    test('si el servidor no acepta, vuelve a como estaba', () async {
      final f = _Falsa()..rechazar = true;
      final c = ControladorContenidoPanel(fuente: f);
      await c.cargar();
      final fallo = await c.guardar(SeccionContenido.portada,
          c.contenido.copiar(portada: const PortadaPanel(mensaje: 'Nuevo')), 'Cambió la portada');
      expect(fallo, contains('permiso'));
      expect(c.contenido.portada.mensaje, isEmpty);
    });

    test('sin la tabla: valores de fábrica y no deja guardar', () async {
      final c = ControladorContenidoPanel(fuente: _Falsa()..sinTabla = true);
      await c.cargar();
      expect(c.origen, OrigenContenido.fabrica);
      expect(c.editable, isFalse);
      expect(await c.guardar(SeccionContenido.portada, ContenidoPanel.fabrica.copiar(portada: const PortadaPanel(mensaje: 'x')), 'r'),
          contains('contenido_editable.sql'));
    });

    test('sin señal: usa la última copia guardada', () async {
      final f = _Falsa()
        ..filas = [
          {'clave': 'portada', 'valor': {'mensaje': 'Copia'}},
        ];
      await (ControladorContenidoPanel(fuente: f)).cargar();
      f.sinRed = true;
      final c = ControladorContenidoPanel(fuente: f);
      await c.cargar();
      expect(c.origen, OrigenContenido.copia);
      expect(c.sinSenal, isTrue);
      expect(c.contenido.portada.mensaje, 'Copia');
      expect(c.editable, isFalse);
    });

    test('sin el permiso de la sección no se guarda', () async {
      final f = _Falsa();
      final c = ControladorContenidoPanel(fuente: f, puede: (p) => p == Permiso.editarContenido);
      await c.cargar();
      expect(c.puedeEditar(SeccionContenido.portada), isTrue);
      expect(c.puedeEditar(SeccionContenido.umbrales), isFalse);
      final fallo = await c.guardar(SeccionContenido.umbrales, c.contenido.copiar(umbrales: {'salinidad': 30}), 'r');
      expect(fallo, contains('Puntos QR'));
      expect(f.guardados, isEmpty);
    });

    test('historial y puntos del servidor (el estado real del punto manda)', () async {
      final c = ControladorContenidoPanel(fuente: _Falsa());
      await c.cargar();
      await c.cargarHistorial();
      expect(c.historial.single.quien, 'ana@cra.gov.co · Administración');
      await c.cargarPuntos();
      expect(c.puntos!.single.codigo, 'muelle-1');
      expect(c.contenido.puntosInactivos, {'muelle-1'});
    });
  });

  group('en la app', () {
    NoticiaManglar n(int id) =>
        NoticiaManglar(id: id, fecha: DateTime(2026, 11, id), titulo: 'N$id', resumen: '', parrafos: const [], enlace: '', imagen: null);

    test('noticias: sin las ocultas y con las fijadas arriba', () {
      final c = ContenidoPanel.fabrica.copiar(fijadas: {3}, ocultas: {2});
      expect(aplicarAjustesNoticias([n(1), n(2), n(3)], c).map((x) => x.id), [3, 1]);
      expect(aplicarAjustesNoticias([n(1), n(2)], ContenidoPanel.fabrica).map((x) => x.id), [1, 2]);
    });

    testWidgets('Inicio: la franja sale al guardar la portada y no ocupa nada si está vacía', (tester) async {
      reiniciarContenidoPublico();
      await tester.pumpWidget(MaterialApp(theme: temaCra(), home: const Scaffold(body: Column(children: [FranjaPortada()]))));
      await tester.pump();
      expect(find.text('DE LA CRA'), findsNothing);
      final c = ControladorContenidoPanel();
      await c.cargar();
      await c.guardar(SeccionContenido.portada,
          c.contenido.copiar(portada: const PortadaPanel(mensaje: 'Siembra el sábado', aviso: 'Marea alta', avisoActivo: true)), 'r');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Siembra el sábado'), findsOneWidget);
      expect(find.text('Marea alta'), findsOneWidget);
      reiniciarContenidoPublico();
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('pantalla', () {
    final noticias = [
      NoticiaManglar(id: 1, fecha: DateTime(2026, 11, 20), titulo: 'La CRA siembra mangle', resumen: '', parrafos: const [], enlace: '', imagen: null),
    ];

    Future<void> montar(WidgetTester tester, ControladorContenidoPanel c, Size tam) async {
      tester.view.physicalSize = tam;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
        theme: temaCra(),
        home: Scaffold(body: SeccionContenidoAdmin(controlador: c, noticias: () async => noticias)),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    Future<void> cerrar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    }

    testWidgets('390: portada se edita, se guarda y queda en el historial (demostración)', (tester) async {
      final c = ControladorContenidoPanel();
      await montar(tester, c, const Size(390, 844));
      expect(find.textContaining('Demostración'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Sembramos el sábado');
      await tester.pump();
      await tester.tap(find.text('Guardar portada'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(c.contenido.portada.mensaje, 'Sembramos el sábado');
      expect(c.historial.single.resumen, contains('portada'));
      expect(tester.takeException(), isNull);
      await cerrar(tester);
    });

    testWidgets('1280: lista de secciones al lado y todas se abren sin desbordes', (tester) async {
      final c = ControladorContenidoPanel()..contenido = ContenidoPanel.fabrica.copiar(jornadas: [_jornada]);
      await montar(tester, c, const Size(1280, 800));
      for (final s in ['Jornadas', 'Noticias', 'Puntos QR', 'Umbrales', 'Historial']) {
        await tester.tap(find.text(s).first);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        expect(tester.takeException(), isNull, reason: s);
      }
      await tester.tap(find.text('Jornadas').first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Siembra en Bocana'), findsOneWidget);
      expect(find.text('30 cupos'), findsOneWidget);
      await cerrar(tester);
    });

    testWidgets('sin permisos de jornadas ni puntos, solo se ven portada, noticias e historial', (tester) async {
      final c = ControladorContenidoPanel(puede: (p) => p == Permiso.editarContenido);
      await montar(tester, c, const Size(390, 844));
      expect(find.text('Jornadas'), findsNothing);
      expect(find.text('Umbrales'), findsNothing);
      expect(find.text('Noticias'), findsOneWidget);
      await cerrar(tester);
    });
  });
}

extension on JornadaPanel {
  JornadaPanel copiarId(String id) =>
      JornadaPanel(id: id, titulo: titulo, fecha: fecha, lugar: lugar, fotoUrl: fotoUrl, cupos: cupos, cerrada: cerrada);
}
