import 'package:flutter/material.dart';

import '../../datos/estado.dart';
import '../../datos/guardian.dart';
import '../../datos/tipos.dart';
import '../../nucleo/base/entrada_escalonada.dart';
import '../../nucleo/base/esqueleto.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/burbuja.dart';
import '../comun/comunes.dart';
import '../comun/zanqui_mascota.dart';
import '../raiz.dart';
import '../reporte/flujo_reporte.dart';

/// Inicio: lo urgente arriba (reportar), lo que motiva en medio (tu progreso, la
/// misión) y lo que enseña abajo (el tiempo de hoy y «¿Sabías que…?»).
class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  int _dato = -1;

  String _saludo() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Buenos días' : (h < 19 ? 'Buenas tardes' : 'Buenas noches');
  }

  @override
  Widget build(BuildContext context) {
    final estado = Zanqui.de(context);
    final tt = Theme.of(context).textTheme;
    final nombre = estado.perfil?.nombre.trim().split(' ').first ?? '';
    final arriba = MediaQuery.paddingOf(context).top;
    var i = 0;
    return RefreshIndicator(
      color: Zc.hoja,
      onRefresh: () async {
        await Future.wait([estado.sincronizar(), estado.cargarClima()]);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, arriba + 10, 0, 120),
        children: [
          // Saludo + Zanqui que cuenta cosas al tocarlo.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_saludo().toUpperCase(), style: tt.labelSmall?.copyWith(color: Zc.hoja)),
                      const SizedBox(height: 2),
                      Text(nombre.isEmpty ? 'Guardián del manglar' : nombre, style: tt.headlineMedium),
                    ],
                  ),
                ),
                ZanquiMascota(
                  tamano: 74,
                  animo: _dato < 0 ? Animo.feliz : Animo.curioso,
                  onTap: () => setState(() => _dato = (_dato + 1) % DatosZanqui.todos.length),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: Zm.medio,
            curve: Zm.entrar,
            child: _dato < 0
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: BurbujaZanqui(texto: DatosZanqui.todos[_dato], colaIzquierda: false),
                  ),
          ),
          const SizedBox(height: 14),
          const FranjaConexion(),
          EntradaEscalonada(index: i++, child: const _TarjetaReportar()),
          const SizedBox(height: 18),
          EntradaEscalonada(index: i++, child: const _Rapidos()),
          const SizedBox(height: 18),
          EntradaEscalonada(index: i++, child: _Progreso(progreso: estado.progreso)),
          const SizedBox(height: 14),
          EntradaEscalonada(index: i++, child: _TarjetaClima(estado: estado)),
          const SizedBox(height: 14),
          EntradaEscalonada(index: i++, child: _Mision(mision: Mision.deLaSemana(DateTime.now()))),
          const SizedBox(height: 22),
          EntradaEscalonada(index: i++, child: _SabiasQue(hectareas: estado.manglar.areaTotalHa)),
        ],
      ),
    );
  }
}

