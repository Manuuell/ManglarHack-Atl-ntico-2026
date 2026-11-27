-- =====================================================================================
-- Zanky · DATOS DE DEMOSTRACIÓN (no son reportes reales)
-- =====================================================================================
-- 15 reportes de prueba, todos con la descripción «[DEMO] …» y reportante_id nulo, repartidos en las
-- 4 zonas de manglar, con tipos y estados variados. Los puntos están dentro de los polígonos (INVEMAR),
-- a ~150-300 m (área de influencia) o a >1 km. La zona, la distancia, la corroboración y la prioridad
-- las calcula el trigger de recepción con PostGIS, igual que con un reporte de verdad.
--
-- Correr DESPUÉS de schema.sql y zonas.sql, en el SQL Editor (rol postgres). No hace falta apagar el
-- trigger del límite: reportante_id es nulo, y el límite solo cuenta por reportante_id. Es repetible
-- (ids fijos; si ya existen, no se duplican).
--
-- Para quitar la demostración (como postgres; el historial es solo-INSERT, así que se apaga su
-- trigger un momento y se vuelve a prender):
--   alter table public.historial_estado disable trigger historial_inmutable_fila;
--   delete from public.historial_estado h using public.reportes r where h.reporte_id = r.id and r.descripcion like '[DEMO]%';
--   alter table public.historial_estado enable trigger historial_inmutable_fila;
--   delete from public.reportes where descripcion like '[DEMO]%';
--
-- Por honestidad del dato: nada de esto debe aparecer en el pitch como actividad real.
-- =====================================================================================
set search_path = public, extensions;

-- Paso 1: recepción normal (el trigger fija zona, prioridad, corroboraciones y estado 'recibido').
insert into public.reportes
  (id, canal, tipo, descripcion, lat, lon, precision_m, metodo_ubicacion, capturado_en, momento, magnitud,
   confianza, foto_de_camara, anonimo)
values
  -- Ciénaga de Mallorquín (prioridad de conservación 5)
  ('1a3cde00-0000-4000-8000-000000000001', 'app',      'tala',          '[DEMO] Troncos de mangle recién cortados y apilados en la orilla.',
   11.05617, -74.84053, 8,  'gps',  now() - interval '50 minutes', 'ahora', 'grande',  70, true,  false),
  ('2b7ede00-0000-4000-8000-000000000002', 'app',      'quema',         '[DEMO] Humo y llamas en el borde del manglar, el viento lo empuja hacia adentro.',
   11.04342, -74.87890, 12, 'gps',  now() - interval '35 minutes', 'ahora', 'mediana', 75, true,  false),
  ('3c19de00-0000-4000-8000-000000000003', 'web',      'relleno',       '[DEMO] Volqueta botando escombros en un lote pegado al caño.',
   11.06395, -74.84334, 25, 'mapa', now() - interval '3 hours',    'hoy',   'mediana', 55, false, false),
  ('4d82de00-0000-4000-8000-000000000004', 'app',      'basuras',       '[DEMO] Botella y plástico enredado en las raíces, jornada de limpieza.',
   11.03208, -74.85488, 10, 'gps',  now() - interval '26 hours',   'antes', 'pequena', 60, true,  false),
  ('5e4ade00-0000-4000-8000-000000000005', 'whatsapp', 'vertimiento',   '[DEMO] Tubo botando agua con espuma y mal olor hacia la ciénaga.',
   11.07395, -74.84636, 40, 'enlace', now() - interval '2 hours',  'hoy',   'mediana', 50, false, true),
  -- Costa de Tubará (4)
  ('6f07de00-0000-4000-8000-000000000006', 'app',      'cano_taponado', '[DEMO] El caño está cerrado con tierra y llantas, el agua dulce no pasa.',
   10.95266, -75.02417, 9,  'gps',  now() - interval '5 hours',    'hoy',   'mediana', 65, true,  false),
  ('7a5dde00-0000-4000-8000-000000000007', 'app',      'tala',          '[DEMO] Se oye motosierra al fondo del manglar, vi a dos personas cortando.',
   10.95624, -75.02210, 15, 'gps',  now() - interval '45 minutes', 'ahora', 'mediana', 70, true,  false),
  -- Costa de Juan de Acosta (4)
  ('9c2fde00-0000-4000-8000-000000000009', 'app',      'fauna',         '[DEMO] Varios peces y un ave muertos junto a la orilla.',
   10.85898, -75.12574, 7,  'gps',  now() - interval '20 minutes', 'ahora', 'mediana', 65, true,  false),
  ('a41ede00-0000-4000-8000-000000000010', 'web',      'vertimiento',   '[DEMO] Mancha de aceite en el agua cerca de la desembocadura.',
   10.85671, -75.12847, 30, 'mapa', now() - interval '4 hours',    'hoy',   'pequena', 45, true,  false),
  ('b65cde00-0000-4000-8000-000000000011', 'app',      'basuras',       '[DEMO] Bolsas de basura en un lote lejos del manglar (reporte de práctica).',
   10.86705, -75.13967, 20, 'gps',  now() - interval '30 hours',   'antes', 'pequena', 25, false, false),
  -- Ciénaga del Totumo, Piojó (5)
  ('c87ade00-0000-4000-8000-000000000012', 'app',      'quema',         '[DEMO] Columna de humo grande, se ve desde la carretera.',
   10.71241, -75.21671, 14, 'gps',  now() - interval '15 minutes', 'ahora', 'grande',  70, true,  false),
  ('d9b1de00-0000-4000-8000-000000000013', 'whatsapp', 'tala',          '[DEMO] Mangle cortado con machete, ya no hay nadie en el sitio.',
   10.69096, -75.21862, 35, 'enlace', now() - interval '6 hours',  'hoy',   'mediana', 55, true,  false),
  ('e2f4de00-0000-4000-8000-000000000014', 'app',      'otro',          '[DEMO] Cerca de pozos nuevos, se ve el agua de otro color (a confirmar).',
   10.71296, -75.21340, 60, 'gps',  now() - interval '28 hours',   'antes', 'pequena', 30, false, false),
  ('f36dde00-0000-4000-8000-000000000015', 'app',      'fauna',         '[DEMO] Un caimán atrapado en una red abandonada.',
   10.82840, -75.17435, 11, 'gps',  now() - interval '7 hours',    'hoy',   'pequena', 60, true,  false)
