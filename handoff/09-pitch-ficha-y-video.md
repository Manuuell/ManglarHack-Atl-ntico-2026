# 09 · Pitch, ficha técnica y video

Preparado el 27-11-2026 (mediodía) leyendo el código de `main` y de la rama `zanqui-bot` (el bot de Manuel). Todo lo que
dice «hoy» está comprobado en el código; lo que no, va marcado **[por confirmar]** o **[pendiente]**. Si algo cambia antes
de las 16:00, se corrige aquí primero y después el guion.

**Estado real a las 12:00, para no engañarnos:**

| Pieza | Estado comprobado en el código |
|---|---|
| App Flutter | Flujo completo (tipo → ubicación → foto → detalles → enviado), cola sin señal, mapa, mis reportes, guardián. Sin `--dart-define` corre en **modo demostración** (todo queda en el teléfono y lo dice). |
| Backend Supabase | SQL escrito y revisado a mano; **no se ha ejecutado contra una base real** (`backend/supabase/README.md` §7). |
| Bot de WhatsApp | Flujo completo en el simulador (`npm run simular`); guarda en **archivos JSON propios**, no en Supabase. Conexión con Meta **[por confirmar con Manuel]**. |
| Panel web | **[pendiente]** Jerson y Manuel. No hay carpeta `web/` en el repo todavía. |
| IA que clasifica fotos | **[pendiente]**. Las columnas `ia_*` existen, no hay modelo conectado. |

---

## 1. Ficha técnica (para Byte Arena)

| Componente | Herramientas y tecnologías (versión real) | Modelos de IA | Para qué |
|---|---|---|---|
| App móvil (Android) | Flutter 3.44.9 / Dart ^3.12.2; `flutter_map` 8.3, `geolocator` 14, `image_picker` 1.2, `connectivity_plus` 7.3, `shared_preferences` 2.5, `http` 1.6, `uuid` 4.6, `crypto` 3.0, `flutter_animate` 4.5, `qr_flutter` 4.1, `share_plus` 13.3; fuente Inter incluida en la app | Ninguno dentro de la app | Reportar sin señal con GPS y foto, prioridad 1-5 con motivos, solidez 0-100, mapa, «mis reportes», tarjeta de guardián |
| App web / PWA | Mismo código Flutter compilado a web (`app/web/`, `manifest.json`, service worker). iPhone: **[por confirmar]**, no se ha probado | Ninguno | Demo en navegador y QR para turistas **[por confirmar que se publica]** |
| Bot de WhatsApp (Manuel, rama `zanqui-bot`) | Node.js ≥ 20, TypeScript 5.7, Express 4.21, dotenv 16.4; API oficial de WhatsApp Cloud (Meta) | Ninguno hoy (no procesa audios) | Reportar por conversación, número de caso, aviso de cambio de estado, datos abiertos |
| Backend y base de datos | Supabase (Postgres 15 + PostGIS 3, RLS, Storage, Realtime) **[SQL sin ejecutar contra base real]**; el bot usa por ahora almacén JSON propio | Ninguno hoy | Zona, prioridad y hora de recepción recalculadas en el servidor; auditoría; datos abiertos (GeoJSON, CSV, KML) |
| Panel web de la CRA | **[pendiente: Jerson y Manuel]** (stack **[por confirmar]**) | — | Cola de verificación, mapa, estados, exportación |
| Validación de reportes | Reglas en código: puntaje de solidez/confianza, huella SHA-256 de la foto (el bot penaliza repetidas; en Supabase solo se guarda la huella), límites de envío | **Modelo de visión: [pendiente], no declarar como hecho** | Clasificar foto y texto contra el tipo reportado; marca, nunca bloquea |
| Datos | INVEMAR, Capa Nacional de Manglares 2020 (144 polígonos del Atlántico, 533 ha; provisional hasta recibir el KMZ de la CRA); OpenStreetMap (mapa base); Open-Meteo (viento, lluvia, oleaje) | — | Punto en polígono, viento para incendios, mapa |
| Construcción, documentación y revisión | Claude Code | **Claude Opus 5.5** (Anthropic) como orquestador; **Claude Sonnet 5.5** (Anthropic) en agentes de construcción y revisión; Codex se intentó y no se usó; el bot lo construyó Manuel con su propio agente **[por confirmar con él cuál]** | Análisis del reto, código, pruebas, documentación |
| Arte y video de Zanky | Google Flow (Manuel) | **[por confirmar con Manuel]** qué modelos de imagen y video usó Flow | Mascota, clips de intro y cierre |

