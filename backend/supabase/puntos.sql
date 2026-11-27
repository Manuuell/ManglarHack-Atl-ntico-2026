-- Puntos Zanky. Ejecutar después de schema.sql y estadisticas.sql.
-- Aditivo e idempotente: no cambia ni borra visitas existentes.
set search_path = public, extensions;

do $$
declare c record;
begin
  for c in select conname from pg_constraint
    where conrelid = 'public.panel_roles'::regclass and contype = 'c'
      and conname in ('panel_roles_rol_check', 'panel_roles_rol_puntos_check')
  loop
    execute format('alter table public.panel_roles drop constraint %I', c.conname);
  end loop;
  if not exists (select 1 from pg_constraint where conrelid = 'public.panel_roles'::regclass and conname = 'panel_roles_rol_puntos_check') then
    alter table public.panel_roles add constraint panel_roles_rol_puntos_check
      check (rol in ('admin','moderador_cra','vigia','aliado','investigador','organizador'));
  end if;
end $$;

create table if not exists public.puntos_zanky (
  codigo text primary key check (codigo ~ '^[a-z0-9-]{3,40}$'),
  tipo text not null check (tipo in ('asistencia_evento','estacion_educativa','foto_fija','sensor')),
  titulo text not null check (length(trim(titulo)) between 3 and 120),
  descripcion text not null default '',
  zona text not null default '',
  lat double precision check (lat between -90 and 90),
  lon double precision check (lon between -180 and 180),
  evento_id text,
  sensor_id uuid references public.sensores(id) on delete set null,
  activo boolean not null default true,
  creado_por uuid default auth.uid() references auth.users(id),
  creado_en timestamptz not null default now()
);
alter table public.puntos_zanky alter column creado_por set default auth.uid();
create index if not exists puntos_zanky_zona_idx on public.puntos_zanky (zona, activo);

create table if not exists public.visitas_punto (
  punto text not null references public.puntos_zanky(codigo),
  telefono_id uuid not null,
  cuando timestamptz not null default now(),
  datos jsonb not null default '{}'::jsonb,
  primary key (punto, telefono_id, cuando)
);
create index if not exists visitas_punto_dia_idx on public.visitas_punto (punto, cuando desc);
-- Cada fotografía de seguimiento queda vinculada al reporte real que guarda su evidencia.
create table if not exists public.fotos_punto (
  reporte_id uuid primary key references public.reportes(id) on delete cascade,
  punto text not null references public.puntos_zanky(codigo),
  vinculado_en timestamptz not null default now()
);
create index if not exists fotos_punto_punto_idx on public.fotos_punto(punto, vinculado_en desc);
alter table public.puntos_zanky enable row level security;
alter table public.visitas_punto enable row level security;
alter table public.fotos_punto enable row level security;
revoke all on public.puntos_zanky, public.visitas_punto, public.fotos_punto from public, anon, authenticated;
-- La política permite leer activos, pero las columnas precisas no se conceden a la API.
grant select (codigo, tipo, titulo, descripcion, zona, evento_id, sensor_id, activo, creado_en)
  on public.puntos_zanky to anon, authenticated;
drop policy if exists puntos_lectura_activos on public.puntos_zanky;
create policy puntos_lectura_activos on public.puntos_zanky for select to anon, authenticated using (activo);
grant insert (codigo,tipo,titulo,descripcion,zona,lat,lon,evento_id,sensor_id,activo),
      update (tipo,titulo,descripcion,zona,lat,lon,evento_id,sensor_id,activo)
  on public.puntos_zanky to authenticated;
drop policy if exists puntos_gestor_inserta on public.puntos_zanky;
create policy puntos_gestor_inserta on public.puntos_zanky for insert to authenticated
  with check (public.panel_rol_de(auth.uid()) in ('admin','investigador','organizador'));
drop policy if exists puntos_gestor_actualiza on public.puntos_zanky;
create policy puntos_gestor_actualiza on public.puntos_zanky for update to authenticated
  using (public.panel_rol_de(auth.uid()) in ('admin','investigador','organizador'))
  with check (public.panel_rol_de(auth.uid()) in ('admin','investigador','organizador'));
