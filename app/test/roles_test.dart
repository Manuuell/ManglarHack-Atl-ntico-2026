// La lógica de secciones, sin pantallas: ya no hay rol ciudadano que cambie lo que se ve; el
// perfil viejo se sigue leyendo, Inicio y Guardián son iguales para todos y «¿Qué hago ya?»
// depende solo del momento y de los reportes.
import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/datos/experiencia/jornada.dart';
import 'package:zanky/datos/guardian.dart';
import 'package:zanky/datos/resumen_reportes.dart';
import 'package:zanky/datos/reporte.dart';
import 'package:zanky/datos/roles.dart';
import 'package:zanky/datos/tipos.dart';
import 'package:zanky/vistas/inicio/secciones_rol.dart';

import 'apoyo_datos.dart';

Jornada _jornada(String id, DateTime inicio, {Duration dura = const Duration(hours: 3)}) => Jornada(
      id: id,
      accionId: 'a',
      titulo: 'Jornada $id',
      tipo: 'siembra',
      inicio: inicio,
      fin: inicio.add(dura),
      puntoEncuentro: 'Entrada',
      lat: 11,
      lon: -74.8,
      cupos: 10,
      inscritos: 4,
      queLlevar: const [],
      descripcion: '',
    );

void main() {
  group('RolUsuario', () {
    test('un id desconocido o ausente vale ciudadano', () {
      expect(RolUsuario.deId(null), RolUsuario.ciudadano);
      expect(RolUsuario.deId('capitan'), RolUsuario.ciudadano);
      expect(RolUsuario.deId('estudiante'), RolUsuario.estudiante);
    });

    test('cada rol se reconoce por su propio id y los ids no se repiten', () {
      for (final r in RolUsuario.values) {
        expect(RolUsuario.deId(r.id), r);
      }
      expect({for (final r in RolUsuario.values) r.id}.length, RolUsuario.values.length);
    });

    test('el perfil guarda el rol y uno viejo sin rol sigue siendo ciudadano', () {
      final p = Perfil(id: 'abc', creado: DateTime(2026, 11, 1), rol: RolUsuario.organizador);
      final vuelta = Perfil.fromJson(p.toJson());
      expect(vuelta.rol, RolUsuario.organizador);
      final viejo = p.toJson()..remove('rol');
      expect(Perfil.fromJson(viejo).rol, RolUsuario.ciudadano);
    });

    test('los roles del servidor tienen etiqueta y un rol ciudadano no es del servidor', () {
      for (final r in RolPanel.todos) {
        expect(RolPanel.esConocido(r), isTrue);
        expect(RolPanel.etiqueta(r), isNot('Equipo'));
      }
      expect(RolPanel.esConocido(null), isFalse);
      expect(RolPanel.esConocido('estudiante'), isFalse);
    });
  });

  group('Secciones de Inicio', () {
    test('todos ven lo mismo: empieza por «¿Qué hago ya?» y el héroe de reportar, sin repetir', () {
      final s = seccionesDeInicio();
      expect(s.first, SeccionInicio.queHagoYa);
      expect(s[1], SeccionInicio.reportar);
      expect(s.toSet().length, s.length);
      expect(s, isNot(contains(SeccionInicio.panel)));
    });

    test('lo ciudadano está todo: ver, no hacer, jornadas, evento, reto, ranking, progreso, clima', () {
      expect(seccionesDeInicio(), containsAll([
        SeccionInicio.queVer, SeccionInicio.queNoHacer, SeccionInicio.jornadasCerca, SeccionInicio.evento,
        SeccionInicio.retoManglar, SeccionInicio.rankingColegio, SeccionInicio.progreso, SeccionInicio.clima,
        SeccionInicio.pronostico, SeccionInicio.sensores, SeccionInicio.estadoReportes, SeccionInicio.mision,
      ]));
    });

    test('un solo llamado a reportar: el reporte rápido no sale suelto (va dentro del héroe)', () {
      expect(seccionesDeInicio(), isNot(contains(SeccionInicio.reporteRapido)));
    });

    test('las herramientas de quien organiza no salen en Inicio (van en Gestión)', () {
      final s = seccionesDeInicio(rolPanel: 'admin');
      for (final x in [SeccionInicio.misJornadas, SeccionInicio.qrEvento, SeccionInicio.asistentes]) {
        expect(s, isNot(contains(x)));
      }
    });

    test('orden por bloques: actuar, lo tuyo, el manglar hoy (con hueco para Comunidad), participar', () {
      final s = seccionesDeInicio();
      expect(s.sublist(0, 5), [
        SeccionInicio.queHagoYa,
        SeccionInicio.reportar,
        SeccionInicio.progreso,
        SeccionInicio.estadoReportes,
        SeccionInicio.mision,
      ]);
      expect(s.indexOf(SeccionInicio.pronostico), s.indexOf(SeccionInicio.sensores) + 1);
      // «Comunidad» entra entre el clima y las jornadas: deben quedar seguidas.
      expect(s.indexOf(SeccionInicio.jornadasCerca), s.indexOf(SeccionInicio.clima) + 1);
      expect(s.last, SeccionInicio.sabiasQue);
    });

    test('con sesión del equipo que modera, la bandeja del panel va primero', () {
      for (final panel in RolPanel.todos) {
        expect(seccionesDeInicio(rolPanel: panel).first, SeccionInicio.panel);
      }
      expect(seccionesDeInicio(rolPanel: 'otro'), isNot(contains(SeccionInicio.panel)));
    });
  });

  group('¿Qué hago ya?', () {
    AccionYa cual({int hora = 10, String? panel, int sinVer = 0, int porEnviar = 0, int rechazados = 0, bool enLinea = true, int enviados = 3, bool colegio = true, bool evento = false}) =>
        queHagoYa(ContextoYa(
          hora: hora,
          rolPanel: panel,
          sinVerPanel: sinVer,
          porEnviar: porEnviar,
          rechazados: rechazados,
          enLinea: enLinea,
          enviados: enviados,
          tieneColegio: colegio,
          eventoAbierto: evento,
        ));

    test('lo del equipo gana a todo: reportes por revisar llevan al panel', () {
      final a = cual(panel: 'vigia', sinVer: 3, porEnviar: 2, rechazados: 1);
      expect(a.destino, DestinoYa.panel);
      expect(a.tono, TonoYa.urgente);
      expect(a.titulo, '3 reportes nuevos por revisar');
      expect(cual(panel: 'admin', sinVer: 1).titulo, '1 reporte nuevo por revisar');
    });

    test('con sesión del equipo pero sin nada nuevo, sigue lo de todos', () {
      expect(cual(panel: 'admin', sinVer: 0, evento: true).destino, DestinoYa.evento);
    });

    test('un reporte rechazado va antes que uno que espera señal', () {
      final a = cual(rechazados: 2, porEnviar: 1);
      expect(a.destino, DestinoYa.misReportes);
      expect(a.tono, TonoYa.urgente);
      expect(a.titulo, '2 reportes rechazados');
    });

    test('sin señal lo guardado se explica; con señal se dice que ya sale', () {
      final sin = cual(porEnviar: 1, enLinea: false);
      expect(sin.clave, 'sin_senal');
      expect(sin.titulo, '1 reporte espera señal');
      final con = cual(porEnviar: 2);
      expect(con.clave, 'enviando');
      expect(con.tono, TonoYa.suave);
    });

    test('jornada abierta, luego primer reporte, noche, madrugada, colegio y mapa', () {
      expect(cual(evento: true, enviados: 0).clave, 'evento_abierto');
      expect(cual(enviados: 0).clave, 'primero');
      expect(cual(hora: 20).clave, 'noche');
      expect(cual(hora: 3).clave, 'noche');
      expect(cual(hora: 6).clave, 'madrugada');
      expect(cual(colegio: false, enviados: 1).destino, DestinoYa.perfil);
      expect(cual(hora: 12).clave, 'mapa');
    });

    test('toda combinación da una acción completa (sin textos vacíos)', () {
      for (final hora in [0, 6, 12, 18, 23]) {
        for (final panel in [null, 'moderador_cra']) {
          for (final n in [0, 1]) {
            final a = cual(hora: hora, panel: panel, sinVer: n, porEnviar: n, rechazados: n, enviados: n, colegio: n == 1, evento: n == 1);
            expect(a.titulo, isNotEmpty);
            expect(a.detalle, isNotEmpty);
            expect(a.boton, isNotEmpty);
            expect(a.clave, isNotEmpty);
          }
        }
      }
    });
  });

  group('Secciones de Guardián', () {
    test('sin rol que elegir: la tarjeta primero y nunca la sección «TU ROL»', () {
      for (final g in [true, false]) {
        final s = seccionesDeGuardian(conGestion: g);
        expect(s.first, SeccionGuardian.tarjeta);
        expect(s, isNot(contains(SeccionGuardian.rol)));
        expect(s.toSet().length, s.length);
        expect(s, contains(SeccionGuardian.colegios));
      }
    });

    test('«Gestión» solo con una cuenta del equipo, justo bajo la tarjeta', () {
      expect(seccionesDeGuardian(), isNot(contains(SeccionGuardian.panel)));
      expect(seccionesDeGuardian(conGestion: true)[1], SeccionGuardian.panel);
    });
  });

  group('Resumen de reportes', () {
    test('cada reporte cae en una sola casilla y la suma cierra', () {
      final lista = [
        reporteDePrueba(idDePrueba(1), envio: Envio.enCola),
        reporteDePrueba(idDePrueba(2), envio: Envio.error),
        reporteDePrueba(idDePrueba(3), envio: Envio.enviado),
        reporteDePrueba(idDePrueba(4), envio: Envio.enviado, estado: EstadoReporte.enVerificacion),
        reporteDePrueba(idDePrueba(5), envio: Envio.enviado, estado: EstadoReporte.verificado),
        reporteDePrueba(idDePrueba(6), envio: Envio.enviado, estado: EstadoReporte.cerrado),
        reporteDePrueba(idDePrueba(7), envio: Envio.enviado, estado: EstadoReporte.descartado),
        reporteDePrueba(idDePrueba(8), envio: Envio.rechazado),
      ];
      final r = ResumenReportes.de(lista);
      expect(r.enTelefono, 2);
      expect(r.enRevision, 2);
      expect(r.validados, 2);
      expect(r.descartados, 1);
      expect(r.rechazados, 1);
      expect(r.total, lista.length);
      expect(ResumenReportes.de(const []).vacio, isTrue);
    });
  });

  group('Jornadas próximas y carné', () {
    test('solo las que no terminaron, la más cercana primero', () {
      final ahora = DateTime(2026, 11, 27, 12);
      final lista = [
        _jornada('lejos', DateTime(2026, 12, 20, 7)),
        _jornada('pasada', DateTime(2026, 11, 1, 7)),
        _jornada('en_curso', DateTime(2026, 11, 27, 10)),
        _jornada('cerca', DateTime(2026, 11, 29, 7)),
      ];
      expect([for (final j in proximasJornadas(lista, ahora)) j.id], ['en_curso', 'cerca', 'lejos']);
      expect(proximasJornadas(const [], ahora), isEmpty);
    });

    test('iniciales del carné', () {
      expect(inicialesDe('Ana Pérez'), 'AP');
      expect(inicialesDe('  maría fernanda de los Ángeles  '), 'MF');
      expect(inicialesDe('Zanky'), 'Z');
      expect(inicialesDe('   '), '');
    });
  });
}
