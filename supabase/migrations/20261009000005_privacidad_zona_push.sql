-- FAXI · 005 · Ubicación en vivo privada · zona de servicio real · push automático
-- Requiere 001–004 aplicadas. Se puede correr más de una vez.

-- ───────── 1. Ubicación en vivo: canales privados `trip:<uuid>` autorizados por RLS ─────────
-- Solo el pasajero y el conductor del viaje (y los admins) pueden escuchar; solo el conductor puede transmitir,
-- y solo mientras el viaje está en curso. Las apps se unen con { config: { private: true } }.

create or replace function public.trip_topic_id(p_topic text) returns uuid
language sql immutable set search_path = public as $$
  select case when p_topic ~* '^trip:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
              then substr(p_topic, 6)::uuid end
$$;

create or replace function public.can_listen_trip_location(p_trip uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p_trip is not null and (
    public.is_admin() or exists (
      select 1 from public.trips t
      where t.id = p_trip
        and (t.passenger_id = auth.uid() or t.driver_id = auth.uid())
        and t.status in ('ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP')))
$$;

create or replace function public.can_send_trip_location(p_trip uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p_trip is not null and exists (
    select 1 from public.trips t
    where t.id = p_trip and t.driver_id = auth.uid()
      and t.status in ('ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP'))
$$;

revoke all on function public.trip_topic_id(text), public.can_listen_trip_location(uuid), public.can_send_trip_location(uuid) from public, anon;
grant execute on function public.trip_topic_id(text), public.can_listen_trip_location(uuid), public.can_send_trip_location(uuid) to authenticated;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'realtime' and tablename = 'messages' and policyname = 'faxi_trip_location_listen') then
    create policy faxi_trip_location_listen on realtime.messages for select to authenticated
      using (realtime.messages.extension = 'broadcast'
             and public.can_listen_trip_location(public.trip_topic_id(realtime.topic())));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'realtime' and tablename = 'messages' and policyname = 'faxi_trip_location_send') then
    create policy faxi_trip_location_send on realtime.messages for insert to authenticated
      with check (realtime.messages.extension = 'broadcast'
                  and public.can_send_trip_location(public.trip_topic_id(realtime.topic())));
  end if;
end $$;

-- ───────── 2. Zona de servicio: límites reales del Gran Santo Domingo ─────────
-- Distrito Nacional + provincia Santo Domingo (SDE, SDN, SDO, Boca Chica, Los Alcarrizos, Pedro Brand, San Antonio de Guerra),
-- unidos y con ~1 km de margen para el error del GPS. Fuente: geoBoundaries (ADM1 República Dominicana, licencia abierta).
-- Puntos [lat, lng]. Se puede editar desde app_settings sin nueva migración.
insert into public.app_settings(key, value, description) values ('SERVICE_AREA',
  '[[18.4569,-69.8965],[18.4263,-69.9526],[18.4075,-70.0045],[18.4196,-70.0168],[18.442,-70.0184],[18.4533,-70.0264],[18.4564,-70.0735],[18.4706,-70.0867],[18.4879,-70.0899],[18.5245,-70.131],[18.5603,-70.1517],[18.5985,-70.1628],[18.6442,-70.1505],[18.6849,-70.1762],[18.7385,-70.1745],[18.7414,-70.1649],[18.7306,-70.1339],[18.6989,-70.1139],[18.6726,-70.01],[18.6882,-69.9747],[18.706,-69.9663],[18.7124,-69.9504],[18.7108,-69.8849],[18.6629,-69.8306],[18.5909,-69.785],[18.6264,-69.7488],[18.6521,-69.6677],[18.6639,-69.648],[18.6712,-69.6104],[18.6576,-69.5719],[18.6456,-69.5657],[18.6307,-69.5783],[18.5975,-69.5681],[18.5688,-69.5703],[18.5214,-69.604],[18.489,-69.572],[18.4781,-69.5154],[18.4685,-69.5083],[18.4071,-69.5186],[18.4003,-69.5282],[18.446,-69.605],[18.4454,-69.6128],[18.4245,-69.6109],[18.4093,-69.6165],[18.4036,-69.6466],[18.4116,-69.6712],[18.4465,-69.6994],[18.4625,-69.8518]]'::jsonb,
  'Polígono [lat,lng] del Gran Santo Domingo (DN + provincia Santo Domingo, margen ~1 km). Vacío = toda la República Dominicana.')
on conflict (key) do update set value = excluded.value, description = excluded.description;

-- ───────── 3. Push automático: cada fila nueva en notifications llama a la Edge Function send-push ─────────
-- Sustituye al Database Webhook manual. Lee del Vault la URL (faxi_push_url) y el secreto (faxi_push_secret),
-- que se crean abajo; la función send-push valida el secreto con check_push_secret().
-- Si faltan, no hace nada (no rompe la creación de notificaciones).
create extension if not exists pg_net with schema extensions;

create or replace function public.notify_push() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_url text; v_secret text;
begin
  begin
    select decrypted_secret into v_url from vault.decrypted_secrets where name = 'faxi_push_url' limit 1;
    select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'faxi_push_secret' limit 1;
    if v_url is null or v_secret is null then return new; end if;
    perform net.http_post(
      url := v_url,
      body := jsonb_build_object('type', 'INSERT', 'table', 'notifications', 'record', to_jsonb(new)),
      headers := jsonb_build_object('content-type', 'application/json', 'x-faxi-secret', v_secret),
      timeout_milliseconds := 5000);
  exception when others then
    raise warning 'faxi push: %', sqlerrm;   -- nunca bloquear la notificación
  end;
  return new;
end $$;
revoke all on function public.notify_push() from public, anon, authenticated;

do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'notifications_push' and tgrelid = 'public.notifications'::regclass) then
    create trigger notifications_push after insert on public.notifications
      for each row execute function public.notify_push();
  end if;
end $$;

create or replace function public.check_push_secret(p_secret text) returns boolean
language sql stable security definer set search_path = public as $$
  select p_secret is not null and exists (
    select 1 from vault.decrypted_secrets where name = 'faxi_push_secret' and decrypted_secret = p_secret)
$$;
revoke all on function public.check_push_secret(text) from public, anon, authenticated;
grant execute on function public.check_push_secret(text) to service_role;

-- Secreto del Vault (aleatorio, nunca sale de la base).
do $$ begin
  if not exists (select 1 from vault.secrets where name = 'faxi_push_secret') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(24), 'hex'), 'faxi_push_secret',
      'Secreto entre el trigger notifications_push y la Edge Function send-push');
  end if;
end $$;
-- La URL depende del proyecto; crearla una vez por proyecto (ver supabase/PRODUCCION_PEGAR.sql):
--   select vault.create_secret('https://<ref>.supabase.co/functions/v1/send-push', 'faxi_push_url');
