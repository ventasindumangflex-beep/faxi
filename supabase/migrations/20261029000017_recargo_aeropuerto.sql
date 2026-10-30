-- FAXI · 017 · Recargo fijo opcional del aeropuerto (decisión del dueño, 29-oct-2026)
-- Los peajes no se cobran aparte. Una zona de tipo AEROPUERTO (panel → Zonas) puede tener un recargo fijo en pesos.
-- Por defecto 0 = apagado: esta migración no pone ningún monto. Solo un SUPER_ADMIN lo cambia.
-- Si el origen o el destino cae dentro de una zona de aeropuerto activa con recargo > 0, se suma una vez a la cotización
-- (quote_trip lo devuelve aparte en airport_surcharge), al estimado del viaje y al precio final. La comisión va sobre el total.
-- Una zona de aeropuerto NO prohíbe recoger pasajeros (la regla de 200 m es solo para hoteles y taxis turísticos).
-- Se puede correr más de una vez.

-- ───────── 1. Zonas: tipo AEROPUERTO y recargo ─────────
alter table public.restricted_zones drop constraint if exists restricted_zones_kind_check;
alter table public.restricted_zones add constraint restricted_zones_kind_check
  check (kind in ('HOTEL','TAXI_TURISTICO','OTRA','AEROPUERTO'));
alter table public.restricted_zones add column if not exists surcharge numeric(10,2) not null default 0;
alter table public.restricted_zones drop constraint if exists restricted_zones_surcharge_check;
alter table public.restricted_zones add constraint restricted_zones_surcharge_check
  check (surcharge >= 0 and (surcharge = 0 or kind = 'AEROPUERTO'));

create or replace function public.guard_zone_surcharge() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if public.is_system_call() then return new; end if;
  if new.surcharge <> 0 and new.kind <> 'AEROPUERTO' then
    raise exception 'Solo las zonas de aeropuerto pueden tener recargo' using errcode = '22023';
  end if;
  if (tg_op = 'INSERT' and new.surcharge <> 0) or (tg_op = 'UPDATE' and new.surcharge is distinct from old.surcharge) then
    if not public.is_super_admin() then
      raise exception 'Solo un SUPER_ADMIN puede cambiar el recargo del aeropuerto' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'restricted_zones_guard_surcharge' and tgrelid = 'public.restricted_zones'::regclass) then
    create trigger restricted_zones_guard_surcharge before insert or update on public.restricted_zones
      for each row execute function public.guard_zone_surcharge();
  end if;
end $$;

-- La regla de 200 m no aplica a las zonas de aeropuerto (igual que en 012, sin AEROPUERTO)
create or replace function public.assert_pickup_allowed(p_lat double precision, p_lng double precision) returns void
language plpgsql stable security definer set search_path = public as $$
declare z public.restricted_zones;
begin
  select * into z from public.restricted_zones
   where is_active and kind <> 'AEROPUERTO' and public.distance_m(lat, lng, p_lat, p_lng) < radius_m
   order by public.distance_m(lat, lng, p_lat, p_lng) limit 1;
  if found then
    raise exception 'Por normas del INTRANT no podemos recogerte a menos de % m de %. Mueve el punto de recogida un poco más lejos.', z.radius_m, z.name
      using errcode = '22023';
  end if;
end $$;

-- Recargo que corresponde a un viaje (el mayor, una sola vez)
create or replace function public.airport_surcharge(o_lat double precision, o_lng double precision, d_lat double precision, d_lng double precision)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(max(z.surcharge), 0) from public.restricted_zones z
   where z.is_active and z.kind = 'AEROPUERTO' and z.surcharge > 0
     and (public.distance_m(z.lat, z.lng, o_lat, o_lng) < z.radius_m or public.distance_m(z.lat, z.lng, d_lat, d_lng) < z.radius_m)
$$;

alter table public.trips add column if not exists airport_surcharge numeric(10,2) not null default 0 check (airport_surcharge >= 0);

