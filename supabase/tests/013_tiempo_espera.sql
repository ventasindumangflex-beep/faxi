-- FAXI · Prueba de la migración 016 (no deja datos: termina en ROLLBACK). SOLO faxi-pruebas (usa el seed).
-- Debe terminar con NOTICE "FAXI 016 OK".
begin;

do $$
declare
  pax uuid := md5('faxi:p:1')::uuid;
  drv uuid := md5('faxi:d:1')::uuid;
  adm uuid := (select id from public.users where role = 'ADMIN' and is_active limit 1);
  t public.trips; r public.trip_requests; s public.trip_status; v_base numeric; v_est numeric; n int; v_round int;
begin
  update public.app_settings set value = '100000' where key = 'COMMISSION_DEBT_LIMIT';   -- que la deuda no estorbe
  assert public.setting_num('WAIT_FREE_MINUTES') = 5, 'WAIT_FREE_MINUTES debe ser 5';

  -- Dos viajes con 12 minutos de espera: con 5 gratis se cobran 7; con 15 gratis no se cobra nada
  for v_round in 1..2 loop
    if v_round = 2 then update public.app_settings set value = '15' where key = 'WAIT_FREE_MINUTES'; end if;
    update public.drivers set availability = 'OFFLINE' where id = drv;
    perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
    perform public.set_driver_availability(true, 18.4719, -69.9406);
    perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
    select total into v_est from public.quote_trip(18.4719, -69.9406, 18.4796, -69.9315) where category = 'ECONOMICO';
    t := public.request_trip('ECONOMICO', 'Piantini', 18.4719, -69.9406, 'Naco', 18.4796, -69.9315, 'CASH');
    assert t.estimated_fare = v_est, 'la cotización cambió';
    select * into r from public.trip_requests where trip_id = t.id and driver_id = drv;
    perform set_config('request.jwt.claims', json_build_object('sub', drv, 'role', 'authenticated')::text, true);
    t := public.accept_trip_request(r.id);
    t := public.driver_advance_trip(t.id, 'ENROUTE');
    t := public.driver_advance_trip(t.id, 'ARRIVED');
    update public.trips set arrived_at = now() - interval '12 minutes' where id = t.id;   -- llegó hace 12 min
    foreach s in array array['STARTED','ONTRIP','FINISHED']::public.trip_status[] loop
      t := public.driver_advance_trip(t.id, s);
    end loop;
    select total into v_base from public.quote_fare(t.category, t.distance_km, t.duration_min);
    assert t.wait_minutes = 12, 'espera mal medida: ' || t.wait_minutes;
    if v_round = 1 then
      assert t.wait_charge = 7 * 5, format('cargo de espera %s, esperado 35 (7 min × RD$5)', t.wait_charge);
      assert t.final_fare = v_base + 35, format('precio final %s, esperado %s', t.final_fare, v_base + 35);
    else
      assert t.wait_charge = 0, 'cobró espera dentro de los minutos gratis';
      assert t.final_fare = v_base, 'el precio final no debe llevar espera';
    end if;
    assert t.faxi_commission = round(t.final_fare * t.commission_rate, 2), 'la comisión no se calculó sobre el precio con espera';
    assert t.faxi_commission + t.driver_earnings = t.final_fare, 'reparto no cuadra';
    perform public.driver_confirm_cash(t.id);
    assert (select amount from public.payments where trip_id = t.id) = t.final_fare, 'el cobro no lleva la espera';
    -- La pantalla del cobro lo lee de trip_details
    perform set_config('request.jwt.claims', json_build_object('sub', pax, 'role', 'authenticated')::text, true);
    assert (public.trip_details(t.id)->'trip'->>'wait_minutes')::numeric = 12, 'trip_details sin la espera';
  end loop;

  -- Solo el SUPER_ADMIN cambia los minutos gratis
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  update public.app_settings set value = '30' where key = 'WAIT_FREE_MINUTES';
  get diagnostics n = row_count;
  execute 'reset role';
  assert n = 0, 'un ADMIN cambió los minutos de espera gratis';

  raise notice 'FAXI 016 OK · 5 min de espera gratis, luego tarifa por minuto, comisión sobre el total';
end $$;

rollback;
