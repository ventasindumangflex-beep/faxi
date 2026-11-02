-- FAXI · 022 · Rutas reales por las calles (decisión del dueño, 1-nov-2026)
-- La Edge Function `route` consulta la Routes API de Google con una clave que solo vive en el servidor y guarda el resultado
-- (distancia, tiempo y línea de la ruta) en route_cache. Las apps NO escriben ahí: solo la llave de servicio.
-- route_estimate() (que usan quote_trip, request_trip y el despacho) usa la ruta guardada si existe y es de las últimas 6 horas;
-- si no, sigue con la estimación de siempre (línea recta × 1.35 a 22 km/h). Así el precio sale de la distancia real
-- y, si Google falla, la app sigue funcionando. Se puede correr más de una vez.

create table if not exists public.route_cache (
  id bigint generated always as identity primary key,
  o_lat numeric(8,4) not null, o_lng numeric(9,4) not null,
  d_lat numeric(8,4) not null, d_lng numeric(9,4) not null,
  distance_km numeric(7,2) not null check (distance_km >= 0.1 and distance_km <= 300),
  duration_min numeric(7,1) not null check (duration_min > 0 and duration_min <= 1000),
  polyline text not null check (char_length(polyline) between 2 and 100000),
  created_at timestamptz not null default now(),
  unique (o_lat, o_lng, d_lat, d_lng)
);
alter table public.route_cache enable row level security;          -- sin políticas: solo la llave de servicio
revoke all on public.route_cache from anon, authenticated;
create index if not exists route_cache_created_idx on public.route_cache (created_at);

-- Misma firma que antes (ahora STABLE porque lee la tabla y SECURITY DEFINER para poder leerla)
create or replace function public.route_estimate(o_lat double precision, o_lng double precision, d_lat double precision, d_lng double precision,
  out distance_km numeric, out duration_min numeric)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_variable
declare a double precision; straight double precision; c record;
begin
  select rc.distance_km as dk, rc.duration_min as dm into c from public.route_cache rc
   where rc.o_lat = round(o_lat::numeric, 4) and rc.o_lng = round(o_lng::numeric, 4)
     and rc.d_lat = round(d_lat::numeric, 4) and rc.d_lng = round(d_lng::numeric, 4)
     and rc.created_at > now() - interval '6 hours';
  if found then
    distance_km := c.dk; duration_min := c.dm;
    return;
  end if;
  a := sin(radians(d_lat - o_lat) / 2) ^ 2 + cos(radians(o_lat)) * cos(radians(d_lat)) * sin(radians(d_lng - o_lng) / 2) ^ 2;
  straight := 2 * 6371 * asin(sqrt(a));
  distance_km := round(greatest(straight * 1.35, 0.5)::numeric, 2);
  duration_min := round(distance_km / 22.0 * 60 + 2, 1);
end $$;
revoke all on function public.route_estimate(double precision, double precision, double precision, double precision) from public, anon;
grant execute on function public.route_estimate(double precision, double precision, double precision, double precision) to authenticated;

-- Las rutas viejas no hacen falta: se borran las de más de 2 días, todos los días a las 3:15 a. m. de RD (07:15 UTC)
do $$ begin
  if not exists (select 1 from cron.job where jobname = 'faxi-limpiar-rutas') then
    perform cron.schedule('faxi-limpiar-rutas', '15 7 * * *', $q$delete from public.route_cache where created_at < now() - interval '2 days'$q$);
  end if;
exception when others then
  raise notice 'pg_cron no disponible (%). Programa el borrado de route_cache cada día a las 07:15 UTC.', sqlerrm;
end $$;
