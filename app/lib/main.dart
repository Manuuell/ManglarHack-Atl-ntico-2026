import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'datos/estado.dart';
import 'nucleo/tema.dart';
import 'vistas/bienvenida/bienvenida.dart';
import 'vistas/raiz.dart';
import 'vistas/web/envoltura_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final estado = EstadoZanky();
  runApp(Zanky(estado: estado, child: const AppZanky()));
  await estado.iniciar();
}

class AppZanky extends StatelessWidget {
  const AppZanky({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = Zanky.de(context);
    return MaterialApp(
      title: 'Zanky · Guardianes del manglar', // también es el título de la pestaña en la web
      debugShowCheckedModeBanner: false,
      theme: temaZanky(),
      builder: (context, child) => EnvolturaWeb(child: child!), // solo hace algo en el navegador
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
