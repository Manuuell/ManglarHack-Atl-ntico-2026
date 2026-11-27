import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/datos/avisos_zona/reglas.dart';

void main() {
  consentimientoYBaja();
  test('radio geográfico: ~1,11 km por centésima de latitud', () {
    final d = distanciaKm(10.98, -74.78, 10.99, -74.78);
    expect(d, greaterThan(1.1));
    expect(d, lessThan(1.12));
    expect(avisarVoluntario(nivel: NivelAviso.alta, distanciaKm: d,
      radioKm: 1, eventosUltimaHora: 0, activo: true, tipoAceptado: true), isFalse);
  });

  test('prioridad selecciona destinatarios: encargado siempre, voluntario según nivel', () {
    for (final nivel in NivelAviso.values) {
      final cerca = avisarVoluntario(nivel: nivel, distanciaKm: 1.5,
        radioKm: 4, eventosUltimaHora: 0, activo: true, tipoAceptado: true);
      final lejos = avisarVoluntario(nivel: nivel, distanciaKm: 2.1,
        radioKm: 4, eventosUltimaHora: 0, activo: true, tipoAceptado: true);
      expect(cerca, nivel != NivelAviso.baja);
      expect(lejos, nivel == NivelAviso.alta);
    }
    expect(nivelDePrioridad(4), NivelAviso.alta);
    expect(nivelDePrioridad(3), NivelAviso.media);
    expect(nivelDePrioridad(2), NivelAviso.baja);
  });

  test('horario silencioso cruza medianoche y termina exactamente a la hora indicada', () {
    expect(enSilencio(23 * 60, 22 * 60, 7 * 60), isTrue);
    expect(enSilencio(6 * 60 + 59, 22 * 60, 7 * 60), isTrue);
    expect(enSilencio(7 * 60, 22 * 60, 7 * 60), isFalse);
    expect(enSilencio(12 * 60, null, null), isFalse);
  });

  test('máximo tres eventos por voluntario y hora; requiere estado activo y tipo aceptado', () {
    bool admite(int n, {bool activo = true, bool tipo = true}) => avisarVoluntario(
      nivel: NivelAviso.alta, distanciaKm: 1, radioKm: 2,
      eventosUltimaHora: n, activo: activo, tipoAceptado: tipo);
    expect(admite(2), isTrue);
    expect(admite(3), isFalse);
    expect(admite(0, activo: false), isFalse);
    expect(admite(0, tipo: false), isFalse);
  });
}

void consentimientoYBaja() {
  group('consentimiento y baja (portado del bot)', () {
    test('frases de baja', () {
      expect(interpretarRespuesta('BAJA'), RespuestaAviso.baja);
      expect(interpretarRespuesta('Darme de baja.'), RespuestaAviso.baja);
      expect(interpretarRespuesta('no me interesa, gracias'), RespuestaAviso.baja);
      expect(interpretarRespuesta('No'), RespuestaAviso.bajaDebil);
      expect(interpretarRespuesta('hola, ¿qué pasó?'), RespuestaAviso.ninguna);
      expect(interpretarRespuesta('   '), RespuestaAviso.ninguna);
    });
    test('teléfonos a E.164 y sin repetidos', () {
      expect(normalizarTelefono('300 123 4567'), '+573001234567');
      expect(normalizarTelefono('+57 300 123 4567'), '+573001234567');
      expect(normalizarTelefono('123'), isNull);
      expect(depurarDestinatarios(['300 123 4567', '+573001234567', 'xx', '+14155550123']),
          ['+573001234567', '+14155550123']);
    });
    test('la constancia se revoca sin perder la fecha anterior', () {
      final c = ConstanciaConsentimiento(Decision.si, DateTime(2026, 11, 27));
      final r = c.revocar(DateTime(2026, 11, 28));
      expect(c.vigente, isTrue);
      expect(r.vigente, isFalse);
      expect(r.fecha, DateTime(2026, 11, 28));
    });
  });
}
