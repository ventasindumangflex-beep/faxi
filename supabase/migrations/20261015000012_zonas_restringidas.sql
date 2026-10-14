-- FAXI · 012 · Zonas donde no se puede recoger pasajeros (INTRANT)
-- La Normativa Técnica del INTRANT exige 200 m de distancia de la puerta principal de los hoteles del Gran Santo Domingo
-- y de las zonas de taxis turísticos. Un admin agrega cada lugar desde el panel (Zonas) con las coordenadas de Google Maps.
-- request_trip rechaza (22023) un punto de recogida dentro de una zona activa. Sin zonas no cambia nada.
-- Se puede correr más de una vez.

create table if not exists public.restricted_zones (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  kind text not null default 'HOTEL' check (kind in ('HOTEL','TAXI_TURISTICO','OTRA')),
  lat double precision not null check (lat between 17.3 and 20.1),
  lng double precision not null check (lng between -72.1 and -68.2),
  radius_m int not null default 200 check (radius_m between 50 and 2000),
  is_active boolean not null default true,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.restricted_zones enable row level security;
revoke all on public.restricted_zones from anon;
do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'restricted_zones_updated_at' and tgrelid = 'public.restricted_zones'::regclass) then
    create trigger restricted_zones_updated_at before update on public.restricted_zones for each row execute function public.set_updated_at();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'audit_restricted_zones' and tgrelid = 'public.restricted_zones'::regclass) then
    create trigger audit_restricted_zones after insert or update or delete on public.restricted_zones for each row execute function public.audit_row();
  end if;
  -- Lectura para todos los usuarios con sesión (son lugares públicos); escritura solo admins
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'restricted_zones' and policyname = 'restricted_zones_read') then
    create policy restricted_zones_read on public.restricted_zones for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'restricted_zones' and policyname = 'restricted_zones_admin') then
    create policy restricted_zones_admin on public.restricted_zones for all to authenticated using (public.is_admin()) with check (public.is_admin());
  end if;
end $$;

-- Distancia en metros entre dos puntos (fórmula del haversine)
create or replace function public.distance_m(a_lat double precision, a_lng double precision, b_lat double precision, b_lng double precision)
returns double precision language sql immutable set search_path = public as $$
  select 2 * 6371000 * asin(sqrt(
    power(sin(radians(b_lat - a_lat) / 2), 2) +
    cos(radians(a_lat)) * cos(radians(b_lat)) * power(sin(radians(b_lng - a_lng) / 2), 2)))
$$;

create or replace function public.assert_pickup_allowed(p_lat double precision, p_lng double precision) returns void
language plpgsql stable security definer set search_path = public as $$
declare z public.restricted_zones;
begin
  select * into z from public.restricted_zones
   where is_active and public.distance_m(lat, lng, p_lat, p_lng) < radius_m
   order by public.distance_m(lat, lng, p_lat, p_lng) limit 1;
  if found then
    raise exception 'Por normas del INTRANT no podemos recogerte a menos de % m de %. Mueve el punto de recogida un poco más lejos.', z.radius_m, z.name
      using errcode = '22023';
  end if;
end $$;

create or replace function public.check_trip_pickup() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.assert_pickup_allowed(new.origin_lat, new.origin_lng);
  return new;
end $$;
do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'trips_check_pickup' and tgrelid = 'public.trips'::regclass) then
    create trigger trips_check_pickup before insert on public.trips for each row execute function public.check_trip_pickup();
  end if;
end $$;

revoke all on function public.distance_m(double precision, double precision, double precision, double precision),
  public.assert_pickup_allowed(double precision, double precision), public.check_trip_pickup() from public, anon, authenticated;
