-- FAXI · 007 · trip_details sin datos sensibles del conductor fuera del viaje
-- Antes: el pasajero veía la ubicación actual y el teléfono del conductor en cualquier viaje suyo, incluso terminado.
-- Ahora: ubicación y teléfono solo mientras el viaje está en curso (ASSIGNED → ONTRIP); los admins siempre.

create or replace function public.trip_details(p_trip_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare t public.trips; res jsonb; v_live boolean;
begin
  select * into t from public.trips where id = p_trip_id;
  if not found or not (public.is_trip_party(t.id) or public.has_pending_request(t.id)) then
    raise exception 'Viaje no encontrado' using errcode = 'P0002';
  end if;
  v_live := public.is_admin() or t.status in ('ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP');
  select jsonb_build_object(
    'trip', to_jsonb(t),
    'passenger', (select jsonb_build_object('id', u.id, 'name', u.full_name, 'rating', p.rating_avg) from public.users u join public.passengers p on p.id = u.id where u.id = t.passenger_id),
    'driver', (select jsonb_build_object('id', u.id, 'name', u.full_name, 'rating', d.rating_avg, 'trips', d.trips_count,
                 'phone', case when v_live then u.phone end,
                 'lat', case when v_live then d.last_lat end,
                 'lng', case when v_live then d.last_lng end,
                 'heading', case when v_live then d.last_heading end)
               from public.users u join public.drivers d on d.id = u.id where u.id = t.driver_id),
    'vehicle', (select jsonb_build_object('make', v.make, 'model', v.model, 'year', v.year, 'color', v.color, 'plate', v.plate, 'category', v.category)
                from public.vehicles v where v.id = t.vehicle_id),
    'payment', (select jsonb_build_object('status', pm.status, 'method', pm.method, 'amount', pm.amount, 'card_brand', pm.card_brand, 'card_last4', pm.card_last4, 'paid_at', pm.paid_at)
                from public.payments pm where pm.trip_id = t.id),
    'rating', (select jsonb_build_object('rating', r.rating, 'comment', r.comment) from public.ratings r where r.trip_id = t.id)
  ) into res;
  return res;
end $$;
revoke all on function public.trip_details(uuid) from public, anon;
grant execute on function public.trip_details(uuid) to authenticated;

-- Fichas de otros usuarios (users, passengers, drivers — incluye last_lat/last_lng y teléfono):
-- antes, cualquier viaje pasado bastaba para leerlas (y escuchar la ubicación del conductor por Realtime) para siempre.
-- Ahora solo mientras el viaje está en curso. Las apps no leen esas tablas de otros usuarios: usan trip_details.
create or replace function public.can_view_user(p_target uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p_target = auth.uid() or public.is_admin()
    or exists (select 1 from public.trips t
               where ((t.passenger_id = auth.uid() and t.driver_id = p_target) or (t.driver_id = auth.uid() and t.passenger_id = p_target))
                 and t.status in ('ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP','FINISHED','PAYMENT','PAYMENT_FAILED'))
    or exists (select 1 from public.trip_requests r join public.trips t on t.id = r.trip_id
               where r.driver_id = auth.uid() and r.status = 'PENDING' and t.passenger_id = p_target)
$$;
