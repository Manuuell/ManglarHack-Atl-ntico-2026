# 03 · La solución: Zanqui

**Lo decidido:**
- La mascota es **Zanqui**.
- Hay tres piezas: **app móvil en Flutter**, **aplicación web** y **bot de WhatsApp**.

Lo demás de este documento es una **propuesta para alinearnos**. Se ajusta con los mentores durante el día.

## La mascota

**Zanqui** viene de las **raíces en zancos del mangle rojo** (*Rhizophora mangle*), que parecen patas largas sobre el agua, y de los **zanqueros del Carnaval** de Barranquilla.
- **Personalidad:** alegre y costeño. Es quien guía al ciudadano al reportar: «¡Ajá! ¿Qué viste en el manglar?».
- **Dónde aparece:** en la app, el bot («Hola, soy Zanqui»), el panel público, los stickers y los letreros QR en el territorio.
- **Pendiente:** validar el nombre con los mentores comunitarios y revisar que no choque con una marca registrada.

## Las tres piezas

```
 Ciudadano en el manglar                          CRA
 ───────────────────────                          ───
 App Flutter (offline) ─┐                    ┌─► Panel web (mapa en vivo,
 Web pública (QR) ──────┼─► Backend común ───┤    cola de validación,
 Bot WhatsApp ──────────┘   API + BD geo     │    estados, expedientes)
                            + validación IA  └─► Datos abiertos
                                                  (GeoJSON / CSV / KML)
```

| Pieza | Para quién | Qué hace |
|---|---|---|
| **App móvil (Flutter)** | Ciudadanos frecuentes, vigías comunitarios, colegios | Reporta con foto, tipo, descripción y GPS, **sin conexión** (guarda en cola y sincroniza después). También tiene mapa de reportes, «mis reportes» con su estado, y Zanqui con insignias. |
| **Bot de WhatsApp** | Pescadores, comunidad y turistas que no quieren instalar nada | Guía el reporte: tipo → compartir ubicación → foto → descripción → **número de caso**. Permite consultar el estado del caso y avisa cuando cambia. |
| **Aplicación web** | La CRA (panel) y el público | **Panel de la CRA:** mapa en vivo, filtros, cola de validación, cambio de estado y exportación. **Vista pública:** mapa con datos anonimizados, descarga de datos abiertos y un formulario ligero para turistas que entran por QR. |
| **Backend común** | Las tres piezas | API, base de datos con soporte geográfico, validación, clasificación con IA y auditoría. |

## Respuesta a las 3 preguntas

### 1. ¿Dónde pasa *ahora mismo* y con qué prioridad?

**Dónde:**
- El reporte toma el **GPS del celular en el momento**. El GPS funciona sin internet.
- Si el GPS falla, hay alternativas: marcar el punto en el mapa, compartir la ubicación de WhatsApp o pegar un enlace de Google Maps, como sugirió la CRA.
- Se cruza el punto con los **polígonos KMZ de la CRA** (*point-in-polygon*). Así se sabe si está dentro de una zona de manglar, en cuál (Mallorquín, Tubará, Juan de Acosta o Piojó) y a qué distancia. Un vertimiento o un caño taponado pueden estar fuera del polígono y afectarlo igual, así que se usa además un **área de influencia** de unos 500 m.

**Ahora mismo:**
- Se guardan dos horas: la **hora de captura** (del dispositivo) y la **hora de recepción** (del servidor).
- Un reporte capturado sin conexión conserva su hora real y se marca como «sincronizado tarde».
- El panel muestra en vivo los reportes de las últimas horas.

**Prioridad:** se calcula de 1 a 5 con:
- la **gravedad del tipo de amenaza**: por ejemplo, incendio y tala activa pesan más que basuras;
- la **prioridad de conservación de la zona**: se define con los mentores ambientales; si la CRA tiene una zonificación, se usa esa;
- la **cercanía al núcleo** del polígono;
- la **corroboración**: varios reportes cerca en poco tiempo suben la prioridad.

### 2. ¿Cómo se valida que el dato es confiable?

Cada reporte recibe un **puntaje de confianza de 0 a 100** por capas, y **una persona decide** antes de que se vuelva alerta oficial:

1. **Evidencia:**
   - La foto se toma desde la app o el bot, no de la galería, y se revisan sus metadatos (fecha y lugar).
   - Un **hash** detecta fotos repetidas o recicladas.
2. **Coherencia geográfica:**
   - Se mira la precisión del GPS y si el punto está dentro o cerca del polígono.
   - Se detectan «saltos» imposibles entre reportes de una misma persona, y desfases sospechosos de hora.
3. **IA:** un modelo de visión y lenguaje revisa si la foto y el texto corresponden al tipo reportado (humo o fuego, mangle cortado, basura, agua contaminada). Las incoherencias se marcan.
4. **Corroboración:** otros reportes o confirmaciones de usuarios cercanos.
5. **Reputación del reportante:**
   - El teléfono verificado por WhatsApp o la app suma.
   - También suma tener reportes validados antes.
   - Hay límites de envío para frenar el spam.
   - Se permite reportar **de forma anónima** para proteger a quien denuncia, pero eso pesa menos en el puntaje.
