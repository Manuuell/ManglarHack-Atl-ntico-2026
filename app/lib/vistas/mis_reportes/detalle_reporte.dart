import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../datos/estado.dart';
import '../../datos/reporte.dart';
import '../../datos/tipos.dart';
import '../../nucleo/base/entrada_escalonada.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/comunes.dart';
import 'foto_reporte.dart';
import 'linea_tiempo.dart';
import 'mapa_detalle.dart';

/// Abre el detalle de un reporte con la transición de página de iOS (la del tema).
/// La usan «Mis reportes» y el mapa.
Future<void> abrirDetalleReporte(BuildContext context, Reporte reporte) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      settings: RouteSettings(name: 'reporte/${reporte.id}'),
      builder: (_) => PantallaDetalleReporte(reporte: reporte),
    ),
  );
}

class PantallaDetalleReporte extends StatelessWidget {
  const PantallaDetalleReporte({super.key, required this.reporte});
  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    // El reporte es el mismo objeto que vive en el estado: al llegar un cambio de la
    // CRA (o terminar un envío) esta pantalla se redibuja sola.
    final e = Zanky.de(context);
    final r = reporte;
    final tt = Theme.of(context).textTheme;
    final zona = e.manglar.zonas.where((z) => z.id == r.zonaId).firstOrNull;
    final abajo = MediaQuery.paddingOf(context).bottom;

    final secciones = <Widget>[
      _Titulo(reporte: r),
      if (r.estado == EstadoReporte.descartado) _AvisoDescartado(reporte: r),
      _Tarjeta(
        titulo: 'El camino de tu reporte',
        child: LineaTiempo(reporte: r),
      ),
      _Tarjeta(
        titulo: '¿Por qué esta prioridad?',
        encabezado: PildoraPrioridad(r.prioridad),
        child: _Motivos(reporte: r),
      ),
      _Tarjeta(
        titulo: 'Solidez del reporte',
        child: _Solidez(valor: r.confianza),
      ),
      _Tarjeta(
        titulo: 'Dónde fue',
        relleno: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Zr.l)),
              child: RepaintBoundary(child: MapaDetalle(reporte: r, zona: zona)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    r.dentroPoligono ? Icons.park_rounded : Icons.near_me_rounded,
                    size: 20,
                    color: r.dentroPoligono ? Zc.hoja : Zc.fango,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_textoUbicacion(r), style: tt.bodyLarge)),
                ],
              ),
            ),
          ],
        ),
      ),
      _Tarjeta(titulo: 'Los datos', child: _Datos(reporte: r)),
      _Acciones(reporte: r),
    ];

    return Scaffold(
      backgroundColor: Zc.arena,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Cabecera(reporte: r)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 28 + abajo),
            sliver: SliverList.separated(
              itemCount: secciones.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) => EntradaEscalonada(index: i, child: secciones[i]),
            ),
          ),
        ],
      ),
    );
  }

  static String _textoUbicacion(Reporte r) {
    if (r.dentroPoligono) return 'Dentro del manglar · ${r.zonaNombre}';
    final d = r.distanciaM;
    if (!d.isFinite) return 'Fuera del manglar · ${r.zonaNombre}';
    if (d < 1000) return 'A ${d.round()} m del manglar · ${r.zonaNombre}';
    return 'A ${(d / 1000).toStringAsFixed(1)} km del manglar · ${r.zonaNombre}';
  }
}

// ---------------------------------------------------------------------------
// Cabecera: foto grande (Hero) o color del tipo

class _Cabecera extends StatefulWidget {
  const _Cabecera({required this.reporte});
  final Reporte reporte;

  @override
  State<_Cabecera> createState() => _CabeceraState();
}

class _CabeceraState extends State<_Cabecera> {
  late Future<Uint8List?> _futuro = CacheFotos.de(widget.reporte);

  @override
  void didUpdateWidget(_Cabecera old) {
    super.didUpdateWidget(old);
    if (old.reporte.id != widget.reporte.id) _futuro = CacheFotos.de(widget.reporte);
  }

