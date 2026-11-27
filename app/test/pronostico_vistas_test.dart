import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zanky/datos/pronostico/reglas.dart';
import 'package:zanky/datos/pronostico/servicio_pronostico.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/nucleo/tema.dart';
import 'package:zanky/vistas/pronostico/tarjeta_pronostico.dart';

class ServicioFalso extends ServicioPronostico {
  ServicioFalso(this.valor);
  final PronosticoZona? valor;

  @override
  Future<PronosticoZona?> cargar(ZonaManglar zona) async => valor == null
      ? null
      : PronosticoZona(
          zona.id,
          valor!.leido,
          valor!.dias,
          deCache: valor!.deCache,
        );

  @override
  Future<PronosticoZona?> ultimo(String zonaId) async => valor?.deCache == true
      ? PronosticoZona(zonaId, valor!.leido, valor!.dias, deCache: true)
      : null;

  @override
  void cerrar() {}
}

void main() {
  final zonas = [
    for (final (id, nombre) in [
      ('mallorquin', 'Ciénaga de Mallorquín'),
      ('piojo', 'Ciénaga del Totumo, Piojó'),
      ('juan_de_acosta', 'Costa de Juan de Acosta'),
      ('tubara', 'Costa de Tubará'),
    ])
      ZonaManglar(
        id: id,
        nombre: nombre,
        municipio: nombre,
        prioridadConservacion: 3,
        nota: '',
        areaHa: 1,
        poligonos: [
          const [
            LatLng(11.05, -74.85),
            LatLng(11.06, -74.85),
            LatLng(11.05, -74.84),
          ],
        ],
      ),
  ];
  final hoy = DateTime.now();
  final hoyColombia = hoy.toUtc().subtract(const Duration(hours: 5));
  final p =
      PronosticoZona('mallorquin', hoy.subtract(const Duration(hours: 3)), [
        for (var i = 0; i < 3; i++)
          LecturaDia(
            fecha: DateTime.utc(
              hoyColombia.year,
              hoyColombia.month,
              hoyColombia.day + i,
            ),
            lluvia24: 24,
            lluvia72: 48,
            temperaturaMax: 32,
            humedadMin: 60,
            vientoMax: 20,
            olaMax: 1.6,
            diasSecos: 2,
          ),
      ], deCache: true);

  for (final (ancho, alto) in [(360.0, 800.0), (390.0, 844.0)]) {
    for (final escala in [1.0, 1.3]) {
      testWidgets('tarjeta y detalle $ancho x $alto letra $escala', (
        tester,
      ) async {
        tester.view.physicalSize = Size(ancho, alto);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: temaZanky(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(ancho, alto),
                textScaler: TextScaler.linear(escala),
                disableAnimations: true,
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: TarjetaPronostico(
                    zonas: zonas,
                    reportes: const [],
                    servicio: ServicioFalso(p),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Pronóstico del manglar'), findsOneWidget);
        expect(find.textContaining('Copia guardada'), findsNWidgets(4));
        expect(find.textContaining('de hace 3 h'), findsNWidgets(4));
        await tester.tap(find.text('Ciénaga de Mallorquín').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Por qué:'), findsWidgets);
        expect(find.textContaining('Qué hacer:'), findsWidgets);
        expect(find.textContaining('Fuente:'), findsWidgets);
      });
    }
  }

  testWidgets('sin red ni copia da explicación y permite reintentar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TarjetaPronostico(
            zonas: zonas,
            reportes: const [],
            servicio: ServicioFalso(null),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('no hay copia guardada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
