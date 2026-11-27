import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/admin/aviso_navegador.dart';
import 'package:zanky/datos/avisos/centro_avisos.dart';
import 'package:zanky/datos/avisos/reglas_avisos.dart';
import 'package:zanky/datos/comunidad/comunidad.dart';

/// Navegador falso: cuenta lo que se mostró.
class _Navegador extends AvisoNavegador {
  final mostrados = <String>[];
  @override
  bool get disponible => true;
  @override
  bool get bloqueado => false;
  @override
  Future<bool> pedirPermiso() async => true;
  @override
  void mostrar(String titulo, String cuerpo) => mostrados.add(titulo);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ahora = DateTime.utc(2026, 11, 27, 15);
  var nivel = 'naranja';
  var pedidos = 0;

  CentroAvisos nuevoCentro(_Navegador nav) => CentroAvisos(
        reloj: () => ahora,
        navegador: nav,
        fuente: FuenteComunidad(
          base: 'https://prueba.local',
          cliente: MockClient((r) async {
            pedidos++;
            return http.Response.bytes(
                utf8.encode(jsonEncode({
                  'generado': ahora.toIso8601String(),
                  'alertas': [
                    {
                      'id': 'leva-1',
                      'tipo': 'mar_de_leva',
                      'nivel': nivel,
                      'titulo': 'Mar de leva',
                      'recomendacion': 'No entres al agua.',
                      'lugar': 'Bocas de Ceniza',
                      'lat': 11.04,
                      'lon': -74.85,
                      'desde': '2026-11-27T10:00:00Z',
                      'hasta': '2026-11-28T10:00:00Z',
                    },
                    {
                      'id': 'lluvia-1',
                      'tipo': 'lluvia_fuerte',
                      'nivel': 'amarilla',
                      'titulo': 'Lluvia',
                      'desde': '2026-11-27T10:00:00Z',
                      'hasta': '2026-11-28T10:00:00Z',
                    },
                  ],
                })),
                200);
          }),
        ),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    nivel = 'naranja';
    pedidos = 0;
  });

  test('revisar dos veces avisa una sola vez; si sube a roja, avisa otra', () async {
    final nav = _Navegador();
    final c = nuevoCentro(nav);
    await c.cargar();
    await c.activarNavegador(true);
    await c.revisar();
    await c.revisar();
    expect(c.avisos, hasLength(1));
    expect(c.noLeidos, 1);
    expect(c.nuevo.value?.destino, 'leva-1');
    expect(nav.mostrados, hasLength(1));
    nivel = 'roja';
    await c.revisar();
    expect(c.avisos.map((a) => a.nivel), ['roja', 'naranja']);
    expect(nav.mostrados, hasLength(2));
    expect(pedidos, 3);
  });

  test('lo avisado se recuerda al reabrir la app (no se repite)', () async {
    final a = nuevoCentro(_Navegador());
    await a.cargar();
    await a.revisar();
    await Future<void>.delayed(Duration.zero);
    final b = nuevoCentro(_Navegador());
    await b.cargar();
    expect(b.avisos, hasLength(1));
    await b.revisar();
    expect(b.avisos, hasLength(1));
  });

  test('con las alertas apagadas no se pide nada a la red', () async {
    final c = nuevoCentro(_Navegador());
    await c.cargar();
    c.cambiarPreferencia(TipoAvisoApp.alerta, false);
    await c.revisar();
    expect(c.avisos, isEmpty);
    expect(pedidos, 0);
  });

  test('borrar y deshacer devuelve el aviso a su lugar; marcar leído baja el contador', () async {
    final c = nuevoCentro(_Navegador());
    await c.cargar();
    await c.revisar();
    nivel = 'roja';
    await c.revisar();
    final segundo = c.avisos[1];
    final i = c.borrar(segundo);
    expect(c.avisos, hasLength(1));
    c.restaurar(segundo, i);
    expect(c.avisos[1], same(segundo));
    c.marcarLeido(c.avisos.first);
    expect(c.noLeidos, 1);
    c.marcarTodoLeido();
    expect(c.noLeidos, 0);
  });
}
