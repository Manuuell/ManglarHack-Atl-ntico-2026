import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/datos/pronostico/reglas.dart';
import 'package:zanky/datos/reporte.dart';
import 'package:zanky/datos/tipos.dart';

import 'apoyo_datos.dart';

void main() {
  final ahora = DateTime.utc(2026, 11, 27, 17);
  LecturaDia lectura({
    double lluvia = 0,
    double acumulada = 0,
    double temperatura = 28,
    double humedad = 75,
    double viento = 10,
    double? ola = 0.5,
    int secos = 0,
  }) => LecturaDia(
    fecha: ahora,
    lluvia24: lluvia,
    lluvia72: acumulada,
    temperaturaMax: temperatura,
    humedadMin: humedad,
    vientoMax: viento,
    olaMax: ola,
    diasSecos: secos,
  );
  AlertaManglar regla(LecturaDia d, RiesgoManglar tipo) => evaluarPronostico(
    d,
    zonaId: 'mallorquin',
    ahora: ahora,
  ).firstWhere((r) => r.riesgo == tipo);

  test('quema requiere la combinación completa y usa límites inclusivos', () {
    expect(
      regla(
        lectura(temperatura: 31, humedad: 65, viento: 18, secos: 2),
        RiesgoManglar.quema,
      ).nivel,
      NivelPronostico.medio,
    );
    expect(
      regla(
        lectura(temperatura: 34, humedad: 50, viento: 25, secos: 3),
        RiesgoManglar.quema,
      ).nivel,
      NivelPronostico.alto,
    );
    expect(
      regla(
        lectura(temperatura: 34, humedad: 50, viento: 17, secos: 3),
        RiesgoManglar.quema,
      ).nivel,
      NivelPronostico.bajo,
    );
  });

  test('lluvia en 24 o hasta 72 horas eleva anegamiento', () {
    expect(
      regla(lectura(lluvia: 20), RiesgoManglar.anegamiento).nivel,
      NivelPronostico.medio,
    );
    expect(
      regla(lectura(acumulada: 80), RiesgoManglar.anegamiento).nivel,
      NivelPronostico.alto,
    );
    expect(
      regla(
        lectura(lluvia: 19, acumulada: 39),
        RiesgoManglar.anegamiento,
      ).nivel,
      NivelPronostico.bajo,
    );
  });

  test('ola alta y ausencia de dato marino', () {
    expect(
      regla(lectura(ola: 1.5), RiesgoManglar.oleaje).nivel,
      NivelPronostico.medio,
    );
    expect(
      regla(lectura(ola: 2), RiesgoManglar.oleaje).nivel,
      NivelPronostico.alto,
    );
    expect(regla(lectura(ola: null), RiesgoManglar.oleaje).nivel, isNull);
  });

  test('arrastre tras días secos necesita lluvia y sequedad', () {
    expect(
      regla(lectura(lluvia: 15, secos: 2), RiesgoManglar.vertimiento).nivel,
      NivelPronostico.medio,
    );
    expect(
      regla(lectura(lluvia: 30, secos: 3), RiesgoManglar.vertimiento).nivel,
      NivelPronostico.alto,
    );
    expect(
      regla(lectura(lluvia: 30, secos: 1), RiesgoManglar.vertimiento).nivel,
      NivelPronostico.bajo,
    );
  });

  test('nulos no se convierten en nivel bajo', () {
    final d = LecturaDia(fecha: ahora);
    expect(
      evaluarPronostico(
        d,
        zonaId: 'mallorquin',
        ahora: ahora,
      ).every((a) => a.nivel == null),
      isTrue,
    );
  });

  test('reporte reciente correspondiente eleva un nivel; descartado no', () {
    final d = lectura(temperatura: 31, humedad: 65, viento: 18, secos: 2);
    final activo = reporteDePrueba(
      '1',
      tipo: TipoAmenaza.quema,
      capturado: ahora.subtract(const Duration(days: 1)),
    );
    final descartado = reporteDePrueba(
      '2',
      tipo: TipoAmenaza.quema,
      capturado: ahora.subtract(const Duration(days: 1)),
      estado: EstadoReporte.descartado,
    );
    final alertas = evaluarPronostico(
      d,
      zonaId: 'mallorquin',
      ahora: ahora,
      reportes: [activo, descartado],
    );
    expect(alertas.first.nivel, NivelPronostico.alto);
    expect(alertas.first.reportesRecientes, 1);
    expect(alertas[1].nivel, NivelPronostico.bajo);
    expect(alertas.first.porQue, contains('no confirman'));
  });

  test('oleaje solo cruza un reporte Otro con texto explícito', () {
    final base = reporteDePrueba(
      '3',
      tipo: TipoAmenaza.otro,
      capturado: ahora.subtract(const Duration(hours: 2)),
    );
    final erosion = Reporte.fromJson({
      ...base.toJson(),
      'descripcion': 'Erosión en la playa',
    });
    final alertas = evaluarPronostico(
      lectura(ola: 1.5),
      zonaId: 'mallorquin',
      ahora: ahora,
      reportes: [base, erosion],
    );
    expect(alertas[2].nivel, NivelPronostico.alto);
    expect(alertas[2].reportesRecientes, 1);
  });
}
