# 10 · La vara de diseño y movimiento (web y app)

Reglas concretas y verificables para que la web (Astro, React, Tailwind) y la app (Flutter) se sientan como una sola cosa:
estilo iOS, rápida, honesta y accesible. Cada regla trae un valor o una forma de comprobarla. Si algo no se puede cumplir, se
dice en una línea y se deja el camino que sí sirve.

## 0. Principios

1. **Responder al tacto en menos de 100 ms.** Lo que no responde parece roto.
2. **Solo `transform` y `opacity` en movimiento.** Nada de animar ancho, alto, sombra, `border-radius` ni `filter` por cuadro.
3. **Todo gesto tiene vuelta suave y una vía sin gesto** (botón, menú visible, «Cerrar»).
4. **Reducir movimiento no es quitar contenido:** llega al mismo sitio, sin recorrido.
5. **Honestidad:** lo que es de ejemplo lo dice («Datos de ejemplo»); lo que no está conectado no se simula como hecho.
6. **Medir antes de afirmar.** «Se ve fluido» no cuenta; la cifra, sí.

## 1. Tokens de movimiento (una sola fuente)

Ninguna pantalla declara duraciones ni resortes sueltos: se usan estos tokens.

### 1.1 Duraciones

| Token | Valor | Uso |
|---|---|---|
| `toque` | 100–160 ms | Comprimir y soltar un botón, fila o chip |
| `rapida` | 160 ms | Salidas, fundidos de aviso, cierre de hoja |
| `base` | 260 ms | Entrada de sección, barra que aparece |
| `lenta` | 420 ms | Tarjeta de celebración |
| Navegación entre páginas | 220–300 ms | View transitions |
| Cifra que cuenta | 280 ms (app) · 450–700 ms (web, estadística) | Totales, contadores |
| Ráfaga única (check, confeti) | 350–700 ms, **sin bucles** | Celebraciones |

Tope general: ningún revelado pasa de 800 ms; interfaz < 300 ms; hojas ≈ 500 ms. Escalonado de lista: 40 ms por elemento,
**máximo 8–10 elementos** (del 9.º en adelante entra sin retraso), y ≤ 400 ms por grupo.

### 1.2 Curvas

| Nombre | `cubic-bezier` | Uso |
|---|---|---|
| `salida` | `(0.16, 1, 0.3, 1)` | Entrada de contenido y tarjetas |
| `salida-suave` | `(0.22, 1, 0.36, 1)` | Cambio de página, barras |
| `hoja` (estilo iOS) | `(0.32, 0.72, 0, 1)` | Hojas inferiores y paneles: llegan sin rebote |
| `entrada` | `(0.55, 0, 1, 0.45)` | Solo salidas |
| `trazo` | `(0.65, 0, 0.35, 1)` | Trazo de un check que se dibuja |
| `lineal` | `linear` | Solo cuenta regresiva real |

### 1.3 Resortes (nombre, respuesta en s, amortiguación ζ, rebote)

| Resorte | Respuesta | ζ | Rebote | Uso |
|---|---|---|---|---|
| `toque` | 0,20 | 0,85 | ≈ 0,6 % | Pulsar y soltar |
| `seco` | 0,32 | 0,86 | ≈ 0,5 % | Interruptores, pestañas, foco que encaja |
| `suave` | 0,45 | 1,0 | 0 % | Hojas, paneles, cambios de lugar |
| `tarjeta` | 0,55 | 0,78 | ≈ 2 % | Tarjetas y avisos que entran |
| `pesado` | 0,75 | 0,92 | 0 % | Cosas grandes, cambio de página |
| `icono` | 0,30 | 0,55 | ≈ 12 % | Microanimación de un ícono |
| `gelatina` | 0,45 | 0,40 | ≈ 25 % | **Un** momento de celebración por pantalla |

Jerarquía: el rebote solo vive en íconos y en una celebración. Lo demás llega y se queda.

**En web (CSS):** generar cada resorte con `linear(...)` y dejar un `cubic-bezier` de respaldo antes, dentro de `:root`:

```css
:root {
  --salida: cubic-bezier(.16, 1, .3, 1);
  --hoja: cubic-bezier(.32, .72, 0, 1);
  --resorte-toque: cubic-bezier(.3, 1.3, .5, 1);  --resorte-toque-t: 240ms;
  --resorte-seco:  cubic-bezier(.34, 1.3, .64, 1); --resorte-seco-t: 370ms;
  --resorte-suave: cubic-bezier(.16, 1, .3, 1);    --resorte-suave-t: 570ms;
}
/* uso */ .boton { transition: transform var(--resorte-toque-t) var(--resorte-toque); }
```

