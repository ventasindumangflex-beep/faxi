-- FAXI · 003 · Row Level Security, Realtime, Storage y permisos

do $$ declare t text; begin
  foreach t in array array['app_settings','users','passengers','drivers','vehicles','driver_documents','vehicle_documents','pricing_rules',
    'commissions','trip_status_transitions','trips','trip_requests','locations','payments','ratings','messages','notifications','support_tickets','audit_logs']
  loop execute format('alter table public.%I enable row level security', t); end loop;
end $$;

-- Configuración: lectura para usuarios autenticados, escritura solo admin
create policy app_settings_read on public.app_settings for select to authenticated using (true);
create policy app_settings_admin on public.app_settings for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy pricing_rules_read on public.pricing_rules for select to authenticated using (is_active or public.is_admin());
create policy pricing_rules_admin on public.pricing_rules for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy commissions_read on public.commissions for select to authenticated using (true);
create policy commissions_admin on public.commissions for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy transitions_read on public.trip_status_transitions for select to authenticated using (true);

-- Usuarios (rol/is_active protegidos por trigger users_guard)
create policy users_read on public.users for select to authenticated using (public.can_view_user(id));
create policy users_update_self on public.users for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy users_admin_update on public.users for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy passengers_read on public.passengers for select to authenticated using (public.can_view_user(id));
create policy passengers_admin on public.passengers for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy drivers_read on public.drivers for select to authenticated using (public.can_view_user(id));
create policy drivers_admin on public.drivers for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- Vehículos: el conductor registra (PENDING) y edita mientras no esté aprobado; solo admin aprueba
create policy vehicles_read on public.vehicles for select to authenticated using (
  driver_id = auth.uid() or public.is_admin()
  or exists (select 1 from public.trips t where t.vehicle_id = vehicles.id and t.passenger_id = auth.uid()));
create policy vehicles_driver_insert on public.vehicles for insert to authenticated
  with check (driver_id = auth.uid() and status = 'PENDING' and public.auth_role() = 'DRIVER');
create policy vehicles_driver_update on public.vehicles for update to authenticated
  using (driver_id = auth.uid() and status in ('PENDING','REJECTED')) with check (driver_id = auth.uid() and status = 'PENDING');
create policy vehicles_admin on public.vehicles for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy driver_docs_read on public.driver_documents for select to authenticated using (driver_id = auth.uid() or public.is_admin());
create policy driver_docs_insert on public.driver_documents for insert to authenticated with check (driver_id = auth.uid() and status = 'PENDING');
create policy driver_docs_admin on public.driver_documents for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy vehicle_docs_read on public.vehicle_documents for select to authenticated using (
  public.is_admin() or exists (select 1 from public.vehicles v where v.id = vehicle_id and v.driver_id = auth.uid()));
create policy vehicle_docs_insert on public.vehicle_documents for insert to authenticated with check (
  status = 'PENDING' and exists (select 1 from public.vehicles v where v.id = vehicle_id and v.driver_id = auth.uid()));
create policy vehicle_docs_admin on public.vehicle_documents for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- Viajes: solo lectura desde el cliente; escritura exclusiva por RPC
create policy trips_read on public.trips for select to authenticated using (
  passenger_id = auth.uid() or driver_id = auth.uid() or public.is_admin() or public.has_pending_request(id));
create policy trip_requests_read on public.trip_requests for select to authenticated using (driver_id = auth.uid() or public.is_admin());
create policy locations_read on public.locations for select to authenticated using (
  user_id = auth.uid() or (trip_id is not null and public.is_trip_party(trip_id)));
create policy payments_read on public.payments for select to authenticated using (public.is_trip_party(trip_id));
create policy ratings_read on public.ratings for select to authenticated using (passenger_id = auth.uid() or driver_id = auth.uid() or public.is_admin());

create policy messages_read on public.messages for select to authenticated using (public.is_trip_party(trip_id));
create policy messages_insert on public.messages for insert to authenticated with check (
  sender_id = auth.uid() and exists (select 1 from public.trips t where t.id = trip_id and (t.passenger_id = auth.uid() or t.driver_id = auth.uid())
    and t.status in ('ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP')));
create policy notifications_read on public.notifications for select to authenticated using (user_id = auth.uid());
create policy notifications_mark_read on public.notifications for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy tickets_read on public.support_tickets for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy tickets_insert on public.support_tickets for insert to authenticated with check (user_id = auth.uid() and status = 'OPEN');
create policy tickets_admin on public.support_tickets for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy audit_admin_read on public.audit_logs for select to authenticated using (public.is_admin());

-- ───────── Permisos ─────────
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.faxi_health to anon, authenticated;
grant execute on function
  public.auth_role, public.is_admin, public.is_super_admin, public.is_system_call, public.is_trip_party, public.has_pending_request, public.can_view_user,
  public.setting_num, public.setting_text, public.route_estimate, public.quote_fare, public.commission_split, public.quote_trip,
  public.request_trip, public.cancel_trip, public.pay_trip, public.rate_trip,
  public.set_driver_availability, public.driver_pending_requests, public.accept_trip_request, public.reject_trip_request, public.driver_advance_trip,
  public.update_location, public.expire_stale, public.trip_details, public.admin_set_commission
to authenticated;
-- Internas (sin grant): dispatch_trip, dispatch_for_driver, push_notification, log_action, assert_*, funciones de trigger.

-- ───────── Realtime ─────────
alter publication supabase_realtime add table public.trips, public.trip_requests, public.drivers, public.locations, public.notifications, public.messages;

-- ───────── Storage (documentos privados; ruta = <auth.uid()>/<archivo>) ─────────
insert into storage.buckets (id, name, public) values ('driver-documents', 'driver-documents', false), ('vehicle-documents', 'vehicle-documents', false)
on conflict (id) do nothing;
create policy "docs_owner_upload" on storage.objects for insert to authenticated
  with check (bucket_id in ('driver-documents','vehicle-documents') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "docs_owner_or_admin_read" on storage.objects for select to authenticated
  using (bucket_id in ('driver-documents','vehicle-documents') and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- ───────── Vencimientos automáticos (opcional; requiere extensión pg_cron) ─────────
-- create extension if not exists pg_cron;
-- select cron.schedule('faxi-expire-stale', '15 seconds', $$select public.expire_stale()$$);
