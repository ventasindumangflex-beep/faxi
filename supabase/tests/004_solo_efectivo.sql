-- FAXI · Prueba de la migración 006 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas (usa el seed).
-- Debe terminar con NOTICE "FAXI 006 OK".
begin;

do $$
declare
  pax uuid := md5('faxi:p:1')::uuid;
  drv uuid := md5('faxi:d:1')::uuid;
  t public.trips; r public.trip_requests; p public.payments; s public.trip_status;
begin
  update public.app_settings set value = '"CASH"' where key = 'PAYMENT_PROVIDER';
  assert public.setting_text('PAYMENT_PROVIDER') = 'CASH', 'no quedó en CASH';

  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  perform public.set_driver_availability(true, 18.4719, -69.9406);
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);

  -- Con tarjeta: rechazado
  begin
    perform public.request_trip('ECONOMICO', 'Piantini', 18.4719, -69.9406, 'Naco', 18.4796, -69.9315, 'CARD');
    raise exception 'FALLO: aceptó un viaje con tarjeta en modo solo efectivo';
  exception when sqlstate '22023' then null; end;

  -- En efectivo: funciona de punta a punta
  t := public.request_trip('ECONOMICO', 'Piantini', 18.4719, -69.9406, 'Naco', 18.4796, -69.9315, 'CASH');
  select * into r from public.trip_requests where trip_id = t.id and driver_id = drv;
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  t := public.accept_trip_request(r.id);
  foreach s in array array['ENROUTE','ARRIVED','STARTED','ONTRIP','FINISHED']::public.trip_status[] loop
    t := public.driver_advance_trip(t.id, s);
  end loop;

  -- El pasajero no puede marcarse el viaje como pagado
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  begin
    perform public.pay_trip(t.id, 'CASH');
    raise exception 'FALLO: el pasajero se marcó el viaje como pagado';
  exception when sqlstate '42501' then null; end;

  -- Solo el conductor confirma el efectivo
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  p := public.driver_confirm_cash(t.id);
  assert p.status = 'PAID' and p.method = 'CASH', 'cobro en efectivo incorrecto';

  raise notice 'FAXI 006 OK · solo efectivo';
end $$;

rollback;