**En Flutter:** `SpringDescription.withDampingRatio(mass: 1, stiffness: k, ratio: ζ)` con `k = (2π / respuesta)²`; por
ejemplo `toque` ≈ 987, `suave` ≈ 195. Centralizar en `app/lib/nucleo/base/movimiento.dart` y no escribir duraciones
sueltas en las vistas.

## 2. Toque, escala y gestos

### 2.1 Escala al presionar

| Elemento | Escala |
|---|---|
| Tarjeta grande | 0,985 |
| Botón principal, fila, cuadro | 0,96–0,97 (con *hover* en web: 1,015) |
| Segmentado, pestaña | 0,94 |
| Interruptor | 0,92 |
| Ícono o botón redondo | 0,88 |

Web: además de la animación, `:active { transform: scale(.97) }` a 100 ms para que responda aunque falle el JS.

### 2.2 Umbrales de gesto

| Gesto | Umbral |
|---|---|
| Mantener para menú | 350–450 ms; el elemento baja a 0,97 mientras se sostiene |
| Deslizar para revelar | abrir a 40 px o 500 px/s |
| Cerrar hoja arrastrando | > 25 % de su alto o > 800 px/s; si no, vuelve con `suave` |
| Descartar volando | > 48 px o 450 px/s, sale en la dirección del tirón |
| Deslizar para confirmar | 70 % del recorrido; si se cancela, regresa en 160 ms |
| Proyección al soltar | posición + velocidad × 0,08 s (frenado ≈ 0,998 por ms) |

### 2.3 Reglas

1. **Deshacer en lugar de confirmar** cuando la acción se puede revertir (aviso con «Deshacer» de 5–6 s). Diálogo de
   confirmación solo para lo irreversible (borrar datos, descartar un reporte).
2. **Un gesto nunca es la única vía:** deslizar tiene botón; mantener tiene menú visible; arrastrar la hoja tiene «Cerrar».
3. **Háptica (app):** toque ligero al presionar; selección al cambiar de opción; éxito (patrón corto doble) al aterrizar el
   check; error con sacudida. Una vibración cada ≥ 40 ms como mucho.
4. **Se anima lo que cambia, no lo que se monta:** latidos, sacudidas y píldoras comparan contra el valor previo y no laten
   en el primer dibujo.

## 3. Entradas, listas, cargas y estados vacíos

1. **Esqueleto con la forma real** del contenido (uno por widget), no un spinner genérico. Brillo lento de opacidad. El
   esqueleto y el spinner **no se apagan** con «animaciones apagadas» de la app (un bloque quieto parece colgado); solo con
   «reducir movimiento» del sistema.
2. **Estados vacíos con Zanky:** ilustración del ánimo que corresponda (curioso al no haber reportes, feliz tras enviar,
   preocupado ante un fallo), una frase que dice por qué está vacío y **una acción** («Reportar ahora»). Nada de «?» ni de
   pantallas en blanco.
3. **Cifras que cuentan** de 0 al valor (280–700 ms, curva `salida`) solo al cambiar, con números tabulares
   (`font-variant-numeric: tabular-nums`) para que no bailen.
4. **Barras de progreso:** `scaleX` desde el borde izquierdo; el color no se interpola, se cruzan capas por opacidad.
5. **El estado final también va como estilo normal,** no solo animado: si la app pasa a segundo plano a mitad de la entrada,
   nada se queda en opacidad 0.
6. **La primera pantalla no anima su entrada** (con la animación el HTML del servidor sale en `opacity: 0` y en red lenta la
   pantalla queda en blanco).
7. **Ráfagas únicas:** check (disco 0,55 → 1 con resorte 520/22, trazo de 0,3 s, anillo que crece a 1,75 y se desvanece),
   confeti ≤ 1,2 s (chico) o ≤ 2,4 s (grande). Cero bucles; un bucle lento por pantalla como máximo (dos en total).

## 4. Navegación sin tirones

### 4.1 Web (Astro)

1. Activar **View Transitions** con `<ClientRouter />` (o `<ViewTransitions />` según la versión de Astro) en el layout base.
2. Transición de página 220–300 ms con curva `salida-suave`; **sin salida encadenada** que deje la pantalla en blanco: la
   página nueva monta ya y la vieja se va por debajo.
