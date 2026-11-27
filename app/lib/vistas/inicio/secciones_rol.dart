import 'package:flutter/material.dart';
import '../../nucleo/kit/menu_mantenido.dart';
import 'jornada_acciones.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../datos/experiencia/entrada_evento.dart' hide EntradaEvento;
import '../../datos/experiencia/jornada.dart';
import '../../datos/experiencia/participacion.dart';
import '../../datos/guardian.dart';
import '../../datos/resumen_reportes.dart';
import '../../datos/roles.dart';
import '../../nucleo/kit/estado_vacio.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../admin/panel_cra.dart';
import '../admin/piezas_admin.dart';
import '../comun/zanky_mascota.dart';
import '../experiencia/organizadores_evento.dart';
import '../experiencia/puerta_evento.dart';
import '../experiencia/reto_zanky.dart';
import '../experiencia/widgets_evento.dart' show EntradaEvento;
import '../raiz.dart';
import '../reporte/flujo_reporte.dart';

/// Quién carga las jornadas que ve Inicio (lo que hay en el teléfono: caché o respaldo).
/// Las pruebas lo cambian por una lista fija (es una variable, no una constante).
Future<List<Jornada>> Function() cargaJornadasInicio = () =>
    FuenteJornadas().cargarLocal();

/// Las jornadas que todavía no terminaron, la más cercana en el tiempo primero.
List<Jornada> proximasJornadas(Iterable<Jornada> todas, DateTime ahora) => [
  for (final j in todas)
    if (j.fin.isAfter(ahora)) j,
]..sort((a, b) => a.inicio.compareTo(b.inicio));

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto, {this.nota});
  final String texto;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(texto, style: tt.titleMedium)),
          if (nota != null) Text(nota!, style: tt.bodySmall),
        ],
      ),
    );
  }
}

class _Caja extends StatelessWidget {
  const _Caja({required this.child, this.color, this.onTap});
  final Widget child;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: TarjetaZ(color: color, onTap: onTap, child: child),
  );
}

/// Una fila con ícono en círculo y texto (qué ver, qué no hacer).
class _Fila extends StatelessWidget {
  const _Fila(this.icono, this.color, this.titulo, this.texto);
  final IconData icono;
  final Color color;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: tt.titleSmall),
                Text(
                  texto,
                  style: tt.bodySmall?.copyWith(color: Zc.textoSuave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pildora extends StatelessWidget {
  const _Pildora(this.icono, this.texto, this.color);
  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texto,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: Zc.texto),
          ),
        ),
      ],
    ),
  );
}

// ------------------------------------------------------------------ roles del servidor

