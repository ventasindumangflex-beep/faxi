-- FAXI · Prueba de la migración 020 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas (usa el seed).
-- Debe terminar con NOTICE "FAXI 020 OK".
begin;

do $$
declare
  pax uuid := md5('faxi:p:1')::uuid;
  drv uuid := md5('faxi:d:1')::uuid;
  v_veh uuid := (select current_vehicle_id from public.drivers where id = md5('faxi:d:1')::uuid);
  n int; r jsonb;
begin
  delete from public.storage_purge_queue;   -- solo dentro de esta prueba (se deshace)

  -- Borrar un documento del conductor y uno del vehículo deja sus archivos en la cola
  insert into public.driver_documents(driver_id, type, file_path, status, created_at, reviewed_at)
  values (drv, 'LICENCIA', 'purga/doc-conductor.jpg', 'REJECTED', now() - interval '400 days', now() - interval '400 days');
  insert into public.vehicle_documents(vehicle_id, type, file_path, status, created_at, reviewed_at)
  values (v_veh, 'SEGURO', 'purga/doc-vehiculo.jpg', 'REJECTED', now() - interval '400 days', now() - interval '400 days');
  assert (select count(*) from public.storage_purge_queue) = 0, 'la cola debe empezar vacía';

  delete from public.driver_documents where file_path = 'purga/doc-conductor.jpg';
  delete from public.vehicle_documents where file_path = 'purga/doc-vehiculo.jpg';
  assert exists (select 1 from public.storage_purge_queue where bucket = 'driver-documents' and path = 'purga/doc-conductor.jpg' and purged_at is null), 'el archivo del conductor no quedó en la cola';
  assert exists (select 1 from public.storage_purge_queue where bucket = 'vehicle-documents' and path = 'purga/doc-vehiculo.jpg' and purged_at is null), 'el archivo del vehículo no quedó en la cola';

  -- La retención diaria (018) también los encola
  insert into public.driver_documents(driver_id, type, file_path, status, created_at, reviewed_at)
  values (drv, 'LICENCIA', 'purga/rechazado-viejo.jpg', 'REJECTED', now() - interval '400 days', now() - interval '400 days');
  r := public.run_data_retention();
  assert exists (select 1 from public.storage_purge_queue where path = 'purga/rechazado-viejo.jpg'), 'la retención no encoló el archivo del documento que borró';

  -- La cola es privada
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    select count(*) into n from public.storage_purge_queue;
    raise exception 'FALLO: un pasajero leyó la cola de archivos';
  exception when sqlstate '42501' then null; end;
  execute 'reset role';
  assert not has_function_privilege('authenticated', 'public.run_storage_purge()', 'execute'), 'authenticated puede lanzar la limpieza';
  assert not has_function_privilege('anon', 'public.run_storage_purge()', 'execute'), 'anon puede lanzar la limpieza';
  assert not has_function_privilege('authenticated', 'public.queue_storage_purge()', 'execute'), 'authenticated puede usar la función del trigger';

  -- Sin URL en el Vault no hace nada (y no falla)
  delete from vault.secrets where name = 'faxi_purge_url';
  assert public.run_storage_purge() = false, 'sin faxi_purge_url debe devolver false';
  assert exists (select 1 from cron.job where jobname = 'faxi-limpiar-storage' and schedule = '30 7 * * *'), 'falta la revisión diaria de las 3:30 a. m.';

  raise notice 'FAXI 020 OK · los archivos de documentos borrados se encolan y la cola es privada';
end $$;

rollback;
