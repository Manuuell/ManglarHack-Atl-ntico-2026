import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanky/datos/experiencia/entrada_evento.dart';
import 'package:zanky/datos/experiencia/nfc_evento.dart';
import 'package:zanky/vistas/experiencia/avisos_web.dart';
import 'package:zanky/vistas/experiencia/organizadores_evento.dart';

class _NfcFalso implements GrabadorNfc {
  _NfcFalso(this.disponible);

  @override
  final bool disponible;
  String? enlaceGrabado;

  @override
  Future<void> grabar(String enlace) async {
    enlaceGrabado = enlace;
  }
}

void main() {
  test('accion=asistencia se lee antes y después del fragmento', () {
    final e = leerEntradaEvento(
      Uri.parse(
        'https://mimanglar.sentralabs.co/app/?evento=Jornada-1&accion=asistencia#/',
      ),
    );
    expect(e, const EntradaEvento('jornada-1', accionAsistencia: true));
    expect(
      leerEntradaEvento(
        Uri.parse('https://x.co/app/#/?evento=uno&accion=asistencia'),
      )?.accionAsistencia,
      isTrue,
    );
    expect(
      leerEntradaEvento(
        Uri.parse('https://x.co/app/?evento=uno&accion=otro'),
      )?.accionAsistencia,
      isFalse,
    );
    expect(
      enlaceAsistenciaEvento('jornada-1'),
      'https://mimanglar.sentralabs.co/app/?evento=jornada-1&accion=asistencia',
    );
  });

  testWidgets('NFC disponible graba el enlace de asistencia con un doble', (
    t,
  ) async {
    final falso = _NfcFalso(true);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrganizadoresEvento(codigo: 'jornada-1', grabador: falso),
          ),
        ),
      ),
    );
    await t.tap(find.text('Para organizadores'));
    await t.pump();
    await t.tap(find.text('Grabar etiqueta NFC del evento'));
    await t.pump();
    expect(falso.enlaceGrabado, enlaceAsistenciaEvento('jornada-1'));
    expect(find.textContaining('Etiqueta grabada'), findsOneWidget);
  });

  testWidgets('sin soporte NFC explica la alternativa', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrganizadoresEvento(
              codigo: 'uno',
              grabador: _NfcFalso(false),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Para organizadores'));
    await t.pump();
    expect(find.text('Grabar etiqueta NFC del evento'), findsNothing);
    expect(find.textContaining('En iPhone o PC'), findsOneWidget);
  });

  testWidgets('el aviso ofrece actualizar cuando hay una versión en espera', (
    t,
  ) async {
    final estado = ValueNotifier(const EstadoAvisos(versionNueva: true));
    var llamadas = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvisosWeb(estado: estado, alActualizar: () => llamadas++),
        ),
      ),
    );
    expect(find.text('Hay una versión nueva'), findsOneWidget);
    await t.tap(find.text('Actualizar'));
    expect(llamadas, 1);
    estado.value = const EstadoAvisos(conexion: 'Sin señal');
    await t.pump();
    expect(find.text('Sin señal'), findsOneWidget);
    expect(find.text('Actualizar'), findsNothing);
    await t.pumpWidget(const SizedBox());
    estado.dispose();
  });
}
