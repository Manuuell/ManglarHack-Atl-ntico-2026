// Control de calidad de pantallas: cada pantalla real, en tres tamaños y con dos
// tamaños de letra, sin red ni plugins. Falla ante cualquier excepción (incluido
// «A RenderFlex overflowed»).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ayudas/fuente_lato.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/clima.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/guardian.dart';
import 'package:zanky/datos/reporte.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/datos/tipos.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/nucleo/presionable.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/bienvenida/bienvenida.dart';
import 'package:zanky/vistas/guardian/editar_perfil.dart';
import 'package:zanky/vistas/mapa/pantalla_mapa.dart';
import 'package:zanky/vistas/mis_reportes/detalle_reporte.dart';
import 'package:zanky/vistas/raiz.dart';
import 'package:zanky/vistas/reporte/borrador.dart';
import 'package:zanky/vistas/reporte/enviado.dart';
import 'package:zanky/vistas/reporte/flujo_reporte.dart';
import 'package:zanky/vistas/reporte/paso_detalles.dart';
import 'package:zanky/vistas/reporte/paso_evidencia.dart';
import 'package:zanky/vistas/reporte/paso_tipo.dart';
import 'package:zanky/vistas/reporte/paso_ubicacion.dart';

/// PNG de 1x1 para la «foto» de prueba.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

const _tamanos = <(String, Size)>[
  ('360x640', Size(360, 640)),
  ('390x844', Size(390, 844)),
  ('768x1024', Size(768, 1024)),
];
// Con 2.0 todo pasa salvo PildoraPrioridad (vistas/comun/comunes.dart:59, ver informe):
// súbelo a [1.0, 1.3, 2.0] cuando esa pieza común se arregle.
const _letras = [1.0, 1.3, 2.0];

late Manglar _manglar;

Reporte _reporte(
  String id,
  TipoAmenaza tipo, {
  EstadoReporte estado = EstadoReporte.recibido,
  Envio envio = Envio.enviado,
  int prioridad = 3,
  String descripcion = '',
  String zona = 'Ciénaga de Mallorquín',
  bool anonimo = false,
  int horas = 5,
  int confianza = 60,
  bool dentro = true,
}) {
  final cuando = DateTime.now().subtract(Duration(hours: horas));
  return Reporte(
    id: id,
    tipo: tipo,
    descripcion: descripcion,
    punto: const LatLng(11.05316, -74.85094),
    precisionM: 8,
    metodo: MetodoUbicacion.gps,
    capturadoEn: cuando,
    momento: Momento.ahora,
    magnitud: Magnitud.mediana,
    zonaId: 'mallorquin',
    zonaNombre: zona,
    municipio: 'Barranquilla',
    dentroPoligono: dentro,
    distanciaM: dentro ? 0 : 420,
    prioridad: prioridad,
    motivosPrioridad: const [
      'Dentro del manglar protegido',
      'Está pasando ahora y es una amenaza de gravedad alta para la ciénaga',
    ],
    confianza: confianza,
    anonimo: anonimo,
    reportanteId: 'p-1',
    estado: estado,
    envio: envio,
    historial: [
      CambioEstado(EstadoReporte.recibido, cuando, 'Creado en el teléfono'),
      if (estado != EstadoReporte.recibido)
        CambioEstado(estado, cuando.add(const Duration(hours: 2)), 'La CRA lo revisó'),
    ],
    ultimoError: envio == Envio.error ? 'Sin conexión con el servidor' : null,
    capturadoSinSenal: envio == Envio.enCola,
  );
}

