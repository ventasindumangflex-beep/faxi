-- FAXI · Prueba de la migración 024 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas.
-- Debe terminar con NOTICE "FAXI 024 OK".
--
-- Comprueba tres cosas:
--   1. Ninguna política RLS evalúa auth.uid() o auth_role() fila por fila.
--   2. Los índices de claves foráneas existen.
--   3. Lo más importante: las políticas siguen protegiendo igual que antes.
--      Un pasajero NO puede ver el viaje de otro pasajero.
begin;

-- ───────── 1. Ninguna política re-evalúa auth por fila ─────────
do $$
declare n int; malas text;
begin
  -- Postgres guarda la política ya normalizada: "( SELECT auth.uid() AS uid)".
  -- Contamos cuántas veces aparece auth.uid() suelta, es decir sin un SELECT delante.
  select count(*), coalesce(string_agg(tablename || '.' || policyname, ', '), '')
    into n, malas
  from (
    select tablename, policyname,
           regexp_count(coalesce(qual,'') || ' ' || coalesce(with_check,''), 'auth\.uid\(\)')
             - regexp_count(coalesce(qual,'') || ' ' || coalesce(with_check,''), 'SELECT auth\.uid\(\)', 1, 'i') as sueltas_uid,
           regexp_count(coalesce(qual,'') || ' ' || coalesce(with_check,''), 'auth_role\(\)')
             - regexp_count(coalesce(qual,'') || ' ' || coalesce(with_check,''), 'SELECT auth_role\(\)', 1, 'i') as sueltas_rol
    from pg_policies where schemaname = 'public'
  ) p
  where p.sueltas_uid > 0 or p.sueltas_rol > 0;
  assert n = 0, 'quedan ' || n || ' políticas que evalúan auth por fila: ' || malas;
  raise notice '  · ninguna política re-evalúa auth.uid() por fila';
end $$;

-- ───────── 2. Los índices de claves foráneas existen ─────────
do $$
declare faltan text;
begin
  select coalesce(string_agg(x.nombre, ', '), '') into faltan
  from unnest(array[
    'trips_vehicle_idx','trips_cancelled_by_idx','trips_pricing_rule_idx',
    'drivers_current_vehicle_idx','drivers_reviewed_by_idx','vehicles_reviewed_by_idx',
    'ratings_passenger_idx','messages_sender_idx','support_tickets_user_idx',
    'support_tickets_trip_idx','support_tickets_assigned_idx','driver_docs_reviewed_by_idx',
    'vehicle_docs_reviewed_by_idx','commission_pay_recorded_idx','commission_pay_voided_idx'
  ]) as x(nombre)
  where not exists (select 1 from pg_indexes i where i.schemaname = 'public' and i.indexname = x.nombre);
  assert faltan = '', 'faltan índices: ' || faltan;
  raise notice '  · los 15 índices de claves foráneas existen';
end $$;

-- ───────── 3. Las políticas siguen protegiendo: un pasajero no ve el viaje de otro ─────────
do $$
declare
  pax1 uuid := md5('faxi:p:1')::uuid;
  pax2 uuid := md5('faxi:p:2')::uuid;
  t public.trips;
  v_visibles int;
begin
  -- pax1 pide un viaje (como servicio, para poder crearlo)
  perform set_config('request.jwt.claims', json_build_object('sub', pax1, 'role', 'authenticated')::text, true);
  t := public.request_trip('ECONOMICO', 'Piantini', 18.4719, -69.9406, 'Naco', 18.4796, -69.9315, 'CASH');
  assert t.passenger_id = pax1, 'el viaje debía quedar a nombre de pax1';

  -- ahora miramos la tabla CON las políticas activas, en la piel de pax2
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', pax2, 'role', 'authenticated')::text, true);
  select count(*) into v_visibles from public.trips where id = t.id;
  assert v_visibles = 0, 'FALLO DE SEGURIDAD: pax2 puede ver el viaje de pax1';

  -- y en la piel de pax1, que sí debe verlo
  perform set_config('request.jwt.claims', json_build_object('sub', pax1, 'role', 'authenticated')::text, true);
  select count(*) into v_visibles from public.trips where id = t.id;
  assert v_visibles = 1, 'pax1 debería ver su propio viaje y no lo ve';

  reset role;
  raise notice '  · las políticas siguen protegiendo: cada pasajero solo ve lo suyo';
end $$;

do $$ begin
  raise notice 'FAXI 024 OK · RLS evaluado una sola vez por consulta, 15 índices nuevos, y la protección intacta';
end $$;

rollback;
