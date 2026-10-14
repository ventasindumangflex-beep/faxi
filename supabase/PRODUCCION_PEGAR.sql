-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║ SOLO PARA PRODUCCIÓN: faxi (ref opehqsltrzhtsqqlctdg).                     ║
-- ║ Pegar completo en Supabase → faxi → SQL Editor → Run.  Se puede repetir.  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- Hace: migraciones 005 (ubicación en vivo privada, zona real del Gran Santo Domingo, push automático) y
-- 006 (solo efectivo), 007 (datos del conductor solo durante el viaje), 008 (endurecimiento), 009 (comisión en efectivo: pago semanal
-- y bloqueo al deber más de RD$2,000), pone producción en modo solo efectivo y vehículos de 2008 en adelante, deja lista la URL del push
-- y al final muestra la "huella" para comparar con faxi-pruebas.
-- Probado en faxi-pruebas el 15-oct-2026: FAXI OK · FAXI MÓVIL OK · FAXI 005 OK · FAXI 006 OK · FAXI 007 OK · FAXI 009 OK.

-- Seguro: si esta base tiene las cuentas de demostración (@faxi.test) NO es producción.
do $$ begin
  if exists (select 1 from public.users where email like '%@faxi.test') then
    raise exception 'ABORTADO: esta base tiene datos de demostración. Este archivo es solo para producción (faxi).';
  end if;
end $$;

-- ═════════════ Migración 005 ═════════════
-- FAXI · 005 · Ubicación en vivo privada · zona de servicio real · push automático
-- Requiere 001–004 aplicadas. Se puede correr más de una vez.

-- ───────── 1. Ubicación en vivo: canales privados `trip:<uuid>` autorizados por RLS ─────────
-- Solo el pasajero y el conductor del viaje (y los admins) pueden escuchar; solo el conductor puede transmitir,
-- y solo mientras el viaje está en curso. Las apps se unen con { config: { private: true } }.

create or replace function public.trip_topic_id(p_topic text) returns uuid
language sql immutable set search_path = public as $$
  select case when p_topic ~* '^trip:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
              then substr(p_topic, 6)::uuid end
$$;

create or replace function public.can_listen_trip_location(p_trip uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p_trip is not null and (
    public.is_admin() or exists (
      select 1 from public.trips t
      where t.id = p_trip
        and (t.passenger_id = auth.uid() or t.driver_id = auth.uid())
        and t.status in ('ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP')))
$$;

create or replace function public.can_send_trip_location(p_trip uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p_trip is not null and exists (
    select 1 from public.trips t
    where t.id = p_trip and t.driver_id = auth.uid()
      and t.status in ('ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP'))
$$;

revoke all on function public.trip_topic_id(text), public.can_listen_trip_location(uuid), public.can_send_trip_location(uuid) from public, anon;
grant execute on function public.trip_topic_id(text), public.can_listen_trip_location(uuid), public.can_send_trip_location(uuid) to authenticated;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'realtime' and tablename = 'messages' and policyname = 'faxi_trip_location_listen') then
    create policy faxi_trip_location_listen on realtime.messages for select to authenticated
      using (realtime.messages.extension = 'broadcast'
             and public.can_listen_trip_location(public.trip_topic_id(realtime.topic())));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'realtime' and tablename = 'messages' and policyname = 'faxi_trip_location_send') then
    create policy faxi_trip_location_send on realtime.messages for insert to authenticated
      with check (realtime.messages.extension = 'broadcast'
                  and public.can_send_trip_location(public.trip_topic_id(realtime.topic())));
  end if;
end $$;

