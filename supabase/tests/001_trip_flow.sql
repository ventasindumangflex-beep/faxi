-- FAXI · Prueba de humo del flujo completo (no deja datos: termina en ROLLBACK).
-- Ejecutar después de migraciones + seed:  psql "$DB_URL" -f supabase/tests/001_trip_flow.sql
-- o pegar en el SQL Editor de Supabase. Debe terminar con NOTICE "FAXI OK".
begin;

do $$
declare
  pax uuid := md5('faxi:p:1')::uuid;      -- María
  pax2 uuid := md5('faxi:p:2')::uuid;     -- Ana
  drv uuid := md5('faxi:d:1')::uuid;      -- Carlos
  t public.trips; r public.trip_requests; p public.payments; n int; v_avg numeric;
  procedure_ok boolean;
begin
  -- Conductor se conecta en Piantini
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  perform public.set_driver_availability(true, 18.4719, -69.9406);

  -- Pasajero cotiza y solicita
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  select count(*) into n from public.quote_trip(18.4719, -69.9406, 18.4733, -69.8840);
  assert n = 5, 'quote_trip debe devolver 5 categorías';
  t := public.request_trip('ECONOMICO', 'Piantini', 18.4719, -69.9406, 'Zona Colonial', 18.4733, -69.8840, 'CARD');
  assert t.status = 'SEARCHING', 'esperado SEARCHING, obtuvo ' || t.status;
  assert t.estimated_fare >= 150, 'tarifa por debajo del mínimo';

  -- Un pasajero no puede pedir dos viajes a la vez
  begin
    perform public.request_trip('ECONOMICO', 'Piantini', 18.4719, -69.9406, 'Naco', 18.4796, -69.9315, 'CASH');
    raise exception 'FALLO: permitió dos viajes activos';
  exception when unique_violation then null; end;

  -- Conductor recibe y acepta
  select * into r from public.trip_requests where trip_id = t.id and driver_id = drv;
  assert found, 'Carlos no recibió la solicitud';
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  t := public.accept_trip_request(r.id);
  assert t.status = 'ASSIGNED' and t.driver_id = drv, 'esperado ASSIGNED';
  assert exists (select 1 from public.notifications where user_id = pax and type = 'TRIP_ASSIGNED'), 'sin notificación al pasajero';

  -- Transición imposible
  begin
    perform public.driver_advance_trip(t.id, 'STARTED');
    raise exception 'FALLO: permitió ASSIGNED → STARTED';
  exception when sqlstate 'FX409' then null; end;

  t := public.driver_advance_trip(t.id, 'ENROUTE');
  t := public.driver_advance_trip(t.id, 'ARRIVED');
  t := public.driver_advance_trip(t.id, 'STARTED');
  t := public.driver_advance_trip(t.id, 'ONTRIP');
  t := public.driver_advance_trip(t.id, 'FINISHED');
  assert t.status = 'FINISHED', 'esperado FINISHED';
  assert t.faxi_commission = round(t.final_fare * 0.20, 2), 'comisión incorrecta';
  assert t.faxi_commission + t.driver_earnings = t.final_fare, 'reparto no cuadra';

  -- RLS: otro pasajero no ve el viaje
  perform set_config('request.jwt.claims', json_build_object('sub', pax2, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into n from public.trips where id = t.id;
  execute 'reset role';
  assert n = 0, 'FALLO RLS: otro pasajero ve el viaje';

  -- Otro pasajero no puede pagarlo
  begin
    perform public.pay_trip(t.id, 'CASH');
    raise exception 'FALLO: otro pasajero pagó el viaje';
  exception when sqlstate 'P0002' then null; end;

  -- Pago simulado: primero falla, luego se aprueba
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  p := public.pay_trip(t.id, 'CARD', 'Visa', '4242', true);
  assert p.status = 'FAILED', 'esperado FAILED';
  p := public.pay_trip(t.id, 'CARD', 'Visa', '4242', false);
  assert p.status = 'PAID' and p.attempts = 2, 'esperado PAID en 2 intentos';
  assert (select status from public.trips where id = t.id) = 'COMPLETED', 'esperado COMPLETED';

  -- Calificación
  perform public.rate_trip(t.id, 5, 'Excelente');
  select rating_avg into v_avg from public.drivers where id = drv;
  assert v_avg between 4.9 and 5, 'promedio del conductor no actualizado';

  -- Vehículo 1999 rechazado / 2000 permitido para evaluación
  begin
    insert into public.vehicles(driver_id, make, model, year, color, plate, category, capacity) values (drv, 'Toyota', 'Corolla', 1999, 'Gris', 'A999001', 'ECONOMICO', 4);
    raise exception 'FALLO: aceptó vehículo 1999';
  exception when check_violation then null; end;
  insert into public.vehicles(driver_id, make, model, year, color, plate, category, capacity) values (drv, 'Toyota', 'Corolla', 2000, 'Gris', 'A999002', 'ECONOMICO', 4);
  assert (select status from public.vehicles where plate = 'A999002') = 'PENDING', '2000 debe quedar PENDING, no aprobado';

  raise notice 'FAXI OK · viaje % · RD$ % · comisión % · conductor %', t.code, t.final_fare, t.faxi_commission, t.driver_earnings;
end $$;

rollback;
