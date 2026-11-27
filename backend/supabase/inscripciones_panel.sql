-- =====================================================================================
-- Zanky · Inscripciones a las jornadas que convoca el equipo desde el panel CRA.
--
-- Por qué existe: las jornadas del panel viven en ajustes_panel (contenido_editable.sql) y el
-- servidor del bot de WhatsApp no las conoce, así que su POST /api/jornadas/:id/inscripciones
-- no sirve para ellas. La app inscribe aquí (POST /rest/v1/inscripciones_panel).
--
-- Cargar DESPUÉS de permisos_rol.sql (usa tengo_permiso()) y de contenido_editable.sql (valida
-- que la jornada exista y esté abierta en ajustes_panel). Idempotente: se puede correr otra vez.
-- NO toca tablas ni funciones de schema.sql, admin_app.sql, contenido_editable.sql ni de la web.
--
-- Seguridad (RLS):
--   - Cualquiera (anon o con sesión) inserta SU inscripción, solo con consentimiento de datos.
--   - Solo el equipo con el permiso «gestionar_jornadas» lee las inscripciones.
--   - Nadie edita ni borra desde la API (solo el dueño de la base, desde el editor SQL).
-- =====================================================================================

-- 1. Tabla.
create table if not exists public.inscripciones_panel (
  id              uuid primary key default gen_random_uuid(),
  jornada_id      text not null check (length(jornada_id) between 1 and 80),
  nombre          text not null check (length(btrim(nombre)) between 2 and 120),
  telefono        text check (telefono is null or telefono ~ '^[0-9]{10}$'),
  acepta_datos    boolean not null check (acepta_datos),
  acepta_whatsapp boolean not null default false,
  creada_en       timestamptz not null default now(),
  -- Avisar por WhatsApp exige un celular.
  constraint inscripciones_panel_whatsapp_con_celular check (not acepta_whatsapp or telefono is not null)
);

create index if not exists inscripciones_panel_jornada_idx on public.inscripciones_panel (jornada_id, creada_en desc);

-- El mismo celular no se inscribe dos veces en la misma jornada (la app dice «Ya estás inscrito»).
create unique index if not exists inscripciones_panel_unica_idx
  on public.inscripciones_panel (jornada_id, telefono) where telefono is not null;

-- 2. Solo jornadas del panel que existen y están abiertas (si ajustes_panel ya está cargada).
create or replace function public.inscripciones_panel_validar()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
declare
  v_ok boolean;
begin
  new.nombre := btrim(new.nombre);
  new.creada_en := now();
  if to_regclass('public.ajustes_panel') is null then
    return new;
  end if;
  execute $q$
    select exists (
      select 1
      from public.ajustes_panel a,
           jsonb_array_elements(coalesce(a.valor->'lista', '[]'::jsonb)) j
      where a.clave = 'jornadas'
        and j->>'id' = $1
        and coalesce((j->>'cerrada')::boolean, false) = false
    )$q$ into v_ok using new.jornada_id;
  if not v_ok then
    raise exception 'jornada no encontrada o cerrada' using errcode = 'P0002';
  end if;
  return new;
end $$;

drop trigger if exists inscripciones_panel_validar on public.inscripciones_panel;
create trigger inscripciones_panel_validar
  before insert on public.inscripciones_panel
  for each row execute function public.inscripciones_panel_validar();

-- 3. RLS.
alter table public.inscripciones_panel enable row level security;

drop policy if exists inscripciones_panel_inserta on public.inscripciones_panel;
create policy inscripciones_panel_inserta on public.inscripciones_panel for insert to anon, authenticated
  with check (acepta_datos);

drop policy if exists inscripciones_panel_lee_equipo on public.inscripciones_panel;
create policy inscripciones_panel_lee_equipo on public.inscripciones_panel for select to authenticated
  using (public.tengo_permiso('gestionar_jornadas'));

grant insert on public.inscripciones_panel to anon, authenticated;
grant select on public.inscripciones_panel to authenticated;
revoke update, delete on public.inscripciones_panel from anon, authenticated;
