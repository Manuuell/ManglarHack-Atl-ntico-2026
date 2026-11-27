# Zanky BOT

El canal de WhatsApp de Zanky. Lo usan pescadores, habitantes y turistas para reportar amenazas al manglar del Atlántico sin instalar nada.

Funciona sobre la **API oficial de WhatsApp Cloud (Meta)** con Node.js 20+, TypeScript y Express.

## La conversación

```
hola → menú (🚨 Reportar · 📋 Mis reportes · ℹ️ Cómo funciona)
  🚨 Reportar
    → consentimiento Ley 1581 (solo la primera vez): con mi número / anónimo / no acepto
    → tipo de amenaza (lista): tala, quema, relleno, vertimiento, caño tapado, fauna, basuras, otra
    → ubicación: botón nativo "Enviar ubicación" o enlace de Google Maps
        · se cruza con los polígonos del manglar: dentro / a X m / lejos (pregunta si es correcta)
    → foto tomada en el momento (o "Sin foto")
    → descripción corta (o "Omitir")
    → ¿cuándo? ahora mismo / hoy / hace días
    → resumen → ✅ Enviar → número de caso ZK-0001
```

- **Cualquier paso:** `menu` vuelve al inicio y `cancelar` descarta el reporte.
- **Cambios de estado:** si la persona reportó con su número, el bot le avisa cuando la CRA cambia el estado de su reporte.

## Prioridad y confianza

Cada reporte se guarda con dos puntajes, para que el panel de la CRA decida qué atender primero y qué tan confiable es el dato.

**Prioridad (1 a 5)** = gravedad del tipo de amenaza, ajustada por:
- **+1** si la zona tiene prioridad de conservación 4 o 5;
- **−1** si está lejos del manglar;
- **−1** si pasó hace días;
- **+1** si otra persona reportó cerca en las últimas 24 horas.

**Confianza (0 a 100)** = 20 de base, más:

| Señal | Puntos |
|---|---|
| Foto | +25 (−30 si la foto ya se usó en otro reporte) |
| Ubicación | +20 por GPS, +10 por enlace o coordenadas |
| Posición frente al manglar | +15 dentro, +10 cerca, 0 lejos |
| Momento | +10 si es ahora, +5 si fue hoy |
| Reportes cercanos de otras personas | Hasta +20 |
| Descripción con detalle | +5 |
| Historial del reportante | +10 si tiene reportes verificados, −20 si tiene varios descartados |

Cada punto queda explicado en `motivosConfianza`. **La decisión final la toma una persona:** el reporte entra como `recibido` y solo la CRA lo pasa a `verificado` o `alerta_oficial`.

## Correrlo

```bash
cd bot
npm install
cp .env.example .env   # llenar los valores (ver abajo)
npm run simular        # conversación de prueba completa, sin WhatsApp
npm run dev            # servidor en http://localhost:3000
```

Sin `WHATSAPP_TOKEN`, el bot arranca en **modo simulación** y no envía nada a WhatsApp.

## Conectarlo a WhatsApp (Meta)

1. **Perfil del número:** en WhatsApp Manager → Números de teléfono → el número del bot → Perfil:
   - foto de Zanky;
   - descripción: «Reporta amenazas al manglar del Atlántico»;
   - nombre visible **Zanky BOT**. El cambio de nombre pasa por revisión de Meta y puede tardar.
2. **Token permanente:** Configuración del negocio → Usuarios del sistema → Generar token.
   - Permisos: `whatsapp_business_messaging` y `whatsapp_business_management`.
   - Asignarle la cuenta de WhatsApp.
   - Va en `WHATSAPP_TOKEN`.
3. **Secreto de la app:** developers.facebook.com → tu app → Configuración → Básica → Clave secreta. Va en `META_APP_SECRET`; con él se verifica la firma de cada webhook.
4. **URL pública con HTTPS:**
   - Para la demo, un túnel:
     ```bash
     cloudflared tunnel --url http://localhost:3000
     ```
     Este comando da una URL `https://….trycloudflare.com` que cambia cada vez que se corre.
   - Para algo estable, un servidor con dominio.
