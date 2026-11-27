-- Aplicar después de schema.sql. Repetible; no cambia tablas existentes.
-- No existe una identidad de creador para jornadas ni puntos en el esquema actual.
-- La asignación explícita del rol organizador por ámbito sustituye esa relación.
create table if not exists public.contenido_app (
  clave text not null,
  ambito text not null,
  bloques jsonb not null default '[]'::jsonb,
  publicado boolean not null default false,
  version integer not null default 1,
  editado_por uuid references auth.users(id),
  editado_en timestamptz not null default now(),
  primary key (clave, ambito),
  constraint contenido_clave_valida check (clave ~ '^[a-z0-9_]{1,80}$'),
  constraint contenido_ambito_valido check (ambito = 'global' or ambito ~ '^(evento|punto):[a-zA-Z0-9_-]{1,100}$'),
  constraint contenido_bloques_lista check (jsonb_typeof(bloques) = 'array' and jsonb_array_length(bloques) <= 80),
  constraint contenido_version_positiva check (version > 0)
);

create table if not exists public.contenido_versiones (
  clave text not null,
  ambito text not null,
  version integer not null,
  bloques jsonb not null,
  publicado boolean not null,
  editado_por uuid references auth.users(id),
  editado_en timestamptz not null,
  primary key (clave, ambito, version)
);
create index if not exists contenido_versiones_ambito_ix on public.contenido_versiones (ambito, clave, version desc);

-- Copia pública independiente: guardar un borrador no retira la publicación anterior.
create table if not exists public.contenido_publicado (
  clave text not null,
  ambito text not null,
  bloques jsonb not null,
  publicado boolean not null default true check (publicado),
  version integer not null,
  editado_por uuid references auth.users(id),
  editado_en timestamptz not null,
  primary key (clave, ambito)
);
create table if not exists public.contenido_organizadores (
  ambito text not null check (ambito ~ '^(evento|punto):[a-zA-Z0-9_-]{1,100}$'),
  user_id uuid not null references auth.users(id) on delete cascade,
  rol text not null default 'organizador' check (rol = 'organizador'),
  primary key (ambito, user_id)
);
create index if not exists contenido_organizadores_usuario_ix
  on public.contenido_organizadores (user_id, ambito);
insert into public.contenido_publicado (clave, ambito, bloques, publicado, version, editado_por, editado_en)
  select clave, ambito, bloques, true, version, editado_por, editado_en
    from public.contenido_app where publicado
  on conflict (clave, ambito) do update set bloques = excluded.bloques,
    version = excluded.version, editado_por = excluded.editado_por, editado_en = excluded.editado_en
  where public.contenido_publicado.version < excluded.version;

create or replace function public.contenido_validar_bloques(p_bloques jsonb)
returns boolean language sql immutable set search_path = public, pg_temp as $$
  select jsonb_typeof(p_bloques) = 'array'
    and jsonb_array_length(p_bloques) <= 80
    and not exists (
      select 1 from jsonb_array_elements(p_bloques) b
      where jsonb_typeof(b) <> 'object'
         or coalesce(b->>'tipo', '') not in ('titulo','texto','imagen_url','boton','aviso','lista')
         or coalesce(length(b->>'id'), 0) not between 1 and 100
         or coalesce(length(b->>'texto'), 0) > 4000
         or coalesce(length(b->>'url'), 0) > 2048
         or (b ? 'url' and b->>'url' !~ '^https://')
    );
$$;

create or replace function public.contenido_puede_editar(p_ambito text)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select (select public.panel_rol_de((select auth.uid()))) = 'admin'
    or exists (select 1 from public.contenido_organizadores o
      where o.ambito = p_ambito and o.user_id = (select auth.uid())
        and o.rol = 'organizador');
$$;

