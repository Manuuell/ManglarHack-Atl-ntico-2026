import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../datos/admin/controlador_admin.dart';
import '../../datos/estado.dart';
import '../../datos/experiencia/entrada_evento.dart' hide EntradaEvento;
import '../../datos/resumen_reportes.dart';
import '../../datos/roles.dart';
import '../../datos/guardian.dart';
import '../../datos/tipos.dart';
import '../../nucleo/base/entrada_escalonada.dart';
import '../../nucleo/base/esqueleto.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/kit/accion_gesto.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/menu_mantenido.dart';
import '../../nucleo/kit/tirar_actualizar.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/tema.dart';
import '../admin/panel_cra.dart';
import '../admin/piezas_admin.dart';
import '../comun/burbuja.dart';
import '../comun/comunes.dart';
import '../comun/zanky_mascota.dart';
import '../contenido/bloques_contenido.dart';
import '../experiencia/puerta_evento.dart';
import '../experiencia/widgets_evento.dart' show EntradaEvento;
import '../admin/contenido/franja_portada.dart';
import '../guardian/editar_perfil.dart';
import '../configuracion/pantalla_configuracion.dart';
import '../comunidad/comunidad_inicio.dart';
import '../comunidad/feed_y_eventos.dart' show recargaComunidadInicio;
import '../sensores/sensores_compacto.dart';
import '../visores/visores_compacto.dart';
import 'que_hago_ya.dart';
import 'secciones_rol.dart';
import '../crecimiento/pantalla_mi_manglar.dart';
import '../crecimiento/zanky_crece.dart';
import '../avisos/bandeja_avisos.dart';
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

  /// Secciones que la persona ocultó con el menú (mantener presionado). Duran la sesión
  /// y se devuelven con «Mostrar» al final de la lista.
  final Set<SeccionInicio> _ocultas = {};

  /// Las que se pueden abrir con el menú: las que tienen un campo de texto o ya tienen su
  /// propio mantener (jornadas) quedan fuera para no pelear con ellos.
  static const _sinMenu = {
    SeccionInicio.panel,
    SeccionInicio.reportar,
    SeccionInicio.queHagoYa,
    SeccionInicio.reporteRapido,
    SeccionInicio.evento,
    SeccionInicio.qrEvento,
    SeccionInicio.asistentes,
    SeccionInicio.jornadasCerca,
    SeccionInicio.misJornadas,
    // Alertas, próximo evento y noticias traen su propio mantener (vista previa y acciones).
    SeccionInicio.pronostico,
  };

  static String _nombre(SeccionInicio s) => switch (s) {
        SeccionInicio.estadoReportes => 'Tus reportes',
        SeccionInicio.progreso => 'Tu progreso',
        SeccionInicio.retoManglar => 'El reto del manglar',
        SeccionInicio.rankingColegio => 'Ranking de tu colegio',
        SeccionInicio.mision => 'La misión de la semana',
        SeccionInicio.queVer => 'Qué ver en el manglar',
        SeccionInicio.queNoHacer => 'Qué no hacer en el manglar',
        SeccionInicio.clima => 'El clima en el manglar',
        SeccionInicio.pronostico => 'El pronóstico del manglar',
        SeccionInicio.sensores => 'Los sensores del manglar',
        SeccionInicio.sabiasQue => '¿Sabías qué?',
        _ => 'Zanky',
      };

  Future<void> _compartirSeccion(BuildContext context, SeccionInicio s) async {
    try {
      await SharePlus.instance.share(ShareParams(
        text: 'Mira «${_nombre(s)}» en Zanky: la app para cuidar el manglar de la ciénaga de Mallorquín.',
        subject: 'Zanky',
      ));
    } catch (_) {
      if (context.mounted) avisar(context, 'No pude abrir el menú de compartir.', tipo: TipoAviso.error);
    }
  }

  /// Mantener presionada una tarjeta: reportar aquí, compartir u ocultarla (con «Deshacer»).
  Widget _conMenu(BuildContext context, SeccionInicio s, Widget hijo) {
    if (_sinMenu.contains(s)) return hijo;
    return MenuMantenido(
      etiqueta: _nombre(s),
      acciones: [
        AccionGesto(
          etiqueta: 'Reportar aquí',
          icono: Icons.add_a_photo_rounded,
          alEjecutar: () => abrirReporte(context),
        ),
        AccionGesto(
          etiqueta: 'Compartir',
          icono: Icons.ios_share_rounded,
          alEjecutar: () => _compartirSeccion(context, s),
        ),
        AccionGesto(
          etiqueta: 'Ocultar sección',
          icono: Icons.visibility_off_rounded,
          alEjecutar: () {
            setState(() => _ocultas.add(s));
            avisar(context, '«${_nombre(s)}» oculta',
                accion: AccionAviso('Deshacer', () {
                  if (mounted) setState(() => _ocultas.remove(s));
                }));
          },
        ),
      ],
      child: hijo,
    );
  }

  String _saludo() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Buenos días' : (h < 19 ? 'Buenas tardes' : 'Buenas noches');
  }

  Widget _seccion(BuildContext context, SeccionInicio s, EstadoZanky estado, Progreso progreso,
      ResumenReportes resumen) {
    final perfil = estado.perfil;
    switch (s) {
      case SeccionInicio.panel:
        return const BandejaPanel();
      case SeccionInicio.queHagoYa:
        final admin = AdminScope.maybeDe(context);
        final enPanel = admin != null && admin.dentro;
        return QueHagoYa(
          accion: _accionYa(context, estado, progreso, admin != null && enPanel ? admin : null),
          alTocar: (d) => _ir(context, d),
        );
      case SeccionInicio.reportar:
        // El único llamado a reportar de Inicio: la tarjeta héroe con el reporte rápido debajo.
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_TarjetaReportar(), SizedBox(height: 14), _Rapidos()],
        );
      case SeccionInicio.reporteRapido:
        return const _Rapidos();
      case SeccionInicio.estadoReportes:
        return EstadoMisReportes(resumen: resumen);
      case SeccionInicio.progreso:
        // El crecimiento de Zanky es el corazón de la gamificación: abre «Mi manglar».
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ZankyCreceCompacto(
            puntos: progreso.puntos,
            alAbrir: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PantallaMiManglar())),
          ),
        );
      case SeccionInicio.retoManglar:
        return const RetoManglar();
      case SeccionInicio.rankingColegio:
        return RankingColegio(
          colegio: perfil?.colegio.trim() ?? '',
          progreso: progreso,
          servidorConectado: estado.servidor.configurado,
        );
      case SeccionInicio.mision:
        return _Mision(mision: Mision.deLaSemana(DateTime.now()));
      case SeccionInicio.queVer:
        return const QueVer();
      case SeccionInicio.queNoHacer:
        return const QueNoHacer();
      case SeccionInicio.jornadasCerca:
        return const SeccionJornadas(vista: VistaJornadas.visitante);
      case SeccionInicio.misJornadas:
        return const SeccionJornadas(vista: VistaJornadas.organizador);
      case SeccionInicio.qrEvento:
        return const QrDelEvento();
      case SeccionInicio.asistentes:
        return const Asistentes();
      case SeccionInicio.evento:
        return const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: EntradaEvento());
      case SeccionInicio.clima:
        // El tiempo sale una vez: las cifras de /alertas; Open-Meteo solo sin red.
        return SoloSinCifrasDelServidor(child: _TarjetaClima(estado: estado));
      case SeccionInicio.pronostico:
        // Alertas oficiales del servidor (las de la web); el pronóstico local queda de respaldo sin red.
        return const ComunidadInicio();
      case SeccionInicio.sensores:
        // Visores de la C.R.A. junto a los sensores: un único acceso a «Visores del manglar».
        return const Column(children: [SensoresCompacto(), SizedBox(height: 12), VisoresCompacto()]);
      case SeccionInicio.sabiasQue:
        return _SabiasQue(hectareas: estado.manglar.areaTotalHa);
    }
  }

  AccionYa _accionYa(BuildContext context, EstadoZanky estado, Progreso progreso, ControladorAdmin? admin) {
    final perfil = estado.perfil;
    return queHagoYa(ContextoYa(
      hora: DateTime.now().hour,
      rolPanel: admin?.rol,
      sinVerPanel: admin?.sinVer ?? 0,
      porEnviar: estado.pendientes,
      rechazados: estado.rechazados,
      enLinea: estado.enLinea,
      enviados: progreso.enviados,
      tieneColegio: (perfil?.colegio.trim() ?? '').isNotEmpty,
      eventoAbierto: entradaEvento.value != null,
    ));
  }

  /// ¿Sobra la sección? «¿Qué hago ya?» no repite «reportar» (ya lo dice el héroe) y el
  /// estado de tus reportes no sale vacío (su botón repetiría el héroe).
  bool _sobra(BuildContext context, SeccionInicio s, EstadoZanky estado, Progreso progreso, ResumenReportes resumen) {
    if (s == SeccionInicio.estadoReportes) return resumen.vacio;
    if (s == SeccionInicio.queHagoYa) {
      final admin = AdminScope.maybeDe(context);
      return _accionYa(context, estado, progreso, admin != null && admin.dentro ? admin : null).destino ==
          DestinoYa.reportar;
    }
    return false;
  }

  /// A dónde lleva la sugerencia de «¿Qué hago ya?».
  Future<void> _ir(BuildContext context, DestinoYa d) async {
    switch (d) {
      case DestinoYa.reportar:
        abrirReporte(context);
      case DestinoYa.mapa:
        Raiz.irA(context, 1);
      case DestinoYa.misReportes:
        Raiz.irA(context, 2);
      case DestinoYa.guardian:
        Raiz.irA(context, 3);
      case DestinoYa.perfil:
        mostrarEditarPerfil(context);
      case DestinoYa.panel:
        if (AdminScope.maybeDe(context) != null) abrirPanelCra(context);
      case DestinoYa.evento:
        final abierto = entradaEvento.value;
        if (abierto != null) {
          abrirEvento(context, abierto.codigo);
          return;
        }
        final proximas = proximasJornadas(await cargaJornadasInicio(), DateTime.now());
        if (!context.mounted) return;
        if (proximas.isNotEmpty) {
          abrirEvento(context, proximas.first.id);
        } else {
          avisar(context, 'No hay jornadas programadas. Escribe el código de un evento en «¿Estás en una jornada?».');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = Zanky.de(context);
    final tt = Theme.of(context).textTheme;
    final nombre = estado.perfil?.nombre.trim().split(' ').first ?? '';
    final arriba = MediaQuery.paddingOf(context).top;
    final admin = AdminScope.maybeDe(context);
    final rolPanel = (admin != null && admin.dentro) ? admin.rol : null;
    final progreso = estado.progreso;
    final resumen = ResumenReportes.de(estado.reportes);
    final secciones = seccionesDeInicio(rolPanel: rolPanel)
        .where((s) => !_ocultas.contains(s) && !_sobra(context, s, estado, progreso, resumen))
        .toList();
    var i = 0;
    return TirarActualizar(
      alActualizar: () async {
        recargaComunidadInicio.value++;
        await Future.wait([estado.sincronizar(), estado.cargarClima()]);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, arriba + 10, 0, 120),
        children: [
          const FranjaMarcaCra(),
          // Saludo + Zanky que cuenta cosas al tocarlo.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_saludo().toUpperCase(), style: tt.seccion.copyWith(color: Cra.azul)),
                      const SizedBox(height: 2),
                      Text(nombre.isEmpty ? 'Guardián del manglar' : nombre, style: tt.headlineMedium),
                    ],
                  ),
                ),
                const CampanaAvisos(),
                const SizedBox(width: 8),
                const BotonConfiguracion(),
                const SizedBox(width: 4),
                ZankyMascota(
                  tamano: 74,
                  animo: _dato < 0 ? Animo.feliz : Animo.curioso,
                  onTap: () => setState(() => _dato = (_dato + 1) % DatosZanky.todos.length),
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
                    child: BurbujaZanky(texto: DatosZanky.todos[_dato], colaIzquierda: false),
                  ),
          ),
          const SizedBox(height: 14),
          const FranjaConexion(),
          const FranjaPortada(),
          for (final seccion in secciones) ...[
            EntradaEscalonada(index: i++, child: _conMenu(context, seccion, _seccion(context, seccion, estado, progreso, resumen))),
            const SizedBox(height: 16),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: BloquesContenido(ambito: 'global'),
          ),
          if (_ocultas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Presionable(
                etiqueta: 'Mostrar ${_ocultas.length} ${_ocultas.length == 1 ? 'sección oculta' : 'secciones ocultas'}',
                onTap: () => setState(_ocultas.clear),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Zc.hojaClara, borderRadius: BorderRadius.circular(Zr.m)),
                  child: Text(
                    'Mostrar ${_ocultas.length} ${_ocultas.length == 1 ? 'sección oculta' : 'secciones ocultas'}',
                    style: tt.labelLarge?.copyWith(color: Zc.hoja),
                  ),
                ),
              ),
            ),
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
                        Flexible(child: Text('Reportar ahora', style: tt.labelLarge?.copyWith(color: Colors.white))),
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
          // La altura crece con la letra: 42 de ícono + espacios fijos y una línea de texto.
          height: 80 + 16 * (MediaQuery.textScalerOf(context).scale(12) / 12).clamp(1.0, 2.0),
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

