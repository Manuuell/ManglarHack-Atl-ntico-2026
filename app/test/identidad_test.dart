import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/nucleo/contraste.dart';
import 'package:zanky/nucleo/identidad.dart';

/// Las razones anotadas en `identidad.dart` se miden aquí: si alguien cambia un color, la prueba lo dice.
void main() {
  final casos = <(String, dynamic, dynamic, double)>[
    ('blanco / azul', Cra.blanco, Cra.azul, 14.6),
    ('blanco / hero', Cra.blanco, Cra.hero, 16.8),
    ('blanco / superficie', Cra.blanco, Cra.superficie, 11.8),
    ('suave / azul', Cra.textoSuave, Cra.azul, 8.6),
    ('suave / superficie', Cra.textoSuave, Cra.superficie, 6.9),
    ('tenue / superficie', Cra.textoTenue, Cra.superficie, 5.5),
    ('dorado / azul', Cra.dorado, Cra.azul, 7.6),
    ('dorado / hero', Cra.dorado, Cra.hero, 8.7),
    ('dorado / superficie', Cra.dorado, Cra.superficie, 6.1),
    ('azul / dorado', Cra.azul, Cra.dorado, 7.6),
    ('riesgo / superficie', Cra.riesgo, Cra.superficie, 5.2),
  ];
  for (final (nombre, a, b, minimo) in casos) {
    test('contraste AA: $nombre', () {
      final r = razonContraste(a, b);
      expect(r, greaterThanOrEqualTo(minimo));
      expect(r, greaterThanOrEqualTo(umbralTextoNormal));
    });
  }
  test('prioridades legibles sobre la superficie oscura', () {
    for (final p in Cra.prioridad.values) {
      expect(
        razonContraste(p, Cra.superficie),
        greaterThanOrEqualTo(umbralTextoNormal),
      );
    }
  });
}