Nota para la ficha: la mascota **dentro de la app hoy está dibujada en código** (`zanky_mascota.dart`). El arte de Flow solo
se declara donde de verdad se use (video, stickers, avatar del bot).

---

## 2. Guion del pitch (7:00)

Frases cortas, habladas. Costeño sin caricatura: «ajá», «parce» una vez como mucho. Nunca leer la pantalla. Una persona
habla, otra maneja el teléfono. Plan B grabado de cada demo en el mismo teléfono, listo en el escritorio.

### 0:00–1:00 · El problema

**Se dice:**
«Hace poco, en Juan de Acosta, estaban talando manglar para hacer una escuela. La CRA se enteró tarde. Cuando llegó la
denuncia, el daño ya estaba hecho. La CRA no tiene guardas en el terreno. Pero el manglar sí tiene gente: pescadores,
colegios, turistas. Lo que les falta es un sitio donde contar lo que ven, aunque no haya señal. Les presentamos a Zanky.»

**Se muestra:** foto fija del manglar (sin personas identificables) o la Ciénaga de Mallorquín en el mapa de la app; al
final, Zanky (arte de Flow si llegó; si no, el de la app) diciendo «¡Ajá! ¿Qué viste en el manglar?».
Nota: «Juan de Acosta» es lo que contó la CRA en el lanzamiento; decirlo como «lo que nos contaron hoy», no como dato propio.

### 1:00–4:00 · Demo en vivo (3 min)

| Min | Se dice | Se muestra (pantalla real) |
|---|---|---|
| 1:00 | «Voy a reportar como lo haría un pescador. Primero, sin señal.» | Teléfono en modo avión (se ve el aviso «sin señal»). App abierta en Inicio. |
| 1:20 | «Elijo qué vi: tala. El teléfono toma mi ubicación y la cruza con el mapa del manglar, ahí mismo, sin internet.» | Flujo: tipo → ubicación GPS. Se ve «Dentro del manglar · Mallorquín» (zona y distancia calculadas en el teléfono). |
| 1:50 | «Tomo la foto en el momento. Y me dice por qué este reporte es prioridad cuatro.» | Foto desde la cámara; prioridad con sus motivos y la solidez. |
| 2:10 | «Envío. No hay señal, así que se guarda y Zanky me da mi número de caso.» | Pantalla «enviado» con el número de caso grande; chip «Demostración/en cola». |
| 2:25 | «Apago el modo avión. Se envía sola, una vez, sin duplicarse.» | FranjaConexión pasa a enviado; «Mis reportes» con la línea de tiempo. |
| 2:45 | «El reporte aparece en el mapa y en el panel de la CRA, con su prioridad. Una persona lo valida.» | **[Depende del panel]** Mapa de la app con el punto; panel con la cola. Si el panel no está: mapa de la app y plan B grabado. |
| 3:15 | «Y la CRA puede bajar los datos abiertos, sin nombres ni fotos.» | **[Depende del panel o del endpoint]** Descarga de GeoJSON/CSV/KML abierta en Google Earth o en un visor. |
| 3:40 | «Y quien no instala nada, lo hace por WhatsApp.» | Bot: menú → tipo → ubicación → foto → «Caso ZK-XXXX» (mismo formato que la app). Simulador o WhatsApp real **[por confirmar con Manuel]**; decir «simulador» si es simulador. |

Antes de subir: **dos teléfonos o dos ventanas**. Ensayar la toma que escribe: guarda el dato de verdad, hay que resembrar.

### 4:00–6:00 · Las tres preguntas (40 s cada una)

