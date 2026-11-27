# Experiencia QR con Zanky (modo evento)

Una persona escanea el QR de una jornada y la app web se abre en el modo evento: Zanky la recibe, puede registrar su
asistencia, hablar con Zanky, hacer el reto del manglar y saltar a reportar, mapa o su tarjeta.

## Cómo se entra

- Enlace: `https://mimanglar.sentralabs.co/app/?evento=<codigo>`. También valen `?jornada=<codigo>`, la consulta tras el
  «#» (`/#/?evento=…`) y `#/evento/<codigo>`. El código es `[a-z0-9_-]{1,64}`. Un código que no es una jornada
  conocida abre el evento genérico «Evento con Zanky».
- `main.dart` envuelve el `home` con `PuertaEvento(child: …)`. En la web lee `Uri.base` al arrancar; cuando la app está
  lista abre `PantallaEvento` una sola vez por código.
- Desde código (escáner nativo, botón de Inicio): `abrirEvento(context, codigo)` en `puerta_evento.dart`.
- `enlaceEvento(codigo)` (en `datos/experiencia/entrada_evento.dart`) devuelve el enlace que va dentro del QR.

## Qué hay

Datos (`lib/datos/experiencia/`):
- `entrada_evento.dart`: lectura del enlace, `entradaEvento`, `enlaceEvento`.
- `jornada.dart`: `Jornada`, `EventoZanky`, `FuenteJornadas` (red 6 s, luego caché, luego `assets/datos/jornadas_respaldo.json`),
  fechas en español con hora de Colombia.
- `participacion.dart`: `AlmacenParticipacion` (asistencia 40 puntos; reto 10 por acierto y solo suma si mejora el mejor
  resultado). Se guarda solo en el teléfono (shared_preferences), aparte de los puntos de los reportes.
- `preguntas_zanky.dart`: 28 preguntas frecuentes con fuente, búsqueda por palabras sin conexión; si no sabe, lo dice.
- `ia_zanky.dart`: IA «lista, sin conectar». Solo responde con servidor configurado y `--dart-define=ZANKY_IA=true`
  (llama a la función `zanky-chat` del servidor; no hay claves de IA en la app).
- `trivia.dart`: 15 retos con explicación y fuente; `retoPara(codigo)` es determinista por código.

Vistas (`lib/vistas/experiencia/`): `puerta_evento`, `pantalla_evento`, `asistencia` (hoja con consentimiento Ley 1581),
`charla_zanky`, `reto_zanky`, `atajos_evento`, `piezas` (botón cargando→hecho con check dibujado, sacudida, píldoras),
`widgets_evento`.

## Widgets para otras pantallas (en `widgets_evento.dart`)

```dart
import '../experiencia/widgets_evento.dart';
```

- `EntradaEvento()` para **Inicio**. Constructor: `const EntradaEvento({Key? key})`. Alto aproximado 90 px con letra normal
  (crece con la letra grande); ocupa el ancho que le dé el padre. Sin evento abierto pide el código (o el enlace del
  QR) en una hoja; con uno abierto dice «Tu evento sigue abierto» y vuelve a él.
- `ResumenParticipacion()` para **Guardián**. Constructor: `const ResumenParticipacion({Key? key, AlmacenParticipacion? almacen})`
  (el almacén es solo para pruebas). Alto aproximado 88 px sin eventos y 36 px más por cada evento mostrado (hasta 3).
  Se actualiza solo cuando suma puntos.

Ojo: el widget `EntradaEvento` y la clase de datos `EntradaEvento` (en `entrada_evento.dart`) tienen el mismo nombre.
Quien importe las dos debe poner `hide EntradaEvento` a la de datos (o `as w` al archivo de widgets).

## Qué falta

- `escanear_qr.dart` (escáner nativo): no se hizo; `abrirEvento` ya está listo para usarlo.
- Los widgets no están enganchados en Inicio ni en Guardián (esas carpetas no se tocaron).
- La función `zanky-chat` del servidor no existe todavía.
