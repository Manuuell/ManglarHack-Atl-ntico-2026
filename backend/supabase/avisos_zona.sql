-- Zanky: avisos por zona. Cargar después de schema.sql, estadisticas.sql y sensores_ingesta.sql.
-- Aditivo e idempotente. Ejecutar como postgres en SQL Editor.
set search_path = public, extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.voluntarios (
  id uuid primary key default gen_random_uuid(),
  nombre text not null check (char_length(nombre) between 1 and 80),
  telefono_e164 text not null check (telefono_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  zona text not null references public.zonas(id),
  lat double precision not null check (lat between 10.2 and 11.4),
  lon double precision not null check (lon between -75.7 and -74.4),
  radio_km double precision not null check (radio_km between 0.2 and 20),
  canales text[] not null check (canales <@ array['whatsapp','app','correo']::text[] and cardinality(canales) between 1 and 3),
  tipos_aviso text[] not null check (tipos_aviso <@ array['tala','quema','relleno','vertimiento','basuras','cano_taponado','fauna','otro','sensor']::text[] and cardinality(tipos_aviso) between 1 and 9),
  silencio_desde time,
  silencio_hasta time,
  consentimiento_ley1581 timestamptz not null,
  activo boolean not null default true,
  token_baja_hash text not null check (token_baja_hash ~ '^[0-9a-f]{64}$'),
  creado_en timestamptz not null default now(),
  constraint silencio_par check ((silencio_desde is null) = (silencio_hasta is null))
);
create unique index if not exists voluntarios_telefono_uq on public.voluntarios(telefono_e164);
create unique index if not exists voluntarios_token_uq on public.voluntarios(token_baja_hash);
create index if not exists voluntarios_zona_ix on public.voluntarios(zona) where activo;

create table if not exists public.encargados_zona (
  id uuid primary key default gen_random_uuid(),
  zona text not null references public.zonas(id),
  user_id uuid references auth.users(id) on delete cascade,
  telefono_e164 text check (telefono_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  rol text not null check (rol in ('admin','moderador_cra','vigia','aliado')),
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  constraint encargado_contacto check (user_id is not null or telefono_e164 is not null)
);
create unique index if not exists encargados_usuario_zona_uq on public.encargados_zona(zona,user_id) where user_id is not null;
create unique index if not exists encargados_telefono_zona_uq on public.encargados_zona(zona,telefono_e164) where telefono_e164 is not null;

create table if not exists public.avisos_salientes (
  id uuid primary key default gen_random_uuid(),
  origen text not null check (origen in ('reporte','sensor','participacion')),
  origen_id text not null,
  destinatario_tipo text not null check (destinatario_tipo in ('voluntario','encargado')),
  destinatario_id uuid not null,
  canal text not null check (canal in ('whatsapp','app','correo')),
  plantilla text not null check (plantilla in ('zanky_alerta_zona','zanky_apoyo_confirmado')),
  datos jsonb not null default '{}'::jsonb,
  estado text not null default 'pendiente' check (estado in ('pendiente','proceso','enviado','fallido')),
  intentos integer not null default 0 check (intentos between 0 and 20),
  disponible_en timestamptz not null default now(),
  tomado_en timestamptz,
  creado_en timestamptz not null default now(),
  enviado_en timestamptz,
  constraint datos_objeto check (jsonb_typeof(datos) = 'object')
);
create unique index if not exists avisos_sin_duplicar_uq on public.avisos_salientes
  (origen, origen_id, destinatario_tipo, destinatario_id, canal, plantilla);
create index if not exists avisos_cola_ix on public.avisos_salientes(canal, disponible_en, creado_en)
  where estado in ('pendiente','fallido','proceso');
create index if not exists avisos_destinatario_ix on public.avisos_salientes(destinatario_tipo,destinatario_id,creado_en desc);

create table if not exists public.apoyos_aviso (
  aviso_id uuid not null references public.avisos_salientes(id),
  voluntario_id uuid not null references public.voluntarios(id),
  creado_en timestamptz not null default now(),
  primary key (aviso_id, voluntario_id)
);

alter table public.voluntarios enable row level security;
alter table public.encargados_zona enable row level security;
alter table public.avisos_salientes enable row level security;
alter table public.apoyos_aviso enable row level security;
revoke all on public.voluntarios, public.encargados_zona, public.avisos_salientes, public.apoyos_aviso from public, anon, authenticated;
-- Ninguna política pública: todas las lecturas y escrituras pasan por RPC limitadas.

-- La espera se calcula en hora de Colombia. Incluye intervalos que cruzan medianoche.
create or replace function public._aviso_disponible(p_desde time, p_hasta time, p_ahora timestamptz)
returns timestamptz language plpgsql stable set search_path = public, pg_temp as $$
declare v_local timestamp := p_ahora at time zone 'America/Bogota';
begin
  if p_desde is null or p_hasta is null or p_desde = p_hasta then return p_ahora; end if;
  if p_desde < p_hasta then
    if v_local::time >= p_desde and v_local::time < p_hasta then
      return (v_local::date + p_hasta) at time zone 'America/Bogota';
    end if;
  else
    if v_local::time >= p_desde then
      return ((v_local::date + 1) + p_hasta) at time zone 'America/Bogota';
    elsif v_local::time < p_hasta then
      return (v_local::date + p_hasta) at time zone 'America/Bogota';
    end if;
  end if;
  return p_ahora;
end $$;

create or replace function public._encolar_avisos_zona(
  p_origen text, p_id text, p_zona text, p_tipo text, p_prioridad text,
  p_lat double precision, p_lon double precision
) returns void language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare v public.voluntarios%rowtype; e public.encargados_zona%rowtype;
        v_datos jsonb; v_distancia double precision;
begin
  if p_zona is null or p_prioridad not in ('alta','media','baja') then return; end if;
  -- Solo datos operativos. No se copia descripción, foto, identidad ni contacto del denunciante.
  v_datos := jsonb_build_object('origen',p_origen,'zona',p_zona,'tipo',p_tipo,'prioridad',p_prioridad);
  for e in select * from public.encargados_zona ez
    where ez.zona = p_zona and ez.activo
      and (ez.user_id is null or exists (
        select 1 from public.panel_roles pr where pr.user_id=ez.user_id
          and pr.rol=ez.rol and pr.activo and pr.revocado_en is null)) loop
    insert into public.avisos_salientes(origen,origen_id,destinatario_tipo,destinatario_id,canal,plantilla,datos)
      values (p_origen,p_id,'encargado',e.id,'app','zanky_alerta_zona',v_datos)
      on conflict do nothing;
    if e.telefono_e164 is not null then
      insert into public.avisos_salientes(origen,origen_id,destinatario_tipo,destinatario_id,canal,plantilla,datos)
        values (p_origen,p_id,'encargado',e.id,'whatsapp','zanky_alerta_zona',v_datos)
        on conflict do nothing;
    end if;
  end loop;
  if p_prioridad = 'baja' then return; end if;
  for v in select * from public.voluntarios
            where zona = p_zona and activo and consentimiento_ley1581 is not null
              and p_tipo = any(tipos_aviso)
            order by id for update loop
    v_distancia := ST_Distance(
      ST_SetSRID(ST_MakePoint(v.lon,v.lat),4326)::geography,
      ST_SetSRID(ST_MakePoint(p_lon,p_lat),4326)::geography) / 1000;
    if v_distancia > v.radio_km or (p_prioridad = 'media' and v_distancia >= 2) then continue; end if;
    -- Tres eventos distintos por hora, aunque cada evento use varios canales. El FOR UPDATE
    -- serializa las decisiones para un mismo voluntario y evita carreras entre reportes.
    if (select count(distinct a.origen || ':' || a.origen_id)
          from public.avisos_salientes a
         where a.destinatario_tipo = 'voluntario' and a.destinatario_id = v.id
           and a.creado_en > now() - interval '1 hour') >= 3 then continue; end if;
    insert into public.avisos_salientes(origen,origen_id,destinatario_tipo,destinatario_id,canal,plantilla,datos,disponible_en)
      select p_origen,p_id,'voluntario',v.id,c,'zanky_alerta_zona',v_datos,
             public._aviso_disponible(v.silencio_desde,v.silencio_hasta,now())
        from unnest(v.canales) c where c in ('app','whatsapp','correo')
      on conflict do nothing;
  end loop;
end $$;

create or replace function public._avisar_reporte_insert() returns trigger language plpgsql
security definer set search_path = public, extensions, pg_temp as $$
begin
  perform public._encolar_avisos_zona('reporte',new.id::text,new.zona,new.tipo,
    case when new.prioridad >= 4 then 'alta' when new.prioridad = 3 then 'media' else 'baja' end,
    new.lat,new.lon);
  return new;
end $$;
drop trigger if exists avisos_reporte_insert on public.reportes;
create trigger avisos_reporte_insert after insert on public.reportes
  for each row execute function public._avisar_reporte_insert();

create or replace function public._avisar_sensor_insert() returns trigger language plpgsql
security definer set search_path = public, extensions, pg_temp as $$
declare s public.sensores%rowtype;
begin
  select * into s from public.sensores where id = new.sensor_id;
  if found then
    perform public._encolar_avisos_zona('sensor',new.id::text,s.zona_id,'sensor','alta',s.lat,s.lon);
  end if;
  return new;
end $$;
drop trigger if exists avisos_sensor_insert on public.alertas_sensor;
create trigger avisos_sensor_insert after insert on public.alertas_sensor
  for each row execute function public._avisar_sensor_insert();

-- El token aleatorio es una capacidad privada; solo se guarda su hash en la base.
-- La fecha de consentimiento la fija el servidor, nunca el cliente.
create or replace function public.hacerme_voluntario(
  p_nombre text, p_telefono_e164 text, p_zona text, p_lat double precision,
  p_lon double precision, p_radio_km double precision, p_canales text[],
  p_tipos_aviso text[], p_silencio_desde time, p_silencio_hasta time,
  p_consentimiento boolean
) returns jsonb language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare v_token text := gen_random_uuid()::text || gen_random_uuid()::text;
        v_id uuid;
begin
  if p_consentimiento is distinct from true then
    raise exception 'consentimiento_obligatorio' using errcode = '22023';
  end if;
  if p_nombre is null or char_length(btrim(p_nombre)) not between 1 and 80
     or p_telefono_e164 is null or p_telefono_e164 !~ '^\+[1-9][0-9]{7,14}$'
     or p_zona is null or not exists (select 1 from public.zonas where id=p_zona)
     or p_lat is null or p_lat not between 10.2 and 11.4
     or p_lon is null or p_lon not between -75.7 and -74.4
     or p_radio_km is null or p_radio_km not between 0.2 and 20
     or p_canales is null or cardinality(p_canales) not between 1 and 3
     or not (p_canales <@ array['whatsapp','app','correo']::text[])
     or p_tipos_aviso is null or cardinality(p_tipos_aviso) not between 1 and 9
     or not (p_tipos_aviso <@ array['tala','quema','relleno','vertimiento','basuras','cano_taponado','fauna','otro','sensor']::text[])
     or (p_silencio_desde is null) <> (p_silencio_hasta is null) then
    raise exception 'datos_voluntario_invalidos' using errcode = '22023';
  end if;
  -- No permitir que un tercero reemplace un registro usando un teléfono conocido.
  insert into public.voluntarios(nombre,telefono_e164,zona,lat,lon,radio_km,canales,tipos_aviso,
    silencio_desde,silencio_hasta,consentimiento_ley1581,token_baja_hash)
  values (btrim(p_nombre),p_telefono_e164,p_zona,p_lat,p_lon,p_radio_km,p_canales,p_tipos_aviso,
    p_silencio_desde,p_silencio_hasta,now(),encode(digest(v_token,'sha256'),'hex'))
  on conflict (telefono_e164) do nothing returning id into v_id;
  if v_id is null then raise exception 'telefono_ya_registrado' using errcode = '23505'; end if;
  return jsonb_build_object('telefono_id',v_token,'voluntario_id',v_id);
end $$;

create or replace function public.darme_de_baja(token text) returns boolean
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare v_id uuid;
begin
  if token is null or token !~ '^[0-9a-f-]{72}$' then return false; end if;
  update public.voluntarios set activo=false
    where token_baja_hash=encode(digest(token,'sha256'),'hex') and activo
    returning id into v_id;
  if v_id is null then return false; end if;
  -- Revocar también lo que aún no salió: la baja tiene efecto inmediato.
  update public.avisos_salientes set estado='fallido', intentos=20
    where destinatario_tipo='voluntario' and destinatario_id=v_id
      and estado in ('pendiente','fallido');
  return true;
end $$;

create or replace function public.mis_avisos(telefono_id text) returns jsonb
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare v_id uuid; v_resultado jsonb;
begin
  if telefono_id is null or telefono_id !~ '^[0-9a-f-]{72}$' then return '[]'::jsonb; end if;
  select id into v_id from public.voluntarios
    where token_baja_hash=encode(digest(telefono_id,'sha256'),'hex') and activo;
  if v_id is null then return '[]'::jsonb; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'datos',a.datos,
      'creado_en',a.creado_en,'apoye',ap.aviso_id is not null) order by a.creado_en desc),'[]'::jsonb)
    into v_resultado
    from (select * from public.avisos_salientes
          where destinatario_tipo='voluntario' and destinatario_id=v_id and canal='app'
            and disponible_en <= now() and estado <> 'fallido'
          order by creado_en desc limit 100) a
    left join public.apoyos_aviso ap on ap.aviso_id=a.id and ap.voluntario_id=v_id;
  return v_resultado;
