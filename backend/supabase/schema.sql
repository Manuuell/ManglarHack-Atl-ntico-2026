-- =====================================================================================
-- Zanky · Manglar Hack Atlántico 2026 · Backend común (Supabase = Postgres 15 + PostGIS 3)
-- =====================================================================================
-- Se pega ENTERO en el SQL Editor de Supabase (rol postgres). Es idempotente: se puede
-- volver a correr sin romper nada ni duplicar nada.
-- Orden de carga: schema.sql -> zonas-N.sql -> prioridades-N.sql -> seed_demo.sql (opcional, solo demo).
-- (El orden y el peso de cada archivo están en README.md.)
--
-- Principios (por qué está hecho así; el detalle está en README.md):
--  1. El permiso se decide en el SERVIDOR y en UN solo lugar: panel_rol_de(uid), que lee la
--     tabla panel_roles (no el token). Quitar un rol surte efecto al instante.
--  2. El público (anon) solo puede crear un reporte nuevo (con crear_reporte) y leer la vista anonimizada.
--     Nunca lee ni escribe la tabla reportes directamente. Lo que no manda el servidor, no se confía en el cliente.
--  3. Todo lo sensible que mira el panel (foto, denunciante, ficha) queda en auditoria, que
--     es solo-INSERT: nadie la edita ni la borra.
--  4. Nada de secretos aquí: este archivo es público.
-- =====================================================================================

create extension if not exists postgis with schema extensions;
-- Las funciones y tablas encuentran PostGIS en "extensions" (Supabase) o en "public".
set search_path = public, extensions;

-- -------------------------------------------------------------------------------------
-- 1. ZONAS DE MANGLAR Y PRIORIDADES DE CONSERVACIÓN (capa oficial de la CRA)
-- -------------------------------------------------------------------------------------
-- zonas: cobertura de manglar del Atlántico de la CRA a escala 1:5.000 (649,66 ha, 886 polígonos,
-- 4 zonas); se carga con zonas-N.sql. prioridad_conservacion es DERIVADA (alta 5, media 4, baja 3)
-- de la prioridad dominante en la zona: solo informativa. La que cuenta para la prioridad de un
-- reporte es la de prioridades_cra, punto por punto.
create table if not exists public.zonas (
  id                     text primary key,
  nombre                 text not null,
  municipio              text not null,
  prioridad_conservacion int  not null check (prioridad_conservacion between 1 and 5),
  geom                   geometry(MultiPolygon, 4326) not null,
  -- Copia en geography para medir distancias en metros sobre el elipsoide.
  geog                   geography generated always as (geom::geography) stored
);
create index if not exists zonas_geog_gix on public.zonas using gist (geog);
create index if not exists zonas_geom_gix on public.zonas using gist (geom);

-- Prioridades de conservación de la CRA (Alta/Media/Baja), 458 filas con 9.274 polígonos; se cargan con
-- prioridades-N.sql. MISMA estructura que crea prioridades-1.sql (create table if not exists: da igual
-- cuál de los dos corra primero). Vacía, el trigger de recepción simplemente no suma nada.
create table if not exists public.prioridades_cra (
  id             bigint generated always as identity primary key,
  prioridad      text not null check (prioridad in ('alta','media','baja')),
  accion         text not null,                 -- Preservación, Restauración, Recuperación, Rehabilitación
  escenario      text not null,                 -- Escenario I, Escenario III…
  area_protegida text,                          -- p. ej. Palmar Titi; null si no está en un área protegida
  unidad         text,                          -- unidad hidrográfica
  geom           geometry(MultiPolygon, 4326) not null
);
create index if not exists prioridades_cra_geom_gix on public.prioridades_cra using gist (geom);

-- -------------------------------------------------------------------------------------
-- 2. REPORTES (contrato = Reporte.aServidor() de la app, handoff/05)
-- -------------------------------------------------------------------------------------
create sequence if not exists public.expediente_seq;

create table if not exists public.reportes (
  -- ===== lo que manda el cliente (las 23 columnas de aServidor) =====
  id                 uuid primary key default gen_random_uuid(), -- lo pone el dispositivo: un reintento no duplica
  canal              text not null default 'app'
                       check (canal in ('app', 'web', 'whatsapp')),
  tipo               text not null
                       check (tipo in ('tala','quema','relleno','vertimiento','basuras','cano_taponado','fauna','otro')),
  descripcion        text not null default '' check (char_length(descripcion) <= 1000),
  lat                double precision not null check (lat between 10.2 and 11.4),    -- Atlántico ampliado
  lon                double precision not null check (lon between -75.7 and -74.4),
  precision_m        double precision check (precision_m is null or (precision_m >= 0 and precision_m <= 100000)),
  metodo_ubicacion   text not null default 'gps' check (metodo_ubicacion in ('gps', 'mapa', 'enlace')),
  capturado_en       timestamptz not null,                      -- hora del teléfono
  momento            text not null default 'ahora' check (momento in ('ahora', 'hoy', 'antes')),
  magnitud           text not null default 'pequena' check (magnitud in ('pequena', 'mediana', 'grande')),
  zona               text,            -- el servidor la recalcula (trigger)
  municipio          text,            -- idem
  dentro_poligono    boolean not null default false,            -- idem
  distancia_m        integer check (distancia_m is null or distancia_m >= 0), -- idem
  prioridad          int  not null default 3 check (prioridad between 1 and 5), -- el servidor la recalcula
  confianza          int  not null default 0 check (confianza between 0 and 100), -- el servidor la acota
  foto_hash          text check (foto_hash is null or foto_hash ~ '^[0-9a-f]{64}$'),
  foto_de_camara     boolean not null default false,
  foto_url           text check (foto_url is null or foto_url ~ '^evidencias/[0-9a-f-]{36}\.jpg$'),
  anonimo            boolean not null default false,
  reportante_id      text check (reportante_id is null or char_length(reportante_id) <= 64),
  sincronizado_tarde boolean not null default false,

  -- ===== lo que fija SOLO el servidor =====
  estado             text not null default 'recibido'
                       check (estado in ('recibido','en_verificacion','verificado','alerta_oficial','en_atencion','cerrado','descartado')),
  recibido_en        timestamptz not null default now(),        -- hora del servidor
  actualizado_en     timestamptz not null default now(),
  geom               geography(Point, 4326)
                       generated always as (ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography) stored,
  ia_tipo_detectado  text check (ia_tipo_detectado is null
                       or ia_tipo_detectado in ('tala','quema','relleno','vertimiento','basuras','cano_taponado','fauna','otro')),
  ia_confianza       int check (ia_confianza is null or ia_confianza between 0 and 100),
  ia_motivo          text check (ia_motivo is null or char_length(ia_motivo) <= 1000),
  corroboraciones    int  not null default 0 check (corroboraciones >= 0),
  nota_publica       text check (nota_publica is null or char_length(nota_publica) <= 280), -- la ve quien reportó
  expediente         text,                                       -- CRA-MH-2026-0001, al pasar a alerta_oficial
  -- Id que sale al público (vista, datos abiertos). Es otro UUID al azar, sin relación con id: el id interno
  -- es la llave para consultar el estado (estado_de_reportes) y nunca se publica.
  id_publico         uuid not null default gen_random_uuid(),

  -- No se acepta un reporte capturado "en el futuro" (más de 10 min de margen por el reloj del teléfono).
  constraint reportes_capturado_no_futuro check (capturado_en <= recibido_en + interval '10 minutes'),
  constraint reportes_capturado_razonable check (capturado_en >= timestamptz '2020-01-01 00:00:00+00')
);

