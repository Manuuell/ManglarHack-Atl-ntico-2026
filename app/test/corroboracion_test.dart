// La corroboración de la app contra la regla del trigger del servidor (schema.sql,
// reportes_antes_insert): mismo tipo, ≤ 1 km, ±3 h, sin descartados y de OTRO reportante.
// Los resultados esperados están escritos a mano desde el SQL, no con la función.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zanky/datos/clima.dart';
import 'package:zanky/datos/estado.dart';
import 'package:zanky/datos/fotos.dart';
import 'package:zanky/datos/prioridad.dart';
import 'package:zanky/datos/reporte.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/datos/tipos.dart';
import 'package:zanky/datos/zonas.dart';
import 'package:zanky/vistas/reporte/borrador.dart';

import 'apoyo_datos.dart';
import 'servidor_contrato_test.dart' show jpegConGps;

const p0 = LatLng(11.05316, -74.85094);
// ~0,0045° de latitud ≈ 500 m; 0,011° ≈ 1,2 km.
const a500m = LatLng(11.05316 + 0.0045, -74.85094);
const a1200m = LatLng(11.05316 + 0.011, -74.85094);
final t0 = DateTime(2026, 11, 27, 15);

ReportePublico publico(String id, {TipoAmenaza tipo = TipoAmenaza.tala, LatLng punto = a500m, Duration antes = const Duration(hours: 1)}) =>
    ReportePublico(
      id: id,
      tipo: tipo,
      punto: punto,
      prioridad: 4,
      estado: EstadoReporte.recibido,
      capturadoEn: t0.subtract(antes),
      zona: 'mallorquin',
    );

