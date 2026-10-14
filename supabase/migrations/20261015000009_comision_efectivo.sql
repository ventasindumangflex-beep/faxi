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
