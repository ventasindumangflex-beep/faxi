-- FAXI · 024 · Rendimiento: RLS que no re-evalúa auth.uid() por fila, e índices en claves foráneas (26-nov-2026)
--
-- QUÉ ARREGLA
-- 1. Las políticas RLS llamaban a auth.uid() y auth_role() una vez POR CADA FILA leída.
--    Envolverlas en (select ...) hace que Postgres las evalúe UNA sola vez por consulta.
--    Lo recomienda Supabase: https://supabase.com/docs/guides/database/postgres/row-level-security
--    No cambia NADA de lo que cada política permite o prohíbe: solo cómo se evalúa.
-- 2. Claves foráneas sin índice en las tablas que van a crecer (viajes, calificaciones,
--    documentos, pagos de comisión). Sin índice, borrar un usuario o unir por esa columna
--    obliga a recorrer la tabla entera.
--
-- NO se tocan las tablas de configuración (app_settings, commissions, pricing_rules,
-- restricted_zones): tienen pocas filas y un índice ahí cuesta más de lo que ahorra.
--
-- Se puede correr más de una vez.

-- ───────── 1. Políticas RLS: auth.uid() y auth_role() evaluados una sola vez ─────────

drop policy if exists commission_payments_read on public.commission_payments;
create policy commission_payments_read on public.commission_payments for select to authenticated
  using (driver_id = (select auth.uid()) or public.is_admin());

drop policy if exists driver_docs_read on public.driver_documents;
create policy driver_docs_read on public.driver_documents for select to authenticated
  using (driver_id = (select auth.uid()) or public.is_admin());

drop policy if exists driver_docs_insert on public.driver_documents;
create policy driver_docs_insert on public.driver_documents for insert to authenticated
  with check (driver_id = (select auth.uid()) and status = 'PENDING');

drop policy if exists locations_read on public.locations;
create policy locations_read on public.locations for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin()
         or (trip_id is not null and public.can_listen_trip_location(trip_id)));

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages for insert to authenticated
  with check (sender_id = (select auth.uid()) and exists (
    select 1 from public.trips t
    where t.id = messages.trip_id
      and ((t.passenger_id = (select auth.uid())) or (t.driver_id = (select auth.uid())))
      and t.status in ('ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP')));

drop policy if exists notifications_read on public.notifications;
create policy notifications_read on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists notifications_mark_read on public.notifications;
create policy notifications_mark_read on public.notifications for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists push_tokens_own on public.push_tokens;
create policy push_tokens_own on public.push_tokens for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists ratings_read on public.ratings;
create policy ratings_read on public.ratings for select to authenticated
  using (passenger_id = (select auth.uid()) or driver_id = (select auth.uid()) or public.is_admin());

drop policy if exists tickets_read on public.support_tickets;
create policy tickets_read on public.support_tickets for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());

drop policy if exists tickets_insert on public.support_tickets;
create policy tickets_insert on public.support_tickets for insert to authenticated
  with check (user_id = (select auth.uid()) and status = 'OPEN');

drop policy if exists trip_requests_read on public.trip_requests;
create policy trip_requests_read on public.trip_requests for select to authenticated
  using (driver_id = (select auth.uid()) or public.is_admin());

drop policy if exists trips_read on public.trips;
create policy trips_read on public.trips for select to authenticated
  using (passenger_id = (select auth.uid()) or driver_id = (select auth.uid())
         or public.is_admin() or public.has_pending_request(id));

drop policy if exists users_update_self on public.users;
create policy users_update_self on public.users for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

drop policy if exists vehicle_docs_read on public.vehicle_documents;
create policy vehicle_docs_read on public.vehicle_documents for select to authenticated
  using (public.is_admin() or exists (
    select 1 from public.vehicles v
    where v.id = vehicle_documents.vehicle_id and v.driver_id = (select auth.uid())));

drop policy if exists vehicle_docs_insert on public.vehicle_documents;
create policy vehicle_docs_insert on public.vehicle_documents for insert to authenticated
  with check (status = 'PENDING' and exists (
    select 1 from public.vehicles v
    where v.id = vehicle_documents.vehicle_id and v.driver_id = (select auth.uid())));

drop policy if exists vehicles_read on public.vehicles;
create policy vehicles_read on public.vehicles for select to authenticated
  using (driver_id = (select auth.uid()) or public.is_admin() or exists (
    select 1 from public.trips t
    where t.vehicle_id = vehicles.id and t.passenger_id = (select auth.uid())));

drop policy if exists vehicles_driver_insert on public.vehicles;
create policy vehicles_driver_insert on public.vehicles for insert to authenticated
  with check (driver_id = (select auth.uid()) and status = 'PENDING'
              and (select public.auth_role()) = 'DRIVER');

drop policy if exists vehicles_driver_update on public.vehicles;
create policy vehicles_driver_update on public.vehicles for update to authenticated
  using (driver_id = (select auth.uid()) and status in ('PENDING','REJECTED'))
  with check (driver_id = (select auth.uid()) and status = 'PENDING');

-- ───────── 2. Índices en claves foráneas de las tablas que crecen ─────────

create index if not exists trips_vehicle_idx            on public.trips(vehicle_id);
create index if not exists trips_cancelled_by_idx       on public.trips(cancelled_by);
create index if not exists trips_pricing_rule_idx       on public.trips(pricing_rule_id);
create index if not exists drivers_current_vehicle_idx  on public.drivers(current_vehicle_id);
create index if not exists drivers_reviewed_by_idx      on public.drivers(reviewed_by);
create index if not exists vehicles_reviewed_by_idx     on public.vehicles(reviewed_by);
create index if not exists ratings_passenger_idx        on public.ratings(passenger_id);
create index if not exists messages_sender_idx          on public.messages(sender_id);
create index if not exists support_tickets_user_idx     on public.support_tickets(user_id);
create index if not exists support_tickets_trip_idx     on public.support_tickets(trip_id);
create index if not exists support_tickets_assigned_idx on public.support_tickets(assigned_to);
create index if not exists driver_docs_reviewed_by_idx  on public.driver_documents(reviewed_by);
create index if not exists vehicle_docs_reviewed_by_idx on public.vehicle_documents(reviewed_by);
create index if not exists commission_pay_recorded_idx  on public.commission_payments(recorded_by);
create index if not exists commission_pay_voided_idx    on public.commission_payments(voided_by);