  void _verFoto(Uint8List bytes) {
    Navigator.of(context).push<void>(PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: context.resolveDuration(Zm.medio),
      reverseTransitionDuration: context.resolveDuration(Zm.corto),
      pageBuilder: (_, _, _) => _VisorFoto(bytes: bytes, caso: widget.reporte.caso),
      transitionsBuilder: (_, a, _, hijo) => FadeTransition(opacity: a, child: hijo),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reporte;
    final arriba = MediaQuery.paddingOf(context).top;
    final alto = 300 + arriba;
    final inicial = CacheFotos.tiene(r.id) ? CacheFotos.sincrono(r.id) : null;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(Zr.l)),
      child: SizedBox(
        height: alto,
        child: FutureBuilder<Uint8List?>(
          future: _futuro,
          initialData: inicial,
          builder: (context, snap) {
            final bytes = snap.data;
            final sinFoto = r.fotoRef == null || (snap.connectionState == ConnectionState.done && bytes == null);
            return Stack(
              fit: StackFit.expand,
              children: [
                if (sinFoto)
                  _FondoTipo(tipo: r.tipo)
                else
                  Positioned.fill(
                    child: FotoReporte(reporte: r, hero: true, cacheAncho: 1080),
                  ),
                // Sombra arriba: que los botones se lean sobre cualquier foto.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: arriba + 80,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x730B2E24), Color(0x000B2E24)],
                        ),
                      ),
                    ),
                  ),
                ),
                if (bytes != null)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _verFoto(bytes),
                    ),
                  ),
                Positioned(
                  top: arriba + 8,
                  left: 12,
                  child: _BotonRedondo(
                    icono: Icons.arrow_back_ios_new_rounded,
                    etiqueta: 'Volver a mis reportes',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                if (bytes != null)
                  Positioned(
                    top: arriba + 8,
                    right: 12,
                    child: _BotonRedondo(
                      icono: Icons.open_in_full_rounded,
                      etiqueta: 'Ver la foto a pantalla completa',
                      onTap: () => _verFoto(bytes),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FondoTipo extends StatelessWidget {
  const _FondoTipo({required this.tipo});
  final TipoAmenaza tipo;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tipo.color, Color.lerp(tipo.color, Zc.raiz, 0.55)!],
          ),
        ),
        child: Center(
          child: ExcludeSemantics(
            child: Icon(tipo.icono, size: 120, color: Zc.superficie.withValues(alpha: 0.35)),
          ),
        ),
      );
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({required this.icono, required this.etiqueta, required this.onTap});
  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Presionable(
        onTap: onTap,
        escala: 0.9,
        etiqueta: etiqueta,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Zc.superficie.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Color(0x290B2E24), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Icon(icono, size: 19, color: Zc.texto),
        ),
      );
}

/// La foto a pantalla completa: pellizco para acercar, doble toque para alternar.
class _VisorFoto extends StatefulWidget {
  const _VisorFoto({required this.bytes, required this.caso});
  final Uint8List bytes;
  final String caso;

  @override
  State<_VisorFoto> createState() => _VisorFotoState();
}

class _VisorFotoState extends State<_VisorFoto> with SingleTickerProviderStateMixin {
  final _control = TransformationController();
  late final AnimationController _anim = AnimationController(vsync: this);
  Offset _ultimoToque = Offset.zero;

  static const _acercado = 2.6;

  @override
  void dispose() {
    _anim.dispose();
    _control.dispose();
    super.dispose();
  }

