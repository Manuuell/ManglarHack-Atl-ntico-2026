-- =====================================================================================
-- Zanky · Estadísticas públicas, ranking de colegios y maqueta de sensores
-- =====================================================================================
-- ADITIVO e idempotente: se corre ENCIMA del esquema ya cargado (schema.sql primero), en el SQL Editor
-- de Supabase (rol postgres), las veces que haga falta. No borra ni recrea tablas existentes.
--
-- Qué agrega:
--   1. estadisticas(desde)      -> json con totales agregados (web pública y panel). Sin datos personales.
--   2. reportes.colegio         -> columna opcional; crear_reporte la acepta (mismo parámetro p jsonb, clave
--                                  «colegio»); asignar_colegio(p_id, p_colegio) para ponerla después;
--                                  ranking_colegios(limite) -> json con el puesto de cada colegio.
--   3. sensores / lecturas_sensor / ultimas_lecturas()  -> maqueta de la hoja de ruta (sin lecturas falsas;
--                                  los datos de demostración están aparte en seed_sensores_demo.sql).
--
-- OJO: este archivo reemplaza crear_reporte(jsonb) (misma firma, mismos permisos) para que lea «colegio».
-- Si vuelves a correr schema.sql, esa función vuelve a la versión sin colegio: corre este archivo de nuevo.
-- Este archivo es público: nada de claves aquí.
-- =====================================================================================
set search_path = public, extensions;

-- -------------------------------------------------------------------------------------
-- 1. ESTADÍSTICAS PÚBLICAS
-- -------------------------------------------------------------------------------------
-- Todo se cuenta sobre los reportes RECIBIDOS desde «desde» (por defecto, los últimos 30 días), salvo la
-- serie por día, que siempre son los últimos 30 días (hoy incluido, hora de Bogotá).
-- «Validado» = estado verificado, alerta_oficial, en_atencion o cerrado. «Pendiente» = recibido o
-- en_verificacion. Los descartados no son ni lo uno ni lo otro (van aparte).
-- Solo agregados: ningún id, ninguna coordenada, ninguna descripción, ningún reportante.
-- search_path incluye «extensions» porque en Supabase PostGIS vive ahí (se usa ST_Covers).
create or replace function public.estadisticas(desde timestamptz default now() - interval '30 days')
returns json
language sql stable security definer
set search_path = public, extensions, pg_temp as $$
  with
  p as (select coalesce(desde, now() - interval '30 days') as d),
  b as (
    select r.id, r.tipo, r.estado, r.zona, r.dentro_poligono, r.prioridad, r.recibido_en, r.geom
      from public.reportes r, p
     where r.recibido_en >= p.d
  ),
  -- Primer momento en que cada reporte quedó validado (del historial, que es solo-INSERT).
  v as (
    select h.reporte_id, min(h.creado_en) as en
      from public.historial_estado h
     where h.estado in ('verificado', 'alerta_oficial', 'en_atencion', 'cerrado')
     group by h.reporte_id
  ),
  -- Prioridad de conservación de la CRA en el punto: solo dentro del manglar; si varios polígonos lo
  -- cubren vale el de prioridad más alta (misma regla que el trigger de recepción).
  c as (
    select b.id,
           coalesce((select pc.prioridad
                       from public.prioridades_cra pc
                      where b.dentro_poligono and ST_Covers(pc.geom, b.geom::geometry)
                      order by case pc.prioridad when 'alta' then 3 when 'media' then 2 else 1 end desc
                      limit 1), 'sin_clasificar') as prioridad_cra
      from b
  ),
  estados as (select unnest(array['recibido','en_verificacion','verificado','alerta_oficial','en_atencion','cerrado','descartado']) as k),
  tipos   as (select unnest(array['tala','quema','relleno','vertimiento','basuras','cano_taponado','fauna','otro']) as k),
  dias    as (
    select generate_series((now() at time zone 'America/Bogota')::date - 29,
                           (now() at time zone 'America/Bogota')::date, interval '1 day')::date as dia
  ),
  serie as (
    select (r.recibido_en at time zone 'America/Bogota')::date as dia,
           count(*) as reportes,
           count(*) filter (where r.estado in ('verificado','alerta_oficial','en_atencion','cerrado')) as validados
      from public.reportes r
     where r.recibido_en >= ((now() at time zone 'America/Bogota')::date - 29)::timestamp at time zone 'America/Bogota'
     group by 1
  )
  select jsonb_build_object(
    'generado_en', now(),
    'desde', (select d from p),
    'total', (select count(*) from b),
    'por_estado', (select jsonb_object_agg(e.k, (select count(*) from b where b.estado = e.k)) from estados e),
    'por_tipo',   (select jsonb_object_agg(t.k, (select count(*) from b where b.tipo = t.k)) from tipos t),
    'por_zona', (select coalesce(jsonb_agg(jsonb_build_object(
                    'zona', z.id, 'nombre', z.nombre, 'municipio', z.municipio,
                    'reportes', (select count(*) from b where b.zona = z.id),
                    'validados', (select count(*) from b where b.zona = z.id
                                    and b.estado in ('verificado','alerta_oficial','en_atencion','cerrado'))
                  ) order by z.nombre), '[]'::jsonb)
                  from public.zonas z),
    'por_prioridad', (select jsonb_object_agg(n::text, (select count(*) from b where b.prioridad = n))
                        from generate_series(1, 5) n),
    'por_prioridad_cra', jsonb_build_object(
        'alta',           (select count(*) from c where c.prioridad_cra = 'alta'),
        'media',          (select count(*) from c where c.prioridad_cra = 'media'),
        'baja',           (select count(*) from c where c.prioridad_cra = 'baja'),
        'sin_clasificar', (select count(*) from c where c.prioridad_cra = 'sin_clasificar')),
    'por_dia', (select jsonb_agg(jsonb_build_object(
                    'dia', d.dia, 'reportes', coalesce(s.reportes, 0), 'validados', coalesce(s.validados, 0))
                  order by d.dia)
                  from dias d left join serie s on s.dia = d.dia),
    'validados', (select count(*) from b where b.estado in ('verificado','alerta_oficial','en_atencion','cerrado')),
    'pendientes', (select count(*) from b where b.estado in ('recibido','en_verificacion')),
    'descartados', (select count(*) from b where b.estado = 'descartado'),
    'mediana_validacion_min',
        (select round((percentile_cont(0.5) within group (
                  order by extract(epoch from (v.en - b.recibido_en)) / 60.0))::numeric, 1)
           from b join v on v.reporte_id = b.id
          where v.en >= b.recibido_en),
    'pct_dentro_manglar',
        (select round(100.0 * count(*) filter (where b.dentro_poligono) / nullif(count(*), 0), 1) from b)
  )::json
