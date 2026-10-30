-- FAXI · 015 · Historial de ubicaciones solo durante el viaje · documentos vencidos del conductor
-- a) El historial de ubicaciones de un viaje (tabla locations) solo lo leen el pasajero y el conductor mientras el viaje
--    está en curso (ASSIGNED → ONTRIP). Cada uno ve siempre sus propias filas; los admins todo.
-- b) Documentos obligatorios del conductor (los 6 de la 014) vencidos:
--    · Vencido = el documento aprobado más nuevo de ese tipo tiene fecha de vencimiento anterior a hoy (hora de RD).
--      Un documento aprobado sin fecha no vence. Si falta un tipo, no cuenta como vencido (eso lo cuida la aprobación).
--    · No puede conectarse (como con la deuda de comisión). No se le cambia el estado ni se suspende.
--    · Revisión diaria (pg_cron, 3:00 a. m. de RD = 07:00 UTC): desconecta a quien esté conectado esperando viajes con un
--      documento vencido, le avisa y deja la línea en la auditoría. Un conductor en pleno viaje (BUSY) no se toca.
--    · admin_expiring_documents(días): documentos vencidos o que vencen pronto, para el panel → Conductores.
-- Se puede correr más de una vez.

-- ───────── a) Historial de ubicaciones ─────────
alter policy locations_read on public.locations using (
  user_id = auth.uid() or public.is_admin()
  or (trip_id is not null and public.can_listen_trip_location(trip_id)));

-- ───────── b) Documentos vencidos ─────────
create or replace function public.faxi_today() returns date
language sql stable set search_path = public as $$
  select (now() at time zone 'America/Santo_Domingo')::date
$$;

-- Vencimiento vigente de cada documento obligatorio: el del aprobado más nuevo (null = no vence)
create or replace function public.driver_document_expiry(p_driver uuid)
returns table(doc_type text, label text, ord int, expires_at date)
language sql stable security definer set search_path = public as $$
  select x.doc, x.label, x.ord, last.expires_at
  from (values (1, 'FOTO_PERFIL', 'foto de perfil'), (2, 'LICENCIA', 'licencia'), (3, 'CEDULA', 'cédula'),
               (4, 'BUENA_CONDUCTA', 'buena conducta'), (5, 'CARNET_INTRANT', 'carnet del INTRANT'),
               (6, 'ANTIDOPING', 'antidoping')) as x(ord, doc, label)
  cross join lateral (
    select d.expires_at from public.driver_documents d
     where d.driver_id = p_driver and d.type::text = x.doc and d.status = 'APPROVED'
     order by d.created_at desc limit 1) last
$$;

-- Lista en español de los documentos vencidos ('licencia, antidoping') o null si no hay
create or replace function public.driver_expired_documents(p_driver uuid) returns text
language sql stable security definer set search_path = public as $$
  select string_agg(e.label, ', ' order by e.ord)
    from public.driver_document_expiry(p_driver) e
   where e.expires_at < public.faxi_today()
$$;

create or replace function public.expired_documents_message(p_docs text) returns text
language sql immutable set search_path = public as $$
  select case when p_docs like '%,%'
    then format('Se vencieron tus documentos: %s. Para volver a conectarte, envía los nuevos a Soporte.', p_docs)
    else format('Se venció tu %s. Para volver a conectarte, envía el documento nuevo a Soporte.', p_docs) end
$$;

-- No conectarse con un documento vencido
create or replace function public.guard_driver_documents() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_docs text;
begin
  if new.availability = 'ONLINE' and old.availability = 'OFFLINE' and not public.is_system_call() then
    v_docs := public.driver_expired_documents(new.id);
    if v_docs is not null then
      raise exception '%', public.expired_documents_message(v_docs) using errcode = 'FX409';
    end if;
  end if;
  return new;
end $$;
do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'drivers_guard_documents' and tgrelid = 'public.drivers'::regclass) then
    create trigger drivers_guard_documents before update of availability on public.drivers
      for each row execute function public.guard_driver_documents();
  end if;
end $$;

-- Revisión diaria: desconecta a los conectados con documentos vencidos
create or replace function public.check_expired_documents() returns int
language plpgsql security definer set search_path = public as $$
declare r record; n int := 0;
begin
  for r in select d.id, public.driver_expired_documents(d.id) as docs
             from public.drivers d where d.availability = 'ONLINE' loop
    continue when r.docs is null;
    update public.drivers set availability = 'OFFLINE' where id = r.id and availability = 'ONLINE';
    update public.trip_requests set status = 'CANCELLED', responded_at = now() where driver_id = r.id and status = 'PENDING';
    perform public.push_notification(r.id, 'DOCUMENTS_EXPIRED', 'Tienes documentos vencidos',
      public.expired_documents_message(r.docs), jsonb_build_object('documents', r.docs));
    perform public.log_action('DRIVER_DOCUMENTS_EXPIRED', 'drivers', r.id::text, jsonb_build_object('documents', r.docs));
    n := n + 1;
  end loop;
  perform public.log_action('DOCUMENTS_EXPIRY_CHECK', 'drivers', null, jsonb_build_object('disconnected', n, 'date', public.faxi_today()));
  return n;
end $$;

do $$ begin
  if not exists (select 1 from cron.job where jobname = 'faxi-documentos-vencidos') then
    perform cron.schedule('faxi-documentos-vencidos', '0 7 * * *', 'select public.check_expired_documents()');
  end if;
exception when others then
  raise notice 'pg_cron no disponible (%). Actívalo en Dashboard → Database → Extensions y vuelve a correr este bloque.', sqlerrm;
end $$;

-- Panel: documentos vencidos o que vencen dentro de p_days días
create or replace function public.admin_expiring_documents(p_days int default 30)
returns table(driver_id uuid, full_name text, phone text, driver_status public.approval_status, availability public.driver_availability,
  doc_type text, label text, expires_at date, days_left int, expired boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.is_admin() then raise exception 'No autorizado' using errcode = '42501'; end if;
  if p_days is null or p_days not between 0 and 365 then
    raise exception 'Los días deben estar entre 0 y 365' using errcode = '22023';
  end if;
  return query
  select d.id, u.full_name, u.phone, d.status, d.availability, e.doc_type, e.label, e.expires_at,
         (e.expires_at - public.faxi_today())::int, e.expires_at < public.faxi_today()
  from public.drivers d
  join public.users u on u.id = d.id
  cross join lateral public.driver_document_expiry(d.id) e
  where d.status in ('APPROVED','SUSPENDED') and e.expires_at is not null
    and e.expires_at <= public.faxi_today() + p_days
  order by e.expires_at, u.full_name;
end $$;

-- ───────── Permisos ─────────
revoke all on function public.faxi_today(), public.driver_document_expiry(uuid), public.driver_expired_documents(uuid),
  public.expired_documents_message(text), public.guard_driver_documents(), public.check_expired_documents()
from public, anon, authenticated;
revoke all on function public.admin_expiring_documents(int) from public, anon;
grant execute on function public.admin_expiring_documents(int) to authenticated;
