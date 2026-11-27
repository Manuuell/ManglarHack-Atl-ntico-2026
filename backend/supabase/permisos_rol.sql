-- =====================================================================================
-- Zanky · Permisos por rol configurables desde el panel
-- Cargar DESPUÉS de schema.sql, admin_app.sql y puntos.sql (necesita panel_roles,
-- panel_rol_de y auditar). Idempotente: se puede correr de nuevo sin romper nada.
--
-- La app funciona SIN este archivo: usa las plantillas por defecto (las mismas de abajo) y
-- lo dice en pantalla. Con el archivo cargado, la matriz vive aquí y solo quien tiene
-- «administrar_roles» la cambia. Si se corre puntos.sql otra vez, hay que volver a correr
-- este archivo (puntos.sql deja el check de roles sin encargado_zona ni voluntario).
-- =====================================================================================
set search_path = public, extensions;

-- 1. Roles nuevos del equipo: encargado de zona y voluntario (se suman a los que ya había).
do $$
declare c record;
begin
  for c in select conname from pg_constraint
    where conrelid = 'public.panel_roles'::regclass and contype = 'c'
      and conname in ('panel_roles_rol_check', 'panel_roles_rol_puntos_check', 'panel_roles_rol_permisos_check')
  loop
    execute format('alter table public.panel_roles drop constraint %I', c.conname);
  end loop;
  alter table public.panel_roles add constraint panel_roles_rol_permisos_check
    check (rol in ('admin','moderador_cra','vigia','aliado','investigador','organizador','encargado_zona','voluntario'));
end $$;

-- 2. La matriz rol × permiso.
create table if not exists public.permisos_rol (
  rol            text not null check (rol in ('admin','moderador_cra','vigia','aliado','investigador',
                                              'organizador','encargado_zona','voluntario')),
  permiso        text not null check (permiso in ('ver_reportes','decidir_reportes','editar_contenido',
                                                  'gestionar_puntos','gestionar_jornadas','avisar_zona',
                                                  'ver_datos_personales','administrar_roles')),
  activo         boolean not null default true,
  actualizado_en timestamptz not null default now(),
  actualizado_por uuid,
  primary key (rol, permiso)
);

-- Plantillas por defecto (las mismas que trae la app). Solo se insertan si faltan: no pisan
-- lo que el equipo ya configuró.
insert into public.permisos_rol (rol, permiso) values
  ('admin','ver_reportes'),('admin','decidir_reportes'),('admin','editar_contenido'),('admin','gestionar_puntos'),
  ('admin','gestionar_jornadas'),('admin','avisar_zona'),('admin','ver_datos_personales'),('admin','administrar_roles'),
  ('moderador_cra','ver_reportes'),('moderador_cra','decidir_reportes'),('moderador_cra','avisar_zona'),
  ('moderador_cra','ver_datos_personales'),
  ('vigia','ver_reportes'),('vigia','decidir_reportes'),
  ('aliado','ver_reportes'),
  ('investigador','ver_reportes'),('investigador','gestionar_puntos'),
  ('organizador','ver_reportes'),('organizador','gestionar_jornadas'),('organizador','gestionar_puntos'),
  ('encargado_zona','ver_reportes'),('encargado_zona','decidir_reportes'),('encargado_zona','avisar_zona'),
  ('voluntario','ver_reportes')
on conflict (rol, permiso) do nothing;

-- 3. ¿Tengo este permiso? Lo pregunta cualquier función del servidor y la app.
--    El administrador conserva siempre «administrar_roles» (nadie se deja fuera por error).
create or replace function public.tengo_permiso(p text)
returns boolean language plpgsql stable security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_rol text := public.panel_rol_de(auth.uid());
begin
  if v_rol is null then return false; end if;
  if v_rol = 'admin' and p = 'administrar_roles' then return true; end if;
  return exists (select 1 from public.permisos_rol pr where pr.rol = v_rol and pr.permiso = p and pr.activo);
