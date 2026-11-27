-- Parche aditivo para schema.sql + estadisticas.sql ya cargados.
-- Ejecutar como postgres en el SQL Editor. Se puede repetir.
set search_path = public, extensions;

-- Los roles ajenos a admin/moderador reciben el inicio del día en Bogotá,
-- una ventana de al menos siete días y celdas pequeñas ocultas.
create or replace function public.estadisticas(desde timestamptz default now() - interval '30 days')
returns json
language sql stable security definer
set search_path = public, extensions, pg_temp as $$
  with
  acceso as (
    select coalesce(public.panel_rol_de(auth.uid()) in ('admin', 'moderador_cra'), false) as exacto
  ),
  p as (
    select case when a.exacto then coalesce(desde, now() - interval '30 days')
                else least(
                  (coalesce(desde, now() - interval '30 days') at time zone 'America/Bogota')::date::timestamp
                    at time zone 'America/Bogota',
                  ((now() at time zone 'America/Bogota')::date - 7)::timestamp
                    at time zone 'America/Bogota')
           end as d
      from acceso a
  ),
  b as (
    select r.id, r.tipo, r.estado, r.zona, r.dentro_poligono, r.prioridad, r.recibido_en, r.geom
      from public.reportes r, p
     where r.recibido_en >= p.d
  ),
  v as (
    select h.reporte_id, min(h.creado_en) as en
      from public.historial_estado h
     where h.estado in ('verificado', 'alerta_oficial', 'en_atencion', 'cerrado')
     group by h.reporte_id
  ),
  mediana as (
    select count(*) as base,
           round((percentile_cont(0.5) within group (
             order by extract(epoch from (v.en - b.recibido_en)) / 60.0))::numeric, 1) as minutos
      from b join v on v.reporte_id = b.id
     where v.en >= b.recibido_en
  ),
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
  tipos as (select unnest(array['tala','quema','relleno','vertimiento','basuras','cano_taponado','fauna','otro']) as k),
  dias as (
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
    'por_tipo', (select jsonb_object_agg(t.k,
                    case when not a.exacto and n.conteo between 1 and 2
                         then to_jsonb('<3'::text) else to_jsonb(n.conteo) end)
                   from tipos t cross join acceso a
                   cross join lateral (select count(*) as conteo from b where b.tipo = t.k) n),
    'por_zona', (select coalesce(jsonb_agg(jsonb_build_object(
                    'zona', z.id, 'nombre', z.nombre, 'municipio', z.municipio,
                    'reportes', case when not a.exacto and n.reportes between 1 and 2
                                     then to_jsonb('<3'::text) else to_jsonb(n.reportes) end,
                    'validados', case when not a.exacto and n.validados between 1 and 2
                                      then to_jsonb('<3'::text) else to_jsonb(n.validados) end
                  ) order by z.nombre), '[]'::jsonb)
                  from public.zonas z cross join acceso a
                  cross join lateral (
                    select count(*) as reportes,
                           count(*) filter (where b.estado in ('verificado','alerta_oficial','en_atencion','cerrado')) as validados
                      from b where b.zona = z.id) n),
    'por_prioridad', (select jsonb_object_agg(n::text, (select count(*) from b where b.prioridad = n))
                        from generate_series(1, 5) n),
    'por_prioridad_cra', (select jsonb_object_agg(k.prioridad,
                           case when not a.exacto and n.conteo between 1 and 2
                                then to_jsonb('<3'::text) else to_jsonb(n.conteo) end)
                           from unnest(array['alta','media','baja','sin_clasificar']) as k(prioridad)
                           cross join acceso a
                           cross join lateral (select count(*) as conteo from c where c.prioridad_cra = k.prioridad) n),
    'por_dia', (select jsonb_agg(jsonb_build_object(
                    'dia', d.dia, 'reportes', coalesce(s.reportes, 0), 'validados', coalesce(s.validados, 0))
                  order by d.dia)
                  from dias d left join serie s on s.dia = d.dia),
    'validados', (select count(*) from b where b.estado in ('verificado','alerta_oficial','en_atencion','cerrado')),
    'pendientes', (select count(*) from b where b.estado in ('recibido','en_verificacion')),
    'descartados', (select count(*) from b where b.estado = 'descartado'),
    'mediana_validacion_min', (select case when a.exacto or m.base >= 3 then m.minutos end
                                from mediana m cross join acceso a),
    'pct_dentro_manglar',
        (select round(100.0 * count(*) filter (where b.dentro_poligono) / nullif(count(*), 0), 1) from b)
  )::json
$$;

