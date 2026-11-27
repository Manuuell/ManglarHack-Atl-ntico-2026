// Llamada a Claude (visión + salida estructurada). La comparten la Edge Function y probar.ts.
// Usa el SDK oficial de Anthropic; el cliente se crea fuera (la clave sale del entorno, nunca del código).
import type Anthropic from "@anthropic-ai/sdk";
import {
  construirTextoUsuario,
  ESQUEMA_SALIDA,
  MODELO,
  PROMPT_SISTEMA,
  type RespuestaModelo,
  type TipoMime,
} from "./nucleo.ts";

export const TIMEOUT_MS = 30_000;

export function aBase64(bytes: Uint8Array): string {
  let bin = "";
  const trozo = 0x8000;
  for (let i = 0; i < bytes.length; i += trozo) {
    bin += String.fromCharCode(...bytes.subarray(i, i + trozo));
  }
  return btoa(bin);
}

export async function clasificarConClaude(
  client: Anthropic,
  e: { foto: Uint8Array; mediaType: TipoMime; tipoReportado: string; descripcion: string },
): Promise<RespuestaModelo> {
  const resp = await client.messages.create(
    {
      model: MODELO, // claude-haiku-5-5: el más barato y rápido con visión; ver README «IA en la validación»
      max_tokens: 2048,
      system: PROMPT_SISTEMA,
      // Clasificar una foto no necesita razonar mucho: esfuerzo bajo = menos latencia y menos costo.
      // Sin temperature/top_p (Haiku 5.5 las rechaza) y sin prefill (también rechazado): el formato lo fija el esquema.
      output_config: { effort: "low", format: { type: "json_schema", schema: ESQUEMA_SALIDA } },
      messages: [
        {
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: e.mediaType, data: aBase64(e.foto) } },
            { type: "text", text: construirTextoUsuario(e.tipoReportado, e.descripcion) },
          ],
        },
      ],
    },
    { timeout: TIMEOUT_MS, maxRetries: 1 },
  );

  // Siempre mirar stop_reason antes de leer el contenido.
  if (resp.stop_reason === "refusal") throw new Error("el modelo rechazó la solicitud");
  if (resp.stop_reason === "max_tokens") throw new Error("la respuesta se cortó antes de terminar");
  const texto = resp.content
    .filter((b) => b.type === "text")
    .map((b) => (b as { text: string }).text)
    .join("");
  return {
    texto,
    modelo: resp.model ?? MODELO,
    uso: { input_tokens: resp.usage?.input_tokens, output_tokens: resp.usage?.output_tokens },
  };
}
