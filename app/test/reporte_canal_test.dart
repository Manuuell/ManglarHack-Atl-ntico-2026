// Reglas y textos del reporte por WhatsApp (bot/src/flujos/textos.ts, config.ts) llevados a la
// app, y el flujo completo de vistas con ellos a 390x844 y 1280x800.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/reporte.dart';
import 'package:zanky/datos/reporte_canal.dart';
import 'package:zanky/datos/tipos.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/reporte/enviado.dart';
import 'package:zanky/vistas/reporte/flujo_reporte.dart';
import 'package:zanky/vistas/reporte/paso_detalles.dart';
import 'package:zanky/vistas/reporte/borrador.dart';
import 'package:zanky/vistas/reporte/paso_evidencia.dart';

import 'servidor_contrato_test.dart' show jpegConGps;

late Manglar _manglar;

Reporte _reporte(String id, DateTime cuando, {Envio envio = Envio.enviado, EstadoReporte estado = EstadoReporte.recibido, String? fotoHash}) =>
    Reporte(
      id: id,
      tipo: TipoAmenaza.tala,
      descripcion: '',
      punto: const LatLng(11.05316, -74.85094),
      precisionM: 8,
      metodo: MetodoUbicacion.gps,
      capturadoEn: cuando,
      momento: Momento.ahora,
      magnitud: Magnitud.mediana,
      zonaId: 'mallorquin',
      zonaNombre: 'Ciénaga de Mallorquín',
      municipio: 'Barranquilla',
      dentroPoligono: true,
      distanciaM: 0,
      prioridad: 3,
      motivosPrioridad: const [],
      confianza: 60,
      anonimo: false,
      reportanteId: null,
      envio: envio,
      estado: estado,
      fotoHash: fotoHash,
    );

