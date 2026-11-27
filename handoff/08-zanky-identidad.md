# 08 · Identidad de Zanky: prompts de diseño y video

Los prompts están en inglés porque los generadores de imagen y video los siguen mejor.

## Cómo mantener el personaje igual en todo

1. **Primero la hoja de personaje (prompt 1).** Elijan la mejor imagen y úsenla como **referencia** en todas las demás:
   - ChatGPT o Gemini: subir la imagen y pedir «el mismo personaje».
   - Midjourney: `--cref <url> --cw 100`.
   - Ideogram o Leonardo: la opción de referencia de personaje.
   - Video: usar *image-to-video* partiendo de una imagen fija.
2. **Pegar siempre el bloque BASE completo** al inicio de cada prompt.
3. **Textos dentro de la imagen** (stickers, letrero): Ideogram los escribe mejor. Si salen mal, generar sin texto y agregarlo en Canva o Figma.
4. **Declarar en la ficha técnica** las herramientas y los modelos de IA que se usen.

## Paleta

| Uso | Color |
|---|---|
| Hojas | `#2E7D32` / `#43A047` |
| Corteza | `#8B3A2B` |
| Raíces | `#6D3B2A` |
| Agua (color principal de fondo) | `#1FA2A6` |
| Carnaval: amarillo | `#F9C80E` |
| Carnaval: rojo | `#E63946` |
| Carnaval: verde | `#2A9D8F` |

## Bloque BASE (pegarlo siempre)

```
Zanky, a cute friendly mascot: an anthropomorphic young red mangrove tree (Rhizophora mangle) from the Caribbean coast of Colombia. Small rounded trunk-shaped body with smooth reddish-brown bark; a fluffy crown of glossy, leathery, oval dark-green mangrove leaves on top like hair; big expressive dark eyes with white highlights, a wide joyful smile, small leaf-shaped eyebrows. Instead of legs it stands tall on four long arched stilt roots (mangrove prop roots), like a carnival stilt-walker, each root wrapped with thin striped ribbons in red, yellow and green (Barranquilla carnival colors). Two thin branch arms with little leaf hands. One long slender green propagule (mangrove seed pod) hangs from its leafy crown like a cute antenna. Cheerful, curious, warm Caribbean personality. Not a generic oak or palm tree, no fruit, does not resemble any existing cartoon character.
```

Estilos para agregar al final:
- **3D, para videos y la portada:** `3D family-animation movie style, soft lighting, rounded shapes, high detail.`
- **Plano, para la app y los stickers:** `Flat vector illustration, clean thick outlines, limited palette, simple shapes.`

## Prompts de imagen

1. **Hoja de personaje**
   `[BASE] Character design turnaround sheet: front view, three-quarter view, side view, back view, plus a close-up of the face. Neutral standing pose. Plain white background, even studio lighting. 3D family-animation movie style. No text.`

2. **Expresiones**
   `[BASE] Expression sheet, six head-and-shoulders portraits in a 3x2 grid: happy smiling, surprised and alert, worried, celebrating with arms up, winking, thinking. White background, consistent character design. Flat vector illustration. No text.`

3. **Poses para la app** (una imagen por pose, en estilo plano y con fondo blanco o transparente):
   - **Bienvenida:** `[BASE] waving hello while standing in shallow lagoon water among mangroves.`
   - **Reportando:** `[BASE] holding a smartphone and taking a photo, a bright location pin floating above the phone.`
   - **Sin conexión:** `[BASE] calmly tucking a small glowing envelope into a woven shoulder bag, a "no signal" icon above, relaxed expression, as if saying "I'll send it later".`
   - **Validado:** `[BASE] giving a thumbs up next to a big green check-mark seal.`
   - **Alerta:** `[BASE] pointing at grey smoke rising above distant mangroves, concerned but determined expression.`
   - **Celebración:** `[BASE] dancing cumbia with its carnival ribbons flying, confetti around.`