EstadoZanky _estado({bool conReportes = true, bool conPerfil = true}) {
  final e = EstadoZanky();
  e.manglar = _manglar;
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
  if (conReportes) {
    e.reportes.addAll([
      _reporte('aaaa0001-0000-0000-0000-000000000001', TipoAmenaza.tala,
          prioridad: 5,
          envio: Envio.enCola,
          horas: 1,
          descripcion: 'Están cortando mangle rojo con motosierra, hay troncos apilados cerca del caño y varias '
              'personas trabajando desde la madrugada, me parece que es muy grave.'),
      _reporte('bbbb0002-0000-0000-0000-000000000002', TipoAmenaza.quema,
          prioridad: 4, envio: Envio.error, horas: 3, anonimo: true),
      _reporte('cccc0003-0000-0000-0000-000000000003', TipoAmenaza.vertimiento,
          prioridad: 2, estado: EstadoReporte.verificado, horas: 30, confianza: 85),
      _reporte('dddd0004-0000-0000-0000-000000000004', TipoAmenaza.relleno,
          prioridad: 3, estado: EstadoReporte.descartado, horas: 80, dentro: false, confianza: 20),
      _reporte('eeee0005-0000-0000-0000-000000000005', TipoAmenaza.fauna,
          prioridad: 1,
          estado: EstadoReporte.cerrado,
          horas: 400,
          zona: 'Humedal costero de Puerto Colombia y Salgar, zona de influencia'),
      _reporte('ffff0006-0000-0000-0000-000000000006', TipoAmenaza.basuras, prioridad: 3, horas: 9000),
    ]);
    e.publicos = [
      ReportePublico(
        id: 'pub1',
        tipo: TipoAmenaza.tala,
        punto: const LatLng(11.0545, -74.849),
        prioridad: 4,
        estado: EstadoReporte.recibido,
        capturadoEn: DateTime.now().subtract(const Duration(hours: 2)),
        zona: 'mallorquin',
      ),
    ];
    e.clima = Clima(
      temperatura: 31.4,
      vientoKmh: 28,
      vientoDireccion: 70,
      lluviaMm: 0,
      olaM: 0.8,
      leido: DateTime.now(),
    );
  }
  return e;
}

/// Monta [hijo] dentro del árbol real de la app (Zanky + MaterialApp con el tema).
Future<void> _montar(
  WidgetTester tester,
  EstadoZanky estado,
  Widget hijo,
  Size tam,
  double letra,
) async {
  tester.view.physicalSize = tam;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(Zanky(
    estado: estado,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaZanky(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(letra)),
        child: child!,
      ),
      home: hijo,
    ),
  ));
  await _avanzar(tester);
}