create or replace function public.contenido_versionar()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.contenido_validar_bloques(new.bloques) then
    raise exception 'bloques_invalidos' using errcode = '22023';
  end if;
  if tg_op = 'UPDATE' then
    if new.version <> old.version + 1 then
      raise exception 'version_obsoleta' using errcode = '40001';
    end if;
    if (new.clave, new.ambito) is distinct from (old.clave, old.ambito) then
      raise exception 'identidad_inmutable' using errcode = '22023';
    end if;
  elsif new.version <> 1 then
    raise exception 'version_inicial_invalida' using errcode = '22023';
  end if;
  new.editado_por := auth.uid();
  new.editado_en := now();
  insert into public.contenido_versiones(clave, ambito, version, bloques, publicado, editado_por, editado_en)
    values (new.clave, new.ambito, new.version, new.bloques, new.publicado, new.editado_por, new.editado_en);
  if new.publicado then
    insert into public.contenido_publicado(clave, ambito, bloques, publicado, version, editado_por, editado_en)
      values (new.clave, new.ambito, new.bloques, true, new.version, new.editado_por, new.editado_en)
      on conflict (clave, ambito) do update set bloques = excluded.bloques,
        version = excluded.version, editado_por = excluded.editado_por, editado_en = excluded.editado_en;
  end if;
  return new;
end $$;

drop trigger if exists contenido_versionar_tr on public.contenido_app;
create trigger contenido_versionar_tr before insert or update on public.contenido_app
  for each row execute function public.contenido_versionar();

alter table public.contenido_app enable row level security;
alter table public.contenido_versiones enable row level security;
alter table public.contenido_publicado enable row level security;
alter table public.contenido_organizadores enable row level security;
drop policy if exists contenido_publicado_lee_todos on public.contenido_publicado;
create policy contenido_publicado_lee_todos on public.contenido_publicado for select to anon, authenticated
  using (publicado);
drop policy if exists contenido_publicado_lee on public.contenido_app;
create policy contenido_publicado_lee on public.contenido_app for select to anon, authenticated
  using (publicado or public.contenido_puede_editar(ambito));
drop policy if exists contenido_equipo_inserta on public.contenido_app;
create policy contenido_equipo_inserta on public.contenido_app for insert to authenticated
  with check (public.contenido_puede_editar(ambito));
drop policy if exists contenido_equipo_actualiza on public.contenido_app;
create policy contenido_equipo_actualiza on public.contenido_app for update to authenticated
  using (public.contenido_puede_editar(ambito))
  with check (public.contenido_puede_editar(ambito));
drop policy if exists contenido_versiones_equipo_lee on public.contenido_versiones;
create policy contenido_versiones_equipo_lee on public.contenido_versiones for select to authenticated
  using (public.contenido_puede_editar(ambito));
-- Historial solo por disparador. Nadie puede editar, borrar ni insertar versiones por API.
revoke all on public.contenido_versiones from public, anon, authenticated;
grant select on public.contenido_versiones to authenticated;
revoke all on public.contenido_publicado from public, anon, authenticated;
grant select on public.contenido_publicado to anon, authenticated;
revoke all on public.contenido_organizadores from public, anon, authenticated;
revoke all on public.contenido_app from public, anon, authenticated;
grant select on public.contenido_app to anon, authenticated;
grant insert, update on public.contenido_app to authenticated;

-- RPC con comprobación atómica de versión. Para crear, p_version_esperada=0.
create or replace function public.guardar_contenido(
  p_clave text, p_ambito text, p_bloques jsonb, p_publicado boolean, p_version_esperada integer
) returns public.contenido_app language plpgsql security invoker
set search_path = public, pg_temp as $$
declare v_fila public.contenido_app;
begin
  if p_version_esperada = 0 then
    insert into public.contenido_app(clave, ambito, bloques, publicado)
      values (p_clave, p_ambito, p_bloques, p_publicado)
      returning * into v_fila;
  else
    update public.contenido_app set bloques = p_bloques, publicado = p_publicado,
      version = p_version_esperada + 1
      where clave = p_clave and ambito = p_ambito and version = p_version_esperada
      returning * into v_fila;
    if not found then raise exception 'version_obsoleta' using errcode = '40001'; end if;
  end if;
  return v_fila;
end $$;
revoke all on function public.guardar_contenido(text,text,jsonb,boolean,integer) from public, anon;
grant execute on function public.guardar_contenido(text,text,jsonb,boolean,integer) to authenticated;
