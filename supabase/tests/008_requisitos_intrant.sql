-- FAXI · Prueba de la migración 011 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas (usa el seed).
-- Debe terminar con NOTICE "FAXI 011 OK".
begin;

do $$
declare
  drv uuid := md5('faxi:d:1')::uuid;
  pax uuid := md5('faxi:p:1')::uuid;
  y int := extract(year from now() at time zone 'America/Santo_Domingo')::int;
begin
  -- Sin límite de antigüedad (faxi-pruebas): manda MIN_VEHICLE_YEAR
  assert public.min_vehicle_year() = coalesce(public.setting_num('MIN_VEHICLE_YEAR'), 2000)::int, 'mínimo sin límite incorrecto';

  -- Con la regla del INTRANT (15 años): el mínimo es el año actual − 15
  update public.app_settings set value = '15' where key = 'MAX_VEHICLE_AGE_YEARS';
  assert public.min_vehicle_year() = y - 15, 'mínimo con 15 años incorrecto';
  begin
    insert into public.vehicles(driver_id, make, model, year, color, plate, category, capacity)
    values (drv, 'Toyota', 'Corolla', y - 16, 'Gris', 'A999101', 'ECONOMICO', 4);
    raise exception 'FALLO: aceptó un vehículo de más de 15 años';
  exception when check_violation then null; end;
  insert into public.vehicles(driver_id, make, model, year, color, plate, category, capacity)
  values (drv, 'Toyota', 'Corolla', y - 15, 'Gris', 'A999102', 'ECONOMICO', 4);
  assert (select status from public.vehicles where plate = 'A999102') = 'PENDING', 'un vehículo de 15 años debe quedar PENDING';

  -- Documentos nuevos del INTRANT
  insert into public.driver_documents(driver_id, type, file_path) values
    (drv, 'CARNET_INTRANT', 'prueba/carnet.jpg'), (drv, 'ANTIDOPING', 'prueba/antidoping.jpg');
  assert (select count(*) from public.driver_documents where driver_id = drv and type in ('CARNET_INTRANT','ANTIDOPING')) >= 2, 'documentos INTRANT no guardados';

  -- Aceptación de términos: solo el conductor, con versión válida
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  begin
    perform public.accept_driver_terms('uno');
    raise exception 'FALLO: aceptó una versión inválida';
  exception when sqlstate '22023' then null; end;
  perform public.accept_driver_terms('1.1');
  assert (select terms_version = '1.1' and terms_accepted_at is not null from public.drivers where id = drv), 'aceptación no guardada';
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  begin
    perform public.accept_driver_terms('1.1');
    raise exception 'FALLO: un pasajero aceptó términos de conductor';
  exception when sqlstate '42501' then null; end;

  raise notice 'FAXI 011 OK · 15 años, documentos INTRANT y aceptación de términos';
end $$;

rollback;