-- ───────── 2. Zona de servicio: límites reales del Gran Santo Domingo ─────────
-- Distrito Nacional + provincia Santo Domingo (SDE, SDN, SDO, Boca Chica, Los Alcarrizos, Pedro Brand, San Antonio de Guerra),
-- unidos y con ~1 km de margen para el error del GPS. Fuente: geoBoundaries (ADM1 República Dominicana, licencia abierta).
-- Puntos [lat, lng]. Se puede editar desde app_settings sin nueva migración.
insert into public.app_settings(key, value, description) values ('SERVICE_AREA',
  '[[18.4569,-69.8965],[18.4263,-69.9526],[18.4075,-70.0045],[18.4196,-70.0168],[18.442,-70.0184],[18.4533,-70.0264],[18.4564,-70.0735],[18.4706,-70.0867],[18.4879,-70.0899],[18.5245,-70.131],[18.5603,-70.1517],[18.5985,-70.1628],[18.6442,-70.1505],[18.6849,-70.1762],[18.7385,-70.1745],[18.7414,-70.1649],[18.7306,-70.1339],[18.6989,-70.1139],[18.6726,-70.01],[18.6882,-69.9747],[18.706,-69.9663],[18.7124,-69.9504],[18.7108,-69.8849],[18.6629,-69.8306],[18.5909,-69.785],[18.6264,-69.7488],[18.6521,-69.6677],[18.6639,-69.648],[18.6712,-69.6104],[18.6576,-69.5719],[18.6456,-69.5657],[18.6307,-69.5783],[18.5975,-69.5681],[18.5688,-69.5703],[18.5214,-69.604],[18.489,-69.572],[18.4781,-69.5154],[18.4685,-69.5083],[18.4071,-69.5186],[18.4003,-69.5282],[18.446,-69.605],[18.4454,-69.6128],[18.4245,-69.6109],[18.4093,-69.6165],[18.4036,-69.6466],[18.4116,-69.6712],[18.4465,-69.6994],[18.4625,-69.8518]]'::jsonb,
  'Polígono [lat,lng] del Gran Santo Domingo (DN + provincia Santo Domingo, margen ~1 km). Vacío = toda la República Dominicana.')
on conflict (key) do update set value = excluded.value, description = excluded.description;

-- ───────── 3. Push automático: cada fila nueva en notifications llama a la Edge Function send-push ─────────
-- Sustituye al Database Webhook manual. Lee del Vault la URL (faxi_push_url) y el secreto (faxi_push_secret),
-- que se crean abajo; la función send-push valida el secreto con check_push_secret().
-- Si faltan, no hace nada (no rompe la creación de notificaciones).
create extension if not exists pg_net with schema extensions;

create or replace function public.notify_push() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_url text; v_secret text;
begin
  begin
    select decrypted_secret into v_url from vault.decrypted_secrets where name = 'faxi_push_url' limit 1;
    select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'faxi_push_secret' limit 1;
    if v_url is null or v_secret is null then return new; end if;
    perform net.http_post(
      url := v_url,
      body := jsonb_build_object('type', 'INSERT', 'table', 'notifications', 'record', to_jsonb(new)),
      headers := jsonb_build_object('content-type', 'application/json', 'x-faxi-secret', v_secret),
      timeout_milliseconds := 5000);
  exception when others then
    raise warning 'faxi push: %', sqlerrm;   -- nunca bloquear la notificación
  end;
  return new;
end $$;
revoke all on function public.notify_push() from public, anon, authenticated;

do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'notifications_push' and tgrelid = 'public.notifications'::regclass) then
    create trigger notifications_push after insert on public.notifications
      for each row execute function public.notify_push();
  end if;
end $$;

create or replace function public.check_push_secret(p_secret text) returns boolean
language sql stable security definer set search_path = public as $$
  select p_secret is not null and exists (
    select 1 from vault.decrypted_secrets where name = 'faxi_push_secret' and decrypted_secret = p_secret)
$$;
revoke all on function public.check_push_secret(text) from public, anon, authenticated;
grant execute on function public.check_push_secret(text) to service_role;

-- Secreto del Vault (aleatorio, nunca sale de la base).
do $$ begin
  if not exists (select 1 from vault.secrets where name = 'faxi_push_secret') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(24), 'hex'), 'faxi_push_secret',
      'Secreto entre el trigger notifications_push y la Edge Function send-push');
  end if;
end $$;
-- La URL depende del proyecto; crearla una vez por proyecto (ver supabase/PRODUCCION_PEGAR.sql):
--   select vault.create_secret('https://<ref>.supabase.co/functions/v1/send-push', 'faxi_push_url');

-- ═════════════ Migración 006 ═════════════
-- FAXI · 006 · Modo "solo efectivo" para producción
-- Con PAYMENT_PROVIDER = "CASH":
--   · pay_trip (pago simulado desde el teléfono) queda bloqueado (ya lo hacía con cualquier valor distinto de MOCK);
--   · no se pueden crear viajes con otro método que no sea efectivo, así el conductor siempre puede confirmar el cobro.
-- faxi-pruebas sigue en MOCK para que las pruebas 001 y 002 corran igual. Producción se pone en CASH (PRODUCCION_PEGAR.sql).

create or replace function public.enforce_cash_only() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if public.setting_text('PAYMENT_PROVIDER') = 'CASH' and new.payment_method is distinct from 'CASH' then
    raise exception 'Por ahora faxi solo acepta pagos en efectivo' using errcode = '22023';
  end if;
  return new;
end $$;
revoke all on function public.enforce_cash_only() from public, anon, authenticated;