-- ───────── 2. Cotización: el recargo va en el total y aparte ─────────
drop function if exists public.quote_trip(double precision, double precision, double precision, double precision);
create function public.quote_trip(p_origin_lat double precision, p_origin_lng double precision, p_dest_lat double precision, p_dest_lng double precision)
returns table(category public.vehicle_category, display_name text, capacity int, distance_km numeric, duration_min numeric, total numeric,
  minimum_fare numeric, surcharge numeric, airport_surcharge numeric)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare e record; r record; q record; v_airport numeric;
begin
  perform public.assert_in_service_area(p_origin_lat, p_origin_lng);
  perform public.assert_in_service_area(p_dest_lat, p_dest_lng);
  select * into e from public.route_estimate(p_origin_lat, p_origin_lng, p_dest_lat, p_dest_lng);
  v_airport := public.airport_surcharge(p_origin_lat, p_origin_lng, p_dest_lat, p_dest_lng);
  for r in select pr.category as cat, pr.display_name as dn, pr.capacity as cap, pr.minimum_fare as mf
           from public.pricing_rules pr where pr.is_active order by pr.sort_order loop
    select * into q from public.quote_fare(r.cat, e.distance_km, e.duration_min);
    category := r.cat; display_name := r.dn; capacity := r.cap; minimum_fare := r.mf;
    distance_km := e.distance_km; duration_min := e.duration_min; surcharge := q.surcharge;
    airport_surcharge := v_airport; total := q.total + v_airport;
    return next;
  end loop;
end $$;
revoke all on function public.quote_trip(double precision, double precision, double precision, double precision) from public, anon;
grant execute on function public.quote_trip(double precision, double precision, double precision, double precision) to authenticated;

-- ───────── 3. Pedir el viaje: igual que en 002, con el recargo en el estimado ─────────
create or replace function public.request_trip(
  p_category public.vehicle_category,
  p_origin_address text, p_origin_lat double precision, p_origin_lng double precision,
  p_dest_address text, p_dest_lat double precision, p_dest_lng double precision,
  p_payment_method public.payment_method default 'CASH')
returns public.trips language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); e record; q record; t public.trips; v_airport numeric;
begin
  if v_uid is null or public.auth_role() is distinct from 'PASSENGER' then
    raise exception 'Solo los pasajeros pueden solicitar viajes' using errcode = '42501';
  end if;
  p_origin_address := trim(p_origin_address); p_dest_address := trim(p_dest_address);
  if coalesce(char_length(p_origin_address), 0) < 2 or coalesce(char_length(p_dest_address), 0) < 2 then
    raise exception 'Origen y destino son obligatorios' using errcode = '22023';
  end if;
  perform public.assert_in_service_area(p_origin_lat, p_origin_lng);
  perform public.assert_in_service_area(p_dest_lat, p_dest_lng);
  if abs(p_origin_lat - p_dest_lat) < 0.0005 and abs(p_origin_lng - p_dest_lng) < 0.0005 then
    raise exception 'El destino debe ser distinto del origen' using errcode = '22023';
  end if;
  if exists (select 1 from public.trips where passenger_id = v_uid and status in
      ('REQUESTED','SEARCHING','ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP','FINISHED','PAYMENT','PAYMENT_FAILED','DRIVER_TIMEOUT')) then
    raise exception 'Ya tienes un viaje activo' using errcode = '23505';
  end if;
  select * into e from public.route_estimate(p_origin_lat, p_origin_lng, p_dest_lat, p_dest_lng);
  select * into q from public.quote_fare(p_category, e.distance_km, e.duration_min);
  v_airport := public.airport_surcharge(p_origin_lat, p_origin_lng, p_dest_lat, p_dest_lng);
  insert into public.trips(passenger_id, category, status, origin_address, origin_lat, origin_lng, dest_address, dest_lat, dest_lng,
                           distance_km, duration_min, pricing_rule_id, estimated_fare, airport_surcharge, payment_method)
  values (v_uid, p_category, 'REQUESTED', left(p_origin_address, 200), p_origin_lat, p_origin_lng, left(p_dest_address, 200), p_dest_lat, p_dest_lng,
          e.distance_km, e.duration_min, q.pricing_rule_id, q.total + v_airport, v_airport, p_payment_method)
  returning * into t;
  update public.trips set status = 'SEARCHING' where id = t.id returning * into t;
  perform public.dispatch_trip(t.id);
  perform public.log_action('TRIP_REQUESTED', 'trips', t.id::text, jsonb_build_object('category', p_category, 'estimated_fare', t.estimated_fare));
  return t;
