-- FAXI · Prueba de la migración 004 (no deja datos: termina en ROLLBACK). Correr después de 001_trip_flow.sql.
-- Debe terminar con NOTICE "FAXI MÓVIL OK".
begin;

do $$
declare
  pax uuid := md5('faxi:p:1')::uuid;
  drv uuid := md5('faxi:d:1')::uuid;
  adm uuid := (select id from public.users where role = 'SUPER_ADMIN' limit 1);
  newu uuid := gen_random_uuid();
  t public.trips; r public.trip_requests; p public.payments; u public.users; v uuid; s public.trip_status;
begin
  -- Zona de servicio
  perform public.assert_in_service_area(18.4719, -69.9406);   -- Piantini
  perform public.assert_in_service_area(18.4297, -69.6689);   -- SDQ
  begin
    perform public.assert_in_service_area(19.4517, -70.6970); -- Santiago
    raise exception 'FALLO: aceptó Santiago';
  exception when sqlstate '22023' then null; end;

  -- Registro por teléfono (sin correo) como conductor
  insert into auth.users(instance_id, id, aud, role, phone, raw_user_meta_data, created_at, updated_at)
  values ('00000000-0000-0000-0000-000000000000', newu, 'authenticated', 'authenticated', '18095550199', '{"role":"DRIVER"}', now(), now());
  select * into u from public.users where id = newu;
  assert u.role = 'DRIVER' and u.full_name = 'Usuario' and u.phone = '+18095550199', 'alta por teléfono incorrecta';

  -- Alta de conductor
  perform set_config('request.jwt.claims', json_build_object('sub', newu, 'role', 'authenticated')::text, true);
  v := public.driver_submit_application('Pedro Prueba', 'LIC-777001', 'Toyota', 'Corolla', 2018, 'Gris', 'A 777001', 'ECONOMICO', 4);
  assert (select current_vehicle_id from public.drivers where id = newu) = v, 'vehículo no asignado';
  assert (select status from public.vehicles where id = v) = 'PENDING', 'el vehículo debe quedar PENDING';
  assert (select full_name from public.users where id = newu) = 'Pedro Prueba', 'nombre no actualizado';

  -- Push token
  perform public.register_push_token('ExponentPushToken[test-123]', 'android');
  assert exists (select 1 from public.push_tokens where user_id = newu), 'token no guardado';

  -- Borrado de cuenta
  perform public.delete_my_account();
  assert (select is_active from public.users where id = newu) = false, 'cuenta no desactivada';
  assert (select phone from auth.users where id = newu) is null, 'teléfono no eliminado de auth';
  assert not exists (select 1 from public.push_tokens where user_id = newu), 'tokens no borrados';

  -- Viaje en efectivo confirmado por el conductor
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  perform public.set_driver_availability(true, 18.4719, -69.9406);
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  t := public.request_trip('ECONOMICO', 'Piantini', 18.4719, -69.9406, 'Naco', 18.4796, -69.9315, 'CASH');
  select * into r from public.trip_requests where trip_id = t.id and driver_id = drv;
  assert found, 'el conductor no recibió la solicitud';
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  t := public.accept_trip_request(r.id);
  foreach s in array array['ENROUTE','ARRIVED','STARTED','ONTRIP','FINISHED']::public.trip_status[] loop
    t := public.driver_advance_trip(t.id, s);
  end loop;
  p := public.driver_confirm_cash(t.id);
  assert p.status = 'PAID' and p.method = 'CASH' and p.amount = t.final_fare, 'cobro en efectivo incorrecto';
  assert (select status from public.trips where id = t.id) = 'COMPLETED', 'el viaje debe quedar COMPLETED';
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  perform public.rate_trip(t.id, 5, 'Excelente');

  -- Estadísticas admin
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  assert (public.admin_dashboard_stats()->>'today_completed')::int >= 1, 'estadísticas sin el viaje';

  raise notice 'FAXI MÓVIL OK · viaje % · RD$ % en efectivo', t.code, p.amount;
end $$;

rollback;
