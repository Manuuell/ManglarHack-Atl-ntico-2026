-- =====================================================================================
-- Zanky · SENSORES DE DEMOSTRACIÓN (no son sensores ni lecturas reales)  -- DEMOSTRACIÓN
-- =====================================================================================
-- Opcional. Correr DESPUÉS de estadisticas.sql y de zonas-N.sql. Sirve solo para ver cómo se vería el
-- panel con sensores: todo lo de aquí es inventado, lleva «[DEMO]» en el nombre y NO debe presentarse
-- como medición real. Repetible: ids fijos; las lecturas se insertan solo si el sensor aún no tiene ninguna.
--
-- Para quitarlo (como postgres):
--   delete from public.sensores where nombre like '[DEMO]%';   -- borra también sus lecturas (cascade)
-- =====================================================================================
set search_path = public, extensions;

insert into public.sensores (id, nombre, tipo, zona_id, lat, lon, activo, umbral_alerta)
values
  -- DEMOSTRACIÓN
  ('5e500000-0000-4000-8000-000000000001', '[DEMO] Nivel de agua · Mallorquín',  'nivel_agua',  'mallorquin',     11.0562, -74.8405, true, 1.5),
  -- DEMOSTRACIÓN
  ('5e500000-0000-4000-8000-000000000002', '[DEMO] Salinidad · Tubará',          'salinidad',   'tubara',         10.9527, -75.0241, true, 45),
  -- DEMOSTRACIÓN
  ('5e500000-0000-4000-8000-000000000003', '[DEMO] Temperatura · Juan de Acosta', 'temperatura', 'juan_de_acosta', 10.8590, -75.1257, true, 34),
  -- DEMOSTRACIÓN
  ('5e500000-0000-4000-8000-000000000004', '[DEMO] Turbidez · Ciénaga del Totumo', 'turbidez',   'piojo',          10.7125, -75.2162, true, 100)
on conflict (id) do nothing;

-- DEMOSTRACIÓN: una lectura inventada por sensor (la del Totumo pasa el umbral para mostrar la alerta).
insert into public.lecturas_sensor (sensor_id, valor, unidad, medido_en)
select v.sensor_id, v.valor, v.unidad, now() - v.hace
  from (values
    ('5e500000-0000-4000-8000-000000000001'::uuid, 0.8::double precision,  'm',   interval '20 minutes'),  -- DEMOSTRACIÓN
    ('5e500000-0000-4000-8000-000000000002'::uuid, 32.5::double precision, 'ppt', interval '35 minutes'),  -- DEMOSTRACIÓN
    ('5e500000-0000-4000-8000-000000000003'::uuid, 30.1::double precision, '°C',  interval '10 minutes'),  -- DEMOSTRACIÓN
    ('5e500000-0000-4000-8000-000000000004'::uuid, 120::double precision,  'NTU', interval '15 minutes')   -- DEMOSTRACIÓN
  ) as v(sensor_id, valor, unidad, hace)
 where exists (select 1 from public.sensores s where s.id = v.sensor_id)
   and not exists (select 1 from public.lecturas_sensor l where l.sensor_id = v.sensor_id);
