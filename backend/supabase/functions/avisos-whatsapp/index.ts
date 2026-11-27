// Ejecutar con JWT verificado y llamar únicamente con service_role desde un cron seguro.
// No se registra ningún teléfono, token ni cuerpo de Meta en logs.
declare const Deno: {
  env: { get(nombre: string): string | undefined };
  serve(manejador: (peticion: Request) => Response | Promise<Response>): void;
};

type Aviso = {
  id: string;
  plantilla: "zanky_alerta_zona" | "zanky_apoyo_confirmado";
  datos: { zona?: string; tipo?: string; prioridad?: string };
  telefono_e164: string | null;
  intentos: number;
};

const respuesta = (status: number, datos: Record<string, unknown>) =>
  new Response(JSON.stringify(datos), {
    status, headers: { "content-type": "application/json; charset=utf-8" },
  });

async function rpc(base: string, clave: string, nombre: string, datos: Record<string, unknown>): Promise<unknown> {
  const res = await fetch(`${base}/rest/v1/rpc/${nombre}`, {
    method: "POST",
    headers: { apikey: clave, authorization: `Bearer ${clave}`, "content-type": "application/json" },
    body: JSON.stringify(datos),
  });
  if (!res.ok) throw new Error(`rpc_${nombre}_${res.status}`);
  return await res.json();
}

function parametros(a: Aviso): string[] {
  const d = a.datos;
  if (a.plantilla === "zanky_apoyo_confirmado") return [d.zona ?? "zona", d.tipo ?? "aviso"];
  if (a.plantilla === "zanky_alerta_zona") {
    return [d.zona ?? "zona", d.tipo ?? "aviso", d.prioridad ?? "alta"];
  }
  throw new Error("plantilla_no_permitida");
}

async function enviar(a: Aviso, token: string, phoneId: string): Promise<void> {
  if (!a.telefono_e164 || !/^\+[1-9][0-9]{7,14}$/.test(a.telefono_e164)) {
    throw new Error("destinatario_invalido");
  }
  const valores = parametros(a);
  // La versión se puede actualizar sin publicar otra función.
  const version = Deno.env.get("META_GRAPH_VERSION") ?? "v26.0";
  if (!/^v[0-9]+\.0$/.test(version)) throw new Error("version_meta_invalida");
  const res = await fetch(`https://graph.facebook.com/${version}/${encodeURIComponent(phoneId)}/messages`, {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      to: a.telefono_e164.slice(1),
      type: "template",
      template: {
        name: a.plantilla,
        language: { code: "es_CO" },
        components: [{ type: "body", parameters: valores.map((text) => ({ type: "text", text })) }],
      },
    }),
    signal: AbortSignal.timeout(15000),
  });
  if (!res.ok) throw new Error(`meta_${res.status}`);
  const cuerpo: unknown = await res.json();
  if (!cuerpo || typeof cuerpo !== "object" || !Array.isArray((cuerpo as Record<string, unknown>).messages)
      || (cuerpo as { messages: unknown[] }).messages.length < 1) {
    throw new Error("meta_sin_confirmacion");
  }
}

Deno.serve(async (peticion) => {
  if (peticion.method !== "POST") return respuesta(405, { error: "metodo_no_permitido" });
  const base = Deno.env.get("SUPABASE_URL")?.replace(/\/$/, "");
  const clave = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!base || !clave) return respuesta(500, { error: "servidor_sin_configurar" });
  if (peticion.headers.get("authorization") !== `Bearer ${clave}`) {
    return respuesta(401, { error: "sin_permiso" });
  }
  const token = Deno.env.get("META_TOKEN");
  const phoneId = Deno.env.get("META_PHONE_ID");
  try {
    if (!token || !phoneId) {
      const pendientes = await rpc(base, clave, "contar_avisos_pendientes", { canal: "whatsapp" });
      console.info("[avisos-whatsapp] modo seco", { pendientes });
      return respuesta(200, { modo: "seco", pendientes });
    }
    const lote = await rpc(base, clave, "tomar_avisos", { canal: "whatsapp", limite: 20 });
    if (!Array.isArray(lote)) throw new Error("cola_invalida");
    let enviados = 0;
    let fallidos = 0;
    for (const valor of lote) {
      const aviso = valor as Aviso;
      let exito = false;
      try {
        await enviar(aviso, token, phoneId);
        exito = true;
      } catch (e) {
        fallidos++;
        console.error("[avisos-whatsapp] envio", e instanceof Error ? e.message : "error_desconocido");
      }
      // La RPC programa la espera exponencial si falló. Si marcar falla, el lease se recupera.
      await rpc(base, clave, "marcar_aviso", { id: aviso.id, estado: exito ? "enviado" : "fallido" });
      if (exito) enviados++;
      await new Promise((resolver) => setTimeout(resolver, 300));
    }
    console.info("[avisos-whatsapp] lote", { tomados: lote.length, enviados, fallidos });
    return respuesta(200, { tomados: lote.length, enviados, fallidos });
  } catch (e) {
    console.error("[avisos-whatsapp] ejecucion", e instanceof Error ? e.message : "error_desconocido");
    return respuesta(502, { error: "envio_no_confirmado" });
  }
});