-- Esta vista es la única salida pública con ubicación. Nunca incluye creador ni coordenadas completas.
create or replace view public.puntos_publicos with (security_barrier = true) as
select codigo, tipo, titulo, descripcion, zona, round(lat::numeric, 3)::double precision as lat,
       round(lon::numeric, 3)::double precision as lon, evento_id, sensor_id, activo, creado_en
from public.puntos_zanky where activo;
revoke all on public.puntos_publicos from public, anon, authenticated;
grant select on public.puntos_publicos to anon, authenticated;

create or replace function public.registrar_visita(codigo text, telefono_id uuid)
returns jsonb language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare p public.puntos_zanky%rowtype; n integer;
begin
  if telefono_id is null then raise exception 'telefono_invalido' using errcode = '22023'; end if;
  select * into p from public.puntos_zanky z where z.codigo = registrar_visita.codigo and z.activo;
  if not found then raise exception 'punto_no_existe' using errcode = 'P0002'; end if;
  -- Una visita diaria por teléfono y punto. El bloqueo serializa intentos simultáneos.
  perform pg_advisory_xact_lock(hashtext(telefono_id::text), 0);
  select count(*) into n from public.visitas_punto v
    where v.punto = p.codigo and v.telefono_id = registrar_visita.telefono_id
      and (v.cuando at time zone 'America/Bogota')::date =
          (now() at time zone 'America/Bogota')::date;
  if n = 0 then
    if (select count(*) from public.visitas_punto v where v.telefono_id = registrar_visita.telefono_id
        and (v.cuando at time zone 'America/Bogota')::date = (now() at time zone 'America/Bogota')::date) >= 20
    then raise exception 'limite_diario' using errcode = '22023'; end if;
    insert into public.visitas_punto(punto, telefono_id) values (p.codigo, telefono_id);
  end if;
  return jsonb_build_object('codigo', p.codigo, 'tipo', p.tipo, 'titulo', p.titulo,
    'descripcion', p.descripcion, 'zona', p.zona,
    'lat', round(p.lat::numeric,3), 'lon', round(p.lon::numeric,3),
    'evento_id', p.evento_id, 'sensor_id', p.sensor_id, 'participacion_sumada', n = 0,
    'puntos_ganados', case when n = 0 then 5 else 0 end,
    'participacion_total', (select count(*) * 5 from public.visitas_punto v
      where v.telefono_id = registrar_visita.telefono_id));
end $$;

create or replace function public.puntos_de(zona text default null)
returns jsonb language plpgsql stable security definer set search_path = public, extensions, pg_temp as $$
begin
  if not coalesce(public.panel_rol_de(auth.uid()) in ('admin','investigador','organizador'), false)
    then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(p) order by p.creado_en desc), '[]'::jsonb)
    from public.puntos_zanky p where puntos_de.zona is null or p.zona = puntos_de.zona);
end $$;

create or replace function public.guardar_punto(p jsonb)
returns jsonb language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare v_codigo text := lower(trim(p->>'codigo')); v public.puntos_zanky%rowtype;
begin
  if not coalesce(public.panel_rol_de(auth.uid()) in ('admin','investigador','organizador'), false)
    then raise exception 'sin_permiso' using errcode = '42501'; end if;
  if v_codigo !~ '^[a-z0-9-]{3,40}$' then raise exception 'codigo_invalido' using errcode = '22023'; end if;
  insert into public.puntos_zanky(codigo,tipo,titulo,descripcion,zona,lat,lon,evento_id,sensor_id,activo,creado_por)
  values (v_codigo,p->>'tipo',trim(p->>'titulo'),coalesce(p->>'descripcion',''),coalesce(p->>'zona',''),
    nullif(p->>'lat','')::double precision,nullif(p->>'lon','')::double precision,
    nullif(p->>'evento_id',''),nullif(p->>'sensor_id','')::uuid,coalesce((p->>'activo')::boolean,true),auth.uid())
  on conflict (codigo) do update set tipo=excluded.tipo,titulo=excluded.titulo,
    descripcion=excluded.descripcion,zona=excluded.zona,lat=excluded.lat,lon=excluded.lon,
    evento_id=excluded.evento_id,sensor_id=excluded.sensor_id,activo=excluded.activo
  returning * into v;
  return to_jsonb(v);
