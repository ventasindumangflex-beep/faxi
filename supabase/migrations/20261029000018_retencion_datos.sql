-- FAXI · 018 · Cuánto tiempo se guardan los datos (decisión del dueño, 29-oct-2026)
-- Revisión diaria a las 3:00 a. m. de RD (07:00 UTC) con el pg_cron que ya existe: run_data_retention().
-- Los plazos son ajustes en app_settings (en días; 0 = apagado; mínimo 30). Desde la 014 solo un SUPER_ADMIN los cambia.
--   RETENTION_LOCATIONS_DAYS       90    Historial de ubicaciones de los viajes: se borra.
--   RETENTION_NOTIFICATIONS_DAYS   90    Avisos a los usuarios: se borran.
--   RETENTION_TRIP_REQUESTS_DAYS   90    Ofertas de viaje a conductores (ya respondidas o vencidas): se borran.
--   RETENTION_REJECTED_DOCS_DAYS   365   Documentos RECHAZADOS de conductores y vehículos: se borran.
--   RETENTION_EXPIRED_DOCS_DAYS    365   Documentos VENCIDOS que ya tienen uno más nuevo aprobado: se borran.
--                                        Nunca se borra el único documento de un tipo: así un documento vencido no "desaparece"
--                                        y el conductor no se conecta por error (migración 015).
--   RETENTION_TRIPS_ANONYMIZE_DAYS 3650  Viajes terminados: NO se borran (contabilidad). A los 10 años se les quitan los datos
--                                        personales: direcciones, comentario de cancelación, mensajes del chat y comentario de la
--                                        calificación; las coordenadas quedan redondeadas a ~1 km. Montos, comisión y fechas se conservan.
--   Las comisiones y sus pagos (commission_payments) nunca se tocan.
-- Cada borrado o anonimización deja una línea en la auditoría con cuántos registros fueron.
-- Las copias de seguridad de Supabase guardan lo borrado hasta 7 días más.
-- Pendiente (no se hace aquí): los ARCHIVOS de documentos borrados siguen en Storage; hay que quitarlos con la API de Storage.
-- Los códigos OTP los maneja Supabase Auth y no están en nuestras tablas: su vencimiento se configura en Supabase.
-- Se puede correr más de una vez.

-- ───────── 1. Plazos (editables sin tocar código) ─────────
insert into public.app_settings(key, value, description) values
  ('RETENTION_LOCATIONS_DAYS', '90', 'Días que se guarda el historial de ubicaciones de los viajes. 0 = no borrar. Mínimo 30.'),
  ('RETENTION_NOTIFICATIONS_DAYS', '90', 'Días que se guardan los avisos a los usuarios. 0 = no borrar. Mínimo 30.'),
  ('RETENTION_TRIP_REQUESTS_DAYS', '90', 'Días que se guardan las ofertas de viaje a conductores ya respondidas o vencidas. 0 = no borrar. Mínimo 30.'),
  ('RETENTION_REJECTED_DOCS_DAYS', '365', 'Días que se guardan los documentos rechazados de conductores y vehículos. 0 = no borrar. Mínimo 30.'),
  ('RETENTION_EXPIRED_DOCS_DAYS', '365', 'Días después de vencido que se guarda un documento que ya tiene uno más nuevo aprobado. 0 = no borrar. Mínimo 30.'),
  ('RETENTION_TRIPS_ANONYMIZE_DAYS', '3650', 'Días (3650 = 10 años) después de los cuales los viajes terminados pierden sus datos personales. Los viajes y las comisiones no se borran. 0 = no anonimizar. Mínimo 30.')
on conflict (key) do nothing;

-- Un error de dedo no debe borrar todo: cero (apagado) o al menos 30 días, y siempre un número
create or replace function public.guard_retention_settings() returns trigger
language plpgsql security definer set search_path = public as $$
declare v numeric;
begin
  if new.key like 'RETENTION\_%' then
    if jsonb_typeof(new.value) <> 'number' then
      raise exception 'El plazo debe ser un número entero de días: 0 (apagado) o al menos 30.' using errcode = '22023';
    end if;
    v := (new.value #>> '{}')::numeric;
    if v <> trunc(v) or (v <> 0 and v < 30) then
      raise exception 'El plazo debe ser un número entero de días: 0 (apagado) o al menos 30.' using errcode = '22023';
    end if;
  end if;
  return new;
end $$;
revoke all on function public.guard_retention_settings() from public, anon, authenticated;
do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'app_settings_guard_retention' and tgrelid = 'public.app_settings'::regclass) then
    create trigger app_settings_guard_retention before insert or update on public.app_settings
      for each row execute function public.guard_retention_settings();
  end if;
end $$;

-- ───────── 2. Marca de viajes anonimizados ─────────
alter table public.trips add column if not exists anonymized_at timestamptz;

-- ───────── 3. Plazo de un ajuste, en días; null = apagado o inválido ─────────
create or replace function public.retention_days(p_key text) returns int
language plpgsql stable security definer set search_path = public as $$
declare v numeric;
begin
  begin v := public.setting_num(p_key); exception when others then return null; end;
  if v is null or v < 30 or v <> trunc(v) then return null; end if;
  return v::int;
end $$;
revoke all on function public.retention_days(text) from public, anon, authenticated;

