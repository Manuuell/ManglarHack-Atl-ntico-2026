import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../datos/estado.dart';
import '../../datos/guardian.dart';
import '../../datos/roles.dart';
import '../../nucleo/base/entrada_escalonada.dart';
import '../../nucleo/base/transicion_pestanas.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/celebracion.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/tema.dart';
import '../admin/entrada_panel.dart';
import '../gestion/entrada_gestor.dart';
import '../admin/panel_cra.dart';
import '../admin/piezas_admin.dart';
import '../comun/comunes.dart';
import '../comun/zanky_mascota.dart';
import '../reporte/flujo_reporte.dart';
import '../roles/selector_rol.dart';
import 'editar_perfil.dart';
import 'insignias_guardian.dart';
import '../experiencia/widgets_evento.dart' show ResumenParticipacion;
import 'nivel_guardian.dart';
import '../crecimiento/pantalla_mi_manglar.dart';
import '../crecimiento/zanky_crece.dart';
import 'tarjeta_guardian.dart';

/// Guardián: la tarjeta digital, el nivel, las insignias, la misión de la semana y los
/// colegios. Responde a «¿cómo se sostiene la participación?»: la gente vuelve porque ve
/// su impacto y siente que hace parte, sin premiar el spam (solo cuenta lo validado).
class PantallaGuardian extends StatefulWidget {
  const PantallaGuardian({super.key});

  @override
  State<PantallaGuardian> createState() => _PantallaGuardianState();
}