**1. ¿Dónde pasa ahora mismo y con qué prioridad?**
«El reporte guarda el GPS, la hora del teléfono y la hora en que llega al servidor, así un reporte sin señal se marca como
tardío y no se hace pasar por nuevo. Se cruza con los polígonos del manglar y da una prioridad de uno a cinco, y siempre dice
por qué: tipo de amenaza, zona, si pasa ahora, viento si es fuego.»
**Se ve:** pantalla de prioridad con motivos; detalle del reporte con zona y hora.

**2. ¿Cómo se valida que el dato es confiable?**
«Cada reporte lleva un puntaje de solidez: foto tomada en el sitio, ubicación precisa, cerca del manglar, descripción. La foto
lleva una huella; el bot ya penaliza fotos repetidas y el servidor guarda la huella para hacerlo. El anónimo pesa menos, pero se permite. Y lo más importante: **una persona
decide** antes de abrir un expediente. La IA que revisa la foto es el siguiente paso; hoy no está conectada.»
**Se ve:** desglose de la solidez; estados `recibido → en verificación → verificado → alerta oficial`.

**3. ¿Cómo se sostiene la participación?**
«Zanky crece con los reportes validados, no con la cantidad, así el spam no da puntos. Hay niveles, insignias y la tarjeta
del guardián. El colegio puede usarlo para servicio social y PRAE, y el turista entra por un QR sin instalar. Y quien
reporta ve qué pasó con su caso.»
**Se ve:** tarjeta del guardián con nivel e insignias; «Mis reportes» con el estado. Decir «proponemos» para colegios y QR:
la alianza no existe aún.

### 6:00–7:00 · Sostenibilidad, seguridad y siguientes pasos

**Se dice:**
«Seguridad: el permiso se decide en el servidor, la foto solo la ve quien tiene rol y cada vez que se mira queda registro.
Al que denuncia lo protegemos: puede ser anónimo, el teléfono se guarda cifrado y lo público sale con la ubicación
redondeada a unos cien metros. Costos: base de datos y mapa con servicios gratuitos. Siguiente paso con la CRA: cargar sus
polígonos oficiales, validar con los mentores los tipos y las prioridades, y pilotear en Mallorquín. Gracias.»
**Se muestra:** una sola diapositiva con tres frases (qué hay hoy, qué falta, qué pedimos) y Zanky celebrando.

### Cinco preguntas difíciles

1. **Ciberseguridad: ¿qué impide que me suban basura o me tumben el servicio?**
   «Lo que el cliente manda, el servidor lo recalcula: zona, prioridad y estado. El público solo puede escribir, no leer.
   Hay límite por persona. Hay un hueco que reconocemos: los anónimos no tienen límite por IP todavía, y se pone en el borde.
   La defensa de fondo es que una persona decide antes de cualquier alerta.»
2. **Datos falsos: ¿y si alguien reporta locuras para sabotear?**
   «Un reporte falso no abre expediente por sí solo. Pierde puntos si no trae foto del sitio, si está lejos del manglar o (en el bot) si
   la foto se repite. El que reporta basura baja su reputación. Falta afinar con casos reales; lo probamos con datos de ejemplo.»
3. **Costos: ¿cuánto cuesta mantenerlo?**
   «No tenemos una cifra medida. La base y el almacenamiento corren en el plan gratuito de Supabase y el mapa es abierto. El
   costo real aparece con el volumen de fotos y con WhatsApp; lo calculamos con la CRA.» (No inventar cifras.)
4. **Adopción: ¿por qué lo usarían un mes después?**
   «Por tres cosas: ven qué pasó con su reporte, Zanky premia lo validado y no la cantidad, y los colegios pueden contarlo
   como servicio social. Todavía no lo hemos probado con comunidad; ese es el piloto que proponemos.»
5. **Privacidad: ¿qué pasa con el que denuncia?**
   «Puede reportar anónimo. Si da su número, se guarda cifrado. La foto y la descripción nunca salen en los datos abiertos.
   Hay aviso de privacidad y consentimiento al empezar, según la Ley 1581. Quien ve la identidad es solo el moderador y queda
   auditado.» (Si el panel todavía no muestra eso, decir «el servidor lo permite» y no «el panel lo muestra».)

---

## 3. Guion del video del prototipo (2:30)