do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'trips_cash_only' and tgrelid = 'public.trips'::regclass) then
    create trigger trips_cash_only before insert or update of payment_method on public.trips
      for each row execute function public.enforce_cash_only();
  end if;
end $$;

update public.app_settings
   set description = 'MOCK = pagos simulados (solo pruebas). CASH = solo efectivo, confirmado por el conductor (producción). Cambiar al integrar pasarela.'
 where key = 'PAYMENT_PROVIDER';

-- ═════════════ Migración 007 ═════════════
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

-- ═════════════ Migración 008 ═════════════
-- FAXI · 008 · Endurecimiento sugerido por el asesor de seguridad de Supabase
-- 1. search_path fijo en las funciones que no lo tenían.
-- 2. expire_stale solo lo corre pg_cron (como postgres); las apps no lo llaman.
-- 3. faxi_health ya no es público (anon) y no revela el proveedor de pagos.

alter function public.enforce_trip_transition() set search_path = public;
alter function public.set_updated_at() set search_path = public;
alter function public.is_system_call() set search_path = public;
do $$ declare f regprocedure; begin
  for f in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'route_estimate' loop
    execute format('alter function %s set search_path = public', f);
  end loop;
end $$;

revoke execute on function public.expire_stale() from public, anon, authenticated;

create or replace function public.faxi_health() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('ok', true, 'time', now())
$$;
revoke execute on function public.faxi_health() from public, anon;
grant execute on function public.faxi_health() to authenticated;

-- ═════════════ Migración 009 ═════════════
-- FAXI · 009 · Comisión de los viajes en efectivo: deuda del conductor, pagos semanales y bloqueo por límite
-- El pasajero paga todo en efectivo al conductor; el conductor le debe a faxi la comisión (trips.faxi_commission).
-- Deuda = comisión de sus viajes COMPLETED en efectivo − pagos registrados por un admin.
-- Si la deuda pasa de COMMISSION_DEBT_LIMIT (RD$2,000), el conductor no puede conectarse y, si está conectado,
-- se desconecta al completar el viaje que lo hace pasar del límite. Al registrar su pago vuelve a poder conectarse.
-- Se puede correr más de una vez.

-- ───────── 1. Configuración (editable desde app_settings sin nueva migración) ─────────
insert into public.app_settings(key, value, description) values
  ('COMMISSION_DEBT_LIMIT', '2000', 'Deuda máxima de comisión (RD$) antes de bloquear al conductor. Al pasarla no puede conectarse.'),
  ('COMMISSION_PAY_DAY', '"lunes"', 'Día de la semana en que el conductor paga la comisión de la semana anterior.'),
  ('COMMISSION_PAY_INFO', '"Transferencia o depósito a la cuenta de faxi. Envía el comprobante por WhatsApp a soporte."',
   'Cómo paga el conductor la comisión (se muestra en la app del conductor).')
on conflict (key) do nothing;

-- ───────── 2. Pagos de comisión (solo los registra un admin) ─────────
create table if not exists public.commission_payments (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers(id) on delete cascade,
  amount numeric(10,2) not null check (amount > 0 and amount <= 100000),
  method text not null check (method in ('TRANSFERENCIA','DEPOSITO','EFECTIVO')),
  reference text check (char_length(reference) <= 100),
  recorded_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists commission_payments_driver_idx on public.commission_payments(driver_id, created_at desc);
alter table public.commission_payments enable row level security;
revoke all on public.commission_payments from anon;
revoke insert, update, delete, truncate on public.commission_payments from authenticated;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'commission_payments' and policyname = 'commission_payments_read') then
    create policy commission_payments_read on public.commission_payments for select to authenticated
      using (driver_id = auth.uid() or public.is_admin());
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'audit_commission_payments' and tgrelid = 'public.commission_payments'::regclass) then
    create trigger audit_commission_payments after insert or update or delete on public.commission_payments
      for each row execute function public.audit_row();
  end if;
end $$;

-- ───────── 3. Cálculo de la deuda (interno) ─────────
create or replace function public.driver_commission_owed(p_driver uuid) returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce((select sum(faxi_commission) from public.trips
                   where driver_id = p_driver and status = 'COMPLETED' and payment_method = 'CASH'), 0)
       - coalesce((select sum(amount) from public.commission_payments where driver_id = p_driver), 0)
$$;
create or replace function public.commission_debt_limit() returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce(public.setting_num('COMMISSION_DEBT_LIMIT'), 2000)
$$;
create or replace function public.fmt_rd(p numeric) returns text
language sql immutable set search_path = public as $$
  select 'RD$' || to_char(coalesce(p, 0), 'FM999,999,990.00')