end $$;

-- 4. Cambiar un permiso de un rol (solo con «administrar_roles»). Queda en auditoría.
create or replace function public.fijar_permiso(p_rol text, p_permiso text, p_activo boolean)
returns void language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
begin
  if not public.tengo_permiso('administrar_roles') then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if p_rol = 'admin' and p_permiso = 'administrar_roles' and not p_activo then
    raise exception 'admin_conserva_roles' using errcode = '22023';
  end if;
  insert into public.permisos_rol (rol, permiso, activo, actualizado_en, actualizado_por)
  values (p_rol, p_permiso, p_activo, now(), auth.uid())
  on conflict (rol, permiso) do update
    set activo = excluded.activo, actualizado_en = now(), actualizado_por = auth.uid();
  perform public.auditar('asignar_rol', 'permisos_rol', p_rol,
    jsonb_build_object('permiso', p_permiso, 'activo', p_activo));
end $$;

-- 5. Dar un rol a una persona por su correo (la persona ya debe tener cuenta).
create or replace function public.asignar_rol_por_correo(p_correo text, p_rol text)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_user uuid;
begin
  if not public.tengo_permiso('administrar_roles') then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if p_rol not in ('admin','moderador_cra','vigia','aliado','investigador','organizador','encargado_zona','voluntario') then
    raise exception 'rol_invalido' using errcode = '22023';
  end if;
  select u.id into v_user from auth.users u where lower(u.email) = lower(btrim(p_correo)) limit 1;
  if v_user is null then
    raise exception 'persona_no_existe' using errcode = 'P0002';
  end if;
  insert into public.panel_roles (user_id, rol, activo, revocado_en, creado_por)
  values (v_user, p_rol, true, null, auth.uid())
  on conflict (user_id) do update
    set rol = excluded.rol, activo = true, revocado_en = null, creado_por = auth.uid();
  return jsonb_build_object('correo', lower(btrim(p_correo)), 'rol', p_rol);
end $$;

-- 6. Quién está en el equipo (solo con «administrar_roles»): correo y rol, nada más.
create or replace function public.equipo_panel()
returns table (correo text, rol text, activo boolean)
language plpgsql stable security definer
set search_path = public, extensions, pg_temp as $$
begin
  if not public.tengo_permiso('administrar_roles') then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  return query
    select u.email::text, pr.rol, (pr.activo and pr.revocado_en is null)
      from public.panel_roles pr join auth.users u on u.id = pr.user_id
     order by pr.rol, u.email;
end $$;

-- 7. Seguridad: RLS. Leer la matriz, cualquiera del equipo; escribir, solo por fijar_permiso().
alter table public.permisos_rol enable row level security;
drop policy if exists permisos_rol_lee_equipo on public.permisos_rol;
create policy permisos_rol_lee_equipo on public.permisos_rol
  for select to authenticated using (public.panel_rol_de(auth.uid()) is not null);
drop policy if exists permisos_rol_escribe_admin on public.permisos_rol;
create policy permisos_rol_escribe_admin on public.permisos_rol
  for all to authenticated
  using (public.tengo_permiso('administrar_roles'))
  with check (public.tengo_permiso('administrar_roles'));
revoke all on public.permisos_rol from anon;
grant select, insert, update on public.permisos_rol to authenticated;

revoke all on function public.tengo_permiso(text)                  from public, anon, authenticated;
revoke all on function public.fijar_permiso(text, text, boolean)   from public, anon, authenticated;
revoke all on function public.asignar_rol_por_correo(text, text)   from public, anon, authenticated;
revoke all on function public.equipo_panel()                       from public, anon, authenticated;
grant execute on function public.tengo_permiso(text)                to authenticated;
grant execute on function public.fijar_permiso(text, text, boolean) to authenticated;
grant execute on function public.asignar_rol_por_correo(text, text) to authenticated;
grant execute on function public.equipo_panel()                     to authenticated;
