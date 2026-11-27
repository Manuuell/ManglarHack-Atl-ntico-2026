// La lógica de roles y secciones, sin pantallas: qué rol se guarda, en qué orden sale cada
// sección y qué sugiere «¿Qué hago ya?» según el rol y el momento.
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

    test('los roles del servidor tienen etiqueta y solo los cuatro del panel se conocen', () {
      for (final r in RolPanel.todos) {
        expect(RolPanel.esConocido(r), isTrue);
        expect(RolPanel.etiqueta(r), isNot('Equipo'));
      }
      expect(RolPanel.esConocido(null), isFalse);
      expect(RolPanel.esConocido('estudiante'), isFalse);
    });
  });

  group('Secciones de Inicio', () {
    test('cada rol empieza por «¿Qué hago ya?» y no repite secciones', () {
      for (final r in RolUsuario.values) {
        final s = seccionesDeInicio(r);
        expect(s.first, SeccionInicio.queHagoYa, reason: r.id);
        expect(s.toSet().length, s.length, reason: r.id);
        expect(s, isNot(contains(SeccionInicio.panel)), reason: r.id);
      }
    });

    test('con sesión del equipo la bandeja del panel va primero, sea cual sea el rol elegido', () {
      for (final rol in RolUsuario.values) {
        for (final panel in RolPanel.todos) {
          expect(seccionesDeInicio(rol, rolPanel: panel).first, SeccionInicio.panel);
        }
      }
      expect(seccionesDeInicio(RolUsuario.turista, rolPanel: 'otro'), isNot(contains(SeccionInicio.panel)));
    });

    test('el estudiante ve el reto y el ranking de su colegio antes que reportar', () {
      final s = seccionesDeInicio(RolUsuario.estudiante);
      expect(s.indexOf(SeccionInicio.retoManglar), lessThan(s.indexOf(SeccionInicio.reportar)));
      expect(s.indexOf(SeccionInicio.rankingColegio), lessThan(s.indexOf(SeccionInicio.reportar)));
      expect(s, contains(SeccionInicio.mision));
    });

    test('el visitante ve qué ver, qué no hacer y jornadas; no ve ranking ni progreso', () {
      final s = seccionesDeInicio(RolUsuario.turista);
      expect(s, containsAll([SeccionInicio.queVer, SeccionInicio.queNoHacer, SeccionInicio.jornadasCerca]));
      expect(s, isNot(contains(SeccionInicio.rankingColegio)));
      expect(s, isNot(contains(SeccionInicio.progreso)));
      expect(s, contains(SeccionInicio.reporteRapido));
    });

    test('el organizador ve sus jornadas, el QR y los asistentes arriba', () {
      final s = seccionesDeInicio(RolUsuario.organizador);
      expect(s.sublist(2, 5), [SeccionInicio.misJornadas, SeccionInicio.qrEvento, SeccionInicio.asistentes]);
    });

    test('el pronóstico va arriba para organizador y visitante, y más abajo para los demás', () {
      expect(seccionesDeInicio(RolUsuario.organizador)[1], SeccionInicio.pronostico);
      expect(seccionesDeInicio(RolUsuario.turista)[1], SeccionInicio.pronostico);
      for (final r in [RolUsuario.ciudadano, RolUsuario.estudiante]) {
        final s = seccionesDeInicio(r);
        expect(s.indexOf(SeccionInicio.pronostico), greaterThan(4), reason: r.id);
      }
    });

    test('el ciudadano ve el estado de sus reportes y el clima', () {
      final s = seccionesDeInicio(RolUsuario.ciudadano);
      expect(s, containsAll([SeccionInicio.reportar, SeccionInicio.estadoReportes, SeccionInicio.clima]));
      expect(s.indexOf(SeccionInicio.reportar), lessThan(s.indexOf(SeccionInicio.estadoReportes)));
    });
  });

  group('¿Qué hago ya?', () {
    AccionYa cual(RolUsuario rol, {int hora = 10, String? panel, int sinVer = 0, int porEnviar = 0, int rechazados = 0, bool enLinea = true, int enviados = 3, bool colegio = true, bool evento = false}) =>
        queHagoYa(ContextoYa(
          rol: rol,
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
      final a = cual(RolUsuario.estudiante, panel: 'vigia', sinVer: 3, porEnviar: 2, rechazados: 1);
      expect(a.destino, DestinoYa.panel);
      expect(a.tono, TonoYa.urgente);
      expect(a.titulo, '3 reportes nuevos por revisar');
      expect(cual(RolUsuario.ciudadano, panel: 'admin', sinVer: 1).titulo, '1 reporte nuevo por revisar');
    });

    test('con sesión del equipo pero sin nada nuevo, sigue lo propio del rol', () {
      expect(cual(RolUsuario.organizador, panel: 'admin', sinVer: 0).destino, DestinoYa.evento);
    });

    test('un reporte rechazado va antes que uno que espera señal', () {
      final a = cual(RolUsuario.turista, rechazados: 2, porEnviar: 1);
      expect(a.destino, DestinoYa.misReportes);
      expect(a.tono, TonoYa.urgente);
      expect(a.titulo, '2 reportes rechazados');
    });

    test('sin señal lo guardado se explica; con señal se dice que ya sale', () {
      final sin = cual(RolUsuario.ciudadano, porEnviar: 1, enLinea: false);
      expect(sin.clave, 'sin_senal');
      expect(sin.titulo, '1 reporte espera señal');
      final con = cual(RolUsuario.ciudadano, porEnviar: 2);
      expect(con.clave, 'enviando');
      expect(con.tono, TonoYa.suave);
    });

    test('estudiante: primero el colegio, luego el primer reporte, luego la misión', () {
      expect(cual(RolUsuario.estudiante, colegio: false, enviados: 0).destino, DestinoYa.perfil);
      expect(cual(RolUsuario.estudiante, enviados: 0).clave, 'est_primero');
      expect(cual(RolUsuario.estudiante, enviados: 2).clave, 'est_mision');
    });

    test('visitante: de día a reportar con cuidado, de noche a planear con el mapa', () {
      expect(cual(RolUsuario.turista, hora: 9).destino, DestinoYa.reportar);
      expect(cual(RolUsuario.turista, hora: 18).destino, DestinoYa.mapa);
      expect(cual(RolUsuario.turista, hora: 3).destino, DestinoYa.mapa);
      expect(cual(RolUsuario.turista, hora: 17).destino, DestinoYa.reportar);
    });

    test('organizador: abre el evento, y dice si ya hay uno abierto', () {
      expect(cual(RolUsuario.organizador).clave, 'org_preparar');
      expect(cual(RolUsuario.organizador, evento: true).clave, 'org_abierto');
    });

    test('ciudadano: primer reporte, madrugada o el mapa', () {
      expect(cual(RolUsuario.ciudadano, enviados: 0).clave, 'ciu_primero');
      expect(cual(RolUsuario.ciudadano, hora: 5).clave, 'ciu_madrugada');
      expect(cual(RolUsuario.ciudadano, hora: 6).clave, 'ciu_madrugada');
      expect(cual(RolUsuario.ciudadano, hora: 7).clave, 'ciu_mapa');
    });

    test('toda combinación da una acción completa (sin textos vacíos)', () {
      for (final rol in RolUsuario.values) {
        for (final hora in [0, 6, 12, 18, 23]) {
          for (final panel in [null, 'moderador_cra']) {
            for (final n in [0, 1]) {
              final a = cual(rol, hora: hora, panel: panel, sinVer: n, porEnviar: n, rechazados: n, enviados: n, colegio: n == 1);
              expect(a.titulo, isNotEmpty);
              expect(a.detalle, isNotEmpty);
              expect(a.boton, isNotEmpty);
              expect(a.clave, isNotEmpty);
            }
          }
        }
      }
    });
  });

  group('Secciones de Guardián', () {
    test('la tarjeta va primero, el rol justo debajo y el panel al final', () {
      for (final r in RolUsuario.values) {
        final s = seccionesDeGuardian(r);
        expect(s.first, SeccionGuardian.tarjeta);
        expect(s[1], SeccionGuardian.rol);
        expect(s.last, SeccionGuardian.panel);
        expect(s.toSet().length, s.length);
      }
    });

    test('sin perfil no hay rol que cambiar', () {
      expect(seccionesDeGuardian(RolUsuario.ciudadano, conPerfil: false), isNot(contains(SeccionGuardian.rol)));
    });

    test('el estudiante ve su colegio justo después de la tarjeta; el visitante no ve colegios', () {
      expect(seccionesDeGuardian(RolUsuario.estudiante)[2], SeccionGuardian.colegios);
      expect(seccionesDeGuardian(RolUsuario.turista), isNot(contains(SeccionGuardian.colegios)));
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
