# 02 · El evento y la entrega

Manglar Hack Atlántico 2026 la organizan la CRA (Corporación Autónoma Regional del Atlántico) y la Universidad Simón Bolívar. Es el viernes 27-11-2026 en Cajacopi, sede Prado.

## Horario

| Hora | Qué pasa |
|---|---|
| 8:00 | Lanzamiento del reto |
| 8:30 | Empieza la competencia |
| **17:00** | **Entrega de prototipos en Byte Arena** |
| 19:00 | Pitch (máximo 7 minutos) y evaluación |
| ~20:30 | Cierre y premiación |

## Checklist de entrega (Byte Arena)

- [ ] Enlace a este repositorio, con un README claro.
- [ ] Prototipo funcional:
  - [ ] Reporte geolocalizado.
  - [ ] Vista del panel.
  - [ ] Exportación de datos abiertos.
- [ ] Video del prototipo, de 2 a 3 minutos, grabado antes de las 16:30.
- [ ] Ficha técnica con herramientas y modelos de IA (plantilla abajo).
- [ ] Presentación del pitch.
- [ ] Sin secretos en el repositorio: nada de `.env`, claves, tokens ni llaves.

## Quién es quién

- **CRA:**
  - Dra. Pamela: plantea el problema.
  - Mauricio («Mao») Bengoechea: líder de Ciencia, Tecnología e Innovación; explica la mecánica y las reglas.
- **Mentores:**
  - Uno tech y uno ambiental por equipo, asignados en Byte Arena.
  - **Mentores comunitarios:** pescadores de la Ciénaga de Mallorquín y una lideresa de Puerto Colombia. Son quienes mejor saben qué amenazas hay y cómo reporta la gente.
  - **Mentor de ciberseguridad y desarrollo:** uno solo, que pasa por todos los equipos **revisando el código**.
- **Jurado:** perfiles de ambiente, academia, sector privado, tecnología y gobierno. La calificación es con rúbrica; hay que pedirla y alinear el pitch con ella.

## Reglas

- Se puede usar cualquier tecnología. El hardware es opcional; si la solución lo necesita, hay que documentar los requisitos.
- La CRA quiere que se use **inteligencia artificial** y que se declare en la ficha técnica.

## Plantilla de ficha técnica

Hay que irla llenando durante el día.

| Componente | Herramientas y tecnologías | Modelos de IA | Para qué |
|---|---|---|---|
| App móvil | Flutter, … | | |
| Aplicación web (panel y público) | … | | |
| Bot de WhatsApp | … | | |
| Backend y base de datos | … | | |
| Validación de reportes | … | (modelo de visión o lenguaje) | Clasificar la foto y el texto del reporte |
| Documentación y análisis | Claude Code | Claude Opus 5.5 (Anthropic) | Análisis del reto, documentación y handoff |

## Estructura sugerida del pitch (7 min)

| Tiempo | Qué contar |
|---|---|
| 0:00–1:00 | El problema, con la historia de la tala en Juan de Acosta que se supo tarde. Presentar a Zanky. |
| 1:00–4:00 | **Demo en vivo:** un ciudadano reporta sin internet → se sincroniza → aparece en el panel con prioridad → la CRA lo valida → se exportan los datos abiertos. Mostrar también el reporte por WhatsApp. |
| 4:00–6:00 | **Las 3 preguntas**, una por una (ver [03-solucion-zanqui.md](03-solucion-zanqui.md)). |
| 6:00–7:00 | Sostenibilidad, seguridad y protección del denunciante, y los siguientes pasos con la CRA. |