class _PantallaGuardianState extends State<PantallaGuardian> {
  static const _claveCelebradas = 'guardian.celebradas.v1';
  static const _claveNivel = 'guardian.nivel.v1';
  bool _revisando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _dejarSalEscrita());
  }

  /// Un perfil de la versión anterior no tenía sal: se creó al cargarlo y, hasta que se
  /// guarde, el código público cambiaría en cada arranque. Se deja escrita una vez.
  Future<void> _dejarSalEscrita() async {
    if (!mounted) return;
    final estado = Zanky.leer(context);
    final p = estado.perfil;
    if (p == null || !p.salPendiente) return;
    try {
      await estado.guardarPerfil(p);
      p.salPendiente = false;
    } catch (_) {
      // Sin espacio: se reintenta la próxima vez que se abra esta pantalla.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Solo se celebra con la pestaña a la vista: una celebración sobre otra pestaña
    // sería un susto. Al abrirla, didChangeDependencies vuelve a pasar por aquí.
    if (PestanaVisible.de(context)) {
      final progreso = Zanky.de(context).progreso;
      WidgetsBinding.instance.addPostFrameCallback((_) => _celebrar(progreso));
    }
  }

  /// Cada insignia se celebra UNA vez: se anota antes de mostrarla.
  Future<void> _celebrar(Progreso progreso) async {
    if (_revisando || !mounted) return;
    _revisando = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ya = (prefs.getStringList(_claveCelebradas) ?? const <String>[]).toSet();
      final nuevas = [for (final i in Insignia.todas) if (progreso.insignias.contains(i.id) && !ya.contains(i.id)) i];
      // Subida de nivel: se compara con el último nivel celebrado (nivel 1 de partida, sin fiesta).
      final nivel = progreso.nivel;
      final visto = prefs.getInt(_claveNivel) ?? 1;
      final subio = nivel.numero > visto;
      if (nivel.numero != visto) await prefs.setInt(_claveNivel, nivel.numero);
      if (nuevas.isEmpty && !subio) return;
      if (nuevas.isNotEmpty) {
        await prefs.setStringList(_claveCelebradas, {...ya, for (final i in nuevas) i.id}.toList());
      }
      if (subio && mounted) {
        // El ✓ con confeti y, a la vez, el aviso con el nombre del nivel; las insignias esperan su turno.
        final fiesta = celebrar(context, etiqueta: 'Subiste al nivel ${nivel.numero}: ${nivel.nombre}', grande: true);
        avisar(context, 'Nivel ${nivel.numero}: ${nivel.nombre}', tipo: TipoAviso.exito);
        await fiesta;
      }
      for (final i in nuevas) {
        if (!mounted) return;
        await mostrarCelebracion(context, i);
      }
    } catch (_) {
      // Celebrar es un extra: si el teléfono no deja guardar, la pantalla sigue igual.
    } finally {
      _revisando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = Zanky.de(context);
    final perfil = estado.perfil;
    final progreso = estado.progreso;
    final rol = perfil?.rol ?? RolUsuario.ciudadano;
    final secciones = [
      for (final sec in seccionesDeGuardian(rol, conPerfil: perfil != null))
        switch (sec) {
          SeccionGuardian.tarjeta =>
            perfil != null ? SeccionTarjeta(perfil: perfil, progreso: progreso) : const _SinPerfil(),
          SeccionGuardian.rol => _SeccionRol(rol: rol),
          SeccionGuardian.nivel => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SeccionNivel(progreso: progreso, sinReportes: estado.reportes.isEmpty),
                const SizedBox(height: 12),
                ZankyCreceCompacto(
                  puntos: progreso.puntos,
                  alAbrir: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PantallaMiManglar())),
                ),
              ],
            ),
          SeccionGuardian.puntos => SeccionPuntos(servidorConectado: estado.servidor.configurado),
          SeccionGuardian.participacion => const ResumenParticipacion(),
          SeccionGuardian.mision => const _MisionSemana(),
          SeccionGuardian.insignias => SeccionInsignias(progreso: progreso),
          SeccionGuardian.colegios => _Colegios(
              colegio: perfil?.colegio.trim() ?? '',
              servidorConectado: estado.servidor.configurado,
            ),
          SeccionGuardian.panel => const Column(
            children: [EntradaPanelCra(), SizedBox(height: 10), EntradaGestor()],
          ),
        },
    ];
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          CabeceraZ(
            titulo: 'Guardián',
            subtitulo: 'Tu lugar en el manglar',
            accion: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // El ícono del panel solo aparece con la sesión del equipo, con su contador.
                if (AdminScope.maybeDe(context)?.dentro ?? false) ...[
                  BotonIcono(
                    icono: Icons.shield_rounded,
                    etiqueta: 'Panel CRA',
                    cuenta: AdminScope.de(context).sinVer,
                    alTocar: () => abrirPanelCra(context),
                  ),
                  const SizedBox(width: 8),
                ],
                Presionable(
                  etiqueta: 'Editar mi perfil',
                  onTap: () => mostrarEditarPerfil(context),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Zc.superficie,
                      shape: BoxShape.circle,
                      border: Border.all(color: Zc.linea),
                    ),
                    child: const Icon(Icons.edit_rounded, size: 22, color: Zc.raiz),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < secciones.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: EntradaEscalonada(index: i, child: secciones[i]),
            ),
        ],
      ),
    );
  }
}

