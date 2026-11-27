// Pantallas de la experiencia QR: cada una en dos tamaños de teléfono y tres de letra, sin excepciones
// (incluye «A RenderFlex overflowed») y con los toques de al menos 44 px. Más los recorridos principales.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ayudas/fuente_lato.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/experiencia/entrada_evento.dart';
import 'package:zanky/datos/experiencia/jornada.dart';
import 'package:zanky/datos/experiencia/participacion.dart';
import 'package:zanky/datos/experiencia/trivia.dart';
import 'package:zanky/datos/guardian.dart';
import 'package:zanky/nucleo/presionable.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/experiencia/asistencia.dart';
import 'package:zanky/vistas/experiencia/charla_zanky.dart';
import 'package:zanky/vistas/experiencia/pantalla_evento.dart';
import 'package:zanky/vistas/experiencia/puerta_evento.dart';
import 'package:zanky/vistas/experiencia/reto_zanky.dart';
import 'package:zanky/vistas/experiencia/widgets_evento.dart' as w;

const _tamanos = <(String, Size)>[('360x800', Size(360, 800)), ('390x844', Size(390, 844))];
const _letras = [1.0, 1.3, 2.0];

/// Una jornada cancelada, con foto y con aviso del servidor.
class _FuenteCancelada extends FuenteJornadas {
  _FuenteCancelada();
  @override
  Future<EventoZanky> eventoLocal(String codigo) => evento(codigo);

  @override
  Future<EventoZanky> evento(String codigo) async {
    final m = (jsonDecode(File('test/fixtures/api_jornada_siembra.json').readAsStringSync()) as Map)
      ..['estado'] = 'cancelada';
    final j = Jornada.fromJson(m);
    return EventoZanky(codigo: codigo, titulo: j.titulo, jornada: j, aviso: 'Cambio de fecha: pregunta a la organización.');
  }
}

/// Lee las jornadas del respaldo sin red ni canales de plataforma.
class _FuenteFija extends FuenteJornadas {
  _FuenteFija();
  @override
  Future<List<Jornada>> cargar() async {
    final j = jsonDecode(File('test/fixtures/jornadas_ejemplo.json').readAsStringSync()) as Map<String, dynamic>;
    return [for (final f in j['jornadas'] as List) Jornada.fromJson(f as Map)];
  }

  @override
  Future<EventoZanky> evento(String codigo) async {
    for (final j in await cargar()) {
      if (j.id == codigo) return EventoZanky(codigo: codigo, titulo: j.titulo, jornada: j);
    }
    return EventoZanky.generico(codigo);
  }
}

EstadoZanky _estado({bool conPerfil = true}) {
  final e = EstadoZanky();
  e.listo = true;
  if (conPerfil) {
    e.perfil = Perfil(
      id: '123e4567-e89b-12d3-a456-426614174000',
      nombre: 'María Fernanda de los Ángeles Pérez',
      colegio: 'Institución Educativa Distrital Ciénaga de Mallorquín',
      consentimiento: DateTime.now(),
      creado: DateTime.now(),
    );
  }
  return e;
}

Future<void> _montar(
  WidgetTester tester,
  Widget hijo, {
  Size tam = const Size(360, 800),
  double letra = 1.0,
  EstadoZanky? estado,
  bool sinAnimar = false,
}) async {
  tester.view.physicalSize = tam;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(Zanky(
    estado: estado ?? _estado(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaZanky(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(letra), disableAnimations: sinAnimar),
        child: child!,
      ),
      home: hijo,
    ),
  ));
  await _avanzar(tester);
}