3. Elementos compartidos con `transition:name` (la tarjeta de una jornada que se vuelve su detalle; el encabezado fijo con
   `transition:persist`).
4. Los islotes de React y el mapa **sobreviven** a la navegación con `transition:persist`; no se reinicia Leaflet.
5. Respaldo: si el navegador no soporta la API, la navegación normal sigue funcionando sin animación.
6. `@media (prefers-reduced-motion: reduce)`: fundido de 120–150 ms, sin desplazamiento.

### 4.2 App (Flutter)

1. Una sola `PageRoute` para hojas: la hoja entra con `suave` y se cierra arrastrando (§2.2).
2. Las pestañas se funden con `transicion_pestanas.dart`; sin saltos de scroll al cambiar.
3. El botón «atrás» del sistema y la gesta de borde cierran lo mismo que el botón visible.
4. Al abrir por QR (`?evento=`), pintar al instante con lo guardado y actualizar después con la red.

## 5. Fluidez: 60 a 144 cuadros por segundo

1. **Meta:** 60 cps en cualquier teléfono de gama media; 120–144 en pantallas de alta frecuencia. Cuadros lentos < 1 %.
2. **Animar solo `transform` y `opacity`.** Si hay que animar otra cosa (altura automática), usar `grid-template-rows: 0fr → 1fr`.
3. **`will-change: transform` desde el principio** en lo que se va a animar seguro (y quitarlo al terminar solo si no se
   vuelve a animar). **No dar capa a todo:** cada capa extra se compone en cada cuadro.
4. **Lo que repinta** (`width`, `height`, `border-radius`, `box-shadow`, `clip-path`, `backdrop-filter`) no se anima por
   cuadro. Si hace falta, en pasos de 1 px.
5. **Vidrio (`backdrop-filter`):** aparece entero y crece (escala 0,9 → 1); al cerrar se funde rápido. Uno a la vez, nunca en
   listas. Un desenfoque que se desvanece se recalcula en cada cuadro: apagarlo de golpe cuando ya no hace falta.
6. **Sombras:** corta mientras algo vuela y la grande al aterrizar; la sombra enorme animada cuesta más que el resto junto.
7. **Flutter:** `const` donde se pueda; `RepaintBoundary` alrededor de lo que anima; `AnimatedBuilder` con `child` fijo;
   evitar `Opacity` y `ClipRRect` animados (usar `FadeTransition` y recortes estáticos); listas con `ListView.builder`; no
   repartir la construcción de una lista en muchos cuadros con `addView`-equivalentes que re-maqueten a los hermanos;
   imágenes con `cacheWidth` al tamaño real; el mapa no se reconstruye al cambiar de pestaña.
8. **Precargar sin trabar:** lo pesado espera a 8 s sin interacción o a la intención del usuario (pasar el puntero, tocar);
   nunca «a los pocos segundos de cargar».
9. **Lo invisible no es gratis:** lo que sale de pantalla se oculta (`visibility: hidden`, `Offstage`) y deja de dibujarse.

### 5.1 Cómo medir

| Dónde | Cómo | Se acepta |
|---|---|---|
| Web | Traza de Chrome (Performance) con la escena automatizada; partir en tramos de 250 ms; contar cuadros por tramo (36 = 144 cps) | ≥ 55 cps con CPU ×4 en una animación de entrada; 0 tareas largas (> 50 ms) durante el gesto |
| Web | `PerformanceObserver` con `longtask` y `layout-shift` | CLS < 0,1; sin tareas largas |
| Flutter | `flutter run --profile` en un teléfono real; DevTools → Performance (cuadros de UI y raster) | Cuadros de UI y raster < 8 ms (120 Hz) u 11 ms (90 Hz); lentos < 1 % |
| Android | `adb shell dumpsys gfxinfo <paquete> reset` y luego `dumpsys gfxinfo <paquete> framestats` | Cuadros lentos < 1 % |

Reglas de medición:
- **A/B alternado** (antes, ahora, ahora, antes) con ≥ 3 vueltas; un orden fijo engaña. Incluir una copia de la misma
  versión contra sí misma para saber el ruido.
- **Comprobar que la escena ocurrió** (si el gesto no se hizo, se miden cuadros quietos y salen cifras falsas).
- Un emulador con GPU del equipo no sirve para medir fluidez: usar un teléfono real.
- Una cifra que no cuadra con el resto es una medida rota, no un logro.
- Cada arreglo lleva una prueba que **falla si se quita** el arreglo.

