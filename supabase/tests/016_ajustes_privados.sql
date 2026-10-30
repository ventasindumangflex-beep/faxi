-- FAXI · Prueba de la migración 019 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas (usa el seed).
-- Debe terminar con NOTICE "FAXI 019 OK".
begin;

do $$
declare
  pax uuid := md5('faxi:p:1')::uuid;
  drv uuid := md5('faxi:d:1')::uuid;
  drv_new uuid := md5('faxi:d:18')::uuid;
  v_info text := 'Banco de prueba · Ahorro · 000-000000-0 · Titular de prueba';
begin
  update public.app_settings set value = to_jsonb(v_info) where key = 'COMMISSION_PAY_INFO';

  -- Nadie con sesión (ni sin ella) lee ajustes por RPC
  assert not has_function_privilege('authenticated', 'public.setting_text(text)', 'execute'), 'authenticated puede leer ajustes de texto';
  assert not has_function_privilege('authenticated', 'public.setting_num(text)', 'execute'), 'authenticated puede leer ajustes numéricos';
  assert not has_function_privilege('anon', 'public.setting_text(text)', 'execute'), 'anon puede leer ajustes de texto';
  assert not has_function_privilege('anon', 'public.setting_num(text)', 'execute'), 'anon puede leer ajustes numéricos';

  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    perform public.setting_text('COMMISSION_PAY_INFO');
    raise exception 'FALLO: un pasajero leyó la cuenta de pago por RPC';
  exception when sqlstate '42501' then null; end;
  execute 'reset role';

  -- Lo que sí debe seguir funcionando (funciones definer que usan los ajustes por dentro)
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  assert public.my_commission_status()->>'pay_info' = v_info, 'el conductor aprobado dejó de ver los datos de pago';
  perform set_config('request.jwt.claims', json_build_object('sub', drv_new, 'role', 'authenticated')::text, true);
  assert public.my_commission_status()->>'pay_info' is null, 'un conductor sin aprobar ve los datos de pago';

  raise notice 'FAXI 019 OK · los ajustes del sistema no se leen por RPC';
end $$;

rollback;