end $$;

create or replace function public.mis_avisos_encargado() returns jsonb
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare v_resultado jsonb;
begin
  if auth.uid() is null then return '[]'::jsonb; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'plantilla',a.plantilla,
    'datos',a.datos,'creado_en',a.creado_en)
    order by a.creado_en desc),'[]'::jsonb) into v_resultado
    from (select a.* from public.avisos_salientes a
          join public.encargados_zona e on e.id=a.destinatario_id
          where a.destinatario_tipo='encargado' and a.canal='app' and e.activo
            and e.user_id=auth.uid() and e.rol=public.panel_rol_de(auth.uid())
          order by a.creado_en desc limit 100) a;
  return v_resultado;
end $$;

create or replace function public.voy_a_ayudar(telefono_id text, p_aviso_id uuid) returns jsonb
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare v public.voluntarios%rowtype; a public.avisos_salientes%rowtype;
        e public.encargados_zona%rowtype; v_nuevo boolean;
begin
  if telefono_id is null or telefono_id !~ '^[0-9a-f-]{72}$' then
    raise exception 'sin_permiso' using errcode='42501';
  end if;
  select * into v from public.voluntarios
    where token_baja_hash=encode(digest(telefono_id,'sha256'),'hex') and activo;
  select * into a from public.avisos_salientes where id=p_aviso_id and canal='app'
    and destinatario_tipo='voluntario' and destinatario_id=v.id and disponible_en <= now();
  if v.id is null or a.id is null then raise exception 'sin_permiso' using errcode='42501'; end if;
  insert into public.apoyos_aviso(aviso_id,voluntario_id) values(a.id,v.id) on conflict do nothing;
  v_nuevo := found;
  if v_nuevo then
    for e in select * from public.encargados_zona ez where ez.zona=v.zona and ez.activo
      and (ez.user_id is null or exists (
        select 1 from public.panel_roles pr where pr.user_id=ez.user_id
          and pr.rol=ez.rol and pr.activo and pr.revocado_en is null)) loop
      insert into public.avisos_salientes(origen,origen_id,destinatario_tipo,destinatario_id,canal,plantilla,datos)
      values ('participacion',a.id::text,'encargado',e.id,'app','zanky_apoyo_confirmado',
        jsonb_build_object('zona',v.zona,'tipo',a.datos->>'tipo','prioridad',a.datos->>'prioridad'))
      on conflict do nothing;
      if e.telefono_e164 is not null then
        insert into public.avisos_salientes(origen,origen_id,destinatario_tipo,destinatario_id,canal,plantilla,datos)
        values ('participacion',a.id::text,'encargado',e.id,'whatsapp','zanky_apoyo_confirmado',
          jsonb_build_object('zona',v.zona,'tipo',a.datos->>'tipo','prioridad',a.datos->>'prioridad'))
        on conflict do nothing;
      end if;
    end loop;
  end if;
  return jsonb_build_object('nuevo',v_nuevo,'participaciones',
    (select count(*) from public.apoyos_aviso where voluntario_id=v.id));
