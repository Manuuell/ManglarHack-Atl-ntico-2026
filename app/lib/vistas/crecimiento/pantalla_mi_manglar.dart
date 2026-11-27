import 'package:flutter/material.dart';

import '../../datos/crecimiento/ranking_colegios.dart';
import '../../datos/estado.dart';
import '../../datos/guardian.dart';
import '../../datos/reporte.dart';
import '../../datos/servidor.dart';
import '../../datos/tipos.dart';
import '../../nucleo/tema.dart';
import 'zanky_crece.dart';
import '../../nucleo/kit/icono_amenaza.dart';

/// Pantalla de destino para la tarjeta compacta de Inicio y la entrada de
/// Guardián. Los parámetros opcionales permiten previsualizarla sin estado global.
class PantallaMiManglar extends StatefulWidget {
  const PantallaMiManglar({super.key, this.progreso, this.reportes, this.perfil,
    this.servidor, this.hora});

  final Progreso? progreso;
  final List<Reporte>? reportes;
  final Perfil? perfil;
  final Servidor? servidor;
  final DateTime? hora;

  @override
  State<PantallaMiManglar> createState() => _PantallaMiManglarState();
}

class _PantallaMiManglarState extends State<PantallaMiManglar> {
  Future<List<ColegioEnRanking>>? _ranking;
  Servidor? _servidorConsultado;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _consultarRanking();
  }

  @override
  void didUpdateWidget(PantallaMiManglar anterior) {
    super.didUpdateWidget(anterior);
    if (widget.servidor != anterior.servidor) _consultarRanking();
  }

  void _consultarRanking() {
    final servidor = widget.servidor ?? (widget.progreso == null ? Zanky.leer(context).servidor : null);
    if (servidor == _servidorConsultado) return;
    _servidorConsultado = servidor;
    _ranking = servidor?.configurado == true ? RankingColegios(servidor!).cargar() : null;
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.progreso == null ? Zanky.de(context) : null;
    final progreso = widget.progreso ?? estado!.progreso;
    final reportes = widget.reportes ?? estado?.reportes ?? const <Reporte>[];
    final perfil = widget.perfil ?? estado?.perfil;
    final servidor = widget.servidor ?? estado?.servidor;
    final colegio = perfil?.colegio.trim() ?? '';
    final historia = _HistoriaCrecimiento(reportes: reportes);
    final insignias = _ProximasInsignias(progreso: progreso);
    final ranking = _RankingColegios(
      colegio: colegio, configurado: servidor?.configurado ?? false,
      resultado: _ranking, alReintentar: () {
        if (servidor == null) return;
        setState(() => _ranking = RankingColegios(servidor).cargar());
      },
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Mi manglar'), backgroundColor: Zc.arena),
      body: LayoutBuilder(builder: (context, limites) {
        final ancho = limites.maxWidth;
        final escritorio = ancho >= 900;
        final margen = escritorio ? 28.0 : 16.0;
        final contenido = escritorio
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 6, child: Column(children: [
                  ZankyCrece(puntos: progreso.puntos, nivel: progreso.nivel.numero,
                    idGuardian: perfil?.id, hora: widget.hora),
                  const SizedBox(height: 16),
                  ranking,
                ])),
                const SizedBox(width: 22),
                Expanded(flex: 5, child: Column(children: [
                  historia,
                  const SizedBox(height: 16),
                  insignias,
                ])),
              ])
            : Column(children: [
                ZankyCrece(puntos: progreso.puntos, nivel: progreso.nivel.numero,
                  idGuardian: perfil?.id, hora: widget.hora),
                const SizedBox(height: 16),
                historia,
                const SizedBox(height: 16),
                insignias,
                const SizedBox(height: 16),
                ranking,
              ]);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(margen, 12, margen, 28),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1220), child: contenido,
          )),
        );
      }),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.titulo, required this.icono, required this.contenido});
  final String titulo;
  final IconData icono;
  final Widget contenido;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Zc.superficie, borderRadius: BorderRadius.circular(Zr.l),
      border: Border.all(color: Zc.linea)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icono, color: Zc.hoja, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(titulo, style: Theme.of(context).textTheme.titleLarge)),
      ]),
      const SizedBox(height: 14),
      contenido,
    ]),
  );
}

class _HistoriaCrecimiento extends StatelessWidget {
  const _HistoriaCrecimiento({required this.reportes});
  final List<Reporte> reportes;