/// Sin pumpAndSettle: Zanky respira para siempre.
Future<void> _avanzar(WidgetTester tester, {int veces = 6}) async {
  for (var i = 0; i < veces; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _cerrar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
}

void _probar(String nombre, Widget Function() fabrica, {Future<void> Function(WidgetTester)? despues}) {
  for (final (tn, tam) in _tamanos) {
    for (final letra in _letras) {
      testWidgets('$nombre · $tn · letra x$letra', (tester) async {
        final errores = <String>[];
        final previo = FlutterError.onError;
        FlutterError.onError = (d) {
          final donde = RegExp(r'lib/[\w/]+\.dart:\d+').allMatches(d.toString()).map((m) => m.group(0)).toSet().join(', ');
          errores.add('${d.exceptionAsString().trim().split('\n').first} [$donde]');
        };
        try {
          await _montar(tester, fabrica(), tam: tam, letra: letra);
          if (despues != null) {
            await despues(tester);
            await _avanzar(tester);
          }
          if (letra == 1.0) {
            for (final el in tester.elementList(find.byType(Presionable, skipOffstage: false))) {
              final ro = el.renderObject;
              if (ro is! RenderBox || !ro.hasSize) continue; // fuera de la pantalla y sin construir
              final p = el.widget as Presionable;
              if (ro.size.width < 44 || ro.size.height < 44) {
                errores.add('Toque menor de 44 px: ${ro.size.width.toStringAsFixed(0)}x${ro.size.height.toStringAsFixed(0)} (${p.etiqueta})');
              }
            }
          }
          await _cerrar(tester);
        } finally {
          FlutterError.onError = previo;
        }
        expect(errores.toSet().toList(), isEmpty, reason: '$nombre a $tn con letra x$letra');
      });
    }
  }
}

EventoZanky _evento() => EventoZanky.generico('feria-colegio');

void main() {
  setUpAll(() async {
    await cargarLato();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    entradaEvento.value = null;
    PuertaEvento.olvidarAbiertos();
  });

  group('Pantalla del evento', () {
    _probar('Evento con jornada', () => PantallaEvento(codigo: 'jornada-1', fuente: _FuenteFija(), almacen: AlmacenParticipacion()));
    _probar('Evento con jornada llena', () => PantallaEvento(codigo: 'jornada-3', fuente: _FuenteFija(), almacen: AlmacenParticipacion()));
    _probar('Evento genérico', () => PantallaEvento(codigo: 'desconocido', fuente: _FuenteFija(), almacen: AlmacenParticipacion()));
  });

  testWidgets('la tarjeta muestra fecha en español, punto de encuentro, cupos, qué llevar y «Datos de ejemplo»', (t) async {
    await _montar(t, PantallaEvento(codigo: 'jornada-1', fuente: _FuenteFija(), almacen: AlmacenParticipacion()));
    expect(find.textContaining('domingo 29 de noviembre'), findsOneWidget);
    expect(find.textContaining('Ecoparque Ciénaga de Mallorquín'), findsOneWidget);
    expect(find.text('17 cupos libres de 40'), findsOneWidget);
    expect(find.text('Guantes de trabajo'), findsOneWidget);
    expect(find.text('Datos de ejemplo'), findsOneWidget);
    expect(find.textContaining('Bienvenido a «Jornada de siembra en el caño»'), findsOneWidget);
    await _cerrar(t);
  });

  testWidgets('jornada cancelada con foto: aviso, rótulo, foto con error elegante y sin registrar asistencia', (t) async {
    await _montar(t, PantallaEvento(codigo: 'x', fuente: _FuenteCancelada(), almacen: AlmacenParticipacion()));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.textContaining('Cambio de fecha'), findsOneWidget);
    expect(find.byType(FotoJornada), findsOneWidget);
    expect(find.text('Sin foto por ahora'), findsOneWidget); // en pruebas la red falla: error elegante, sin excepción
    await _cerrar(t);
  });

  testWidgets('evento genérico: «Evento con Zanky» y sin rótulo de ejemplo', (t) async {
    await _montar(t, PantallaEvento(codigo: 'otro', fuente: _FuenteFija(), almacen: AlmacenParticipacion()));
    expect(find.text('Evento con Zanky'), findsOneWidget);
    expect(find.text('Datos de ejemplo'), findsNothing);
    await _cerrar(t);
  });

  testWidgets('con movimiento reducido todo aparece sin animar', (t) async {
    await _montar(t, PantallaEvento(codigo: 'jornada-1', fuente: _FuenteFija(), almacen: AlmacenParticipacion()),
        sinAnimar: true);
    await t.scrollUntilVisible(find.text('Hablar con Zanky'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Hablar con Zanky'), findsOneWidget);
    await _cerrar(t);
  });

  group('Asistencia', () {
    testWidgets('exige nombre y consentimiento, y luego celebra con los 40 puntos', (t) async {
      final almacen = AlmacenParticipacion();
      await _montar(t, PantallaEvento(codigo: 'jornada-1', fuente: _FuenteFija(), almacen: almacen),
          estado: _estado(conPerfil: false));
      await t.scrollUntilVisible(find.text('Registrar mi asistencia (+40)'), 200, scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('Registrar mi asistencia (+40)'));
      await _avanzar(t);
      // Sin llenar nada: no registra y marca lo que falta.
      await t.tap(find.text('Registrar asistencia (+40)'));
      await _avanzar(t);
      expect(almacen.puntos, 0);
      expect(find.text('Escribe tu nombre'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'Ana Gómez');
      await t.tap(find.textContaining('Autorizo guardar'));
      await _avanzar(t);
      await t.tap(find.text('Registrar asistencia (+40)'));
      await _avanzar(t, veces: 8);
      expect(almacen.asistio('jornada-1'), isTrue);
      expect(find.text('¡Asistencia registrada!'), findsOneWidget);
      await t.tap(find.text('Listo'));
      await _avanzar(t, veces: 8);
      expect(find.text('Asistencia registrada'), findsOneWidget);
      expect(find.text('Tus puntos de eventos: 40'), findsOneWidget);
      await _cerrar(t);
    });

    testWidgets('la hoja en sí no se desborda a 360 con letra x2', (t) async {
      final errores = <String>[];
      final previo = FlutterError.onError;
      FlutterError.onError = (d) => errores.add(d.exceptionAsString());
      await _montar(
        t,
        Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => abrirAsistencia(c, _evento(), almacen: AlmacenParticipacion()), child: const Text('abrir'))))),
        letra: 2.0,
      );
      await t.tap(find.text('abrir'));
      await _avanzar(t, veces: 8);
      FlutterError.onError = previo;
      expect(errores, isEmpty);
      await _cerrar(t);
    });
  });

  group('Charla con Zanky', () {
    _probar('Charla', () => CharlaZanky(evento: _evento()));

    testWidgets('chip → escribiendo… → respuesta con fuente; lo desconocido se dice honesto', (t) async {
      await _montar(t, CharlaZanky(evento: _evento()));
      expect(find.textContaining('IA lista, sin conectar'), findsOneWidget);
      await t.tap(find.text('¿Qué es el carbono azul?'));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('escribiendo…'), findsOneWidget);
      await _avanzar(t);
      expect(find.textContaining('ecosistemas costeros'), findsOneWidget);
      expect(find.textContaining('Fuente: INVEMAR'), findsOneWidget);
      expect(find.text('escribiendo…'), findsNothing);
      await t.enterText(find.byType(TextField), 'cuanto cuesta un iphone');
      await t.testTextInput.receiveAction(TextInputAction.send);
      await _avanzar(t);
      expect(find.textContaining('prefiero no inventarte nada'), findsOneWidget);
      await _cerrar(t);
    });
  });

  group('Reto', () {
    _probar('Reto', () => RetoZanky(evento: _evento(), almacen: AlmacenParticipacion()));

    testWidgets('5 preguntas: aciertos suman, error sacude y marca, y repetir sin mejorar no suma', (t) async {
      final almacen = AlmacenParticipacion();
      await _montar(t, RetoZanky(evento: _evento(), almacen: almacen));
      final preguntas = retoPara('feria-colegio');
      for (var i = 0; i < preguntas.length; i++) {
        expect(find.text('Pregunta ${i + 1} de 5'), findsOneWidget);
        final p = preguntas[i];
        // Las dos primeras bien; la tercera mal; las demás bien.
        final elegir = i == 2 ? p.opciones[(p.correcta + 1) % p.opciones.length] : p.respuestaCorrecta;
        await t.tap(find.text(elegir));
        await t.pump(const Duration(milliseconds: 100));
        await _avanzar(t);
        expect(find.textContaining('Fuente: '), findsOneWidget);
        expect(find.text(i == 2 ? 'Casi. La respuesta era «${p.respuestaCorrecta}».' : '¡Muy bien!'), findsOneWidget);
        await t.tap(find.text(i == preguntas.length - 1 ? 'Ver mi resultado' : 'Siguiente'));
        await _avanzar(t);
      }
      expect(find.text('4 de 5'), findsOneWidget);
      expect(find.text('+40 puntos'), findsOneWidget);
      expect(almacen.mejorReto('feria-colegio'), 4);
      // Repetir con el mismo resultado no suma nada.
      await t.tap(find.text('Repetir el reto'));
      await _avanzar(t);
      for (var i = 0; i < 5; i++) {
        final p = retoPara('feria-colegio')[i];
        await t.tap(find.text(i == 0 ? p.opciones[(p.correcta + 1) % p.opciones.length] : p.respuestaCorrecta));
        await _avanzar(t);
        await t.tap(find.text(i == 4 ? 'Ver mi resultado' : 'Siguiente'));
        await _avanzar(t);
      }
      expect(find.text('4 de 5'), findsOneWidget);
      expect(find.textContaining('Sin puntos nuevos'), findsOneWidget);
      expect(almacen.puntos, 40);
      await _cerrar(t);
    });
  });

  group('Atajos', () {
    testWidgets('sin perfil explican que hace falta y vuelven a la bienvenida', (t) async {
      await _montar(t, PantallaEvento(codigo: 'x', fuente: _FuenteFija(), almacen: AlmacenParticipacion()),
          estado: _estado(conPerfil: false));
      await t.scrollUntilVisible(find.text('Mi tarjeta'), 200, scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('Mi tarjeta'));
      await _avanzar(t, veces: 8);
      expect(find.text('Primero crea tu perfil'), findsOneWidget);
      await t.tap(find.text('Ahora no'));
      await _avanzar(t, veces: 8);
      expect(find.text('Primero crea tu perfil'), findsNothing);
      await _cerrar(t);
    });
  });

  group('Puerta', () {
    testWidgets('abre el evento una sola vez cuando la app está lista', (t) async {
      entradaEvento.value = const EntradaEvento('jornada-1');
      final estado = _estado()..listo = false;
      await _montar(t, const PuertaEvento(child: Scaffold(body: Text('inicio'))), estado: estado);
      expect(find.byType(PantallaEvento), findsNothing); // todavía cargando
      estado.listo = true;
      estado.notifyListeners();
      await _avanzar(t, veces: 8);
      expect(find.byType(PantallaEvento), findsOneWidget);
      // Se cierra y no se vuelve a abrir.
      Navigator.of(t.element(find.byType(PantallaEvento))).pop();
      await _avanzar(t, veces: 8);
      estado.notifyListeners();
      await _avanzar(t);
      expect(find.byType(PantallaEvento), findsNothing);
      await _cerrar(t);
    });

    testWidgets('sin evento no abre nada', (t) async {
      await _montar(t, const PuertaEvento(child: Scaffold(body: Text('inicio'))));
      expect(find.text('inicio'), findsOneWidget);
      expect(find.byType(PantallaEvento), findsNothing);
      await _cerrar(t);
    });
  });

  group('Piezas para Inicio y Guardián', () {
    _probar('EntradaEvento', () => const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: w.EntradaEvento())));
    _probar('ResumenParticipacion vacío', () => Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: w.ResumenParticipacion(almacen: AlmacenParticipacion()))));

    testWidgets('EntradaEvento acepta un código y abre el evento; rechaza uno malo', (t) async {
      await _montar(t, const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: w.EntradaEvento())));
      await t.tap(find.text('¿Estás en una jornada?'));
      await _avanzar(t, veces: 8);
      await t.enterText(find.byType(TextField), 'no vale!');
      await t.tap(find.text('Entrar'));
      await _avanzar(t);
      expect(find.textContaining('Solo letras'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'https://mimanglar.sentralabs.co/app/?evento=jornada-1');
      await t.tap(find.text('Entrar'));
      await _avanzar(t, veces: 10);
      expect(find.byType(PantallaEvento), findsOneWidget);
      await _cerrar(t);
    });

    testWidgets('ResumenParticipacion muestra puntos y eventos', (t) async {
      final a = AlmacenParticipacion();
      await a.registrarAsistencia(evento: const EventoZanky(codigo: 'e1', titulo: 'Siembra en el caño'), nombre: 'Ana');
      await a.guardarReto('e1', 3);
      await _montar(t, Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: w.ResumenParticipacion(almacen: a))));
      expect(find.text('70 puntos · 1 evento'), findsOneWidget);
      expect(find.text('Siembra en el caño'), findsOneWidget);
      await _cerrar(t);
    });
  });
}
