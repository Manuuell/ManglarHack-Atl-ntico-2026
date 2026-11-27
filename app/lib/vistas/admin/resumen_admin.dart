import 'package:flutter/material.dart';

import '../../datos/admin/controlador_admin.dart';
import '../../datos/admin/reporte_admin.dart';
import '../../datos/tipos.dart';
import '../../nucleo/base/esqueleto.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';
import 'piezas_admin.dart';

enum _Periodo { hoy, semana }

/// Las cifras del día y de la semana con barras sencillas: cuántos llegaron, cuántos
/// de prioridad alta, cuántos esperan y de dónde y de qué tipo son.
class ResumenAdmin extends StatefulWidget {
  const ResumenAdmin({super.key, required this.controlador});
  final ControladorAdmin controlador;

  @override
  State<ResumenAdmin> createState() => _ResumenAdminState();
}

class _ResumenAdminState extends State<ResumenAdmin> {
  _Periodo _periodo = _Periodo.hoy;

  @override
  Widget build(BuildContext context) {
    final c = widget.controlador;
    if (!c.cargado) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [Esqueleto.cabecera(), SizedBox(height: 12), Esqueleto.lista(3)],
      );
    }
    final ahora = c.reloj();
    final desde = _periodo == _Periodo.hoy ? inicioDelDia(ahora) : inicioDeLaSemana(ahora);
    final cifras = resumir(c.reportes, desde);
    final dias = porDia(c.reportes, ahora);
    final nombrePeriodo = _periodo == _Periodo.hoy ? 'hoy' : 'en los últimos 7 días';
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        if (c.demostracion) FranjaDemo(controlador: c),
        SegmentosZ<_Periodo>(
          valores: _Periodo.values,
          actual: _periodo,
          nombre: (p) => p == _Periodo.hoy ? 'Hoy' : '7 días',
          alCambiar: (p) => setState(() => _periodo = p),
        ),
        const SizedBox(height: 14),
        if (cifras.vacio)
          VacioAdmin(
            titulo: 'Sin reportes $nombrePeriodo',
            detalle: 'Cuando lleguen, aquí verás cuántos son, de dónde y de qué tipo.',
            animo: Animo.curioso,
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Gran(valor: cifras.nuevos, titulo: 'Nuevos', color: Zc.cienaga, icono: Icons.inbox_rounded),
                _Gran(valor: cifras.altaPrioridad, titulo: 'Alta prioridad', color: Zc.prioridad[5]!, icono: Icons.priority_high_rounded),
                _Gran(valor: cifras.pendientes, titulo: 'Esperan decisión', color: Zc.sol, icono: Icons.hourglass_top_rounded),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SeccionAdmin(
            titulo: 'Por zona',
            child: _Barras<String>(
              datos: cifras.porZona,
              etiqueta: (z) => z,
              color: (_) => Zc.cienaga,
            ),
          ),
          SeccionAdmin(
            titulo: 'Por tipo',
            child: _Barras<TipoAmenaza>(
              datos: cifras.porTipo,
              etiqueta: (t) => t.nombre,
              color: (t) => t.color,
            ),
          ),
        ],
        SeccionAdmin(
          titulo: 'Últimos 7 días',
          nota: 'Reportes que llegaron cada día',
          child: _BarrasDias(cuentas: dias, ahora: ahora),
        ),
      ],
    );
  }
}

class _Gran extends StatelessWidget {
  const _Gran({required this.valor, required this.titulo, required this.color, required this.icono});
  final int valor;
  final String titulo;
  final Color color;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$titulo: $valor',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Zc.superficie,
          borderRadius: BorderRadius.circular(Zr.l),
          border: Border.all(color: Zc.linea.withValues(alpha: 0.7)),
          boxShadow: const [BoxShadow(color: Color(0x0F0B2E24), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icono, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(child: Text(titulo, style: tt.labelMedium)),
            ]),
            const SizedBox(height: 6),
            ContadorAnimado(valor: valor.toDouble(), formato: (v) => v.round().toString(), estilo: tt.displaySmall?.copyWith(color: Zc.texto)),
          ],
        ),
      ),
    );
  }
}

/// Barras horizontales ordenadas de más a menos, con el número al final.
class _Barras<K> extends StatelessWidget {
  const _Barras({required this.datos, required this.etiqueta, required this.color});
  final Map<K, int> datos;
  final String Function(K) etiqueta;
  final Color Function(K) color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final tope = datos.values.fold<int>(1, (a, b) => b > a ? b : a);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Zc.superficie,
        borderRadius: BorderRadius.circular(Zr.l),
        border: Border.all(color: Zc.linea.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          for (final e in datos.entries)
            Semantics(
              container: true,
              label: '${etiqueta(e.key)}: ${e.value} ${e.value == 1 ? 'reporte' : 'reportes'}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(etiqueta(e.key), style: tt.bodyMedium?.copyWith(color: Zc.texto))),
                        const SizedBox(width: 8),
                        Text('${e.value}', style: tt.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _Barra(fraccion: e.value / tope, color: color(e.key)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({required this.fraccion, required this.color});
  final double fraccion;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: 10,
        color: Zc.arena,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fraccion.clamp(0.04, 1.0)),
          duration: context.resolveDuration(AppMotion.slow),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => FractionallySizedBox(widthFactor: v, child: Container(color: color)),
        ),
      ),
    );
  }
}

/// Siete columnas, la última es hoy.
class _BarrasDias extends StatelessWidget {
  const _BarrasDias({required this.cuentas, required this.ahora});
  final List<int> cuentas;
  final DateTime ahora;

  static const _dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final tope = cuentas.fold<int>(1, (a, b) => b > a ? b : a);
    final total = cuentas.fold<int>(0, (a, b) => a + b);
    return Semantics(
      container: true,
      label: 'Reportes de los últimos 7 días: ${cuentas.join(', ')}. Total $total.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
        decoration: BoxDecoration(
          color: Zc.superficie,
          borderRadius: BorderRadius.circular(Zr.l),
          border: Border.all(color: Zc.linea.withValues(alpha: 0.7)),
        ),
        child: SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < cuentas.length; i++)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${cuentas[i]}', style: tt.labelMedium),
                      const SizedBox(height: 4),
                      Flexible(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: cuentas[i] / tope),
                          duration: context.resolveDuration(AppMotion.slow),
                          curve: Curves.easeOutBack,
                          builder: (_, v, _) => Container(
                            width: 18,
                            height: 4 + 64 * v.clamp(0.0, 1.2),
                            decoration: BoxDecoration(
                              color: i == cuentas.length - 1 ? Zc.hoja : Zc.cienaga.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(_dias[ahora.subtract(Duration(days: cuentas.length - 1 - i)).weekday - 1], style: tt.labelSmall),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
