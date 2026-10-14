-- FAXI · Prueba de la migración 009 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas (usa el seed).
-- Debe terminar con NOTICE "FAXI 009 OK".
begin;

do $$
declare
  pax uuid := md5('faxi:p:1')::uuid;
  drv uuid := md5('faxi:d:1')::uuid;
  drv2 uuid := md5('faxi:d:2')::uuid;
  adm uuid := md5('faxi:admin')::uuid;
  t public.trips; r public.trip_requests; s public.trip_status; st jsonb; cp public.commission_payments;
  v_base numeric; v_owed numeric; n int;
begin
  -- Límite justo por encima de lo que Carlos ya debe: el próximo viaje lo hace pasarse
  v_base := public.driver_commission_owed(drv);
  update public.app_settings set value = to_jsonb(v_base + 10) where key = 'COMMISSION_DEBT_LIMIT';
  assert public.commission_debt_limit() = v_base + 10, 'límite no configurado';

  -- Por debajo del límite se conecta y hace un viaje en efectivo
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  perform public.set_driver_availability(true, 18.4719, -69.9406);
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  t := public.request_trip('ECONOMICO', 'Piantini', 18.4719, -69.9406, 'Los Prados', 18.4878, -69.9500, 'CASH');
  select * into r from public.trip_requests where trip_id = t.id and driver_id = drv;
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  t := public.accept_trip_request(r.id);
  foreach s in array array['ENROUTE','ARRIVED','STARTED','ONTRIP','FINISHED']::public.trip_status[] loop
    t := public.driver_advance_trip(t.id, s);
  end loop;
  assert t.faxi_commission > 10, 'la comisión del viaje de prueba debe pasar de RD$10';
  assert (select availability from public.drivers where id = drv) = 'ONLINE', 'tras FINISHED debe seguir conectado';
  perform public.driver_confirm_cash(t.id);

  -- Al completar el viaje se pasa del límite: queda desconectado y avisado
  assert (select availability from public.drivers where id = drv) = 'OFFLINE', 'no se desconectó al pasar el límite';
  assert exists (select 1 from public.notifications where user_id = drv and type = 'COMMISSION_LIMIT'), 'sin aviso de límite';
  st := public.my_commission_status();
  v_owed := (st->>'owed')::numeric;
  assert v_owed = v_base + t.faxi_commission, 'deuda mal calculada';
  assert (st->>'blocked')::boolean, 'debería estar bloqueado';
  assert st->>'pay_day' = 'lunes', 'día de pago';

  -- No puede volver a conectarse
  begin
    perform public.set_driver_availability(true, 18.4719, -69.9406);
    raise exception 'FALLO: se conectó con deuda por encima del límite';
  exception when sqlstate 'FX409' then null; end;

  -- No puede registrarse pagos a sí mismo (ni por RPC ni directo en la tabla)
  begin
    perform public.admin_record_commission_payment(drv, v_owed, 'EFECTIVO');
    raise exception 'FALLO: el conductor registró su propio pago';
  exception when sqlstate '42501' then null; end;
  execute 'set local role authenticated';
  begin
    insert into public.commission_payments(driver_id, amount, method) values (drv, 1, 'EFECTIVO');
    raise exception 'FALLO: insertó un pago directo en la tabla';
  exception when insufficient_privilege then null; end;
  execute 'reset role';

  -- El pasajero no ve deudas
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  begin
    perform public.my_commission_status();
    raise exception 'FALLO: el pasajero consultó una deuda';
  exception when sqlstate '42501' then null; end;
  begin
    perform public.admin_commission_balances();
    raise exception 'FALLO: el pasajero vio el listado de deudas';
  exception when sqlstate '42501' then null; end;

  -- El admin valida datos y registra el pago
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  begin
    perform public.admin_record_commission_payment(drv, 0, 'EFECTIVO');
    raise exception 'FALLO: aceptó un pago de 0';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.admin_record_commission_payment(drv, 100, 'CHEQUE');
    raise exception 'FALLO: aceptó una forma de pago inválida';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.admin_record_commission_payment(gen_random_uuid(), 100, 'EFECTIVO');
    raise exception 'FALLO: aceptó un conductor inexistente';
  exception when sqlstate 'P0002' then null; end;
  assert (select blocked from public.admin_commission_balances() where driver_id = drv), 'el admin no lo ve bloqueado';
  cp := public.admin_record_commission_payment(drv, v_owed, 'TRANSFERENCIA', 'BHD 123456');
  assert cp.recorded_by = adm and cp.reference = 'BHD 123456', 'pago mal registrado';
  assert (select owed from public.admin_commission_balances() where driver_id = drv) = 0, 'la deuda no quedó en 0';
  assert exists (select 1 from public.notifications where user_id = drv and type = 'COMMISSION_PAID'), 'sin aviso de pago';

  -- Pagado: vuelve a conectarse y ve solo sus pagos
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  assert not (public.my_commission_status()->>'blocked')::boolean, 'sigue bloqueado tras pagar';
  perform public.set_driver_availability(true, 18.4719, -69.9406);
  assert (select availability from public.drivers where id = drv) = 'ONLINE', 'no se pudo conectar tras pagar';
  execute 'set local role authenticated';
  select count(*) into n from public.commission_payments;
  execute 'reset role';
  assert n = 1, 'el conductor debe ver solo su pago';
  perform set_config('request.jwt.claims', json_build_object('sub', drv2, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into n from public.commission_payments;
  execute 'reset role';
  assert n = 0, 'otro conductor ve pagos ajenos';

  raise notice 'FAXI 009 OK · comisión en efectivo';
end $$;

rollback;