-- ───────── 4. La revisión diaria ─────────
create or replace function public.run_data_retention() returns jsonb
language plpgsql security definer set search_path = public as $$
declare d int; n int; res jsonb := '{}'::jsonb; v_cut timestamptz;
begin
  -- Ubicaciones
  d := public.retention_days('RETENTION_LOCATIONS_DAYS');
  if d is not null then
    delete from public.locations where recorded_at < now() - make_interval(days => d);
    get diagnostics n = row_count;
    res := res || jsonb_build_object('locations', n);
    perform public.log_action('DATA_RETENTION', 'locations', null, jsonb_build_object('deleted', n, 'days', d));
  end if;

  -- Avisos
  d := public.retention_days('RETENTION_NOTIFICATIONS_DAYS');
  if d is not null then
    delete from public.notifications where created_at < now() - make_interval(days => d);
    get diagnostics n = row_count;
    res := res || jsonb_build_object('notifications', n);
    perform public.log_action('DATA_RETENTION', 'notifications', null, jsonb_build_object('deleted', n, 'days', d));
  end if;

  -- Ofertas de viaje ya respondidas o vencidas (las pendientes no se tocan)
  d := public.retention_days('RETENTION_TRIP_REQUESTS_DAYS');
  if d is not null then
    delete from public.trip_requests where status <> 'PENDING' and created_at < now() - make_interval(days => d);
    get diagnostics n = row_count;
    res := res || jsonb_build_object('trip_requests', n);
    perform public.log_action('DATA_RETENTION', 'trip_requests', null, jsonb_build_object('deleted', n, 'days', d));
  end if;

  -- Documentos rechazados (del conductor y del vehículo)
  d := public.retention_days('RETENTION_REJECTED_DOCS_DAYS');
  if d is not null then
    v_cut := now() - make_interval(days => d);
    delete from public.driver_documents where status = 'REJECTED' and coalesce(reviewed_at, created_at) < v_cut;
    get diagnostics n = row_count;
    delete from public.vehicle_documents where status = 'REJECTED' and coalesce(reviewed_at, created_at) < v_cut;
    get diagnostics d = row_count;
    res := res || jsonb_build_object('rejected_documents', n + d);
    perform public.log_action('DATA_RETENTION', 'rejected_documents', null, jsonb_build_object('deleted', n + d));
  end if;

  -- Documentos vencidos que ya tienen uno más nuevo aprobado del mismo tipo
  d := public.retention_days('RETENTION_EXPIRED_DOCS_DAYS');
  if d is not null then
    delete from public.driver_documents x
     where x.status = 'APPROVED' and x.expires_at < public.faxi_today() - d
       and exists (select 1 from public.driver_documents y
                    where y.driver_id = x.driver_id and y.type = x.type and y.status = 'APPROVED' and y.created_at > x.created_at);
    get diagnostics n = row_count;
    delete from public.vehicle_documents x
     where x.status = 'APPROVED' and x.expires_at < public.faxi_today() - d
       and exists (select 1 from public.vehicle_documents y
                    where y.vehicle_id = x.vehicle_id and y.type = x.type and y.status = 'APPROVED' and y.created_at > x.created_at);
    get diagnostics d = row_count;
    res := res || jsonb_build_object('expired_documents', n + d);
    perform public.log_action('DATA_RETENTION', 'expired_documents', null, jsonb_build_object('deleted', n + d));
  end if;

  -- Viajes terminados: no se borran; se les quitan los datos personales
  d := public.retention_days('RETENTION_TRIPS_ANONYMIZE_DAYS');
  if d is not null then
    update public.trips
       set origin_address = 'Dirección eliminada', dest_address = 'Dirección eliminada',
           origin_lat = round(origin_lat::numeric, 2)::double precision, origin_lng = round(origin_lng::numeric, 2)::double precision,
           dest_lat = round(dest_lat::numeric, 2)::double precision, dest_lng = round(dest_lng::numeric, 2)::double precision,
           cancel_reason = null, anonymized_at = now()
     where anonymized_at is null and created_at < now() - make_interval(days => d)
       and status in ('COMPLETED','CANCELLED','CANCELLED_BY_PASSENGER','CANCELLED_BY_DRIVER','NO_DRIVER','REQUEST_TIMEOUT');
    get diagnostics n = row_count;
    update public.messages m set body = '[mensaje eliminado]'
      from public.trips t where m.trip_id = t.id and t.anonymized_at is not null and m.body <> '[mensaje eliminado]';
    update public.ratings r set comment = null
      from public.trips t where r.trip_id = t.id and t.anonymized_at is not null and r.comment is not null;
    res := res || jsonb_build_object('trips_anonymized', n);
    perform public.log_action('DATA_RETENTION', 'trips', null, jsonb_build_object('anonymized', n, 'days', d));
  end if;

  perform public.log_action('DATA_RETENTION_RUN', 'app_settings', null, res);
  return res;
end $$;
revoke all on function public.run_data_retention() from public, anon, authenticated;

-- ───────── 5. Programación diaria: 3:00 a. m. de RD = 07:00 UTC ─────────
do $$ begin
  if not exists (select 1 from cron.job where jobname = 'faxi-retencion-datos') then
    perform cron.schedule('faxi-retencion-datos', '0 7 * * *', 'select public.run_data_retention()');
  end if;
exception when others then
  raise notice 'pg_cron no disponible (%). Programa select public.run_data_retention() cada día a las 07:00 UTC.', sqlerrm;
end $$;