class _TarjetaReportar extends StatelessWidget {
  const _TarjetaReportar();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Presionable(
        escala: 0.98,
        vibracion: Vibracion.media,
        etiqueta: 'Reportar ahora una amenaza al manglar',
        onTap: () => abrirReporte(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Zr.xl),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Zc.raizSuave, Zc.raiz],
            ),
            boxShadow: [BoxShadow(color: Zc.raiz.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¿Viste algo en el manglar?', style: tt.titleLarge?.copyWith(color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(
                      'Tala, fuego, vertimientos, un caño tapado… Repórtalo ahora, aunque no tengas señal.',
                      style: tt.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.78)),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: Zc.hoja, borderRadius: BorderRadius.circular(99)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('Reportar ahora', style: tt.labelLarge?.copyWith(color: Colors.white)),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const _CamaraViva(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Atajos: tocar un tipo abre el reporte ya en «¿Dónde?».
class _Rapidos extends StatelessWidget {
  const _Rapidos();

  static const _tipos = [
    TipoAmenaza.tala,
    TipoAmenaza.quema,
    TipoAmenaza.vertimiento,
    TipoAmenaza.canoTaponado,
    TipoAmenaza.relleno,
    TipoAmenaza.fauna,
    TipoAmenaza.basuras,
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Reporte rápido', style: tt.titleMedium),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _tipos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final t = _tipos[i];
              return Presionable(
                escala: 0.94,
                etiqueta: 'Reportar ${t.nombre}',
                onTap: () => abrirReporte(context, tipo: t),
                child: Container(
                  width: 86,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Zr.m),
                    border: Border.all(color: Zc.linea.withValues(alpha: 0.7)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconoTipo(t, tamano: 42),
                      const SizedBox(height: 7),
                      Text(t.corto, maxLines: 1, style: tt.labelMedium),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Progreso extends StatelessWidget {
  const _Progreso({required this.progreso});
  final Progreso progreso;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final n = progreso.nivel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TarjetaZ(
        onTap: () => Raiz.irA(context, 3),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: progreso.avanceNivel),
                    duration: Zm.largo,
                    curve: Zm.entrar,
                    builder: (_, v, _) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      color: Zc.hoja,
                      backgroundColor: Zc.hojaClara,
                    ),
                  ),
                  Text('${n.numero}', style: tt.titleLarge?.copyWith(color: Zc.hoja)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.nombre, style: tt.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    progreso.enviados == 0
                        ? 'Tu primer reporte validado te hace crecer.'
                        : '${progreso.enviados} ${progreso.enviados == 1 ? 'reporte enviado' : 'reportes enviados'} · '
                            '${progreso.validados} ${progreso.validados == 1 ? 'validado' : 'validados'}',
                    style: tt.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Zc.textoTenue),
          ],
        ),
      ),
    );
  }
}

class _TarjetaClima extends StatelessWidget {
  const _TarjetaClima({required this.estado});
  final EstadoZanqui estado;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final c = estado.clima;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TarjetaZ(
        color: Zc.cienagaClara,
        child: c == null
            ? const Skeleton(width: double.infinity, height: 92)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.water_rounded, color: Zc.cienaga, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Ciénaga de Mallorquín, ahora', style: tt.labelMedium?.copyWith(color: Zc.cienaga))),
                      if (estado.climaDeCache)
                        Text('sin señal · ${haceCuanto(c.leido)}', style: tt.labelSmall),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('${c.temperatura.round()}°', style: tt.displaySmall?.copyWith(color: Zc.raiz)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          children: [
                            _Dato(Icons.air_rounded, '${c.vientoKmh.round()} km/h ${c.rumbo}'),
                            _Dato(Icons.water_drop_outlined, '${c.lluviaMm.toStringAsFixed(1)} mm'),
                            if (c.olaM != null) _Dato(Icons.waves_rounded, 'Olas ${c.olaM!.toStringAsFixed(1)} m'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(c.frase, style: tt.bodyMedium?.copyWith(color: Zc.texto)),
                  const SizedBox(height: 4),
                  Text('Datos: Open-Meteo', style: tt.labelSmall?.copyWith(fontSize: 9.5, color: Zc.textoTenue)),
                ],
              ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.texto);
  final IconData icono;
  final String texto;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 16, color: Zc.cienaga),
        const SizedBox(width: 4),
        Text(texto, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Zc.texto)),
      ]);
}