$$;

comment on function public.estadisticas(timestamptz) is
  'Totales agregados y anónimos para la web pública y el panel. Ver backend/supabase/README.md.';

-- -------------------------------------------------------------------------------------
-- 2. COLEGIOS
-- -------------------------------------------------------------------------------------
alter table public.reportes
  add column if not exists colegio text
  check (colegio is null or char_length(colegio) between 1 and 80);

-- La columna NO se agrega al «grant select (...)» del panel: se ve con ver_reporte() y se publica solo
-- agregada, en ranking_colegios().

-- Misma firma que en schema.sql (crear_reporte(p jsonb)): nadie que la llame hoy se rompe. La única
-- diferencia es que lee la clave opcional «colegio» (texto; se recorta, se junta el espacio repetido y
-- se corta a 80). Sin la clave, queda null, igual que antes.
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
  v_col   text;
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
  -- Colegio (opcional): solo si viene como texto; vacío = sin colegio.
  if jsonb_typeof(p -> 'colegio') = 'string' then
    v_col := left(nullif(btrim(regexp_replace(p ->> 'colegio', '\s+', ' ', 'g')), ''), 80);
  end if;

  insert into public.reportes (
    id, canal, tipo, descripcion, lat, lon, precision_m, metodo_ubicacion, capturado_en, momento, magnitud,
    zona, municipio, dentro_poligono, distancia_m, prioridad, confianza, foto_hash, foto_de_camara, foto_url,
    anonimo, reportante_id, sincronizado_tarde, colegio)
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
    case when jsonb_typeof(p -> 'sincronizado_tarde') = 'boolean' then (p ->> 'sincronizado_tarde')::boolean else false end,
    v_col)
  on conflict (id) do nothing
  returning reportes.id_publico into v_pub;

  if found then
    return jsonb_build_object('id', v_id, 'nuevo', true, 'id_publico', v_pub);
  end if;
  select r.id_publico into v_pub from public.reportes r where r.id = v_id;
  return jsonb_build_object('id', v_id, 'nuevo', false, 'id_publico', v_pub);
end $$;

revoke all on function public.crear_reporte(jsonb) from public, anon, authenticated;
grant execute on function public.crear_reporte(jsonb) to anon, authenticated;