  void _dobleToque() {
    final acercada = _control.value.getMaxScaleOnAxis() > 1.05;
    final p = _ultimoToque;
    final s = _acercado;
    final destino = acercada
        ? Matrix4.identity()
        : Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, p.dx * (1 - s), p.dy * (1 - s), 0, 1);
    if (context.animationsDisabled) {
      _control.value = destino;
      return;
    }
    final anim = Matrix4Tween(begin: _control.value, end: destino).animate(
      CurvedAnimation(parent: _anim, curve: Zm.entrar),
    );
    void paso() => _control.value = anim.value;
    _anim
      ..duration = Zm.medio
      ..reset()
      ..addListener(paso)
      ..forward().whenCompleteOrCancel(() => _anim.removeListener(paso));
  }

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Zc.raiz,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onDoubleTapDown: (d) => _ultimoToque = d.localPosition,
            onDoubleTap: _dobleToque,
            child: InteractiveViewer(
              transformationController: _control,
              minScale: 1,
              maxScale: 6,
              child: Center(
                child: Semantics(
                  image: true,
                  label: 'Foto del reporte ${widget.caso}',
                  child: Image.memory(widget.bytes, fit: BoxFit.contain, gaplessPlayback: true),
                ),
              ),
            ),
          ),
          Positioned(
            top: arriba + 8,
            right: 12,
            child: _BotonRedondo(
              icono: Icons.close_rounded,
              etiqueta: 'Cerrar la foto',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Título, avisos y tarjetas

class _Titulo extends StatelessWidget {
  const _Titulo({required this.reporte});
  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final r = reporte;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconoTipo(r.tipo, tamano: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(r.tipo.nombre, style: tt.headlineSmall)),
                    Text('Caso ${r.caso}', style: tt.labelLarge?.copyWith(color: Zc.hoja)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChipEstado(r),
              PildoraPrioridad(r.prioridad),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvisoDescartado extends StatelessWidget {
  const _AvisoDescartado({required this.reporte});
  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final nota = reporte.historial
        .where((c) => c.estado == EstadoReporte.descartado)
        .map((c) => (c.nota ?? '').trim())
        .where((n) => n.isNotEmpty)
        .lastOrNull;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Zc.cienagaClara,
        borderRadius: BorderRadius.circular(Zr.m),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.favorite_rounded, size: 20, color: Zc.cienaga),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No se pudo confirmar este reporte', style: tt.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'No es culpa tuya: a veces desde lejos la foto o el sitio no bastan para comprobarlo. '
                  'Tu aviso sirvió igual. Si lo sigues viendo, vuelve a reportar con una foto más clara.',
                  style: tt.bodyMedium?.copyWith(color: Zc.texto),
                ),
                if (nota != null) ...[
                  const SizedBox(height: 8),
                  Text('Nota de la revisión: $nota', style: tt.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.titulo, required this.child, this.encabezado, this.relleno = true});
  final String titulo;
  final Widget child;
  final Widget? encabezado;

  /// Falso cuando el contenido va de borde a borde (el mapa).
  final bool relleno;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cabecera = Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, relleno ? 12 : 12),
      child: Row(
        children: [
          Expanded(child: Semantics(header: true, child: Text(titulo, style: tt.titleMedium))),
          if (encabezado != null) ...[const SizedBox(width: 8), encabezado!],
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: Zc.superficie,
        borderRadius: BorderRadius.circular(Zr.l),
        border: Border.all(color: Zc.linea.withValues(alpha: 0.7)),
        boxShadow: const [BoxShadow(color: Color(0x0F0B2E24), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cabecera,
          if (relleno)
            Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), child: child)
          else
            child,
        ],
      ),
    );
  }
}

class _Motivos extends StatelessWidget {
  const _Motivos({required this.reporte});
  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color = Zc.dePrioridad(reporte.prioridad);
    final motivos = reporte.motivosPrioridad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (motivos.isEmpty)
          Text('Este reporte no trae el detalle de su prioridad.', style: tt.bodyMedium)
        else
          for (final m in motivos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(m, style: tt.bodyLarge)),
                ],
              ),
            ),
        const SizedBox(height: 4),
        Text(
          'Es una estimación con pesos de prueba. La CRA la ajusta cuando revisa el caso.',
          style: tt.bodySmall?.copyWith(color: Zc.textoTenue),
        ),
      ],
    );
  }
}

class _Solidez extends StatelessWidget {
  const _Solidez({required this.valor});
  final int valor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final v = valor.clamp(0, 100);
    final color = v >= 70 ? Zc.hoja : (v >= 40 ? Zc.sol : Zc.fango);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$v', style: tt.headlineMedium?.copyWith(color: Color.lerp(color, Zc.texto, 0.25))),
            Text(' de 100', style: tt.bodyMedium),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          label: 'Solidez $v de 100',
          excludeSemantics: true,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: v / 100),
            duration: context.resolveDuration(Zm.largo),
            curve: Zm.entrar,
            builder: (context, t, _) => CustomPaint(
              size: const Size(double.infinity, 10),
              painter: _PintorBarra(t, color),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'La decide una persona de la CRA o un vigía; la foto en el sitio y la ubicación precisa la suben.',
          style: tt.bodyMedium,
        ),
      ],
    );
  }
}

