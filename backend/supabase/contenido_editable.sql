-- =====================================================================================
-- Zanky · Contenido editable desde el panel CRA (portada, jornadas, noticias, puntos QR y
-- umbrales de sensores) con historial de cambios (quién cambió qué y cuándo).
--
-- Cargar DESPUÉS de schema.sql, estadisticas.sql, puntos.sql, admin_app.sql y permisos_rol.sql
-- (usa tengo_permiso() y panel_rol_de()). Idempotente: se puede correr otra vez sin romper nada.
--
-- La app funciona SIN este archivo: usa los valores de fábrica y lo dice en el panel.
--
-- Permisos (los mismos nombres de permisos_rol.sql y de la web):
--   portada, noticias          -> editar_contenido
--   jornadas                   -> gestionar_jornadas
--   puntos_qr, umbrales_sensores -> gestionar_puntos
-- =====================================================================================
set search_path = public, extensions;

-- 1. Un ajuste por sección. El valor es JSON (lo arma la app; el servidor limita tamaño y forma).
create table if not exists public.ajustes_panel (
  clave           text primary key check (clave in ('portada','jornadas','noticias','puntos_qr','umbrales_sensores')),
  valor           jsonb not null default '{}'::jsonb check (jsonb_typeof(valor) = 'object'),
  actualizado_en  timestamptz not null default now(),
  actualizado_por uuid
);

-- 2. Historial del panel: una fila por cambio guardado. Solo lo escribe guardar_ajuste().
create table if not exists public.historial_panel (
  id         bigint generated always as identity primary key,
  creado_en  timestamptz not null default now(),
  usuario_id uuid,
  correo     text,
  rol        text,
  clave      text not null,
  resumen    text not null check (char_length(resumen) between 1 and 200),
  antes      jsonb,
  despues    jsonb
);
create index if not exists historial_panel_fecha_ix on public.historial_panel (creado_en desc);

-- 3. Qué permiso pide cada sección.
create or replace function public.permiso_de_ajuste(p_clave text)
returns text language sql immutable set search_path = public, pg_temp as $$
  select case p_clave
    when 'portada' then 'editar_contenido'
    when 'noticias' then 'editar_contenido'
    when 'jornadas' then 'gestionar_jornadas'
    when 'puntos_qr' then 'gestionar_puntos'
    when 'umbrales_sensores' then 'gestionar_puntos'
  end;
$$;

-- 4. Guardar una sección (único camino de escritura). Comprueba el permiso, limita el tamaño,
--    deja historial y aplica lo que tiene efecto en otras tablas (puntos y umbrales).
create or replace function public.guardar_ajuste(p_clave text, p_valor jsonb, p_resumen text)
returns jsonb language plpgsql security definer
set search_path = public, extensions, pg_temp as $$
declare
  v_permiso text := public.permiso_de_ajuste(p_clave);
  v_antes   jsonb;
  v_codigo  text;
  v_tipo    text;
begin
  if v_permiso is null then
    raise exception 'clave_invalida' using errcode = '22023';
  end if;
  if not public.tengo_permiso(v_permiso) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if p_valor is null or jsonb_typeof(p_valor) <> 'object' or length(p_valor::text) > 60000 then
    raise exception 'valor_invalido' using errcode = '22023';
  end if;

  select valor into v_antes from public.ajustes_panel where clave = p_clave;

  insert into public.ajustes_panel (clave, valor, actualizado_en, actualizado_por)
  values (p_clave, p_valor, now(), auth.uid())
  on conflict (clave) do update
    set valor = excluded.valor, actualizado_en = now(), actualizado_por = auth.uid();

  -- Puntos QR: «inactivos» apaga el punto de verdad (la app del visitante ya respeta `activo`).
  if p_clave = 'puntos_qr' and to_regclass('public.puntos_zanky') is not null then
    update public.puntos_zanky set activo = true
     where not activo and codigo not in (select jsonb_array_elements_text(coalesce(p_valor->'inactivos','[]'::jsonb)));
    for v_codigo in select jsonb_array_elements_text(coalesce(p_valor->'inactivos','[]'::jsonb)) loop
      update public.puntos_zanky set activo = false where codigo = v_codigo;
    end loop;
  end if;

  -- Umbrales: se copian a sensores.umbral_alerta de cada magnitud (lo que dispara la alerta).
  if p_clave = 'umbrales_sensores' and to_regclass('public.sensores') is not null then
    for v_tipo in select jsonb_object_keys(coalesce(p_valor->'umbrales','{}'::jsonb)) loop
      if v_tipo in ('nivel_agua','salinidad','temperatura','turbidez')
         and jsonb_typeof(p_valor->'umbrales'->v_tipo) = 'number' then
        update public.sensores set umbral_alerta = (p_valor->'umbrales'->>v_tipo)::double precision
         where tipo = v_tipo;
      end if;
    end loop;
  end if;

  insert into public.historial_panel (usuario_id, correo, rol, clave, resumen, antes, despues)
  values (auth.uid(),
          (select u.email::text from auth.users u where u.id = auth.uid()),
          public.panel_rol_de(auth.uid()),
          p_clave,
          left(coalesce(nullif(btrim(p_resumen), ''), 'Cambió ' || p_clave), 200),
          v_antes, p_valor);

  return jsonb_build_object('clave', p_clave, 'actualizado_en', now());
end $$;

-- 5. Seguridad (RLS).
alter table public.ajustes_panel   enable row level security;
alter table public.historial_panel enable row level security;

-- Lo que ve el público (portada, jornadas, noticias, puntos) lo lee cualquiera; los umbrales,
-- solo el equipo (estadisticas_parche_1.sql ya los oculta al público).
drop policy if exists ajustes_panel_lee on public.ajustes_panel;
create policy ajustes_panel_lee on public.ajustes_panel for select to anon, authenticated
  using (clave <> 'umbrales_sensores' or public.panel_rol_de(auth.uid()) is not null);

drop policy if exists historial_panel_lee_equipo on public.historial_panel;
create policy historial_panel_lee_equipo on public.historial_panel for select to authenticated
  using (public.panel_rol_de(auth.uid()) is not null);

-- Puntos QR: el público solo lee los activos (puntos.sql); quien gestiona puntos ve también los
-- apagados, para poder volver a encenderlos desde el panel.
do $$
begin
  if to_regclass('public.puntos_zanky') is not null then
    execute 'drop policy if exists puntos_equipo_lee_todos on public.puntos_zanky';
    execute 'create policy puntos_equipo_lee_todos on public.puntos_zanky for select to authenticated
               using (public.tengo_permiso(''gestionar_puntos''))';
  end if;
end $$;

-- Nadie escribe directo: solo guardar_ajuste().
revoke all on public.ajustes_panel   from public, anon, authenticated;
revoke all on public.historial_panel from public, anon, authenticated;
grant select on public.ajustes_panel   to anon, authenticated;
grant select on public.historial_panel to authenticated;

revoke all on function public.permiso_de_ajuste(text)               from public, anon, authenticated;
revoke all on function public.guardar_ajuste(text, jsonb, text)     from public, anon, authenticated;
grant execute on function public.permiso_de_ajuste(text)            to authenticated;
grant execute on function public.guardar_ajuste(text, jsonb, text)  to authenticated;
