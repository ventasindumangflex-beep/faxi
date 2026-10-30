-- FAXI · Prueba de la migración 017 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas (usa el seed).
-- Debe terminar con NOTICE "FAXI 017 OK". El monto de RD$100 es solo para la prueba: el recargo real lo define el dueño.
begin;

do $$
declare
  pax uuid := md5('faxi:p:1')::uuid;
  drv uuid := md5('faxi:d:1')::uuid;
  adm uuid := (select id from public.users where role = 'ADMIN' and is_active limit 1);
  sup uuid := (select id from public.users where role = 'SUPER_ADMIN' and is_active limit 1);
  z uuid; h uuid; q record; b record; t public.trips; r public.trip_requests; s public.trip_status; n int;
  sdq_lat double precision := 18.4297; sdq_lng double precision := -69.6689;
begin
  update public.app_settings set value = '100000' where key = 'COMMISSION_DEBT_LIMIT';   -- que la deuda no estorbe

  -- El ADMIN puede crear la zona del aeropuerto, pero sin recargo (apagado por defecto)
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  insert into public.restricted_zones(name, kind, lat, lng, radius_m) values ('Aeropuerto de prueba', 'AEROPUERTO', sdq_lat, sdq_lng, 1500)
  returning id into z;
  begin
    update public.restricted_zones set surcharge = 100 where id = z;
    raise exception 'FALLO: un ADMIN puso el recargo';
  exception when sqlstate '42501' then null; end;
  execute 'reset role';
  assert (select surcharge from public.restricted_zones where id = z) = 0, 'el recargo debe empezar en 0 (apagado)';

  -- Apagado: la cotización no cambia
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  for q in select * from public.quote_trip(18.4719, -69.9406, sdq_lat, sdq_lng) loop
    select * into b from public.quote_fare(q.category, q.distance_km, q.duration_min);
    assert q.airport_surcharge = 0 and q.total = b.total, 'con el recargo en 0 la cotización cambió';
  end loop;

  -- El SUPER_ADMIN lo enciende (RD$100, solo prueba); en un hotel no se puede
  perform set_config('request.jwt.claims', json_build_object('sub', sup, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  update public.restricted_zones set surcharge = 100 where id = z;
  get diagnostics n = row_count;
  assert n = 1, 'el SUPER_ADMIN no pudo poner el recargo';
  insert into public.restricted_zones(name, kind, lat, lng) values ('Hotel de prueba', 'HOTEL', 18.4800, -69.9300) returning id into h;
  begin
    update public.restricted_zones set surcharge = 100 where id = h;
    raise exception 'FALLO: puso recargo a un hotel';
  exception when sqlstate '22023' then null; end;
  execute 'reset role';

  -- Encendido: se suma una vez y se muestra aparte, si el destino o el origen es el aeropuerto
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  for q in select * from public.quote_trip(18.4719, -69.9406, sdq_lat, sdq_lng) loop
    select * into b from public.quote_fare(q.category, q.distance_km, q.duration_min);
    assert q.airport_surcharge = 100 and q.total = b.total + 100, format('%s: recargo %s, total %s', q.category, q.airport_surcharge, q.total);
  end loop;
  assert (select airport_surcharge from public.quote_trip(sdq_lat + 0.001, sdq_lng, 18.4719, -69.9406) limit 1) = 100, 'desde el aeropuerto no lleva recargo';
  assert (select airport_surcharge from public.quote_trip(18.4719, -69.9406, 18.4796, -69.9315) limit 1) = 0, 'un viaje sin aeropuerto lleva recargo';

  -- La regla de 200 m del INTRANT sigue igual: a 100 m del hotel no se recoge; a 300 m sí
  begin
    perform public.request_trip('ECONOMICO', 'Puerta del hotel', 18.4809, -69.9300, 'Piantini', 18.4719, -69.9406, 'CASH');
    raise exception 'FALLO: la 017 debilitó la regla de 200 m (recogió a ~100 m de un hotel)';
  exception when sqlstate '22023' then null; end;
  assert not exists (select 1 from public.trips where passenger_id = pax and origin_address = 'Puerta del hotel'), 'se creó un viaje desde la puerta del hotel';

  -- Viaje al aeropuerto: el estimado y el precio final llevan el recargo; la comisión va sobre el total
  update public.drivers set availability = 'OFFLINE' where id = drv;
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  perform public.set_driver_availability(true, 18.4719, -69.9406);
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  t := public.request_trip('ECONOMICO', 'Piantini', 18.4719, -69.9406, 'Aeropuerto', sdq_lat, sdq_lng, 'CASH');
  assert t.airport_surcharge = 100, 'el viaje no guardó el recargo';
  assert t.estimated_fare = (select total from public.quote_trip(18.4719, -69.9406, sdq_lat, sdq_lng) where category = 'ECONOMICO'), 'el estimado no coincide con la cotización';
  select * into r from public.trip_requests where trip_id = t.id and driver_id = drv;
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  t := public.accept_trip_request(r.id);
  foreach s in array array['ENROUTE','ARRIVED','STARTED','ONTRIP','FINISHED']::public.trip_status[] loop
    t := public.driver_advance_trip(t.id, s);
  end loop;
  select * into b from public.quote_fare(t.category, t.distance_km, t.duration_min);
  assert t.final_fare = b.total + 100, format('precio final %s, esperado %s', t.final_fare, b.total + 100);
  assert t.faxi_commission = round(t.final_fare * t.commission_rate, 2), 'la comisión no va sobre el total';

  -- El aeropuerto no prohíbe recoger
  perform public.driver_confirm_cash(t.id);
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  t := public.request_trip('ECONOMICO', 'Aeropuerto', sdq_lat, sdq_lng, 'Piantini', 18.4719, -69.9406, 'CASH');
  assert t.status = 'SEARCHING' and t.airport_surcharge = 100, 'no dejó pedir desde el aeropuerto';
  perform public.cancel_trip(t.id, 'prueba');

  -- Zona pausada: sin recargo
  update public.restricted_zones set is_active = false where id = z;
  assert (select airport_surcharge from public.quote_trip(18.4719, -69.9406, sdq_lat, sdq_lng) limit 1) = 0, 'una zona pausada cobra recargo';

  raise notice 'FAXI 017 OK · recargo del aeropuerto apagado por defecto, solo SUPER_ADMIN, aparte en la cotización y en el precio final';
end $$;

rollback;