-- Bases creadas antes de id_publico: se agrega sin tocar lo demás (cada fila recibe su propio UUID al azar).
alter table public.reportes add column if not exists id_publico uuid not null default gen_random_uuid();

create unique index if not exists reportes_expediente_uq on public.reportes (expediente) where expediente is not null;
create unique index if not exists reportes_id_publico_uq on public.reportes (id_publico);
create index if not exists reportes_geom_gix        on public.reportes using gist (geom);
create index if not exists reportes_capturado_ix    on public.reportes (capturado_en desc);
create index if not exists reportes_estado_ix       on public.reportes (estado, prioridad desc);
create index if not exists reportes_tipo_cap_ix     on public.reportes (tipo, capturado_en);
create index if not exists reportes_reportante_ix   on public.reportes (reportante_id, recibido_en) where reportante_id is not null;

-- -------------------------------------------------------------------------------------
-- 3. HISTORIAL DE ESTADO, AUDITORÍA y ROLES DEL PANEL
-- -------------------------------------------------------------------------------------
create table if not exists public.historial_estado (
  id          bigint generated always as identity primary key,
  reporte_id  uuid not null references public.reportes (id),
  estado      text not null,
  usuario_id  uuid,                     -- null = sistema (recepción automática)
  rol         text,
  nota        text,                     -- nota INTERNA (la ve solo el panel)
  creado_en   timestamptz not null default now()
);
create index if not exists historial_reporte_ix on public.historial_estado (reporte_id, creado_en);

create table if not exists public.auditoria (
  id           bigint generated always as identity primary key,
  creado_en    timestamptz not null default now(),
  usuario_id   uuid,                    -- null = sistema / SQL Editor
  rol          text not null default 'sistema',
  accion       text not null check (accion in
                 ('cambio_estado','miro_foto','miro_reporte','miro_reportante','asignar_rol','revocar_rol','exportar')),
  objeto_tipo  text not null,           -- 'reporte', 'panel_roles', ...
  objeto_id    text,
  detalle      jsonb not null default '{}'::jsonb
);
create index if not exists auditoria_usuario_ix on public.auditoria (usuario_id, creado_en desc);
create index if not exists auditoria_objeto_ix  on public.auditoria (objeto_tipo, objeto_id, creado_en desc);
create index if not exists auditoria_foto_ix    on public.auditoria (usuario_id, objeto_id, creado_en desc) where accion = 'miro_foto';

-- Roles del panel. Fuente única de verdad de los permisos (no se lee del token).
create table if not exists public.panel_roles (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  rol         text not null check (rol in ('admin', 'moderador_cra', 'vigia', 'aliado')),
  activo      boolean not null default true,
  revocado_en timestamptz,
  creado_en   timestamptz not null default now(),
  creado_por  uuid
);

-- Solo-INSERT de verdad: ni siquiera el dueño de la tabla actualiza o borra por error.
create or replace function public.bloquear_modificacion()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  raise exception 'La tabla % es solo de lectura/inserción: no se modifica ni se borra', tg_table_name
    using errcode = '42501';
end $$;

drop trigger if exists auditoria_inmutable_fila on public.auditoria;
create trigger auditoria_inmutable_fila before update or delete on public.auditoria
  for each row execute function public.bloquear_modificacion();
drop trigger if exists auditoria_inmutable_trunc on public.auditoria;
create trigger auditoria_inmutable_trunc before truncate on public.auditoria
  for each statement execute function public.bloquear_modificacion();

drop trigger if exists historial_inmutable_fila on public.historial_estado;
create trigger historial_inmutable_fila before update or delete on public.historial_estado
  for each row execute function public.bloquear_modificacion();
drop trigger if exists historial_inmutable_trunc on public.historial_estado;
create trigger historial_inmutable_trunc before truncate on public.historial_estado
  for each statement execute function public.bloquear_modificacion();

-- -------------------------------------------------------------------------------------
-- 4. PERMISOS: UNA función, panel_rol_de(uid)
-- -------------------------------------------------------------------------------------
-- Confirma el rol contra la tabla panel_roles (no contra el token): si a alguien le quitan el
-- rol, la próxima llamada ya no pasa, aunque su sesión siga viva. Un usuario solo puede
-- preguntar por SÍ MISMO (evita enumerar quién es admin); service_role y el SQL Editor, por cualquiera.
create or replace function public.panel_rol_de(uid uuid)
returns text language plpgsql stable security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_rol text;
begin
  if uid is null then return null; end if;
  if uid is distinct from auth.uid() and coalesce(auth.role(), 'service_role') <> 'service_role' then
    return null;
  end if;
  select pr.rol into v_rol
    from public.panel_roles pr
   where pr.user_id = uid and pr.activo and pr.revocado_en is null;
  return v_rol;
end $$;

-- Auditoría interna (no se expone por la API).
create or replace function public.auditar(p_accion text, p_tipo text, p_objeto text, p_detalle jsonb default '{}'::jsonb)
returns void language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
begin
  insert into public.auditoria (usuario_id, rol, accion, objeto_tipo, objeto_id, detalle)
  values (auth.uid(), coalesce(public.panel_rol_de(auth.uid()), 'sistema'), p_accion, p_tipo, p_objeto,
          coalesce(p_detalle, '{}'::jsonb));
end $$;

-- Toda asignación o revocación de rol queda en auditoría, venga de donde venga (RPC o SQL Editor).
create or replace function public.panel_roles_audita()
returns trigger language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
begin
  perform public.auditar(
    case when new.activo and new.revocado_en is null then 'asignar_rol' else 'revocar_rol' end,
    'panel_roles', new.user_id::text,
    jsonb_build_object('rol', new.rol, 'activo', new.activo, 'operacion', tg_op));
  return new;
end $$;

drop trigger if exists panel_roles_audita_trg on public.panel_roles;
create trigger panel_roles_audita_trg after insert or update on public.panel_roles
  for each row execute function public.panel_roles_audita();

