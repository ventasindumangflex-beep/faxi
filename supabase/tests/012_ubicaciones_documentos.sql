-- FAXI · Prueba de la migración 015 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas (usa el seed).
-- Debe terminar con NOTICE "FAXI 015 OK".
begin;

do $$
declare
  pax uuid := md5('faxi:p:1')::uuid;
  pax2 uuid := md5('faxi:p:2')::uuid;
  drv uuid := md5('faxi:d:1')::uuid;      -- conductor aprobado del seed, con vehículo aprobado
  adm uuid := (select id from public.users where role = 'ADMIN' and is_active limit 1);
  t public.trips; r public.trip_requests; s public.trip_status; n int; v_msg text; hoy date := public.faxi_today();
begin
  -- ───── a) Historial de ubicaciones: solo mientras el viaje está en curso ─────
  update public.drivers set availability = 'OFFLINE' where id = drv;
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  perform public.set_driver_availability(true, 18.4719, -69.9406);
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  t := public.request_trip('ECONOMICO', 'Piantini', 18.4719, -69.9406, 'Naco', 18.4796, -69.9315, 'CASH');
  select * into r from public.trip_requests where trip_id = t.id and driver_id = drv;
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  t := public.accept_trip_request(r.id);
  perform public.update_location(18.4725, -69.9400, 90, 30, 5, 'GPS');

  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into n from public.locations where trip_id = t.id and user_id = drv;
  execute 'reset role';
  assert n >= 1, 'el pasajero no ve la ubicación del conductor durante el viaje';
  perform set_config('request.jwt.claims', json_build_object('sub', pax2, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into n from public.locations where trip_id = t.id;
  execute 'reset role';
  assert n = 0, 'un extraño ve el historial del viaje';

  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  foreach s in array array['ENROUTE','ARRIVED','STARTED','ONTRIP','FINISHED']::public.trip_status[] loop
    t := public.driver_advance_trip(t.id, s);
  end loop;
  perform public.driver_confirm_cash(t.id);

  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into n from public.locations where trip_id = t.id and user_id = drv;
  execute 'reset role';
  assert n = 0, 'el pasajero sigue viendo la ruta del conductor después del viaje';
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into n from public.locations where trip_id = t.id and user_id = drv;
  execute 'reset role';
  assert n >= 1, 'el conductor dejó de ver sus propias ubicaciones';
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into n from public.locations where trip_id = t.id;
  execute 'reset role';
  assert n >= 1, 'el admin dejó de ver el historial';

  -- ───── b) Documento vencido: no se conecta, sin cambiar su estado ─────
  update public.drivers set availability = 'OFFLINE' where id = drv;
  insert into public.driver_documents(driver_id, type, file_path, status, expires_at, created_at)
  values (drv, 'LICENCIA', drv || '/licencia-vieja.jpg', 'APPROVED', hoy - 1, now() + interval '1 second');
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  begin
    perform public.set_driver_availability(true, 18.4719, -69.9406);
    raise exception 'FALLO: se conectó con la licencia vencida';
  exception when sqlstate 'FX409' then get stacked diagnostics v_msg = message_text; end;
  assert v_msg like 'Se venció tu licencia.%', 'mensaje incorrecto: ' || v_msg;
  assert (select status from public.drivers where id = drv) = 'APPROVED', 'el bloqueo cambió el estado del conductor';
  assert public.expired_documents_message('licencia, antidoping') like 'Se vencieron tus documentos: licencia, antidoping.%', 'mensaje de varios documentos';

  -- Un documento que vence hoy todavía vale; con la licencia nueva aprobada vuelve a conectarse
  insert into public.driver_documents(driver_id, type, file_path, status, expires_at, created_at)
  values (drv, 'LICENCIA', drv || '/licencia-nueva.jpg', 'APPROVED', hoy, now() + interval '2 seconds');
  perform public.set_driver_availability(true, 18.4719, -69.9406);
  assert (select availability from public.drivers where id = drv) = 'ONLINE', 'no se conectó con la licencia al día';

  -- ───── Revisión diaria: desconecta, avisa y deja constancia ─────
  insert into public.driver_documents(driver_id, type, file_path, status, expires_at, created_at)
  values (drv, 'ANTIDOPING', drv || '/antidoping.jpg', 'APPROVED', hoy - 3, now() + interval '3 seconds');
  assert public.check_expired_documents() >= 1, 'la revisión no desconectó a nadie';
  assert (select availability from public.drivers where id = drv) = 'OFFLINE', 'la revisión no desconectó al conductor';
  assert (select status from public.drivers where id = drv) = 'APPROVED', 'la revisión cambió el estado del conductor';
  assert exists (select 1 from public.notifications where user_id = drv and type = 'DOCUMENTS_EXPIRED'), 'sin aviso al conductor';
  assert exists (select 1 from public.audit_logs where action = 'DRIVER_DOCUMENTS_EXPIRED' and entity_id = drv::text), 'sin constancia del conductor en la auditoría';
  assert exists (select 1 from public.audit_logs where action = 'DOCUMENTS_EXPIRY_CHECK'), 'sin constancia de la revisión en la auditoría';
  assert exists (select 1 from cron.job where jobname = 'faxi-documentos-vencidos' and schedule = '0 7 * * *'), 'falta la revisión diaria de las 3:00 a. m.';

  -- ───── Panel: vencidos y por vencer ─────
  insert into public.driver_documents(driver_id, type, file_path, status, expires_at, created_at)
  values (drv, 'CEDULA', drv || '/cedula.jpg', 'APPROVED', hoy + 10, now() + interval '4 seconds'),
         (drv, 'CARNET_INTRANT', drv || '/carnet.jpg', 'APPROVED', hoy + 60, now() + interval '4 seconds');
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  assert exists (select 1 from public.admin_expiring_documents(30) where driver_id = drv and doc_type = 'ANTIDOPING' and expired and days_left = -3), 'el panel no muestra el antidoping vencido';
  assert exists (select 1 from public.admin_expiring_documents(30) where driver_id = drv and doc_type = 'CEDULA' and not expired and days_left = 10), 'el panel no muestra la cédula por vencer';
  assert exists (select 1 from public.admin_expiring_documents(30) where driver_id = drv and doc_type = 'LICENCIA' and not expired and days_left = 0), 'el panel no muestra la licencia que vence hoy';
  assert not exists (select 1 from public.admin_expiring_documents(30) where driver_id = drv and doc_type = 'CARNET_INTRANT'), 'el panel muestra un documento que vence en 60 días';
  assert exists (select 1 from public.admin_expiring_documents(90) where driver_id = drv and doc_type = 'CARNET_INTRANT'), 'con 90 días debe salir el carnet';
  begin
    perform public.admin_expiring_documents(400);
    raise exception 'FALLO: aceptó 400 días';
  exception when sqlstate '22023' then null; end;
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  begin
    perform public.admin_expiring_documents(30);
    raise exception 'FALLO: un pasajero vio los documentos vencidos';
  exception when sqlstate '42501' then null; end;

  raise notice 'FAXI 015 OK · historial solo durante el viaje · documentos vencidos bloquean la conexión · revisión diaria · panel';
end $$;

rollback;
