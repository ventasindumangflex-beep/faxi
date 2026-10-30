-- FAXI · 016 · Tiempo de espera (decisión del dueño, 29-oct-2026)
-- La espera es el tiempo entre "Llegué" (arrived_at) y "Iniciar" (started_at). Se calcula en el servidor al terminar el viaje.
-- Los primeros WAIT_FREE_MINUTES (5) son gratis; cada minuto de más se cobra con la tarifa por minuto (per_min) de la categoría,
-- en proporción (2.5 min de más = 2.5 × per_min). Se suma al precio final y la comisión se calcula sobre ese total.
-- La cotización no cambia: la espera no se conoce al pedir.
-- WAIT_FREE_MINUTES está en app_settings: desde la 014 solo lo cambia un SUPER_ADMIN.
-- Se puede correr más de una vez.

insert into public.app_settings(key, value, description) values
  ('WAIT_FREE_MINUTES', '5', 'Minutos de espera gratis entre "Llegué" e "Iniciar". Después se cobra la tarifa por minuto de la categoría.')
on conflict (key) do nothing;

alter table public.trips add column if not exists wait_minutes numeric(6,1) check (wait_minutes is null or wait_minutes >= 0);
alter table public.trips add column if not exists wait_charge numeric(10,2) check (wait_charge is null or wait_charge >= 0);

-- Igual que en 002, más la espera al terminar
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
    -- Espera: de "Llegué" a "Iniciar"
    v_wait := case when t.arrived_at is not null and t.started_at is not null
                   then greatest(0, round((extract(epoch from t.started_at - t.arrived_at) / 60.0)::numeric, 1)) else 0 end;
    v_free := greatest(coalesce(public.setting_num('WAIT_FREE_MINUTES'), 5), 0);
    select per_min into v_per_min from public.pricing_rules where id = q.pricing_rule_id;
    v_wait_charge := round(greatest(v_wait - v_free, 0) * coalesce(v_per_min, 0), 2);
    v_total := round(q.total + v_wait_charge, 0);
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
