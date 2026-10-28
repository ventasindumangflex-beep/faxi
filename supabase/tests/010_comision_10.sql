-- FAXI · Prueba de la migración 013 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas.
-- Debe terminar con NOTICE "FAXI 013 OK" (el número es el de la migración, como en las demás pruebas).
begin;

do $$
declare
  esperado jsonb := '{"ECONOMICO": 290, "CONFORT": 335, "PREMIUM": 437, "SUV": 484, "VAN": 536}';
  minimo   jsonb := '{"ECONOMICO": 150, "CONFORT": 170, "PREMIUM": 220, "SUV": 240, "VAN": 280}';
  cat public.vehicle_category; q record; c record; n int;
begin
  -- Una sola comisión activa, del 10 %, para todas las categorías
  select count(*) into n from public.commissions where is_active;
  assert n = 1, 'debe haber una sola comisión activa, hay ' || n;
  foreach cat in array enum_range(null::public.vehicle_category) loop
    select * into c from public.commission_split(1000, cat);
    assert c.rate = 0.10, format('comisión de %s: %s, esperado 0.10', cat, c.rate);
    assert c.faxi_commission = 100 and c.driver_earnings = 900, 'reparto de RD$1,000 incorrecto';
  end loop;

  -- Tarifas: 5 km y 12 min, y el mínimo en un viaje corto
  foreach cat in array enum_range(null::public.vehicle_category) loop
    select * into q from public.quote_fare(cat, 5, 12);
    assert q.total = (esperado->>cat::text)::numeric, format('%s: RD$%s, esperado %s', cat, q.total, esperado->>cat::text);
    select * into q from public.quote_fare(cat, 0.5, 1);
    assert q.total = (minimo->>cat::text)::numeric, format('mínimo de %s: RD$%s, esperado %s', cat, q.total, minimo->>cat::text);
  end loop;

  -- Límite de deuda
  assert public.commission_debt_limit() = 1000, 'el límite de deuda debe ser RD$1,000';

  -- La auditoría guarda la comisión vieja
  assert exists (select 1 from public.audit_logs where entity = 'commissions' and action = 'UPDATE'
                 and (data->'old'->>'rate')::numeric = 0.20 and (data->'new'->>'is_active')::boolean = false),
    'la auditoría no guardó la comisión del 20 %';

  raise notice 'FAXI 013 OK · comisión 10 %% · 290 / 335 / 437 / 484 / 536 · límite RD$1,000';
end $$;

rollback;