6. **Validación humana:** un vigía comunitario o un funcionario de la CRA confirma.

**Estados del reporte:**
`recibido → en verificación → verificado → alerta oficial (abre expediente) → en atención → cerrado`, o bien `descartado`.

Cada cambio de estado queda en un **registro de auditoría**: quién, cuándo y por qué.

### 3. ¿Cómo se sostiene la participación?

- **Ver el impacto.** Quien reporta recibe aviso por WhatsApp o en la app cuando su reporte se verifica o cuando generó un operativo. Es lo que más motiva.
- **Colegios:**
  - El monitoreo validado puede contar como **horas de servicio social estudiantil** (obligatorio en bachillerato) y conectarse con el **PRAE** (Proyecto Ambiental Escolar).
  - Ranking de colegios «Guardianes del manglar».
  - Misiones mensuales de Zanqui, por ejemplo «revisa el caño X» o «cuenta residuos en la playa Y».
- **Turistas:**
  - **Letreros con QR o NFC** en el Ecoparque Mallorquín, Puerto Colombia y las playas. Escanean y reportan desde la web o WhatsApp, sin instalar nada.
  - Zanqui como recuerdo digital (insignia o sticker).
- **Gamificación con sentido:**
  - Zanqui crece con los reportes **validados**, no con la cantidad. Así no se premia el spam.
  - Insignias por tipo de aporte.
- **Alianzas:** empresas que ya hacen RSE en el manglar patrocinan premios o reconocimientos. Los operadores turísticos y las asociaciones de pescadores actúan como vigías.
- **Transparencia:** los datos abiertos y el mapa público muestran que la herramienta sirve.

## Datos abiertos (Gobierno Digital)

- **Formatos:** GeoJSON, CSV y KML (para Google Earth), descargables desde el panel y la vista pública.
- **Campos públicos:** id, fecha y hora, tipo, municipio, zona, prioridad, estado, latitud y longitud, y canal.
- **Nunca se publican:** el nombre, el teléfono ni las fotos del reportante, ni los metadatos de ubicación de las fotos.
- **Licencia sugerida:** CC BY 4.0. Se puede publicar en datos.gov.co.

## Seguridad y privacidad

El mentor de ciberseguridad va a revisar el código, así que hay que cumplir esto desde el principio:

- **Secretos:** nada de secretos en el repositorio; usar `.env` y un `.env.example`.
- **Servidor:** roles verificados en el servidor (ciudadano, vigía, moderador de la CRA, administrador) y validación de entradas.
- **Fotos:** quitarles los metadatos de ubicación antes de mostrarlas en público.
- **Denunciantes:**
  - Proteger su identidad: la opción anónima y el teléfono guardado como hash.
  - Coordenadas más imprecisas en la vista pública para las denuncias sensibles.
- **Ley 1581 (datos personales):** aviso de privacidad y consentimiento al reportar.
- **Abuso:** límites de envío y registro de auditoría.

## Modelo de datos mínimo (borrador)

```
reporte: id, canal (app|web|whatsapp), tipo, descripcion,
         lat, lon, precision_m, capturado_en, recibido_en,
         zona, municipio, dentro_poligono, distancia_m,
         prioridad (1-5), confianza (0-100), estado,
         ia_tipo_detectado, ia_confianza, foto_hash, reportante_id (nullable)
foto:    id, reporte_id, url, hash
historial_estado: id, reporte_id, estado, usuario_id, nota, fecha
usuario: id, rol, telefono_hash, colegio_id, puntos, insignias
zona:    id, nombre, municipio, prioridad_conservacion, geometria
```

## Tipos de reporte (borrador; validar con los mentores)

1. Tala o corte de mangle.
2. Quema o incendio.
3. Relleno o construcción en el manglar.
4. Vertimiento o contaminación del agua.
5. Basuras o residuos.
6. Caño taponado o alteración del agua.
7. Fauna afectada: caza, mortandad de peces o aves.
8. Otro.

## Reparto sugerido (equipo de 3)

| Persona | Pieza | Hito a las 12:00 | Hito a las 14:30 | Hito a las 16:00 |
|---|---|---|---|---|
| A | App Flutter | Reporte con GPS y foto, guardado sin conexión | Sincronización con el backend y mapa | Zanqui e insignias, pulido |
| B | Web: panel y vista pública | Mapa con reportes en vivo | Validación, estados y prioridad | Exportación GeoJSON/CSV/KML y vista pública |
| C | Backend, bot de WhatsApp e IA | API y base de datos con polígonos cargados | Bot funcionando de punta a punta | Clasificación con IA y puntaje de confianza |

- **Todos:**
  - Lista de tipos y prioridades con los mentores, antes de las 11:00.
  - Video a las 16:00–16:30.
  - Entrega a las 17:00.
  - Ensayo del pitch antes de las 19:00.
- **Congelar funciones a las 16:00:** después de esa hora, solo arreglos y la demo.