void main() {
  group('contarCorroboraciones = regla del trigger', () {
    // (caso, reporte propio previo, ¿el nuevo va con nombre «yo»?, ¿cuenta en el servidor?)
    final casos = <(String, Reporte, bool, int)>[
      ('propio con el mismo nombre: el servidor lo excluye', reporteDePrueba('a', punto: a500m, capturado: t0), true, 0),
      ('propio anónimo: llegó sin reportante y el servidor lo cuenta',
          reporteDePrueba('b', punto: a500m, capturado: t0, anonimo: true), true, 1),
      ('nuevo anónimo: el servidor no sabe de quién es y cuenta el propio',
          reporteDePrueba('c', punto: a500m, capturado: t0), false, 1),
      ('propio de otro perfil del teléfono', reporteDePrueba('d', punto: a500m, capturado: t0, reportanteId: 'otro'), true, 1),
      ('descartado no cuenta', reporteDePrueba('e', punto: a500m, capturado: t0, anonimo: true, estado: EstadoReporte.descartado), true, 0),
      ('rechazado nunca llegó', reporteDePrueba('f', punto: a500m, capturado: t0, anonimo: true, envio: Envio.rechazado), true, 0),
      ('otro tipo no cuenta', reporteDePrueba('g', punto: a500m, capturado: t0, anonimo: true, tipo: TipoAmenaza.quema), true, 0),
      ('a 1,2 km no cuenta', reporteDePrueba('h', punto: a1200m, capturado: t0, anonimo: true), true, 0),
      ('justo 3 h antes cuenta', reporteDePrueba('i', punto: a500m, capturado: t0.subtract(const Duration(hours: 3)), anonimo: true), true, 1),
      ('3 h y 1 min antes no cuenta',
          reporteDePrueba('j', punto: a500m, capturado: t0.subtract(const Duration(hours: 3, minutes: 1)), anonimo: true), true, 0),
    ];
    for (final (nombre, previo, conNombre, esperado) in casos) {
      test(nombre, () {
        final n = contarCorroboraciones(
          tipo: TipoAmenaza.tala,
          punto: p0,
          cuando: t0,
          otros: [previo],
          excluirId: 'nuevo',
          reportanteId: conNombre ? 'yo' : null,
        );
        expect(n, esperado);
      });
    }

    test('cuenta los públicos de otras personas', () {
      expect(
        contarCorroboraciones(
            tipo: TipoAmenaza.tala, punto: p0, cuando: t0, otros: const [], publicos: [publico('x')], reportanteId: 'yo'),
        1,
      );
    });

    test('un público que es mío (mismo id público) no se cuenta dos veces', () {
      final mio = reporteDePrueba('m', punto: a500m, capturado: t0, idPublico: 'pub-m');
      expect(
        contarCorroboraciones(
            tipo: TipoAmenaza.tala, punto: p0, cuando: t0, otros: [mio], publicos: [publico('pub-m')], reportanteId: 'yo'),
        0,
      );
    });

    test('públicos de otro tipo, lejos o viejos no cuentan', () {
      expect(
        contarCorroboraciones(tipo: TipoAmenaza.tala, punto: p0, cuando: t0, otros: const [], publicos: [
          publico('1', tipo: TipoAmenaza.quema),
          publico('2', punto: a1200m),
          publico('3', antes: const Duration(hours: 4)),
        ]),
        0,
      );
    });
  });

  group('Borrador', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    late Manglar manglar;
    late Directory tmp;

    setUpAll(() {
      manglar = Manglar.desdeJson(
          jsonDecode(File('assets/datos/manglar_zonas.json').readAsStringSync()) as Map<String, dynamic>);
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tmp = Directory.systemTemp.createTempSync('zanky_borrador_');
      final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      m.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (c) async => tmp.path);
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
      tmp.deleteSync(recursive: true);
    });

    EstadoZanky estado() => EstadoZanky()
      ..manglar = manglar
      ..enLinea = false;

    test('corrobora con un público ajeno cerca y suma a la prioridad', () {
      final e = estado()..publicos = [publico('x', antes: Duration.zero)];
      final b = Borrador(e, tipo: TipoAmenaza.basuras)..marcarEnMapa(p0);
      expect(b.corroboraciones, 0, reason: 'el público es de tala y esto es basuras');
      b.cambiar(() => b.tipo = TipoAmenaza.tala);
      e.publicos = [ReportePublico(id: 'x', tipo: TipoAmenaza.tala, punto: a500m, prioridad: 4,
          estado: EstadoReporte.recibido, capturadoEn: DateTime.now(), zona: 'mallorquin')];
      expect(b.corroboraciones, 1);
      expect(b.prioridad!.motivos.join(' '), contains('parecido cerca'));
      b.dispose();
    });

    test('el viento es el de la zona del reporte: sin dato de Piojó no se suma el de Mallorquín', () {
      final e = estado()
        ..clima = Clima(temperatura: 30, vientoKmh: 40, vientoDireccion: 0, lluviaMm: 0, olaM: null, leido: DateTime.now());
      final b = Borrador(e, tipo: TipoAmenaza.quema)..marcarEnMapa(p0);
      expect(b.prioridad!.motivos.join(' '), contains('Viento de 40'), reason: 'en Mallorquín sí');
      b.marcarEnMapa(const LatLng(10.8162, -75.2035)); // dentro de Piojó
      expect(b.ubicacion!.zona.id, 'piojo');
      expect(b.prioridad!.motivos.join(' '), isNot(contains('Viento')));
      b.dispose();
    });

    test('un punto fuera del Atlántico no se deja enviar y lo dice', () async {
      final e = estado();
      final b = Borrador(e, tipo: TipoAmenaza.tala)..marcarEnMapa(const LatLng(4.65, -74.08)); // Bogotá
      expect(b.puntoAceptado, isFalse);
      expect(b.listoParaEnviar, isFalse);
      await expectLater(b.enviar(), throwsA(isA<ErrorAlGuardar>().having((x) => x.mensaje, 'mensaje', contains('fuera del Atlántico'))));
      expect(e.reportes, isEmpty);
      b.dispose();
    });

    test('al enviar: hora de tocar «Enviar», descripción recortada, prioridad local y foto sin GPS', () async {
      final e = estado();
      final b = Borrador(e, tipo: TipoAmenaza.tala)..marcarEnMapa(p0);
      b.ponerFoto(base64Decode(jpegConGps), deCamara: true);
      expect(latin1.decode(b.foto!).contains('TelefonoX'), isFalse, reason: 'la foto se limpia al ponerla');
      b.descripcion = '👨‍👩‍👧‍👦' * 200;
      final antes = DateTime.now();
      final r = await b.enviar();
      expect(r.capturadoEn.isBefore(antes), isFalse, reason: 'no la hora de abrir el flujo');
      expect(r.capturadoEn.isAfter(b.visto) || r.capturadoEn == b.visto, isTrue);
      expect(r.descripcion.runes.length, maxDescripcionServidor);
      expect(r.prioridadLocal, r.prioridad);
      final guardada = await Fotos.leer(r.fotoRef);
      expect(latin1.decode(guardada!).contains('TelefonoX'), isFalse);
      expect(r.fotoHash, Fotos.huella(guardada));
      b.dispose();
    });

    test('si guardar el reporte falla, la foto suelta se borra', () async {
      final e = _EstadoSinEspacio()
        ..manglar = manglar
        ..enLinea = false;
      final b = Borrador(e, tipo: TipoAmenaza.tala)..marcarEnMapa(p0);
      b.ponerFoto(base64Decode(jpegConGps), deCamara: true);
      await expectLater(b.enviar(), throwsA(isA<ErrorAlGuardar>().having((x) => x.sinEspacio, 'sinEspacio', isTrue)));
      final fotos = Directory('${tmp.path}/fotos');
      expect(fotos.existsSync() ? fotos.listSync() : const [], isEmpty);
      b.dispose();
    });
  });
}

class _EstadoSinEspacio extends EstadoZanky {
  @override
  Future<Reporte> agregar(Reporte r, foto) async =>
      throw const FileSystemException('write failed', 'x', OSError('No space left on device', 28));
}
