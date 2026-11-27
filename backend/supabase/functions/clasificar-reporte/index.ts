// Supabase Edge Function «clasificar-reporte» (Deno).
//
// Recibe {id} (o el cuerpo de un Database Webhook), baja la foto del bucket privado «evidencias», pide a Claude
// que diga qué amenaza muestra y escribe ia_tipo_detectado / ia_confianza / ia_motivo con la service_role,
// mediante la RPC registrar_clasificacion_ia (que además deja la línea de auditoría con actor «ia»).
//
// La IA NUNCA cambia estado ni prioridad: esa RPC no tiene forma de tocarlos. Una persona decide.
//
// Variables de entorno (Supabase las inyecta; las dos últimas se fijan con `supabase secrets set`):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   (automáticas)
//   ANTHROPIC_API_KEY                         (secreto; nunca en el código)
//   IA_WEBHOOK_SECRET                         (secreto compartido con ia.sql; ≥ 16 caracteres)
//
// Despliegue: `supabase functions deploy clasificar-reporte --no-verify-jwt` (la defensa es el secreto compartido).
import { createClient } from "@supabase/supabase-js";
import Anthropic from "@anthropic-ai/sdk";
import { clasificarConClaude } from "./modelo.ts";
import { extraerId, procesarReporte, secretoValido, type Deps } from "./nucleo.ts";

declare const Deno: {
  env: { get(k: string): string | undefined };
  serve(h: (req: Request) => Response | Promise<Response>): void;
};

function json(cuerpo: unknown, status = 200): Response {
  return new Response(JSON.stringify(cuerpo), { status, headers: { "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "metodo_no_permitido" }, 405);

  // 1) ¿Viene del webhook / del panel (RPC)? Sin el secreto compartido no se hace nada.
  if (!secretoValido(req.headers.get("x-webhook-secret"), Deno.env.get("IA_WEBHOOK_SECRET"))) {
    return json({ error: "no_autorizado" }, 401);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const llaveServicio = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const llaveIA = Deno.env.get("ANTHROPIC_API_KEY");
  if (!url || !llaveServicio || !llaveIA) return json({ error: "servidor_sin_configurar" }, 500);

  let cuerpo: unknown = null;
  try {
    cuerpo = await req.json();
  } catch { /* se valida abajo */ }
  const id = extraerId(cuerpo);
  if (!id) return json({ error: "id_invalido" }, 400);
  const forzar = new URL(req.url).searchParams.get("forzar") === "1";

  const db = createClient(url, llaveServicio, { auth: { persistSession: false, autoRefreshToken: false } });
  const claude = new Anthropic({ apiKey: llaveIA });

  const deps: Deps = {
    async leerReporte(rid) {
      const { data, error } = await db
        .from("reportes")
        .select("id,tipo,descripcion,foto_url,ia_tipo_detectado,ia_confianza,ia_motivo")
        .eq("id", rid)
        .maybeSingle();
      if (error) throw new Error("leer_reporte: " + error.message);
      return data;
    },
    async bajarFoto(ruta) {
      // foto_url = 'evidencias/<id>.jpg' (el trigger de schema.sql no deja otra cosa)
      const objeto = ruta.replace(/^evidencias\//, "");
      const { data, error } = await db.storage.from("evidencias").download(objeto);
      if (error || !data) return null; // aún no se subió
      return new Uint8Array(await data.arrayBuffer());
    },
    clasificar: (e) => clasificarConClaude(claude, e),
    async guardar(p) {
      const { error } = await db.rpc("registrar_clasificacion_ia", p);
      if (error) throw new Error("registrar_clasificacion_ia: " + error.message);
    },
  };

  try {
    const r = await procesarReporte(deps, id, { forzar });
    // 202 = todavía no hay nada que hacer (la foto o el reporte no han llegado): el otro disparador reintenta.
    const pendiente = r.resultado === "no_existe" || r.resultado === "foto_pendiente";
    return json({ id, ...r }, pendiente ? 202 : 200);
  } catch (e) {
    // Error de la base (no del modelo: ese caso ya se guardó como «No se pudo revisar con IA»).
    console.error("clasificar-reporte", id, e instanceof Error ? e.message : e);
    return json({ error: "fallo_interno" }, 500);
  }
});
