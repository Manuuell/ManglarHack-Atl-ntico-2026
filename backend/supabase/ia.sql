-- =====================================================================================
-- Zanky · IA en la validación (clasificar-reporte)             Ejecutar DESPUÉS de schema.sql
-- Idempotente. Pegar entero en SQL Editor.
--
-- Qué agrega:
--   1. registrar_clasificacion_ia(): la ÚNICA puerta por la que la IA escribe ia_* (solo service_role).
--      Escribe las 3 columnas ia_* y una línea en auditoría con actor «ia». No toca estado ni prioridad.
--   2. Disparadores (pg_net): al crear un reporte con foto, y al subirse la foto al bucket, avisan a la
--      Edge Function. Si la IA falla o no está configurada, el reporte se guarda igual (nunca bloquea).
--   3. solicitar_revision_ia(): RPC para que el panel pida «revisar con IA» a mano.
--
-- ANTES de correr esto (una sola vez, con valores propios; NO los pegues en el repo):
--   * Habilita en Dashboard > Database > Extensions: pg_net y supabase_vault.
--   * Guarda los dos valores en el Vault (SQL Editor):
--       select vault.create_secret('https://<REF>.supabase.co/functions/v1/clasificar-reporte', 'ia_function_url');
--       select vault.create_secret('<el mismo valor de IA_WEBHOOK_SECRET>',                     'ia_webhook_secret');
--   * Despliega la función y fija sus secretos (ver README, sección «IA en la validación»).
-- =====================================================================================

create extension if not exists pg_net with schema extensions;

-- -------------------------------------------------------------------------------------
-- 0. La auditoría admite las acciones de la IA (hay que ampliar el CHECK de schema.sql)
-- -------------------------------------------------------------------------------------
do $$
declare c record;
begin
  for c in
    select conname from pg_constraint
     where conrelid = 'public.auditoria'::regclass and contype = 'c'
       and pg_get_constraintdef(oid) ilike '%accion%'
  loop
    execute format('alter table public.auditoria drop constraint %I', c.conname);
  end loop;
  alter table public.auditoria add constraint auditoria_accion_check check (accion in
    ('cambio_estado','miro_foto','miro_reporte','miro_reportante','asignar_rol','revocar_rol','exportar',
     'clasificacion_ia','solicitar_revision_ia'));
end $$;

-- -------------------------------------------------------------------------------------
-- 1. La puerta de escritura de la IA. SOLO service_role. Solo ia_tipo_detectado, ia_confianza, ia_motivo.
-- -------------------------------------------------------------------------------------
create or replace function public.registrar_clasificacion_ia(
  p_id uuid, p_tipo text, p_confianza int, p_motivo text,
  p_detalle jsonb default '{}'::jsonb, p_forzar boolean default false)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_ya boolean;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;

  -- Bloquea la fila: dos disparadores a la vez no escriben dos veces.
  select (r.ia_confianza is not null or r.ia_tipo_detectado is not null) into v_ya
    from public.reportes r where r.id = p_id for update;
  if not found then
    raise exception 'reporte_no_existe' using errcode = 'P0002';
  end if;

  -- Idempotente: si ya tiene resultado y no se pide forzar, no se repite.
  if v_ya and not coalesce(p_forzar, false) then
    return jsonb_build_object('id', p_id, 'escrito', false, 'motivo', 'ya_tenia');
  end if;

  -- SOLO las tres columnas ia_*. (No hay estado, prioridad, confianza ni expediente aquí: es a propósito.)
  update public.reportes
     set ia_tipo_detectado = p_tipo,
         ia_confianza      = p_confianza,
         ia_motivo         = left(p_motivo, 1000)
   where id = p_id;

  -- Línea de auditoría con actor «ia» (la tabla es solo-INSERT).
  insert into public.auditoria (usuario_id, rol, accion, objeto_tipo, objeto_id, detalle)
  values (null, 'ia', 'clasificacion_ia', 'reporte', p_id::text,
          coalesce(p_detalle, '{}'::jsonb)
          || jsonb_build_object('ia_tipo_detectado', p_tipo, 'ia_confianza', p_confianza, 'forzado', coalesce(p_forzar, false)));

  return jsonb_build_object('id', p_id, 'escrito', true);
end $$;

-- -------------------------------------------------------------------------------------
-- 2. Avisar a la Edge Function (pg_net, asíncrono). Nunca debe romper el INSERT del reporte.
-- -------------------------------------------------------------------------------------
create or replace function public._llamar_ia(p_id uuid, p_forzar boolean)
returns boolean language plpgsql security definer
set search_path = public, extensions, vault, pg_temp as $$
declare
  v_url    text;
  v_secret text;
