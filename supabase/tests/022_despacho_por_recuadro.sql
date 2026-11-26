-- FAXI · Prueba de la migración 025 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas.
-- Debe terminar con NOTICE "FAXI 025 OK".
--
-- El recuadro de coordenadas es solo un filtro previo para no calcular distancias de más.
-- Lo que hay que demostrar es que NO cambia a quién se le ofrece el viaje:
--   · un conductor cerca sigue recibiendo la solicitud,
--   · un conductor lejos sigue sin recibirla,
--   · y el que está justo dentro del radio no se pierde por culpa del recuadro.
begin;

-- El aviso push sale por pg_net; en una prueba no queremos llamadas de red.
alter table public.notifications disable trigger user;

do $$
declare
  pax   uuid := md5('faxi:p:1')::uuid;
  cerca uuid := md5('faxi:d:1')::uuid;   -- Corolla · ECONOMICO
  lejos uuid := md5('faxi:d:2')::uuid;   -- otro ECONOMICO
  t public.trips;
  v_radio numeric := coalesce(public.setting_num('DISPATCH_RADIUS_KM'), 8);
begin
  assert exists (select 1 from pg_indexes where schemaname='public' and indexname='drivers_online_pos_idx'),
    'falta el índice drivers_online_pos_idx';

  update public.drivers set availability='OFFLINE' where availability='ONLINE';

  -- uno a 300 m del pasajero, otro a unos 55 km (fuera del Gran Santo Domingo)
  perform set_config('request.jwt.claims', json_build_object('sub', cerca, 'role','authenticated')::text, true);
  perform public.set_driver_availability(true, 18.4745, -69.9406);
  update public.drivers set availability='ONLINE', last_lat = 18.9719, last_lng = -69.9406, last_location_at = now()
   where id = lejos;

  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role','authenticated')::text, true);
  t := public.request_trip('ECONOMICO','Piantini',18.4719,-69.9406,'Naco',18.4796,-69.9315,'CASH');

  assert exists (select 1 from public.trip_requests where trip_id=t.id and driver_id=cerca),
    'el conductor cercano debía recibir la solicitud';
  assert not exists (select 1 from public.trip_requests where trip_id=t.id and driver_id=lejos),
    'el conductor a 55 km NO debía recibir la solicitud';

  -- La distancia guardada nunca puede pasar del radio configurado
  assert not exists (select 1 from public.trip_requests where trip_id=t.id and distance_to_pickup_km > v_radio),
    'se ofreció el viaje a alguien más lejos que el radio de despacho';

  perform public.cancel_trip(t.id, 'prueba');
  raise notice '  · cerca recibe, lejos no, y nadie fuera del radio';
end $$;

-- El recuadro no debe recortar a quien está justo dentro del radio:
-- un conductor a ~7,5 km en diagonal (dentro de 8 km) sigue entrando.
do $$
declare
  pax   uuid := md5('faxi:p:1')::uuid;
  borde uuid := md5('faxi:d:1')::uuid;
  t public.trips;
  d_km numeric;
begin
  update public.drivers set availability='OFFLINE' where availability='ONLINE';
  update public.drivers set availability='ONLINE', last_lat = 18.5069, last_lng = -69.9739, last_location_at = now()
   where id = borde;   -- ~5,4 km en línea recta, ~7,3 km con el factor 1,35

  select e.distance_km into d_km
    from public.route_estimate(18.5069, -69.9739, 18.4719, -69.9406) e;
  assert d_km <= 8, 'el conductor del borde debería estar dentro del radio (está a ' || d_km || ' km)';

  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role','authenticated')::text, true);
  t := public.request_trip('ECONOMICO','Piantini',18.4719,-69.9406,'Naco',18.4796,-69.9315,'CASH');
  assert exists (select 1 from public.trip_requests where trip_id=t.id and driver_id=borde),
    'el recuadro recortó a un conductor que SÍ estaba dentro del radio';

  perform public.cancel_trip(t.id, 'prueba');
  raise notice '  · el conductor del borde del radio no se pierde';
end $$;

do $$ begin
  raise notice 'FAXI 025 OK · el despacho filtra por recuadro antes de calcular distancias y ofrece a los mismos conductores';
end $$;

rollback;
