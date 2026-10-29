-- FAXI · 013 · Comisión del 10 %, tarifas nuevas y límite de deuda de RD$1,000 (decisión del dueño y Virgilio, 22-oct-2026)
-- Para 5 km y 12 min: Económico 290 (igual) · Confort 335 · Premium 437 · SUV 484 · Van 536.
-- Los viajes ya terminados conservan su comisión (cada viaje guarda la suya). La auditoría guarda los valores viejos.
-- Se puede correr más de una vez.

-- ───────── 1. Comisión: 10 % para todas las categorías ─────────
do $$ begin
  if exists (select 1 from public.commissions where is_active and (category is not null or rate <> 0.10))
     or not exists (select 1 from public.commissions where is_active and category is null) then
    update public.commissions set is_active = false where is_active;
    insert into public.commissions(category, rate) values (null, 0.10);
  end if;
end $$;

-- ───────── 2. Tarifas (base / por km / por min / mínimo) ─────────
update public.pricing_rules r
   set base_fare = n.base, per_km = n.km, per_min = n.min, minimum_fare = n.minimo
  from (values ('ECONOMICO'::public.vehicle_category,  80, 30, 5, 150),
               ('CONFORT'::public.vehicle_category,   100, 35, 5, 170),
               ('PREMIUM'::public.vehicle_category,   135, 46, 6, 220),
               ('SUV'::public.vehicle_category,       150, 50, 7, 240),
               ('VAN'::public.vehicle_category,       165, 55, 8, 280)) as n(cat, base, km, min, minimo)
 where r.category = n.cat and r.is_active
   and (r.base_fare, r.per_km, r.per_min, r.minimum_fare) is distinct from (n.base::numeric, n.km::numeric, n.min::numeric, n.minimo::numeric);

-- ───────── 3. Límite de deuda: RD$1,000 ─────────
update public.app_settings set value = '1000'
 where key = 'COMMISSION_DEBT_LIMIT' and value is distinct from '1000'::jsonb;

create or replace function public.commission_debt_limit() returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce(public.setting_num('COMMISSION_DEBT_LIMIT'), 1000)
$$;
revoke all on function public.commission_debt_limit() from public, anon, authenticated;