-- Poner (o cambiar) el colegio de un reporte ya enviado.
--   · Quien tiene el id del reporte (el UUID inadivinable que solo conoce su teléfono, igual que en
--     estado_de_reportes) puede ponerlo UNA vez, mientras el reporte no tenga colegio.
--   · Un admin del panel puede ponerlo, cambiarlo o quitarlo (p_colegio vacío o null).
-- Responde {id, colegio}. Errores: 22023 colegio/ id inválido, P0002 no existe, 42501 sin permiso.
create or replace function public.asignar_colegio(p_id uuid, p_colegio text)
returns jsonb language plpgsql volatile security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_col   text;
  v_actual text;
  v_admin boolean := coalesce(public.panel_rol_de(auth.uid()) = 'admin', false);
begin
  if p_id is null then
    raise exception 'id_invalido: falta el id del reporte' using errcode = '22023';
  end if;
  v_col := left(nullif(btrim(regexp_replace(coalesce(p_colegio, ''), '\s+', ' ', 'g')), ''), 80);

  select r.colegio into v_actual from public.reportes r where r.id = p_id for update;
  if not found then
    raise exception 'reporte_no_existe' using errcode = 'P0002';
  end if;

  if not v_admin then
    if v_col is null then
      raise exception 'colegio_invalido: escribe el nombre del colegio' using errcode = '22023';
    end if;
    if v_actual is not null then
      raise exception 'sin_permiso: el colegio de este reporte ya está puesto' using errcode = '42501';
    end if;
  end if;

  update public.reportes set colegio = v_col where id = p_id;
  return jsonb_build_object('id', p_id, 'colegio', v_col);
end $$;

-- Ranking público. Solo cuentan para el puesto los reportes VALIDADOS (verificado, alerta_oficial,
-- en_atencion, cerrado); un colegio sin ninguno sale al final con puesto null. Empates: mismo puesto.
-- Los nombres se agrupan sin distinguir mayúsculas ni espacios repetidos. Los descartados no cuentan.
-- Solo agregados: nada de ids, coordenadas ni personas; «ultimo_reporte» es solo la fecha.
create or replace function public.ranking_colegios(limite int default 20)
returns json
language sql stable security definer
set search_path = public, extensions, pg_temp as $$
  with g as (
    select lower(btrim(regexp_replace(r.colegio, '\s+', ' ', 'g'))) as clave,
           (array_agg(r.colegio order by r.recibido_en desc))[1] as colegio,
           count(*) filter (where r.estado in ('verificado','alerta_oficial','en_atencion','cerrado')) as validados,
           count(*) as totales,
           count(distinct r.zona) as zonas,
           max(r.recibido_en) as ultimo
      from public.reportes r
     where r.colegio is not null and r.estado <> 'descartado'
     group by 1
  ),
  o as (
    select g.*,
           case when g.validados > 0
                then dense_rank() over (order by g.validados desc) end as puesto
      from g
  )
  select coalesce(json_agg(json_build_object(
           'puesto', o.puesto,
           'colegio', o.colegio,
           'validados', o.validados,
           'totales', o.totales,
           'zonas_distintas', o.zonas,
           'ultimo_reporte', (o.ultimo at time zone 'America/Bogota')::date
         ) order by o.validados desc, o.totales desc, o.ultimo desc, o.colegio), '[]'::json)
    from (select * from o
           order by validados desc, totales desc, ultimo desc, colegio
           limit greatest(1, least(coalesce(limite, 20), 100))) o
$$;

-- -------------------------------------------------------------------------------------
-- 3. SENSORES (maqueta de la hoja de ruta: la tabla existe; las lecturas reales las cargará quien instale
--    el sensor. Aquí NO hay lecturas inventadas.)
-- -------------------------------------------------------------------------------------
create table if not exists public.sensores (
  id            uuid primary key default gen_random_uuid(),
  nombre        text not null check (char_length(nombre) between 1 and 80),
  tipo          text not null check (tipo in ('nivel_agua', 'salinidad', 'temperatura', 'turbidez')),
  zona_id       text references public.zonas (id) on delete set null,
  lat           double precision not null check (lat between 10.2 and 11.4),
  lon           double precision not null check (lon between -75.7 and -74.4),
  activo        boolean not null default true,
  -- La lectura que llega a este valor o lo pasa dispara la alerta (en las cuatro medidas, más es peor).
  umbral_alerta double precision,
  creado_en     timestamptz not null default now()
);
create index if not exists sensores_zona_ix on public.sensores (zona_id);

