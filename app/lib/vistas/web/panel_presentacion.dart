import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../nucleo/base/entrada_escalonada.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';
import 'abrir_enlace.dart';
import 'entrada_qr.dart';

/// TODO: número de WhatsApp del bot de Zanky, con indicativo y sin «+» ni espacios (ej. '573001234567').
/// Mientras esté vacío, el botón de WhatsApp NO se muestra.
const String kWhatsappZanky = '';

/// Qué parte del panel se pinta: en pantallas muy anchas va repartido a los dos lados del teléfono.
enum PartePanel { izquierda, derecha, todo }

/// Panel de presentación del escritorio: qué es Zanky, qué hace y cómo abrirla en el teléfono.
class PanelPresentacion extends StatelessWidget {
  const PanelPresentacion({super.key, required this.parte});
  final PartePanel parte;

  @override
  Widget build(BuildContext context) {
    final izq = parte != PartePanel.derecha;
    final der = parte != PartePanel.izquierda;
    var i = 0;
    final hijos = <Widget>[
      if (izq) EntradaEscalonada(index: i++, child: const _Presentacion()),
      if (izq) EntradaEscalonada(index: i++, child: const _TresCosas()),
      if (der) EntradaEscalonada(index: i++, child: const _TarjetaQr()),
      if (der) EntradaEscalonada(index: i++, child: const _Fuentes()),
    ];
    return LayoutBuilder(builder: (context, c) {
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight - 56),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var k = 0; k < hijos.length; k++) ...[
                  if (k > 0) const SizedBox(height: 28),
                  hijos[k],
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}

const _blancoSuave = Color(0xFFDDF2F2);

class _Presentacion extends StatelessWidget {
  const _Presentacion();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ZankyMascota(tamano: 132),
        const SizedBox(height: 10),
        Text('Zanky', style: t.displaySmall!.copyWith(color: Colors.white, fontSize: 44)),
        const SizedBox(height: 2),
        Text('Guardianes del manglar', style: t.titleLarge!.copyWith(color: Zc.solClaro, fontSize: 21)),
        const SizedBox(height: 14),
        Text(
          'El manglar del Atlántico cuida la costa, el agua y a la gente. Si ves tala, basura, fuego o un '
          'vertimiento, cuéntaselo a Zanky en segundos, aunque estés sin señal.',
          style: t.bodyLarge!.copyWith(color: _blancoSuave, height: 1.5),
        ),
      ],
    );
  }
}

class _TresCosas extends StatelessWidget {
  const _TresCosas();

  static const _items = [
    (Icons.add_a_photo_rounded, 'Reporta lo que ves', 'Una foto y tu ubicación bastan. Queda guardado aunque no haya señal.'),
    (Icons.map_rounded, 'Mira el manglar', 'El mapa con las cuatro zonas que cuida la autoridad ambiental.'),
    (Icons.workspace_premium_rounded, 'Crece como guardián', 'Ganas puntos e insignias cuando tus reportes se validan.'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Icon(_items[i].$1, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_items[i].$2, style: t.titleMedium!.copyWith(color: Colors.white, fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(_items[i].$3, style: t.bodyMedium!.copyWith(color: _blancoSuave)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TarjetaQr extends StatefulWidget {
  const _TarjetaQr();
  @override
  State<_TarjetaQr> createState() => _TarjetaQrState();
}

class _TarjetaQrState extends State<_TarjetaQr> {
  bool _copiado = false;

  static const _nombres = {
    'mallorquin': 'la Ciénaga de Mallorquín',
    'tubara': 'la Costa de Tubará',
    'juan_de_acosta': 'la Costa de Juan de Acosta',
    'piojo': 'la Ciénaga del Totumo',
  };

  String get _url => Uri.base.removeFragment().toString();

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: _url));
    if (!mounted) return;
    setState(() => _copiado = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copiado = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Zr.l),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ábrela en tu teléfono', style: t.titleLarge!.copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          Text('Apunta la cámara al código. No necesitas instalar nada.',
              style: t.bodyMedium!.copyWith(color: _blancoSuave)),
          const SizedBox(height: 16),
          Center(
            child: Semantics(
              label: 'Código QR para abrir Zanky en el teléfono',
              image: true,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Zr.m)),
                child: QrImageView(
                  data: _url,
                  size: 176,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Zc.raiz),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Zc.raiz),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pastilla(
                icono: _copiado ? Icons.check_rounded : Icons.link_rounded,
                texto: _copiado ? 'Enlace copiado' : 'Copiar enlace',
                onTap: _copiar,
              ),
              if (kWhatsappZanky.isNotEmpty)
                _Pastilla(
                  icono: Icons.chat_rounded,
                  texto: 'Escríbele por WhatsApp',
                  relleno: true,
                  onTap: () => abrirEnlace('https://wa.me/$kWhatsappZanky?text=${Uri.encodeComponent('Hola, Zanky')}'),
                ),
            ],
          ),
          ValueListenableBuilder<EntradaQr?>(
            valueListenable: entradaQr,
            builder: (context, e, _) {
              final zona = _nombres[e?.zonaId];
              if (zona == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text('Llegaste desde el letrero de $zona.',
                    style: t.bodySmall!.copyWith(color: Zc.solClaro, fontWeight: FontWeight.w600)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  const _Pastilla({required this.icono, required this.texto, required this.onTap, this.relleno = false});
  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final bool relleno;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = relleno ? Zc.raiz : Colors.white;
    return Presionable(
      etiqueta: texto,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: relleno ? Zc.solClaro : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: relleno ? 0 : 0.26)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 19, color: color),
            const SizedBox(width: 8),
            Text(texto, style: t.labelLarge!.copyWith(color: color, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _Fuentes extends StatelessWidget {
  const _Fuentes();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Text(
      'Datos: CRA (cartografía 1:5.000) · OpenStreetMap · Open-Meteo',
      style: t.bodySmall!.copyWith(color: _blancoSuave.withValues(alpha: 0.85)),
    );
  }
}