$$;

-- ───────── 4. Bloqueo: no conectarse con deuda por encima del límite ─────────
create or replace function public.guard_driver_debt() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_owed numeric; v_limit numeric;
begin
  if new.availability = 'ONLINE' and old.availability = 'OFFLINE' and not public.is_system_call() then
    v_owed := public.driver_commission_owed(new.id);
    v_limit := public.commission_debt_limit();
    if v_owed > v_limit then
      raise exception 'Debes % de comisión a faxi (el límite es %). Paga para volver a conectarte.',
        public.fmt_rd(v_owed), public.fmt_rd(v_limit) using errcode = 'FX409';
    end if;
  end if;
  return new;
end $$;
do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'drivers_guard_debt' and tgrelid = 'public.drivers'::regclass) then
    create trigger drivers_guard_debt before update of availability on public.drivers
      for each row execute function public.guard_driver_debt();
  end if;
end $$;

-- Al completar un viaje en efectivo que deja la deuda por encima del límite: desconectar y avisar.
create or replace function public.check_driver_debt_after_trip() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_owed numeric; v_limit numeric;
begin
  if new.status = 'COMPLETED' and old.status is distinct from 'COMPLETED' and new.payment_method = 'CASH' and new.driver_id is not null then
    v_owed := public.driver_commission_owed(new.driver_id);
    v_limit := public.commission_debt_limit();
    if v_owed > v_limit then
      update public.drivers set availability = 'OFFLINE' where id = new.driver_id and availability = 'ONLINE';
      update public.trip_requests set status = 'CANCELLED', responded_at = now() where driver_id = new.driver_id and status = 'PENDING';
      perform public.push_notification(new.driver_id, 'COMMISSION_LIMIT', 'Paga tu comisión para seguir',
        format('Debes %s de comisión (el límite es %s). Te desconectamos hasta que pagues.', public.fmt_rd(v_owed), public.fmt_rd(v_limit)),
        jsonb_build_object('owed', v_owed));
    end if;
  end if;
  return null;
end $$;
do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'trips_check_driver_debt' and tgrelid = 'public.trips'::regclass) then
    create trigger trips_check_driver_debt after update of status on public.trips
      for each row execute function public.check_driver_debt_after_trip();
  end if;
end $$;

-- ───────── 5. RPC · Conductor: su deuda ─────────
create or replace function public.my_commission_status() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owed numeric; v_limit numeric; p public.commission_payments;
begin
  if public.auth_role() is distinct from 'DRIVER' then raise exception 'Solo conductores' using errcode = '42501'; end if;
  v_owed := public.driver_commission_owed(auth.uid());
  v_limit := public.commission_debt_limit();
  select * into p from public.commission_payments where driver_id = auth.uid() order by created_at desc limit 1;
  return jsonb_build_object(
    'owed', v_owed, 'limit', v_limit, 'blocked', v_owed > v_limit,
    'pay_day', coalesce(public.setting_text('COMMISSION_PAY_DAY'), 'lunes'),
    'pay_info', public.setting_text('COMMISSION_PAY_INFO'),
    'last_payment_amount', p.amount, 'last_payment_at', p.created_at);
end $$;

