-- FAXI · Prueba de la migración 023 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas.
-- Debe terminar con NOTICE "FAXI 023 OK".
begin;

do $$
declare
  pax1 uuid := md5('faxi:p:1')::uuid;
  pax2 uuid := md5('faxi:p:2')::uuid;
  d_eco uuid := md5('faxi:d:1')::uuid;      -- Corolla · ECONOMICO
  d_con uuid := md5('faxi:d:9')::uuid;      -- Accord · CONFORT
  t public.trips;
begin
  -- Matriz de la escalera
  assert public.category_can_serve('ECONOMICO', 'ECONOMICO'), 'Económico sirve Económico';
  assert not public.category_can_serve('ECONOMICO', 'CONFORT'), 'Económico NO sirve Confort';
  assert public.category_can_serve('CONFORT', 'ECONOMICO'), 'Confort sirve Económico';
  assert public.category_can_serve('PREMIUM', 'ECONOMICO') and public.category_can_serve('PREMIUM', 'CONFORT'), 'Premium sirve hacia abajo';
  assert not public.category_can_serve('CONFORT', 'PREMIUM'), 'Confort NO sirve Premium';
  assert public.category_can_serve('SUV', 'SUV') and public.category_can_serve('VAN', 'VAN'), 'SUV y Van sirven la suya';
  assert not public.category_can_serve('SUV', 'ECONOMICO') and not public.category_can_serve('VAN', 'CONFORT'), 'SUV y Van no bajan';
  assert not public.category_can_serve('PREMIUM', 'SUV') and not public.category_can_serve('ECONOMICO', 'VAN'), 'nadie sube a SUV/Van';

  -- Los dos conductores en línea en Piantini
  perform set_config('request.jwt.claims', json_build_object('sub', d_eco, 'role', 'authenticated')::text, true);
  perform public.set_driver_availability(true, 18.4719, -69.9406);
  perform set_config('request.jwt.claims', json_build_object('sub', d_con, 'role', 'authenticated')::text, true);
  perform public.set_driver_availability(true, 18.4720, -69.9407);

  -- Viaje CONFORT: lo recibe el Confort, no el Económico
  perform set_config('request.jwt.claims', json_build_object('sub', pax1, 'role', 'authenticated')::text, true);
  t := public.request_trip('CONFORT', 'Piantini', 18.4719, -69.9406, 'Zona Colonial', 18.4733, -69.8840, 'CASH');
  assert exists (select 1 from public.trip_requests where trip_id = t.id and driver_id = d_con), 'el Confort debía recibir el viaje Confort';
  assert not exists (select 1 from public.trip_requests where trip_id = t.id and driver_id = d_eco), 'el Económico NO debía recibir un viaje Confort';

  -- Viaje ECONOMICO: lo reciben el Económico y también el Confort (hacia abajo)
  perform set_config('request.jwt.claims', json_build_object('sub', pax2, 'role', 'authenticated')::text, true);
  t := public.request_trip('ECONOMICO', 'Piantini', 18.4719, -69.9406, 'Naco', 18.4796, -69.9315, 'CASH');
  assert exists (select 1 from public.trip_requests where trip_id = t.id and driver_id = d_eco), 'el Económico debía recibir el viaje Económico';
  assert exists (select 1 from public.trip_requests where trip_id = t.id and driver_id = d_con), 'el Confort debía poder recibir un viaje Económico';

  -- Si el Confort lo acepta, el pasajero paga la tarifa Económica y la comisión sale de ese precio
  perform set_config('request.jwt.claims', json_build_object('sub', d_con, 'role', 'authenticated')::text, true);
  t := public.accept_trip_request((select id from public.trip_requests where trip_id = t.id and driver_id = d_con));
  assert t.status = 'ASSIGNED' and t.driver_id = d_con and t.category = 'ECONOMICO', 'el Confort debía quedar asignado al viaje Económico';

  raise notice 'FAXI 023 OK · los conductores de categoría alta reciben viajes de categorías más bajas; SUV/Van y los de abajo no suben';
end $$;

rollback;