-- El texto publicado siempre proviene de la clave normalizada de un colegio
-- con al menos un reporte validado. Los demás reportes solo aportan conteos.
create or replace function public.ranking_colegios(limite int default 20)
returns json
language sql stable security definer
set search_path = public, extensions, pg_temp as $$
  with g as (
    select lower(btrim(regexp_replace(r.colegio, '\s+', ' ', 'g'))) as colegio,
           count(*) filter (where r.estado in ('verificado','alerta_oficial','en_atencion','cerrado')) as validados,
           count(*) as totales,
           count(distinct r.zona) as zonas,
           max(r.recibido_en) as ultimo
      from public.reportes r
     where r.colegio is not null and btrim(r.colegio) <> '' and r.estado <> 'descartado'
     group by 1
    having count(*) filter (where r.estado in ('verificado','alerta_oficial','en_atencion','cerrado')) > 0
  ),
  o as (
    select g.*, dense_rank() over (order by g.validados desc) as puesto from g
  )
  select coalesce(json_agg(json_build_object(
           'puesto', o.puesto,
           'colegio', initcap(o.colegio),   -- clave normalizada, con mayúscula inicial para mostrar
           'validados', o.validados,
           'totales', o.totales,
           'zonas_distintas', o.zonas,
           'ultimo_reporte', (o.ultimo at time zone 'America/Bogota')::date
         ) order by o.validados desc, o.totales desc, o.ultimo desc, o.colegio), '[]'::json)
    from (select * from o
           order by validados desc, totales desc, ultimo desc, colegio
           limit greatest(1, least(coalesce(limite, 20), 100))) o
$$;

-- Una respuesta genérica evita usar esta RPC para distinguir ids desconocidos
-- de reportes ya asignados, cerrados o antiguos. El admin conserva la edición.
create or replace function public.asignar_colegio(p_id uuid, p_colegio text)
returns jsonb language plpgsql volatile security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_col text := left(nullif(btrim(regexp_replace(coalesce(p_colegio, ''), '\s+', ' ', 'g')), ''), 80);
  v_admin boolean := coalesce(public.panel_rol_de(auth.uid()) = 'admin', false);
begin
  if v_admin then
    if p_id is null then
      raise exception 'id_invalido: falta el id del reporte' using errcode = '22023';
    end if;
    update public.reportes set colegio = v_col where id = p_id;
    if not found then
      raise exception 'reporte_no_existe' using errcode = 'P0002';
    end if;
  else
    if v_col is null then
      raise exception 'colegio_invalido: escribe el nombre del colegio' using errcode = '22023';
    end if;
    update public.reportes set colegio = v_col
     where id = p_id and colegio is null and estado = 'recibido'
       and recibido_en > now() - interval '24 hours' and recibido_en <= now();
    if not found then
      raise exception 'sin_permiso: no se puede asignar el colegio' using errcode = '42501';
    end if;
  end if;
  return jsonb_build_object('id', p_id, 'colegio', v_col);
end $$;

-- RLS no sustituye los privilegios de tabla: se quita la lectura directa.
revoke select on public.sensores, public.lecturas_sensor from anon;

create or replace function public.ultimas_lecturas()
returns json
language sql stable security definer
set search_path = public, extensions, pg_temp as $$
  with acceso as (
    select coalesce(public.panel_rol_de(auth.uid()) = 'admin', false) as exacto
  )
  select coalesce(jsonb_agg((jsonb_build_object(
           'sensor_id', s.id,
           'nombre', s.nombre,
           'tipo', s.tipo,
           'zona', s.zona_id,
           'zona_nombre', z.nombre,
           'lat', case when a.exacto then s.lat else round(s.lat::numeric, 2) end,
           'lon', case when a.exacto then s.lon else round(s.lon::numeric, 2) end,
           'valor', l.valor,
           'unidad', l.unidad,
           'medido_en', l.medido_en,
           'en_alerta', coalesce(l.valor >= s.umbral_alerta, false),
           'vigente', coalesce(l.medido_en > now() - interval '6 hours', false)
         ) || case when a.exacto then jsonb_build_object('umbral_alerta', s.umbral_alerta)
                 else '{}'::jsonb end) order by s.nombre), '[]'::jsonb)::json
    from public.sensores s
    cross join acceso a
    left join public.zonas z on z.id = s.zona_id
    left join lateral (
      select ls.valor, ls.unidad, ls.medido_en
        from public.lecturas_sensor ls
       where ls.sensor_id = s.id
       order by ls.medido_en desc
       limit 1) l on true
   where s.activo
$$;

revoke all on function public.estadisticas(timestamptz), public.ranking_colegios(int),
  public.asignar_colegio(uuid, text), public.ultimas_lecturas() from public, anon, authenticated;
grant execute on function public.estadisticas(timestamptz), public.ranking_colegios(int),
  public.asignar_colegio(uuid, text), public.ultimas_lecturas() to anon, authenticated;
