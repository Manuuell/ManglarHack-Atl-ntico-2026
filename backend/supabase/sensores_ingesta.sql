-- Ingesta de sensores de Zanky. Ejecutar después de estadisticas.sql.
-- Aditivo e idempotente; ningún token en claro se guarda en la base.
set search_path = public, extensions;

create table if not exists public.sensor_tokens (
  sensor_id uuid primary key references public.sensores(id) on delete cascade,
  token_sha256 text not null check (token_sha256 ~ '^[0-9a-f]{64}$'),
  creado_en timestamptz not null default now(),
  ultimo_envio timestamptz
);
create unique index if not exists sensor_tokens_hash_ix on public.sensor_tokens(token_sha256);
alter table public.sensor_tokens enable row level security;
revoke all on public.sensor_tokens from public, anon, authenticated;
-- Sin políticas: únicamente el rol de servicio puede administrar los hashes.
grant select on public.sensor_tokens to service_role;

create unique index if not exists lecturas_sensor_reintento_ix
  on public.lecturas_sensor(sensor_id, medido_en);

create table if not exists public.alertas_sensor (
  id bigint generated always as identity primary key,
  sensor_id uuid not null references public.sensores(id) on delete cascade,
  lectura_id bigint not null unique references public.lecturas_sensor(id) on delete cascade,
  valor double precision not null,
  umbral_alerta double precision not null,
  medido_en timestamptz not null,
  registrado_en timestamptz not null default now()
);
create index if not exists alertas_sensor_recientes_ix
  on public.alertas_sensor(registrado_en desc);
alter table public.alertas_sensor enable row level security;
revoke all on public.alertas_sensor from public, anon, authenticated;
grant select on public.alertas_sensor to authenticated;
drop policy if exists alertas_sensor_panel_lee on public.alertas_sensor;
create policy alertas_sensor_panel_lee on public.alertas_sensor for select to authenticated
  using ((select public.panel_rol_de((select auth.uid()))) in ('admin', 'moderador_cra', 'vigia'));

-- Una transacción y un bloqueo por sensor hacen atómicos el límite de tasa,
-- la inserción y la alerta. Solo la Edge Function usa esta RPC con service_role.
create or replace function public.registrar_lote_sensor(
  p_sensor_id uuid, p_token_sha256 text, p_lecturas jsonb
) returns jsonb language plpgsql volatile security definer
set search_path = public, pg_temp as $$
declare
  v_sensor public.sensores%rowtype;
  v_ultimo timestamptz;
  v_lectura jsonb;
  v_id bigint;
  v_nuevas integer := 0;
  v_alertas integer := 0;
begin
  select s.* into v_sensor from public.sensores s where s.id = p_sensor_id and s.activo;
  if not found then
    raise exception 'sensor_no_autorizado' using errcode = '28000';
  end if;
  select t.ultimo_envio into v_ultimo from public.sensor_tokens t
    where t.sensor_id = p_sensor_id and t.token_sha256 = p_token_sha256
    for update;
  if not found then
    raise exception 'token_no_autorizado' using errcode = '28000';
  end if;
  if v_ultimo > now() - interval '30 seconds' then
    raise exception 'limite_de_tasa' using errcode = 'P0001';
  end if;
  if jsonb_typeof(p_lecturas) <> 'array' or jsonb_array_length(p_lecturas) not between 1 and 32 then
    raise exception 'lote_invalido' using errcode = '22023';
  end if;

  for v_lectura in select value from jsonb_array_elements(p_lecturas) loop
    if v_lectura ->> 'tipo' is distinct from v_sensor.tipo then
      raise exception 'tipo_invalido' using errcode = '22023';
    end if;
    insert into public.lecturas_sensor(sensor_id, valor, unidad, medido_en)
    values (p_sensor_id, (v_lectura ->> 'valor')::double precision,
            v_lectura ->> 'unidad', (v_lectura ->> 'medido_en')::timestamptz)
    on conflict (sensor_id, medido_en) do nothing returning id into v_id;
    if v_id is not null then
      v_nuevas := v_nuevas + 1;
      if v_sensor.umbral_alerta is not null
         and (v_lectura ->> 'valor')::double precision >= v_sensor.umbral_alerta then
        insert into public.alertas_sensor(sensor_id, lectura_id, valor, umbral_alerta, medido_en)
        values (p_sensor_id, v_id, (v_lectura ->> 'valor')::double precision,
                v_sensor.umbral_alerta, (v_lectura ->> 'medido_en')::timestamptz);
        v_alertas := v_alertas + 1;
      end if;
    end if;
    v_id := null;
  end loop;
  update public.sensor_tokens set ultimo_envio = now() where sensor_id = p_sensor_id;
  return jsonb_build_object('recibidas', jsonb_array_length(p_lecturas),
                            'nuevas', v_nuevas, 'alertas', v_alertas);
end $$;
revoke all on function public.registrar_lote_sensor(uuid, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.registrar_lote_sensor(uuid, text, jsonb) to service_role;
