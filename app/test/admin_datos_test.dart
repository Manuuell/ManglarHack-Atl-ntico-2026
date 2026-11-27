// Lógica del panel de la CRA dentro de la app: filtros, cifras, decisiones con «Deshacer»,
// consulta periódica con avisos de llegada y el contrato con Supabase (sin red real).
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zanky/datos/admin/aviso_navegador.dart';
import 'package:zanky/datos/admin/controlador_admin.dart';
import 'package:zanky/datos/admin/repositorio_admin.dart';
import 'package:zanky/datos/admin/reporte_admin.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/datos/tipos.dart';

final _ahora = DateTime(2026, 11, 27, 13, 30);

class _NavegadorFalso extends AvisoNavegador {
  final avisos = <String>[];
  bool concede = true;
  int pedidos = 0;
  @override
  bool get disponible => true;
  @override
  Future<bool> pedirPermiso() async {
    pedidos++;
    return concede;
  }

  @override
  void mostrar(String titulo, String cuerpo) => avisos.add('$titulo|$cuerpo');
}

ControladorAdmin _demo({Duration cada = Duration.zero, AvisoNavegador? navegador, Duration plazo = const Duration(milliseconds: 50)}) {
  final c = ControladorAdmin(
    servidor: Servidor(base: '', anon: ''),
    reloj: () => _ahora,
    cada: cada,
    plazoDeshacer: plazo,
    avisoNavegador: navegador ?? _NavegadorFalso(),
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _esperarCarga(ControladorAdmin c) async {
  for (var i = 0; i < 50 && !c.cargado; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bandeja: filtros y orden', () {
    final todos = reportesDemo(_ahora);

    test('pendientes son los recibidos y en verificación, lo más urgente primero', () {
      final l = bandeja(todos, FiltroBandeja.pendientes);
      expect(l.map((r) => r.id), ['demo-01', 'demo-02', 'demo-03', 'demo-04', 'demo-05']);
      expect(l.every((r) => r.pendiente), isTrue);
      // Misma prioridad 5: el más reciente primero.
      expect(l[0].llegadaEn.isAfter(l[1].llegadaEn), isTrue);
    });

    test('aprobados = verificado, alerta, atención y cerrado; rechazados = descartado', () {
      expect(bandeja(todos, FiltroBandeja.aprobados).map((r) => r.id).toSet(),
          {'demo-06', 'demo-07', 'demo-09', 'demo-10', 'demo-12'});
      expect(bandeja(todos, FiltroBandeja.rechazados).map((r) => r.id).toSet(), {'demo-08', 'demo-11'});
    });

    test('todos pone lo pendiente antes que lo resuelto', () {
      final l = bandeja(todos, FiltroBandeja.todos);
      expect(l.length, todos.length);
      final primeroResuelto = l.indexWhere((r) => !r.pendiente);
      expect(l.skip(primeroResuelto).every((r) => !r.pendiente), isTrue);
    });

    test('los conteos de los segmentos suman cada filtro', () {
      final c = contarPorFiltro(todos);
      expect(c[FiltroBandeja.pendientes], 5);
      expect(c[FiltroBandeja.aprobados], 5);
      expect(c[FiltroBandeja.rechazados], 2);
      expect(c[FiltroBandeja.todos], 12);
    });

    test('una lista vacía no rompe nada', () {
      expect(bandeja(const [], FiltroBandeja.todos), isEmpty);
      expect(resumir(const [], inicioDelDia(_ahora)).vacio, isTrue);
    });
  });

  group('Resumen: cifras del día y de la semana', () {
    final todos = reportesDemo(_ahora);

    test('hoy: los de las últimas horas desde medianoche', () {
      final hoy = resumir(todos, inicioDelDia(_ahora));
      // 01 (20 min), 02 (1 h), 03 (3 h), 04 (5 h), 05 (7 h → 06:30, hoy). 06 es de ayer.
      expect(hoy.nuevos, 5);
      expect(hoy.altaPrioridad, 4); // 01, 02, 03, 04
      expect(hoy.pendientes, 5);
      expect(hoy.porZona.keys.first, 'Ciénaga de Mallorquín');
      expect(hoy.porZona['Ciénaga de Mallorquín'], 2);
    });

    test('la semana cuenta 7 días con hoy y deja fuera lo de hace 8', () {
      final sem = resumir(todos, inicioDeLaSemana(_ahora));
      expect(sem.nuevos, 11); // todos menos el 12 (hace 8 días)
      expect(sem.porTipo.values.fold<int>(0, (a, b) => a + b), 11);
      // Ordenado de más a menos.
      final v = sem.porZona.values.toList();
      expect([...v]..sort((a, b) => b.compareTo(a)), v);
    });

    test('por día: 7 cubos, el último es hoy', () {
      final d = porDia(todos, _ahora);
      expect(d.length, 7);
      expect(d.last, 5);
      expect(d.fold<int>(0, (a, b) => a + b), 11);
    });
  });

  group('ReporteAdmin.fromJson', () {
    test('lee lo que da Supabase y acota valores raros', () {
      final r = ReporteAdmin.fromJson({
        'id': 'a',
        'tipo': 'quema',
        'lat': 11.05,
        'lon': -74.85,
        'zona': null,
        'prioridad': 9,
        'confianza': 140,
        'estado': 'en_verificacion',
        'capturado_en': '2026-11-27T15:00:00Z',
        'foto_url': 'evidencias/a.jpg',
        'distancia_m': 120,
      });
      expect(r.tipo, TipoAmenaza.quema);
      expect(r.prioridad, 5);
      expect(r.confianza, 100);
      expect(r.zona, 'Sin zona');
      expect(r.tieneFoto, isTrue);
      expect(r.estado, EstadoReporte.enVerificacion);
      expect(r.pendiente, isTrue);
    });
  });

  group('Controlador en demostración', () {
    test('sin servidor configurado no se puede entrar con cuenta, solo en demostración', () async {
      final c = _demo();
      expect(c.configurado, isFalse);
      await expectLater(c.entrar('a@b.co', 'x'), throwsA(isA<ErrorPanel>()));
      c.entrarDemo();
      expect(c.dentro, isTrue);
      expect(c.demostracion, isTrue);
      await _esperarCarga(c);
      expect(c.reportes.length, 12);
    });

    test('el contador cuenta los recibidos sin ver y se limpia al abrir la bandeja', () async {
      final c = _demo()..entrarDemo(semilla: reportesDemo(_ahora));
      await _esperarCarga(c);
      expect(c.sinVer, 4); // 01, 02, 04 y 05 (el 03 ya está en verificación)
      c.marcarVistos();
      expect(c.sinVer, 0);
    });

    test('aprobar cambia el estado al instante y lo confirma pasado el plazo', () async {
      final c = _demo()..entrarDemo();
      await _esperarCarga(c);
      final r = c.reportes.firstWhere((x) => x.id == 'demo-01');
      await c.decidir(AccionAdmin.aprobar, r);
      expect(c.reportes.firstWhere((x) => x.id == 'demo-01').estado, EstadoReporte.verificado);
      expect(c.pendiente, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(c.pendiente, isNull);
      expect(c.reportes.firstWhere((x) => x.id == 'demo-01').estado, EstadoReporte.verificado);
      await c.actualizar();
      expect(c.reportes.firstWhere((x) => x.id == 'demo-01').estado, EstadoReporte.verificado);
      expect(c.visibles.any((x) => x.id == 'demo-01'), isFalse); // salió de «Pendientes»
    });

    test('Deshacer devuelve el reporte tal cual y el repositorio nunca se entera', () async {
      final c = _demo(plazo: const Duration(milliseconds: 200))..entrarDemo();
      await _esperarCarga(c);
      final r = c.reportes.firstWhere((x) => x.id == 'demo-02');
      await c.decidir(AccionAdmin.rechazar, r, texto: 'No es el manglar');
      expect(c.reportes.firstWhere((x) => x.id == 'demo-02').estado, EstadoReporte.descartado);
      c.deshacer();
      expect(c.pendiente, isNull);
      expect(c.reportes.firstWhere((x) => x.id == 'demo-02').estado, EstadoReporte.recibido);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await c.actualizar();
      expect(c.reportes.firstWhere((x) => x.id == 'demo-02').estado, EstadoReporte.recibido);
    });

    test('rechazar guarda el motivo para quien reportó; pedir datos deja en verificación con el mensaje', () async {
      final c = _demo(plazo: const Duration(milliseconds: 10))..entrarDemo();
      await _esperarCarga(c);
      await c.decidir(AccionAdmin.rechazar, c.reportes.firstWhere((x) => x.id == 'demo-04'), texto: 'Foto de otro sitio');
      await c.decidir(AccionAdmin.pedirDatos, c.reportes.firstWhere((x) => x.id == 'demo-05'), texto: '¿Hay maquinaria?');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final a = c.reportes.firstWhere((x) => x.id == 'demo-04');
      final b = c.reportes.firstWhere((x) => x.id == 'demo-05');
      expect(a.estado, EstadoReporte.descartado);
      expect(a.notaPublica, 'Foto de otro sitio');
      expect(b.estado, EstadoReporte.enVerificacion);
      expect(b.notaPublica, '¿Hay maquinaria?');
    });

    test('una segunda decisión manda primero la anterior', () async {
      final c = _demo(plazo: const Duration(seconds: 5))..entrarDemo();
      await _esperarCarga(c);
      await c.decidir(AccionAdmin.aprobar, c.reportes.firstWhere((x) => x.id == 'demo-01'));
      final primera = c.pendiente!;
      await c.decidir(AccionAdmin.aprobar, c.reportes.firstWhere((x) => x.id == 'demo-02'));
      expect(c.pendiente, isNot(primera));
      expect(c.pendiente!.antes.id, 'demo-02');
      await c.actualizar();
      expect(c.reportes.firstWhere((x) => x.id == 'demo-01').estado, EstadoReporte.verificado);
      c.deshacer();
    });

    test('rechazar sin motivo lo para el repositorio y deja el aviso de fallo', () async {
      final c = _demo(plazo: const Duration(milliseconds: 10))..entrarDemo();
      await _esperarCarga(c);
      await c.decidir(AccionAdmin.rechazar, c.reportes.firstWhere((x) => x.id == 'demo-01'), texto: '  ');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(c.reportes.firstWhere((x) => x.id == 'demo-01').estado, EstadoReporte.recibido);
      expect(c.tomarFallo(), contains('motivo'));
    });

    test('salir manda lo pendiente y vuelve a cero', () async {
      final c = _demo(plazo: const Duration(seconds: 5))..entrarDemo();
      await _esperarCarga(c);
      await c.decidir(AccionAdmin.aprobar, c.reportes.first);
      c.salir();
      expect(c.dentro, isFalse);
      expect(c.reportes, isEmpty);
      expect(c.pendiente, isNull);
    });
  });

  group('Avisos de reportes nuevos', () {
    test('la primera carga no avisa; un reporte que llega después sí, con contador', () async {
      final nav = _NavegadorFalso();
      final c = _demo(navegador: nav)..entrarDemo();
      await _esperarCarga(c);
      expect(c.aviso, isNull);
      c.marcarVistos();
      expect(c.sinVer, 0);
      c.simularLlegada();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.aviso, isNotNull);
      expect(c.aviso!.cantidad, 1);
      expect(c.aviso!.titulo, 'Reporte nuevo');
      expect(c.sinVer, 1);
      expect(nav.avisos, isEmpty, reason: 'el aviso del navegador solo si el admin lo activó');
    });

    test('con los avisos del navegador activados, también se dispara la notificación', () async {
      final nav = _NavegadorFalso();
      final c = _demo(navegador: nav)..entrarDemo();
      await _esperarCarga(c);
      expect(await c.activarAvisosNavegador(true), isTrue);
      expect(nav.activo, isTrue);
      c.simularLlegada();
      c.simularLlegada();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(nav.avisos, hasLength(1)); // dos llegadas en una sola consulta = un aviso
      expect(nav.avisos.single, startsWith('2 reportes nuevos|'));
      await c.activarAvisosNavegador(false);
      c.simularLlegada();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(nav.avisos, hasLength(1));
    });

    test('si el navegador no concede permiso, queda apagado', () async {
      final nav = _NavegadorFalso()..concede = false;
      final c = _demo(navegador: nav)..entrarDemo();
      expect(await c.activarAvisosNavegador(true), isFalse);
      expect(nav.activo, isFalse);
    });

    test('consulta periódica: cada tick trae lo nuevo sin que nadie toque nada', () async {
      final c = _demo(cada: const Duration(milliseconds: 40))..entrarDemo();
      await _esperarCarga(c);
      c.marcarVistos();
      final repo = c.reportes.length;
      c.simularLlegada(); // ya consulta una vez
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(c.reportes.length, repo + 1);
      c.salir(); // cancela el reloj: no hay Timer colgado
    });
  });

  group('Contrato con Supabase (sin red)', () {
    final peticiones = <http.Request>[];

    Servidor servidorCon(Future<http.Response> Function(http.Request r) f) => Servidor(
          base: 'https://x.supabase.co',
          anon: 'anon',
          cliente: MockClient((req) async {
            peticiones.add(req);
            return f(req);
          }),
        );

    setUp(peticiones.clear);

    http.Response json(Object? o, [int s = 200]) =>
        http.Response(jsonEncode(o), s, headers: {'content-type': 'application/json; charset=utf-8'});

    Map<String, dynamic> fila(String id, String estado) => {
          'id': id,
          'tipo': 'tala',
          'lat': 11.05,
          'lon': -74.85,
          'estado': estado,
          'capturado_en': '2026-11-27T10:00:00Z',
          'prioridad': 4,
          'confianza': 60,
        };

    test('entrar: contraseña, rol confirmado en el servidor y lista con el token del usuario', () async {
      final s = servidorCon((r) async {
        if (r.url.path == '/auth/v1/token') {
          expect(r.url.queryParameters['grant_type'], 'password');
          expect(jsonDecode(r.body), {'email': 'ana@cra.gov.co', 'password': 'clave'});
          return json({'access_token': 'TOK', 'refresh_token': 'REF', 'expires_in': 3600});
        }
        if (r.url.path.endsWith('/rpc/mi_rol')) return json('moderador_cra');
        if (r.url.path == '/rest/v1/reportes') return json([fila('1', 'recibido')]);
        return http.Response('?', 404);
      });
      final c = ControladorAdmin(servidor: s, reloj: () => _ahora, cada: Duration.zero, avisoNavegador: _NavegadorFalso());
      addTearDown(c.dispose);
      await c.entrar('ana@cra.gov.co', 'clave');
      await _esperarCarga(c);
      expect(c.rol, 'moderador_cra');
      expect(c.demostracion, isFalse);
      expect(c.reportes.single.id, '1');
      final lista = peticiones.lastWhere((r) => r.url.path == '/rest/v1/reportes');
      expect(lista.headers['Authorization'], 'Bearer TOK');
      expect(lista.headers['apikey'], 'anon');
      // Nunca se pide el reportante.
      expect(lista.url.toString(), isNot(contains('reportante')));
      c.salir();
    });

    test('contraseña incorrecta y cuenta sin rol dan mensajes claros', () async {
      final mal = servidorCon((r) async => json({'error_description': 'Invalid login credentials'}, 400));
      final c1 = ControladorAdmin(servidor: mal, reloj: () => _ahora, cada: Duration.zero, avisoNavegador: _NavegadorFalso());
      addTearDown(c1.dispose);
      await expectLater(c1.entrar('a@b.co', 'x'), throwsA(isA<ErrorPanel>().having((e) => e.mensaje, 'm', contains('incorrectos'))));
      expect(c1.fase, FaseAdmin.fuera);
      expect(c1.error, contains('incorrectos'));

      final sinRol = servidorCon((r) async {
        if (r.url.path == '/auth/v1/token') return json({'access_token': 'T', 'refresh_token': 'R', 'expires_in': 3600});
        return json(null);
      });
      final c2 = ControladorAdmin(servidor: sinRol, reloj: () => _ahora, cada: Duration.zero, avisoNavegador: _NavegadorFalso());
      addTearDown(c2.dispose);
      await expectLater(c2.entrar('a@b.co', 'x'), throwsA(isA<ErrorPanel>().having((e) => e.mensaje, 'm', contains('permiso'))));
      expect(c2.dentro, isFalse);
    });

    test('aprobar usa panel_aprobar; si no está cargada, avanza de un estado a la vez con cambiar_estado', () async {
      final sesion = SesionAdmin(token: 'T', refresco: 'R', vence: _ahora.add(const Duration(hours: 1)), correo: 'a@b.co');
      final s = servidorCon((r) async {
        if (r.url.path.endsWith('/rpc/panel_aprobar')) {
          return json({'code': 'PGRST202', 'message': 'Could not find the function'}, 404);
        }
        return json({'id': 'x'});
      });
      final repo = RepositorioRemoto(s, sesion);
      final r = ReporteAdmin.fromJson(fila('abc', 'recibido'));
      final nuevo = await repo.aprobar(r);
      expect(nuevo.estado, EstadoReporte.verificado);
      final cambios = [
        for (final p in peticiones)
          if (p.url.path.endsWith('/rpc/cambiar_estado')) (jsonDecode(p.body) as Map)['p_estado']
      ];
      expect(cambios, ['en_verificacion', 'verificado']);
    });

    test('rechazar manda el motivo como nota interna y pública; sin motivo ni sale', () async {
      final sesion = SesionAdmin(token: 'T', refresco: 'R', vence: _ahora.add(const Duration(hours: 1)), correo: 'a@b.co');
      final s = servidorCon((r) async => json({'id': 'x'}));
      final repo = RepositorioRemoto(s, sesion);
      final r = ReporteAdmin.fromJson(fila('abc', 'recibido'));
      await expectLater(repo.rechazar(r, '  '), throwsA(isA<ErrorPanel>()));
      expect(peticiones, isEmpty);
      final n = await repo.rechazar(r, 'Foto repetida');
      expect(n.estado, EstadoReporte.descartado);
      final cuerpo = jsonDecode(peticiones.single.body) as Map;
      expect(cuerpo['p_estado'], 'descartado');
      expect(cuerpo['p_nota'], 'Foto repetida');
      expect(cuerpo['p_nota_publica'], 'Foto repetida');
    });

    test('los errores del servidor se traducen y un 401 saca de la sesión', () async {
      expect(ErrorPanel.deRespuesta(400, jsonEncode({'message': 'descartar_requiere_nota'})).mensaje, contains('motivo'));
      expect(ErrorPanel.deRespuesta(403, jsonEncode({'message': 'transicion_no_permitida: recibido -> cerrado (rol vigia)'})).mensaje,
          contains('rol'));
      final e = ErrorPanel.deRespuesta(401, jsonEncode({'message': 'JWT expired'}));
      expect(e.sinSesion, isTrue);
    });

    test('la foto se pide en dos pasos auditados: url_foto y URL firmada', () async {
      final sesion = SesionAdmin(token: 'T', refresco: 'R', vence: _ahora.add(const Duration(hours: 1)), correo: 'a@b.co');
      final s = servidorCon((r) async {
        if (r.url.path.endsWith('/rpc/url_foto')) return json({'objeto': 'abc.jpg', 'ruta': 'evidencias/abc.jpg'});
        if (r.method == 'POST' && r.url.path.contains('/object/sign/evidencias/abc.jpg')) return json({'signedURL': '/object/sign/evidencias/abc.jpg?token=zz'});
        if (r.url.path.contains('/storage/v1/object/sign/evidencias/abc.jpg') && r.method == 'GET') {
          return http.Response.bytes([1, 2, 3], 200);
        }
        return http.Response('?', 404);
      });
      final repo = RepositorioRemoto(s, sesion);
      final bytes = await repo.foto(ReporteAdmin.fromJson({...fila('abc', 'recibido'), 'foto_url': 'evidencias/abc.jpg'}));
      expect(bytes, [1, 2, 3]);
      expect(peticiones.map((p) => p.url.path).first, endsWith('/rpc/url_foto'));
      expect(await repo.foto(ReporteAdmin.fromJson(fila('sinfoto', 'recibido'))), isNull);
    });

    test('al vencer el token se renueva antes de consultar', () async {
      var renovado = false;
      final s = servidorCon((r) async {
        if (r.url.path == '/auth/v1/token') {
          if (r.url.queryParameters['grant_type'] == 'refresh_token') renovado = true;
          return json({'access_token': 'NUEVO', 'refresh_token': 'R2', 'expires_in': 3600});
        }
        if (r.url.path.endsWith('/rpc/mi_rol')) return json('admin');
        return json([]);
      });
      var hora = _ahora;
      final c = ControladorAdmin(servidor: s, reloj: () => hora, cada: Duration.zero, avisoNavegador: _NavegadorFalso());
      addTearDown(c.dispose);
      await c.entrar('a@b.co', 'x');
      await _esperarCarga(c);
      hora = _ahora.add(const Duration(minutes: 59));
      await c.actualizar();
      expect(renovado, isTrue);
      expect(peticiones.last.headers['Authorization'], 'Bearer NUEVO');
      c.salir();
    });
  });
}