class _Mision extends StatelessWidget {
  const _Mision({required this.mision});
  final Mision mision;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TarjetaZ(
        color: Zc.solClaro,
        onTap: () => abrirReporte(context),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: Zc.sol.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(mision.icono, color: const Color(0xFFB8741A)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MISIÓN DE LA SEMANA', style: tt.labelSmall?.copyWith(color: const Color(0xFFB8741A))),
                  const SizedBox(height: 2),
                  Text(mision.titulo, style: tt.titleMedium),
                  const SizedBox(height: 2),
                  Text(mision.detalle, style: tt.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «¿Sabías que…?»: tarjetas que se deslizan para concientizar (lo pidió el equipo:
/// resiliencia, primera defensa contra el mar, carbono).
class _SabiasQue extends StatefulWidget {
  const _SabiasQue({required this.hectareas});
  final double hectareas;

  @override
  State<_SabiasQue> createState() => _SabiasQueState();
}

class _SabiasQueState extends State<_SabiasQue> {
  final _paginas = PageController(viewportFraction: 0.86);
  double _pagina = 0;

  late final _datos = [
    (Icons.shield_rounded, Zc.cienaga, 'Primera defensa contra el mar',
        'Las raíces del manglar frenan el oleaje y sostienen la costa cuando el mar sube.'),
    (Icons.co2_rounded, Zc.raizSuave, 'Carbono azul',
        'El manglar guarda carbono en el fango durante siglos: es de los bosques que más carbono atrapan.'),
    (Icons.autorenew_rounded, Zc.hoja, 'Resiliente',
        'Si lo dejamos en paz, vuelve a brotar: sus propágulos flotan y echan raíz donde llegan.'),
    (Icons.set_meal_rounded, Zc.sol, 'Cuna de la pesca',
        'Peces, cangrejos y camarones crecen entre sus raíces: de ahí comen los pescadores de Mallorquín.'),
    (Icons.water_rounded, const Color(0xFF6A4FA3), 'Agua dulce y salada',
        'Necesita las dos. Un caño taponado le corta el agua dulce y lo enferma: también se reporta.'),
    (Icons.map_rounded, Zc.fango, 'Cuatro ciénagas',
        'En el Atlántico hay manglar en Mallorquín, Tubará, Juan de Acosta y Piojó: unas 775 ha según la CRA '
            '(${widget.hectareas.round()} ha en la capa de INVEMAR que usa esta app).'),
  ];

  @override
  void initState() {
    super.initState();
    _paginas.addListener(() => setState(() => _pagina = _paginas.page ?? 0));
  }

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('¿Sabías que…?', style: tt.titleMedium),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _paginas,
            padEnds: false,
            itemCount: _datos.length,
            onPageChanged: (_) => vibrar(Vibracion.seleccion),
            itemBuilder: (context, i) {
              final (icono, color, titulo, texto) = _datos[i];
              // Las tarjetas vecinas se ven un poco más chicas: invita a deslizar.
              final d = (_pagina - i).abs().clamp(0.0, 1.0);
              return Transform.scale(
                scale: 1 - d * 0.05,
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 16 : 6, right: 6),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(Zr.l),
                      border: Border.all(color: Zc.linea.withValues(alpha: 0.7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.13), shape: BoxShape.circle),
                          child: Icon(icono, color: color, size: 22),
                        ),
                        const SizedBox(height: 10),
                        Text(titulo, style: tt.titleSmall),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(texto, style: tt.bodySmall?.copyWith(color: Zc.texto, height: 1.4),
                              overflow: TextOverflow.fade),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Cámara con dos anillos que salen despacio: invita a tocar sin repetir a Zanqui.
class _CamaraViva extends StatefulWidget {
  const _CamaraViva();
  @override
  State<_CamaraViva> createState() => _CamaraVivaState();
}

class _CamaraVivaState extends State<_CamaraViva> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.animationsDisabled) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: SizedBox(
          width: 84,
          height: 84,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, hijo) => CustomPaint(painter: _Anillos(_c.value), child: hijo),
            child: Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
                ),
                child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
        ),
      );
}

class _Anillos extends CustomPainter {
  _Anillos(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (final fase in const [0.0, 0.5]) {
      final x = (t + fase) % 1;
      canvas.drawCircle(
        c,
        26 + 16 * x,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.35 * (1 - x)),
      );
    }
  }

  @override
  bool shouldRepaint(_Anillos o) => o.t != t;
}
