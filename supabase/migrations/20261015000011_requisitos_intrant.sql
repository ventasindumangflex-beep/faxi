-- FAXI · 011 · Requisitos del INTRANT (Normativa Técnica de taxis por plataforma) y aceptación de términos
-- 1. Vehículo con no más de MAX_VEHICLE_AGE_YEARS años de fabricación (INTRANT: 15). El año mínimo sube solo cada año.
--    0 = sin límite: faxi-pruebas queda así para que FAXI OK siga probando el mínimo fijo (MIN_VEHICLE_YEAR).
--    Producción lo pone en 15 (PRODUCCION_PEGAR.sql).
-- 2. Documentos nuevos del conductor: carnet de taxi por plataforma del INTRANT y prueba antidoping.
-- 3. El conductor acepta los términos con una casilla; se guarda la versión y la fecha.
-- Se puede correr más de una vez.

-- ───────── 1. Antigüedad máxima del vehículo ─────────
insert into public.app_settings(key, value, description) values
  ('MAX_VEHICLE_AGE_YEARS', '0', 'Antigüedad máxima del vehículo en años (INTRANT: 15). 0 = sin límite. El año mínimo efectivo es el mayor entre MIN_VEHICLE_YEAR y (año actual − este valor).')
on conflict (key) do nothing;

create or replace function public.min_vehicle_year() returns int
language sql stable security definer set search_path = public as $$
  select greatest(
    coalesce(public.setting_num('MIN_VEHICLE_YEAR'), 2000)::int,
    case when coalesce(public.setting_num('MAX_VEHICLE_AGE_YEARS'), 0) > 0
         then extract(year from now() at time zone 'America/Santo_Domingo')::int - public.setting_num('MAX_VEHICLE_AGE_YEARS')::int end)
$$;

-- Igual que en 002, con el año mínimo de min_vehicle_year() y un mensaje más claro
create or replace function public.validate_vehicle() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_min int := public.min_vehicle_year();
        v_docs boolean := coalesce(public.setting_text('REQUIRE_VEHICLE_DOCUMENTS')::boolean, true);
begin
  new.plate := upper(replace(new.plate, ' ', ''));
  if new.year > extract(year from now())::int + 1 then
    raise exception 'Año de vehículo inválido (%)', new.year using errcode = '23514';
  end if;
  if new.year < v_min and (tg_op = 'INSERT' or new.year is distinct from old.year or new.status = 'APPROVED') then
    raise exception 'El vehículo debe ser del año % o más nuevo (el tuyo es %).', v_min, new.year using errcode = '23514';
  end if;
  if new.status = 'APPROVED' and (tg_op = 'INSERT' or old.status is distinct from 'APPROVED') and not public.is_system_call() then
    if not public.is_admin() then raise exception 'No autorizado' using errcode = '42501'; end if;
    if v_docs and (select count(distinct type) from public.vehicle_documents
                   where vehicle_id = new.id and status = 'APPROVED' and type in ('MATRICULA','SEGURO')
                     and (expires_at is null or expires_at >= current_date)) < 2 then
      raise exception 'No se puede aprobar: faltan matrícula y seguro aprobados y vigentes' using errcode = '23514';
    end if;
  end if;
  if tg_op = 'UPDATE' and new.status is distinct from old.status and not public.is_system_call() then
    new.reviewed_by := auth.uid(); new.reviewed_at := now();
  end if;
  return new;
end $$;

-- ───────── 2. Documentos del conductor exigidos por el INTRANT ─────────
alter type public.driver_document_type add value if not exists 'CARNET_INTRANT';
alter type public.driver_document_type add value if not exists 'ANTIDOPING';

-- ───────── 3. Aceptación de los términos para conductores ─────────
alter table public.drivers add column if not exists terms_version text check (terms_version ~ '^[0-9]+\.[0-9]+$');
alter table public.drivers add column if not exists terms_accepted_at timestamptz;

create or replace function public.accept_driver_terms(p_version text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.auth_role() is distinct from 'DRIVER' then raise exception 'Solo conductores' using errcode = '42501'; end if;
  if p_version is null or p_version !~ '^[0-9]+\.[0-9]+$' then raise exception 'Versión de términos inválida' using errcode = '22023'; end if;
  update public.drivers set terms_version = p_version, terms_accepted_at = now() where id = auth.uid();
  if not found then raise exception 'Conductor no encontrado' using errcode = 'P0002'; end if;
  perform public.log_action('DRIVER_TERMS_ACCEPTED', 'drivers', auth.uid()::text, jsonb_build_object('version', p_version));
end $$;

-- ───────── 4. Permisos ─────────
revoke all on function public.min_vehicle_year(), public.accept_driver_terms(text) from public, anon;
grant execute on function public.min_vehicle_year(), public.accept_driver_terms(text) to authenticated;
revoke all on function public.validate_vehicle() from public, anon, authenticated;