5. **Dirigir a Zanky solo los mensajes de este número** (*webhook override*), sin tocar otros números de la misma cuenta. El bot tiene que estar corriendo, porque Meta verifica la URL con `WHATSAPP_VERIFY_TOKEN`:
   ```bash
   source .env
   curl -X POST "https://graph.facebook.com/$GRAPH_API_VERSION/$WHATSAPP_PHONE_NUMBER_ID" \
     -H "Authorization: Bearer $WHATSAPP_TOKEN" -H "Content-Type: application/json" \
     -d "{\"webhook_configuration\":{\"override_callback_uri\":\"https://TU-URL/webhook\",\"verify_token\":\"$WHATSAPP_VERIFY_TOKEN\"}}"
   ```
   - **Comprobar:** `curl "https://graph.facebook.com/$GRAPH_API_VERSION/$WHATSAPP_PHONE_NUMBER_ID?fields=webhook_configuration" -H "Authorization: Bearer $WHATSAPP_TOKEN"`
   - **Deshacer:** el mismo POST con `"override_callback_uri":""`.
   - **Requisito:** la app tiene que estar suscrita a la cuenta de WhatsApp (`subscribed_apps`) con el campo `messages`.
   - Por si acaso, el bot ignora los mensajes dirigidos a otros números.
6. **Probar:** escribirle «hola» al número.

## Endpoints

| Ruta | Acceso | Qué devuelve |
|---|---|---|
| `GET /webhook` · `POST /webhook` | Meta (firma) | Verificación y mensajes entrantes |
| `GET /datos-abiertos/reportes.geojson` | Público | Reportes anonimizados en GeoJSON |
| `GET /datos-abiertos/reportes.csv` | Público | Los mismos datos en CSV |
| `GET /datos-abiertos/reportes.kml` | Público | Los mismos datos en KML (Google Earth) |
| `GET /api/reportes` | `x-api-key` | Reportes completos para el panel de la CRA |
| `PATCH /api/reportes/:codigo/estado` | `x-api-key` | Cambiar el estado; body: `{ "estado": "verificado", "por": "nombre", "nota": "…" }` |
| `GET /api/fotos/:archivo` | `x-api-key` | Foto de un reporte |
| `GET /health` | Público | Estado del servicio |

Estados posibles: `recibido`, `en_verificacion`, `verificado`, `alerta_oficial`, `en_atencion`, `cerrado`, `descartado`.

## Privacidad y seguridad

- **Datos abiertos:**
  - Nunca incluyen el contacto, la descripción libre ni las fotos.
  - Las coordenadas se redondean a unos 110 m.
  - Los reportes descartados no se publican.
- **Teléfonos:** se guardan como hash con sal. El número en claro solo se guarda si la persona eligió reportar con su número.
- **Firma:** se verifica `X-Hub-Signature-256` con `META_APP_SECRET`. Se ignoran los mensajes duplicados y los de otros números.
- **Abuso:** máximo 5 reportes por persona por hora.
- **Enlaces de Google Maps:** solo se expanden hacia dominios de Google Maps, para que el bot no haga peticiones a URLs arbitrarias.
- **Secretos:** van en `.env`, que no se sube al repositorio.

## Polígonos

Por defecto el bot usa `datos/manglares_atlantico_invemar_2020.geojson`, la capa de INVEMAR. Cuando llegue el KMZ de la CRA:
1. Convertirlo a GeoJSON (ver `handoff/04-datos.md`).
2. Apuntar `ZONAS_GEOJSON` al archivo nuevo.

El nombre de cada zona sale de la propiedad `nombre` o `Name`. Una propiedad `prioridad` (de 1 a 5) en cada polígono sube la prioridad de los reportes en esa zona.
