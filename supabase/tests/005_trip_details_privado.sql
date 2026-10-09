-- FAXI · Prueba de la migración 007 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas (usa el seed).
-- Debe terminar con NOTICE "FAXI 007 OK".
begin;

do $$
declare
  pax uuid := md5('faxi:p:1')::uuid;
  drv uuid := md5('faxi:d:1')::uuid;
  t public.trips; r public.trip_requests; s public.trip_status; d jsonb; n int;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  perform public.set_driver_availability(true, 18.4719, -69.9406);
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  t := public.request_trip('ECONOMICO', 'Piantini', 18.4719, -69.9406, 'Naco', 18.4796, -69.9315, 'CASH');
  select * into r from public.trip_requests where trip_id = t.id and driver_id = drv;
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  t := public.accept_trip_request(r.id);

  -- Durante el viaje: el pasajero ve ubicación y teléfono, y la ficha del conductor
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  d := public.trip_details(t.id);
  assert d->'driver'->>'lat' is not null, 'sin ubicación durante el viaje';
  execute 'set local role authenticated';
  select count(*) into n from public.drivers where id = drv;
  execute 'reset role';
  assert n = 1, 'el pasajero no ve al conductor durante el viaje';

  -- Termina el viaje en efectivo
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  foreach s in array array['ENROUTE','ARRIVED','STARTED','ONTRIP','FINISHED']::public.trip_status[] loop
    t := public.driver_advance_trip(t.id, s);
  end loop;
  perform public.driver_confirm_cash(t.id);

  -- Después: ni ubicación ni teléfono, ni ficha del conductor por la tabla
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  d := public.trip_details(t.id);
  assert d->'driver'->>'lat' is null and d->'driver'->>'phone' is null, 'ubicación o teléfono visibles tras el viaje';
  assert d->'driver'->>'name' is not null and d->'vehicle'->>'plate' is not null, 'el recibo perdió nombre o placa';
  execute 'set local role authenticated';
  select count(*) into n from public.drivers where id = drv;
  execute 'reset role';
  assert n = 0, 'el pasajero sigue viendo la ficha (y ubicación) del conductor tras el viaje';

  -- Calificar sigue funcionando
  perform public.rate_trip(t.id, 5, 'Bien');

  raise notice 'FAXI 007 OK · datos del conductor solo durante el viaje';
end $$;

rollback;