Future<void> _montar(WidgetTester tester, EstadoZanky estado, Widget hijo, Size tamano) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(Zanky(
    estado: estado,
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: temaZanky(), home: hijo),
  ));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _esperar(WidgetTester tester, [int veces = 6]) async {
  for (var i = 0; i < veces; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final j = jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync());
    _manglar = Manglar.desdeJson(j as Map<String, dynamic>);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Reglas del bot', () {
    test('confianza con la regla de evaluacion.ts y del formulario web', () {
      // Foto + GPS + dentro + ahora + descripción: 20+25+20+15+10+5 = 95, el cliente topa en 80.
      final completo = confianzaCanal(
          conFoto: true, fotoHash: 'h1', metodo: MetodoUbicacion.gps, dentro: true, distanciaM: 0,
          momento: Momento.ahora, descripcion: 'Cortan mangle con motosierra');
      expect(completo.puntaje, 80);
      expect(completo.motivos, containsAll(['+20 base', '+25 trae foto', '+20 ubicación del GPS', '+15 dentro del manglar']));
      // Sin foto, por enlace, a 300 m, de hoy y sin detalle: 20+10+10+5 = 45.
      expect(
          confianzaCanal(
                  conFoto: false, metodo: MetodoUbicacion.enlace, dentro: false, distanciaM: 300,
                  momento: Momento.hoy, descripcion: 'humo')
              .puntaje,
          45);
      // Lejos y de antes: solo base + mapa = 30.
      expect(
          confianzaCanal(
                  conFoto: false, metodo: MetodoUbicacion.mapa, dentro: false, distanciaM: 900,
                  momento: Momento.antes, descripcion: '')
              .puntaje,
          30);
      // Foto repetida de otro reporte propio: -30; corroboraciones suman de a 10 hasta 20.
      final previo = _reporte('p1', DateTime(2026, 11, 26), fotoHash: 'h1');
      expect(
          confianzaCanal(
                  conFoto: true, fotoHash: 'h1', metodo: MetodoUbicacion.gps, dentro: true, distanciaM: 0,
                  momento: Momento.antes, descripcion: '', corroborados: 3, propios: [previo])
              .puntaje,
          20 - 30 + 20 + 15 + 20);
      // Reportante con un verificado: +10; con dos descartados: -20.
      final verificado = _reporte('v1', DateTime(2026, 11, 20), estado: EstadoReporte.verificado);
      final d1 = _reporte('d1', DateTime(2026, 11, 20), estado: EstadoReporte.descartado);
      final d2 = _reporte('d2', DateTime(2026, 11, 21), estado: EstadoReporte.descartado);
      final base = confianzaCanal(
          conFoto: false, metodo: MetodoUbicacion.mapa, dentro: false, distanciaM: 900, momento: Momento.antes,
          descripcion: '', propios: [verificado]);
      expect(base.puntaje, 40);
      expect(
          confianzaCanal(
                  conFoto: false, metodo: MetodoUbicacion.mapa, dentro: false, distanciaM: 900,
                  momento: Momento.antes, descripcion: '', propios: [d1, d2])
              .puntaje,
          10);
    });

    test('mismos números que bot/src/config.ts', () {
      expect(ReglasCanal.distanciaSospechosaM, 3000);
      expect(ReglasCanal.maxReportesPorHora, 5);
      expect(ReglasCanal.radioInfluenciaM, Ubicacion.influenciaM);
    });

    test('ubicación sospechosa: fuera del manglar y a más de 3 km', () {
      expect(ubicacionSospechosa(dentro: false, distanciaM: 3001), isTrue);
      expect(ubicacionSospechosa(dentro: false, distanciaM: 3000), isFalse);
      expect(ubicacionSospechosa(dentro: true, distanciaM: 9000), isFalse);
      expect(ubicacionSospechosa(dentro: false, distanciaM: double.infinity), isFalse);
    });

    test('5 reportes en la última hora piden una pausa; los rechazados y los viejos no cuentan', () {
      final ahora = DateTime(2026, 11, 27, 12);
      final cuatro = [for (var i = 0; i < 4; i++) _reporte('a$i', ahora.subtract(Duration(minutes: i * 10)))];
      expect(demasiadosSeguidos(cuatro, ahora: ahora), isFalse);
      expect(demasiadosSeguidos([...cuatro, _reporte('r', ahora, envio: Envio.rechazado)], ahora: ahora), isFalse);
      expect(demasiadosSeguidos([...cuatro, _reporte('v', ahora.subtract(const Duration(hours: 2)))], ahora: ahora),
          isFalse);
      expect(demasiadosSeguidos([...cuatro, _reporte('n', ahora, envio: Envio.enCola)], ahora: ahora), isTrue);
    });

    test('textos de ubicación como el bot', () {
      expect(TextosCanal.ubicacionRecibida(dentro: true, distanciaM: 0, zona: 'Mallorquín'),
          'Ubicación recibida: está dentro del manglar (Mallorquín).');
      expect(TextosCanal.ubicacionRecibida(dentro: false, distanciaM: 320.4),
          'Ubicación recibida: está a 320 m del manglar. Lo que pasa cerca también lo afecta.');
      expect(TextosCanal.ubicacionLejana(4567), contains('4.6 km'));
    });

    test('estado en la lista: primero el envío, después el estado del contrato', () {
      final ahora = DateTime(2026, 11, 27);
      expect(TextosCanal.estadoEnLista(_reporte('a', ahora, envio: Envio.enCola)), 'Pendiente de envío');
      expect(TextosCanal.estadoEnLista(_reporte('a', ahora, envio: Envio.error)), 'Pendiente de envío');
      expect(TextosCanal.estadoEnLista(_reporte('a', ahora, envio: Envio.rechazado)), 'No se pudo enviar');
      expect(TextosCanal.estadoEnLista(_reporte('a', ahora, estado: EstadoReporte.alertaOficial)),
          'Alerta oficial (expediente abierto)');
    });

    test('resumen: las seis filas del bot y la descripción cortada a 200', () {
      final filas = TextosCanal.resumen(
        tipo: TipoAmenaza.quema,
        dentro: false,
        distanciaM: 120,
        zona: 'Tubará',
        conFoto: false,
        descripcion: 'x' * 250,
        momento: Momento.ahora,
        magnitud: Magnitud.grande,
      );
      expect(filas.map((f) => f.$1), ['Qué pasa', 'Dónde', 'Foto', 'Qué viste', 'Cuándo', 'Tamaño']);
      expect(filas[1].$2, 'A 120 m del manglar (Tubará)');
      expect(filas[2].$2, 'Sin foto');
      expect(filas[3].$2.length, 201);
      expect(filas[5].$2, 'Grande (más que una cancha)');
    });

    test('el 123 se recuerda solo con lo más grave que pasa ahora', () {
      expect(TextosCanal.pideEmergencia(TipoAmenaza.quema, Momento.ahora), isTrue);
      expect(TextosCanal.pideEmergencia(TipoAmenaza.quema, Momento.antes), isFalse);
      expect(TextosCanal.pideEmergencia(TipoAmenaza.basuras, Momento.ahora), isFalse);
    });

    test('el número de caso es el mismo que el del bot (ZK- + 4 hex)', () {
      expect(_reporte('7f3a1b2c-0000-4000-8000-000000000000', DateTime(2026)).caso, 'ZK-7F3A');
    });
  });

  for (final (nombre, tamano) in const [('390x844', Size(390, 844)), ('1280x800', Size(1280, 800))]) {
    testWidgets('flujo completo a $nombre: lejanía, resumen, 123 y por qué de la prioridad', (tester) async {
      final e = EstadoZanky()..manglar = _manglar;
      // Interior del Atlántico (cerca de Sabanalarga): muy lejos de cualquier manglar.
      await _montar(tester, e, FlujoReporte(estado: e, tipo: TipoAmenaza.quema, punto: const LatLng(10.63, -74.92)),
          tamano);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Usar este punto'));
      await _esperar(tester);
      expect(find.text('¿Seguro que es ahí?'), findsOneWidget);
      await tester.tap(find.text('Sí, es ahí'));
      await _esperar(tester);

      await tester.tap(find.text('Seguir sin foto'));
      await _esperar(tester);
      expect(find.textContaining('llama primero al 123'), findsWidgets);
      // El resumen va al final de la lista: se baja hasta verlo, como lo haría la persona.
      await tester.scrollUntilVisible(find.text('REVISA TU REPORTE'), 200,
          scrollable: find.descendant(of: find.byType(PasoDetalles), matching: find.byType(Scrollable)).first);
      expect(find.text('REVISA TU REPORTE'), findsOneWidget);
      expect(find.text('Sin foto'), findsOneWidget);

      await tester.tap(find.textContaining('Guardar reporte'));
      await _esperar(tester, 20);
      expect(find.byType(ReporteEnviado), findsOneWidget);
      expect(find.textContaining('¿Por qué prioridad'), findsOneWidget);
      await tester.tap(find.textContaining('¿Por qué prioridad'));
      await _esperar(tester);
      expect(find.textContaining('gravedad base'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
    });
  }

  testWidgets('«Cambiarla» deja a la persona en «¿Dónde?»', (tester) async {
    final e = EstadoZanky()..manglar = _manglar;
    await _montar(tester, e, FlujoReporte(estado: e, tipo: TipoAmenaza.tala, punto: const LatLng(10.63, -74.92)),
        const Size(390, 844));
    await tester.tap(find.text('Usar este punto'));
    await _esperar(tester);
    await tester.tap(find.text('Cambiarla'));
    await _esperar(tester);
    expect(find.text('Seguir sin foto'), findsNothing);
    expect(find.text('Usar este punto'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('con 5 reportes en la última hora, Zanky pregunta antes de seguir', (tester) async {
    final e = EstadoZanky()..manglar = _manglar;
    final ahora = DateTime.now();
    e.reportes.addAll([for (var i = 0; i < 5; i++) _reporte('b$i', ahora.subtract(Duration(minutes: i)))]);
    await _montar(tester, e, FlujoReporte(estado: e, tipo: TipoAmenaza.tala), const Size(390, 844));
    await _esperar(tester);
    expect(find.text('Varios reportes seguidos'), findsOneWidget);
    await tester.tap(find.text('Es algo nuevo'));
    await _esperar(tester);
    expect(find.text('Varios reportes seguidos'), findsNothing);
    expect(find.byType(FlujoReporte), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('foto: tocarla la abre en grande; «Quitar» ofrece «Deshacer» y la devuelve', (tester) async {
    final e = EstadoZanky()..manglar = _manglar;
    final b = Borrador(e, tipo: TipoAmenaza.tala)..marcarEnMapa(const LatLng(11.05316, -74.85094));
    addTearDown(b.dispose);
    b.ponerFoto(base64Decode(jpegConGps), deCamara: true);
    await _montar(tester, e, Scaffold(body: PasoEvidencia(borrador: b)),
        const Size(390, 844));
    await tester.tap(find.bySemanticsLabel('Ver la foto en grande'));
    await _esperar(tester);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Cerrar la foto').last);
    await _esperar(tester);
    expect(find.byType(InteractiveViewer), findsNothing);
    await tester.tap(find.text('Quitar'));
    await _esperar(tester);
    expect(b.foto, isNull);
    await tester.tap(find.text('Deshacer'));
    await _esperar(tester);
    expect(b.foto, isNotNull);
    expect(b.fotoDeCamara, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
