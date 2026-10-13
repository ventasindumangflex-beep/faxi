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
