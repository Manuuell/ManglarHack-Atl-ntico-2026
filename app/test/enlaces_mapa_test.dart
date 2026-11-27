import 'package:flutter_test/flutter_test.dart';
import 'package:zanqui/datos/enlaces_mapa.dart';

void main() {
  void espera(String texto, double lat, double lon) {
    final r = leerEnlaceMapa(texto);
    expect(r.punto, isNotNull, reason: texto);
    expect(r.punto!.latitude, closeTo(lat, 1e-6), reason: texto);
    expect(r.punto!.longitude, closeTo(lon, 1e-6), reason: texto);
  }

  test('la @ de una vista de Google Maps', () {
    espera('https://www.google.com/maps/@11.0432,-74.8611,17z', 11.0432, -74.8611);
  });

  test('en un lugar manda el pin (!3d!4d), no el centro de la vista (@)', () {
    espera(
      'https://www.google.com/maps/place/Ci%C3%A9naga+de+Mallorqu%C3%ADn/@11.0400,-74.8700,15z/data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d11.0435!4d-74.8607',
      11.0435,
      -74.8607,
    );
  });

  test('parámetros q, ll y query', () {
    espera('https://maps.google.com/?q=11.0432,-74.8611', 11.0432, -74.8611);
    espera('https://maps.google.com/maps?ll=10.95,-75.03&z=14', 10.95, -75.03);
    espera('https://www.google.com/maps/search/?api=1&query=10.8162%2C-75.2035', 10.8162, -75.2035);
  });

  test('geo: y coordenadas sueltas', () {
    espera('geo:10.85258,-75.13677', 10.85258, -75.13677);
    espera('11.0432, -74.8611', 11.0432, -74.8611);
    espera('  11.0432 -74.8611 ', 11.0432, -74.8611);
  });

  test('los enlaces cortos se reconocen pero no se adivinan', () {
    final r = leerEnlaceMapa('https://maps.app.goo.gl/AbCdEf123');
    expect(r.corto, isTrue);
    expect(r.punto, isNull);
  });

  test('texto que no es una ubicación y coordenadas imposibles', () {
    expect(leerEnlaceMapa('están talando por el caño').punto, isNull);
    expect(leerEnlaceMapa('').punto, isNull);
    expect(leerEnlaceMapa('geo:123.4,-74.8').punto, isNull);
  });

  test('un punto en Bogotá no está en el Atlántico', () {
    expect(enElAtlantico(leerEnlaceMapa('4.711,-74.072').punto!), isFalse);
    expect(enElAtlantico(leerEnlaceMapa('11.0432,-74.8611').punto!), isTrue);
  });
}
