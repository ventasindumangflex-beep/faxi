-- FAXI · 025 · El despacho ya no calcula la distancia a todos los conductores conectados (26-nov-2026)
--
-- EL PROBLEMA (medido en faxi-pruebas)
--   dispatch_trip hacía `cross join lateral route_estimate(...)` contra TODOS los conductores
--   en línea, y recién después descartaba los lejanos. El costo crecía con cada conductor:
--     1 conductor en línea  → request_trip 2,75 ms
--    21 conductores en línea → request_trip 9,67 ms   (~0,35 ms por conductor)
--   Con 300 conductores conectados serían >100 ms por viaje pedido, y subiendo.
--
-- LA SOLUCIÓN
--   Antes de calcular distancias, descartar por un recuadro de latitud/longitud que un
--   índice puede resolver. Solo a los que caen dentro se les calcula la distancia real.
--
-- POR QUÉ NO CAMBIA A QUIÉN SE LE OFRECE EL VIAJE
--   El recuadro usa el MISMO radio que el filtro de distancia. La distancia por carretera
--   (y también la estimación straight*1.35) nunca es menor que la distancia en línea recta,
--   así que todo conductor que antes pasaba el filtro cae dentro del recuadro. No se pierde
--   ninguno; solo se dejan de calcular los que de todas formas se iban a descartar.
--
-- Se puede correr más de una vez.

-- Índice parcial: solo las filas que el despacho mira (conductores conectados con posición).
create index if not exists drivers_online_pos_idx
  on public.drivers(last_lat, last_lng)
  where availability = 'ONLINE' and last_lat is not null;

create or replace function public.dispatch_trip(p_trip_id uuid) returns int
language plpgsql security definer set search_path = public as $$
declare t public.trips; n int;
        v_ttl int := coalesce(public.setting_num('OFFER_TTL_SECONDS'), 30)::int;
        v_radius numeric := coalesce(public.setting_num('DISPATCH_RADIUS_KM'), 8);
        v_dlat double precision;
        v_dlng double precision;
begin
  select * into t from public.trips where id = p_trip_id;
  if not found or t.status <> 'SEARCHING' then return 0; end if;

  -- Medio lado del recuadro, en grados. 1° de latitud ≈ 111,045 km.
  v_dlat := v_radius / 111.045;
  v_dlng := v_radius / (111.045 * greatest(cos(radians(t.origin_lat)), 0.01));

  insert into public.trip_requests(trip_id, driver_id, distance_to_pickup_km, expires_at)
  select t.id, d.id, e.distance_km, now() + make_interval(secs => v_ttl)
  from public.drivers d
  join public.vehicles v on v.id = d.current_vehicle_id
  cross join lateral public.route_estimate(d.last_lat, d.last_lng, t.origin_lat, t.origin_lng) e
  where d.status = 'APPROVED' and d.availability = 'ONLINE' and v.status = 'APPROVED'
    and d.last_lat is not null
    and d.last_lat between t.origin_lat - v_dlat and t.origin_lat + v_dlat
    and d.last_lng between t.origin_lng - v_dlng and t.origin_lng + v_dlng
    and public.category_can_serve(v.category, t.category)
    and e.distance_km <= v_radius
    and not exists (select 1 from public.trip_requests r where r.trip_id = t.id and r.driver_id = d.id)
  order by (v.category <> t.category), e.distance_km
  limit 5
  on conflict (trip_id, driver_id) do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function public.dispatch_for_driver(p_driver_id uuid) returns int
language plpgsql security definer set search_path = public as $$
declare d public.drivers; v public.vehicles; n int;
        v_ttl int := coalesce(public.setting_num('OFFER_TTL_SECONDS'), 30)::int;
        v_radius numeric := coalesce(public.setting_num('DISPATCH_RADIUS_KM'), 8);
        v_window int := coalesce(public.setting_num('SEARCH_WINDOW_SECONDS'), 180)::int;
        v_dlat double precision;
        v_dlng double precision;
begin
  select * into d from public.drivers where id = p_driver_id;
  if not found or d.availability <> 'ONLINE' or d.last_lat is null then return 0; end if;
  select * into v from public.vehicles where id = d.current_vehicle_id and status = 'APPROVED';
  if not found then return 0; end if;

  v_dlat := v_radius / 111.045;
  v_dlng := v_radius / (111.045 * greatest(cos(radians(d.last_lat)), 0.01));

  insert into public.trip_requests(trip_id, driver_id, distance_to_pickup_km, expires_at)
  select t.id, d.id, e.distance_km, now() + make_interval(secs => v_ttl)
  from public.trips t
  cross join lateral public.route_estimate(d.last_lat, d.last_lng, t.origin_lat, t.origin_lng) e
  where t.status = 'SEARCHING'
    and t.origin_lat between d.last_lat - v_dlat and d.last_lat + v_dlat
    and t.origin_lng between d.last_lng - v_dlng and d.last_lng + v_dlng
    and public.category_can_serve(v.category, t.category) and e.distance_km <= v_radius
    and t.requested_at > now() - make_interval(secs => v_window)
    and not exists (select 1 from public.trip_requests r where r.trip_id = t.id and r.driver_id = d.id)
  on conflict (trip_id, driver_id) do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

-- Mismos permisos que tenían: las llaman otras funciones del servidor, no los usuarios.
revoke all on function public.dispatch_trip(uuid) from public, anon, authenticated;
revoke all on function public.dispatch_for_driver(uuid) from public, anon, authenticated;
