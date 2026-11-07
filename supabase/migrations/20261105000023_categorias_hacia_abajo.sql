-- FAXI · 023 · Un conductor de categoría más alta también recibe viajes de categorías más bajas (5-nov-2026)
-- Escalera de autos: ECONOMICO < CONFORT < PREMIUM. Un Premium puede tomar un viaje Confort o Económico, un Confort uno Económico.
-- SUV y Van no entran en la escalera (se piden por capacidad): solo atienden su propia categoría.
-- El pasajero paga la categoría que pidió y la comisión se calcula sobre ese precio (no cambia nada del cobro).
-- A igual cercanía se ofrece primero a los conductores de la categoría exacta. Se puede correr más de una vez.

create or replace function public.category_can_serve(p_vehicle public.vehicle_category, p_trip public.vehicle_category) returns boolean
language sql immutable set search_path = public as $$
  select p_vehicle = p_trip
      or (p_vehicle in ('CONFORT', 'PREMIUM') and p_trip in ('ECONOMICO', 'CONFORT')
          and array_position(array['ECONOMICO','CONFORT','PREMIUM'], p_vehicle::text) > array_position(array['ECONOMICO','CONFORT','PREMIUM'], p_trip::text));
$$;
revoke all on function public.category_can_serve(public.vehicle_category, public.vehicle_category) from public, anon;
grant execute on function public.category_can_serve(public.vehicle_category, public.vehicle_category) to authenticated;

create or replace function public.dispatch_trip(p_trip_id uuid) returns int
language plpgsql security definer set search_path = public as $$
declare t public.trips; n int;
        v_ttl int := coalesce(public.setting_num('OFFER_TTL_SECONDS'), 30)::int;
        v_radius numeric := coalesce(public.setting_num('DISPATCH_RADIUS_KM'), 8);
begin
  select * into t from public.trips where id = p_trip_id;
  if not found or t.status <> 'SEARCHING' then return 0; end if;
  insert into public.trip_requests(trip_id, driver_id, distance_to_pickup_km, expires_at)
  select t.id, d.id, e.distance_km, now() + make_interval(secs => v_ttl)
  from public.drivers d
  join public.vehicles v on v.id = d.current_vehicle_id
  cross join lateral public.route_estimate(d.last_lat, d.last_lng, t.origin_lat, t.origin_lng) e
  where d.status = 'APPROVED' and d.availability = 'ONLINE' and v.status = 'APPROVED'
    and public.category_can_serve(v.category, t.category)
    and d.last_lat is not null and e.distance_km <= v_radius
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
begin
  select * into d from public.drivers where id = p_driver_id;
  if not found or d.availability <> 'ONLINE' or d.last_lat is null then return 0; end if;
  select * into v from public.vehicles where id = d.current_vehicle_id and status = 'APPROVED';
  if not found then return 0; end if;
  insert into public.trip_requests(trip_id, driver_id, distance_to_pickup_km, expires_at)
  select t.id, d.id, e.distance_km, now() + make_interval(secs => v_ttl)
  from public.trips t
  cross join lateral public.route_estimate(d.last_lat, d.last_lng, t.origin_lat, t.origin_lng) e
  where t.status = 'SEARCHING' and public.category_can_serve(v.category, t.category) and e.distance_km <= v_radius
    and t.requested_at > now() - make_interval(secs => v_window)
    and not exists (select 1 from public.trip_requests r where r.trip_id = t.id and r.driver_id = d.id)
  on conflict (trip_id, driver_id) do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

-- Mismo permiso que tenían (las llaman otras funciones del servidor, no los usuarios)
revoke all on function public.dispatch_trip(uuid) from public, anon, authenticated;
revoke all on function public.dispatch_for_driver(uuid) from public, anon, authenticated;
