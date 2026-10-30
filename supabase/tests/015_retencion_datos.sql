-- FAXI · Prueba de la migración 018 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas (usa el seed).
-- Debe terminar con NOTICE "FAXI 018 OK". Requiere 015 (faxi_today) y 018.
begin;

do $$
declare
  pax uuid := md5('faxi:p:1')::uuid;
  drv uuid := md5('faxi:d:1')::uuid;
  drv2 uuid := md5('faxi:d:2')::uuid;
  adm uuid := (select id from public.users where role = 'ADMIN' and is_active limit 1);
  v_veh uuid := (select current_vehicle_id from public.drivers where id = md5('faxi:d:1')::uuid);
  t_old uuid; t_new uuid; r jsonb; n int; hoy date := public.faxi_today(); v_owed numeric;
begin
  v_owed := public.driver_commission_owed(drv);
  -- Plazos por defecto
  assert public.setting_num('RETENTION_LOCATIONS_DAYS') = 90, 'ubicaciones: 90 días';
  assert public.setting_num('RETENTION_NOTIFICATIONS_DAYS') = 90, 'avisos: 90 días';
  assert public.setting_num('RETENTION_TRIP_REQUESTS_DAYS') = 90, 'ofertas: 90 días';
  assert public.setting_num('RETENTION_REJECTED_DOCS_DAYS') = 365, 'documentos rechazados: 1 año';
  assert public.setting_num('RETENTION_TRIPS_ANONYMIZE_DAYS') = 3650, 'viajes: 10 años';

  -- Un plazo inválido no entra (menos de 30 días, texto, decimales)
  begin
    update public.app_settings set value = '5' where key = 'RETENTION_LOCATIONS_DAYS';
    raise exception 'FALLO: aceptó un plazo de 5 días';
  exception when sqlstate '22023' then null; end;
  begin
    update public.app_settings set value = '"mucho"' where key = 'RETENTION_LOCATIONS_DAYS';
    raise exception 'FALLO: aceptó un plazo de texto';
  exception when sqlstate '22023' then null; end;
  begin
    update public.app_settings set value = '45.5' where key = 'RETENTION_LOCATIONS_DAYS';
    raise exception 'FALLO: aceptó un plazo con decimales';
  exception when sqlstate '22023' then null; end;

  -- Un ADMIN no cambia los plazos
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  update public.app_settings set value = '30' where key = 'RETENTION_LOCATIONS_DAYS';
  get diagnostics n = row_count;
  execute 'reset role';
  assert n = 0, 'un ADMIN cambió un plazo de retención';

  -- Nadie, ni un usuario con sesión, corre la limpieza a mano
  assert not has_function_privilege('authenticated', 'public.run_data_retention()', 'execute'), 'authenticated puede correr la limpieza';
  assert not has_function_privilege('anon', 'public.run_data_retention()', 'execute'), 'anon puede correr la limpieza';
  assert exists (select 1 from cron.job where jobname = 'faxi-retencion-datos' and schedule = '0 7 * * *'), 'falta la revisión diaria de las 3:00 a. m.';

  -- Datos de prueba: uno vencido y uno vigente de cada cosa (zonas apagadas para que no estorben al insertar viajes)
  update public.restricted_zones set is_active = false;
  insert into public.trips(passenger_id, driver_id, vehicle_id, category, status, origin_address, origin_lat, origin_lng, dest_address, dest_lat, dest_lng,
                           distance_km, duration_min, estimated_fare, final_fare, commission_rate, faxi_commission, driver_earnings, payment_method, completed_at, created_at)
  values (pax, drv, v_veh, 'ECONOMICO', 'COMPLETED', 'Calle de prueba 123', 18.4719123, -69.9406456, 'Otra calle de prueba 45', 18.4796789, -69.9315123,
          5, 12, 290, 290, 0.10, 29, 261, 'CASH', now() - interval '11 years', now() - interval '11 years')
  returning id into t_old;
  insert into public.trips(passenger_id, driver_id, vehicle_id, category, status, origin_address, origin_lat, origin_lng, dest_address, dest_lat, dest_lng,
                           distance_km, duration_min, estimated_fare, final_fare, commission_rate, faxi_commission, driver_earnings, payment_method, completed_at, created_at)
  values (pax, drv, v_veh, 'ECONOMICO', 'COMPLETED', 'Calle reciente 7', 18.4719123, -69.9406456, 'Destino reciente 9', 18.4796789, -69.9315123,
          5, 12, 290, 290, 0.10, 29, 261, 'CASH', now() - interval '1 day', now() - interval '1 day')
  returning id into t_new;

  insert into public.locations(user_id, trip_id, lat, lng, recorded_at, created_at) values
    (drv, t_old, 18.47, -69.94, now() - interval '100 days', now() - interval '100 days'),
    (drv, t_new, 18.47, -69.94, now() - interval '10 days', now() - interval '10 days');
  insert into public.notifications(user_id, type, title, created_at) values
    (pax, 'PRUEBA', 'RET-VIEJA', now() - interval '100 days'), (pax, 'PRUEBA', 'RET-NUEVA', now() - interval '10 days');
  insert into public.trip_requests(trip_id, driver_id, status, expires_at, created_at) values
    (t_old, drv,  'EXPIRED', now() - interval '100 days', now() - interval '100 days'),
    (t_old, drv2, 'PENDING', now() - interval '100 days', now() - interval '100 days'),
    (t_new, drv,  'EXPIRED', now() - interval '10 days',  now() - interval '10 days');
  insert into public.driver_documents(driver_id, type, file_path, status, expires_at, created_at, reviewed_at) values
    (drv, 'LICENCIA', 'ret/rechazado-viejo.jpg',   'REJECTED', null, now() - interval '400 days', now() - interval '400 days'),
    (drv, 'LICENCIA', 'ret/rechazado-reciente.jpg', 'REJECTED', null, now() - interval '30 days',  now() - interval '30 days'),
    (drv, 'LICENCIA', 'ret/vencido-reemplazado.jpg', 'APPROVED', hoy - 400, now() - interval '800 days', now() - interval '800 days'),
    (drv, 'ANTIDOPING', 'ret/vencido-unico.jpg',   'APPROVED', hoy - 400, now() - interval '800 days', now() - interval '800 days');
  insert into public.messages(trip_id, sender_id, body) values (t_old, pax, 'Estoy en la puerta'), (t_new, pax, 'Ya voy saliendo');
  insert into public.ratings(trip_id, passenger_id, driver_id, rating, comment) values
    (t_old, pax, drv, 5, 'Muy buen viaje'), (t_new, pax, drv, 5, 'Todo bien');

  -- Primera pasada
  r := public.run_data_retention();
  assert (r->>'locations')::int = 1, 'debía borrar 1 ubicación vieja: ' || r;
  assert not exists (select 1 from public.locations where trip_id = t_old), 'la ubicación vieja sigue';
  assert exists (select 1 from public.locations where trip_id = t_new), 'borró una ubicación vigente';
  assert not exists (select 1 from public.notifications where title = 'RET-VIEJA'), 'el aviso viejo sigue';
  assert exists (select 1 from public.notifications where title = 'RET-NUEVA'), 'borró un aviso vigente';
  assert not exists (select 1 from public.trip_requests where trip_id = t_old and driver_id = drv), 'la oferta vieja sigue';
  assert exists (select 1 from public.trip_requests where trip_id = t_old and driver_id = drv2 and status = 'PENDING'), 'borró una oferta pendiente';
  assert exists (select 1 from public.trip_requests where trip_id = t_new and driver_id = drv), 'borró una oferta vigente';
  assert not exists (select 1 from public.driver_documents where file_path = 'ret/rechazado-viejo.jpg'), 'el documento rechazado viejo sigue';
  assert exists (select 1 from public.driver_documents where file_path = 'ret/rechazado-reciente.jpg'), 'borró un rechazado reciente';
  assert not exists (select 1 from public.driver_documents where file_path = 'ret/vencido-reemplazado.jpg'), 'el vencido ya reemplazado sigue';
  assert exists (select 1 from public.driver_documents where file_path = 'ret/vencido-unico.jpg'), 'borró el único documento de su tipo (el conductor dejaría de verse vencido)';
  assert public.driver_expired_documents(drv) like '%antidoping%', 'el antidoping vencido dejó de contar como vencido';

  -- Los viajes y las comisiones NO se borran; el viejo pierde sus datos personales, el reciente no
  assert (select count(*) from public.trips where id in (t_old, t_new)) = 2, 'se borró un viaje';
  assert (select origin_address = 'Dirección eliminada' and dest_address = 'Dirección eliminada' and anonymized_at is not null
            and origin_lat = 18.47 and origin_lng = -69.94 from public.trips where id = t_old), 'el viaje viejo no quedó anonimizado';
  assert (select final_fare = 290 and faxi_commission = 29 and driver_earnings = 261 and commission_rate = 0.10 from public.trips where id = t_old), 'se tocaron los montos';
  assert (select origin_address = 'Calle reciente 7' and anonymized_at is null from public.trips where id = t_new), 'se anonimizó un viaje reciente';
  assert (select body from public.messages where trip_id = t_old) = '[mensaje eliminado]', 'el mensaje viejo sigue';
  assert (select body from public.messages where trip_id = t_new) = 'Ya voy saliendo', 'se tocó un mensaje reciente';
  assert (select comment from public.ratings where trip_id = t_old) is null, 'el comentario viejo sigue';
  assert (select comment from public.ratings where trip_id = t_new) = 'Todo bien', 'se tocó un comentario reciente';
  assert (select count(*) from public.commissions) > 0, 'se borraron comisiones';
  assert (select count(*) from public.trips where id in (t_old, t_new)) = 2 and public.driver_commission_owed(drv) = v_owed + 58, 'la deuda de comisión cambió';

  -- Constancia en la auditoría
  assert exists (select 1 from public.audit_logs where action = 'DATA_RETENTION' and entity = 'locations' and (data->>'deleted')::int = 1), 'sin línea de ubicaciones en la auditoría';
  assert exists (select 1 from public.audit_logs where action = 'DATA_RETENTION' and entity = 'trips' and (data->>'anonymized')::int = 1), 'sin línea de viajes en la auditoría';
  assert exists (select 1 from public.audit_logs where action = 'DATA_RETENTION_RUN'), 'sin línea de la revisión en la auditoría';

  -- Segunda pasada: no hay nada más que borrar
  r := public.run_data_retention();
  assert (r->>'locations')::int = 0 and (r->>'notifications')::int = 0 and (r->>'trips_anonymized')::int = 0, 'la segunda pasada borró algo: ' || r;

  -- Con el plazo en 0 (apagado) no se borra nada de ese tipo
  update public.app_settings set value = '0' where key = 'RETENTION_NOTIFICATIONS_DAYS';
  insert into public.notifications(user_id, type, title, created_at) values (pax, 'PRUEBA', 'RET-APAGADA', now() - interval '500 days');
  r := public.run_data_retention();
  assert exists (select 1 from public.notifications where title = 'RET-APAGADA'), 'borró con el plazo apagado';
  assert not jsonb_exists(r, 'notifications'), 'reportó avisos con el plazo apagado';

  raise notice 'FAXI 018 OK · borra lo vencido, conserva lo vigente, viajes y comisiones intactos, plazos editables';
end $$;

rollback;