class _PintorBarra extends CustomPainter {
  _PintorBarra(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pista = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height));
    canvas.drawRRect(pista, Paint()..color = Zc.linea);
    if (t <= 0) return;
    final ancho = (size.width * t).clamp(size.height, size.width);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, ancho, size.height), Radius.circular(size.height)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_PintorBarra o) => o.t != t || o.color != color;
}

class _Datos extends StatelessWidget {
  const _Datos({required this.reporte});
  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final r = reporte;
    final enviado = r.envio == Envio.enviado;
    final p = r.precisionM;
    final filas = <(String, String)>[
      ('Lo viste', fechaLarga(r.capturadoEn)),
      (
        'Llegó a la CRA',
        enviado
            ? (r.enviadoEn != null ? fechaLarga(r.enviadoEn!) : 'Ya llegó')
            : (r.envio == Envio.enviando ? 'Enviándose ahora' : 'Todavía no: sigue en tu teléfono'),
      ),
      if (r.capturadoSinSenal)
        (
          'Conexión',
          enviado
              ? 'Se capturó sin señal y se envió al volver la conexión'
              : 'Se capturó sin señal; saldrá al volver la conexión',
        ),
      ('Ubicación', '${r.metodo.nombre}${p != null ? ' · precisión de unos ${p.round()} m' : ''}'),
      ('Cuándo pasó', r.momento.nombre),
      ('Tamaño', '${r.magnitud.nombre} · ${r.magnitud.ejemplo.toLowerCase()}'),
      (
        'Foto',
        r.fotoRef == null
            ? 'Sin foto'
            : (r.fotoDeCamara ? 'Tomada con la cámara en el momento' : 'Elegida de la galería'),
      ),
      ('Reporte anónimo', r.anonimo ? 'Sí: no lleva tu nombre' : 'No: va con tu perfil'),
    ];
    final descripcion = r.descripcion.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (k, v) in filas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: Text(k, style: tt.bodySmall)),
                const SizedBox(width: 8),
                Expanded(flex: 6, child: Text(v, style: tt.bodyMedium?.copyWith(color: Zc.texto))),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text('Lo que contaste', style: tt.bodySmall),
        const SizedBox(height: 4),
        Text(
          descripcion.isEmpty ? 'No escribiste descripción.' : descripcion,
          style: tt.bodyLarge?.copyWith(color: descripcion.isEmpty ? Zc.textoTenue : Zc.texto),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Acciones

class _Acciones extends StatelessWidget {
  const _Acciones({required this.reporte});
  final Reporte reporte;

  /// Solo lo que se puede decir en voz alta: caso, tipo, zona y estado. Nunca las
  /// coordenadas ni nada del perfil (aunque el reporte no sea anónimo).
  String _texto() {
    final r = reporte;
    final estado = r.envio == Envio.enviado ? r.estado.nombre : 'Guardado en mi teléfono, aún sin enviar';
    return 'Reporté un problema en el manglar con Zanky.\n'
        'Caso: ${r.caso}\n'
        'Qué: ${r.tipo.nombre}\n'
        'Zona: ${r.zonaNombre}\n'
        'Estado: $estado';
  }

  Future<void> _compartir(BuildContext context) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await SharePlus.instance.share(ShareParams(text: _texto(), subject: 'Caso ${reporte.caso} en Zanky'));
    } catch (_) {
      mensajero.showSnackBar(const SnackBar(content: Text('No pude abrir el menú de compartir.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = Zanky.de(context);
    final r = reporte;
    final conError = r.envio == Envio.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (conError) ...[
          BotonZ(
            texto: 'Reintentar envío',
            icono: Icons.refresh_rounded,
            color: Zc.sol,
            colorTexto: Zc.raiz,
            cargando: e.sincronizando,
            onTap: () => Zanky.leer(context).sincronizar(),
          ),
          const SizedBox(height: 12),
        ],
        BotonZ(
          texto: 'Compartir el número de caso',
          icono: Icons.ios_share_rounded,
          secundario: conError,
          onTap: () => _compartir(context),
        ),
        const SizedBox(height: 10),
        Text(
          'Al compartir solo salen el número de caso, el tipo, la zona y el estado. Nunca la ubicación exacta.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