on conflict (id) do nothing;

-- El 8 va aparte: tala a ~400 m del 7, mismo tipo y misma hora, para que el trigger cuente la
-- corroboración (y suba la prioridad de los dos reportes de tala en la demo).
insert into public.reportes
  (id, canal, tipo, descripcion, lat, lon, precision_m, metodo_ubicacion, capturado_en, momento, magnitud,
   confianza, foto_de_camara, anonimo)
values
  ('8b93de00-0000-4000-8000-000000000008', 'app', 'tala',
   '[DEMO] Más troncos cortados cerca de la orilla, parece el mismo grupo.',
   10.95290, -75.02387, 10, 'gps', now() - interval '30 minutes', 'ahora', 'grande', 70, true, false)
on conflict (id) do nothing;

-- Paso 2: como administrador (esto es el SQL Editor), se simula lo que el panel ya hizo con ellos:
-- estado, hora de recepción (el caso 11 llegó tarde: se capturó sin señal), expediente y nota pública.
-- Los expedientes de demostración llevan «DEMO» para no gastar la numeración oficial.
update public.reportes r
   set estado         = v.estado,
       recibido_en    = r.capturado_en + v.demora,
       nota_publica   = v.nota_publica,
       expediente     = v.expediente,
       sincronizado_tarde = v.demora > interval '10 minutes'
  from (values
    ('1a3cde00-0000-4000-8000-000000000001'::uuid, 'verificado',      interval '2 minutes',  '[DEMO] Un vigía confirmó la tala. Gracias por avisar.', null::text),
    ('2b7ede00-0000-4000-8000-000000000002'::uuid, 'alerta_oficial',  interval '1 minute',   '[DEMO] Se abrió un expediente en la CRA.',            'CRA-MH-2026-DEMO1'),
    ('3c19de00-0000-4000-8000-000000000003'::uuid, 'en_verificacion', interval '4 minutes',  '[DEMO] Un funcionario lo está revisando.',            null),
    ('4d82de00-0000-4000-8000-000000000004'::uuid, 'cerrado',         interval '3 minutes',  '[DEMO] La basura se retiró en la jornada de limpieza.', null),
    ('5e4ade00-0000-4000-8000-000000000005'::uuid, 'recibido',        interval '1 minute',   null,                                                  null),
    ('6f07de00-0000-4000-8000-000000000006'::uuid, 'en_atencion',     interval '6 minutes',  '[DEMO] Hay una cuadrilla en camino al caño.',         'CRA-MH-2026-DEMO2'),
    ('7a5dde00-0000-4000-8000-000000000007'::uuid, 'recibido',        interval '2 minutes',  null,                                                  null),
    ('8b93de00-0000-4000-8000-000000000008'::uuid, 'recibido',        interval '1 minute',   null,                                                  null),
    ('9c2fde00-0000-4000-8000-000000000009'::uuid, 'verificado',      interval '2 minutes',  '[DEMO] Confirmado por un vigía de la comunidad.',     null),
    ('a41ede00-0000-4000-8000-000000000010'::uuid, 'en_verificacion', interval '5 minutes',  null,                                                  null),
    ('b65cde00-0000-4000-8000-000000000011'::uuid, 'descartado',      interval '90 minutes', '[DEMO] Quedó lejos del manglar y no lo afecta.',      null),
    ('c87ade00-0000-4000-8000-000000000012'::uuid, 'recibido',        interval '1 minute',   null,                                                  null),
    ('d9b1de00-0000-4000-8000-000000000013'::uuid, 'verificado',      interval '3 minutes',  '[DEMO] Confirmado. Se avisó a la autoridad ambiental.', null),
    ('e2f4de00-0000-4000-8000-000000000014'::uuid, 'recibido',        interval '2 minutes',  null,                                                  null),
    ('f36dde00-0000-4000-8000-000000000015'::uuid, 'en_atencion',     interval '8 minutes',  '[DEMO] Rescatistas de fauna en camino.',              null)
  ) as v(id, estado, demora, nota_publica, expediente)
 where r.id = v.id
   and r.descripcion like '[DEMO]%';

-- Historial coherente con el estado simulado (una fila por reporte que ya no está en «recibido»).
insert into public.historial_estado (reporte_id, estado, usuario_id, rol, nota, creado_en)
select r.id, r.estado, null, 'sistema', '[DEMO] Estado de demostración', r.recibido_en + interval '5 minutes'
  from public.reportes r
 where r.descripcion like '[DEMO]%'
   and r.estado <> 'recibido'
   and not exists (select 1 from public.historial_estado h where h.reporte_id = r.id and h.estado = r.estado);

-- Comprobación: debe haber 15 reportes de demostración repartidos en 4 zonas.
select zona, count(*) as reportes, min(prioridad) as prio_min, max(prioridad) as prio_max
  from public.reportes where descripcion like '[DEMO]%' group by zona order by zona;