create or replace function public._orden_estado(p_estado text)
returns int language sql immutable set search_path = public as $$
  select case p_estado
    when 'recibido' then 1 when 'en_verificacion' then 2 when 'verificado' then 3
    when 'alerta_oficial' then 4 when 'en_atencion' then 5 when 'cerrado' then 6 else null end
$$;

-- -------------------------------------------------------------------------------------
-- 5. TRIGGER DE RECEPCIÓN: el servidor manda (BEFORE INSERT)
-- -------------------------------------------------------------------------------------
-- Lo que el cliente dice de zona, distancia, prioridad, estado, hora de recepción, IA,
-- expediente y nota pública NO se cree: se recalcula o se anula aquí.
-- La prioridad repite la lógica de app/lib/datos/prioridad.dart (Prioridad.calcular), menos
-- el viento de Open-Meteo para incendios (el servidor no lo consulta todavía).
create or replace function public.reportes_antes_insert()
returns trigger language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_pto   geography;
  v_zona  record;
  v_alta  boolean := false;   -- el punto cae en una zona de prioridad de conservación ALTA de la CRA
  v_n     int;
  v_corr  int;
  v_p     int;
begin
  -- Reintento de un reporte que ya llegó: se ignora en silencio (idempotente) y NO cuenta para
  -- el límite. (La app entra por crear_reporte(), que además usa ON CONFLICT (id) DO NOTHING para
  -- la carrera de dos envíos simultáneos; esto evita que un reintento reciba un error de límite.)
  if exists (select 1 from public.reportes r where r.id = new.id) then
    return null;
  end if;

  -- Anónimo de verdad: no se guarda quién fue.
  new.reportante_id := nullif(btrim(new.reportante_id), '');
  if new.anonimo then new.reportante_id := null; end if;

  -- Límite anti-spam: 10 reportes por reportante_id por hora.
  -- Si reportante_id es null (anónimo) NO se limita aquí: ese límite va en el borde (por IP,
  -- Cloudflare/Edge Function; ver README). reportante_id lo manda el cliente: es un freno
  -- suave contra errores y abuso torpe, no una defensa contra un atacante decidido.
  if new.reportante_id is not null then
    select count(*) into v_n
      from public.reportes r
     where r.reportante_id = new.reportante_id
       and r.recibido_en > now() - interval '1 hour';
    if v_n >= 10 then
      -- 'PT429' hace que PostgREST responda HTTP 429.
      raise exception 'limite_de_reportes: máximo 10 por hora' using errcode = 'PT429';
    end if;
  end if;

  v_pto := ST_SetSRID(ST_MakePoint(new.lon, new.lat), 4326)::geography;

  -- Zona más cercana (siempre se asigna la más próxima), si zonas-N.sql ya se cargó.
  select z.id, z.municipio,
         ST_Distance(z.geog, v_pto) as d,
         ST_Covers(z.geog, v_pto)   as dentro
    into v_zona
    from public.zonas z
   order by ST_Distance(z.geog, v_pto)
   limit 1;

  if v_zona.id is not null then
    new.zona            := v_zona.id;
    new.municipio       := v_zona.municipio;
    new.dentro_poligono := v_zona.dentro;
    new.distancia_m     := case when v_zona.dentro then 0 else round(v_zona.d)::int end;
  end if;
  -- (Sin zonas cargadas se respeta lo del cliente para no perder el reporte.)

  -- Prioridad de conservación oficial de la CRA en el punto (misma regla que app/lib/datos/prioridad.dart):
  -- solo cuenta dentro del manglar; si varios polígonos lo cubren vale el de prioridad más alta; si ninguno
  -- lo cubre (fuera de la zonificación) o prioridades_cra está vacía, no suma ni inventa nada.
  if new.dentro_poligono then
    select (c.prioridad = 'alta') into v_alta
      from public.prioridades_cra c
     where ST_Covers(c.geom, v_pto::geometry)
     order by case c.prioridad when 'alta' then 3 when 'media' then 2 else 1 end desc
     limit 1;
    v_alta := coalesce(v_alta, false);
  end if;

  -- Corroboración: mismo tipo, a ≤ 1 km, con ±3 h de diferencia, de OTRO reportante, sin descartados.
  select count(*) into v_corr
    from public.reportes r
   where r.tipo = new.tipo
     and r.estado <> 'descartado'
     and r.capturado_en between new.capturado_en - interval '3 hours' and new.capturado_en + interval '3 hours'
     and ST_DWithin(r.geom, v_pto, 1000)
     and (new.reportante_id is null or r.reportante_id is distinct from new.reportante_id);

  -- Prioridad 1-5 (misma lógica que Prioridad.calcular de la app).
  v_p := case new.tipo
           when 'tala' then 5 when 'quema' then 5
           when 'relleno' then 4 when 'vertimiento' then 4 when 'cano_taponado' then 4 when 'fauna' then 4
           else 2 end;
  if new.dentro_poligono then
    if v_alta then v_p := v_p + 1; end if;           -- prioridad de conservación ALTA de la CRA
  elsif coalesce(new.distancia_m, 1000000) > 500 then
    v_p := v_p - 1;                                  -- fuera del área de influencia (500 m)
  end if;
  if new.momento = 'antes'  then v_p := v_p - 1; end if;
  if new.magnitud = 'grande' then v_p := v_p + 1; end if;
  if v_corr > 0 then v_p := v_p + 1; end if;
  new.prioridad := greatest(1, least(5, v_p));

  -- Confianza: la del teléfono vale como máximo 80; la corroboración suma hasta 10.
  -- Pasar de ahí lo hacen la IA y las personas (ia_* y estado), nunca el cliente.
  new.confianza := least(100, least(coalesce(new.confianza, 0), 80) + least(v_corr * 5, 10));

  -- La foto solo puede ser la de este reporte en el bucket privado: nada de URLs ajenas.
  if new.foto_url is not null and lower(new.foto_url) = 'evidencias/' || new.id::text || '.jpg' then
    new.foto_url := lower(new.foto_url);
  else
    new.foto_url := null;
  end if;
  new.foto_hash := lower(new.foto_hash);
  if new.foto_hash is not null and new.foto_hash !~ '^[0-9a-f]{64}$' then
    new.foto_hash := null;
  end if;

  -- Reloj del teléfono adelantado o desconfigurado (p. ej. en 1970 tras quedarse sin batería): no se
  -- pierde el reporte: se corrige a la hora del servidor.
  -- (Los CHECK reportes_capturado_no_futuro y reportes_capturado_razonable quedan como respaldo.)
  if new.capturado_en > now() + interval '10 minutes'
     or new.capturado_en < timestamptz '2020-01-01 00:00:00+00' then
    new.capturado_en := now();
  end if;

  -- La app cuenta letras visibles y Postgres puntos de código (un emoji de familia son 7): se recorta
  -- aquí en vez de rechazar el reporte por el CHECK de 1000.
  new.descripcion := left(btrim(coalesce(new.descripcion, '')), 1000);

  -- El id público lo elige siempre el servidor.
  new.id_publico := gen_random_uuid();

  -- Lo que solo fija el servidor.
  new.estado             := 'recibido';
  new.recibido_en        := now();
  new.actualizado_en     := now();
  new.sincronizado_tarde := coalesce(new.sincronizado_tarde, false)
                            or (now() - new.capturado_en) > interval '10 minutes';
  new.corroboraciones    := v_corr;
  new.ia_tipo_detectado  := null;
  new.ia_confianza       := null;
  new.ia_motivo          := null;
  new.expediente         := null;
  new.nota_publica       := null;
  return new;