/// Cómo participas: el rol de la bienvenida, con su ilustración y un toque para cambiarlo.
class _SeccionRol extends StatelessWidget {
  const _SeccionRol({required this.rol});
  final RolUsuario rol;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TarjetaZ(
        onTap: () => mostrarCambiarRol(context),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IlustracionRol(rol, tamano: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TU ROL', style: tt.seccion.copyWith(color: rol.color)),
                  Text(rol.nombre, style: tt.titleMedium),
                  Text(rol.lema, style: tt.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Semantics(
              label: 'Cambiar mi rol',
              excludeSemantics: true,
              child: Text('Cambiar', style: tt.labelMedium?.copyWith(color: Zc.hoja)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sin perfil todavía: invita a crearlo en vez de dejar un hueco.
class _SinPerfil extends StatelessWidget {
  const _SinPerfil();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TarjetaZ(
        child: Column(
          children: [
            const ZankyMascota(tamano: 90, animo: Animo.curioso),
            const SizedBox(height: 8),
            Text('Crea tu tarjeta de guardián', style: tt.titleLarge),
            const SizedBox(height: 6),
            Text('Ponle tu nombre y empieza a crecer con cada reporte validado.',
                textAlign: TextAlign.center, style: tt.bodyMedium),
            const SizedBox(height: 14),
            BotonZ(texto: 'Crear mi perfil', icono: Icons.badge_rounded, onTap: () => mostrarEditarPerfil(context)),
          ],
        ),
      ),
    );
  }
}

/// La misión de la semana: un motivo concreto para volver al manglar.
class _MisionSemana extends StatelessWidget {
  const _MisionSemana();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final hoy = DateTime.now();
    final mision = Mision.deLaSemana(hoy);
    // La misión cambia cada 7 días contados desde el 1 de enero.
    final quedan = 7 - hoy.difference(DateTime(hoy.year)).inDays % 7;
    final plazo = quedan == 1 ? 'Último día: es hoy' : 'Quedan $quedan días';
    const tinta = Color(0xFF7A4800);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Zc.solClaro,
          borderRadius: BorderRadius.circular(Zr.l),
          border: Border.all(color: Zc.sol.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(color: Zc.sol, shape: BoxShape.circle),
                  child: Icon(mision.icono, color: Zc.raiz, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Misión de la semana', style: tt.labelSmall?.copyWith(color: tinta)),
                      const SizedBox(height: 2),
                      Text(mision.titulo, style: tt.titleMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(mision.detalle, style: tt.bodyLarge),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.timelapse_rounded, size: 18, color: tinta),
                const SizedBox(width: 6),
                Text(plazo, style: tt.labelMedium?.copyWith(color: tinta)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Los puntos son los de siempre: lo que cuenta es reportar bien.', style: tt.bodySmall),
            const SizedBox(height: 14),
            BotonZ(
              texto: 'Reportar para esta misión',
              icono: Icons.add_a_photo_rounded,
              color: Zc.raiz,
              onTap: () => abrirReporte(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colegios y servicio social. Sin servidor no hay ranking: se dice, no se inventa.
class _Colegios extends StatelessWidget {
  const _Colegios({required this.colegio, required this.servidorConectado});
  final String colegio;
  final bool servidorConectado;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    Widget punto(IconData i, String t) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(i, size: 22, color: Zc.cienaga),
              const SizedBox(width: 12),
              Expanded(child: Text(t, style: tt.bodyLarge)),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TarjetaZ(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: Zc.cienagaClara, shape: BoxShape.circle),
                  child: const Icon(Icons.school_rounded, color: Zc.cienaga, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Colegios y servicio social', style: tt.titleLarge)),
              ],
            ),
            punto(Icons.schedule_rounded,
                'El monitoreo validado puede contar como horas de servicio social estudiantil. Cada colegio y la CRA definen cómo se certifican.'),
            punto(Icons.eco_rounded, 'También se conecta con el PRAE, el proyecto ambiental escolar de tu colegio.'),
            punto(
              Icons.leaderboard_rounded,
              servidorConectado
                  ? 'El ranking «Guardianes del manglar» aparecerá aquí cuando varios colegios tengan reportes validados.'
                  : 'El ranking «Guardianes del manglar» se activa cuando la app esté conectada al servidor. '
                      'Hoy estás en modo demostración: no hay datos de otros colegios y no inventamos ninguno.',
            ),
            const SizedBox(height: 14),
            if (colegio.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Zc.hojaClara, borderRadius: BorderRadius.circular(Zr.s)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 20, color: Zc.hoja),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Tu colegio: $colegio', style: tt.titleSmall)),
                  ],
                ),
              )
            else
              BotonZ(
                texto: 'Agregar mi colegio',
                icono: Icons.add_rounded,
                secundario: true,
                onTap: () => mostrarEditarPerfil(context),
              ),
          ],
        ),
      ),
    );
  }
}
