import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'datos/estado.dart';
import 'nucleo/tema.dart';
import 'vistas/bienvenida/bienvenida.dart';
import 'vistas/raiz.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final estado = EstadoZanqui();
  runApp(Zanqui(estado: estado, child: const AppZanqui()));
  await estado.iniciar();
}

class AppZanqui extends StatelessWidget {
  const AppZanqui({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = Zanqui.de(context);
    return MaterialApp(
      title: 'Zanqui',
      debugShowCheckedModeBanner: false,
      theme: temaZanqui(),
      home: AnimatedSwitcher(
        duration: Zm.medio,
        switchInCurve: Zm.entrar,
        child: !estado.listo
            ? const _Arranque()
            : (estado.perfil?.consentimiento == null ? const Bienvenida() : const Raiz()),
      ),
    );
  }
}

/// Lo que se ve mientras carga el mapa del manglar (unos cientos de ms).
class _Arranque extends StatelessWidget {
  const _Arranque();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Zc.arena,
        child: Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3))),
      );
}