-- ───────── 6. RPC · Admin: deudas y registro de pagos ─────────
create or replace function public.admin_commission_balances()
returns table(driver_id uuid, full_name text, phone text, driver_status public.approval_status, availability public.driver_availability,
  owed numeric, last_payment_at timestamptz, blocked boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_limit numeric := public.commission_debt_limit();
begin
  if not public.is_admin() then raise exception 'No autorizado' using errcode = '42501'; end if;
  return query
  select d.id, u.full_name, u.phone, d.status, d.availability, x.owed,
         (select max(cp.created_at) from public.commission_payments cp where cp.driver_id = d.id), x.owed > v_limit
  from public.drivers d
  join public.users u on u.id = d.id
  cross join lateral (select public.driver_commission_owed(d.id) as owed) x
  where d.status = 'APPROVED' or x.owed <> 0
  order by x.owed desc, u.full_name;
end $$;

create or replace function public.admin_record_commission_payment(p_driver_id uuid, p_amount numeric, p_method text, p_reference text default null)
returns public.commission_payments language plpgsql security definer set search_path = public as $$
declare cp public.commission_payments; v_owed numeric;
begin
  if not public.is_admin() then raise exception 'No autorizado' using errcode = '42501'; end if;
  if p_amount is null or p_amount <= 0 or p_amount > 100000 then
    raise exception 'El monto debe ser mayor que 0 y hasta RD$100,000' using errcode = '22023';
  end if;
  if p_method is null or p_method not in ('TRANSFERENCIA','DEPOSITO','EFECTIVO') then
    raise exception 'Forma de pago inválida' using errcode = '22023';
  end if;
  if not exists (select 1 from public.drivers where id = p_driver_id) then
    raise exception 'Conductor no encontrado' using errcode = 'P0002';
  end if;
  insert into public.commission_payments(driver_id, amount, method, reference, recorded_by)
  values (p_driver_id, round(p_amount, 2), p_method, nullif(left(trim(p_reference), 100), ''), auth.uid())
  returning * into cp;
  v_owed := public.driver_commission_owed(p_driver_id);
  perform public.push_notification(p_driver_id, 'COMMISSION_PAID', 'Pago de comisión recibido',
    format('Registramos tu pago de %s. Ahora debes %s.', public.fmt_rd(cp.amount), public.fmt_rd(greatest(v_owed, 0))),
    jsonb_build_object('payment_id', cp.id, 'owed', v_owed));
  return cp;
end $$;

-- ───────── 7. Permisos ─────────
revoke all on function
  public.driver_commission_owed(uuid), public.commission_debt_limit(), public.fmt_rd(numeric),
  public.guard_driver_debt(), public.check_driver_debt_after_trip()
from public, anon, authenticated;
revoke all on function
  public.my_commission_status(), public.admin_commission_balances(), public.admin_record_commission_payment(uuid, numeric, text, text)
from public, anon;
grant execute on function
  public.my_commission_status(), public.admin_commission_balances(), public.admin_record_commission_payment(uuid, numeric, text, text)
to authenticated;

-- Producción: solo efectivo (el pasajero no puede marcarse pagos; el conductor confirma el cobro)
update public.app_settings set value = '"CASH"' where key = 'PAYMENT_PROVIDER';
-- Producción: vehículos de 2008 en adelante (faxi-pruebas sigue en 2000 para que FAXI OK corra igual)
update public.app_settings set value = '2008' where key = 'MIN_VEHICLE_YEAR';

-- ═════════════ URL del push en producción ═════════════
do $$ begin
  if not exists (select 1 from vault.secrets where name = 'faxi_push_url') then
    perform vault.create_secret('https://opehqsltrzhtsqqlctdg.supabase.co/functions/v1/send-push', 'faxi_push_url', 'URL de la Edge Function send-push');
  end if;
end $$;

-- ═════════════ Huella: debe coincidir con faxi-pruebas ═════════════
-- Esperado (faxi-pruebas, 15-oct-2026, con 009): tablas 21 · funciones 59 · politicas 44 · triggers 32 · indices 54 · cron 1
--   h_tablas 0d7f36 · h_funciones 9b0b05 · h_politicas c5c2d4 · h_triggers c5c0fe · h_indices e9402f · vault 2 · proveedor CASH · año 2008
with
 t as (select string_agg(table_name, ',' order by table_name) s, count(*) n from information_schema.tables where table_schema='public' and table_type='BASE TABLE'),
 f as (select string_agg(p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')', ',' order by p.proname, pg_get_function_identity_arguments(p.oid)) s, count(*) n from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where ns.nspname='public'),
 pol as (select string_agg(schemaname||'.'||tablename||'.'||policyname, ',' order by schemaname, tablename, policyname) s, count(*) n from pg_policies where schemaname in ('public','storage','realtime')),
 tr as (select string_agg(c.relname||'.'||tg.tgname, ',' order by c.relname, tg.tgname) s, count(*) n from pg_trigger tg join pg_class c on c.oid=tg.tgrelid join pg_namespace ns on ns.oid=c.relnamespace where not tg.tgisinternal and ns.nspname='public'),
 ix as (select string_agg(indexname, ',' order by indexname) s, count(*) n from pg_indexes where schemaname='public'),
 cr as (select count(*) n from cron.job)
select t.n tablas, f.n funciones, pol.n politicas, tr.n triggers, ix.n indices, cr.n cron,
  left(md5(t.s),6) h_tablas, left(md5(f.s),6) h_funciones, left(md5(pol.s),6) h_politicas, left(md5(tr.s),6) h_triggers, left(md5(ix.s),6) h_indices,
  (select count(*) from vault.secrets where name in ('faxi_push_url','faxi_push_secret')) vault,
  public.setting_text('PAYMENT_PROVIDER') proveedor,
  public.setting_text('MIN_VEHICLE_YEAR') año
from t,f,pol,tr,ix,cr;
