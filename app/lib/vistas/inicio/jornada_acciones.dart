import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../datos/experiencia/entrada_evento.dart' hide EntradaEvento;
import '../../datos/experiencia/jornada.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/kit/accion_gesto.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/tema.dart';

/// Lo que se comparte de una jornada: qué, cuándo, dónde y el enlace que entra al evento.
String textoJornada(Jornada j) => 'Te invito a una jornada del manglar con Zanky.\n'
    '${j.titulo}\n'
    '${fechaLarga(j.inicio)} · ${horaCorta(j.inicio)}\n'
    'Punto de encuentro: ${j.puntoEncuentro}\n'
    '${enlaceEvento(j.id)}';

String _ics(DateTime d) {
  final u = d.toUtc();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${u.year}${dos(u.month)}${dos(u.day)}T${dos(u.hour)}${dos(u.minute)}${dos(u.second)}Z';
}

String _escapar(String t) => t.replaceAll('\\', '\\\\').replaceAll(';', '\\;').replaceAll(',', '\\,').replaceAll('\n', '\\n');

/// Un evento de calendario (.ics) de la jornada: lo abre cualquier app de calendario.
String icsJornada(Jornada j) => [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Zanky//Jornadas//ES',
      'BEGIN:VEVENT',
      'UID:${j.id}@zanky',
      'DTSTAMP:${_ics(DateTime.now())}',
      'DTSTART:${_ics(j.inicio)}',
      'DTEND:${_ics(j.fin)}',
      'SUMMARY:${_escapar(j.titulo)}',
      'LOCATION:${_escapar(j.puntoEncuentro)}',
      'DESCRIPTION:${_escapar(enlaceEvento(j.id))}',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');

/// Las acciones de una jornada (mantener o clic derecho): compartir, ver su QR y llevarla
/// al calendario. Tocar la fila sigue abriendo el evento.
List<AccionGesto> accionesJornada(BuildContext context, Jornada j) => [
      AccionGesto(
        etiqueta: 'Compartir',
        icono: Icons.ios_share_rounded,
        alEjecutar: () async {
          try {
            await SharePlus.instance.share(ShareParams(text: textoJornada(j), subject: j.titulo));
          } catch (_) {
            if (context.mounted) avisar(context, 'No pude abrir el menú de compartir.', tipo: TipoAviso.error);
          }
        },
      ),
      AccionGesto(
        etiqueta: 'Ver QR',
        icono: Icons.qr_code_2_rounded,
        alEjecutar: () => mostrarHojaZ<void>(
          context,
          nombre: 'jornada_qr',
          contenido: (_) => _HojaQr(j),
        ),
      ),
      AccionGesto(
        etiqueta: 'Añadir al calendario',
        icono: Icons.event_available_rounded,
        alEjecutar: () async {
          try {
            await SharePlus.instance.share(ShareParams(
              text: '${j.titulo} · ${fechaLarga(j.inicio)}',
              files: [XFile.fromData(utf8.encode(icsJornada(j)), mimeType: 'text/calendar', name: 'jornada.ics')],
              fileNameOverrides: const ['jornada.ics'],
            ));
          } catch (_) {
            if (context.mounted) avisar(context, 'No pude preparar el calendario.', tipo: TipoAviso.error);
          }
        },
      ),
    ];

class _HojaQr extends StatelessWidget {
  const _HojaQr(this.j);
  final Jornada j;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(header: true, child: Text(j.titulo, style: tt.titleLarge, textAlign: TextAlign.center)),
        const SizedBox(height: 4),
        Text('${fechaLarga(j.inicio)} · ${horaCorta(j.inicio)}', style: tt.bodyMedium),
        const SizedBox(height: 16),
        Semantics(
          label: 'Código QR para entrar a la jornada ${j.titulo}',
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Zr.m), border: Border.all(color: Zc.linea)),
            child: QrImageView(data: enlaceEvento(j.id), size: 200, padding: EdgeInsets.zero),
          ),
        ),
        const SizedBox(height: 12),
        Text('Quien lo escanee entra al modo evento.', style: tt.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }
}
