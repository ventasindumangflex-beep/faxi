-- FAXI · 004 · Apps móviles
-- Login por teléfono · borrado de cuenta · push · alta de conductor · cobro en efectivo · zona de servicio · pg_cron · estadísticas admin
-- Requiere 001–003 aplicadas.

-- ───────── 1. Alta desde Supabase Auth (teléfono o correo) ─────────
create or replace function public.handle_new_auth_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_role public.user_role; v_name text; v_phone text;
begin
  v_role := case upper(coalesce(new.raw_user_meta_data->>'role', '')) when 'DRIVER' then 'DRIVER'::public.user_role else 'PASSENGER'::public.user_role end;
  v_name := left(coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
                          nullif(split_part(coalesce(new.email, ''), '@', 1), ''), 'Usuario'), 120);
  if char_length(v_name) < 2 then v_name := 'Usuario'; end if;
  v_phone := coalesce(nullif(trim(new.raw_user_meta_data->>'phone'), ''),
                      case when coalesce(new.phone, '') <> '' then '+' || ltrim(new.phone, '+') end);
  if v_phone is not null and v_phone !~ '^\+?[0-9 ]{10,16}$' then v_phone := null; end if;
  insert into public.users(id, role, full_name, email, phone) values (new.id, v_role, v_name, new.email, v_phone);
  if v_role = 'DRIVER' then insert into public.drivers(id) values (new.id);
  else insert into public.passengers(id) values (new.id); end if;
  return new;
end $$;

-- ───────── 2. users_guard: permite el borrado de la propia cuenta (flag local de transacción) ─────────
create or replace function public.guard_user_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if public.is_system_call() or current_setting('faxi.self_delete', true) = 'on' then return new; end if;
  if new.id <> old.id then raise exception 'No autorizado' using errcode = '42501'; end if;
  if new.role is distinct from old.role and not public.is_super_admin() then
    raise exception 'Solo un SUPER_ADMIN puede cambiar roles' using errcode = '42501';
  end if;
  if (new.is_active is distinct from old.is_active or new.email is distinct from old.email) and not public.is_admin() then
    raise exception 'No autorizado' using errcode = '42501';
  end if;
  return new;
end $$;