end $$;

-- Solo service_role puede reclamar la cola. Se devuelve el teléfono exclusivamente a este rol.
create or replace function public.tomar_avisos(canal text, limite integer default 20) returns jsonb
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare v_resultado jsonb;
begin
  if auth.role() <> 'service_role' then raise exception 'sin_permiso' using errcode='42501'; end if;
  if canal not in ('whatsapp','correo','app') or limite is null or limite not between 1 and 100 then
    raise exception 'lote_invalido' using errcode='22023'; end if;
  with elegidos as (
    select a.id from public.avisos_salientes a
    where a.canal=canal and a.intentos < 5 and a.disponible_en <= now()
      and (a.estado in ('pendiente','fallido')
           or (a.estado='proceso' and a.tomado_en < now()-interval '10 minutes'))
      and ((a.destinatario_tipo='encargado' and exists (
        select 1 from public.encargados_zona e where e.id=a.destinatario_id and e.activo
          and (e.user_id is null or exists (
            select 1 from public.panel_roles pr where pr.user_id=e.user_id
              and pr.rol=e.rol and pr.activo and pr.revocado_en is null))))
        or (a.destinatario_tipo='voluntario' and exists
          (select 1 from public.voluntarios v where v.id=a.destinatario_id and v.activo)))
    order by a.creado_en limit limite for update of a skip locked
  ), tomados as (
    update public.avisos_salientes a set estado='proceso', intentos=a.intentos+1,tomado_en=now()
      from elegidos x where a.id=x.id returning a.*
  )
  select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'canal',a.canal,'plantilla',a.plantilla,
    'datos',a.datos,'intentos',a.intentos,'telefono_e164',
    case when a.destinatario_tipo='voluntario' then v.telefono_e164 else e.telefono_e164 end)),'[]'::jsonb)
    into v_resultado from tomados a
    left join public.voluntarios v on a.destinatario_tipo='voluntario' and v.id=a.destinatario_id
    left join public.encargados_zona e on a.destinatario_tipo='encargado' and e.id=a.destinatario_id;
  return v_resultado;
