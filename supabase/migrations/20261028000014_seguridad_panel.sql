-- FAXI · 014 · Seguridad del panel (revisión del 27-oct-2026)
-- a) Aprobar a un conductor exige sus 6 documentos aprobados y vigentes (como matrícula y seguro para el vehículo).
-- b) Los ajustes del sistema (app_settings, incluidas la cuenta de pago y el día de pago) solo los cambia un SUPER_ADMIN.
--    Los admins los siguen viendo.
-- c) Nadie borra tarifas, comisiones ni ajustes desde las apps o la API (se desactivan, no se borran).
-- d) Solo un SUPER_ADMIN cambia o desactiva a otro ADMIN o SUPER_ADMIN.
-- e) Un SUPER_ADMIN puede anular un pago de comisión, con motivo; queda en la auditoría.
-- f) Un conductor aprobado (o suspendido) no puede cambiar su nombre; solo un admin.
-- Pendiente (no se hace aquí): avisar o suspender cuando un documento se vence.
-- Se puede correr más de una vez.

-- ───────── a) Documentos del conductor para aprobarlo ─────────
create or replace function public.guard_driver_approval() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_missing text;
begin
  if new.status = 'APPROVED' and old.status is distinct from 'APPROVED' and not public.is_system_call() then
    select string_agg(x.label, ', ' order by x.ord) into v_missing
      from (values (1, 'FOTO_PERFIL', 'foto de perfil'), (2, 'LICENCIA', 'licencia'), (3, 'CEDULA', 'cédula'),
                   (4, 'BUENA_CONDUCTA', 'buena conducta'), (5, 'CARNET_INTRANT', 'carnet del INTRANT'),
                   (6, 'ANTIDOPING', 'antidoping')) as x(ord, doc, label)
     where not exists (select 1 from public.driver_documents d
                        where d.driver_id = new.id and d.type::text = x.doc and d.status = 'APPROVED'
                          and (d.expires_at is null or d.expires_at >= current_date));
    if v_missing is not null then
      raise exception 'No se puede aprobar al conductor: falta aprobar (o está vencido): %.', v_missing using errcode = 'FX409';
    end if;
  end if;
  return new;
end $$;
revoke all on function public.guard_driver_approval() from public, anon, authenticated;

do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'drivers_guard_approval' and tgrelid = 'public.drivers'::regclass) then
    create trigger drivers_guard_approval before update of status on public.drivers
      for each row execute function public.guard_driver_approval();
  end if;
end $$;

-- ───────── b) Ajustes del sistema: escritura solo SUPER_ADMIN (la lectura no cambia) ─────────
alter policy app_settings_admin on public.app_settings
  using (public.is_super_admin()) with check (public.is_super_admin());

-- ───────── c) Sin borrar tarifas, comisiones ni ajustes ─────────
revoke delete, truncate on public.app_settings, public.pricing_rules, public.commissions from anon, authenticated, service_role;

-- ───────── d) y f) Protección de administradores y del nombre del conductor ─────────
create or replace function public.guard_user_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if public.is_system_call() or current_setting('faxi.self_delete', true) = 'on' then return new; end if;
  if new.id <> old.id then raise exception 'No autorizado' using errcode = '42501'; end if;
  if new.role is distinct from old.role and not public.is_super_admin() then
    raise exception 'Solo un SUPER_ADMIN puede cambiar roles' using errcode = '42501';
  end if;
  if old.role in ('ADMIN','SUPER_ADMIN') and old.id is distinct from auth.uid() and not public.is_super_admin()
     and row(new.*) is distinct from row(old.*) then
    raise exception 'Solo un SUPER_ADMIN puede cambiar o desactivar a un administrador' using errcode = '42501';
  end if;
  if (new.is_active is distinct from old.is_active or new.email is distinct from old.email) and not public.is_admin() then
    raise exception 'No autorizado' using errcode = '42501';
  end if;
  if new.full_name is distinct from old.full_name and not public.is_admin()
     and exists (select 1 from public.drivers d where d.id = new.id and d.status in ('APPROVED','SUSPENDED')) then
    raise exception 'Tu nombre ya fue verificado. Para cambiarlo, escribe a soporte.' using errcode = '42501';
  end if;
  return new;
end $$;

-- ───────── e) Anular un pago de comisión ─────────
alter table public.commission_payments add column if not exists voided_at timestamptz;
alter table public.commission_payments add column if not exists voided_by uuid references public.users(id) on delete set null;
alter table public.commission_payments add column if not exists void_reason text
  check (void_reason is null or char_length(void_reason) between 5 and 300);