end $$;

drop trigger if exists reportes_antes_insert on public.reportes;
create trigger reportes_antes_insert before insert on public.reportes
  for each row execute function public.reportes_antes_insert();

-- Primera fila del historial: «recibido».
create or replace function public.reportes_despues_insert()
returns trigger language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
begin
  insert into public.historial_estado (reporte_id, estado, usuario_id, rol, nota)
  values (new.id, new.estado, null, 'sistema', 'Reporte recibido');
  return new;
end $$;

drop trigger if exists reportes_despues_insert on public.reportes;
create trigger reportes_despues_insert after insert on public.reportes
  for each row execute function public.reportes_despues_insert();

create or replace function public.reportes_antes_update()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  new.actualizado_en := now();
  return new;
end $$;

drop trigger if exists reportes_antes_update on public.reportes;
create trigger reportes_antes_update before update on public.reportes
  for each row execute function public.reportes_antes_update();

-- -------------------------------------------------------------------------------------
-- 6. VISTA PÚBLICA (sin descripción, sin reportante, sin foto; coordenadas a 3 decimales ≈ 110 m)
-- -------------------------------------------------------------------------------------
-- NUNCA publica r.id: ese UUID es la llave para preguntar el estado (estado_de_reportes) y de él sale el
-- número de caso ZK-XXXX que la persona comparte. Si la vista lo diera, cualquiera listaría todos los ids,
-- leería la nota pública de reportes ajenos y, con un número de caso visto en WhatsApp, hallaría el punto y la
-- hora del denunciante. Sale id_publico (otro UUID al azar) y la hora redondeada a la hora en punto.
drop view if exists public.reportes_publicos;
create view public.reportes_publicos
  with (security_invoker = false)   -- corre con los permisos del dueño: así anon la lee sin ver la tabla
as
select r.id_publico,
       r.tipo,
       round(r.lat::numeric, 3)::double precision as lat,
       round(r.lon::numeric, 3)::double precision as lon,
       r.prioridad,
       r.estado,
       date_trunc('hour', r.capturado_en) as capturado_en,
       r.zona,
       r.municipio,
       r.canal
  from public.reportes r
 where r.estado <> 'descartado';

comment on view public.reportes_publicos is
  'Datos abiertos y mapa público. Sin id interno, descripción, foto ni reportante; lat/lon a 3 decimales y hora en punto. CC BY 4.0.';

-- -------------------------------------------------------------------------------------
-- 7. RPC PÚBLICAS
-- -------------------------------------------------------------------------------------
-- Estado de MIS reportes: solo responde por los ids que se le dan (UUID inadivinables, que ninguna vista
-- publica). Devuelve también id_publico, para que el teléfono reconozca sus propios reportes en el mapa público.
-- (drop antes de create: cambió lo que devuelve, y create or replace no puede cambiarlo.)
drop function if exists public.estado_de_reportes(uuid[]);
create function public.estado_de_reportes(ids uuid[])
returns table (id uuid, estado text, prioridad int, confianza int, nota_publica text, actualizado_en timestamptz,
               id_publico uuid)
language plpgsql stable security definer
set search_path = public, extensions, pg_temp as $$
begin
  if ids is null then return; end if;
  if cardinality(ids) > 100 then
    raise exception 'maximo_100_ids' using errcode = '22023';
  end if;
  return query
    select r.id, r.estado, r.prioridad, r.confianza, r.nota_publica, r.actualizado_en, r.id_publico
      from public.reportes r
     where r.id = any (ids);
end $$;

-- Crear un reporte: la ÚNICA puerta de escritura del público (anon).
--
-- Por qué una función y no POST /rest/v1/reportes: con «Prefer: resolution=ignore-duplicates» PostgREST hace
-- INSERT ... ON CONFLICT (id) DO NOTHING; ese ON CONFLICT lee la columna id, la orden pasa a exigir SELECT y,
-- cuando una orden exige SELECT, Postgres aplica las políticas SELECT de RLS como comprobación sobre la fila nueva.
-- anon no tiene (ni debe tener) política SELECT sobre reportes, así que todo reporte fallaba con 42501.
-- Esta función corre como su dueño, valida el contrato (handoff/05), inserta con ON CONFLICT (id) DO NOTHING y
-- responde {id, nuevo, id_publico}. El trigger reportes_antes_insert sigue recalculando todo lo del servidor.
--
-- Errores (PostgREST los convierte en HTTP):
--   22023 con un mensaje «motivo: explicación» -> 400. El teléfono NO reintenta y le muestra el motivo a la persona.
--   PT429 (límite de 10 por hora, en el trigger)  -> 429. El teléfono reintenta más tarde.
-- Un reintento del mismo id responde {nuevo: false} sin volver a validar ni a contar para el límite.
create or replace function public.crear_reporte(p jsonb)
returns jsonb language plpgsql volatile security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_id    uuid;
  v_pub   uuid;
  v_lat   double precision;
  v_lon   double precision;
  v_cap   timestamptz;
  v_canal text;
  v_tipo  text;
  v_met   text;
  v_mom   text;
  v_mag   text;
  v_rep   text;
