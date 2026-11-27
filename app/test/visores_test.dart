import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/cra/modelos_cra.dart';
import 'package:zanky/datos/cra/servicio_visores.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/nucleo/kit/menu_mantenido.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/visores/pantalla_visores.dart';
import 'package:zanky/vistas/visores/visores_compacto.dart';

/// Pruebas de los visores con las respuestas REALES de la API de la CRA guardadas el 27-nov
/// (`test/fixtures/cra/`). Ninguna prueba sale a la red.

String fx(String n) => File('test/fixtures/cra/$n').readAsStringSync();
Object? fj(String n) => jsonDecode(fx(n));

/// El 30-jun-2026 hubo un foco en la franja: sirve para ver el aviso de 7 días.
final ahora = DateTime.utc(2026, 7, 2, 15);

int pedidos = 0;

http.Client clienteFijo({bool caido = false}) => MockClient((req) async {
      pedidos++;
      if (caido) throw http.ClientException('sin señal');
      final u = req.url.toString();
      String? cuerpo;
      if (u.contains('event_types')) cuerpo = fx('tipos_evento.json');
      if (u.contains('event_zones')) cuerpo = fx('zonas_evento.json');
      if (u.contains('critical_points/items')) cuerpo = fx('puntos_criticos.geojson');
      if (u.contains('wildfire-clusters')) cuerpo = fx('focos_calor.geojson');
      if (u.contains('sampling_points')) cuerpo = fx('puntos_agua.geojson');
      if (u.contains('measurements')) cuerpo = fx('mediciones_agua.json');
      if (u.contains('core.json')) cuerpo = fx('core_reducido.json');
      if (u.contains('rpc/estadisticas')) cuerpo = fx('estadisticas.json');
      if (cuerpo == null) return http.Response('no', 404);
      return http.Response.bytes(utf8.encode(cuerpo), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

ServicioVisores servicio({bool caido = false, bool conServidor = true}) => ServicioVisores(
      cliente: clienteFijo(caido: caido),
      servidor: conServidor ? Servidor(base: 'https://ejemplo.supabase.co', anon: 'anon') : Servidor(base: '', anon: ''),
      reloj: () => ahora,
    );

Future<void> montar(WidgetTester t, Widget w, Size tam, {double letra = 1}) async {
  t.view.physicalSize = tam;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: temaZanky(),
    home: MediaQuery(data: MediaQueryData(size: tam, textScaler: TextScaler.linear(letra)), child: w),
  ));
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

Future<void> irA(WidgetTester t, String pestana) async {
  await t.tap(find.text(pestana).first);
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    relojVisores = () => ahora;
    distanciaAlManglar = (_, lat, lon) => enFranjaManglar(lat, lon) ? 0 : double.infinity;
    pedidos = 0;
  });

  group('Datos de la CRA (respuestas reales)', () {
    test('puntos críticos: todo el Atlántico o solo la franja, con el color oficial', () {
      final tipos = interpretarTipos(fj('tipos_evento.json'));
      final zonas = interpretarZonas(fj('zonas_evento.json'));
      final todos = interpretarPuntosCriticos(fj('puntos_criticos.geojson'), tipos, zonas, soloFranja: false);
      final franja = interpretarPuntosCriticos(fj('puntos_criticos.geojson'), tipos, zonas);
      expect(todos, hasLength(210));
      expect(franja, hasLength(103)); // oráculo: recorte de LIMITES_MANGLAR en Python sobre el mismo GeoJSON
      expect(todos.where((p) => p.enFranja), hasLength(103));
      expect(tipos.firstWhere((t) => t.id == 5).colorHex, '#b600c7'); // la API lo manda con alfa
      expect(tipos.firstWhere((t) => t.id == 4).color, const Color(0xFFF0027F));
      expect(franja.where((p) => p.tipo.id == 1), hasLength(44));
    });

    test('focos: solo los de la franja y el aviso cuenta 7 días y 2 km', () {
      final focos = interpretarFocos(fj('focos_calor.geojson'));
      expect(focos, isNotEmpty);
      expect(focos.every((f) => enFranjaManglar(f.lat, f.lon)), isTrue);
      final recientes = focosCercaDelManglar(focos, ahora, (_, _) => 0);
      expect(recientes, isNotEmpty);
      expect(recientes.every((f) => ahora.difference(f.hasta!).inDays <= 7), isTrue);
      expect(focosCercaDelManglar(focos, ahora, (_, _) => 2500), isEmpty, reason: 'a 2,5 km no cuenta');
      expect(focosCercaDelManglar(focos, ahora.add(const Duration(days: 30)), (_, _) => 0), isEmpty);
    });

    test('agua: semáforo ICA del IDEAM y ciénagas con manglar primero', () {
      final m = interpretarAgua(fj('puntos_agua.geojson'), fj('mediciones_agua.json'));
      expect(m, isNotEmpty);
      final c = agruparPorCienaga(m);
      expect(c.first.conManglar, isTrue);
      expect(categoriaIca(0.95)!.etiqueta, 'Buena');
      expect(categoriaIca(0.71)!.etiqueta, 'Aceptable');
      expect(categoriaIca(0.5)!.etiqueta, 'Mala');
      expect(categoriaIca(0.1)!.etiqueta, 'Muy mala');
      expect(indicadoresAgua['od']!.evaluar(3.5), Semaforo.mal);
      expect(indicadoresAgua['coli']!.evaluar(2000), Semaforo.ojo);
    });

    test('cifras: resumen del workflow y estadísticas agregadas', () {
      final w = interpretarCore(fj('core_reducido.json'))!;
      expect(w.sectores, isNotEmpty);
      expect(w.probableHa, greaterThan(0));
      final ida = CifrasWorkflow.desdeJson(jsonDecode(jsonEncode(w.toJson())) as Map);
      expect(ida.probableHa, w.probableHa);
      final e = EstadisticasReportes.desdeJson(fj('estadisticas.json'))!;
      expect((e.total, e.validados, e.pendientes), (14, 8, 5));
      expect(e.porTipo['tala'], 4);
    });
  });

  group('Servicio con copia sin señal', () {
    test('lee en vivo, guarda la copia y sin señal devuelve la copia con su hora', () async {
      final vivo = await servicio().riesgo();
      expect(vivo.origen, OrigenVisor.enVivo);
      expect(vivo.datos!.puntos, hasLength(210));
      final sin = await servicio(caido: true).riesgo();
      expect(sin.origen, OrigenVisor.copia);
      expect(sin.leido, ahora);
      expect(sin.datos!.puntos.where((p) => p.enFranja), hasLength(103));
      expect(sin.datos!.puntos.first.tipo.color, vivo.datos!.puntos.first.tipo.color);
    });

    test('sin señal y sin copia: sin datos (la pantalla muestra el error)', () async {
      final r = await servicio(caido: true).agua();
      expect(r.origen, OrigenVisor.sinDatos);
      expect(r.datos, isNull);
    });

    test('core.json se baja como mucho una vez al día', () async {
      final s = servicio();
      await s.workflow();
      final antes = pedidos;
      final otra = await s.workflow();
      expect(pedidos, antes, reason: 'la copia de hoy basta');
      expect(otra.datos!.sectores, isNotEmpty);
    });

    test('sin servidor de Zanky no inventa estadísticas', () async {
      final r = await servicio(conServidor: false).estadisticas();
      expect(r.origen, OrigenVisor.sinDatos);
    });

    test('copias de focos y agua van y vuelven iguales', () async {
      final s = servicio();
      final f = await s.focos();
      final a = await s.agua();
      final cf = await s.copiaFocos();
      final ca = await s.copiaAgua();
      expect(cf!.datos!.length, f.datos!.length);
      expect(cf.datos!.first.anillo.length, f.datos!.first.anillo.length);
      expect(ca!.datos!.map((m) => m.ica), a.datos!.map((m) => m.ica));
    });
  });

  for (final tam in const [Size(360, 800), Size(390, 844), Size(768, 1024), Size(1280, 800)]) {
    testWidgets('los cuatro visores se ven sin desbordes a ${tam.width.toInt()}x${tam.height.toInt()}', (t) async {
      await montar(t, PantallaVisores(servicio: servicio()), tam);
      expect(t.takeException(), isNull);
      expect(find.text('Visores del manglar'), findsOneWidget);
      expect(find.textContaining('Datos oficiales'), findsWidgets);
      expect(find.byKey(const ValueKey('chip-1')), findsOneWidget);
      await irA(t, 'Focos');
      expect(find.byKey(const ValueKey('aviso-focos')), findsOneWidget);
      expect(find.textContaining('a menos de 2 km del manglar'), findsOneWidget);
      await irA(t, 'Agua');
      expect(find.byKey(const ValueKey('cienaga-15')), findsOneWidget); // Mallorquín
      await irA(t, 'Cifras');
      expect(find.text('reportes recibidos'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('360 px con letra 1,3 no desborda', (t) async {
    await montar(t, PantallaVisores(servicio: servicio()), const Size(360, 800), letra: 1.3);
    expect(t.takeException(), isNull);
    await irA(t, 'Agua');
    expect(t.takeException(), isNull);
  });

  testWidgets('el filtro de franja y los chips cambian la lista; tocar abre la ficha', (t) async {
    await montar(t, PantallaVisores(servicio: servicio()), const Size(390, 844));
    expect(find.text('103 puntos en la costa del manglar'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Solo dentro de la franja del manglar'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('210 puntos en todo el Atlántico'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Solo dentro de la franja del manglar'));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(const ValueKey('chip-4')));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Puntos críticos (7)'), findsOneWidget);
    final fila = find.textContaining('Incendio forestal').last;
    await t.ensureVisible(fila);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(fila);
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey('ficha-riesgo')), findsOneWidget);
    expect(find.text('Franja del manglar'), findsOneWidget);
  });

  testWidgets('deslizar a la izquierda pasa al siguiente visor', (t) async {
    await montar(t, PantallaVisores(servicio: servicio()), const Size(390, 844));
    await t.fling(find.byKey(const ValueKey('chip-1')), const Offset(-300, 0), 1200);
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const ValueKey('aviso-focos')), findsOneWidget);
  });

  testWidgets('sin señal: muestra la copia con su hora; sin copia, el error con reintento', (t) async {
    await servicio().riesgo(); // queda la copia
    await montar(t, PantallaVisores(servicio: servicio(caido: true)), const Size(390, 844));
    expect(find.textContaining('Sin señal: copia de las'), findsOneWidget);
    await irA(t, 'Agua');
    expect(find.text('La CRA no respondió'), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsOneWidget);
    // La mascota del estado vacío parpadea con un temporizador: se desmonta antes de cerrar.
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 10));
  });

  testWidgets('tarjeta de Inicio: usa la copia, avisa los focos y abre los visores', (t) async {
    final s = servicio();
    await s.riesgo();
    await s.focos();
    await montar(t, Scaffold(body: VisoresCompacto(servicio: s)), const Size(390, 844));
    expect(find.textContaining('a menos de 2 km del manglar'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('visores-compacto')));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Visores del manglar'), findsOneWidget);
    expect(find.byKey(const ValueKey('aviso-focos')), findsOneWidget);
  });

  Finder porClave(String prefijo) => find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> && k.value.startsWith(prefijo);
      });

  Future<void> abrirPrimero(WidgetTester t, String prefijo) async {
    final fila = porClave(prefijo).first;
    await t.ensureVisible(fila);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(fila);
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('focos: cada fila tiene menú con vista previa y tocar abre su ficha', (t) async {
    await montar(t, PantallaVisores(servicio: servicio()), const Size(390, 844));
    await irA(t, 'Focos');
    final filas = find.byWidgetPredicate(
        (w) => w is MenuMantenido && w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('foco-'));
    expect(filas, findsWidgets);
    expect(t.widget<MenuMantenido>(filas.first).vistaPrevia, isNotNull);
    await t.ensureVisible(filas.first);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(filas.first);
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey('ficha-foco')), findsOneWidget);
    expect(find.text('Confianza'), findsWidgets);
  });

  testWidgets('ciénagas: mantener tiene vista previa y tocar abre la ficha con sus estaciones', (t) async {
    await montar(t, PantallaVisores(servicio: servicio()), const Size(390, 844));
    await irA(t, 'Agua');
    final tarjeta = porClave('cienaga-').first;
    final menu = find.ancestor(of: tarjeta, matching: find.byType(MenuMantenido));
    expect(menu, findsOneWidget);
    expect(t.widget<MenuMantenido>(menu).vistaPrevia, isNotNull);
    await abrirPrimero(t, 'cienaga-');
    expect(find.byKey(const ValueKey('ficha-cienaga')), findsOneWidget);
    expect(find.text('ESTACIONES DE MUESTREO'), findsOneWidget);
  });

  test('textos para copiar: sin puntos en CRA y con la fuente', () {
    final f = FocoCalor(
      id: 1, municipio: 'Tubará', desde: DateTime(2026, 11, 20), hasta: DateTime(2026, 11, 21), focos: 2,
      satelites: 'VIIRS', confianza: 'high', anillo: const [], lat: 10.9, lon: -74.9,
    );
    final t = textoFoco(f);
    expect(t, contains('Tubará'));
    expect(t, contains('Confianza alta'));
    expect(t, contains('Fuente: visor de focos de calor de la CRA'));
    expect(t, isNot(contains('C.R.A.')));
  });
}