end $$;

create or replace function public.resumen_punto(codigo text)
returns jsonb language plpgsql stable security definer set search_path = public, extensions, pg_temp as $$
begin
  if not coalesce(public.panel_rol_de(auth.uid()) in ('admin','investigador','organizador'), false)
    then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return (select jsonb_build_object('codigo', p.codigo, 'total', count(v.cuando),
    'fotografias', (select count(*) from public.fotos_punto f where f.punto = p.codigo),
    'fotos_por_dia', coalesce((select jsonb_agg(jsonb_build_object('dia', x.dia, 'fotografias', x.n) order by x.dia)
      from (select (r.capturado_en at time zone 'America/Bogota')::date dia, count(*) n
        from public.fotos_punto f join public.reportes r on r.id = f.reporte_id
        where f.punto = p.codigo group by 1) x), '[]'::jsonb),
    'por_dia', coalesce((select jsonb_agg(jsonb_build_object('dia', x.dia, 'visitas', x.n) order by x.dia)
      from (select (v2.cuando at time zone 'America/Bogota')::date dia, count(*) n from public.visitas_punto v2
        where v2.punto = p.codigo group by 1) x), '[]'::jsonb))
    from public.puntos_zanky p left join public.visitas_punto v on v.punto = p.codigo
    where p.codigo = resumen_punto.codigo group by p.codigo);
end $$;

create or replace function public.vincular_foto_punto(codigo text, reporte_id uuid)
returns boolean language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare p public.puntos_zanky%rowtype; r public.reportes%rowtype;
begin
  select * into p from public.puntos_zanky z where z.codigo = vincular_foto_punto.codigo
    and z.tipo = 'foto_fija' and z.activo;
  if not found then raise exception 'punto_no_existe' using errcode = 'P0002'; end if;
  select * into r from public.reportes x where x.id = vincular_foto_punto.reporte_id
    and x.foto_url is not null;
  if not found then raise exception 'reporte_sin_foto' using errcode = 'P0002'; end if;
  if p.lat is null or p.lon is null or not ST_DWithin(
    ST_SetSRID(ST_MakePoint(p.lon, p.lat), 4326)::geography, r.geom, 300) then
    raise exception 'foto_lejos_del_punto' using errcode = '22023'; end if;
  if exists (select 1 from public.fotos_punto f where f.reporte_id = r.id and f.punto <> p.codigo) then
    raise exception 'foto_ya_vinculada' using errcode = '23505'; end if;
  insert into public.fotos_punto(reporte_id,punto) values(r.id,p.codigo)
    on conflict(reporte_id) do nothing;
  return true;
end $$;

-- schema.sql conserva asignar_rol() para los cuatro roles antiguos.
-- Esta RPC añade los dos roles nuevos sin reemplazar la función base.
create or replace function public.asignar_rol_punto(p_user uuid, p_rol text)
returns void language plpgsql security definer set search_path = public, extensions, pg_temp as $$
begin
  if public.panel_rol_de(auth.uid()) is distinct from 'admin' then
    raise exception 'sin_permiso' using errcode = '42501'; end if;
  if p_rol not in ('investigador','organizador') then
    raise exception 'rol_invalido' using errcode = '22023'; end if;
  insert into public.panel_roles(user_id,rol,activo,revocado_en,creado_por)
  values(p_user,p_rol,true,null,auth.uid())
  on conflict(user_id) do update set rol=excluded.rol,activo=true,revocado_en=null,creado_por=auth.uid();
end $$;

revoke all on function public.registrar_visita(text,uuid), public.puntos_de(text),
  public.guardar_punto(jsonb), public.resumen_punto(text), public.asignar_rol_punto(uuid,text),
  public.vincular_foto_punto(text,uuid)
  from public, anon, authenticated;
grant execute on function public.registrar_visita(text,uuid) to anon, authenticated;
grant execute on function public.vincular_foto_punto(text,uuid) to anon, authenticated;
grant execute on function public.puntos_de(text), public.guardar_punto(jsonb),
  public.resumen_punto(text), public.asignar_rol_punto(uuid,text) to authenticated;
