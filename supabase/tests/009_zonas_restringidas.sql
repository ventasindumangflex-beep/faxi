-- FAXI · Prueba de la migración 012 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas (usa el seed).
-- Debe terminar con NOTICE "FAXI 012 OK".
begin;

do $$
declare
  pax uuid := md5('faxi:p:1')::uuid;
  t public.trips;
begin
  -- Distancia: 0.0027° de latitud ≈ 300 m
  assert public.distance_m(18.4719, -69.9406, 18.4746, -69.9406) between 290 and 310, 'distancia mal calculada';

  -- Hotel de prueba en el punto de recogida
  insert into public.restricted_zones(name, kind, lat, lng) values ('Hotel de prueba', 'HOTEL', 18.4719, -69.9406);

  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  begin
    perform public.request_trip('ECONOMICO', 'Puerta del hotel', 18.4720, -69.9407, 'Naco', 18.4796, -69.9315, 'CASH');
    raise exception 'FALLO: permitió recoger a menos de 200 m del hotel';
  exception when sqlstate '22023' then null; end;

  -- A 300 m sí se puede
  t := public.request_trip('ECONOMICO', 'Esquina a 300 m', 18.4746, -69.9406, 'Naco', 18.4796, -69.9315, 'CASH');
  assert t.status = 'SEARCHING', 'a 300 m del hotel debe permitir el viaje';

  -- Un pasajero no puede crear ni borrar zonas
  execute 'set local role authenticated';
  begin
    insert into public.restricted_zones(name, lat, lng) values ('Zona falsa', 18.48, -69.93);
    raise exception 'FALLO: un pasajero creó una zona';
  exception when insufficient_privilege then null; end;
  execute 'reset role';

  raise notice 'FAXI 012 OK · no se recoge a menos de 200 m de un hotel';
end $$;

rollback;
