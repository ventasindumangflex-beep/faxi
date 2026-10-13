-- FAXI · Prueba de la migración 005 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas (usa el seed).
-- Debe terminar con NOTICE "FAXI 005 OK".
begin;

do $$
declare
  pax uuid := md5('faxi:p:1')::uuid;      -- pasajero del viaje
  pax2 uuid := md5('faxi:p:2')::uuid;     -- otro pasajero
  drv uuid := md5('faxi:d:1')::uuid;      -- conductor del viaje
  adm uuid := (select id from public.users where role = 'SUPER_ADMIN' limit 1);
  t public.trips; r public.trip_requests; topic text; k text; ok boolean;
  inside text[] := array['18.4735,-69.8840','18.4720,-69.9390','18.4297,-69.6689','18.4510,-69.6060','18.5170,-70.0170',
                         '18.5680,-70.0910','18.5550,-69.9100','18.5030,-69.7600','18.4580,-69.9050','18.5170,-69.8560'];
  outside text[] := array['19.4517,-70.6970','18.4260,-69.4260','18.4167,-70.1000','18.4270,-68.9700','18.7900,-69.9000'];
begin
  -- Zona de servicio: Gran Santo Domingo sí; Santiago, Juan Dolio, San Cristóbal, La Romana, Monte Plata no
  foreach k in array inside loop
    perform public.assert_in_service_area(split_part(k, ',', 1)::float8, split_part(k, ',', 2)::float8);
  end loop;
  foreach k in array outside loop
    begin
      perform public.assert_in_service_area(split_part(k, ',', 1)::float8, split_part(k, ',', 2)::float8);
      raise exception 'FALLO: aceptó % fuera de la zona', k;
    exception when sqlstate '22023' then null; end;
  end loop;

  -- Viaje asignado (también prueba que notify_push no rompe el flujo de notificaciones)
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  perform public.set_driver_availability(true, 18.4719, -69.9406);
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  t := public.request_trip('ECONOMICO', 'Piantini', 18.4719, -69.9406, 'Naco', 18.4796, -69.9315, 'CASH');
  topic := 'trip:' || t.id;

  -- Antes de asignar nadie escucha (el viaje está en búsqueda)
  assert not public.can_listen_trip_location(public.trip_topic_id(topic)), 'pasajero escucha antes de asignar';

  select * into r from public.trip_requests where trip_id = t.id and driver_id = drv;
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  t := public.accept_trip_request(r.id);

  -- Conductor: escucha y transmite
  assert public.can_listen_trip_location(public.trip_topic_id(topic)), 'conductor no puede escuchar';
  assert public.can_send_trip_location(public.trip_topic_id(topic)), 'conductor no puede transmitir';
  -- Pasajero: escucha pero no transmite
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  assert public.can_listen_trip_location(public.trip_topic_id(topic)), 'pasajero no puede escuchar';
  assert not public.can_send_trip_location(public.trip_topic_id(topic)), 'pasajero puede transmitir';
  -- Extraño: nada
  perform set_config('request.jwt.claims', json_build_object('sub', pax2, 'role', 'authenticated')::text, true);
  assert not public.can_listen_trip_location(public.trip_topic_id(topic)), 'un extraño puede escuchar';
  assert not public.can_send_trip_location(public.trip_topic_id(topic)), 'un extraño puede transmitir';
  -- Admin: escucha
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  assert public.can_listen_trip_location(public.trip_topic_id(topic)), 'admin no puede escuchar';
  -- Temas mal formados
  assert public.trip_topic_id('trip:abc') is null and public.trip_topic_id('otro:' || t.id) is null, 'tema inválido aceptado';

  -- Al terminar el viaje se cierra el canal
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  perform public.cancel_trip(t.id, 'prueba');
  assert not public.can_listen_trip_location(public.trip_topic_id(topic)), 'canal abierto tras cancelar';

  -- Políticas y trigger instalados
  assert (select count(*) from pg_policies where schemaname = 'realtime' and policyname like 'faxi_trip_location_%') = 2, 'faltan políticas realtime';
  assert exists (select 1 from pg_trigger where tgname = 'notifications_push'), 'falta trigger de push';

  raise notice 'FAXI 005 OK · zona, ubicación privada y push';
end $$;

rollback;