end $$;

create or replace function public.marcar_aviso(id uuid, estado text) returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_id uuid;
begin
  if auth.role() <> 'service_role' then raise exception 'sin_permiso' using errcode='42501'; end if;
  if estado not in ('enviado','fallido') then raise exception 'estado_invalido' using errcode='22023'; end if;
  update public.avisos_salientes a set estado=marcar_aviso.estado,
    enviado_en=case when marcar_aviso.estado='enviado' then now() else null end,
    disponible_en=case when marcar_aviso.estado='fallido'
      then now() + make_interval(secs => least(3600,30 * power(2,greatest(0,a.intentos-1)))::int)
      else a.disponible_en end,
    tomado_en=null
    where a.id=marcar_aviso.id and a.estado='proceso' returning a.id into v_id;
  return v_id is not null;
end $$;

create or replace function public.contar_avisos_pendientes(canal text) returns integer
language plpgsql security definer set search_path = public, pg_temp as $$
declare n integer;
begin
  if auth.role() <> 'service_role' then raise exception 'sin_permiso' using errcode='42501'; end if;
  select count(*) into n from public.avisos_salientes a where a.canal=contar_avisos_pendientes.canal
    and a.estado in ('pendiente','fallido') and a.intentos<5 and a.disponible_en<=now();
  return n;
