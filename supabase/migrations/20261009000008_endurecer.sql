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