begin
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception 'reporte_invalido: se esperaba un objeto JSON' using errcode = '22023';
  end if;
  if octet_length(p::text) > 16384 then
    raise exception 'reporte_demasiado_grande: máximo 16 KB' using errcode = '22023';
  end if;

  if coalesce(jsonb_typeof(p -> 'id'), '') <> 'string'
     or (p ->> 'id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception 'id_invalido: el id debe ser un UUID' using errcode = '22023';
  end if;
  v_id := (p ->> 'id')::uuid;

  -- Reintento de uno que ya llegó (la respuesta anterior se perdió): misma respuesta, nada nuevo.
  select r.id_publico into v_pub from public.reportes r where r.id = v_id;
  if found then
    return jsonb_build_object('id', v_id, 'nuevo', false, 'id_publico', v_pub);
  end if;

  v_tipo := p ->> 'tipo';
  if v_tipo is null or v_tipo not in ('tala','quema','relleno','vertimiento','basuras','cano_taponado','fauna','otro') then
    raise exception 'tipo_invalido: el tipo de amenaza no existe' using errcode = '22023';
  end if;

  if coalesce(jsonb_typeof(p -> 'lat'), '') <> 'number' or coalesce(jsonb_typeof(p -> 'lon'), '') <> 'number' then
    raise exception 'ubicacion_invalida: faltan la latitud o la longitud' using errcode = '22023';
  end if;
  v_lat := (p ->> 'lat')::double precision;
  v_lon := (p ->> 'lon')::double precision;
  -- Los mismos límites que el CHECK de la tabla (y que la app en dentroDelAreaDelServidor).
  if v_lat not between 10.2 and 11.4 or v_lon not between -75.7 and -74.4 then
    raise exception 'punto_fuera_del_atlantico: el punto queda fuera del departamento del Atlántico' using errcode = '22023';
  end if;

  begin
    v_cap := (p ->> 'capturado_en')::timestamptz;
  exception when others then
    v_cap := null;
  end;
  if v_cap is null then
    raise exception 'hora_invalida: falta la hora de captura o no se entiende' using errcode = '22023';
  end if;
  -- (Una hora en el futuro o antes de 2020 no se rechaza: el trigger la corrige a now().)

  v_canal := coalesce(p ->> 'canal', 'app');
  if v_canal not in ('app', 'web', 'whatsapp') then
    raise exception 'canal_invalido: el canal debe ser app, web o whatsapp' using errcode = '22023';
  end if;
  v_met := coalesce(p ->> 'metodo_ubicacion', 'gps');
  if v_met not in ('gps', 'mapa', 'enlace') then
    raise exception 'metodo_invalido: el método de ubicación no existe' using errcode = '22023';
  end if;
  v_mom := coalesce(p ->> 'momento', 'ahora');
  if v_mom not in ('ahora', 'hoy', 'antes') then
    raise exception 'momento_invalido: el momento no existe' using errcode = '22023';
  end if;
  v_mag := coalesce(p ->> 'magnitud', 'pequena');
  if v_mag not in ('pequena', 'mediana', 'grande') then
    raise exception 'magnitud_invalida: la magnitud no existe' using errcode = '22023';
  end if;
  v_rep := nullif(btrim(p ->> 'reportante_id'), '');
  if v_rep is not null and char_length(v_rep) > 64 then
    raise exception 'reportante_invalido: máximo 64 caracteres' using errcode = '22023';
  end if;

  insert into public.reportes (
    id, canal, tipo, descripcion, lat, lon, precision_m, metodo_ubicacion, capturado_en, momento, magnitud,
    zona, municipio, dentro_poligono, distancia_m, prioridad, confianza, foto_hash, foto_de_camara, foto_url,
    anonimo, reportante_id, sincronizado_tarde)
  values (
    v_id, v_canal, v_tipo,
    left(btrim(coalesce(p ->> 'descripcion', '')), 1000),
    v_lat, v_lon,
    case when jsonb_typeof(p -> 'precision_m') = 'number'
         then least(greatest((p ->> 'precision_m')::double precision, 0), 100000) end,
    v_met, v_cap, v_mom, v_mag,
    left(p ->> 'zona', 64), left(p ->> 'municipio', 120),          -- el trigger los recalcula
    case when jsonb_typeof(p -> 'dentro_poligono') = 'boolean' then (p ->> 'dentro_poligono')::boolean else false end,
    case when jsonb_typeof(p -> 'distancia_m') = 'number'
         then least(greatest(round((p ->> 'distancia_m')::numeric), 0), 2000000000)::int end,
    3,                                                               -- el trigger la recalcula
    case when jsonb_typeof(p -> 'confianza') = 'number'
         then least(greatest(round((p ->> 'confianza')::numeric), 0), 100)::int else 0 end,
    p ->> 'foto_hash',                                               -- el trigger la limpia
    case when jsonb_typeof(p -> 'foto_de_camara') = 'boolean' then (p ->> 'foto_de_camara')::boolean else false end,
    p ->> 'foto_url',                                                -- el trigger solo acepta evidencias/<id>.jpg
    case when jsonb_typeof(p -> 'anonimo') = 'boolean' then (p ->> 'anonimo')::boolean else false end,
    v_rep,
    case when jsonb_typeof(p -> 'sincronizado_tarde') = 'boolean' then (p ->> 'sincronizado_tarde')::boolean else false end)
  on conflict (id) do nothing
  returning reportes.id_publico into v_pub;

  if found then
    return jsonb_build_object('id', v_id, 'nuevo', true, 'id_publico', v_pub);
  end if;
  -- Otro envío del mismo id ganó la carrera entre la consulta de arriba y este insert.
  select r.id_publico into v_pub from public.reportes r where r.id = v_id;
  return jsonb_build_object('id', v_id, 'nuevo', false, 'id_publico', v_pub);
end $$;

-- Ayudantes de texto para KML.
create or replace function public._xml(t text)
returns text language sql immutable set search_path = public as $$
  select replace(replace(replace(replace(replace(coalesce(t, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;'), '''', '&apos;')
$$;

create or replace function public._nombre_tipo(t text)
returns text language sql immutable set search_path = public as $$
  select case t
    when 'tala' then 'Tala o corte de mangle'
    when 'quema' then 'Quema o incendio'
    when 'relleno' then 'Relleno o construcción'
    when 'vertimiento' then 'Vertimiento o contaminación'
    when 'cano_taponado' then 'Caño taponado o agua alterada'
    when 'fauna' then 'Fauna afectada'
    when 'basuras' then 'Basuras o residuos'
    else 'Otra situación' end
$$;

-- Datos abiertos (Gobierno Digital) · GeoJSON · licencia CC BY 4.0.
-- Campos públicos (handoff/03): id (el id_publico, no el interno), fecha y hora (en punto), tipo, municipio, zona,
-- prioridad, estado, lat, lon, canal. Nunca: el id interno, nombre, teléfono, foto ni metadatos de foto del reportante.
create or replace function public.datos_abiertos_geojson()
returns jsonb language sql stable security definer
set search_path = public, extensions, pg_temp as $$
  select jsonb_build_object(
    'type', 'FeatureCollection',
    'name', 'zanky_reportes_manglar_atlantico',
    'licencia', 'CC BY 4.0',
    'licencia_url', 'https://creativecommons.org/licenses/by/4.0/deed.es',
    'fuente', 'Zanky, ciencia ciudadana para el manglar del Atlántico',
    'aviso', 'Reportes ciudadanos: los de estado «recibido» aún no están verificados. Coordenadas a 3 decimales (~110 m) y hora redondeada a la hora en punto.',
    'generado_en', now(),
    'features', coalesce(jsonb_agg(
      jsonb_build_object(
        'type', 'Feature',
        'id', p.id_publico,
        'geometry', jsonb_build_object('type', 'Point', 'coordinates', jsonb_build_array(p.lon, p.lat)),
        'properties', jsonb_build_object(
          'id', p.id_publico,
          'capturado_en', p.capturado_en,
          'tipo', p.tipo,
          'municipio', p.municipio,
          'zona', p.zona,
          'prioridad', p.prioridad,
          'estado', p.estado,
          'canal', p.canal,
          'licencia', 'CC BY 4.0')
      ) order by p.capturado_en desc), '[]'::jsonb))
  from (select * from public.reportes_publicos order by capturado_en desc limit 5000) p
$$;

-- Datos abiertos · KML (Google Earth). Devuelve el texto KML (en PostgREST llega como cadena JSON).
create or replace function public.datos_abiertos_kml()
returns text language sql stable security definer
set search_path = public, extensions, pg_temp as $$
  select '<?xml version="1.0" encoding="UTF-8"?>' || E'\n'
      || '<kml xmlns="http://www.opengis.net/kml/2.2"><Document>'
      || '<name>Zanky - reportes del manglar del Atlántico</name>'
      || '<description>Licencia CC BY 4.0. Reportes ciudadanos; los de estado recibido no están verificados. Coordenadas a 3 decimales.</description>'
      || coalesce(string_agg(
           '<Placemark><name>' || public._xml(public._nombre_tipo(p.tipo)) || '</name>'
        || '<TimeStamp><when>' || to_char(p.capturado_en at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || '</when></TimeStamp>'
        || '<ExtendedData>'
        || '<Data name="id"><value>' || p.id_publico || '</value></Data>'
        || '<Data name="tipo"><value>' || public._xml(p.tipo) || '</value></Data>'
        || '<Data name="municipio"><value>' || public._xml(p.municipio) || '</value></Data>'
        || '<Data name="zona"><value>' || public._xml(p.zona) || '</value></Data>'
        || '<Data name="prioridad"><value>' || p.prioridad || '</value></Data>'
        || '<Data name="estado"><value>' || public._xml(p.estado) || '</value></Data>'
        || '<Data name="canal"><value>' || public._xml(p.canal) || '</value></Data>'
        || '<Data name="licencia"><value>CC BY 4.0</value></Data>'
        || '</ExtendedData>'
        || '<Point><coordinates>' || p.lon || ',' || p.lat || ',0</coordinates></Point></Placemark>',
           '' order by p.capturado_en desc), '')
      || '</Document></kml>'
  from (select * from public.reportes_publicos order by capturado_en desc limit 5000) p
$$;

-- -------------------------------------------------------------------------------------
-- 8. RPC DEL PANEL (todas comprueban panel_rol_de(auth.uid()) y escriben auditoría)
-- -------------------------------------------------------------------------------------
create or replace function public.mi_rol()
returns text language sql stable security definer
set search_path = public, extensions, pg_temp as $$
  select public.panel_rol_de(auth.uid())
$$;

-- Cambio de estado con transiciones válidas:
--   recibido -> en_verificacion -> verificado -> alerta_oficial -> en_atencion -> cerrado   (de uno en uno)
--   cualquiera (menos cerrado/descartado) -> descartado   : solo moderador_cra y admin, con nota
--   descartado -> en_verificacion (reabrir)                : solo moderador_cra y admin
--   vigia: solo recibido -> en_verificacion -> verificado ; aliado: ningún cambio
-- Al pasar a alerta_oficial se genera el expediente CRA-MH-AAAA-NNNN.
create or replace function public.cambiar_estado(
  p_id uuid, p_estado text, p_nota text default null, p_nota_publica text default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_uid    uuid := auth.uid();
  v_rol    text := public.panel_rol_de(auth.uid());
  v_actual text;
  v_exp    text;
  v_ok     boolean := false;
  v_o_act  int;
  v_o_new  int;
begin
  if v_rol is null or v_rol = 'aliado' then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if p_estado is null or p_estado not in
     ('recibido','en_verificacion','verificado','alerta_oficial','en_atencion','cerrado','descartado') then
    raise exception 'estado_invalido' using errcode = '22023';
  end if;
  if p_nota is not null and char_length(p_nota) > 1000 then
    raise exception 'nota_demasiado_larga' using errcode = '22023';
  end if;
  if p_nota_publica is not null and char_length(p_nota_publica) > 280 then
    raise exception 'nota_publica_demasiado_larga (max 280)' using errcode = '22023';
  end if;

  select r.estado, r.expediente into v_actual, v_exp
    from public.reportes r where r.id = p_id for update;
  if not found then
    raise exception 'reporte_no_existe' using errcode = 'P0002';
  end if;
  if v_actual = p_estado then
    raise exception 'sin_cambio: ya está en %', p_estado using errcode = 'P0001';
  end if;

  v_o_act := public._orden_estado(v_actual);
  v_o_new := public._orden_estado(p_estado);

  if p_estado = 'descartado' then
    v_ok := v_rol in ('admin', 'moderador_cra') and v_actual not in ('cerrado', 'descartado');
    if v_ok and coalesce(btrim(p_nota), '') = '' then
      raise exception 'descartar_requiere_nota' using errcode = '22023';
    end if;
  elsif v_actual = 'descartado' then
    v_ok := v_rol in ('admin', 'moderador_cra') and p_estado = 'en_verificacion';
  elsif v_o_new = v_o_act + 1 then
    v_ok := (v_rol in ('admin', 'moderador_cra')) or (v_rol = 'vigia' and v_o_new <= 3);
  end if;

  if not v_ok then
    raise exception 'transicion_no_permitida: % -> % (rol %)', v_actual, p_estado, v_rol using errcode = '42501';
  end if;

  if p_estado = 'cerrado' and coalesce(btrim(p_nota), '') = '' then
    raise exception 'cerrar_requiere_nota' using errcode = '22023';
  end if;

  if p_estado = 'alerta_oficial' and v_exp is null then
    v_exp := 'CRA-MH-' || to_char(now() at time zone 'America/Bogota', 'YYYY') || '-'
             || lpad(nextval('public.expediente_seq')::text, 4, '0');
  end if;

  update public.reportes r
     set estado       = p_estado,
         expediente   = v_exp,
         nota_publica = coalesce(nullif(btrim(p_nota_publica), ''), r.nota_publica)
   where r.id = p_id;

  insert into public.historial_estado (reporte_id, estado, usuario_id, rol, nota)
  values (p_id, p_estado, v_uid, v_rol, nullif(btrim(p_nota), ''));

  perform public.auditar('cambio_estado', 'reporte', p_id::text,
    jsonb_build_object('de', v_actual, 'a', p_estado, 'nota', nullif(btrim(p_nota), ''), 'expediente', v_exp));

  return jsonb_build_object('id', p_id, 'estado', p_estado, 'expediente', v_exp, 'actualizado_en', now());
end $$;

-- Ficha completa de un reporte (sin el reportante). Queda auditado como «miro_reporte».
create or replace function public.ver_reporte(p_id uuid)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_rol text := public.panel_rol_de(auth.uid());
  v_r   jsonb;
begin
  if v_rol is null or v_rol = 'aliado' then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  select to_jsonb(r) - 'reportante_id' - 'geom' into v_r from public.reportes r where r.id = p_id;
  if v_r is null then raise exception 'reporte_no_existe' using errcode = 'P0002'; end if;
  perform public.auditar('miro_reporte', 'reporte', p_id::text, '{}'::jsonb);
  return v_r;
end $$;

-- Identificador del reportante (dato sensible): solo moderador y admin; auditado como «miro_reportante».
create or replace function public.ver_reportante(p_id uuid)
returns text language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_rol text := public.panel_rol_de(auth.uid());
  v_rep text;
begin
  if v_rol is null or v_rol not in ('admin', 'moderador_cra') then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  select r.reportante_id into v_rep from public.reportes r where r.id = p_id;
  if not found then raise exception 'reporte_no_existe' using errcode = 'P0002'; end if;
  perform public.auditar('miro_reportante', 'reporte', p_id::text, '{}'::jsonb);
  return v_rep;
end $$;

-- Foto de evidencia. SQL no puede firmar URLs de Storage (la firma la hace la API de Storage), así que
-- el permiso se parte en dos pasos que no se pueden saltar:
--   1) url_foto(id): comprueba el rol, AUDITA «miro_foto» y devuelve la ruta;
--   2) con esa ruta el panel pide la URL firmada a Storage (createSignedUrl, 60 s). La política de
--      storage.objects solo deja leer si hay un «miro_foto» de ese usuario en los últimos 2 minutos.
-- Resultado: no se puede ver una foto sin dejar rastro, ni siquiera llamando a Storage directo.
create or replace function public.url_foto(p_id uuid)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_rol  text := public.panel_rol_de(auth.uid());
  v_ruta text;
begin
  if v_rol is null or v_rol = 'aliado' then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  select r.foto_url into v_ruta from public.reportes r where r.id = p_id;
  if not found then raise exception 'reporte_no_existe' using errcode = 'P0002'; end if;
  if v_ruta is null then raise exception 'sin_foto' using errcode = 'P0002'; end if;
  perform public.auditar('miro_foto', 'reporte', p_id::text, jsonb_build_object('ruta', v_ruta));
  return jsonb_build_object(
    'bucket', 'evidencias',
    'objeto', substring(v_ruta from '^evidencias/(.*)$'),
    'ruta', v_ruta,
    'valida_segundos', 120,
    'siguiente_paso', 'Pedir la URL firmada a Storage con la sesión del panel: createSignedUrl(objeto, 60)');
end $$;

-- Para la política de storage.objects (ver más abajo).
create or replace function public.foto_autorizada(p_nombre text)
returns boolean language sql stable security definer
set search_path = public, extensions, pg_temp as $$
  select public.panel_rol_de(auth.uid()) in ('admin', 'moderador_cra', 'vigia')
     and exists (
       select 1 from public.auditoria a
        where a.accion = 'miro_foto'
          and a.usuario_id = auth.uid()
          and a.objeto_id is not null
          and a.detalle ->> 'ruta' = 'evidencias/' || p_nombre
          and a.creado_en > now() - interval '2 minutes')
$$;

-- Gestión de roles (solo admin). El primer admin se crea por SQL (README).
create or replace function public.asignar_rol(p_user uuid, p_rol text)
returns void language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
begin
  if public.panel_rol_de(auth.uid()) is distinct from 'admin' then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if p_rol not in ('admin', 'moderador_cra', 'vigia', 'aliado') then
    raise exception 'rol_invalido' using errcode = '22023';
  end if;
  insert into public.panel_roles (user_id, rol, activo, revocado_en, creado_por)
  values (p_user, p_rol, true, null, auth.uid())
  on conflict (user_id) do update
    set rol = excluded.rol, activo = true, revocado_en = null, creado_por = auth.uid();
end $$;

create or replace function public.revocar_rol(p_user uuid)
returns void language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
begin
  if public.panel_rol_de(auth.uid()) is distinct from 'admin' then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if p_user = auth.uid() then
    raise exception 'no_puedes_revocarte_a_ti_mismo' using errcode = '22023';
  end if;
  update public.panel_roles set activo = false, revocado_en = now() where user_id = p_user;
end $$;

-- -------------------------------------------------------------------------------------
-- 9. SEGURIDAD: RLS en todo + permisos mínimos
-- -------------------------------------------------------------------------------------
alter table public.zonas            enable row level security;
alter table public.reportes         enable row level security;
alter table public.historial_estado enable row level security;
alter table public.auditoria        enable row level security;
alter table public.panel_roles      enable row level security;

-- Se parte de cero: ni anon ni authenticated tienen nada por defecto (Supabase les da todo).
revoke all on public.zonas, public.reportes, public.historial_estado, public.auditoria, public.panel_roles
  from public, anon, authenticated;
revoke all on public.reportes_publicos from public, anon, authenticated;
revoke all on sequence public.expediente_seq from public, anon, authenticated;

-- zonas y prioridades_cra: capas públicas (CRA), lectura abierta.
grant select on public.zonas to anon, authenticated;
drop policy if exists zonas_lectura_publica on public.zonas;
create policy zonas_lectura_publica on public.zonas for select to anon, authenticated using (true);

alter table public.prioridades_cra enable row level security;
revoke all on public.prioridades_cra from public, anon, authenticated;
grant select on public.prioridades_cra to anon, authenticated;
drop policy if exists prioridades_cra_lectura_publica on public.prioridades_cra;
create policy prioridades_cra_lectura_publica on public.prioridades_cra for select to anon, authenticated using (true);

-- reportes: el público NO toca la tabla. Crea reportes solo con crear_reporte() (más abajo), que valida y
-- corre como el dueño. Por eso ya no hay GRANT INSERT ni la política de INSERT para anon, ni el
-- «grant select (id)» que pedía el ON CONFLICT de ignore-duplicates (el revoke all de arriba también los
-- quita de una base donde ya se habían dado).
drop policy if exists reportes_insertar_publico on public.reportes;

-- Panel: lectura directa permitida solo con rol activo confirmado en panel_roles. El reportante_id NO se
-- concede por columna: se pide con ver_reportante() (auditado). El aliado no lee reportes.
grant select (id, canal, tipo, descripcion, lat, lon, precision_m, metodo_ubicacion, capturado_en, momento,
              magnitud, zona, municipio, dentro_poligono, distancia_m, prioridad, confianza, foto_hash,
              foto_de_camara, foto_url, anonimo, sincronizado_tarde, estado, recibido_en, actualizado_en, geom,
              ia_tipo_detectado, ia_confianza, ia_motivo, corroboraciones, nota_publica, expediente)
  on public.reportes to authenticated;
drop policy if exists reportes_panel_lee on public.reportes;
create policy reportes_panel_lee on public.reportes for select to authenticated
  using ((select public.panel_rol_de((select auth.uid()))) in ('admin', 'moderador_cra', 'vigia'));

-- historial: lo lee el panel; lo escriben solo las funciones del servidor.
grant select on public.historial_estado to authenticated;
drop policy if exists historial_panel_lee on public.historial_estado;
create policy historial_panel_lee on public.historial_estado for select to authenticated
  using ((select public.panel_rol_de((select auth.uid()))) in ('admin', 'moderador_cra', 'vigia'));

-- auditoria: solo la lee el admin. Nadie la escribe por la API (solo auditar(), interna).
grant select on public.auditoria to authenticated;
drop policy if exists auditoria_admin_lee on public.auditoria;
create policy auditoria_admin_lee on public.auditoria for select to authenticated
  using ((select public.panel_rol_de((select auth.uid()))) = 'admin');

-- panel_roles: sin políticas ni permisos. Se consulta con mi_rol()/panel_rol_de() y se gestiona con las RPC.

-- Vista y funciones: Supabase concede EXECUTE a anon por defecto, así que se revoca y se concede una a una.
grant select on public.reportes_publicos to anon, authenticated;

revoke all on function public.panel_rol_de(uuid)                          from public, anon, authenticated;
revoke all on function public.auditar(text, text, text, jsonb)            from public, anon, authenticated;
revoke all on function public.panel_roles_audita()                        from public, anon, authenticated;
revoke all on function public.bloquear_modificacion()                     from public, anon, authenticated;
revoke all on function public.reportes_antes_insert()                     from public, anon, authenticated;
revoke all on function public.reportes_despues_insert()                   from public, anon, authenticated;
revoke all on function public.reportes_antes_update()                     from public, anon, authenticated;
revoke all on function public._orden_estado(text)                         from public, anon, authenticated;
revoke all on function public._xml(text)                                  from public, anon, authenticated;
revoke all on function public._nombre_tipo(text)                          from public, anon, authenticated;
revoke all on function public.estado_de_reportes(uuid[])                  from public, anon, authenticated;
revoke all on function public.crear_reporte(jsonb)                        from public, anon, authenticated;
revoke all on function public.datos_abiertos_geojson()                    from public, anon, authenticated;
revoke all on function public.datos_abiertos_kml()                        from public, anon, authenticated;
revoke all on function public.mi_rol()                                    from public, anon, authenticated;
revoke all on function public.cambiar_estado(uuid, text, text, text)     from public, anon, authenticated;
revoke all on function public.ver_reporte(uuid)                           from public, anon, authenticated;
revoke all on function public.ver_reportante(uuid)                        from public, anon, authenticated;
revoke all on function public.url_foto(uuid)                              from public, anon, authenticated;
revoke all on function public.foto_autorizada(text)                       from public, anon, authenticated;
revoke all on function public.asignar_rol(uuid, text)                     from public, anon, authenticated;
revoke all on function public.revocar_rol(uuid)                           from public, anon, authenticated;

-- Públicas (anon + authenticated)
grant execute on function public.estado_de_reportes(uuid[]) to anon, authenticated;
grant execute on function public.crear_reporte(jsonb)       to anon, authenticated;
grant execute on function public.datos_abiertos_geojson()   to anon, authenticated;
grant execute on function public.datos_abiertos_kml()       to anon, authenticated;
-- Solo con sesión (y cada una comprueba el rol por dentro)
grant execute on function public.panel_rol_de(uuid)                      to authenticated, service_role;
grant execute on function public.mi_rol()                                to authenticated;
grant execute on function public.cambiar_estado(uuid, text, text, text) to authenticated;
grant execute on function public.ver_reporte(uuid)                       to authenticated;
grant execute on function public.ver_reportante(uuid)                    to authenticated;
grant execute on function public.url_foto(uuid)                          to authenticated;
grant execute on function public.foto_autorizada(text)                   to authenticated;
grant execute on function public.asignar_rol(uuid, text)                 to authenticated;
grant execute on function public.revocar_rol(uuid)                       to authenticated;

-- -------------------------------------------------------------------------------------
-- 10. STORAGE: bucket privado «evidencias»
-- -------------------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('evidencias', 'evidencias', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = false, file_size_limit = 5242880,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

-- Subir: cualquiera, pero solo con nombre <uuid>.jpg (el que genera la app: evidencias/<id>.jpg).
drop policy if exists evidencias_subir_anonimo on storage.objects;
create policy evidencias_subir_anonimo on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'evidencias'
              and name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$');

-- Reemplazar (x-upsert de la app, para reintentos): mismo patrón de nombre y solo durante 7 días tras subirla.
drop policy if exists evidencias_reemplazar_anonimo on storage.objects;
create policy evidencias_reemplazar_anonimo on storage.objects
  for update to anon, authenticated
  using (bucket_id = 'evidencias'
         and name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$'
         and created_at > now() - interval '7 days')
  with check (bucket_id = 'evidencias'
              and name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$');

-- Leer: SOLO el panel, y solo si acaba de pasar por url_foto() (queda auditado). anon no tiene SELECT.
drop policy if exists evidencias_leer_panel_auditado on storage.objects;
create policy evidencias_leer_panel_auditado on storage.objects
  for select to authenticated
  using (bucket_id = 'evidencias' and public.foto_autorizada(name));

-- -------------------------------------------------------------------------------------
-- 11. TIEMPO REAL para el panel
-- -------------------------------------------------------------------------------------
-- Realtime respeta RLS: el panel (con rol) recibe los reportes; anon no recibe nada.
-- IMPORTANTE para la web: Realtime no reenvía lo que pasó mientras el canal estaba caído, así que al
-- (re)conectar el canal el panel debe RELEER toda la lista, no solo escuchar lo nuevo.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'reportes') then
    alter publication supabase_realtime add table public.reportes;
  end if;
end $$;

-- Listo. Siguiente: zonas-N.sql, prioridades-N.sql (y, si quieres datos de demostración, seed_demo.sql).
