// Entrada HTTPS de una magnitud por sensor físico. El lote permite reenviar muestras sin conexión.
// Desplegar con --no-verify-jwt: aquí se valida el token propio de cada sensor.
declare const Deno: {
  env: { get(nombre: string): string | undefined };
  serve(manejador: (peticion: Request) => Response | Promise<Response>): void;
};

type Tipo = "nivel_agua" | "salinidad" | "temperatura" | "turbidez";
type Lectura = { tipo: Tipo; valor: number; unidad: string; medido_en: string };
type Sensor = { tipo: Tipo; activo: boolean };
const medidas: Record<Tipo, { unidad: string; minimo: number; maximo: number }> = {
  nivel_agua: { unidad: "m", minimo: 0, maximo: 10 },
  salinidad: { unidad: "ppt", minimo: 0, maximo: 60 },
  temperatura: { unidad: "°C", minimo: -5, maximo: 60 },
  turbidez: { unidad: "NTU", minimo: 0, maximo: 4000 },
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function responder(estado: number, error: string, extra: Record<string, unknown> = {}): Response {
  return new Response(JSON.stringify({ error, ...extra }), {
    status: estado, headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function validarLecturas(valor: unknown, tipo: Tipo): valor is Lectura[] {
  if (!Array.isArray(valor) || valor.length < 1 || valor.length > 32) return false;
  const ahora = Date.now();
  return valor.every((lectura) => {
    if (!lectura || typeof lectura !== "object") return false;
    const l = lectura as Record<string, unknown>;
    const rango = medidas[tipo];
    if (l.tipo !== tipo || l.unidad !== rango.unidad ||
        typeof l.valor !== "number" || !Number.isFinite(l.valor) ||
        l.valor < rango.minimo || l.valor > rango.maximo ||
        typeof l.medido_en !== "string" ||
        !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-]\d\d:\d\d)$/.test(l.medido_en)) return false;
    const fecha = Date.parse(l.medido_en);
    return Number.isFinite(fecha) && fecha <= ahora + 5 * 60_000 && fecha >= ahora - 7 * 86_400_000;
  });
}

async function consultar(base: string, clave: string, ruta: string): Promise<unknown> {
  const respuesta = await fetch(`${base}/rest/v1/${ruta}`, {
    headers: { apikey: clave, authorization: `Bearer ${clave}` },
  });
  if (!respuesta.ok) throw new Error(`consulta_${respuesta.status}`);
  return respuesta.json();
}

Deno.serve(async (peticion) => {
  if (peticion.method !== "POST") return responder(405, "metodo_no_permitido");
  const autorizacion = peticion.headers.get("authorization") ?? "";
  const coincidencia = /^Bearer ([A-Za-z0-9_-]{32,128})$/.exec(autorizacion);
  if (!coincidencia) return responder(401, "token_de_sensor_requerido");
  const longitud = Number(peticion.headers.get("content-length") ?? 0);
  if (longitud > 16_384) return responder(422, "lote_demasiado_grande");
  let cuerpo: Record<string, unknown>;
  try {
    const texto = await peticion.text();
    if (texto.length > 16_384) return responder(422, "lote_demasiado_grande");
    const analizado: unknown = JSON.parse(texto);
    if (!analizado || typeof analizado !== "object" || Array.isArray(analizado)) throw new Error();
    cuerpo = analizado as Record<string, unknown>;
  } catch {
    return responder(422, "json_invalido");
  }
  if (typeof cuerpo.sensor_id !== "string" || !uuid.test(cuerpo.sensor_id)) {
    return responder(422, "sensor_id_invalido");
  }
  const base = Deno.env.get("SUPABASE_URL")?.replace(/\/$/, "");
  const clave = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!base || !clave) return responder(500, "servidor_sin_configurar");

  try {
    const bytes = new TextEncoder().encode(coincidencia[1]);
    const digest = await crypto.subtle.digest("SHA-256", bytes);
    const hash = Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
    const id = encodeURIComponent(cuerpo.sensor_id);
    const tokens = await consultar(base, clave,
      `sensor_tokens?select=sensor_id&sensor_id=eq.${id}&token_sha256=eq.${hash}`);
    if (!Array.isArray(tokens) || tokens.length !== 1) return responder(401, "token_o_sensor_no_autorizado");
    const sensores = await consultar(base, clave, `sensores?select=tipo,activo&id=eq.${id}`);
    const sensor = Array.isArray(sensores) ? sensores[0] as Sensor | undefined : undefined;
    if (!sensor?.activo || !(sensor.tipo in medidas)) return responder(401, "sensor_inactivo_o_no_autorizado");
    if (!validarLecturas(cuerpo.lecturas, sensor.tipo)) {
      return responder(422, "lecturas_invalidas", {
        detalle: "Tipo, unidad, rango físico o fecha inválidos; máximo 32 muestras de los últimos 7 días.",
      });
    }

    const respuesta = await fetch(`${base}/rest/v1/rpc/registrar_lote_sensor`, {
      method: "POST",
      headers: {
        apikey: clave, authorization: `Bearer ${clave}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ p_sensor_id: cuerpo.sensor_id, p_token_sha256: hash, p_lecturas: cuerpo.lecturas }),
    });
    const resultado = await respuesta.json();
    if (!respuesta.ok) {
      if (resultado.code === "28000") return responder(401, "token_o_sensor_no_autorizado");
      if (resultado.message === "limite_de_tasa") {
        return new Response(JSON.stringify({ error: "limite_de_tasa" }), {
          status: 429, headers: { "content-type": "application/json", "retry-after": "30" },
        });
      }
      if (resultado.code === "22023" || resultado.code === "22P02") return responder(422, "lecturas_invalidas");
      throw new Error(`registro_${respuesta.status}`);
    }
    return new Response(JSON.stringify(resultado), {
      status: 200, headers: { "content-type": "application/json; charset=utf-8" },
    });
  } catch (error) {
    console.error("lectura-sensor", error instanceof Error ? error.message : error);
    return responder(500, "fallo_interno");
  }
});