4. **Etapas de crecimiento** (para la gamificación)
   `[BASE] Growth stages of the character, five figures from left to right on a white background: 1) a green mangrove propagule seed pod with tiny eyes, 2) a small seedling with two leaves and tiny roots, 3) a young sapling version of Zanky, 4) the full Zanky on tall stilt roots, 5) "guardian" Zanky wearing a small carnival paper-flower crown and a sash, proud pose. Consistent design, flat vector illustration. No text.`

5. **Ícono de la app**
   `App icon, rounded square: Zanky's face and leafy crown peeking from behind a white map location pin, teal water background with one simple wave. Bold simple shapes, readable at 48 px, flat vector. No text.`

6. **Avatar del bot de WhatsApp**
   `[BASE] circular profile picture, bust shot, waving, solid teal background, high contrast, flat vector. No text.`

7. **Stickers de WhatsApp**
   `[BASE] Sticker sheet with six stickers, each with a thick white die-cut border on a transparent background: waving; thumbs up; holding a phone with a location pin; shocked face; sleeping curled on a root (offline); dancing. Flat vector.`
   - Versión con texto (Ideogram): agregar `with the caption "¡Ajá!"` y repetir con «¡Reportado!», «Ojo al manglar», «¡Gracias, vigía!» y «¡Eche, qué bacano!».

8. **Letrero con QR para el territorio**
   `Vertical outdoor sign for a mangrove boardwalk. [BASE] pointing at an empty white square (space for a QR code). Headline text: "¿Viste algo raro en el manglar? ¡Repórtalo!". Subtitle: "Escanea o escríbele a Zanky por WhatsApp". Mangrove lagoon background, flat vector, high contrast.`
   - El QR real se pega después en el cuadro blanco.

9. **Portada del pitch o banner 16:9**
   `Wide 16:9 banner. [BASE] standing on its stilt roots in a Caribbean coastal lagoon with mangroves at golden hour, white egrets flying, a floating holographic map of the coastline with glowing location pins beside it, empty space on the left for a title. 3D family-animation movie style.`

## Prompts de video

Usar *image-to-video* partiendo de la hoja de personaje. Son clips de 8 a 10 segundos.

| # | Escena | Prompt |
|---|---|---|
| V1 | Intro | `Zanky walks toward the camera on its long stilt roots through shallow lagoon water among mangroves at sunrise, ripples under each step, white egrets take off in the background; it stops, waves and smiles at the camera. Slow dolly-in, warm light, 3D animation, 8 seconds.` |
| V2 | Alerta | `Zanky stands at the edge of the mangrove forest, notices smoke rising in the distance, its leaves shiver and its expression turns worried; it pulls out a smartphone and takes a photo, and a red location pin pops up above the phone. Medium shot, 3D animation, 8 seconds.` |
| V3 | Sin señal | `Close-up of a phone screen showing a "no signal" icon; Zanky calmly taps a button and the report turns into a small glowing envelope that tucks into its leafy crown. Cut to Zanky walking toward a fishing village, signal bars fill up, and the envelope flies off toward the city skyline. 3D animation, 10 seconds.` |
| V4 | Llega a la CRA | `A small glowing envelope lands on a large digital map of a Caribbean coastline on a dashboard screen; a red pin blinks with a priority badge, then turns green with a check mark. Clean motion graphics, 8 seconds.` |
| V5 | Participación | `Zanky dances cumbia on a Caribbean beach with a group of school children in uniforms holding phones, the carnival ribbons on its stilt roots flutter, confetti, golden hour, 3D animation, 8 seconds.` |
| V6 | Loop de inicio | `Seamless 3-second loop: Zanky bounces gently on its stilt roots and blinks, plain teal background, flat 2D animation.` |

**Frase de voz para el video:** «¡Ajá! Yo soy Zanky. Si ves que algo le pasa al manglar, repórtalo… ¡aunque no tengas señal!».

**Para la demo del pitch:** el jurado pide un prototipo funcional, así que conviene usar **grabación de pantalla del prototipo real**. Los clips de IA quedan para la intro y el cierre; V4 se reemplaza por el panel real.
