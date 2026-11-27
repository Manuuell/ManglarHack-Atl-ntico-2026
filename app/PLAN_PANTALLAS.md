# App Zanqui: plan de pantallas y kit común

Guía para quien construye una pantalla (persona o agente). Antes de escribir, lee `../handoff/06-la-vara-y-aprendizajes.md`
§4 (lista de chequeo por pantalla) y este archivo entero.

## Quién hace qué

| Pantalla | Archivo(s) | Dueño |
|---|---|---|
| Arranque, raíz y barra de pestañas | `lib/main.dart`, `lib/vistas/raiz.dart` | chat principal |
| Inicio | `lib/vistas/inicio/` | chat principal |
| Flujo de reporte (tipo → ubicación → evidencia → detalles → enviar) | `lib/vistas/reporte/` | chat principal |
| Bienvenida + perfil + privacidad | `lib/vistas/bienvenida/` | agente |
| Mapa | `lib/vistas/mapa/` | agente |
| Mis reportes + detalle | `lib/vistas/mis_reportes/` | agente |
| Guardián (tarjeta, nivel, insignias, misiones) | `lib/vistas/guardian/` | agente |

**Cada uno toca solo su carpeta.** Si necesitas cambiar algo común (`lib/datos/`, `lib/nucleo/`, `lib/vistas/comun/`,
`raiz.dart`), no lo cambies: escríbelo en tu informe con el cambio exacto y el chat principal lo hace.

## Kit común (úsalo, no lo copies)

- **Estado:** `Zanqui.de(context)` → `EstadoZanqui` (`lib/datos/estado.dart`): `manglar` (zonas y polígonos), `perfil`,
  `reportes` (los del teléfono, más nuevo primero), `publicos` (del servidor, puede estar vacío), `clima`, `enLinea`,
  `pendientes`, `progreso` (puntos, nivel, insignias), `servidor.configurado`, `guardarPerfil()`, `sincronizar()`.
  `Zanqui.leer(context)` para leer sin suscribirse (en callbacks).
- **Datos:** `lib/datos/tipos.dart` (`TipoAmenaza`, `EstadoReporte`, `Momento`, `Magnitud`), `reporte.dart`
  (`Reporte`, `Envio`, `CambioEstado`, `caso` = ZQ-XXXX), `zonas.dart` (`Manglar`, `ZonaManglar`, `Ubicacion`,
  `puntoMallorquin`), `prioridad.dart` (`Prioridad`, `Solidez`), `guardian.dart` (`Perfil`, `Nivel`, `Insignia`,
  `Progreso`, `Mision`), `fotos.dart` (`Fotos.leer(ref)`), `clima.dart`.
- **Tema:** `lib/nucleo/tema.dart`: colores `Zc.*` (raíz, hoja, ciénaga, arena, fango, sol, prioridad 1-5), tiempos y
  resortes `Zm.*`, radios `Zr.*`, textos con `Theme.of(context).textTheme`. **Nada de colores sueltos ni Material
  genérico** (sin `ElevatedButton`, sin `AppBar` por defecto, sin `ListTile` gris).
- **Toque:** `Presionable` (se hunde y vibra; `etiqueta:` para TalkBack), `BotonZ` (56 px, con `cargando`),
  `TarjetaZ`, `vibrar(Vibracion.x)` en `lib/nucleo/presionable.dart`.
- **Movimiento ya medido:** `lib/nucleo/base/`: `AppMotion` (duraciones, curvas, resortes `resorteSuave`,
  `resorteFirme`, `resorteRebote`, `resorteEmergente`, `stagger(i)`), `EntradaEscalonada` (listas que entran por turno,
  tope 6), `Esqueleto`/`Skeleton` (carga con la forma real), `mostrarHojaZ` / `HojaZ` (hoja inferior que se arrastra
  para cerrar), `context.animationsDisabled` (respetar «reducir movimiento»).
- **Comunes:** `lib/vistas/comun/comunes.dart`: `CabeceraZ` (título grande), `PildoraPrioridad`, `ChipEstado`
  (envío + estado), `IconoTipo`, `FranjaConexion`, `haceCuanto()`. `zanqui_mascota.dart`: `ZanquiMascota(tamano:,
  animo: Animo.feliz|curioso|preocupado|celebrando, onTap:)`. `burbuja.dart`: `BurbujaZanqui(texto:)` y
  `DatosZanqui.todos` (frases para concientizar).
- **Navegación:** `abrirReporte(context, tipo: …)` abre el flujo de reporte; `Raiz.irA(context, 1)` cambia de pestaña
  (0 Inicio, 1 Mapa, 2 Mis reportes, 3 Guardián).

## Reglas de cada pantalla

- Español en todo, sin jerga. Letra que se lee al sol; toques de 44 px o más; nada que salte bajo el dedo.
- La barra de pestañas flota abajo (72 px + borde inferior): deja `padding` inferior de **110 px** en listas con scroll.
- Estados **vacío, cargando, error y sin señal** pensados y bonitos (con Zanqui cuando aporte), nunca una pantalla
  en blanco ni un «0» que mienta.
- Honestidad: datos de prueba se dicen de prueba; si no hay servidor, se dice «modo demostración».
- Movimiento con intención: entrada escalonada en listas, resortes en lo que se toca, `Hero` para tarjetas que se
  abren. Respeta `context.animationsDisabled`.
- Rendimiento: `RepaintBoundary` en lo que anima, `const` donde se pueda, sin `Opacity` animado sobre árboles grandes
  (usa `FadeTransition`), listas con `ListView.builder`/`SliverList`.
- Privacidad: nunca mostrar la huella de la cédula ni el id interno del perfil; el código público es `perfil.codigo`.
- Antes de entregar: `dart analyze lib` sin avisos. No corras `flutter build` ni `flutter run` (uno a la vez en el PC;
  lo hace el chat principal). No hagas commit.
