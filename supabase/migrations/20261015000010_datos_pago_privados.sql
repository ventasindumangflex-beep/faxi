-- FAXI · 010 · Datos de la cuenta donde se paga la comisión: solo para conductores aprobados
-- COMMISSION_PAY_INFO puede llevar un número de cuenta bancaria. Antes lo podía leer cualquier usuario con sesión
-- (app_settings_read = true). Ahora solo lo leen los admins en la tabla, y los conductores APROBADOS por my_commission_status.
-- Se puede correr más de una vez.

-- ───────── 1. Ajustes privados: fuera de la lectura general ─────────
alter policy app_settings_read on public.app_settings
  using (key <> 'COMMISSION_PAY_INFO' or public.is_admin());

update public.app_settings
   set description = 'Dónde paga el conductor la comisión (banco, tipo y número de cuenta, titular). Solo lo ven los admins y los conductores aprobados.'
 where key = 'COMMISSION_PAY_INFO';

-- ───────── 2. my_commission_status: pay_info solo para conductores aprobados ─────────
create or replace function public.my_commission_status() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owed numeric; v_limit numeric; p public.commission_payments; v_approved boolean;
begin
  if public.auth_role() is distinct from 'DRIVER' then raise exception 'Solo conductores' using errcode = '42501'; end if;
  v_owed := public.driver_commission_owed(auth.uid());
  v_limit := public.commission_debt_limit();
  v_approved := exists (select 1 from public.drivers where id = auth.uid() and status = 'APPROVED');
  select * into p from public.commission_payments where driver_id = auth.uid() order by created_at desc limit 1;
  return jsonb_build_object(
    'owed', v_owed, 'limit', v_limit, 'blocked', v_owed > v_limit,
    'pay_day', coalesce(public.setting_text('COMMISSION_PAY_DAY'), 'lunes'),
    'pay_info', case when v_approved then public.setting_text('COMMISSION_PAY_INFO') end,
    'last_payment_amount', p.amount, 'last_payment_at', p.created_at);
end $$;

revoke all on function public.my_commission_status() from public, anon;
grant execute on function public.my_commission_status() to authenticated;