-- ───────── 3. Tokens de notificaciones push (Expo) ─────────
create table if not exists public.push_tokens (
  token text primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  platform text not null check (platform in ('ios','android')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists push_tokens_user_idx on public.push_tokens(user_id);
alter table public.push_tokens enable row level security;
create policy push_tokens_own on public.push_tokens for select to authenticated using (user_id = auth.uid());
create trigger push_tokens_updated_at before update on public.push_tokens for each row execute function public.set_updated_at();

create or replace function public.register_push_token(p_token text, p_platform text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'No autenticado' using errcode = '42501'; end if;
  if p_token is null or p_token !~ '^Expo(nent)?PushToken\[.+\]$' then raise exception 'Token inválido' using errcode = '22023'; end if;
  if p_platform not in ('ios','android') then raise exception 'Plataforma inválida' using errcode = '22023'; end if;
  insert into public.push_tokens(token, user_id, platform) values (p_token, auth.uid(), p_platform)
  on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
end $$;

-- ───────── 4. Borrado de cuenta (exigido por Apple y Google) ─────────
-- Anonimiza en lugar de borrar filas: los viajes y pagos se conservan por obligaciones contables.
-- Los archivos de Storage los borra la app antes de llamar a esta función (política docs_owner_delete).
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public, auth as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'No autenticado' using errcode = '42501'; end if;
  if exists (select 1 from public.trips where (passenger_id = v_uid or driver_id = v_uid) and status in
      ('REQUESTED','SEARCHING','ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP','FINISHED','PAYMENT','PAYMENT_FAILED')) then
    raise exception 'Termina o cancela tu viaje activo antes de eliminar la cuenta' using errcode = 'FX409';
  end if;
  perform set_config('faxi.self_delete', 'on', true);
  update public.trip_requests set status = 'CANCELLED', responded_at = now() where driver_id = v_uid and status = 'PENDING';
  update public.drivers set availability = 'OFFLINE', last_lat = null, last_lng = null, last_heading = null,
    status = case when status = 'APPROVED' then 'SUSPENDED'::public.approval_status else status end
  where id = v_uid;
  update public.users set full_name = 'Cuenta eliminada', phone = null, email = null, avatar_path = null, is_active = false where id = v_uid;
  delete from public.push_tokens where user_id = v_uid;
  delete from public.locations where user_id = v_uid;
  update auth.users set phone = null, email = null, raw_user_meta_data = '{}'::jsonb, banned_until = 'infinity' where id = v_uid;
  delete from auth.sessions where user_id = v_uid;
  perform public.log_action('ACCOUNT_DELETED', 'users', v_uid::text);
end $$;

-- ───────── 5. Alta del conductor (datos + vehículo). Los documentos se suben a Storage y se insertan por RLS. ─────────
create or replace function public.driver_submit_application(
  p_full_name text, p_license_number text,
  p_make text, p_model text, p_year int, p_color text, p_plate text, p_category public.vehicle_category, p_capacity int)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); d public.drivers; v_id uuid;
begin
  if public.auth_role() is distinct from 'DRIVER' then raise exception 'Solo conductores' using errcode = '42501'; end if;
  select * into d from public.drivers where id = v_uid for update;
  if d.status in ('APPROVED','SUSPENDED') then
    raise exception 'Tu cuenta ya fue revisada. Contacta a soporte para cambiar tus datos.' using errcode = 'FX409';
  end if;
  p_full_name := trim(p_full_name);
  if coalesce(char_length(p_full_name), 0) < 3 then raise exception 'Escribe tu nombre completo' using errcode = '22023'; end if;
  if coalesce(char_length(trim(p_license_number)), 0) < 5 then raise exception 'Número de licencia inválido' using errcode = '22023'; end if;
  update public.users set full_name = left(p_full_name, 120) where id = v_uid;
  if d.current_vehicle_id is not null and exists (select 1 from public.vehicles where id = d.current_vehicle_id and status in ('PENDING','REJECTED')) then
    update public.vehicles set make = trim(p_make), model = trim(p_model), year = p_year, color = trim(p_color), plate = p_plate,
      category = p_category, capacity = p_capacity, status = 'PENDING', rejection_reason = null
    where id = d.current_vehicle_id returning id into v_id;
  else
    insert into public.vehicles(driver_id, make, model, year, color, plate, category, capacity)
    values (v_uid, trim(p_make), trim(p_model), p_year, trim(p_color), p_plate, p_category, p_capacity)
    returning id into v_id;
  end if;
  update public.drivers set license_number = upper(trim(p_license_number)), current_vehicle_id = v_id,
    status = 'PENDING', rejection_reason = null
  where id = v_uid;
  perform public.log_action('DRIVER_APPLICATION', 'drivers', v_uid::text, jsonb_build_object('vehicle_id', v_id));
  return v_id;
exception when unique_violation then
  raise exception 'La placa o la licencia ya está registrada' using errcode = '23505';
end $$;

-- ───────── 6. Cobro en efectivo confirmado por el conductor ─────────
insert into public.trip_status_transitions(from_status, to_status, actor) values ('FINISHED','PAYMENT','DRIVER') on conflict do nothing;

create or replace function public.driver_confirm_cash(p_trip_id uuid)
returns public.payments language plpgsql security definer set search_path = public as $$
declare t public.trips; p public.payments;
begin
  if public.auth_role() is distinct from 'DRIVER' then raise exception 'Solo conductores' using errcode = '42501'; end if;
  select * into t from public.trips where id = p_trip_id for update;
  if not found or t.driver_id is distinct from auth.uid() then raise exception 'Viaje no encontrado' using errcode = 'P0002'; end if;
  if t.payment_method <> 'CASH' then raise exception 'Este viaje no es en efectivo' using errcode = 'FX409'; end if;
  perform public.assert_transition(t.status, 'PAYMENT', 'DRIVER');
  update public.trips set status = 'PAYMENT' where id = t.id;
  insert into public.payments(trip_id, passenger_id, amount, method, status, provider, provider_ref, attempts, paid_at)
  values (t.id, t.passenger_id, t.final_fare, 'CASH', 'PAID', 'CASH', 'CASH-' || t.code, 1, now())
  on conflict (trip_id) do update set status = 'PAID', method = 'CASH', provider = 'CASH', paid_at = now(), attempts = public.payments.attempts + 1
  returning * into p;
  update public.trips set status = 'COMPLETED', completed_at = now() where id = t.id;
  update public.passengers set trips_count = trips_count + 1 where id = t.passenger_id;
  perform public.push_notification(t.passenger_id, 'TRIP_COMPLETED', 'Viaje completado', 'Gracias por viajar con faxi. Califica a tu conductor.', jsonb_build_object('trip_id', t.id));
  perform public.log_action('PAYMENT_PAID', 'payments', p.id::text, jsonb_build_object('trip_id', t.id, 'method', 'CASH'));
  return p;
end $$;

-- ───────── 7. Zona de servicio: polígono editable desde el admin ([lat, lng]) ─────────
-- Aproximación generosa del Gran Santo Domingo (incluye SDQ y Boca Chica). Ajustar con datos reales.
insert into public.app_settings(key, value, description) values
  ('SERVICE_AREA', '[[18.40,-70.12],[18.56,-70.12],[18.64,-70.00],[18.65,-69.85],[18.60,-69.70],[18.50,-69.54],[18.40,-69.54]]',
   'Polígono [lat,lng] del área de servicio. Vacío = toda la República Dominicana.')
on conflict (key) do nothing;

create or replace function public.assert_in_service_area(p_lat double precision, p_lng double precision) returns void
language plpgsql stable security definer set search_path = public as $$
declare poly jsonb; n int; j int; inside boolean := false; yi float8; xi float8; yj float8; xj float8;
begin
  if p_lat is null or p_lng is null then raise exception 'Ubicación fuera del área de servicio' using errcode = '22023'; end if;
  select value into poly from public.app_settings where key = 'SERVICE_AREA';
  if poly is null or jsonb_typeof(poly) <> 'array' or jsonb_array_length(poly) < 3 then
    if p_lat not between 17.3 and 20.1 or p_lng not between -72.1 and -68.2 then
      raise exception 'Ubicación fuera del área de servicio' using errcode = '22023';
    end if;
    return;
  end if;
  n := jsonb_array_length(poly); j := n - 1;
  for i in 0 .. n - 1 loop
    yi := (poly->i->>0)::float8; xi := (poly->i->>1)::float8;
    yj := (poly->j->>0)::float8; xj := (poly->j->>1)::float8;
    if ((yi > p_lat) <> (yj > p_lat)) and (p_lng < (xj - xi) * (p_lat - yi) / (yj - yi) + xi) then inside := not inside; end if;
    j := i;
  end loop;
  if not inside then raise exception 'Por ahora faxi solo opera en el Gran Santo Domingo' using errcode = '22023'; end if;
end $$;

-- ───────── 8. Vencimientos automáticos cada 15 s ─────────
do $$ begin
  create extension if not exists pg_cron;
  perform cron.schedule('faxi-expire-stale', '15 seconds', 'select public.expire_stale()');
exception when others then
  raise notice 'pg_cron no disponible (%). Actívalo en Dashboard → Database → Extensions y vuelve a correr este bloque.', sqlerrm;
end $$;

-- ───────── 9. Estadísticas del panel ─────────
create or replace function public.admin_dashboard_stats() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_today timestamptz := date_trunc('day', now() at time zone 'America/Santo_Domingo') at time zone 'America/Santo_Domingo';
begin
  if not public.is_admin() then raise exception 'No autorizado' using errcode = '42501'; end if;
  return jsonb_build_object(
    'active_trips',     (select count(*) from public.trips where status in ('ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP')),
    'searching',        (select count(*) from public.trips where status = 'SEARCHING'),
    'drivers_online',   (select count(*) from public.drivers where availability = 'ONLINE'),
    'drivers_busy',     (select count(*) from public.drivers where availability = 'BUSY'),
    'drivers_pending',  (select count(*) from public.drivers where status = 'PENDING' and current_vehicle_id is not null),
    'today_completed',  (select count(*) from public.trips where status = 'COMPLETED' and completed_at >= v_today),
    'today_gross',      (select coalesce(sum(final_fare), 0) from public.trips where status = 'COMPLETED' and completed_at >= v_today),
    'today_commission', (select coalesce(sum(faxi_commission), 0) from public.trips where status = 'COMPLETED' and completed_at >= v_today),
    'today_cancelled',  (select count(*) from public.trips where requested_at >= v_today and (status::text like 'CANCELLED%' or status = 'NO_DRIVER')),
    'open_tickets',     (select count(*) from public.support_tickets where status in ('OPEN','IN_REVIEW')));
end $$;

-- ───────── 10. Storage: el dueño puede borrar sus documentos ─────────
create policy "docs_owner_delete" on storage.objects for delete to authenticated
  using (bucket_id in ('driver-documents','vehicle-documents') and (storage.foldername(name))[1] = auth.uid()::text);

-- ───────── 11. Permisos ─────────
revoke execute on function
  public.register_push_token(text, text), public.delete_my_account(),
  public.driver_submit_application(text, text, text, text, int, text, text, public.vehicle_category, int),
  public.driver_confirm_cash(uuid), public.admin_dashboard_stats()
from public, anon;
grant execute on function
  public.register_push_token(text, text), public.delete_my_account(),
  public.driver_submit_application(text, text, text, text, int, text, text, public.vehicle_category, int),
  public.driver_confirm_cash(uuid), public.admin_dashboard_stats()
to authenticated;
revoke all on public.push_tokens from anon;
