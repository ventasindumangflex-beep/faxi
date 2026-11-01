-- FAXI · 021 · Tarifas por tramos de distancia, como Uber / inDrive (decisión del dueño, 1-nov-2026)
-- Hasta tier_km kilómetros se cobra per_km por km; de ahí en adelante, per_km_long (más barato). Así un viaje largo no se dispara.
-- precio = base + (km hasta tier_km × per_km) + (km de más × per_km_long) + (minutos × per_min), con el mínimo de la categoría.
-- tier_km = 0 apaga los tramos (un solo per_km para todo el viaje, como antes).
-- Referencia (Económico, tiempo ≈ 24 km/h): 5 km ≈ RD$205 · 10 km ≈ 360 · 15 km ≈ 485 · 20 km ≈ 605 · 30 km ≈ 850.
-- La comisión (10 %), el recargo del aeropuerto y la espera no cambian: se calculan igual sobre este precio. Se puede correr más de una vez.

-- ───────── 1. Columnas del segundo tramo ─────────
alter table public.pricing_rules add column if not exists tier_km numeric(6,2) not null default 0 check (tier_km >= 0);
alter table public.pricing_rules add column if not exists per_km_long numeric(10,2) check (per_km_long is null or per_km_long >= 0);

-- ───────── 2. El cálculo: igual que antes, con la parte de distancia por tramos ─────────
create or replace function public.quote_fare(p_category public.vehicle_category, p_distance_km numeric, p_duration_min numeric, p_discount numeric default 0)
returns table(pricing_rule_id uuid, base numeric, distance_part numeric, time_part numeric, surcharge numeric, discount numeric, minimum_adj numeric, total numeric)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare r public.pricing_rules; v_sub numeric; v_raw numeric;
begin
  select * into r from public.pricing_rules pr where pr.category = p_category and pr.is_active;
  if not found then raise exception 'Categoría % no disponible', p_category using errcode = 'P0002'; end if;
  if p_distance_km is null or p_distance_km <= 0 or p_duration_min is null or p_duration_min <= 0 then
    raise exception 'Distancia o duración inválida' using errcode = '22023';
  end if;
  pricing_rule_id := r.id;
  base := r.base_fare;
  if r.tier_km > 0 and r.per_km_long is not null then
    distance_part := round(least(p_distance_km, r.tier_km) * r.per_km + greatest(p_distance_km - r.tier_km, 0) * r.per_km_long, 2);
  else
    distance_part := round(p_distance_km * r.per_km, 2);
  end if;
  time_part := round(p_duration_min * r.per_min, 2);
  v_sub := base + distance_part + time_part;
  surcharge := round(v_sub * (r.surge_multiplier - 1), 2);
  discount := least(greatest(coalesce(p_discount, 0), 0), v_sub + surcharge);
  v_raw := v_sub + surcharge - discount;
  minimum_adj := greatest(0, r.minimum_fare - v_raw);
  total := round(v_raw + minimum_adj, 0);
  return next;
end $$;
revoke all on function public.quote_fare(public.vehicle_category, numeric, numeric, numeric) from public, anon;
grant execute on function public.quote_fare(public.vehicle_category, numeric, numeric, numeric) to authenticated;

-- ───────── 3. Tarifas nuevas (base / km hasta el km 10 / km de más / minuto / mínimo) ─────────
update public.pricing_rules r
   set base_fare = n.base, per_km = n.km, tier_km = 10, per_km_long = n.km_long, per_min = n.min, minimum_fare = n.minimo
  from (values ('ECONOMICO'::public.vehicle_category, 45, 25, 18, 2.5, 130),
               ('CONFORT'::public.vehicle_category,   52, 29, 21, 3,   150),
               ('PREMIUM'::public.vehicle_category,   68, 37, 27, 4,   190),
               ('SUV'::public.vehicle_category,       75, 42, 30, 4,   210),
               ('VAN'::public.vehicle_category,       83, 46, 33, 5,   240)) as n(cat, base, km, km_long, min, minimo)
 where r.category = n.cat and r.is_active
   and (r.base_fare, r.per_km, r.tier_km, r.per_km_long, r.per_min, r.minimum_fare)
       is distinct from (n.base::numeric, n.km::numeric, 10::numeric, n.km_long::numeric, n.min::numeric, n.minimo::numeric);