## 6. Accesibilidad

1. **Objetivos táctiles ≥ 44 × 44 px** (web) y ≥ 48 × 48 dp (Android) con 8 px de separación; el área puede ser mayor que el dibujo.
2. **Foco visible:** anillo de 2 px con contraste ≥ 3:1 y separación de 2 px; nunca `outline: none` sin reemplazo. Orden de
   tabulación igual al visual; al cerrar una hoja, devolver el foco a quien la abrió.
3. **Contraste:** texto normal ≥ 4,5:1; texto grande y componentes ≥ 3:1; medir contra los píxeles reales cuando el texto va
   sobre una imagen. Un estado no se comunica solo por color (agregar ícono o texto).
4. **`prefers-reduced-motion`:** sin desplazamientos ni escalas; fundidos de 120–160 ms; sin confeti; el estado final y el
   texto («Listo») se conservan. En Flutter, `MediaQuery.disableAnimations`.
5. **Sin desbordes a 360 px** de ancho (web y app): sin barra horizontal; textos que no se parten en cinco renglones; un chip
   elegido nunca queda cortado; barras fijas que no tapan media pantalla.
6. **Lectores de pantalla:** botones con nombre (`aria-label`, `Semantics`), imágenes con descripción o marcadas decorativas,
   estados dinámicos con `aria-live="polite"`.
7. **Teclas:** `Esc` cierra hojas y menús; flechas en segmentados y menús; el gesto de mantener tiene clic derecho o tecla.
8. **Zoom:** la interfaz soporta texto al 200 % sin perder funciones.
9. **Hojas y diálogos:** `role="dialog"`, `aria-modal`, foco atrapado, `inert` en lo de atrás.

## 7. Honestidad del dato y de los textos

1. Todo dato de demostración lleva el rótulo **«Datos de ejemplo»** visible; si la fuente real responde, el rótulo
   desaparece.
2. Un «ver detalle» da detalle de verdad; no repite el número.
3. Descartar atípicos antes de mostrar promedios; indicar siempre el rango de fechas y la fuente.
4. Con la app en español no queda **nada** en inglés; un mismo nombre en toda la app; sin jerga.
5. Los errores dicen qué pasó y qué hacer («No hay señal. Tu reporte queda en el teléfono y se envía solo»), nunca un código.
6. Nunca presentar como hecho lo que no está conectado: se rotula «maqueta» o «en la hoja de ruta».
7. Privacidad: sin datos personales en datos abiertos; el consentimiento antes de difundir.

## 8. Diseño visual (estilo iOS)

1. **Rejilla de 4/8 px;** márgenes laterales de 16 px en móvil.
2. **Radios:** tarjetas 16–20, botones 12–14, chips completos; el mismo radio en la misma jerarquía.
3. **Tipografía:** una familia (Inter incluida en la app y en la web, subconjunto latino); cuerpo 16 px mínimo en móvil;
   interlineado 1,4–1,5; títulos que se colapsan al hacer scroll (título grande → pequeño entre 30 y 50 px de desplazamiento).
4. **Color:** tokens en `:root` y en el tema de Flutter; modo oscuro con los mismos tokens; la identidad de la CRA y la
   paleta de Zanky no se mezclan con colores sueltos.
5. **Íconos:** rejilla 24, trazo 2, remates redondos, `currentColor` con un solo acento; los de estado se dibujan **una vez**
   (350–700 ms) y quedan quietos.
6. **Superficies:** hojas inferiores con asa; vidrio solo en barras y menús; sombras suaves y cortas.
7. **Densidad:** una acción principal por pantalla, claramente más fuerte que las demás.

## 9. Lista de chequeo antes de dar algo por terminado

- [ ] Se vio en un teléfono real (o a 360 y 390 px en el navegador), en claro y oscuro.
- [ ] Todo botón y fila responde al toque con escala; los toques miden ≥ 44 px.
- [ ] Tiene esqueleto al cargar, estado vacío con Zanky y error con salida.
- [ ] Sin barra horizontal a 360 px.
- [ ] Con «reducir movimiento» llega al mismo sitio sin recorrido.
- [ ] Foco visible y orden de tabulación correcto.
- [ ] Solo `transform` y `opacity` se animan; medido: ≥ 55 cps con CPU ×4 (web) o lentos < 1 % (Flutter).
- [ ] Los datos de ejemplo están rotulados; nada se presenta como hecho sin estarlo.
- [ ] Hay una prueba que falla si se quita el arreglo.
