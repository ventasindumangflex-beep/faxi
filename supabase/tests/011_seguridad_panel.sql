-- FAXI · Prueba de la migración 014 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas (usa el seed).
-- Debe terminar con NOTICE "FAXI 014 OK" (el número es el de la migración, como en las demás pruebas).
begin;

do $$
declare
  adm uuid := (select id from public.users where role = 'ADMIN' and is_active limit 1);
  sup uuid := (select id from public.users where role = 'SUPER_ADMIN' and is_active limit 1);
  pax uuid := md5('faxi:p:1')::uuid;
  pax2 uuid := md5('faxi:p:2')::uuid;
  drv uuid := md5('faxi:d:1')::uuid;      -- conductor aprobado del seed
  nd uuid := gen_random_uuid();           -- conductor nuevo, solo en esta prueba
  adm2 uuid := gen_random_uuid();         -- segundo admin, solo en esta prueba
  cp public.commission_payments; v_owed numeric; n int; v_msg text;
begin
  assert adm is not null and sup is not null, 'el seed debe tener un ADMIN y un SUPER_ADMIN';

  -- ───── a) Aprobar conductor exige sus 6 documentos aprobados y vigentes ─────
  insert into auth.users(instance_id, id, aud, role, phone, raw_user_meta_data, created_at, updated_at)
  values ('00000000-0000-0000-0000-000000000000', nd, 'authenticated', 'authenticated', '18095550188',
          '{"role":"DRIVER","full_name":"Conductor de prueba"}', now(), now());
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    update public.drivers set status = 'APPROVED' where id = nd;
    raise exception 'FALLO: aprobó un conductor sin documentos';
  exception when sqlstate 'FX409' then null; end;
  execute 'reset role';

  insert into public.driver_documents(driver_id, type, file_path, status, expires_at)
  select nd, t::public.driver_document_type, nd || '/' || t || '.jpg', 'APPROVED', current_date + 365
    from unnest(array['FOTO_PERFIL','LICENCIA','CEDULA','BUENA_CONDUCTA','CARNET_INTRANT','ANTIDOPING']) t;
  update public.driver_documents set expires_at = current_date - 1 where driver_id = nd and type = 'ANTIDOPING';

  execute 'set local role authenticated';
  begin
    update public.drivers set status = 'APPROVED' where id = nd;
    raise exception 'FALLO: aprobó un conductor con el antidoping vencido';
  exception when sqlstate 'FX409' then get stacked diagnostics v_msg = message_text; end;
  execute 'reset role';
  assert v_msg like '%antidoping%' and v_msg not like '%licencia%', 'mensaje de documentos incorrecto: ' || v_msg;

  update public.driver_documents set expires_at = current_date + 365 where driver_id = nd and type = 'ANTIDOPING';
  execute 'set local role authenticated';
  update public.drivers set status = 'APPROVED' where id = nd;
  execute 'reset role';
  assert (select status from public.drivers where id = nd) = 'APPROVED', 'no aprobó al conductor con sus 6 documentos';

  -- ───── b) Ajustes del sistema: el ADMIN los ve pero no los cambia; el SUPER_ADMIN sí ─────
  execute 'set local role authenticated';
  update public.app_settings set value = '9' where key = 'DISPATCH_RADIUS_KM';
  get diagnostics n = row_count;
  assert n = 0, 'un ADMIN cambió un ajuste del sistema';
  update public.app_settings set value = '"martes"' where key = 'COMMISSION_PAY_DAY';
  get diagnostics n = row_count;
  assert n = 0, 'un ADMIN cambió el día de pago';
  select count(*) into n from public.app_settings where key in ('COMMISSION_PAY_INFO', 'COMMISSION_PAY_DAY');
  assert n = 2, 'el ADMIN dejó de ver los datos de pago';
  begin
    insert into public.app_settings(key, value) values ('AJUSTE_FALSO', '1');
    raise exception 'FALLO: un ADMIN creó un ajuste';
  exception when insufficient_privilege then null; end;
  execute 'reset role';

  perform set_config('request.jwt.claims', json_build_object('sub', sup, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  update public.app_settings set value = '9' where key = 'DISPATCH_RADIUS_KM';
  get diagnostics n = row_count;
  assert n = 1, 'el SUPER_ADMIN no pudo cambiar un ajuste';

  -- ───── c) Nadie borra tarifas, comisiones ni ajustes (ni el SUPER_ADMIN) ─────
  begin
    delete from public.pricing_rules where category = 'VAN';
    raise exception 'FALLO: borró una tarifa';
  exception when insufficient_privilege then null; end;
  begin
    delete from public.commissions;
    raise exception 'FALLO: borró la comisión';
  exception when insufficient_privilege then null; end;
  begin
    delete from public.app_settings where key = 'SERVICE_AREA';
    raise exception 'FALLO: borró un ajuste';
  exception when insufficient_privilege then null; end;
  execute 'reset role';

  -- ───── d) Solo un SUPER_ADMIN cambia o desactiva a otro admin ─────
  insert into auth.users(instance_id, id, aud, role, phone, raw_user_meta_data, created_at, updated_at)
  values ('00000000-0000-0000-0000-000000000000', adm2, 'authenticated', 'authenticated', '18095550187',
          '{"full_name":"Admin de prueba"}', now(), now());
  update public.users set role = 'ADMIN' where id = adm2;

  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    update public.users set is_active = false where id = sup;
    raise exception 'FALLO: un ADMIN desactivó al SUPER_ADMIN';
  exception when sqlstate '42501' then null; end;
  begin
    update public.users set full_name = 'Otro nombre' where id = adm2;
    raise exception 'FALLO: un ADMIN cambió a otro ADMIN';
  exception when sqlstate '42501' then null; end;
  update public.users set is_active = false where id = pax2;
  get diagnostics n = row_count;
  assert n = 1, 'el ADMIN ya no puede desactivar a un pasajero';
  execute 'reset role';

  perform set_config('request.jwt.claims', json_build_object('sub', sup, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  update public.users set is_active = false where id = adm2;
  get diagnostics n = row_count;
  execute 'reset role';
  assert n = 1 and not (select is_active from public.users where id = adm2), 'el SUPER_ADMIN no pudo desactivar a un ADMIN';

  -- ───── e) Anular un pago de comisión: solo SUPER_ADMIN, con motivo y en la auditoría ─────
  v_owed := public.driver_commission_owed(drv);
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  cp := public.admin_record_commission_payment(drv, 50, 'EFECTIVO', 'prueba de anulación');
  assert public.driver_commission_owed(drv) = v_owed - 50, 'el pago no bajó la deuda';
  begin
    perform public.admin_void_commission_payment(cp.id, 'Monto equivocado');
    raise exception 'FALLO: un ADMIN anuló un pago';
  exception when sqlstate '42501' then null; end;

  perform set_config('request.jwt.claims', json_build_object('sub', sup, 'role', 'authenticated')::text, true);
  begin
    perform public.admin_void_commission_payment(cp.id, 'no');
    raise exception 'FALLO: anuló sin motivo';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.admin_void_commission_payment(gen_random_uuid(), 'Monto equivocado');
    raise exception 'FALLO: anuló un pago inexistente';
  exception when sqlstate 'P0002' then null; end;
  cp := public.admin_void_commission_payment(cp.id, 'Monto equivocado');
  assert cp.voided_at is not null and cp.voided_by = sup and cp.void_reason = 'Monto equivocado', 'anulación mal guardada';
  assert public.driver_commission_owed(drv) = v_owed, 'la deuda no volvió a su valor al anular';
  assert exists (select 1 from public.audit_logs where action = 'COMMISSION_PAYMENT_VOIDED' and entity_id = cp.id::text), 'sin constancia en la auditoría';
  assert exists (select 1 from public.notifications where user_id = drv and type = 'COMMISSION_PAYMENT_VOIDED'), 'sin aviso al conductor';
  begin
    perform public.admin_void_commission_payment(cp.id, 'Otra vez');
    raise exception 'FALLO: anuló dos veces el mismo pago';
  exception when sqlstate 'FX409' then null; end;

  -- ───── f) El conductor aprobado no cambia su nombre; el pasajero y el admin sí ─────
  perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    update public.users set full_name = 'Nombre inventado' where id = drv;
    raise exception 'FALLO: un conductor aprobado cambió su nombre';
  exception when sqlstate '42501' then null; end;
  execute 'reset role';

  perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  update public.users set full_name = 'María Prueba' where id = pax;
  get diagnostics n = row_count;
  execute 'reset role';
  assert n = 1, 'el pasajero no pudo cambiar su nombre';

  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  update public.users set full_name = 'Nombre corregido' where id = drv;
  get diagnostics n = row_count;
  execute 'reset role';
  assert n = 1, 'el admin no pudo corregir el nombre del conductor';

  raise notice 'FAXI 014 OK · documentos para aprobar, ajustes solo SUPER_ADMIN, sin borrar, admins protegidos, anular pagos, nombre del conductor';
end $$;

rollback;
