import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zanky/datos/avisos/reglas_avisos.dart';
import 'package:zanky/datos/comunidad/comunidad.dart';
import 'package:zanky/datos/experiencia/jornada.dart';

AlertaManglar _alerta(String id, NivelAlerta nivel, {DateTime? hasta}) => AlertaManglar(
      id: id,
      tipo: 'mar_de_leva',
      nivel: nivel,
      titulo: 'Mar de leva',
      detalle: 'Olas de 2 m',
      recomendacion: 'No entres al agua.',
      lugar: 'Bocas de Ceniza',
      punto: const LatLng(11.04, -74.85),
      desde: DateTime.utc(2026, 11, 27, 10),
      hasta: hasta ?? DateTime.utc(2026, 11, 28, 10),
      medido: true,
      fuentes: const ['dimar'],
    );

Jornada _jornada(DateTime inicio) => Jornada(
      id: 'j1',
      accionId: 'a1',
      titulo: 'Siembra de mangle',
      tipo: 'siembra',
      inicio: inicio,
      fin: inicio.add(const Duration(hours: 3)),
      puntoEncuentro: 'Ecoparque Mallorquín',
      lat: 11.03,
      lon: -74.86,
      cupos: 30,
      inscritos: 4,
      queLlevar: const ['gorra', 'agua'],
      descripcion: '',
    );

void main() {
  final ahora = DateTime.utc(2026, 11, 27, 15);

  group('alertas', () {
    test('solo naranja y roja vigentes, con lugar, nivel y qué hacer', () {
      final r = avisosDeAlertas([
        _alerta('a', NivelAlerta.amarilla),
        _alerta('b', NivelAlerta.naranja),
        _alerta('c', NivelAlerta.roja),
        _alerta('d', NivelAlerta.roja, hasta: DateTime.utc(2026, 11, 27, 12)), // ya terminó
      ], {}, ahora);
      expect(r.map((a) => a.destino), ['b', 'c']);
      expect(r.first.titulo, contains('Alerta naranja'));
      expect(r.first.cuerpo, contains('Bocas de Ceniza'));
      expect(r.first.cuerpo, contains('Qué hacer: No entres al agua.'));
      expect(r.last.cuerpo, contains('123'));
      expect(r.first.lat, 11.04);
    });

    test('no repite lo ya avisado, pero sí avisa si sube de naranja a roja', () {
      final primera = avisosDeAlertas([_alerta('b', NivelAlerta.naranja)], {}, ahora);
      final ya = primera.map((a) => a.clave).toSet();
      expect(avisosDeAlertas([_alerta('b', NivelAlerta.naranja)], ya, ahora), isEmpty);
      final sube = avisosDeAlertas([_alerta('b', NivelAlerta.roja)], ya, ahora);
      expect(sube, hasLength(1));
      expect(sube.single.nivel, 'roja');
    });
  });

  group('jornadas', () {
    // Jornada el sábado 28-nov a las 7:00 a. m. de Colombia (12:00 UTC).
    final inicio = DateTime.utc(2026, 11, 28, 12);
    final j = _jornada(inicio);

    test('la víspera es a las 6:00 p. m. de Colombia del día anterior', () {
      expect(momentoVispera(inicio), DateTime.utc(2026, 11, 27, 23));
    });

    test('antes de la víspera no hay nada', () {
      expect(recordatoriosJornadas([j], {}, DateTime.utc(2026, 11, 27, 22, 59)), isEmpty);
    });

    test('la víspera avisa una sola vez', () {
      final r = recordatoriosJornadas([j], {}, DateTime.utc(2026, 11, 27, 23, 5));
      expect(r, hasLength(1));
      expect(r.single.clave, 'jornada|j1|vispera');
      expect(r.single.titulo, startsWith('Mañana'));
      expect(r.single.cuerpo, contains('7:00 a. m.'));
      expect(r.single.cuerpo, contains('Ecoparque Mallorquín'));
      expect(recordatoriosJornadas([j], {r.single.clave}, DateTime.utc(2026, 11, 28, 1)), isEmpty);
    });

    test('2 h antes avisa aunque la víspera ya se haya dado', () {
      final r = recordatoriosJornadas([j], {'jornada|j1|vispera'}, DateTime.utc(2026, 11, 28, 10, 30));
      expect(r.single.clave, 'jornada|j1|2h');
      expect(r.single.titulo, contains('empieza pronto'));
    });

    test('quien se inscribe 1 h antes solo recibe el de 2 h; una jornada pasada no avisa', () {
      final r = recordatoriosJornadas([j], {}, DateTime.utc(2026, 11, 28, 11));
      expect(r.map((a) => a.clave), ['jornada|j1|2h']);
      expect(recordatoriosJornadas([j], {}, DateTime.utc(2026, 11, 28, 13)), isEmpty);
    });
  });

  group('reportes', () {
    test('usa el texto del bot y no repite el mismo cambio', () {
      const texto = 'Listo: tu reporte ZK-1 ya llegó al panel de la CRA. ¡Gracias por cuidar el manglar!';
      final a = avisoDeNovedad(texto, 'r1', {}, ahora)!;
      expect(a.titulo, 'Tu reporte llegó a la CRA');
      expect(a.cuerpo, texto);
      expect(a.destino, 'r1');
      expect(avisoDeNovedad(texto, 'r1', {a.clave}, ahora), isNull);
      expect(avisoDeNovedad(null, 'r1', {}, ahora), isNull);
      expect(avisoDeNovedad('Novedad de tu reporte ZK-1: ahora está validado.', 'r1', {a.clave}, ahora)!.titulo,
          'Novedad de tu reporte');
    });
  });

  group('bandeja y preferencias', () {
    test('une sin repetir, lo nuevo arriba y con tope', () {
      AvisoApp av(String c, int min) => AvisoApp(
          clave: c, tipo: TipoAvisoApp.alerta, titulo: c, cuerpo: '', creado: ahora.add(Duration(minutes: min)), destino: c);
      final b = unirBandeja([av('x', 0)], [av('y', 5), av('x', 9)]);
      expect(b.map((a) => a.clave), ['x', 'y']); // la «x» más reciente gana y queda una sola
      expect(b.first.creado, ahora.add(const Duration(minutes: 9)));
      final muchos = unirBandeja([], [for (var i = 0; i < 80; i++) av('k$i', i)]);
      expect(muchos, hasLength(maxAvisos));
      expect(muchos.first.clave, 'k79');
    });

    test('ida y vuelta por JSON', () {
      final a = avisosDeAlertas([_alerta('b', NivelAlerta.roja)], {}, ahora).single..leido = true;
      final b = AvisoApp.deJson(a.aJson())!;
      expect([b.clave, b.tipo, b.nivel, b.leido, b.lat], [a.clave, a.tipo, 'roja', true, 11.04]);
    });

    test('preferencias por tipo', () {
      const p = PreferenciasAvisos();
      final sinJornadas = p.con(TipoAvisoApp.jornada, false);
      expect(sinJornadas.permite(TipoAvisoApp.jornada), isFalse);
      expect(sinJornadas.permite(TipoAvisoApp.alerta), isTrue);
      expect(PreferenciasAvisos.deJson(sinJornadas.aJson()).jornadas, isFalse);
      expect(PreferenciasAvisos.deJson(null).reportes, isTrue);
    });

    test('recorta las claves recordadas a las más recientes', () {
      final c = recortarClaves({for (var i = 0; i < maxClaves + 10; i++) 'c$i'});
      expect(c, hasLength(maxClaves));
      expect(c.first, 'c10');
    });
  });
}