Entregar entre 2:00 y 3:00, **grabado antes de las 16:30**. Voz primero (vara §10, 113): se graba o sintetiza la voz y las
escenas se ajustan a su duración. Pantalla **siempre real**; cuenta de prueba con datos de muestra marcados «Datos de ejemplo»;
ninguna persona real, número ni foto identificable. Antes de cada toma: abrir la pantalla, esperar a que cargue, modo
captura sin notificaciones, PC sin otros procesos pesados. Sincronizar con el cuadro donde la pantalla cambia, no con el toque.

| # | Tiempo | Se graba | Voz en off |
|---|---|---|---|
| 1 | 0:00–0:12 | Clip corto de Zanky (arte de Flow si llegó; si no, la mascota de la app en Inicio) | «¡Ajá! Yo soy Zanky. Si ves que algo le pasa al manglar, repórtalo, ¡aunque no tengas señal!» |
| 2 | 0:12–0:30 | Mapa de la app con las zonas del manglar y el punto de Mallorquín | «En el Atlántico nadie sabe cuándo talan un manglar hasta que ya es tarde. La CRA no tiene guardas en el terreno.» |
| 3 | 0:30–0:50 | Teléfono en modo avión; botón de reportar; elegir tipo «Tala» | «Con Zanky, cualquiera reporta desde donde está. Aquí no hay señal, y no importa.» |
| 4 | 0:50–1:10 | Ubicación por GPS: se ve «Dentro del manglar · Mallorquín» | «El teléfono toma el punto y lo cruza con el mapa del manglar, ahí mismo.» |
| 5 | 1:10–1:30 | Foto con la cámara; pantalla de prioridad con motivos y solidez | «Foto en el momento. Y Zanky explica por qué la prioridad es alta, no solo un número.» |
| 6 | 1:30–1:45 | Pantalla «enviado» con el número de caso; chip de en cola | «Se guarda y te da tu número de caso. Cuando vuelve la señal, se envía sola, una sola vez.» |
| 7 | 1:45–2:00 | Apagar modo avión; «Mis reportes» pasa de en cola a enviado; línea de tiempo | «Ahora la CRA lo ve, y tú sigues el caso.» |
| 8 | 2:00–2:15 | **[Depende del panel]** Panel: cola con el reporte, prioridad, cambio de estado. Si no está: no mostrarlo, ver abajo | «Una persona revisa y decide. La IA, cuando esté, sugiere; nunca decide.» |
| 9 | 2:15–2:25 | **[Depende del panel o del endpoint]** Descarga de datos abiertos abierta en un visor | «Y los datos salen abiertos, sin nombres ni fotos, para cualquiera.» |
| 10 | 2:25–2:40 | Conversación del bot de WhatsApp (simulador o real) hasta el número de caso | «¿Sin instalar nada? Escríbele a Zanky por WhatsApp.» |
| 11 | 2:40–2:50 | Tarjeta del guardián con nivel e insignias; cierre con Zanky | «Zanky crece con lo que de verdad se valida. Cuida el manglar con nosotros.» |

Regla: si una escena depende de algo que no existe a las 16:00 (panel, WhatsApp real), **se corta esa escena** o se dice en
pantalla «simulador». No se simula una pantalla.

**Lista de tomas, en este orden** (teléfono Android real salvo indicación):
1. Inicio de la app con modo captura (T1, T2).
2. Modo avión puesto; flujo completo de reporte hasta «enviado» (T3-T6), en una sola toma continua.
3. Modo avión quitado; «Mis reportes» sincronizando (T7).
4. Mapa de la app con reportes de ejemplo (T2, T4).
5. Tarjeta del guardián y niveles (T11).
6. Navegador: panel (T8), si existe a las 15:30.
7. Navegador: descarga de datos abiertos y apertura (T9).
8. Pantalla de WhatsApp o del simulador del bot (T10).
9. Zanky de Flow (clips de intro y cierre, T1 y T11).
10. Una hoja de cuadros del MP4 final revisada (vara 110): ninguna pantalla vacía ni cortada.

---

## 4. Lista «No afirmar» (comprobada contra el código)