create table if not exists public.lecturas_sensor (
  id        bigint generated always as identity primary key,
  sensor_id uuid not null references public.sensores (id) on delete cascade,
  valor     double precision not null,
  unidad    text not null check (char_length(unidad) between 1 and 16),  -- m, ppt, °C, NTU…
  medido_en timestamptz not null default now()
);
create index if not exists lecturas_sensor_ix on public.lecturas_sensor (sensor_id, medido_en desc);

alter table public.sensores        enable row level security;
alter table public.lecturas_sensor enable row level security;
revoke all on public.sensores, public.lecturas_sensor from public, anon, authenticated;

-- Los sensores activos son públicos (nombre, tipo, zona y lugar). Las lecturas crudas NO: el público las ve
-- por ultimas_lecturas() (solo la última de cada sensor).
grant select on public.sensores to anon, authenticated;
drop policy if exists sensores_lectura_publica on public.sensores;
create policy sensores_lectura_publica on public.sensores for select to anon, authenticated using (activo);

-- Escritura: solo admin (por la sesión del panel). El service role se salta RLS por diseño.
grant insert, update, delete on public.sensores to authenticated;
drop policy if exists sensores_admin_escribe on public.sensores;
create policy sensores_admin_escribe on public.sensores for all to authenticated
  using      ((select public.panel_rol_de((select auth.uid()))) = 'admin')
  with check ((select public.panel_rol_de((select auth.uid()))) = 'admin');

grant select, insert, update, delete on public.lecturas_sensor to authenticated;
drop policy if exists lecturas_panel_lee on public.lecturas_sensor;
create policy lecturas_panel_lee on public.lecturas_sensor for select to authenticated
  using ((select public.panel_rol_de((select auth.uid()))) in ('admin', 'moderador_cra', 'vigia'));
drop policy if exists lecturas_admin_escribe on public.lecturas_sensor;
create policy lecturas_admin_escribe on public.lecturas_sensor for all to authenticated
  using      ((select public.panel_rol_de((select auth.uid()))) = 'admin')
  with check ((select public.panel_rol_de((select auth.uid()))) = 'admin');

-- Última lectura de cada sensor activo (null en valor/unidad/medido_en si aún no tiene ninguna).
-- «en_alerta» = la última lectura llegó al umbral. «vigente» = tiene menos de 6 h.
create or replace function public.ultimas_lecturas()
returns json
language sql stable security definer
set search_path = public, extensions, pg_temp as $$
  select coalesce(json_agg(json_build_object(
           'sensor_id', s.id,
           'nombre', s.nombre,
           'tipo', s.tipo,
           'zona', s.zona_id,
           'zona_nombre', z.nombre,
           'lat', s.lat,
           'lon', s.lon,
           'valor', l.valor,
           'unidad', l.unidad,
           'medido_en', l.medido_en,
           'umbral_alerta', s.umbral_alerta,
           'en_alerta', coalesce(l.valor >= s.umbral_alerta, false),
           'vigente', coalesce(l.medido_en > now() - interval '6 hours', false)
         ) order by s.nombre), '[]'::json)
    from public.sensores s
    left join public.zonas z on z.id = s.zona_id
    left join lateral (
      select ls.valor, ls.unidad, ls.medido_en
        from public.lecturas_sensor ls
       where ls.sensor_id = s.id
       order by ls.medido_en desc
       limit 1) l on true
   where s.activo
$$;

-- -------------------------------------------------------------------------------------
-- 4. PERMISOS DE LAS RPC NUEVAS (Supabase da EXECUTE a anon por defecto: se revoca y se concede una a una)
-- -------------------------------------------------------------------------------------
revoke all on function public.estadisticas(timestamptz)        from public, anon, authenticated;
revoke all on function public.asignar_colegio(uuid, text)      from public, anon, authenticated;
revoke all on function public.ranking_colegios(int)            from public, anon, authenticated;
revoke all on function public.ultimas_lecturas()               from public, anon, authenticated;

grant execute on function public.estadisticas(timestamptz)     to anon, authenticated;
grant execute on function public.asignar_colegio(uuid, text)   to anon, authenticated;
grant execute on function public.ranking_colegios(int)         to anon, authenticated;
grant execute on function public.ultimas_lecturas()            to anon, authenticated;

-- Listo. Opcional, solo para demostración de la maqueta de sensores: seed_sensores_demo.sql.
