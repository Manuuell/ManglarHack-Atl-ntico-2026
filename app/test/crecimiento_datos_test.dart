import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/datos/crecimiento/progreso_crecimiento.dart';
import 'package:zanky/datos/crecimiento/ranking_colegios.dart';
import 'package:zanky/datos/servidor.dart';

void main() {
  test('las cinco etapas usan los umbrales reales de Guardián', () {
    const casos = <int, int>{
      0: 1, 59: 1, 60: 2, 179: 2, 180: 3,
      399: 3, 400: 4, 799: 4, 800: 5, 1500: 5,
    };
    for (final caso in casos.entries) {
      expect(EtapaCrecimiento.dePuntos(caso.key).numero, caso.value);
    }
  });

  test('lo que falta explica puntos y estimación honesta de reportes', () {
    final inicio = AvanceCrecimiento.de(0);
    expect(inicio.faltanPuntos, 60);
    expect(inicio.faltaTexto, contains('hasta 2 reportes validados más'));
    expect(AvanceCrecimiento.de(50).faltaTexto, contains('hasta 1 reporte validado más'));
    expect(AvanceCrecimiento.de(60).fraccion, 0);
    expect(AvanceCrecimiento.de(800).fraccion, 1);
    expect(AvanceCrecimiento.de(800).siguiente, isNull);
  });

  test('solo un nivel superior previamente visto inicia la evolución', () {
    expect(RegistroEvolucion.debeEvolucionar(null, 3), isFalse);
    expect(RegistroEvolucion.debeEvolucionar(2, 2), isFalse);
    expect(RegistroEvolucion.debeEvolucionar(3, 2), isFalse);
    expect(RegistroEvolucion.debeEvolucionar(2, 3), isTrue);
    expect(RegistroEvolucion.clave('persona'), contains('persona'));
  });

  test('el ranking usa la RPC pública con límite y lee puestos reales', () async {
    final cliente = MockClient((peticion) async {
      expect(peticion.method, 'POST');
      expect(peticion.url.path, '/rest/v1/rpc/ranking_colegios');
      expect(peticion.body, contains('"limite":5'));
      expect(peticion.headers['apikey'], 'clave-prueba');
      return http.Response('[{"puesto":1,"colegio":"Colegio del manglar",'
          '"validados":3,"totales":4}]', 200);
    });
    final servidor = Servidor(base: 'https://ejemplo.invalid',
      anon: 'clave-prueba', cliente: cliente);
    final filas = await RankingColegios(servidor).cargar(limite: 5);
    expect(filas.single.nombre, 'Colegio del manglar');
    expect(filas.single.validados, 3);
    cliente.close();
  });
}