end $$;
revoke all on function public.request_trip(public.vehicle_category, text, double precision, double precision, text, double precision, double precision, public.payment_method) from public, anon;
grant execute on function public.request_trip(public.vehicle_category, text, double precision, double precision, text, double precision, double precision, public.payment_method) to authenticated;

-- ───────── 4. Terminar el viaje: igual que en 016, con el recargo en el precio final ─────────
create or replace function public.driver_advance_trip(p_trip_id uuid, p_to public.trip_status)
returns public.trips language plpgsql security definer set search_path = public as $$
declare t public.trips; q record; c record; v_minutes numeric; v_msg text;
        v_wait numeric; v_free numeric; v_per_min numeric; v_wait_charge numeric; v_total numeric;
begin
  if public.auth_role() is distinct from 'DRIVER' then raise exception 'Solo conductores' using errcode = '42501'; end if;
  if p_to not in ('ENROUTE','ARRIVED','STARTED','ONTRIP','FINISHED') then raise exception 'Estado no permitido para el conductor' using errcode = 'FX409'; end if;
  select * into t from public.trips where id = p_trip_id for update;
  if not found or t.driver_id is distinct from auth.uid() then raise exception 'Viaje no encontrado' using errcode = 'P0002'; end if;
  perform public.assert_transition(t.status, p_to, 'DRIVER');
  if p_to = 'FINISHED' then
    v_minutes := greatest(t.duration_min, round((extract(epoch from now() - coalesce(t.started_at, now())) / 60.0)::numeric, 1));
    select * into q from public.quote_fare(t.category, t.distance_km, v_minutes);
    v_wait := case when t.arrived_at is not null and t.started_at is not null
                   then greatest(0, round((extract(epoch from t.started_at - t.arrived_at) / 60.0)::numeric, 1)) else 0 end;
    v_free := greatest(coalesce(public.setting_num('WAIT_FREE_MINUTES'), 5), 0);
    select per_min into v_per_min from public.pricing_rules where id = q.pricing_rule_id;
    v_wait_charge := round(greatest(v_wait - v_free, 0) * coalesce(v_per_min, 0), 2);
    v_total := round(q.total + v_wait_charge + coalesce(t.airport_surcharge, 0), 0);
    select * into c from public.commission_split(v_total, t.category);
    update public.trips set status = 'FINISHED', finished_at = now(), final_fare = v_total,
      wait_minutes = v_wait, wait_charge = v_wait_charge,
      commission_rate = c.rate, faxi_commission = c.faxi_commission, driver_earnings = c.driver_earnings
    where id = t.id returning * into t;
    update public.drivers set availability = 'ONLINE', trips_count = trips_count + 1 where id = t.driver_id;
  else
    update public.trips set status = p_to,
      arrived_at = case when p_to = 'ARRIVED' then now() else arrived_at end,
      started_at = case when p_to = 'STARTED' then now() else started_at end
    where id = t.id returning * into t;
  end if;
  v_msg := case p_to when 'ENROUTE' then 'Tu conductor va en camino.' when 'ARRIVED' then 'Tu conductor ha llegado.'
                     when 'STARTED' then 'Viaje iniciado.' when 'FINISHED' then 'Has llegado a tu destino.' end;
  if v_msg is not null then
    perform public.push_notification(t.passenger_id, 'TRIP_' || p_to, v_msg, null, jsonb_build_object('trip_id', t.id));
  end if;
  return t;
end $$;
revoke all on function public.driver_advance_trip(uuid, public.trip_status) from public, anon;
grant execute on function public.driver_advance_trip(uuid, public.trip_status) to authenticated;

-- ───────── 5. Permisos de las funciones internas ─────────
revoke all on function public.guard_zone_surcharge(),
  public.airport_surcharge(double precision, double precision, double precision, double precision),
  public.assert_pickup_allowed(double precision, double precision)
from public, anon, authenticated;
