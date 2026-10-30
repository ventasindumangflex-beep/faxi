-- FAXI · 020 · Borrar también los ARCHIVOS de los documentos que la 018 (y el borrado de cuenta) quitan de la base (30-oct-2026)
-- Antes: al borrar la fila de driver_documents / vehicle_documents, el archivo seguía en Storage.
-- Ahora: cada fila borrada deja su archivo en una cola (storage_purge_queue); una revisión diaria llama a la Edge Function
-- purge-storage, que borra los archivos con la llave de servicio y marca la cola. Si la función no está desplegada, la cola
-- simplemente espera (no rompe nada). Se puede correr más de una vez.
--
-- Una vez por proyecto, igual que send-push (ver PRODUCCION_PEGAR.sql):
--   select vault.create_secret('https://<ref>.supabase.co/functions/v1/purge-storage', 'faxi_purge_url');
--   y desplegar supabase/functions/purge-storage/index.ts con "Verify JWT" apagado (usa el mismo secreto faxi_push_secret).

create table if not exists public.storage_purge_queue (
  id bigint generated always as identity primary key,
  bucket text not null,
  path text not null,
  queued_at timestamptz not null default now(),
  purged_at timestamptz,
  attempts int not null default 0,
  last_error text
);
alter table public.storage_purge_queue enable row level security;      -- sin políticas: solo la llave de servicio y el dueño la ven
revoke all on public.storage_purge_queue from anon, authenticated;
create index if not exists storage_purge_pending on public.storage_purge_queue (queued_at) where purged_at is null;

create or replace function public.queue_storage_purge() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.file_path is not null and old.file_path <> '' then
    insert into public.storage_purge_queue(bucket, path)
    values (case tg_table_name when 'driver_documents' then 'driver-documents' else 'vehicle-documents' end, old.file_path);
  end if;
  return old;
end $$;
revoke all on function public.queue_storage_purge() from public, anon, authenticated;

do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'driver_documents_queue_purge' and tgrelid = 'public.driver_documents'::regclass) then
    create trigger driver_documents_queue_purge after delete on public.driver_documents
      for each row execute function public.queue_storage_purge();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'vehicle_documents_queue_purge' and tgrelid = 'public.vehicle_documents'::regclass) then
    create trigger vehicle_documents_queue_purge after delete on public.vehicle_documents
      for each row execute function public.queue_storage_purge();
  end if;
end $$;

-- Llama a la Edge Function solo si hay archivos esperando y el proyecto ya tiene la URL en el Vault
create or replace function public.run_storage_purge() returns boolean
language plpgsql security definer set search_path = public as $$
declare v_url text; v_secret text;
begin
  if not exists (select 1 from public.storage_purge_queue where purged_at is null and attempts < 5) then return false; end if;
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'faxi_purge_url' limit 1;
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'faxi_push_secret' limit 1;
  if v_url is null or v_secret is null then return false; end if;
  perform net.http_post(url := v_url, body := '{}'::jsonb,
    headers := jsonb_build_object('content-type', 'application/json', 'x-faxi-secret', v_secret), timeout_milliseconds := 20000);
  return true;
exception when others then
  raise warning 'faxi purge-storage: %', sqlerrm;
  return false;
end $$;
revoke all on function public.run_storage_purge() from public, anon, authenticated;

do $$ begin
  if not exists (select 1 from cron.job where jobname = 'faxi-limpiar-storage') then
    perform cron.schedule('faxi-limpiar-storage', '30 7 * * *', 'select public.run_storage_purge()');   -- 3:30 a. m. de RD, después de la retención
  end if;
exception when others then
  raise notice 'pg_cron no disponible (%). Programa select public.run_storage_purge() cada día a las 07:30 UTC.', sqlerrm;
end $$;