  @override
  Widget build(BuildContext context) {
    final ganadores = reportes.where((r) => r.estado.validado).toList()
      ..sort((a, b) => (b.cambiadoEn ?? b.capturadoEn)
        .compareTo(a.cambiadoEn ?? a.capturadoEn));
    return _Tarjeta(titulo: 'Así creció Zanky', icono: Icons.history_rounded,
      contenido: ganadores.isEmpty
          ? const Text('Cuando la CRA valide un reporte, verás aquí cada punto que hizo crecer a Zanky.')
          : Column(children: [
              for (final r in ganadores) Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 38, height: 38, alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Zc.hojaClara, shape: BoxShape.circle),
                    child: IconoAmenaza(r.tipo, tamano: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r.tipo.corto} · ${r.zonaNombre}',
                      style: Theme.of(context).textTheme.titleSmall),
                    Text(_detallePuntos(r), style: Theme.of(context).textTheme.bodySmall),
                    Text(_fecha(r.cambiadoEn ?? r.capturadoEn),
                      style: Theme.of(context).textTheme.labelSmall),
                  ])),
                  Text('+${Progreso.puntosDe(r)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Zc.hoja)),
                ]),
              ),
            ]),
    );
  }

  static String _detallePuntos(Reporte r) {
    final partes = <String>['50 por validación'];
    if (r.fotoDeCamara) partes.add('10 por foto propia');
    if (r.prioridad >= 4) partes.add('10 por prioridad alta');
    if (r.estado == EstadoReporte.alertaOficial ||
        r.estado == EstadoReporte.enAtencion || r.estado == EstadoReporte.cerrado) {
      partes.add('30 por acción oficial');
    }
    return partes.join(' · ');
  }

  static String _fecha(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
}

class _ProximasInsignias extends StatelessWidget {
  const _ProximasInsignias({required this.progreso});
  final Progreso progreso;

  @override
  Widget build(BuildContext context) {
    final proximas = Insignia.todas.where((i) => !progreso.insignias.contains(i.id)).take(3).toList();
    return _Tarjeta(titulo: 'Próximas insignias', icono: Icons.workspace_premium_rounded,
      contenido: proximas.isEmpty
          ? const Text('Ya reuniste todas las insignias disponibles. ¡Sigue cuidando el manglar!')
          : Column(children: [
              for (final i in proximas) Padding(padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Container(width: 42, height: 42, alignment: Alignment.center,
                    decoration: BoxDecoration(color: i.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(i.icono, color: i.color)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.nombre, style: Theme.of(context).textTheme.titleSmall),
                    Text(i.como, style: Theme.of(context).textTheme.bodySmall),
                  ])),
                ])),
            ]),
    );
  }
}

class _RankingColegios extends StatelessWidget {
  const _RankingColegios({required this.colegio, required this.configurado,
    required this.resultado, required this.alReintentar});
  final String colegio;
  final bool configurado;
  final Future<List<ColegioEnRanking>>? resultado;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) => _Tarjeta(
    titulo: 'Zanky de tu colegio', icono: Icons.school_rounded,
    contenido: !configurado || resultado == null
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Demostración · El ranking aparecerá cuando se conecte el servidor. No hay posiciones inventadas.'),
            if (colegio.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10),
              child: Text('Tu colegio: $colegio')),
          ])
        : FutureBuilder<List<ColegioEnRanking>>(
            future: resultado,
            builder: (context, datos) {
              if (datos.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (datos.hasError) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('No se pudo cargar el ranking de colegios.'),
                  TextButton(onPressed: alReintentar, child: const Text('Reintentar')),
                ]);
              }
              final filas = datos.data ?? const <ColegioEnRanking>[];
              if (filas.isEmpty) return const Text('Aún no hay colegios con reportes validados.');
              return Column(children: [
                for (final fila in filas) Padding(padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colegio.isNotEmpty && fila.nombre.toLowerCase().trim() == colegio.toLowerCase().trim()
                          ? Zc.hojaClara : Zc.arena,
                      borderRadius: BorderRadius.circular(Zr.s)),
                    child: Row(children: [
                      Text('${fila.puesto}.', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(width: 10),
                      Expanded(child: Text(fila.nombre, style: Theme.of(context).textTheme.bodyMedium)),
                      Text('${fila.validados} validados', style: Theme.of(context).textTheme.labelMedium),
                    ]),
                  )),
              ]);
            },
          ),
  );
}
