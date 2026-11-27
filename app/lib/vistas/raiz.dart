import 'dart:ui';

import 'package:flutter/material.dart';

import '../datos/admin/controlador_admin.dart';
import '../datos/estado.dart';
import '../nucleo/base/transicion_pestanas.dart';
import '../nucleo/presionable.dart';
import '../nucleo/tema.dart';
import 'admin/piezas_admin.dart';
import 'comun/capa_avisos.dart';
import 'guardian/pantalla_guardian.dart';
import 'comun/zanky_mascota.dart';
import 'inicio/inicio.dart';
import 'mapa/pantalla_mapa.dart';
import 'mis_reportes/pantalla_mis_reportes.dart';
import 'reporte/flujo_reporte.dart';

/// La raíz: cuatro pestañas y, en el centro, el botón grande de reportar (lo más
/// importante de la app siempre a un pulgar de distancia).
class Raiz extends StatefulWidget {
  const Raiz({super.key});

  /// Cambia de pestaña desde cualquier pantalla, incluso desde una ruta apilada encima
  /// (la confirmación de un reporte no tiene a la raíz como ancestro).
  static void irA(BuildContext context, int pestana) => _pedida.value = pestana;
  static final _pedida = ValueNotifier<int?>(null);

  @override
  State<Raiz> createState() => _RaizState();
}

class _RaizState extends State<Raiz> {
  int _actual = 0;

  /// El panel de la CRA: vive con la raíz para que su consulta periódica y el contador
  /// del ícono sigan mientras se navega, y se detiene al cerrarla.
  ControladorAdmin? _admin;

  @override
  void initState() {
    super.initState();
    Raiz._pedida.addListener(_atenderPedido);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _admin ??= ControladorAdmin(servidor: Zanky.leer(context).servidor);
    // Una sola vez: las imágenes de Zanky ya en memoria antes del primer cambio de ánimo.
    if (!_precargado) {
      _precargado = true;
      precargarZanky(context);
    }
  }

  bool _precargado = false;

  @override
  void dispose() {
    Raiz._pedida.removeListener(_atenderPedido);
    _admin?.dispose();
    super.dispose();
  }

  void _atenderPedido() {
    final p = Raiz._pedida.value;
    if (p == null) return;
    Raiz._pedida.value = null;
    _ir(p);
  }

  void _ir(int i) {
    if (i == _actual) return;
    vibrar(Vibracion.seleccion);
    setState(() => _actual = i);
  }

  @override
  Widget build(BuildContext context) {
    final abajo = MediaQuery.paddingOf(context).bottom;
    return AdminScope(
      controlador: _admin!,
      child: Scaffold(
        extendBody: true,
        body: CapaAvisos(
          verMisReportes: () => _ir(2),
          child: AnimatedTabStack(
            index: _actual,
            ordenPrecarga: const [1, 2, 3],
            children: const [Inicio(), PantallaMapa(), PantallaMisReportes(), PantallaGuardian()],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 14, abajo > 0 ? abajo : 12),
          child: _BarraPestanas(actual: _actual, onCambio: _ir),
        ),
      ),
    );
  }
}

class _BarraPestanas extends StatelessWidget {
  const _BarraPestanas({required this.actual, required this.onCambio});
  final int actual;
  final ValueChanged<int> onCambio;

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Inicio'),
    (Icons.map_rounded, Icons.map_outlined, 'Mapa'),
    (Icons.inbox_rounded, Icons.inbox_outlined, 'Mis reportes'),
    (Icons.badge_rounded, Icons.badge_outlined, 'Guardián'),
  ];

  @override
  Widget build(BuildContext context) {
    final pendientes = Zanky.de(context).pendientes;
    // El número del panel de la CRA aparece en Guardián solo si hay sesión del equipo.
    final admin = AdminScope.maybeDe(context);
    final sinVer = admin != null && admin.dentro ? admin.sinVer : 0;
    return SizedBox(
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Vidrio: se ve el contenido detrás, sin perder lectura.
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                height: 66,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [BoxShadow(color: Color(0x1F0B2E24), blurRadius: 30, offset: Offset(0, 12))],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < 2; i++) _pestana(context, i, pendientes, sinVer),
              const SizedBox(width: 76),
              for (var i = 2; i < 4; i++) _pestana(context, i, pendientes, sinVer),
            ],
          ),
          Positioned(top: -16, child: _BotonReportar()),
        ],
      ),
    );
  }

  Widget _pestana(BuildContext context, int i, int pendientes, int sinVer) {
    final (lleno, vacio, nombre) = _items[i];
    final activa = i == actual;
    final color = activa ? Zc.hoja : Zc.textoTenue;
    return Expanded(
      child: Presionable(
        escala: 0.88,
        vibracion: Vibracion.ninguna, // la vibración la pone el cambio de pestaña
        etiqueta: nombre,
        onTap: () => onCambio(i),
        child: SizedBox(
          height: 66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: (i == 2 && pendientes > 0) || (i == 3 && sinVer > 0),
                backgroundColor: Zc.sol,
                label: Text(i == 3 ? '$sinVer' : '$pendientes'),
                child: AnimatedScale(
                  scale: activa ? 1.08 : 1,
                  duration: Zm.medio,
                  curve: Curves.easeOutBack,
                  child: Icon(activa ? lleno : vacio, color: color, size: 25),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: Zm.corto,
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: color,
                      fontWeight: activa ? FontWeight.w700 : FontWeight.w600,
                      letterSpacing: 0,
                    ),
                child: Text(nombre, maxLines: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonReportar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Presionable(
      escala: 0.9,
      vibracion: Vibracion.media,
      etiqueta: 'Reportar una amenaza al manglar',
      onTap: () => abrirReporte(context),
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3DB37C), Zc.hoja, Color(0xFF1E7A50)],
          ),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [BoxShadow(color: Zc.hoja.withValues(alpha: 0.45), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
