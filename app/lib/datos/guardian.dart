import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import 'reporte.dart';
import 'tipos.dart';

/// El perfil del ciudadano, guardado solo en su teléfono.
///
/// La cédula es opcional y NUNCA se guarda en claro: solo su huella (SHA-256 con sal
/// de la app), que sirve para que el servidor reconozca a la misma persona en la app y
/// en WhatsApp sin conocer su número de documento (Ley 1581).
class Perfil {
  Perfil({
    required this.id,
    this.nombre = '',
    this.colegio = '',
    this.cedulaHash,
    this.anonimoPorDefecto = false,
    this.consentimiento,
    required this.creado,
  });

  /// Id del guardián (UUID). Va en la tarjeta y en el QR; no revela a la persona.
  final String id;
  String nombre;
  String colegio;
  String? cedulaHash;
  bool anonimoPorDefecto;

  /// Cuándo aceptó el aviso de privacidad. Sin esto no se envía nada.
  DateTime? consentimiento;
  final DateTime creado;

  String get codigo => 'GM-${id.replaceAll('-', '').substring(0, 6).toUpperCase()}';
  String get nombreVisible => nombre.trim().isEmpty ? 'Guardián del manglar' : nombre.trim();

  static String huellaCedula(String cedula) {
    final limpia = cedula.replaceAll(RegExp(r'\D'), '');
    return sha256.convert(utf8.encode('zanqui-guardian:$limpia')).toString();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'colegio': colegio,
        'cedula_hash': cedulaHash,
        'anonimo': anonimoPorDefecto,
        'consentimiento': consentimiento?.toIso8601String(),
        'creado': creado.toIso8601String(),
      };

  static Perfil fromJson(Map<String, dynamic> j) => Perfil(
        id: j['id'] as String,
        nombre: j['nombre'] as String? ?? '',
        colegio: j['colegio'] as String? ?? '',
        cedulaHash: j['cedula_hash'] as String?,
        anonimoPorDefecto: j['anonimo'] as bool? ?? false,
        consentimiento: j['consentimiento'] == null ? null : DateTime.parse(j['consentimiento'] as String),
        creado: DateTime.parse(j['creado'] as String),
      );
}

/// Los niveles siguen la vida del mangle rojo: del propágulo que flota en la ciénaga
/// al árbol que sostiene la costa. Se sube SOLO con reportes validados, nunca por la
/// cantidad: así el spam no da puntos (pregunta 3 del reto).
class Nivel {
  const Nivel(this.numero, this.nombre, this.desde, this.lema);
  final int numero;
  final String nombre;
  final int desde;
  final String lema;

  static const todos = [
    Nivel(1, 'Propágulo', 0, 'Acabas de caer al agua. Todo guardián empezó así.'),
    Nivel(2, 'Plántula', 60, 'Echaste raíz: ya sabes qué mirar en el manglar.'),
    Nivel(3, 'Mangle joven', 180, 'Tus reportes ya ayudaron a la CRA a actuar.'),
    Nivel(4, 'Raíz de zanco', 400, 'Como Zanqui: firme sobre el agua y el fango.'),
    Nivel(5, 'Mangle rojo', 800, 'Tu ciénaga sabe que estás pendiente.'),
    Nivel(6, 'Guardián del manglar', 1500, 'Eres de los que sostienen la costa.'),
  ];

  static Nivel de(int puntos) => todos.lastWhere((n) => puntos >= n.desde);
  Nivel? get siguiente => numero < todos.length ? todos[numero] : null;
}

class Insignia {
  const Insignia(this.id, this.nombre, this.como, this.icono, this.color);
  final String id;
  final String nombre;
  final String como;
  final IconData icono;
  final Color color;

