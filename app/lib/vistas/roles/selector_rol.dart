import 'package:flutter/material.dart';

import '../../datos/estado.dart';
import '../../datos/guardian.dart';
import '../../datos/roles.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';

/// Ilustración de un rol: un cuadro con el color del rol, el agua del manglar abajo, un sol
/// pequeño y el ícono grande al centro. Una sola pieza para la bienvenida, Guardián y el carné.
class IlustracionRol extends StatelessWidget {
  const IlustracionRol(this.rol, {super.key, this.tamano = 64});
  final RolUsuario rol;
  final double tamano;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: tamano,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tamano * 0.3),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [rol.color.withValues(alpha: 0.95), Color.lerp(rol.color, Zc.raiz, 0.45)!],
                ),
              ),
              child: CustomPaint(
                painter: _PaisajeRol(),
                child: Center(child: Icon(rol.icono, color: Colors.white, size: tamano * 0.5)),
              ),
            ),
          ),
        ),
      );
}

class _PaisajeRol extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.8, h * 0.2), w * 0.09, Paint()..color = Colors.white.withValues(alpha: 0.5));
    final ola = Path()
      ..moveTo(0, h * 0.82)
      ..quadraticBezierTo(w * 0.25, h * 0.72, w * 0.5, h * 0.82)
      ..quadraticBezierTo(w * 0.75, h * 0.92, w, h * 0.8)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(ola, Paint()..color = Colors.white.withValues(alpha: 0.2));
  }

  @override
  bool shouldRepaint(_PaisajeRol old) => false;
}

/// Las cuatro tarjetas para elegir cómo participas. Se usa en la bienvenida y en Guardián.
class SelectorRol extends StatelessWidget {
  const SelectorRol({super.key, required this.valor, required this.alCambiar});
  final RolUsuario valor;
  final ValueChanged<RolUsuario> alCambiar;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in RolUsuario.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TarjetaRol(rol: r, elegido: r == valor, alTocar: () => alCambiar(r)),
            ),
        ],
      );
}

class TarjetaRol extends StatelessWidget {
  const TarjetaRol({super.key, required this.rol, required this.elegido, required this.alTocar});
  final RolUsuario rol;
  final bool elegido;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      selected: elegido,
      inMutuallyExclusiveGroup: true,
      child: Presionable(
        escala: 0.98,
        etiqueta: '${rol.nombre}. ${rol.lema}${elegido ? '. Elegido' : ''}',
        onTap: alTocar,
        child: AnimatedContainer(
          duration: context.resolveDuration(Zm.corto),
          curve: Zm.entrar,
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: elegido ? rol.color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(Zr.m),
            border: Border.all(color: elegido ? rol.color : Zc.linea, width: elegido ? 2 : 1),
          ),
          child: Row(
            children: [
              IlustracionRol(rol, tamano: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rol.nombre, style: tt.titleSmall),
                    const SizedBox(height: 2),
                    Text(rol.lema, style: tt.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedScale(
                duration: context.resolveDuration(Zm.corto),
                curve: Zm.entrar,
                scale: elegido ? 1 : 0.0,
                child: Icon(Icons.check_circle_rounded, color: rol.color, size: 26),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cambiar de rol desde Guardián. Guarda al elegir (primero a disco, después a memoria).
Future<void> mostrarCambiarRol(BuildContext context) {
  return mostrarHojaZ<void>(
    context,
    nombre: 'cambiar_rol',
    contenido: (_) => const _HojaRol(),
  );
}

class _HojaRol extends StatefulWidget {
  const _HojaRol();
  @override
  State<_HojaRol> createState() => _HojaRolState();
}

class _HojaRolState extends State<_HojaRol> {
  bool _guardando = false;
  String? _error;

  Future<void> _elegir(RolUsuario r) async {
    final estado = Zanky.leer(context);
    final base = estado.perfil;
    if (base == null || _guardando || base.rol == r) return;
    vibrar(Vibracion.seleccion);
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await estado.guardarPerfil(_conRol(base, r));
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No pudimos guardar el cambio. Revisa el espacio de tu teléfono.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final actual = Zanky.de(context).perfil?.rol ?? RolUsuario.ciudadano;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text('¿Cómo participas?', style: tt.headlineSmall)),
        const SizedBox(height: 6),
        Text('Cambia lo que ves en Inicio y en Guardián. No cambia tus puntos ni tus permisos.', style: tt.bodyMedium),
        const SizedBox(height: 16),
        AbsorbPointer(absorbing: _guardando, child: SelectorRol(valor: actual, alCambiar: _elegir)),
        if (_error != null) Text(_error!, style: tt.bodyMedium?.copyWith(color: Zc.prioridad[5])),
      ],
    );
  }
}

/// Un perfil igual al de [p] con otro rol (se arma uno nuevo: si guardar falla, el de memoria no cambia).
Perfil _conRol(Perfil p, RolUsuario r) => Perfil(
      id: p.id,
      creado: p.creado,
      sal: p.sal,
      nombre: p.nombre,
      colegio: p.colegio,
      cedulaHash: p.cedulaHash,
      anonimoPorDefecto: p.anonimoPorDefecto,
      consentimiento: p.consentimiento,
      rol: r,
    );
