# 01 · El reto oficial

Esto es lo que dijo la CRA en el lanzamiento del 27-11-2026. La Dra. Pamela planteó el problema, y Mao (Mauricio, CRA) explicó las preguntas y los entregables.

## El problema

En el Atlántico todo el mundo quiere hacer algo por el manglar: bancos, colegios, municipios y comunidades. Pero **nada de eso se mide ni se georreferencia, y no hay una fuente única de información**.

Además, la CRA **no tiene guardias en terreno**. Se entera de las amenazas por denuncias que llegan tarde, por ejemplo «están talando manglar en Juan de Acosta para construir una escuela». Para entonces el daño ya puede estar hecho.

La CRA está armando una plataforma propia con dos partes:
1. Un visor técnico para uso interno, con datos satelitales.
2. Una parte abierta a la ciudadanía: registro de actores, propuestas de acciones, seguimiento y proyectos.

Lo que le falta es el **monitoreo ciudadano**, y ahí está el reto.

## El reto, en una frase

> **Diseña y prototipa una herramienta digital de ciencia ciudadana para monitorear en tiempo real el manglar del Atlántico.**

- **Quién la usa:** cualquier persona, colegio, turista o ciudadano que esté en la zona de manglar.
- **Conexión:** tiene que funcionar **con o sin conexión a internet**.
- **Qué hace:** cualquiera puede reportar **en tiempo real y con ubicación** una amenaza al ecosistema, y el reporte le llega a la CRA con detalle suficiente para hacer un operativo rápido.

## Las 3 preguntas de gobernanza que el prototipo DEBE responder

1. **¿Dónde está ocurriendo una amenaza o un cambio en el manglar *ahora mismo*, y con qué nivel de prioridad de conservación coincide?**
   - «Ahora mismo» es literal: un reporte de algo que pasó hace un mes no le sirve a la CRA para actuar.
   - La prioridad de conservación se define con los mentores ambientales.
2. **¿Cómo se valida que el dato ciudadano es confiable antes de usarlo en un expediente o una alerta oficial?**
   - «Si le ingresamos basura al sistema, nos sale basura». Ya han tenido gente que reporta locuras para sabotear.
   - La alerta abre un **expediente** en la CRA, que actúa sobre ese dato.
3. **¿Cómo se sostiene la participación de colegios y turistas en el tiempo, más allá del entusiasmo inicial?**
   - La CRA la va a lanzar, y no quiere que sea una moda de unos días. Tiene que ser sostenible y escalable.

## Qué amenazas se pueden reportar

Lo que mencionaron, para validar con los mentores comunitarios y ambientales:

- **Tala** de manglar, el reporte clásico.
- **Quema o incendio:** riesgo para la flora.
- **Vertimientos o contaminación:** riesgo para la calidad del agua.
- **Alteración hídrica**, por ejemplo un **caño taponado** que corta el agua dulce. El manglar necesita agua salada y agua dulce.
- **Riesgos para las especies** que habitan el manglar.

## Entregables por equipo

1. **Prototipo funcional, no solo un mockup.** Como mínimo debe:
   - **Demostrar cómo el reporte se geolocaliza** en las zonas de manglar.
   - Mostrar **una vista del panel de control** (dashboard).
   - Mostrar **cómo se exportan los datos en formato abierto**, porque Gobierno Digital obliga a la CRA a publicar datos abiertos.
2. **Pitch de máximo 7 minutos** ante el jurado.
3. **En Byte Arena**, en la zona de entrega:
   - El **enlace al repositorio de GitHub**.
   - Los archivos.
   - El **video del prototipo**.
   - La **ficha técnica**, con las herramientas y los **modelos de inteligencia artificial que se usaron**. La CRA quiere que se use IA.

## Qué entrega la CRA

- **Los polígonos del manglar en formato KMZ.** Son 4 zonas costeras: Barranquilla–Puerto Colombia (Mallorquín), Tubará, Juan de Acosta y Piojó, unas 775 ha. Ver [04-datos.md](04-datos.md).
- El acceso a su herramienta (el visor) en borrador.

## Lo que aclararon en las preguntas

- **No hay que usar datos satelitales en la herramienta ciudadana.**
  - Esos datos son de la CRA y solo para su monitoreo metodológico.
  - Se actualizan más o menos cada 13 semanas, y la CRA no controla esa fuente.
- **Lo importante es georreferenciar el suceso en tiempo real** desde el celular del ciudadano. Mencionaron Google Maps y Google Earth: «las herramientas que estén disponibles». Un pescador ve algo, saca el celular y reporta desde donde está.
- **Las alertas no son solo de bosque.** También cuentan los temas hídricos, como el taponamiento de un caño.

La transcripción completa está fuera del repositorio. Pídansela a Manuel si la necesitan.
