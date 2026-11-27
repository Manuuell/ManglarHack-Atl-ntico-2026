import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/datos/avisos/notificador_android.dart';
import 'package:zanky/datos/avisos/reglas_avisos.dart';
import 'package:zanky/datos/experiencia/jornada.dart';

/// Doble del plugin: anota lo que se le pide, sin plataforma.
class _PluginDoble implements PluginAvisos {
  int inicios = 0, permisos = 0;
  bool concede = true;
  String? arranque;
  void Function(String)? alTocar;
  final mostrados = <(int, String, String, CanalAviso, String)>[];
  final programados = <(int, DateTime, String, CanalAviso, String)>[];
  final cancelados = <int>[];

  @override
  Future<void> iniciar(void Function(String clave) alTocar) async {
    inicios++;
    this.alTocar = alTocar;
  }

  @override
  Future<String?> claveDeArranque() async => arranque;

  @override
  Future<bool> pedirPermiso() async {
    permisos++;
    return concede;
  }

  @override
  Future<void> mostrar(int id, String titulo, String cuerpo, CanalAviso canal, String clave) async =>
      mostrados.add((id, titulo, cuerpo, canal, clave));

  @override
  Future<void> programar(int id, DateTime cuandoUtc, String titulo, String cuerpo, CanalAviso canal, String clave) async =>
      programados.add((id, cuandoUtc, titulo, canal, clave));

  @override
  Future<void> cancelar(int id) async => cancelados.add(id);
}

// Sábado 6 de diciembre de 2026, 8:00 a. m. en Colombia (UTC-5) = 13:00 UTC.
final _inicio = DateTime.utc(2026, 12, 6, 13);

Jornada _jornada() => Jornada(
      id: 'j1',
      accionId: 'a1',
      titulo: 'Siembra de mangle',
      tipo: 'siembra',
      inicio: _inicio,
      fin: _inicio.add(const Duration(hours: 3)),
      puntoEncuentro: 'Ecoparque Mallorquín',
      lat: 11.03,
      lon: -74.86,
      cupos: 30,
      inscritos: 4,
      queLlevar: const ['gorra', 'agua'],
      descripcion: '',
    );

void main() {
  group('canales e ids', () {
    test('las alertas van al canal alto; jornadas y reportes, al normal', () {
      expect(canalDe('alerta|a1|roja'), same(canalAlertas));
      expect(canalAlertas.alta, isTrue);
      expect(canalAlertas.nombre, 'Alertas del manglar');
      expect(canalDe('jornada|j1|2h'), same(canalJornadas));
      expect(canalDe('reporte|r1|123'), same(canalJornadas));
      expect(canalJornadas.nombre, 'Jornadas y reportes');
      expect(canalJornadas.alta, isFalse);
    });

    test('el id es estable, positivo y distinto por clave', () {
      expect(idDeAviso('jornada|j1|2h'), idDeAviso('jornada|j1|2h'));
      expect(idDeAviso('jornada|j1|2h'), isNot(idDeAviso('jornada|j1|vispera')));
      for (final c in ['', 'a', 'alerta|x|roja', 'ñandú|' * 40]) {
        expect(idDeAviso(c), inInclusiveRange(0, 0x7FFFFFFF));
      }
    });
  });

  group('programación de jornadas (hora de Colombia)', () {
    test('víspera a las 6:00 p. m. de Colombia y 2 h antes, con las claves de la bandeja', () {
      final p = programacionesJornada(_jornada(), DateTime.utc(2026, 12, 1, 12));
      expect(p, hasLength(2));
      // Víspera: viernes 5 a las 18:00 de Colombia = 23:00 UTC.
      expect(p[0].cuando, DateTime.utc(2026, 12, 5, 23));
      expect(p[0].aviso.clave, 'jornada|j1|vispera');
      expect(p[0].aviso.titulo, 'Mañana: Siembra de mangle');
      // 2 h antes: 6:00 a. m. de Colombia = 11:00 UTC.
      expect(p[1].cuando, DateTime.utc(2026, 12, 6, 11));
      expect(p[1].aviso.clave, 'jornada|j1|2h');
      expect(p[1].aviso.cuerpo, contains('Ecoparque Mallorquín'));
    });

    test('lo que ya pasó no se programa', () {
      // Inscrito la víspera a las 8:00 p. m.: solo queda el de 2 h antes.
      final p = programacionesJornada(_jornada(), DateTime.utc(2026, 12, 6, 1));
      expect(p.map((x) => x.aviso.clave), ['jornada|j1|2h']);
      // Ya empezó: nada.
      expect(programacionesJornada(_jornada(), DateTime.utc(2026, 12, 6, 14)), isEmpty);
    });
  });

  group('NotificadorAndroid con el doble del plugin', () {
    test('inicializa una sola vez y nunca pide permiso por su cuenta', () async {
      final doble = _PluginDoble();
      final n = NotificadorAndroid(doble);
      await n.mostrar('🔴 Alerta roja: Tala', 'Ciénaga de Mallorquín', 'alerta|a1|roja');
      await n.mostrar('Novedad de tu reporte', 'Ya llegó', 'reporte|r1|9');
      expect(doble.inicios, 1);
      expect(doble.permisos, 0);
      expect(doble.mostrados[0].$1, idDeAviso('alerta|a1|roja'));
      expect(doble.mostrados[0].$4, same(canalAlertas));
      expect(doble.mostrados[0].$5, 'alerta|a1|roja');
      expect(doble.mostrados[1].$4, same(canalJornadas));
    });

    test('el permiso solo se pide cuando se llama desde el toque', () async {
      final doble = _PluginDoble()..concede = false;
      final n = NotificadorAndroid(doble);
      expect(await n.pedirPermiso(), isFalse);
      expect(doble.permisos, 1);
    });

    test('programa los dos recordatorios con id de su clave y los cancela', () async {
      final doble = _PluginDoble();
      final n = NotificadorAndroid(doble, reloj: () => DateTime.utc(2026, 12, 1, 12));
      final claves = await n.programarJornada(_jornada());
      expect(claves, ['jornada|j1|vispera', 'jornada|j1|2h']);
      expect(doble.programados.map((p) => p.$1), [for (final c in claves) idDeAviso(c)]);
      expect(doble.programados.map((p) => p.$4), everyElement(same(canalJornadas)));
      expect(doble.programados.first.$2, DateTime.utc(2026, 12, 5, 23));

      await n.cancelarJornada('j1');
      expect(doble.cancelados, [for (final c in clavesJornada('j1')) idDeAviso(c)]);
    });

    test('tocar el aviso (app viva o cerrada) entrega la clave de la bandeja', () async {
      final doble = _PluginDoble()..arranque = 'jornada|j1|vispera';
      final n = NotificadorAndroid(doble);
      final tocadas = <String>[];
      await n.escuchar(tocadas.add);
      expect(tocadas, ['jornada|j1|vispera']); // abrió la app desde el aviso
      doble.alTocar!('alerta|a1|roja'); // con la app abierta
      expect(tocadas, ['jornada|j1|vispera', 'alerta|a1|roja']);
    });

    test('la clave del aviso coincide con la de la bandeja', () {
      final ahora = DateTime.utc(2026, 12, 6, 11, 30);
      final enBandeja = recordatoriosJornadas([_jornada()], const {}, ahora).single;
      final programado = programacionesJornada(_jornada(), DateTime.utc(2026, 12, 1)).last.aviso;
      expect(programado.clave, enBandeja.clave);
      expect(programado.titulo, enBandeja.titulo);
    });
  });
}