class _TarjetaClima extends StatefulWidget {
  const _TarjetaClima({required this.estado});
  final EstadoZanky estado;

  @override
  State<_TarjetaClima> createState() => _TarjetaClimaState();
}

class _TarjetaClimaState extends State<_TarjetaClima> {
  /// La lectura del tiempo tarda como mucho 8 s; pasado ese margen sin datos y sin caché
  /// el esqueleto deja de mentir («cargando») y la tarjeta dice la verdad.
  static const _espera = Duration(seconds: 10);
  bool _esperando = true;
  Timer? _plazo;

  @override
  void initState() {
    super.initState();
    if (widget.estado.clima == null) _plazo = Timer(_espera, _vencio);
  }

  void _vencio() {
    if (mounted) setState(() => _esperando = false);
  }

  Future<void> _reintentar() async {
    _plazo?.cancel();
    setState(() => _esperando = true);
    await widget.estado.cargarClima();
    if (mounted) setState(() => _esperando = false);
  }

  @override
  void dispose() {
    _plazo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;
    final tt = Theme.of(context).textTheme;
    final c = estado.clima;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TarjetaZ(
        color: Zc.cienagaClara,
        child: c == null
            ? (_esperando
                ? const Skeleton(width: double.infinity, height: 92)
                : _ClimaSinDatos(onReintentar: _reintentar))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.water_rounded, color: Zc.cienaga, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          estado.climaDeCache ? 'Ciénaga de Mallorquín, última lectura' : 'Ciénaga de Mallorquín, ahora',
                          style: tt.labelMedium?.copyWith(color: Zc.cienaga),
                        ),
                      ),
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

/// Sin señal y sin ninguna lectura guardada: se dice, sin esqueleto animado, y se puede
/// volver a intentar.
class _ClimaSinDatos extends StatelessWidget {
  const _ClimaSinDatos({required this.onReintentar});
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        const Icon(Icons.cloud_off_rounded, color: Zc.cienaga, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sin señal por ahora', style: tt.titleSmall?.copyWith(color: Zc.texto)),
              const SizedBox(height: 2),
              Text('El tiempo de la ciénaga aparece cuando vuelva la conexión.', style: tt.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
      ],
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
                  Text('MISIÓN DE LA SEMANA', style: tt.seccion.copyWith(color: const Color(0xFFB8741A))),
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
            '(${widget.hectareas.round()} ha en la capa de la CRA, cartografía 1:5.000, que usa esta app).'),
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

/// Cámara con dos anillos que salen despacio: invita a tocar sin repetir a Zanky.
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