-- La deuda no cuenta los pagos anulados
create or replace function public.driver_commission_owed(p_driver uuid) returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce((select sum(faxi_commission) from public.trips
                   where driver_id = p_driver and status = 'COMPLETED' and payment_method = 'CASH'), 0)
       - coalesce((select sum(amount) from public.commission_payments where driver_id = p_driver and voided_at is null), 0)
$$;
revoke all on function public.driver_commission_owed(uuid) from public, anon, authenticated;

-- Igual que en 010, sin contar pagos anulados como "último pago"
create or replace function public.my_commission_status() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owed numeric; v_limit numeric; p public.commission_payments; v_approved boolean;
begin
  if public.auth_role() is distinct from 'DRIVER' then raise exception 'Solo conductores' using errcode = '42501'; end if;
  v_owed := public.driver_commission_owed(auth.uid());
  v_limit := public.commission_debt_limit();
  v_approved := exists (select 1 from public.drivers where id = auth.uid() and status = 'APPROVED');
  select * into p from public.commission_payments where driver_id = auth.uid() and voided_at is null order by created_at desc limit 1;
  return jsonb_build_object(
    'owed', v_owed, 'limit', v_limit, 'blocked', v_owed > v_limit,
    'pay_day', coalesce(public.setting_text('COMMISSION_PAY_DAY'), 'lunes'),
    'pay_info', case when v_approved then public.setting_text('COMMISSION_PAY_INFO') end,
    'last_payment_amount', p.amount, 'last_payment_at', p.created_at);
end $$;
revoke all on function public.my_commission_status() from public, anon;
grant execute on function public.my_commission_status() to authenticated;

-- Igual que en 009, sin contar pagos anulados como "último pago"
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
         (select max(cp.created_at) from public.commission_payments cp where cp.driver_id = d.id and cp.voided_at is null), x.owed > v_limit
  from public.drivers d
  join public.users u on u.id = d.id
  cross join lateral (select public.driver_commission_owed(d.id) as owed) x
  where d.status = 'APPROVED' or x.owed <> 0
  order by x.owed desc, u.full_name;
end $$;
revoke all on function public.admin_commission_balances() from public, anon;
grant execute on function public.admin_commission_balances() to authenticated;

create or replace function public.admin_void_commission_payment(p_payment_id uuid, p_reason text)
returns public.commission_payments language plpgsql security definer set search_path = public as $$
declare cp public.commission_payments; v_owed numeric; v_limit numeric;
begin
  if not public.is_super_admin() then
    raise exception 'Solo un SUPER_ADMIN puede anular pagos de comisión' using errcode = '42501';
  end if;
  p_reason := trim(p_reason);
  if coalesce(char_length(p_reason), 0) < 5 then
    raise exception 'Escribe el motivo de la anulación (al menos 5 letras)' using errcode = '22023';
  end if;
  select * into cp from public.commission_payments where id = p_payment_id for update;
  if not found then raise exception 'Pago no encontrado' using errcode = 'P0002'; end if;
  if cp.voided_at is not null then raise exception 'Este pago ya fue anulado' using errcode = 'FX409'; end if;
  update public.commission_payments set voided_at = now(), voided_by = auth.uid(), void_reason = left(p_reason, 300)
   where id = cp.id returning * into cp;
  -- Si al anular vuelve a pasar del límite, se desconecta (si está esperando viajes)
  v_owed := public.driver_commission_owed(cp.driver_id);
  v_limit := public.commission_debt_limit();
  if v_owed > v_limit then
    update public.drivers set availability = 'OFFLINE' where id = cp.driver_id and availability = 'ONLINE';
    update public.trip_requests set status = 'CANCELLED', responded_at = now() where driver_id = cp.driver_id and status = 'PENDING';
  end if;
  perform public.push_notification(cp.driver_id, 'COMMISSION_PAYMENT_VOIDED', 'Pago de comisión anulado',
    format('Anulamos tu pago de %s. Motivo: %s. Ahora debes %s.', public.fmt_rd(cp.amount), cp.void_reason, public.fmt_rd(greatest(v_owed, 0))),
    jsonb_build_object('payment_id', cp.id, 'owed', v_owed));
  perform public.log_action('COMMISSION_PAYMENT_VOIDED', 'commission_payments', cp.id::text,
    jsonb_build_object('driver_id', cp.driver_id, 'amount', cp.amount, 'reason', cp.void_reason));
  return cp;
end $$;
revoke all on function public.admin_void_commission_payment(uuid, text) from public, anon;
grant execute on function public.admin_void_commission_payment(uuid, text) to authenticated;
