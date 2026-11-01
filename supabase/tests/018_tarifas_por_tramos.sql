-- FAXI · Prueba de la migración 021 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas.
-- Debe terminar con NOTICE "FAXI 021 OK".
begin;

do $$
declare q record; p10 numeric; p15 numeric; p20 numeric; p30 numeric; cat public.vehicle_category;
        minimo jsonb := '{"ECONOMICO": 130, "CONFORT": 150, "PREMIUM": 190, "SUV": 210, "VAN": 240}';
begin
  -- Económico: 5 / 10 / 15 / 20 / 30 km con el tiempo de ~24 km/h (minutos enteros)
  select total into q from public.quote_fare('ECONOMICO', 5, 14);   assert q.total = 205, 'Económico 5 km: ' || q.total;
  select total into q from public.quote_fare('ECONOMICO', 10, 26);  assert q.total = 360, 'Económico 10 km: ' || q.total;
  select total into q from public.quote_fare('ECONOMICO', 15, 40);  assert q.total = 485, 'Económico 15 km: ' || q.total;
  select total into q from public.quote_fare('ECONOMICO', 20, 52);  assert q.total = 605, 'Económico 20 km: ' || q.total;
  select total into q from public.quote_fare('ECONOMICO', 30, 78);  assert q.total = 850, 'Económico 30 km: ' || q.total;

  -- Un viaje de ~15 km cuesta entre RD$400 y RD$550 en Económico
  assert (select total from public.quote_fare('ECONOMICO', 15, 38)) between 400 and 550, 'el viaje de 15 km debe costar RD$400–550';

  -- El kilómetro de más es más barato: cada 5 km extra, después del km 10, cuestan menos que los primeros 5 km
  select total into p10 from public.quote_fare('ECONOMICO', 10, 20);
  select total into p15 from public.quote_fare('ECONOMICO', 15, 25);
  select total into p20 from public.quote_fare('ECONOMICO', 20, 30);
  select total into p30 from public.quote_fare('ECONOMICO', 30, 40);
  assert abs((p20 - p15) - (p15 - p10)) <= 1, 'dos tramos largos iguales deben subir igual (salvo el redondeo de 1 peso)';
  assert (p15 - p10) < (select total from public.quote_fare('ECONOMICO', 10, 20)) - (select total from public.quote_fare('ECONOMICO', 5, 20)), 'el tramo largo debe ser más barato que el corto';
  assert p30 > p20 and p20 > p15 and p15 > p10, 'el precio siempre sube con la distancia';

  -- Todas las categorías: crece con la distancia y respeta el mínimo
  foreach cat in array enum_range(null::public.vehicle_category) loop
    assert (select total from public.quote_fare(cat, 12, 30)) > (select total from public.quote_fare(cat, 4, 12)), cat || ': no sube con la distancia';
    select total into q from public.quote_fare(cat, 0.5, 1);
    assert q.total = (minimo->>cat::text)::numeric, format('mínimo de %s: RD$%s', cat, q.total);
  end loop;
  assert (select total from public.quote_fare('CONFORT', 15, 40)) > (select total from public.quote_fare('ECONOMICO', 15, 40)), 'Confort debe costar más que Económico';

  -- Sin tramos (tier_km = 0) vuelve a un solo precio por km
  update public.pricing_rules set tier_km = 0 where category = 'ECONOMICO' and is_active;
  assert (select distance_part from public.quote_fare('ECONOMICO', 20, 30)) = 500, 'sin tramos: 20 km × 25';

  raise notice 'FAXI 021 OK · tarifas por tramos: 5 km 205 · 10 km 360 · 15 km 485 · 20 km 605 · 30 km 850 (Económico)';
end $$;

rollback;
