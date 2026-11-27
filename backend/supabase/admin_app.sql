-- =====================================================================================
-- Zanky · Panel CRA dentro de la app (vista de administración)
-- Cargar DESPUÉS de schema.sql (necesita panel_rol_de, auditar, _orden_estado y las tablas).
-- Es idempotente: se puede correr de nuevo sin romper nada.
--
-- La app funciona SIN este archivo: si estas funciones no existen, aprobar se hace con dos
-- llamadas a cambiar_estado() y «pedir más datos» solo sirve si el reporte está en «recibido».
-- Con el archivo cargado, cada acción es una sola llamada atómica y queda en auditoría.
-- =====================================================================================

-- Aprobar = dejar el reporte en «verificado», pasando por «en_verificación» si hace falta
-- (el esquema solo permite avanzar de un estado a la vez). Todo en una transacción.
-- Roles: admin, moderador_cra y vigía (un vigía puede llegar hasta «verificado»).
create or replace function public.panel_aprobar(p_id uuid, p_nota text default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_uid    uuid := auth.uid();
  v_rol    text := public.panel_rol_de(auth.uid());
  v_actual text;
begin
  if v_rol is null or v_rol not in ('admin', 'moderador_cra', 'vigia') then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if p_nota is not null and char_length(p_nota) > 1000 then
    raise exception 'nota_demasiado_larga' using errcode = '22023';
  end if;

  select r.estado into v_actual from public.reportes r where r.id = p_id for update;
  if not found then
    raise exception 'reporte_no_existe' using errcode = 'P0002';
  end if;
  if v_actual not in ('recibido', 'en_verificacion') then
    raise exception 'transicion_no_permitida: % -> verificado (rol %)', v_actual, v_rol using errcode = '42501';
  end if;

  if v_actual = 'recibido' then
    update public.reportes set estado = 'en_verificacion' where id = p_id;
    insert into public.historial_estado (reporte_id, estado, usuario_id, rol, nota)
    values (p_id, 'en_verificacion', v_uid, v_rol, null);
  end if;

  update public.reportes set estado = 'verificado' where id = p_id;
  insert into public.historial_estado (reporte_id, estado, usuario_id, rol, nota)
  values (p_id, 'verificado', v_uid, v_rol, nullif(btrim(p_nota), ''));

  perform public.auditar('cambio_estado', 'reporte', p_id::text,
    jsonb_build_object('de', v_actual, 'a', 'verificado', 'por', 'panel_aprobar',
                       'nota', nullif(btrim(p_nota), '')));

  return jsonb_build_object('id', p_id, 'estado', 'verificado', 'actualizado_en', now());
end $$;

-- Pedir más datos: el reporte pasa a «en_verificación» (si estaba «recibido») y la persona que
-- reportó lee el mensaje en su app (nota pública, máx. 280 caracteres). No cambia de estado si ya
-- estaba en verificación: solo deja el mensaje (cambiar_estado() no permite repetir el estado).
create or replace function public.panel_pedir_datos(p_id uuid, p_mensaje text)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_uid    uuid := auth.uid();
  v_rol    text := public.panel_rol_de(auth.uid());
  v_actual text;
  v_msg    text := btrim(coalesce(p_mensaje, ''));
begin
  if v_rol is null or v_rol not in ('admin', 'moderador_cra', 'vigia') then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if v_msg = '' then
    raise exception 'mensaje_requerido' using errcode = '22023';
  end if;
  if char_length(v_msg) > 280 then
    raise exception 'nota_publica_demasiado_larga (max 280)' using errcode = '22023';
  end if;

  select r.estado into v_actual from public.reportes r where r.id = p_id for update;
  if not found then
    raise exception 'reporte_no_existe' using errcode = 'P0002';
  end if;
  if v_actual not in ('recibido', 'en_verificacion') then
    raise exception 'transicion_no_permitida: % -> en_verificacion (rol %)', v_actual, v_rol using errcode = '42501';
  end if;

  update public.reportes set estado = 'en_verificacion', nota_publica = v_msg where id = p_id;
  insert into public.historial_estado (reporte_id, estado, usuario_id, rol, nota)
  values (p_id, 'en_verificacion', v_uid, v_rol, 'Se pidieron más datos: ' || v_msg);

  perform public.auditar('pedir_datos', 'reporte', p_id::text,
    jsonb_build_object('de', v_actual, 'mensaje', v_msg));

  return jsonb_build_object('id', p_id, 'estado', 'en_verificacion', 'nota_publica', v_msg, 'actualizado_en', now());
end $$;

-- Supabase concede EXECUTE a anon por defecto: se revoca y se concede solo a quien tiene sesión.
-- Cada función comprueba el rol por dentro (panel_roles), no el token.
revoke all on function public.panel_aprobar(uuid, text)     from public, anon, authenticated;
revoke all on function public.panel_pedir_datos(uuid, text) from public, anon, authenticated;
grant execute on function public.panel_aprobar(uuid, text)     to authenticated;
grant execute on function public.panel_pedir_datos(uuid, text) to authenticated;
