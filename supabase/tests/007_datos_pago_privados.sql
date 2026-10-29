-- FAXI · Prueba de la migración 010 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas (usa el seed).
-- Debe terminar con NOTICE "FAXI 010 OK".
begin;

do $$
declare
  pax uuid := md5('faxi:p:1')::uuid;
  drv uuid := md5('faxi:d:1')::uuid;      -- aprobado
  drv_new uuid := md5('faxi:d:18')::uuid; -- pendiente de aprobación
  adm uuid := md5('faxi:admin')::uuid;
  n int; v_info text := 'Banco de prueba · Ahorro · 000-000000-0 · Titular de prueba';
begin
  update public.app_settings set value = to_jsonb(v_info) where key = 'COMMISSION_PAY_INFO';

  -- Pasajero: no lee los datos de pago, pero sí los demás ajustes
  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into n from public.app_settings where key = 'COMMISSION_PAY_INFO';
  assert n = 0, 'el pasajero lee los datos de pago';
  select count(*) into n from public.app_settings where key = 'SERVICE_AREA';
  assert n = 1, 'el pasajero dejó de leer los ajustes públicos';
  execute 'reset role';

  -- Conductor aprobado: los recibe por la RPC, no por la tabla
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  assert public.my_commission_status()->>'pay_info' = v_info, 'el conductor aprobado no ve los datos de pago';
  execute 'set local role authenticated';
  select count(*) into n from public.app_settings where key = 'COMMISSION_PAY_INFO';
  execute 'reset role';
  assert n = 0, 'el conductor lee los datos de pago directo en la tabla';

  -- Conductor pendiente: no los recibe
  perform set_config('request.jwt.claims', json_build_object('sub', drv_new, 'role', 'authenticated')::text, true);
  assert public.my_commission_status()->>'pay_info' is null, 'un conductor sin aprobar ve los datos de pago';

  -- Admin: los lee y los edita
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into n from public.app_settings where key = 'COMMISSION_PAY_INFO';
  update public.app_settings set value = '"Otro banco"' where key = 'COMMISSION_PAY_INFO';
  execute 'reset role';
  assert n = 1, 'el admin no ve los datos de pago';
  -- Desde la migración 014 solo el SUPER_ADMIN cambia los datos de pago (decisión del dueño, 28-oct-2026)
  assert public.setting_text('COMMISSION_PAY_INFO') = v_info, 'un ADMIN pudo editar los datos de pago';
  perform set_config('request.jwt.claims', json_build_object('sub', (select id from public.users where role = 'SUPER_ADMIN' limit 1), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  update public.app_settings set value = '"Otro banco"' where key = 'COMMISSION_PAY_INFO';
  execute 'reset role';
  assert public.setting_text('COMMISSION_PAY_INFO') = 'Otro banco', 'el SUPER_ADMIN no pudo editar los datos de pago';

  raise notice 'FAXI 010 OK · datos de pago solo para conductores aprobados';
end $$;

rollback;