end $$;

revoke all on function public._aviso_disponible(time,time,timestamptz) from public,anon,authenticated;
revoke all on function public._encolar_avisos_zona(text,text,text,text,text,double precision,double precision) from public,anon,authenticated;
revoke all on function public._avisar_reporte_insert() from public,anon,authenticated;
revoke all on function public._avisar_sensor_insert() from public,anon,authenticated;
revoke all on function public.hacerme_voluntario(text,text,text,double precision,double precision,double precision,text[],text[],time,time,boolean) from public,anon,authenticated;
revoke all on function public.darme_de_baja(text) from public,anon,authenticated;
revoke all on function public.mis_avisos(text) from public,anon,authenticated;
revoke all on function public.mis_avisos_encargado() from public,anon,authenticated;
revoke all on function public.voy_a_ayudar(text,uuid) from public,anon,authenticated;
revoke all on function public.tomar_avisos(text,integer) from public,anon,authenticated;
revoke all on function public.marcar_aviso(uuid,text) from public,anon,authenticated;
revoke all on function public.contar_avisos_pendientes(text) from public,anon,authenticated;
grant execute on function public.hacerme_voluntario(text,text,text,double precision,double precision,double precision,text[],text[],time,time,boolean) to anon,authenticated;
grant execute on function public.darme_de_baja(text),public.mis_avisos(text),public.voy_a_ayudar(text,uuid) to anon,authenticated;
grant execute on function public.mis_avisos_encargado() to authenticated;
grant execute on function public.tomar_avisos(text,integer),public.marcar_aviso(uuid,text),public.contar_avisos_pendientes(text) to service_role;

-- La cola es legible por el rol de servicio (también directo, además de por RPC); nadie más.
grant select, update on public.avisos_salientes to service_role;
grant select on public.voluntarios, public.encargados_zona, public.apoyos_aviso to service_role;
