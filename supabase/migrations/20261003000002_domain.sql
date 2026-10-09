-- FAXI · 002 · Lógica de dominio en el servidor (fuente de verdad)
-- Toda mutación de viajes/pagos/calificaciones pasa por estas funciones. Los clientes no tienen UPDATE sobre trips.

-- ───────── Helpers de identidad y configuración ─────────
create or replace function public.auth_role() returns public.user_role
language sql stable security definer set search_path = public as $$
  select role from public.users where id = auth.uid() and is_active
$$;
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.auth_role() in ('ADMIN','SUPER_ADMIN'), false)
$$;
create or replace function public.is_super_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.auth_role() = 'SUPER_ADMIN', false)
$$;
-- true cuando la llamada viene de SQL directo / service_role (seed, migraciones, cron)
create or replace function public.is_system_call() returns boolean
language sql stable as $$
  select coalesce(auth.role(), '') not in ('authenticated','anon')
$$;
create or replace function public.setting_num(p_key text) returns numeric
language sql stable security definer set search_path = public as $$
  select (value #>> '{}')::numeric from public.app_settings where key = p_key
$$;
create or replace function public.setting_text(p_key text) returns text
language sql stable security definer set search_path = public as $$
  select value #>> '{}' from public.app_settings where key = p_key
$$;

create or replace function public.is_trip_party(p_trip uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_admin() or exists (select 1 from public.trips where id = p_trip and (passenger_id = auth.uid() or driver_id = auth.uid()))
$$;
create or replace function public.has_pending_request(p_trip uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.trip_requests where trip_id = p_trip and driver_id = auth.uid() and status = 'PENDING')
$$;
create or replace function public.can_view_user(p_target uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p_target = auth.uid() or public.is_admin()
    or exists (select 1 from public.trips t where (t.passenger_id = auth.uid() and t.driver_id = p_target) or (t.driver_id = auth.uid() and t.passenger_id = p_target))
    or exists (select 1 from public.trip_requests r join public.trips t on t.id = r.trip_id
               where r.driver_id = auth.uid() and r.status = 'PENDING' and t.passenger_id = p_target)
$$;

create or replace function public.push_notification(p_user uuid, p_type text, p_title text, p_body text default null, p_data jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into public.notifications(user_id, type, title, body, data) values (p_user, p_type, p_title, p_body, coalesce(p_data, '{}'));
$$;
create or replace function public.log_action(p_action text, p_entity text, p_entity_id text, p_data jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into public.audit_logs(actor_id, action, entity, entity_id, data) values (auth.uid(), p_action, p_entity, p_entity_id, coalesce(p_data, '{}'));
$$;

create or replace function public.assert_in_service_area(p_lat double precision, p_lng double precision) returns void
language plpgsql immutable as $$
begin
  if p_lat is null or p_lng is null or p_lat not between 17.3 and 20.1 or p_lng not between -72.1 and -68.2 then
    raise exception 'Ubicación fuera del área de servicio' using errcode = '22023';
  end if;
end $$;

create or replace function public.assert_transition(p_from public.trip_status, p_to public.trip_status, p_actor text) returns void
language plpgsql stable set search_path = public as $$
begin
  if not exists (select 1 from public.trip_status_transitions where from_status = p_from and to_status = p_to and actor = p_actor) then
    raise exception 'Transición no permitida: % → % (%)', p_from, p_to, p_actor using errcode = 'FX409';
  end if;
end $$;

create or replace function public.faxi_health() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('ok', true, 'schema', '20261003', 'payment_provider', public.setting_text('PAYMENT_PROVIDER'), 'time', now())
$$;

-- ───────── Triggers ─────────
create or replace function public.handle_new_auth_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_role public.user_role; v_name text; v_phone text;
begin
  -- Desde el registro público solo se puede ser PASSENGER o DRIVER. ADMIN se asigna por un SUPER_ADMIN.
  v_role := case upper(coalesce(new.raw_user_meta_data->>'role', '')) when 'DRIVER' then 'DRIVER'::public.user_role else 'PASSENGER'::public.user_role end;
  v_name := left(coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''), split_part(new.email, '@', 1)), 120);
  if char_length(v_name) < 2 then v_name := 'Usuario'; end if;
  v_phone := nullif(trim(new.raw_user_meta_data->>'phone'), '');
  if v_phone is not null and v_phone !~ '^\+?[0-9 ]{10,16}$' then v_phone := null; end if;
  insert into public.users(id, role, full_name, email, phone) values (new.id, v_role, v_name, new.email, v_phone);
  if v_role = 'DRIVER' then insert into public.drivers(id) values (new.id);
  else insert into public.passengers(id) values (new.id); end if;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_auth_user();

create or replace function public.guard_user_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if public.is_system_call() then return new; end if;
  if new.id <> old.id then raise exception 'No autorizado' using errcode = '42501'; end if;
  if new.role is distinct from old.role and not public.is_super_admin() then
    raise exception 'Solo un SUPER_ADMIN puede cambiar roles' using errcode = '42501';
  end if;
  if (new.is_active is distinct from old.is_active or new.email is distinct from old.email) and not public.is_admin() then
    raise exception 'No autorizado' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger users_guard before update on public.users for each row execute function public.guard_user_update();

create or replace function public.enforce_trip_transition() returns trigger
language plpgsql as $$
begin
  if new.status is distinct from old.status and not exists (
    select 1 from public.trip_status_transitions where from_status = old.status and to_status = new.status) then
    raise exception 'Transición inválida: % → %', old.status, new.status using errcode = 'FX409';
  end if;
  return new;
end $$;
create trigger trips_enforce_transition before update of status on public.trips for each row execute function public.enforce_trip_transition();

-- Vehículo: año mínimo configurable + documentos para aprobar. Año ≥ mínimo NO implica aprobación.
create or replace function public.validate_vehicle() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_min int := coalesce(public.setting_num('MIN_VEHICLE_YEAR'), 2000)::int;
        v_docs boolean := coalesce(public.setting_text('REQUIRE_VEHICLE_DOCUMENTS')::boolean, true);
begin
  new.plate := upper(replace(new.plate, ' ', ''));
  if new.year > extract(year from now())::int + 1 then
    raise exception 'Año de vehículo inválido (%)', new.year using errcode = '23514';
  end if;
  if new.year < v_min and (tg_op = 'INSERT' or new.year is distinct from old.year or new.status = 'APPROVED') then
    raise exception 'Vehículo rechazado: año % inferior al mínimo permitido (%)', new.year, v_min using errcode = '23514';
  end if;
  if new.status = 'APPROVED' and (tg_op = 'INSERT' or old.status is distinct from 'APPROVED') and not public.is_system_call() then
    if not public.is_admin() then raise exception 'No autorizado' using errcode = '42501'; end if;
    if v_docs and (select count(distinct type) from public.vehicle_documents
                   where vehicle_id = new.id and status = 'APPROVED' and type in ('MATRICULA','SEGURO')
                     and (expires_at is null or expires_at >= current_date)) < 2 then
      raise exception 'No se puede aprobar: faltan matrícula y seguro aprobados y vigentes' using errcode = '23514';
    end if;
  end if;
  if tg_op = 'UPDATE' and new.status is distinct from old.status and not public.is_system_call() then
    new.reviewed_by := auth.uid(); new.reviewed_at := now();
  end if;
  return new;
end $$;
create trigger vehicles_validate before insert or update on public.vehicles for each row execute function public.validate_vehicle();

create or replace function public.refresh_driver_rating() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_driver uuid := case when tg_op = 'DELETE' then old.driver_id else new.driver_id end;
begin
  update public.drivers d set rating_avg = s.avg_rating, rating_count = s.cnt
  from (select round(avg(rating)::numeric, 2) as avg_rating, count(*)::int as cnt from public.ratings where driver_id = v_driver) s
  where d.id = v_driver;
  return null;
end $$;
create trigger ratings_refresh_driver after insert or update or delete on public.ratings for each row execute function public.refresh_driver_rating();

create or replace function public.audit_row() returns trigger
language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  r := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  insert into public.audit_logs(actor_id, action, entity, entity_id, data)
  values (auth.uid(), tg_op, tg_table_name, coalesce(r->>'id', r->>'key'),
          jsonb_build_object('old', case when tg_op = 'INSERT' then null else to_jsonb(old) end, 'new', case when tg_op = 'DELETE' then null else to_jsonb(new) end));
  return null;
end $$;
create trigger audit_app_settings after insert or update or delete on public.app_settings for each row execute function public.audit_row();
create trigger audit_pricing_rules after insert or update or delete on public.pricing_rules for each row execute function public.audit_row();
create trigger audit_commissions after insert or update or delete on public.commissions for each row execute function public.audit_row();
create trigger audit_driver_status after update of status on public.drivers for each row execute function public.audit_row();
create trigger audit_vehicle_status after update of status on public.vehicles for each row execute function public.audit_row();
create trigger audit_user_role after update of role, is_active on public.users for each row execute function public.audit_row();

-- ───────── Routing (simulado) ─────────
-- Haversine × 1.35 (factor de calle) y 22 km/h promedio urbano + 2 min. Reemplazable por Directions API.
create or replace function public.route_estimate(o_lat double precision, o_lng double precision, d_lat double precision, d_lng double precision,
  out distance_km numeric, out duration_min numeric)
language plpgsql immutable as $$
declare a double precision; straight double precision;
begin
  a := sin(radians(d_lat - o_lat) / 2) ^ 2 + cos(radians(o_lat)) * cos(radians(d_lat)) * sin(radians(d_lng - o_lng) / 2) ^ 2;
  straight := 2 * 6371 * asin(sqrt(a));
  distance_km := round(greatest(straight * 1.35, 0.5)::numeric, 2);
  duration_min := round(distance_km / 22.0 * 60 + 2, 1);
end $$;

-- ───────── PricingService (servidor) ─────────
-- precio = base + km·por_km + min·por_min + recargos − descuentos, con mínimo por categoría.
create or replace function public.quote_fare(p_category public.vehicle_category, p_distance_km numeric, p_duration_min numeric, p_discount numeric default 0)
returns table(pricing_rule_id uuid, base numeric, distance_part numeric, time_part numeric, surcharge numeric, discount numeric, minimum_adj numeric, total numeric)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare r public.pricing_rules; v_sub numeric; v_raw numeric;
begin
  select * into r from public.pricing_rules pr where pr.category = p_category and pr.is_active;
  if not found then raise exception 'Categoría % no disponible', p_category using errcode = 'P0002'; end if;
  if p_distance_km is null or p_distance_km <= 0 or p_duration_min is null or p_duration_min <= 0 then
    raise exception 'Distancia o duración inválida' using errcode = '22023';
  end if;
  pricing_rule_id := r.id;
  base := r.base_fare;
  distance_part := round(p_distance_km * r.per_km, 2);
  time_part := round(p_duration_min * r.per_min, 2);
  v_sub := base + distance_part + time_part;
  surcharge := round(v_sub * (r.surge_multiplier - 1), 2);
  discount := least(greatest(coalesce(p_discount, 0), 0), v_sub + surcharge);
  v_raw := v_sub + surcharge - discount;
  minimum_adj := greatest(0, r.minimum_fare - v_raw);
  total := round(v_raw + minimum_adj, 0);
  return next;
end $$;

-- ───────── CommissionService (servidor) ─────────
create or replace function public.commission_split(p_gross numeric, p_category public.vehicle_category default null,
  out rate numeric, out faxi_commission numeric, out driver_earnings numeric)
language plpgsql stable security definer set search_path = public as $$
begin
  if p_gross is null or p_gross < 0 then raise exception 'Monto inválido' using errcode = '22023'; end if;
  select c.rate into rate from public.commissions c
  where c.is_active and (c.category = p_category or c.category is null)
  order by (c.category is null) limit 1;
  if rate is null then raise exception 'No hay comisión activa configurada' using errcode = 'P0002'; end if;
  faxi_commission := round(p_gross * rate, 2);
  driver_earnings := p_gross - faxi_commission;
end $$;

create or replace function public.quote_trip(p_origin_lat double precision, p_origin_lng double precision, p_dest_lat double precision, p_dest_lng double precision)
returns table(category public.vehicle_category, display_name text, capacity int, distance_km numeric, duration_min numeric, total numeric, minimum_fare numeric, surcharge numeric)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare e record; r record; q record;
begin
  perform public.assert_in_service_area(p_origin_lat, p_origin_lng);
  perform public.assert_in_service_area(p_dest_lat, p_dest_lng);
  select * into e from public.route_estimate(p_origin_lat, p_origin_lng, p_dest_lat, p_dest_lng);
  for r in select pr.category as cat, pr.display_name as dn, pr.capacity as cap, pr.minimum_fare as mf
           from public.pricing_rules pr where pr.is_active order by pr.sort_order loop
    select * into q from public.quote_fare(r.cat, e.distance_km, e.duration_min);
    category := r.cat; display_name := r.dn; capacity := r.cap; minimum_fare := r.mf;
    distance_km := e.distance_km; duration_min := e.duration_min; total := q.total; surcharge := q.surcharge;
    return next;
  end loop;
end $$;

-- ───────── Despacho ─────────
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
  where d.status = 'APPROVED' and d.availability = 'ONLINE' and v.status = 'APPROVED' and v.category = t.category
    and d.last_lat is not null and e.distance_km <= v_radius
    and not exists (select 1 from public.trip_requests r where r.trip_id = t.id and r.driver_id = d.id)
  order by e.distance_km
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
  where t.status = 'SEARCHING' and t.category = v.category and e.distance_km <= v_radius
    and t.requested_at > now() - make_interval(secs => v_window)
    and not exists (select 1 from public.trip_requests r where r.trip_id = t.id and r.driver_id = d.id)
  on conflict (trip_id, driver_id) do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

-- Vencimientos. Idempotente: lo llaman los clientes mientras esperan y/o pg_cron cada 15 s.
create or replace function public.expire_stale() returns void
language plpgsql security definer set search_path = public as $$
declare r record; v_window int := coalesce(public.setting_num('SEARCH_WINDOW_SECONDS'), 180)::int;
begin
  update public.trip_requests set status = 'EXPIRED' where status = 'PENDING' and expires_at < now();
  for r in select id, passenger_id from public.trips
           where status = 'SEARCHING' and requested_at < now() - make_interval(secs => v_window)
           for update skip locked loop
    update public.trips set status = 'NO_DRIVER' where id = r.id;
    perform public.push_notification(r.passenger_id, 'NO_DRIVER', 'No encontramos conductores disponibles', 'Intenta de nuevo en unos minutos.', jsonb_build_object('trip_id', r.id));
  end loop;
  for r in select id from public.trips where status = 'SEARCHING' loop
    perform public.dispatch_trip(r.id);
  end loop;
end $$;

-- ───────── RPC · Pasajero ─────────
create or replace function public.request_trip(
  p_category public.vehicle_category,
  p_origin_address text, p_origin_lat double precision, p_origin_lng double precision,
  p_dest_address text, p_dest_lat double precision, p_dest_lng double precision,
  p_payment_method public.payment_method default 'CASH')
returns public.trips language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); e record; q record; t public.trips;
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
  insert into public.trips(passenger_id, category, status, origin_address, origin_lat, origin_lng, dest_address, dest_lat, dest_lng,
                           distance_km, duration_min, pricing_rule_id, estimated_fare, payment_method)
  values (v_uid, p_category, 'REQUESTED', left(p_origin_address, 200), p_origin_lat, p_origin_lng, left(p_dest_address, 200), p_dest_lat, p_dest_lng,
          e.distance_km, e.duration_min, q.pricing_rule_id, q.total, p_payment_method)
  returning * into t;
  update public.trips set status = 'SEARCHING' where id = t.id returning * into t;
  perform public.dispatch_trip(t.id);
  perform public.log_action('TRIP_REQUESTED', 'trips', t.id::text, jsonb_build_object('category', p_category, 'estimated_fare', t.estimated_fare));
  return t;
end $$;

create or replace function public.cancel_trip(p_trip_id uuid, p_reason text default null)
returns public.trips language plpgsql security definer set search_path = public as $$
declare t public.trips; v_role public.user_role := public.auth_role(); v_to public.trip_status; v_actor text;
begin
  select * into t from public.trips where id = p_trip_id for update;
  if not found then raise exception 'Viaje no encontrado' using errcode = 'P0002'; end if;
  if v_role = 'PASSENGER' and t.passenger_id = auth.uid() then v_to := 'CANCELLED_BY_PASSENGER'; v_actor := 'PASSENGER';
  elsif v_role = 'DRIVER' and t.driver_id = auth.uid() then v_to := 'CANCELLED_BY_DRIVER'; v_actor := 'DRIVER';
  elsif v_role in ('ADMIN','SUPER_ADMIN') then v_to := 'CANCELLED'; v_actor := 'ADMIN';
  else raise exception 'No autorizado' using errcode = '42501';
  end if;
  perform public.assert_transition(t.status, v_to, v_actor);
  update public.trips set status = v_to, cancel_reason = left(p_reason, 300), cancelled_by = auth.uid(), cancelled_at = now()
  where id = t.id returning * into t;
  update public.trip_requests set status = 'CANCELLED', responded_at = now() where trip_id = t.id and status = 'PENDING';
  if t.driver_id is not null then
    update public.drivers set availability = 'ONLINE' where id = t.driver_id and availability = 'BUSY';
    if v_actor = 'DRIVER' then
      perform public.push_notification(t.passenger_id, 'TRIP_CANCELLED', 'El conductor canceló el viaje', 'Puedes solicitar otro conductor.', jsonb_build_object('trip_id', t.id));
    else
      perform public.push_notification(t.driver_id, 'TRIP_CANCELLED', 'El pasajero canceló el viaje', null, jsonb_build_object('trip_id', t.id));
    end if;
  end if;
  perform public.log_action('TRIP_CANCELLED', 'trips', t.id::text, jsonb_build_object('by', v_actor, 'reason', p_reason));
  return t;
end $$;

-- PaymentService · proveedor MOCK. Con un proveedor real, la confirmación vendrá de un webhook (Edge Function).
create or replace function public.pay_trip(p_trip_id uuid, p_method public.payment_method,
  p_card_brand text default null, p_card_last4 text default null, p_simulate_failure boolean default false)
returns public.payments language plpgsql security definer set search_path = public as $$
declare t public.trips; p public.payments;
begin
  if public.setting_text('PAYMENT_PROVIDER') is distinct from 'MOCK' then
    raise exception 'Pago simulado deshabilitado: el proveedor configurado requiere confirmación del servidor' using errcode = '42501';
  end if;
  select * into t from public.trips where id = p_trip_id for update;
  if not found or t.passenger_id is distinct from auth.uid() then raise exception 'Viaje no encontrado' using errcode = 'P0002'; end if;
  if p_method = 'CARD' then
    if p_card_last4 is null or p_card_last4 !~ '^[0-9]{4}$' then raise exception 'Tarjeta inválida' using errcode = '22023'; end if;
  else
    p_card_last4 := null; p_card_brand := null;
  end if;
  perform public.assert_transition(t.status, 'PAYMENT', 'PASSENGER');
  update public.trips set status = 'PAYMENT', payment_method = p_method where id = t.id;
  insert into public.payments(trip_id, passenger_id, amount, method, status, provider, card_brand, card_last4, attempts)
  values (t.id, t.passenger_id, t.final_fare, p_method, 'PROCESSING', 'MOCK', left(p_card_brand, 20), p_card_last4, 1)
  on conflict (trip_id) do update set method = excluded.method, status = 'PROCESSING', card_brand = excluded.card_brand,
    card_last4 = excluded.card_last4, attempts = public.payments.attempts + 1, failure_reason = null
  returning * into p;
  if p_simulate_failure then
    update public.payments set status = 'FAILED', failure_reason = 'Pago rechazado (simulado)' where id = p.id returning * into p;
    update public.trips set status = 'PAYMENT_FAILED' where id = t.id;
  else
    update public.payments set status = 'PAID', paid_at = now(), provider_ref = 'MOCK-' || substr(md5(random()::text), 1, 10) where id = p.id returning * into p;
    update public.trips set status = 'COMPLETED', completed_at = now() where id = t.id;
    update public.passengers set trips_count = trips_count + 1 where id = t.passenger_id;
    perform public.push_notification(t.driver_id, 'PAYMENT_PAID', 'Pago recibido', null, jsonb_build_object('trip_id', t.id, 'amount', p.amount));
  end if;
  perform public.log_action('PAYMENT_' || p.status, 'payments', p.id::text, jsonb_build_object('trip_id', t.id, 'method', p_method, 'provider', 'MOCK'));
  return p;
end $$;

create or replace function public.rate_trip(p_trip_id uuid, p_rating int, p_comment text default null)
returns public.ratings language plpgsql security definer set search_path = public as $$
declare t public.trips; r public.ratings;
begin
  if p_rating is null or p_rating not between 1 and 5 then raise exception 'La calificación debe ser de 1 a 5' using errcode = '22023'; end if;
  select * into t from public.trips where id = p_trip_id;
  if not found or t.passenger_id is distinct from auth.uid() then raise exception 'Viaje no encontrado' using errcode = 'P0002'; end if;
  if t.status <> 'COMPLETED' then raise exception 'Solo puedes calificar viajes completados' using errcode = 'FX409'; end if;
  insert into public.ratings(trip_id, passenger_id, driver_id, rating, comment)
  values (t.id, t.passenger_id, t.driver_id, p_rating, nullif(left(trim(p_comment), 500), ''))
  returning * into r;
  return r;
exception when unique_violation then
  raise exception 'Este viaje ya fue calificado' using errcode = '23505';
end $$;

-- ───────── RPC · Conductor ─────────
create or replace function public.set_driver_availability(p_online boolean, p_lat double precision default null, p_lng double precision default null)
returns public.drivers language plpgsql security definer set search_path = public as $$
declare d public.drivers;
begin
  if public.auth_role() is distinct from 'DRIVER' then raise exception 'Solo conductores' using errcode = '42501'; end if;
  select * into d from public.drivers where id = auth.uid() for update;
  if p_online then
    if d.status <> 'APPROVED' then raise exception 'Tu cuenta de conductor aún no está aprobada' using errcode = '42501'; end if;
    if not exists (select 1 from public.vehicles where id = d.current_vehicle_id and status = 'APPROVED') then
      raise exception 'No tienes un vehículo aprobado asignado' using errcode = '42501';
    end if;
    if p_lat is not null then perform public.assert_in_service_area(p_lat, p_lng); end if;
    if d.availability = 'BUSY' then return d; end if;
    update public.drivers set availability = 'ONLINE', last_lat = coalesce(p_lat, last_lat), last_lng = coalesce(p_lng, last_lng),
      last_location_at = case when p_lat is not null then now() else last_location_at end
    where id = d.id returning * into d;
    perform public.dispatch_for_driver(d.id);
  else
    if d.availability = 'BUSY' then raise exception 'No puedes desconectarte con un viaje en curso' using errcode = 'FX409'; end if;
    update public.drivers set availability = 'OFFLINE' where id = d.id returning * into d;
    update public.trip_requests set status = 'CANCELLED', responded_at = now() where driver_id = d.id and status = 'PENDING';
  end if;
  return d;
end $$;

create or replace function public.driver_pending_requests()
returns table(request_id uuid, trip_id uuid, trip_code text, expires_at timestamptz, distance_to_pickup_km numeric,
  origin_address text, dest_address text, distance_km numeric, duration_min numeric, estimated_fare numeric,
  estimated_earnings numeric, category public.vehicle_category, passenger_name text, passenger_rating numeric)
language plpgsql volatile security definer set search_path = public as $$
#variable_conflict use_column
begin
  if public.auth_role() is distinct from 'DRIVER' then raise exception 'Solo conductores' using errcode = '42501'; end if;
  perform public.expire_stale();
  perform public.dispatch_for_driver(auth.uid());
  return query
  select r.id, t.id, t.code, r.expires_at, r.distance_to_pickup_km, t.origin_address, t.dest_address, t.distance_km, t.duration_min,
         t.estimated_fare, (public.commission_split(t.estimated_fare, t.category)).driver_earnings, t.category, u.full_name, p.rating_avg
  from public.trip_requests r
  join public.trips t on t.id = r.trip_id
  join public.users u on u.id = t.passenger_id
  join public.passengers p on p.id = t.passenger_id
  where r.driver_id = auth.uid() and r.status = 'PENDING' and t.status = 'SEARCHING'
  order by r.offered_at;
end $$;

create or replace function public.accept_trip_request(p_request_id uuid)
returns public.trips language plpgsql security definer set search_path = public as $$
declare r public.trip_requests; d public.drivers; t public.trips;
begin
  if public.auth_role() is distinct from 'DRIVER' then raise exception 'Solo conductores' using errcode = '42501'; end if;
  select * into r from public.trip_requests where id = p_request_id and driver_id = auth.uid() for update;
  if not found then raise exception 'Solicitud no encontrada' using errcode = 'P0002'; end if;
  if r.status <> 'PENDING' or r.expires_at < now() then raise exception 'Esta solicitud ya no está disponible' using errcode = 'FX409'; end if;
  select * into d from public.drivers where id = auth.uid() for update;
  if d.availability <> 'ONLINE' then raise exception 'Debes estar disponible para aceptar viajes' using errcode = 'FX409'; end if;
  select * into t from public.trips where id = r.trip_id for update;
  if t.status <> 'SEARCHING' then raise exception 'Este viaje ya no está disponible' using errcode = 'FX409'; end if;
  perform public.assert_transition(t.status, 'ASSIGNED', 'DRIVER');
  update public.trips set status = 'ASSIGNED', driver_id = d.id, vehicle_id = d.current_vehicle_id, assigned_at = now()
  where id = t.id returning * into t;
  update public.trip_requests set status = 'ACCEPTED', responded_at = now() where id = r.id;
  update public.trip_requests set status = 'CANCELLED', responded_at = now() where trip_id = t.id and id <> r.id and status = 'PENDING';
  update public.drivers set availability = 'BUSY' where id = d.id;
  perform public.push_notification(t.passenger_id, 'TRIP_ASSIGNED', 'Tu conductor ha aceptado el viaje.', null, jsonb_build_object('trip_id', t.id));
  perform public.log_action('TRIP_ASSIGNED', 'trips', t.id::text, jsonb_build_object('driver_id', d.id));
  return t;
end $$;

create or replace function public.reject_trip_request(p_request_id uuid)
returns public.trip_requests language plpgsql security definer set search_path = public as $$
declare r public.trip_requests;
begin
  update public.trip_requests set status = 'REJECTED', responded_at = now()
  where id = p_request_id and driver_id = auth.uid() and status = 'PENDING' returning * into r;
  if not found then raise exception 'Solicitud no encontrada o ya respondida' using errcode = 'P0002'; end if;
  perform public.dispatch_trip(r.trip_id);
  return r;
end $$;

create or replace function public.driver_advance_trip(p_trip_id uuid, p_to public.trip_status)
returns public.trips language plpgsql security definer set search_path = public as $$
declare t public.trips; q record; c record; v_minutes numeric; v_msg text;
begin
  if public.auth_role() is distinct from 'DRIVER' then raise exception 'Solo conductores' using errcode = '42501'; end if;
  if p_to not in ('ENROUTE','ARRIVED','STARTED','ONTRIP','FINISHED') then raise exception 'Estado no permitido para el conductor' using errcode = 'FX409'; end if;
  select * into t from public.trips where id = p_trip_id for update;
  if not found or t.driver_id is distinct from auth.uid() then raise exception 'Viaje no encontrado' using errcode = 'P0002'; end if;
  perform public.assert_transition(t.status, p_to, 'DRIVER');
  if p_to = 'FINISHED' then
    v_minutes := greatest(t.duration_min, round((extract(epoch from now() - coalesce(t.started_at, now())) / 60.0)::numeric, 1));
    select * into q from public.quote_fare(t.category, t.distance_km, v_minutes);
    select * into c from public.commission_split(q.total, t.category);
    update public.trips set status = 'FINISHED', finished_at = now(), final_fare = q.total,
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

-- LocationProvider (servidor). Solo guarda historial si hay viaje activo; si no, actualiza la última posición.
create or replace function public.update_location(p_lat double precision, p_lng double precision, p_heading real default null,
  p_speed_kmh real default null, p_accuracy_m real default null, p_source public.location_source default 'SIMULATED')
returns void language plpgsql security definer set search_path = public as $$
declare v_trip uuid; v_role public.user_role := public.auth_role();
begin
  if v_role is null then raise exception 'No autenticado' using errcode = '42501'; end if;
  perform public.assert_in_service_area(p_lat, p_lng);
  if v_role = 'DRIVER' then
    update public.drivers set last_lat = p_lat, last_lng = p_lng, last_heading = p_heading, last_location_at = now() where id = auth.uid();
    select id into v_trip from public.trips where driver_id = auth.uid() and status in ('ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP') limit 1;
  else
    select id into v_trip from public.trips where passenger_id = auth.uid() and status in ('ASSIGNED','ENROUTE','ARRIVED') limit 1;
  end if;
  if v_trip is not null then
    insert into public.locations(user_id, trip_id, lat, lng, heading, speed_kmh, accuracy_m, source)
    values (auth.uid(), v_trip, p_lat, p_lng, p_heading, p_speed_kmh, p_accuracy_m, p_source);
  end if;
end $$;

-- ───────── Lectura compuesta para la UI ─────────
create or replace function public.trip_details(p_trip_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare t public.trips; res jsonb;
begin
  select * into t from public.trips where id = p_trip_id;
  if not found or not (public.is_trip_party(t.id) or public.has_pending_request(t.id)) then
    raise exception 'Viaje no encontrado' using errcode = 'P0002';
  end if;
  select jsonb_build_object(
    'trip', to_jsonb(t),
    'passenger', (select jsonb_build_object('id', u.id, 'name', u.full_name, 'rating', p.rating_avg) from public.users u join public.passengers p on p.id = u.id where u.id = t.passenger_id),
    'driver', (select jsonb_build_object('id', u.id, 'name', u.full_name, 'phone', u.phone, 'rating', d.rating_avg, 'trips', d.trips_count,
                 'lat', d.last_lat, 'lng', d.last_lng, 'heading', d.last_heading)
               from public.users u join public.drivers d on d.id = u.id where u.id = t.driver_id),
    'vehicle', (select jsonb_build_object('make', v.make, 'model', v.model, 'year', v.year, 'color', v.color, 'plate', v.plate, 'category', v.category)
                from public.vehicles v where v.id = t.vehicle_id),
    'payment', (select jsonb_build_object('status', pm.status, 'method', pm.method, 'amount', pm.amount, 'card_brand', pm.card_brand, 'card_last4', pm.card_last4, 'paid_at', pm.paid_at)
                from public.payments pm where pm.trip_id = t.id),
    'rating', (select jsonb_build_object('rating', r.rating, 'comment', r.comment) from public.ratings r where r.trip_id = t.id)
  ) into res;
  return res;
end $$;

-- ───────── RPC · Admin ─────────
create or replace function public.admin_set_commission(p_rate numeric, p_category public.vehicle_category default null)
returns public.commissions language plpgsql security definer set search_path = public as $$
declare c public.commissions;
begin
  if not public.is_admin() then raise exception 'No autorizado' using errcode = '42501'; end if;
  if p_rate is null or p_rate < 0 or p_rate > 0.5 then raise exception 'La comisión debe estar entre 0 %% y 50 %%' using errcode = '22023'; end if;
  update public.commissions set is_active = false where is_active and category is not distinct from p_category;
  insert into public.commissions(category, rate, created_by) values (p_category, p_rate, auth.uid()) returning * into c;
  return c;
end $$;