/// La bandeja del panel arriba de todo cuando hay sesión del equipo.
class BandejaPanel extends StatelessWidget {
  const BandejaPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AdminScope.maybeDe(context);
    if (c == null || !c.dentro) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final n = c.sinVer;
    return _Caja(
      color: Zc.raiz,
      onTap: () => abrirPanelCra(context),
      child: Row(
        children: [
          Badge(
            isLabelVisible: n > 0,
            backgroundColor: Zc.sol,
            textColor: Zc.raiz,
            label: Text(n > 99 ? '99+' : '$n'),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PANEL · ${RolPanel.etiqueta(c.rol).toUpperCase()}',
                  style: tt.labelSmall?.copyWith(color: Zc.hojaClara),
                ),
                Text(
                  n > 0 ? '$n por revisar' : 'Todo al día',
                  style: tt.titleLarge?.copyWith(color: Colors.white),
                ),
                Text(
                  n > 0
                      ? 'Lo más grave sale primero.'
                      : 'No hay reportes nuevos.',
                  style: tt.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ ciudadano

/// Estado de mis reportes: cuántos esperan salir, cuántos están en la CRA y cuántos se validaron.
class EstadoMisReportes extends StatelessWidget {
  const EstadoMisReportes({super.key, required this.resumen});
  final ResumenReportes resumen;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    if (resumen.vacio) {
      return _Caja(
        child: EstadoVacio(
          titulo: 'Aún no has reportado',
          texto:
              'Cuando avises de algo, aquí verás en qué va: guardado, en revisión o validado.',
          tamanoZanky: 84,
          relleno: EdgeInsets.zero,
          textoAccion: 'Hacer mi primer reporte',
          iconoAccion: Icons.add_a_photo_rounded,
          alAccion: () => abrirReporte(context),
        ),
      );
    }
    Widget casilla(String cifra, String texto, IconData icono, Color color) =>
        Expanded(
          child: Column(
            children: [
              Icon(icono, color: color, size: 22),
              const SizedBox(height: 4),
              Text(cifra, style: tt.titleLarge?.copyWith(color: color)),
              Text(texto, style: tt.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Titulo('Estado de mis reportes'),
        _Caja(
          onTap: () => Raiz.irA(context, 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              casilla(
                '${resumen.enTelefono}',
                'En mi teléfono',
                Icons.phone_android_rounded,
                Zc.fango,
              ),
              casilla(
                '${resumen.enRevision}',
                'En revisión',
                Icons.hourglass_top_rounded,
                Zc.sol,
              ),
              casilla(
                '${resumen.validados}',
                'Validados',
                Icons.verified_rounded,
                Zc.hoja,
              ),
              if (resumen.rechazados > 0)
                casilla(
                  '${resumen.rechazados}',
                  'Rechazados',
                  Icons.error_outline_rounded,
                  Zc.prioridad[5]!,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ estudiante

const codigoReto = 'reto-manglar';

/// El reto del manglar (cinco preguntas con fuente), a un toque desde Inicio.
class RetoManglar extends StatefulWidget {
  const RetoManglar({super.key, this.almacen});
  final AlmacenParticipacion? almacen;

  @override
  State<RetoManglar> createState() => _RetoManglarState();
}

class _RetoManglarState extends State<RetoManglar> {
  late final AlmacenParticipacion _a =
      widget.almacen ?? AlmacenParticipacion.instancia;

  @override
  void initState() {
    super.initState();
    _a.cargar();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _a,
      builder: (context, _) {
        final mejor = _a.mejorReto(codigoReto);
        return _Caja(
          color: Zc.cienagaClara,
          onTap: () =>
              abrirRetoZanky(context, EventoZanky.generico(codigoReto)),
          child: Row(
            children: [
              const ExcludeSemantics(
                child: ZankyMascota(tamano: 64, animo: Animo.curioso),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RETO DEL MANGLAR',
                      style: tt.labelSmall?.copyWith(
                        color: const Color(0xFF137579),
                      ),
                    ),
                    Text(
                      mejor == 0
                          ? '¿Cuánto sabes del manglar?'
                          : 'Tu mejor marca: $mejor de 5',
                      style: tt.titleMedium,
                    ),
                    Text(
                      mejor == 0
                          ? 'Cinco preguntas con fuente. Cada acierto suma 10 puntos.'
                          : 'Juega otra vez y supérala.',
                      style: tt.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Zc.cienaga),
            ],
          ),
        );
      },
    );
  }
}

/// El ranking de tu colegio. Sin servidor no hay datos de otros colegios: se dice, no se inventa.
class RankingColegio extends StatelessWidget {
  const RankingColegio({
    super.key,
    required this.colegio,
    required this.progreso,
    required this.servidorConectado,
  });
  final String colegio;
  final Progreso progreso;
  final bool servidorConectado;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Titulo('Ranking de tu colegio'),
        _Caja(
          child: colegio.isEmpty
              ? EstadoVacio(
                  titulo: 'Falta tu colegio',
                  texto: 'Agrégalo y tus reportes validados suman para él.',
                  tamanoZanky: 72,
                  relleno: EdgeInsets.zero,
                  textoAccion: 'Agregar mi colegio',
                  iconoAccion: Icons.school_rounded,
                  alAccion: () => Raiz.irA(context, 3),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school_rounded, color: Zc.cienaga),
                        const SizedBox(width: 10),
                        Expanded(child: Text(colegio, style: tt.titleSmall)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pildora(
                          Icons.star_rounded,
                          '${progreso.puntos} puntos tuyos',
                          Zc.sol,
                        ),
                        _Pildora(
                          Icons.verified_rounded,
                          '${progreso.validados} validados',
                          Zc.hoja,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      servidorConectado
                          ? 'El ranking «Guardianes del manglar» aparece cuando varios colegios tengan reportes validados.'
                          : 'Modo demostración: no hay datos de otros colegios y no inventamos ninguno.',
                      style: tt.bodySmall,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ visitante

class QueVer extends StatelessWidget {
  const QueVer({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Titulo('Qué ver'),
      _Caja(
        child: Column(
          children: [
            _Fila(
              Icons.park_rounded,
              Zc.hoja,
              'Las raíces de zanco',
              'El mangle rojo se apoya en raíces arqueadas: míralas desde el sendero, sin pisarlas.',
            ),
            _Fila(
              Icons.flutter_dash_rounded,
              Zc.cienaga,
              'Aves y cangrejos',
              'Hay más movimiento al amanecer y al atardecer. Llega temprano.',
            ),
            _Fila(
              Icons.map_rounded,
              Zc.fango,
              'Cuatro ciénagas',
              'Mallorquín, Tubará, Juan de Acosta y Piojó guardan el manglar del Atlántico.',
            ),
          ],
        ),
      ),
    ],
  );
}

class QueNoHacer extends StatelessWidget {
  const QueNoHacer({super.key});

  @override
  Widget build(BuildContext context) {
    final rojo = Zc.prioridad[5]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Titulo('Qué no hacer'),
        _Caja(
          child: Column(
            children: [
              _Fila(
                Icons.do_not_step_rounded,
                rojo,
                'No pises ni cortes raíces',
                'Se rompen y el árbol se enferma.',
              ),
              _Fila(
                Icons.delete_outline_rounded,
                rojo,
                'No dejes basura',
                'Lo que dejas queda enredado en las raíces.',
              ),
              _Fila(
                Icons.local_fire_department_rounded,
                rojo,
                'No hagas fuego ni fumes',
                'Una chispa en el manglar seco se vuelve incendio.',
              ),
              _Fila(
                Icons.pets_rounded,
                rojo,
                'No saques plantas ni animales',
                'Míralos y déjalos donde están.',
              ),
              _Fila(
                Icons.groups_rounded,
                rojo,
                'No vayas solo',
                'Ve acompañado y con las indicaciones de la organización.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ jornadas (visitante y organizador)

enum VistaJornadas { visitante, organizador }

/// Carga las jornadas locales una vez y se las pasa a [construir] (nulo mientras llegan).
class _ConJornadas extends StatefulWidget {
  const _ConJornadas({required this.construir});
  final Widget Function(BuildContext context, List<Jornada>? proximas)
  construir;

  @override
  State<_ConJornadas> createState() => _ConJornadasState();
}

class _ConJornadasState extends State<_ConJornadas> {
  List<Jornada>? _lista;

  @override
  void initState() {
    super.initState();
    cargaJornadasInicio().then(
      (l) {
        if (mounted) {
          setState(() => _lista = proximasJornadas(l, DateTime.now()));
        }
      },
      onError: (Object _) {
        if (mounted) setState(() => _lista = const []);
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.construir(context, _lista);
}

class SeccionJornadas extends StatelessWidget {
  const SeccionJornadas({super.key, required this.vista});
  final VistaJornadas vista;

  @override
  Widget build(BuildContext context) {
    final org = vista == VistaJornadas.organizador;
    return _ConJornadas(
      construir: (context, lista) {
        final tt = Theme.of(context).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Titulo(
              org ? 'Mis jornadas' : 'Próximas jornadas',
              nota: org
                  ? 'Las que están programadas. Toca una para abrir su evento y grabar su etiqueta NFC.'
                  : 'Pregunta en el punto de encuentro si puedes sumarte.',
            ),
            _Caja(
              child: lista == null
                  ? const SizedBox(
                      height: 72,
                      child: Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Zc.hoja,
                          ),
                        ),
                      ),
                    )
                  : lista.isEmpty
                  ? EstadoVacio(
                      titulo: 'Sin jornadas próximas',
                      texto: org
                          ? 'Cuando programes una, aparece aquí con su QR.'
                          : 'Cuando haya una nueva, la verás aquí.',
                      tamanoZanky: 72,
                      relleno: EdgeInsets.zero,
                    )
                  : Column(
                      children: [
                        for (final (i, j) in lista.take(3).indexed) ...[
                          if (i > 0) const Divider(height: 18, color: Zc.linea),
                          MenuMantenido(
                            etiqueta: j.titulo,
                            acciones: accionesJornada(context, j),
                            alTocar: () => abrirEvento(context, j.id),
                            escala: 0.98,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Zc.hojaClara,
                                      borderRadius: BorderRadius.circular(Zr.s),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${aHoraColombia(j.inicio).day}',
                                        style: tt.titleMedium?.copyWith(
                                          color: Zc.hoja,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(j.titulo, style: tt.titleSmall),
                                        Text(
                                          '${fechaLarga(j.inicio)} · ${horaCorta(j.inicio)}'
                                          '${j.esEjemplo ? ' · Datos de ejemplo' : ''}',
                                          style: tt.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Zc.textoTenue,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// El QR de la próxima jornada para que la gente entre al modo evento desde el cartel, y la
/// herramienta para grabar su etiqueta NFC (la de «Para organizadores» del modo evento).
class QrDelEvento extends StatelessWidget {
  const QrDelEvento({super.key});

  @override
  Widget build(BuildContext context) => _ConJornadas(
    construir: (context, lista) {
      final tt = Theme.of(context).textTheme;
      final j = (lista == null || lista.isEmpty) ? null : lista.first;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Titulo('QR del evento'),
          _Caja(
            child: j == null
                ? Column(
                    children: [
                      Text(
                        lista == null
                            ? 'Buscando tu próxima jornada…'
                            : 'Aún no hay una jornada para armar su QR.',
                        style: tt.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      const EntradaEvento(),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(Zr.s),
                              border: Border.all(color: Zc.linea),
                            ),
                            child: QrImageView(
                              data: enlaceEvento(j.id),
                              size: 104,
                              padding: EdgeInsets.zero,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Zc.raiz,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Zc.raiz,
                              ),
                              semanticsLabel:
                                  'Código QR de la jornada ${j.titulo}',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(j.titulo, style: tt.titleSmall),
                                const SizedBox(height: 2),
                                Text(
                                  'Imprímelo o muéstralo en el punto de encuentro: abre el evento en el teléfono.',
                                  style: tt.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Grabar la etiqueta NFC del evento (la herramienta del modo evento).
                      OrganizadoresEvento(codigo: j.id),
                    ],
                  ),
          ),
        ],
      );
    },
  );
}

/// Quiénes van a la próxima jornada. Hoy solo hay cupos e inscritos de la jornada (de ejemplo
/// sin servidor): el registro de llegada vive en el teléfono de cada persona.
class Asistentes extends StatelessWidget {
  const Asistentes({super.key});

  @override
  Widget build(BuildContext context) => _ConJornadas(
    construir: (context, lista) {
      final tt = Theme.of(context).textTheme;
      final j = (lista == null || lista.isEmpty) ? null : lista.first;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Titulo('Asistentes'),
          _Caja(
            child: j == null
                ? Text(
                    'Cuando tengas una jornada, aquí ves cuántas personas se inscribieron.',
                    style: tt.bodyMedium,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${j.inscritos}',
                            style: tt.displaySmall?.copyWith(color: Zc.hoja),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'inscritos de ${j.cupos} cupos',
                              style: tt.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: j.cupos == 0
                              ? 0
                              : (j.inscritos / j.cupos).clamp(0.0, 1.0),
                          minHeight: 8,
                          color: Zc.hoja,
                          backgroundColor: Zc.hojaClara,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${j.esEjemplo ? 'Datos de ejemplo. ' : ''}Cada persona registra su llegada en su teléfono; '
                        'la lista completa llegará con el servidor.',
                        style: tt.bodySmall,
                      ),
                    ],
                  ),
          ),
        ],
      );
    },
  );
}
