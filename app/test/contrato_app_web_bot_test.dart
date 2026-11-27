// Contrato entre la app, el bot de WhatsApp (`origin/zanqui-bot` 2b1f7e9, desplegado en zanqui.sentralabs.co)
// y la web pública (`origin/web-portada`). Los fixtures de test/fixtures/contrato/ son respuestas REALES de
// GET públicos del 27-nov-2026 (sin datos personales); si el servidor cambia un nombre o un campo, esto falla.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zanky/datos/comunidad/comunidad.dart';
import 'package:zanky/datos/experiencia/jornada.dart';
import 'package:zanky/datos/tipos.dart';

String _fixture(String nombre) => File('test/fixtures/contrato/$nombre').readAsStringSync();

void main() {
  group('tipos de reporte: los mismos nombres y gravedad que el bot (reportes/modelo.ts)', () {
    // Copia de TIPOS del bot (nombre, corto, gravedad). La web (catalogos.ts) tiene los mismos nombres.
    const bot = {
      'tala': ('Tala o corte de mangle', 'Tala', 5),
      'quema': ('Quema o incendio', 'Quema', 5),
      'relleno': ('Relleno o construcción', 'Relleno', 4),
      'vertimiento': ('Vertimiento o contaminación del agua', 'Vertimiento', 4),
      'cano_taponado': ('Caño taponado o alteración del agua', 'Caño taponado', 4),
      'fauna': ('Fauna afectada', 'Fauna', 4),
      'basuras': ('Basuras o residuos', 'Basuras', 2),
      'otro': ('Otro', 'Otro', 2),
    };

    test('mismos slugs, nombre largo y gravedad', () {
      expect(TipoAmenaza.values.map((t) => t.slug).toSet(), bot.keys.toSet());
      for (final t in TipoAmenaza.values) {
        expect(t.nombre, bot[t.slug]!.$1, reason: t.slug);
        expect(t.gravedad, bot[t.slug]!.$3, reason: t.slug);
      }
    });

    test('el nombre que publica el servidor vuelve al mismo tipo, exacto', () {
      for (final e in bot.entries) {
        expect(tipoDeNombre(e.value.$1).slug, e.key, reason: e.value.$1);
        expect(tipoDeNombre(e.value.$2).slug, e.key, reason: e.value.$2);
      }
    });
  });

  group('estados del reporte: las frases que el bot manda por WhatsApp', () {
    const bot = {
      'recibido': ('Recibido', 'Recibido para revisión.'),
      'en_verificacion': ('En verificación', 'Una persona de la C.R.A. revisa la evidencia.'),
      'verificado': ('Verificado', 'Hallazgo confirmado por una persona.'),
      'alerta_oficial': ('Alerta oficial', 'Alerta emitida con apertura de expediente.'),
      'en_atencion': ('En atención', 'Caso en atención por el equipo.'),
      'cerrado': ('Cerrado', 'Seguimiento finalizado.'),
      'descartado': ('Descartado', 'La evidencia no confirma el reporte.'),
    };

    test('mismos slugs, etiqueta y explicación', () {
      expect(EstadoReporte.values.map((e) => e.slug).toSet(), bot.keys.toSet());
      for (final e in EstadoReporte.values) {
        expect(e.nombre, bot[e.slug]!.$1);
        expect(e.explicacion, bot[e.slug]!.$2);
        expect(estadoDeNombre(e.nombre), e);
      }
    });
  });

  group('GET /datos-abiertos/reportes.geojson (real, 27-nov)', () {
    test('se lee con código ZK-, tipo, prioridad, estado y canal', () {
      final r = reportesDeGeoJson(_fixture('datos_abiertos_27nov.geojson'));
      expect(r, hasLength(2));
      expect(r.every((x) => RegExp(r'^ZK-[0-9A-F]{4}$').hasMatch(x.publico.id)), isTrue);
      final tala = r.firstWhere((x) => x.publico.id == 'ZK-DA17');
      expect(tala.publico.tipo, TipoAmenaza.tala);
      expect(tala.publico.prioridad, 5);
      expect(tala.publico.estado, EstadoReporte.recibido);
      expect(tala.canal, 'whatsapp');
      expect(r.firstWhere((x) => x.publico.id == 'ZK-16D1').publico.tipo, TipoAmenaza.basuras);
    });
  });

  group('GET /api/jornadas (real, 27-nov): sin límite de cupos', () {
    final jornadas = [
      for (final j in (jsonDecode(_fixture('api_jornadas_27nov.json')) as Map)['jornadas'] as List) Jornada.fromJson(j as Map),
    ];

    test('el servidor aún manda «cupos: 60», pero el bot ya no limita: la app tampoco', () {
      expect(jornadas, hasLength(4));
      final basura = jornadas.firstWhere((j) => j.titulo.startsWith('Recolección'));
      expect(basura.inscritos, 1);
      expect(basura.sinLimite, isTrue);
      expect(basura.llena, isFalse);
      expect(basura.cuposLibres, 0);
      expect(basura.textoInscritos, '1 persona inscrita · gratis y sin límite de cupos');
      expect(jornadas.every((j) => j.sinLimite && !j.llena && !j.esEjemplo), isTrue);
    });

    test('cupo nulo o 0 = sin límite; solo `limite_cupos: true` limita', () {
      final base = jornadas.first.aJson();
      expect(Jornada.fromJson({...base, 'cupos': null}).sinLimite, isTrue);
      expect(Jornada.fromJson({...base, 'cupos': 0}).sinLimite, isTrue);
      final conLimite = Jornada.fromJson({...base, 'cupos': 2, 'inscritos': 2, 'limite_cupos': true});
      expect(conLimite.sinLimite, isFalse);
      expect(conLimite.llena, isTrue);
      // La caché local guarda la marca y vuelve igual.
      expect(Jornada.fromJson(conLimite.aJson()).llena, isTrue);
      expect(Jornada.fromJson({...base, 'inscritos': 0}).textoInscritos,
          'Sé de las primeras personas en inscribirte · gratis y sin límite de cupos');
    });
  });

  group('GET /api/propuestas (propuestas hechas por WhatsApp)', () {
    test('la respuesta real de hoy viene vacía y se lee sin error', () {
      expect(propuestasDeTexto(_fixture('api_propuestas_27nov.json')), isEmpty);
    });

    test('una propuesta con la forma de almacenPropuestas.ts se lee igual que la web', () {
      // Forma de `propuestasPublicas()` del bot; los valores son de prueba.
      final texto = jsonEncode({
        'propuestas': [
          {
            'id': '1a2b3c4d-0000-4000-8000-000000000000',
            'codigo': 'PROP-1A2B',
            'canal': 'whatsapp',
            'tipo': 'siembra',
            'tipo_accion': 'siembra',
            'proponente': 'cra',
            'tipo_actor': 'entidad_publica',
            'descripcion': ' Sembrar 200 plántulas en el caño ',
            'lat': 11.03,
            'lon': -74.86,
            'zona': 'mallorquin',
            'zona_nombre': 'Ciénaga de Mallorquín',
            'dentro_poligono': true,
            'distancia_m': 0,
            'estado': 'propuesta',
            'creada_en': '2026-11-27T20:00:00.000Z',
          },
          {'id': 'x', 'codigo': 'ZK-0000', 'canal': 'whatsapp', 'estado': 'propuesta'}, // no cumple: se descarta
        ],
      });
      final p = propuestasDeTexto(texto).single;
      expect(p.codigo, 'PROP-1A2B');
      expect(p.titulo, 'Siembra propuesta por WhatsApp · PROP-1A2B');
      expect(p.proponenteNombre, 'C.R.A.');
      expect(p.descripcion, 'Sembrar 200 plántulas en el caño');
      expect(p.dentroManglar, isTrue);
      expect(p.emoji, '🌱');
    });

    test('FuenteComunidad.propuestas pide /api/propuestas al servidor del bot', () async {
      Uri? pedida;
      final f = FuenteComunidad(cliente: MockClient((req) async {
        pedida = req.url;
        return http.Response.bytes(utf8.encode(_fixture('api_propuestas_27nov.json')), 200);
      }));
      final l = await f.propuestas();
      expect(pedida.toString(), 'https://zanqui.sentralabs.co/api/propuestas');
      expect(l.origen, OrigenDato.red);
      expect(l.datos, isEmpty);
    });
  });

  group('GET /alertas?simulacro=1 (real, 27-nov)', () {
    test('mismos campos que /alertas, marcado simulacro y con nivel roja', () {
      final r = ResultadoAlertas.deTexto(_fixture('alertas_simulacro_27nov.json'));
      expect(r.simulacro, isTrue);
      expect(r.nivelMaximo, NivelAlerta.roja);
      expect(r.alertas, isNotEmpty);
      expect(r.nota, contains('no reemplazan los avisos oficiales'));
      // En simulacro se ven todas (vienen rotuladas «SIMULACRO»), también la de la comunidad.
      expect(r.publicadas, hasLength(4));
      expect(r.publicadas.every((a) => a.titulo.startsWith('SIMULACRO')), isTrue);
    });

    test('fuera de simulacro, la regla de la portada: sin amenaza_ciudadana y máximo 6', () {
      final r = ResultadoAlertas.deTexto(jsonEncode({
        'alertas': [
          for (var i = 0; i < 9; i++)
            {
              'id': 'a$i',
              'tipo': i.isEven ? 'mar_de_leva' : 'amenaza_ciudadana',
              'nivel': 'amarilla',
              'titulo': 'Alerta $i',
              'lugar': 'Lugar $i',
              'desde': DateTime.utc(2026, 11, 27, i).toIso8601String(),
            },
          for (var i = 0; i < 4; i++)
            {'id': 'b$i', 'tipo': 'riesgo_incendio', 'nivel': 'naranja', 'titulo': 'Fuego $i', 'lugar': 'Otro $i', 'desde': '2026-11-26T00:00:00Z'},
        ],
      }));
      expect(r.publicadas.any((a) => a.tipo == 'amenaza_ciudadana'), isFalse);
      expect(r.porLugar, hasLength(6));
      // Las 6 más recientes: las 5 de mar de leva (27-nov) y una de las de fuego (26-nov).
      expect(r.porLugar.where((g) => g.$1.tipo == 'mar_de_leva'), hasLength(5));
    });

    test('la fuente de la Corporación se escribe «C.R.A.», como la web', () {
      expect(nombreFuente['cra'], 'C.R.A.');
    });
  });
}