| No decir | Por qué | Qué sí decir |
|---|---|---|
| «La IA ya clasifica las fotos» / «validamos con IA» | No hay modelo conectado; solo existen las columnas `ia_*` | «La IA es el siguiente paso; hoy valida un puntaje por reglas y una persona» |
| «Ya está conectado a la CRA» / «la CRA ya lo atiende» | No hay integración con la CRA | «Proponemos un piloto con la CRA» |
| «Funciona en iPhone» | No se ha probado | «Probado en Android» (y solo si es verdad) |
| «Funciona sin conexión en todo» / «el mapa funciona sin internet» | El mapa base de OpenStreetMap **no carga** sin señal (la app lo avisa). Zonas y reportes sí | «Reportar, GPS, zona y cola funcionan sin señal; el mapa base necesita señal» |
| «Datos en tiempo real en el panel» | Panel pendiente; el realtime del backend no se ha probado | «Con señal, llega al servidor al instante» solo si se vio en la demo |
| «Todo está conectado: app, bot y panel» | El bot guarda en JSON propio; la app habla con Supabase, que no se ha ejecutado contra una base real | Mostrar lo que de verdad se vio conectado |
| «Los polígonos son los de la CRA» | Es la capa INVEMAR 2020, provisional | «Con la capa de INVEMAR; cambiamos a la de la CRA cuando llegue» |
| «Las prioridades las validaron los mentores» | Son provisionales | «Provisionales; las ajustamos con los mentores» |
| «El bot entiende audios» | No hay manejo de audio | «El bot recibe texto, ubicación y foto» |
| «Anonimato total» | Anónimo borra el id del reportante; el bot guarda el hash del teléfono salvo en anónimo; no hay red anónima | «Puedes reportar sin dar tu nombre» |
| «Quitamos los metadatos de las fotos» | No se quitan en el servidor; la app **[por confirmar]** si lo hace | «La foto no sale en los datos abiertos» |
| «Los anónimos tienen límite de envío» | No hay límite en base para anónimos | «Hay límite por persona identificada; anónimos van al borde» |
| «Tenemos cifras de impacto/usuarios» | No hay pilotos | No dar cifras. Solo «533 ha» (INVEMAR) con fuente |
| «Colegios y turistas ya participan» | No hay alianzas | «Lo diseñamos para…» |
| «Hecho con Google Flow» para cosas dibujadas en código | La mascota de la app está en código | Decir dónde sí se usó Flow |
| «Sin riesgos de seguridad» | Hay 6 riesgos listados sin probar en `backend/supabase/README.md` | «Los revisamos y dejamos lo que falta dicho» |

---

## 5. Checklist final de entrega

Dueños propuestos: **Á** Ángel (app, backend, ficha, repo), **M** Manuel (bot, arte de Flow, voz del video), **J** Jerson (panel).
Confirmar dueños en el grupo ahora.

| Hora | Qué | Dueño |
|---|---|---|
| 12:30 | Confirmar con Manuel: modelos de Flow, estado del bot en WhatsApp real, número de caso unificado: ZK- + 4 hex del UUID | Á |
| 14:30 | Todo conectado de punta a punta, o decidir qué se corta | Todos |
| 15:00 | Rúbrica del jurado pedida y pitch alineado | Á |
| 15:00 | Revisión de seguridad: `git grep` de claves, `.env.example` al día, nada de nombres de otros proyectos | Á |
| 15:30 | Voz del video lista y revisada contra el guion | M |
| 16:00 | **Congelar funciones.** Plan B de la demo grabado | Todos |
| 16:00–16:30 | Grabar el video (tomas de §3) | Á, M |
| 16:30 | MP4 final 2–3 min revisado en hoja de cuadros | Á |
| 16:40 | README de la raíz al día con cómo correr cada pieza | Á |
| 16:45 | `git pull --rebase`, push, repo visible; ficha técnica final pegada en Byte Arena | Á |
| 17:00 | **Entrega:** enlace del repositorio, video, ficha técnica, archivos | Á |
| 17:30 | Un integrante distinto del autor prueba el flujo completo en un teléfono limpio | J |
| 18:15 | Ensayo con cronómetro (7:00) y teléfono cargado, datos de ejemplo resembrados | Todos |
| 18:45 | Teléfono en modo no molestar, plan B listo, datos móviles y WiFi probados | Á |
| 19:00 | Pitch | Todos |
