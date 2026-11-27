import '../reporte.dart';
import '../tipos.dart';

enum NivelPronostico { bajo, medio, alto }

enum RiesgoManglar { quema, anegamiento, oleaje, vertimiento }

class LecturaDia {
  const LecturaDia({
    required this.fecha,
    this.lluvia24,
    this.lluvia72,
    this.temperaturaMax,
    this.humedadMin,
    this.vientoMax,
    this.olaMax,
    this.diasSecos,
  });

  final DateTime fecha;
  final double? lluvia24,
      lluvia72,
      temperaturaMax,
      humedadMin,
      vientoMax,
      olaMax;
  final int? diasSecos;
}

class AlertaManglar {
  const AlertaManglar(
    this.riesgo,
    this.nivel,
    this.porQue,
    this.queHacer,
    this.fuente, {
    this.reportesRecientes = 0,
  });
  final RiesgoManglar riesgo;
  final NivelPronostico? nivel;
  final String porQue, queHacer, fuente;
  final int reportesRecientes;

  String get nombre => switch (riesgo) {
    RiesgoManglar.quema => 'Quema',
    RiesgoManglar.anegamiento => 'Caño taponado / anegamiento',
    RiesgoManglar.oleaje => 'Oleaje / erosión',
    RiesgoManglar.vertimiento => 'Vertimiento arrastrado',
  };
  String get nivelTexto => nivel?.name ?? 'Sin datos';
}

/// Umbrales orientativos para observación ciudadana; no son alertas oficiales.
List<AlertaManglar> evaluarPronostico(
  LecturaDia d, {
  Iterable<Reporte> reportes = const [],
  required String zonaId,
  required DateTime ahora,
}) {
  final recientes = reportes.where(
    (r) =>
        r.zonaId == zonaId &&
        r.capturadoEn.isAfter(ahora.subtract(const Duration(days: 7))) &&
        !r.capturadoEn.isAfter(ahora) &&
        r.envio != Envio.rechazado &&
        r.estado != EstadoReporte.descartado &&
        r.estado != EstadoReporte.cerrado,
  );

  AlertaManglar alerta(
    RiesgoManglar tipo,
    NivelPronostico? base,
    String motivo,
    String accion,
    String fuente,
    TipoAmenaza? reporteTipo,
  ) {
    final n = recientes.where((r) {
      if (reporteTipo != null) return r.tipo == reporteTipo;
      // La app no tiene un tipo propio para erosión; solo cuenta «Otro» si el
      // texto la menciona expresamente. Es una señal local sin verificar.
      return tipo == RiesgoManglar.oleaje &&
          r.tipo == TipoAmenaza.otro &&
          RegExp(
            r'(^|\W)(erosión|erosion|oleaje|olas?|playa)(\W|$)',
            caseSensitive: false,
            unicode: true,
          ).hasMatch(r.descripcion);
    }).length;
    final nivel = n > 0 && base != null
        ? NivelPronostico.values[(base.index + 1).clamp(0, 2)]
        : base;
    return AlertaManglar(
      tipo,
      nivel,
      '$motivo${n > 0 ? ' $n reporte(s) reciente(s) de esta zona elevan un nivel; no confirman la causa.' : ''}',
      accion,
      fuente,
      reportesRecientes: n,
    );
  }

  final t = d.temperaturaMax,
      h = d.humedadMin,
      v = d.vientoMax,
      s = d.diasSecos;
  NivelPronostico? fuego;
  if (t != null && h != null && v != null && s != null) {
    fuego = t >= 34 && h <= 50 && v >= 25 && s >= 3
        ? NivelPronostico.alto
        : t >= 31 && h <= 65 && v >= 18 && s >= 2
        ? NivelPronostico.medio
        : NivelPronostico.bajo;
  }
  final lluvia = d.lluvia24, acumulada = d.lluvia72;
  NivelPronostico? agua;
  if (lluvia != null && acumulada != null) {
    agua = lluvia >= 40 || acumulada >= 80
        ? NivelPronostico.alto
        : lluvia >= 20 || acumulada >= 40
        ? NivelPronostico.medio
        : NivelPronostico.bajo;
  }
  final ola = d.olaMax;
  final oleaje = ola == null
      ? null
      : ola >= 2
      ? NivelPronostico.alto
      : ola >= 1.5
      ? NivelPronostico.medio
      : NivelPronostico.bajo;
  NivelPronostico? arrastre;
  if (lluvia != null && s != null) {
    arrastre = lluvia >= 30 && s >= 3
        ? NivelPronostico.alto
        : lluvia >= 15 && s >= 2
        ? NivelPronostico.medio
        : NivelPronostico.bajo;
  }

  String numero(double? n, String unidad) =>
      n == null ? 'sin dato' : '${n.toStringAsFixed(1)} $unidad';
  return [
    alerta(
      RiesgoManglar.quema,
      fuego,
      'Máxima ${numero(t, '°C')}, humedad mínima ${numero(h, '%')}, viento máximo ${numero(v, 'km/h')} y ${s ?? 'sin dato'} días secos previos. Los extremos pueden ocurrir a distintas horas. Medio: ≥31 °C, ≤65 %, ≥18 km/h y ≥2 días; alto: ≥34 °C, ≤50 %, ≥25 km/h y ≥3 días.',
      'Evita quemas; si ves humo o fuego, aléjate y repórtalo.',
      'Open-Meteo Forecast: temperatura, humedad, viento y precipitación horaria.',
      TipoAmenaza.quema,
    ),
    alerta(
      RiesgoManglar.anegamiento,
      agua,
      'Lluvia modelada por día: ${numero(lluvia, 'mm')} en 24 h y ${numero(acumulada, 'mm')} en hasta 72 h. Hoy incluye horas ya transcurridas. Medio: ≥20/40 mm; alto: ≥40/80 mm. La lluvia no demuestra que un caño esté taponado.',
      'Observa si el agua deja de correr; reporta obstrucciones sin entrar al caño.',
      'Open-Meteo Forecast: precipitación horaria.',
      TipoAmenaza.canoTaponado,
    ),
    alerta(
      RiesgoManglar.oleaje,
      oleaje,
      'Ola significativa máxima: ${numero(ola, 'm')}. Medio: ≥1,5 m; alto: ≥2 m. La ola no predice por sí sola erosión local.',
      'Mantente lejos de bordes expuestos; documenta cambios visibles desde un lugar seguro.',
      'Open-Meteo Marine: wave_height horaria. Puede faltar cerca de la costa.',
      null,
    ),
    alerta(
      RiesgoManglar.vertimiento,
      arrastre,
      'Lluvia modelada por día: ${numero(lluvia, 'mm')} en 24 h tras ${s ?? 'sin dato'} días secos. Hoy incluye horas ya transcurridas. Medio: ≥15 mm tras ≥2 días; alto: ≥30 mm tras ≥3 días. La lluvia puede arrastrar residuos; no demuestra un vertimiento.',
      'Observa color, olor o espuma sin tocar el agua; repórtalos si aparecen.',
      'Open-Meteo Forecast: precipitación horaria.',
      TipoAmenaza.vertimiento,
    ),
  ];
}