begin
  select decrypted_secret into v_url    from vault.decrypted_secrets where name = 'ia_function_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'ia_webhook_secret';
  if v_url is null or v_secret is null then
    return false; -- IA sin configurar: el reporte sigue su camino sin IA
  end if;
  perform net.http_post(
    url     := v_url || case when p_forzar then '?forzar=1' else '' end,
    body    := jsonb_build_object('id', p_id),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', v_secret),
    timeout_milliseconds := 5000);
  return true;
exception when others then
  raise warning '_llamar_ia: %', sqlerrm;
  return false;
end $$;

-- (a) Al crear el reporte con foto.
create or replace function public.reportes_ia_despues_insert()
returns trigger language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
begin
  begin
    perform public._llamar_ia(new.id, false);
  exception when others then
    raise warning 'reportes_ia_despues_insert: %', sqlerrm;
  end;
  return new;
end $$;

drop trigger if exists reportes_ia_despues_insert on public.reportes;
create trigger reportes_ia_despues_insert after insert on public.reportes
  for each row when (new.foto_url is not null)
  execute function public.reportes_ia_despues_insert();

-- (b) Al subirse la foto al bucket (la app puede subirla antes o después de crear el reporte; la función
--     espera un poco si falta uno de los dos y el que llegue segundo completa el trabajo).
create or replace function public.storage_ia_despues_insert()
returns trigger language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_id text;
begin
  begin
    if new.bucket_id = 'evidencias' then
      v_id := substring(new.name from '^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\.jpg$');
      if v_id is not null then
        perform public._llamar_ia(v_id::uuid, false);
      end if;
    end if;
  exception when others then
    raise warning 'storage_ia_despues_insert: %', sqlerrm;
  end;
  return new;
end $$;

-- storage.objects es de supabase_storage_admin: si el SQL Editor no deja crear el disparador, no pasa nada
-- (queda solo el de reportes, que espera a la foto). Alternativa: Dashboard > Database > Webhooks (ver README).
do $$
begin
  drop trigger if exists evidencias_ia_despues_insert on storage.objects;
  create trigger evidencias_ia_despues_insert after insert on storage.objects
    for each row when (new.bucket_id = 'evidencias')
    execute function public.storage_ia_despues_insert();
exception when others then
  raise notice 'No se pudo crear el disparador en storage.objects (%). Se usa solo el de reportes.', sqlerrm;
end $$;

-- -------------------------------------------------------------------------------------
-- 3. «Revisar con IA» a mano desde el panel (mismo patrón de permisos: panel_rol_de).
--    La IA solo ESCRIBE ia_*; el panel solo la PIDE. Admin, moderador y vigía (los que ven la foto).
-- -------------------------------------------------------------------------------------
create or replace function public.solicitar_revision_ia(p_id uuid)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_rol  text := public.panel_rol_de(auth.uid());
  v_foto text;
begin
  if v_rol is null or v_rol not in ('admin', 'moderador_cra', 'vigia') then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  select r.foto_url into v_foto from public.reportes r where r.id = p_id;
  if not found then
    raise exception 'reporte_no_existe' using errcode = 'P0002';
  end if;
  if v_foto is null then
    raise exception 'sin_foto' using errcode = 'P0002';
  end if;
  if not public._llamar_ia(p_id, true) then
    raise exception 'ia_no_configurada' using errcode = 'P0001';
  end if;
  perform public.auditar('solicitar_revision_ia', 'reporte', p_id::text, '{}'::jsonb);
  return jsonb_build_object('id', p_id, 'solicitado', true,
    'nota', 'La IA tarda unos segundos; el resultado llega por Realtime (ia_tipo_detectado, ia_confianza, ia_motivo).');
end $$;

-- -------------------------------------------------------------------------------------
-- 4. Permisos: funciones sin EXECUTE por defecto (misma regla que schema.sql §9)
-- -------------------------------------------------------------------------------------
revoke all on function public.registrar_clasificacion_ia(uuid, text, int, text, jsonb, boolean) from public, anon, authenticated;
revoke all on function public._llamar_ia(uuid, boolean)                from public, anon, authenticated;
revoke all on function public.reportes_ia_despues_insert()             from public, anon, authenticated;
revoke all on function public.storage_ia_despues_insert()              from public, anon, authenticated;
revoke all on function public.solicitar_revision_ia(uuid)              from public, anon, authenticated;

grant execute on function public.registrar_clasificacion_ia(uuid, text, int, text, jsonb, boolean) to service_role;
grant execute on function public.solicitar_revision_ia(uuid) to authenticated;

-- Listo. Prueba: crea un reporte con foto y mira ia_* en unos segundos; o, como admin/moderador/vigía con sesión:
--   select public.solicitar_revision_ia('<uuid del reporte>');