  static const todas = [
    Insignia('primer_aviso', 'Primer aviso', 'Envía tu primer reporte.', Icons.campaign_rounded, Color(0xFF2E9E6A)),
    Insignia('ojo_de_garza', 'Ojo de garza', 'Tres reportes verificados por la CRA.', Icons.visibility_rounded,
        Color(0xFF1F7A8C)),
    Insignia('sin_senal', 'Sin señal, sin excusa', 'Reporta sin internet: Zanqui lo envía después.',
        Icons.signal_cellular_off_rounded, Color(0xFF55655F)),
    Insignia('centinela_fuego', 'Centinela del fuego', 'Un reporte de quema verificado.',
        Icons.local_fire_department_rounded, Color(0xFFD13B3B)),
    Insignia('guardian_cano', 'Guardián del caño', 'Un caño taponado verificado.', Icons.waves_rounded,
        Color(0xFF1F7A8C)),
    Insignia('madrugador', 'Madrugador', 'Reporta antes de las 7 de la mañana, como los pescadores.',
        Icons.wb_twilight_rounded, Color(0xFFF2A33A)),
    Insignia('expediente', 'Abriste un expediente', 'Un reporte tuyo se volvió alerta oficial.',
        Icons.gavel_rounded, Color(0xFF6A4FA3)),
    Insignia('cuatro_zonas', 'Las cuatro ciénagas', 'Reporta en las cuatro zonas de manglar del Atlántico.',
        Icons.map_rounded, Color(0xFF8A5A2B)),
  ];
}

/// Puntos e insignias calculados desde los reportes del teléfono y su estado en el
/// servidor. No hay puntos guardados aparte que se puedan inflar.
class Progreso {
  Progreso._(this.puntos, this.pendientes, this.insignias, this.enviados, this.validados);

  /// Puntos de reportes validados por una persona (cuentan para el nivel).
  final int puntos;

  /// Puntos que llegarán si la CRA valida lo que está en revisión.
  final int pendientes;
  final Set<String> insignias;
  final int enviados;
  final int validados;

  Nivel get nivel => Nivel.de(puntos);

  double get avanceNivel {
    final s = nivel.siguiente;
    if (s == null) return 1;
    return ((puntos - nivel.desde) / (s.desde - nivel.desde)).clamp(0.0, 1.0);
  }

  static int puntosDe(Reporte r) {
    var p = 50 + (r.fotoDeCamara ? 10 : 0) + (r.prioridad >= 4 ? 10 : 0);
    if (r.estado == EstadoReporte.alertaOficial ||
        r.estado == EstadoReporte.enAtencion ||
        r.estado == EstadoReporte.cerrado) {
      p += 30;
    }
    return p;
  }

  static Progreso de(List<Reporte> reportes) {
    var puntos = 0, pendientes = 0, enviados = 0, validados = 0;
    final ins = <String>{};
    final zonas = <String>{};
    for (final r in reportes) {
      final llego = r.envio == Envio.enviado;
      if (llego) {
        enviados++;
        ins.add('primer_aviso');
        if (r.capturadoSinSenal) ins.add('sin_senal');
        if (r.capturadoEn.hour < 7) ins.add('madrugador');
        zonas.add(r.zonaId);
      }
      if (r.estado.validado) {
        validados++;
        puntos += puntosDe(r);
        if (r.tipo == TipoAmenaza.quema) ins.add('centinela_fuego');
        if (r.tipo == TipoAmenaza.canoTaponado) ins.add('guardian_cano');
        if (r.estado != EstadoReporte.verificado) ins.add('expediente');
      } else if (llego && r.estado != EstadoReporte.descartado) {
        pendientes += puntosDe(r);
      }
    }
    if (validados >= 3) ins.add('ojo_de_garza');
    if (zonas.length >= 4) ins.add('cuatro_zonas');
    return Progreso._(puntos, pendientes, ins, enviados, validados);
  }
}

/// Misiones de la semana: dan un motivo para volver al manglar (colegios, PRAE,
/// servicio social). Rotan cada semana del año.
class Mision {
  const Mision(this.titulo, this.detalle, this.icono);
  final String titulo;
  final String detalle;
  final IconData icono;

  static const _todas = [
    Mision('Recorre el borde de Mallorquín', 'Camina el sendero del Ecoparque y reporta lo que encuentres en las raíces.',
        Icons.directions_walk_rounded),
    Mision('El caño que alimenta la ciénaga', 'Busca un caño cerca de ti: ¿corre el agua o está tapado?',
        Icons.waves_rounded),
    Mision('Cero plástico en las raíces', 'Fotografía un punto con basura enredada. Con tu reporte se arma la próxima limpieza.',
        Icons.recycling_rounded),
    Mision('Ojos de pescador', 'Sal temprano con un pescador de la asociación y aprende a leer el manglar.',
        Icons.phishing_rounded),
  ];

  static Mision deLaSemana(DateTime hoy) {
    final semana = hoy.difference(DateTime(hoy.year)).inDays ~/ 7;
    return _todas[semana % _todas.length];
  }
}
