-- FAXI · Prueba de la migración 022 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas.
-- Debe terminar con NOTICE "FAXI 022 OK".
begin;

do $$
declare
  pax uuid := md5('faxi:p:1')::uuid;
  oa double precision := 18.4805; ob double precision := -69.7802;   -- Santo Domingo Este
  da double precision := 18.4829; db double precision := -69.9090;   -- Sambil
  est record; rr record; q record; n int;
begin
  delete from public.route_cache where o_lat = round(oa::numeric, 4) and o_lng = round(ob::numeric, 4);

  -- Sin ruta guardada: la estimación de siempre (recta × 1.35, 22 km/h)
  select * into est from public.route_estimate(oa, ob, da, db);
  assert est.distance_km > 10 and est.duration_min > 30, 'estimación base rara';

  -- Ni un pasajero ni nadie con sesión escribe ni lee la caché desde la API
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    insert into public.route_cache(o_lat, o_lng, d_lat, d_lng, distance_km, duration_min, polyline) values (1, 1, 1, 1, 1, 1, 'x');
    raise exception 'FALLO: un usuario escribió en route_cache';
  exception when insufficient_privilege then null; end;
  begin
    perform count(*) from public.route_cache;
    raise exception 'FALLO: un usuario leyó route_cache';
  exception when insufficient_privilege then null; end;
  execute 'reset role';

  -- Con una ruta guardada (la guarda la llave de servicio): el precio sale de la distancia real
  insert into public.route_cache(o_lat, o_lng, d_lat, d_lng, distance_km, duration_min, polyline)
  values (round(oa::numeric, 4), round(ob::numeric, 4), round(da::numeric, 4), round(db::numeric, 4), 15.2, 38.0, '_p~iF~ps|U_ulLnnqC');
  select * into rr from public.route_estimate(oa, ob, da, db);
  assert rr.distance_km = 15.2 and rr.duration_min = 38.0, format('no usó la ruta real: %s km, %s min', rr.distance_km, rr.duration_min);
  assert rr.distance_km < est.distance_km, 'la ruta real debería ser menor que la estimación inflada';
  -- Coordenadas casi iguales (a menos de ~10 m) usan la misma ruta
  select * into rr from public.route_estimate(oa + 0.00001, ob - 0.00001, da, db);
  assert rr.distance_km = 15.2, 'no usó la ruta con coordenadas casi iguales';

  -- El precio del viaje sale de la ruta real: Económico ~RD$480 (rango del dueño 400–550)
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  select * into q from public.quote_trip(oa, ob, da, db) where category = 'ECONOMICO';
  assert q.distance_km = 15.2 and q.duration_min = 38.0, 'quote_trip no usó la ruta real';
  assert q.total between 400 and 550, 'el viaje de 15 km debe costar RD$400–550, costó ' || q.total;

  -- Una ruta de hace más de 6 horas ya no vale
  update public.route_cache set created_at = now() - interval '7 hours' where o_lat = round(oa::numeric, 4);
  select * into rr from public.route_estimate(oa, ob, da, db);
  assert rr.distance_km = est.distance_km, 'usó una ruta vencida';

  -- Valores absurdos no entran
  begin
    insert into public.route_cache(o_lat, o_lng, d_lat, d_lng, distance_km, duration_min, polyline) values (1, 2, 3, 4, 5000, 10, 'x');
    raise exception 'FALLO: aceptó 5000 km';
  exception when check_violation then null; end;

  raise notice 'FAXI 022 OK · la ruta real manda el precio, solo el servidor la escribe, vence a las 6 h y si falta se usa la estimación';
end $$;

rollback;