/// Sin pumpAndSettle: Zanky respira y los marcadores laten para siempre.
Future<void> _avanzar(WidgetTester tester, {int veces = 6}) async {
  for (var i = 0; i < veces; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Desmonta y deja correr los temporizadores pendientes.
Future<void> _cerrar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
}

Borrador _borrador(EstadoZanky e, {bool completo = true}) {
  final b = Borrador(e, tipo: completo ? TipoAmenaza.quema : null);
  if (completo) {
    b.marcarEnMapa(const LatLng(11.05316, -74.85094));
    b.ponerFoto(_png, deCamara: true);
    b.descripcion = 'Humo negro y fuego en el borde del mangle, mucha gente mirando desde la orilla.';
  }
  return b;
}

typedef _Fabrica = Widget Function(EstadoZanky e);

void _probar(
  String nombre,
  _Fabrica fabrica, {
  EstadoZanky Function()? estado,
  Future<void> Function(WidgetTester)? despues,
}) {
  for (final (tn, tam) in _tamanos) {
    for (final letra in _letras) {
      testWidgets('$nombre · $tn · letra x$letra', (tester) async {
        // Se recogen TODAS las excepciones (no solo la primera) con dónde ocurrieron.
        final errores = <String>[];
        final previo = FlutterError.onError;
        FlutterError.onError = (d) {
          final texto = d.toString();
          final donde = RegExp(r'lib/[\w/]+\.dart:\d+').allMatches(texto).map((m) => m.group(0)).toSet().join(', ');
          final primera = d.exceptionAsString().trim().split(String.fromCharCode(10)).first;
          errores.add('$primera [$donde]');
        };
        try {
          final e = (estado ?? _estado)();
          await _montar(tester, e, fabrica(e), tam, letra);
          if (despues != null) {
            await despues(tester);
            await _avanzar(tester);
          }
          if (letra == 1.0) {
            for (final w in tester.widgetList<Presionable>(find.byType(Presionable))) {
              final tam = tester.getSize(find.byWidget(w).first);
              if (tam.width < 44 || tam.height < 44) {
                errores.add('Toque menor de 44 px: ${tam.width.toStringAsFixed(0)}x${tam.height.toStringAsFixed(0)} '
                    '(${w.etiqueta ?? w.child.runtimeType})');
              }
            }
          }
          await _cerrar(tester);
        } finally {
          FlutterError.onError = previo;
        }
        expect(errores.toSet().toList(), isEmpty, reason: 'Excepciones en $nombre a $tn con letra x$letra');
      });
    }
  }
}

/// Un paso suelto del flujo, con la misma estructura que le da el flujo (columna con tope).
Widget _paso(Widget Function(Borrador b) construir, EstadoZanky e, {bool completo = true}) {
  final b = _borrador(e, completo: completo);
  return Scaffold(
    backgroundColor: Zc.arena,
    body: Column(children: [
      const SizedBox(height: 24),
      Expanded(child: construir(b)),
    ]),
  );
}

void main() {
  setUpAll(() async {
    // Sin esto el test mide con la fuente cuadrada de prueba (Ahem) y da desbordes falsos.
    await cargarLato();
    final j = jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync());
    _manglar = Manglar.desdeJson(j as Map<String, dynamic>);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Bienvenida', () {
    _probar('Bienvenida', (_) => const Bienvenida(), estado: () => _estado(conReportes: false, conPerfil: false));
  });

  group('Raíz y pestañas', () {
    for (final (i, nombre) in ['Inicio', 'Mapa', 'Mis reportes', 'Guardián'].indexed) {
      _probar('Raiz pestaña $nombre', (_) => const Raiz(), despues: (t) async {
        if (i > 0) {
          await t.tap(find.text(nombre).last);
          await _avanzar(t, veces: 8);
        }
      });
    }
    _probar('Raiz sin reportes (vacío)', (_) => const Raiz(), estado: () => _estado(conReportes: false),
        despues: (t) async {
      await t.tap(find.text('Mis reportes').last);
      await _avanzar(t, veces: 8);
    });
  });

  group('Mapa suelto', () {
    _probar('PantallaMapa', (_) => const Scaffold(body: PantallaMapa()));
  });

  group('Flujo de reporte', () {
    _probar('FlujoReporte paso 1 Qué viste', (e) => FlujoReporte(estado: e));
    _probar('FlujoReporte paso 2 Dónde (tipo elegido)', (e) => FlujoReporte(estado: e, tipo: TipoAmenaza.tala));
    _probar('PasoTipo', (e) => _paso((b) => PasoTipo(borrador: b, onElegido: () {}), e, completo: false));
    _probar('PasoUbicacion sin punto', (e) => _paso((b) => PasoUbicacion(borrador: b), e, completo: false));
    _probar('PasoUbicacion con punto', (e) => _paso((b) => PasoUbicacion(borrador: b), e));
    _probar('PasoEvidencia sin foto', (e) => _paso((b) => PasoEvidencia(borrador: b), e, completo: false));
    _probar('PasoEvidencia con foto', (e) => _paso((b) => PasoEvidencia(borrador: b), e));
    _probar('PasoDetalles', (e) => _paso((b) => PasoDetalles(borrador: b), e));
    _probar('PasoDetalles gravedad alta', (e) {
      final b = Borrador(e, tipo: TipoAmenaza.tala)
        ..marcarEnMapa(const LatLng(11.05316, -74.85094))
        ..magnitud = Magnitud.grande;
      return Scaffold(backgroundColor: Zc.arena, body: PasoDetalles(borrador: b));
    });
    _probar('FlujoReporte diálogo descartar', (e) => FlujoReporte(estado: e, tipo: TipoAmenaza.tala), despues: (t) async {
      await t.tap(find.bySemanticsLabel('Cerrar el reporte'));
      await _avanzar(t, veces: 8);
      expect(find.text('¿Descartar este reporte?'), findsOneWidget);
    });
    _probar('ReporteEnviado', (e) => ReporteEnviado(reporteId: e.reportes.first.id));
    _probar('ReporteEnviado ya enviado', (e) => ReporteEnviado(reporteId: e.reportes[2].id));
  });

  group('Detalle de un reporte', () {
    for (var i = 0; i < 6; i++) {
      _probar('Detalle reporte #$i', (e) => PantallaDetalleReporte(reporte: e.reportes[i]));
    }
  });

  group('Editar perfil', () {
    _probar(
      'Hoja editar perfil',
      (_) => Builder(
        builder: (c) => Scaffold(
          body: Center(child: TextButton(onPressed: () => mostrarEditarPerfil(c), child: const Text('abrir'))),
        ),
      ),
      despues: (t) async {
        await t.tap(find.text('abrir'));
        await _avanzar(t, veces: 8);
        expect(find.byType(TextField), findsWidgets);
      },
    );
  });
}
