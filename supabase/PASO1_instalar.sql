-- FAXI · INSTALACIÓN COMPLETA (migraciones 001–003 + datos demo)
-- Pegar entero en Supabase → SQL Editor → Run. Solo una vez, en un proyecto nuevo.


-- ═════════════ supabase/migrations/20261003000001_schema.sql ═════════════
-- FAXI · 001 · Esquema base
create extension if not exists pgcrypto with schema extensions;

-- ───────── Tipos ─────────
create type public.user_role as enum ('PASSENGER','DRIVER','ADMIN','SUPER_ADMIN');
create type public.trip_status as enum (
  'REQUESTED','SEARCHING','ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP','FINISHED','PAYMENT','COMPLETED','CANCELLED',
  'NO_DRIVER','DRIVER_TIMEOUT','REQUEST_TIMEOUT','PAYMENT_FAILED','CANCELLED_BY_PASSENGER','CANCELLED_BY_DRIVER');
create type public.trip_request_status as enum ('PENDING','ACCEPTED','REJECTED','EXPIRED','CANCELLED');
create type public.approval_status as enum ('PENDING','APPROVED','REJECTED','SUSPENDED');
create type public.driver_availability as enum ('OFFLINE','ONLINE','BUSY');
create type public.vehicle_category as enum ('ECONOMICO','CONFORT','PREMIUM','SUV','VAN');
create type public.payment_method as enum ('CASH','CARD','TRANSFER','WALLET');
create type public.payment_status as enum ('PENDING','PROCESSING','PAID','FAILED','REFUNDED');
create type public.ticket_status as enum ('OPEN','IN_REVIEW','RESOLVED','CLOSED');
create type public.ticket_priority as enum ('LOW','MEDIUM','HIGH');
create type public.driver_document_type as enum ('LICENCIA','CEDULA','BUENA_CONDUCTA','FOTO_PERFIL');
create type public.vehicle_document_type as enum ('MATRICULA','SEGURO','INSPECCION','FOTO_EXTERIOR','FOTO_INTERIOR');
create type public.location_source as enum ('SIMULATED','GPS');

create or replace function public.set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

-- ───────── Configuración ─────────
create table public.app_settings (
  key text primary key check (key ~ '^[A-Z_]+$'),
  value jsonb not null,
  description text,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ───────── Usuarios ─────────
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.user_role not null default 'PASSENGER',
  full_name text not null check (char_length(full_name) between 2 and 120),
  email text,
  phone text check (phone is null or phone ~ '^\+?[0-9 ]{10,16}$'),
  avatar_path text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index users_role_idx on public.users(role);

create table public.passengers (
  id uuid primary key references public.users(id) on delete cascade,
  rating_avg numeric(3,2) not null default 5.00 check (rating_avg between 1 and 5),
  rating_count int not null default 0 check (rating_count >= 0),
  trips_count int not null default 0 check (trips_count >= 0),
  default_payment_method public.payment_method not null default 'CASH',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.drivers (
  id uuid primary key references public.users(id) on delete cascade,
  license_number text unique,
  status public.approval_status not null default 'PENDING',
  availability public.driver_availability not null default 'OFFLINE',
  current_vehicle_id uuid,
  rating_avg numeric(3,2) check (rating_avg is null or rating_avg between 1 and 5),
  rating_count int not null default 0 check (rating_count >= 0),
  trips_count int not null default 0 check (trips_count >= 0),
  last_lat double precision check (last_lat between -90 and 90),
  last_lng double precision check (last_lng between -180 and 180),
  last_heading real,
  last_location_at timestamptz,
  rejection_reason text,
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint drivers_online_requires_approval check (availability = 'OFFLINE' or status = 'APPROVED')
);
create index drivers_dispatch_idx on public.drivers(availability, status);

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers(id) on delete cascade,
  make text not null check (char_length(make) between 2 and 40),
  model text not null check (char_length(model) between 1 and 40),
  year int not null check (year between 1950 and 2100),
  color text not null check (char_length(color) between 3 and 30),
  plate text not null unique check (plate ~ '^[A-Z]{1,2}[0-9]{6}$'),
  category public.vehicle_category not null,
  capacity int not null check (capacity between 1 and 15),
  photos text[] not null default '{}',
  status public.approval_status not null default 'PENDING',
  rejection_reason text,
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index vehicles_driver_idx on public.vehicles(driver_id);
create index vehicles_status_idx on public.vehicles(status);
alter table public.drivers add constraint drivers_current_vehicle_fk
  foreign key (current_vehicle_id) references public.vehicles(id) on delete set null;

create table public.driver_documents (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers(id) on delete cascade,
  type public.driver_document_type not null,
  file_path text not null,
  status public.approval_status not null default 'PENDING',
  expires_at date,
  rejection_reason text,
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index driver_documents_driver_idx on public.driver_documents(driver_id, type);

create table public.vehicle_documents (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  type public.vehicle_document_type not null,
  file_path text not null,
  status public.approval_status not null default 'PENDING',
  expires_at date,
  rejection_reason text,
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index vehicle_documents_vehicle_idx on public.vehicle_documents(vehicle_id, type);

-- ───────── Precios y comisión (única fuente de verdad) ─────────
create table public.pricing_rules (
  id uuid primary key default gen_random_uuid(),
  category public.vehicle_category not null,
  display_name text not null,
  base_fare numeric(10,2) not null check (base_fare >= 0),
  per_km numeric(10,2) not null check (per_km >= 0),
  per_min numeric(10,2) not null check (per_min >= 0),
  minimum_fare numeric(10,2) not null check (minimum_fare >= 0),
  surge_multiplier numeric(4,2) not null default 1.00 check (surge_multiplier between 1 and 5),
  capacity int not null default 4 check (capacity between 1 and 15),
  sort_order int not null default 0,
  is_active boolean not null default true,
  updated_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index pricing_rules_one_active on public.pricing_rules(category) where is_active;

create table public.commissions (
  id uuid primary key default gen_random_uuid(),
  category public.vehicle_category,            -- null = comisión por defecto
  rate numeric(5,4) not null check (rate >= 0 and rate < 1),
  is_active boolean not null default true,
  effective_from timestamptz not null default now(),
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index commissions_one_active on public.commissions((coalesce(category::text,'*'))) where is_active;

-- ───────── Viajes ─────────
create table public.trip_status_transitions (
  from_status public.trip_status not null,
  to_status public.trip_status not null,
  actor text not null check (actor in ('PASSENGER','DRIVER','SYSTEM','ADMIN')),
  created_at timestamptz not null default now(),
  primary key (from_status, to_status, actor)
);

create sequence public.trip_code_seq start 312900;

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  code text not null unique default ('FX-' || nextval('public.trip_code_seq')::text),
  passenger_id uuid not null references public.passengers(id),
  driver_id uuid references public.drivers(id),
  vehicle_id uuid references public.vehicles(id),
  category public.vehicle_category not null,
  status public.trip_status not null default 'REQUESTED',
  origin_address text not null check (char_length(origin_address) between 2 and 200),
  origin_lat double precision not null check (origin_lat between -90 and 90),
  origin_lng double precision not null check (origin_lng between -180 and 180),
  dest_address text not null check (char_length(dest_address) between 2 and 200),
  dest_lat double precision not null check (dest_lat between -90 and 90),
  dest_lng double precision not null check (dest_lng between -180 and 180),
  distance_km numeric(7,2) not null check (distance_km > 0),
  duration_min numeric(7,1) not null check (duration_min > 0),
  pricing_rule_id uuid references public.pricing_rules(id),
  estimated_fare numeric(10,2) not null check (estimated_fare >= 0),
  final_fare numeric(10,2) check (final_fare >= 0),
  commission_rate numeric(5,4),
  faxi_commission numeric(10,2),
  driver_earnings numeric(10,2),
  currency char(3) not null default 'DOP',
  payment_method public.payment_method not null default 'CASH',
  cancel_reason text check (char_length(cancel_reason) <= 300),
  cancelled_by uuid references public.users(id),
  requested_at timestamptz not null default now(),
  assigned_at timestamptz, arrived_at timestamptz, started_at timestamptz,
  finished_at timestamptz, completed_at timestamptz, cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trips_driver_required check (
    driver_id is not null or status in ('REQUESTED','SEARCHING','NO_DRIVER','REQUEST_TIMEOUT','DRIVER_TIMEOUT','CANCELLED','CANCELLED_BY_PASSENGER')),
  constraint trips_final_fare_required check (
    final_fare is not null or status not in ('FINISHED','PAYMENT','COMPLETED','PAYMENT_FAILED')),
  constraint trips_split_consistent check (
    final_fare is null or (faxi_commission is not null and driver_earnings is not null and faxi_commission + driver_earnings = final_fare))
);
create index trips_passenger_idx on public.trips(passenger_id, created_at desc);
create index trips_driver_idx on public.trips(driver_id, created_at desc);
create index trips_status_idx on public.trips(status);
create unique index trips_one_active_per_passenger on public.trips(passenger_id)
  where status in ('REQUESTED','SEARCHING','ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP','FINISHED','PAYMENT','PAYMENT_FAILED','DRIVER_TIMEOUT');
create unique index trips_one_active_per_driver on public.trips(driver_id)
  where driver_id is not null and status in ('ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP');

create table public.trip_requests (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  driver_id uuid not null references public.drivers(id) on delete cascade,
  status public.trip_request_status not null default 'PENDING',
  distance_to_pickup_km numeric(6,2),
  offered_at timestamptz not null default now(),
  expires_at timestamptz not null,
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (trip_id, driver_id)
);
create index trip_requests_driver_idx on public.trip_requests(driver_id, status);

-- Append-only: solo created_at.
create table public.locations (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  trip_id uuid references public.trips(id) on delete set null,
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  heading real, speed_kmh real, accuracy_m real,
  source public.location_source not null default 'SIMULATED',
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index locations_trip_idx on public.locations(trip_id, recorded_at desc);
create index locations_user_idx on public.locations(user_id, recorded_at desc);

-- ───────── Pagos, calificaciones, comunicación ─────────
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null unique references public.trips(id) on delete cascade,
  passenger_id uuid not null references public.passengers(id),
  amount numeric(10,2) not null check (amount >= 0),
  currency char(3) not null default 'DOP',
  method public.payment_method not null,
  status public.payment_status not null default 'PENDING',
  provider text not null default 'MOCK',
  provider_ref text,
  card_brand text check (card_brand is null or char_length(card_brand) <= 20),
  card_last4 char(4) check (card_last4 is null or card_last4 ~ '^[0-9]{4}$'),  -- nunca el número completo
  failure_reason text,
  attempts int not null default 0,
  paid_at timestamptz, refunded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index payments_passenger_idx on public.payments(passenger_id, created_at desc);
create index payments_status_idx on public.payments(status);

create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null unique references public.trips(id) on delete cascade,
  passenger_id uuid not null references public.passengers(id),
  driver_id uuid not null references public.drivers(id),
  rating smallint not null check (rating between 1 and 5),
  comment text check (char_length(comment) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index ratings_driver_idx on public.ratings(driver_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  sender_id uuid not null references public.users(id),
  body text not null check (char_length(body) between 1 and 1000),
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index messages_trip_idx on public.messages(trip_id, created_at);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  type text not null,
  title text not null,
  body text,
  data jsonb not null default '{}',
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications(user_id, created_at desc);

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  trip_id uuid references public.trips(id) on delete set null,
  category text not null check (category in ('COBRO','RUTA','SEGURIDAD','OBJETO_PERDIDO','CONDUCTOR','PASAJERO','OTRO')),
  subject text not null check (char_length(subject) between 3 and 120),
  body text not null check (char_length(body) between 3 and 2000),
  status public.ticket_status not null default 'OPEN',
  priority public.ticket_priority not null default 'MEDIUM',
  assigned_to uuid references public.users(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index support_tickets_status_idx on public.support_tickets(status, priority);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid,
  action text not null,
  entity text not null,
  entity_id text,
  data jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index audit_logs_entity_idx on public.audit_logs(entity, entity_id);
create index audit_logs_created_idx on public.audit_logs(created_at desc);

-- updated_at en todas las tablas que lo tienen
do $$ declare t text; begin
  foreach t in array array['app_settings','users','passengers','drivers','vehicles','driver_documents','vehicle_documents',
    'pricing_rules','commissions','trips','trip_requests','payments','ratings','messages','notifications','support_tickets']
  loop execute format('create trigger %I before update on public.%I for each row execute function public.set_updated_at()', t||'_updated_at', t); end loop;
end $$;

-- ───────── Datos de configuración inicial ─────────
insert into public.app_settings(key, value, description) values
  ('MIN_VEHICLE_YEAR', '2000', 'Año mínimo para evaluar un vehículo. No implica aprobación automática.'),
  ('REQUIRE_VEHICLE_DOCUMENTS', 'true', 'Exigir MATRICULA y SEGURO aprobados para aprobar un vehículo.'),
  ('SEARCH_WINDOW_SECONDS', '180', 'Tiempo máximo buscando conductor antes de NO_DRIVER.'),
  ('OFFER_TTL_SECONDS', '30', 'Tiempo que un conductor tiene para aceptar una solicitud.'),
  ('DISPATCH_RADIUS_KM', '8', 'Radio de búsqueda de conductores.'),
  ('PAYMENT_PROVIDER', '"MOCK"', 'MOCK permite confirmar pagos desde el cliente. Cambiar al integrar pasarela.');

insert into public.pricing_rules(category, display_name, base_fare, per_km, per_min, minimum_fare, capacity, sort_order) values
  ('ECONOMICO','Faxi Económico', 80, 30,  5, 150, 4, 1),
  ('CONFORT',  'Faxi Confort',  120, 40,  6, 200, 4, 2),
  ('PREMIUM',  'Faxi Premium',  180, 55,  8, 280, 4, 3),
  ('SUV',      'Faxi SUV',      200, 60,  9, 300, 6, 4),
  ('VAN',      'Faxi Van',      220, 65, 10, 350, 10, 5);

insert into public.commissions(category, rate) values (null, 0.20);

insert into public.trip_status_transitions(from_status, to_status, actor) values
  ('REQUESTED','SEARCHING','SYSTEM'),
  ('REQUESTED','CANCELLED_BY_PASSENGER','PASSENGER'),
  ('REQUESTED','REQUEST_TIMEOUT','SYSTEM'),
  ('SEARCHING','ASSIGNED','DRIVER'),
  ('SEARCHING','NO_DRIVER','SYSTEM'),
  ('SEARCHING','REQUEST_TIMEOUT','SYSTEM'),
  ('SEARCHING','CANCELLED_BY_PASSENGER','PASSENGER'),
  ('ASSIGNED','ENROUTE','DRIVER'),
  ('ASSIGNED','DRIVER_TIMEOUT','SYSTEM'),
  ('ASSIGNED','CANCELLED_BY_PASSENGER','PASSENGER'),
  ('ASSIGNED','CANCELLED_BY_DRIVER','DRIVER'),
  ('ENROUTE','ARRIVED','DRIVER'),
  ('ENROUTE','CANCELLED_BY_PASSENGER','PASSENGER'),
  ('ENROUTE','CANCELLED_BY_DRIVER','DRIVER'),
  ('ARRIVED','STARTED','DRIVER'),
  ('ARRIVED','CANCELLED_BY_PASSENGER','PASSENGER'),
  ('ARRIVED','CANCELLED_BY_DRIVER','DRIVER'),
  ('STARTED','ONTRIP','DRIVER'),
  ('ONTRIP','FINISHED','DRIVER'),
  ('FINISHED','PAYMENT','PASSENGER'),
  ('PAYMENT','COMPLETED','SYSTEM'),
  ('PAYMENT','PAYMENT_FAILED','SYSTEM'),
  ('PAYMENT_FAILED','PAYMENT','PASSENGER'),
  ('DRIVER_TIMEOUT','SEARCHING','SYSTEM');
-- Cancelación administrativa desde cualquier estado activo
insert into public.trip_status_transitions(from_status, to_status, actor)
select s::public.trip_status, 'CANCELLED', 'ADMIN'
from unnest(array['REQUESTED','SEARCHING','ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP','DRIVER_TIMEOUT']) s;


-- ═════════════ supabase/migrations/20261003000002_domain.sql ═════════════
-- FAXI · 002 · Lógica de dominio en el servidor (fuente de verdad)
-- Toda mutación de viajes/pagos/calificaciones pasa por estas funciones. Los clientes no tienen UPDATE sobre trips.

-- ───────── Helpers de identidad y configuración ─────────
create or replace function public.auth_role() returns public.user_role
language sql stable security definer set search_path = public as $$
  select role from public.users where id = auth.uid() and is_active
$$;
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.auth_role() in ('ADMIN','SUPER_ADMIN'), false)
$$;
create or replace function public.is_super_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.auth_role() = 'SUPER_ADMIN', false)
$$;
-- true cuando la llamada viene de SQL directo / service_role (seed, migraciones, cron)
create or replace function public.is_system_call() returns boolean
language sql stable as $$
  select coalesce(auth.role(), '') not in ('authenticated','anon')
$$;
create or replace function public.setting_num(p_key text) returns numeric
language sql stable security definer set search_path = public as $$
  select (value #>> '{}')::numeric from public.app_settings where key = p_key
$$;
create or replace function public.setting_text(p_key text) returns text
language sql stable security definer set search_path = public as $$
  select value #>> '{}' from public.app_settings where key = p_key
$$;

create or replace function public.is_trip_party(p_trip uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_admin() or exists (select 1 from public.trips where id = p_trip and (passenger_id = auth.uid() or driver_id = auth.uid()))
$$;
create or replace function public.has_pending_request(p_trip uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.trip_requests where trip_id = p_trip and driver_id = auth.uid() and status = 'PENDING')
$$;
create or replace function public.can_view_user(p_target uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p_target = auth.uid() or public.is_admin()
    or exists (select 1 from public.trips t where (t.passenger_id = auth.uid() and t.driver_id = p_target) or (t.driver_id = auth.uid() and t.passenger_id = p_target))
    or exists (select 1 from public.trip_requests r join public.trips t on t.id = r.trip_id
               where r.driver_id = auth.uid() and r.status = 'PENDING' and t.passenger_id = p_target)
$$;

create or replace function public.push_notification(p_user uuid, p_type text, p_title text, p_body text default null, p_data jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into public.notifications(user_id, type, title, body, data) values (p_user, p_type, p_title, p_body, coalesce(p_data, '{}'));
$$;
create or replace function public.log_action(p_action text, p_entity text, p_entity_id text, p_data jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into public.audit_logs(actor_id, action, entity, entity_id, data) values (auth.uid(), p_action, p_entity, p_entity_id, coalesce(p_data, '{}'));
$$;

create or replace function public.assert_in_service_area(p_lat double precision, p_lng double precision) returns void
language plpgsql immutable as $$
begin
  if p_lat is null or p_lng is null or p_lat not between 17.3 and 20.1 or p_lng not between -72.1 and -68.2 then
    raise exception 'Ubicación fuera del área de servicio' using errcode = '22023';
  end if;
end $$;

create or replace function public.assert_transition(p_from public.trip_status, p_to public.trip_status, p_actor text) returns void
language plpgsql stable set search_path = public as $$
begin
  if not exists (select 1 from public.trip_status_transitions where from_status = p_from and to_status = p_to and actor = p_actor) then
    raise exception 'Transición no permitida: % → % (%)', p_from, p_to, p_actor using errcode = 'FX409';
  end if;
end $$;

create or replace function public.faxi_health() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('ok', true, 'schema', '20261003', 'payment_provider', public.setting_text('PAYMENT_PROVIDER'), 'time', now())
$$;

-- ───────── Triggers ─────────
create or replace function public.handle_new_auth_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_role public.user_role; v_name text; v_phone text;
begin
  -- Desde el registro público solo se puede ser PASSENGER o DRIVER. ADMIN se asigna por un SUPER_ADMIN.
  v_role := case upper(coalesce(new.raw_user_meta_data->>'role', '')) when 'DRIVER' then 'DRIVER'::public.user_role else 'PASSENGER'::public.user_role end;
  v_name := left(coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''), split_part(new.email, '@', 1)), 120);
  if char_length(v_name) < 2 then v_name := 'Usuario'; end if;
  v_phone := nullif(trim(new.raw_user_meta_data->>'phone'), '');
  if v_phone is not null and v_phone !~ '^\+?[0-9 ]{10,16}$' then v_phone := null; end if;
  insert into public.users(id, role, full_name, email, phone) values (new.id, v_role, v_name, new.email, v_phone);
  if v_role = 'DRIVER' then insert into public.drivers(id) values (new.id);
  else insert into public.passengers(id) values (new.id); end if;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_auth_user();

create or replace function public.guard_user_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if public.is_system_call() then return new; end if;
  if new.id <> old.id then raise exception 'No autorizado' using errcode = '42501'; end if;
  if new.role is distinct from old.role and not public.is_super_admin() then
    raise exception 'Solo un SUPER_ADMIN puede cambiar roles' using errcode = '42501';
  end if;
  if (new.is_active is distinct from old.is_active or new.email is distinct from old.email) and not public.is_admin() then
    raise exception 'No autorizado' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger users_guard before update on public.users for each row execute function public.guard_user_update();

create or replace function public.enforce_trip_transition() returns trigger
language plpgsql as $$
begin
  if new.status is distinct from old.status and not exists (
    select 1 from public.trip_status_transitions where from_status = old.status and to_status = new.status) then
    raise exception 'Transición inválida: % → %', old.status, new.status using errcode = 'FX409';
  end if;
  return new;
end $$;
create trigger trips_enforce_transition before update of status on public.trips for each row execute function public.enforce_trip_transition();

-- Vehículo: año mínimo configurable + documentos para aprobar. Año ≥ mínimo NO implica aprobación.
create or replace function public.validate_vehicle() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_min int := coalesce(public.setting_num('MIN_VEHICLE_YEAR'), 2000)::int;
        v_docs boolean := coalesce(public.setting_text('REQUIRE_VEHICLE_DOCUMENTS')::boolean, true);
begin
  new.plate := upper(replace(new.plate, ' ', ''));
  if new.year > extract(year from now())::int + 1 then
    raise exception 'Año de vehículo inválido (%)', new.year using errcode = '23514';
  end if;
  if new.year < v_min and (tg_op = 'INSERT' or new.year is distinct from old.year or new.status = 'APPROVED') then
    raise exception 'Vehículo rechazado: año % inferior al mínimo permitido (%)', new.year, v_min using errcode = '23514';
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
create trigger vehicles_validate before insert or update on public.vehicles for each row execute function public.validate_vehicle();

create or replace function public.refresh_driver_rating() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_driver uuid := case when tg_op = 'DELETE' then old.driver_id else new.driver_id end;
begin
  update public.drivers d set rating_avg = s.avg_rating, rating_count = s.cnt
  from (select round(avg(rating)::numeric, 2) as avg_rating, count(*)::int as cnt from public.ratings where driver_id = v_driver) s
  where d.id = v_driver;
  return null;
end $$;
create trigger ratings_refresh_driver after insert or update or delete on public.ratings for each row execute function public.refresh_driver_rating();

create or replace function public.audit_row() returns trigger
language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  r := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  insert into public.audit_logs(actor_id, action, entity, entity_id, data)
  values (auth.uid(), tg_op, tg_table_name, coalesce(r->>'id', r->>'key'),
          jsonb_build_object('old', case when tg_op = 'INSERT' then null else to_jsonb(old) end, 'new', case when tg_op = 'DELETE' then null else to_jsonb(new) end));
  return null;
end $$;
create trigger audit_app_settings after insert or update or delete on public.app_settings for each row execute function public.audit_row();
create trigger audit_pricing_rules after insert or update or delete on public.pricing_rules for each row execute function public.audit_row();
create trigger audit_commissions after insert or update or delete on public.commissions for each row execute function public.audit_row();
create trigger audit_driver_status after update of status on public.drivers for each row execute function public.audit_row();
create trigger audit_vehicle_status after update of status on public.vehicles for each row execute function public.audit_row();
create trigger audit_user_role after update of role, is_active on public.users for each row execute function public.audit_row();

-- ───────── Routing (simulado) ─────────
-- Haversine × 1.35 (factor de calle) y 22 km/h promedio urbano + 2 min. Reemplazable por Directions API.
create or replace function public.route_estimate(o_lat double precision, o_lng double precision, d_lat double precision, d_lng double precision,
  out distance_km numeric, out duration_min numeric)
language plpgsql immutable as $$
declare a double precision; straight double precision;
begin
  a := sin(radians(d_lat - o_lat) / 2) ^ 2 + cos(radians(o_lat)) * cos(radians(d_lat)) * sin(radians(d_lng - o_lng) / 2) ^ 2;
  straight := 2 * 6371 * asin(sqrt(a));
  distance_km := round(greatest(straight * 1.35, 0.5)::numeric, 2);
  duration_min := round(distance_km / 22.0 * 60 + 2, 1);
end $$;

-- ───────── PricingService (servidor) ─────────
-- precio = base + km·por_km + min·por_min + recargos − descuentos, con mínimo por categoría.
create or replace function public.quote_fare(p_category public.vehicle_category, p_distance_km numeric, p_duration_min numeric, p_discount numeric default 0)
returns table(pricing_rule_id uuid, base numeric, distance_part numeric, time_part numeric, surcharge numeric, discount numeric, minimum_adj numeric, total numeric)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare r public.pricing_rules; v_sub numeric; v_raw numeric;
begin
  select * into r from public.pricing_rules pr where pr.category = p_category and pr.is_active;
  if not found then raise exception 'Categoría % no disponible', p_category using errcode = 'P0002'; end if;
  if p_distance_km is null or p_distance_km <= 0 or p_duration_min is null or p_duration_min <= 0 then
    raise exception 'Distancia o duración inválida' using errcode = '22023';
  end if;
  pricing_rule_id := r.id;
  base := r.base_fare;
  distance_part := round(p_distance_km * r.per_km, 2);
  time_part := round(p_duration_min * r.per_min, 2);
  v_sub := base + distance_part + time_part;
  surcharge := round(v_sub * (r.surge_multiplier - 1), 2);
  discount := least(greatest(coalesce(p_discount, 0), 0), v_sub + surcharge);
  v_raw := v_sub + surcharge - discount;
  minimum_adj := greatest(0, r.minimum_fare - v_raw);
  total := round(v_raw + minimum_adj, 0);
  return next;
end $$;

-- ───────── CommissionService (servidor) ─────────
create or replace function public.commission_split(p_gross numeric, p_category public.vehicle_category default null,
  out rate numeric, out faxi_commission numeric, out driver_earnings numeric)
language plpgsql stable security definer set search_path = public as $$
begin
  if p_gross is null or p_gross < 0 then raise exception 'Monto inválido' using errcode = '22023'; end if;
  select c.rate into rate from public.commissions c
  where c.is_active and (c.category = p_category or c.category is null)
  order by (c.category is null) limit 1;
  if rate is null then raise exception 'No hay comisión activa configurada' using errcode = 'P0002'; end if;
  faxi_commission := round(p_gross * rate, 2);
  driver_earnings := p_gross - faxi_commission;
end $$;

create or replace function public.quote_trip(p_origin_lat double precision, p_origin_lng double precision, p_dest_lat double precision, p_dest_lng double precision)
returns table(category public.vehicle_category, display_name text, capacity int, distance_km numeric, duration_min numeric, total numeric, minimum_fare numeric, surcharge numeric)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare e record; r record; q record;
begin
  perform public.assert_in_service_area(p_origin_lat, p_origin_lng);
  perform public.assert_in_service_area(p_dest_lat, p_dest_lng);
  select * into e from public.route_estimate(p_origin_lat, p_origin_lng, p_dest_lat, p_dest_lng);
  for r in select pr.category as cat, pr.display_name as dn, pr.capacity as cap, pr.minimum_fare as mf
           from public.pricing_rules pr where pr.is_active order by pr.sort_order loop
    select * into q from public.quote_fare(r.cat, e.distance_km, e.duration_min);
    category := r.cat; display_name := r.dn; capacity := r.cap; minimum_fare := r.mf;
    distance_km := e.distance_km; duration_min := e.duration_min; total := q.total; surcharge := q.surcharge;
    return next;
  end loop;
end $$;

-- ───────── Despacho ─────────
create or replace function public.dispatch_trip(p_trip_id uuid) returns int
language plpgsql security definer set search_path = public as $$
declare t public.trips; n int;
        v_ttl int := coalesce(public.setting_num('OFFER_TTL_SECONDS'), 30)::int;
        v_radius numeric := coalesce(public.setting_num('DISPATCH_RADIUS_KM'), 8);
begin
  select * into t from public.trips where id = p_trip_id;
  if not found or t.status <> 'SEARCHING' then return 0; end if;
  insert into public.trip_requests(trip_id, driver_id, distance_to_pickup_km, expires_at)
  select t.id, d.id, e.distance_km, now() + make_interval(secs => v_ttl)
  from public.drivers d
  join public.vehicles v on v.id = d.current_vehicle_id
  cross join lateral public.route_estimate(d.last_lat, d.last_lng, t.origin_lat, t.origin_lng) e
  where d.status = 'APPROVED' and d.availability = 'ONLINE' and v.status = 'APPROVED' and v.category = t.category
    and d.last_lat is not null and e.distance_km <= v_radius
    and not exists (select 1 from public.trip_requests r where r.trip_id = t.id and r.driver_id = d.id)
  order by e.distance_km
  limit 5
  on conflict (trip_id, driver_id) do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function public.dispatch_for_driver(p_driver_id uuid) returns int
language plpgsql security definer set search_path = public as $$
declare d public.drivers; v public.vehicles; n int;
        v_ttl int := coalesce(public.setting_num('OFFER_TTL_SECONDS'), 30)::int;
        v_radius numeric := coalesce(public.setting_num('DISPATCH_RADIUS_KM'), 8);
        v_window int := coalesce(public.setting_num('SEARCH_WINDOW_SECONDS'), 180)::int;
begin
  select * into d from public.drivers where id = p_driver_id;
  if not found or d.availability <> 'ONLINE' or d.last_lat is null then return 0; end if;
  select * into v from public.vehicles where id = d.current_vehicle_id and status = 'APPROVED';
  if not found then return 0; end if;
  insert into public.trip_requests(trip_id, driver_id, distance_to_pickup_km, expires_at)
  select t.id, d.id, e.distance_km, now() + make_interval(secs => v_ttl)
  from public.trips t
  cross join lateral public.route_estimate(d.last_lat, d.last_lng, t.origin_lat, t.origin_lng) e
  where t.status = 'SEARCHING' and t.category = v.category and e.distance_km <= v_radius
    and t.requested_at > now() - make_interval(secs => v_window)
    and not exists (select 1 from public.trip_requests r where r.trip_id = t.id and r.driver_id = d.id)
  on conflict (trip_id, driver_id) do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

-- Vencimientos. Idempotente: lo llaman los clientes mientras esperan y/o pg_cron cada 15 s.
create or replace function public.expire_stale() returns void
language plpgsql security definer set search_path = public as $$
declare r record; v_window int := coalesce(public.setting_num('SEARCH_WINDOW_SECONDS'), 180)::int;
begin
  update public.trip_requests set status = 'EXPIRED' where status = 'PENDING' and expires_at < now();
  for r in select id, passenger_id from public.trips
           where status = 'SEARCHING' and requested_at < now() - make_interval(secs => v_window)
           for update skip locked loop
    update public.trips set status = 'NO_DRIVER' where id = r.id;
    perform public.push_notification(r.passenger_id, 'NO_DRIVER', 'No encontramos conductores disponibles', 'Intenta de nuevo en unos minutos.', jsonb_build_object('trip_id', r.id));
  end loop;
  for r in select id from public.trips where status = 'SEARCHING' loop
    perform public.dispatch_trip(r.id);
  end loop;
end $$;

-- ───────── RPC · Pasajero ─────────
create or replace function public.request_trip(
  p_category public.vehicle_category,
  p_origin_address text, p_origin_lat double precision, p_origin_lng double precision,
  p_dest_address text, p_dest_lat double precision, p_dest_lng double precision,
  p_payment_method public.payment_method default 'CASH')
returns public.trips language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); e record; q record; t public.trips;
begin
  if v_uid is null or public.auth_role() is distinct from 'PASSENGER' then
    raise exception 'Solo los pasajeros pueden solicitar viajes' using errcode = '42501';
  end if;
  p_origin_address := trim(p_origin_address); p_dest_address := trim(p_dest_address);
  if coalesce(char_length(p_origin_address), 0) < 2 or coalesce(char_length(p_dest_address), 0) < 2 then
    raise exception 'Origen y destino son obligatorios' using errcode = '22023';
  end if;
  perform public.assert_in_service_area(p_origin_lat, p_origin_lng);
  perform public.assert_in_service_area(p_dest_lat, p_dest_lng);
  if abs(p_origin_lat - p_dest_lat) < 0.0005 and abs(p_origin_lng - p_dest_lng) < 0.0005 then
    raise exception 'El destino debe ser distinto del origen' using errcode = '22023';
  end if;
  if exists (select 1 from public.trips where passenger_id = v_uid and status in
      ('REQUESTED','SEARCHING','ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP','FINISHED','PAYMENT','PAYMENT_FAILED','DRIVER_TIMEOUT')) then
    raise exception 'Ya tienes un viaje activo' using errcode = '23505';
  end if;
  select * into e from public.route_estimate(p_origin_lat, p_origin_lng, p_dest_lat, p_dest_lng);
  select * into q from public.quote_fare(p_category, e.distance_km, e.duration_min);
  insert into public.trips(passenger_id, category, status, origin_address, origin_lat, origin_lng, dest_address, dest_lat, dest_lng,
                           distance_km, duration_min, pricing_rule_id, estimated_fare, payment_method)
  values (v_uid, p_category, 'REQUESTED', left(p_origin_address, 200), p_origin_lat, p_origin_lng, left(p_dest_address, 200), p_dest_lat, p_dest_lng,
          e.distance_km, e.duration_min, q.pricing_rule_id, q.total, p_payment_method)
  returning * into t;
  update public.trips set status = 'SEARCHING' where id = t.id returning * into t;
  perform public.dispatch_trip(t.id);
  perform public.log_action('TRIP_REQUESTED', 'trips', t.id::text, jsonb_build_object('category', p_category, 'estimated_fare', t.estimated_fare));
  return t;
end $$;

create or replace function public.cancel_trip(p_trip_id uuid, p_reason text default null)
returns public.trips language plpgsql security definer set search_path = public as $$
declare t public.trips; v_role public.user_role := public.auth_role(); v_to public.trip_status; v_actor text;
begin
  select * into t from public.trips where id = p_trip_id for update;
  if not found then raise exception 'Viaje no encontrado' using errcode = 'P0002'; end if;
  if v_role = 'PASSENGER' and t.passenger_id = auth.uid() then v_to := 'CANCELLED_BY_PASSENGER'; v_actor := 'PASSENGER';
  elsif v_role = 'DRIVER' and t.driver_id = auth.uid() then v_to := 'CANCELLED_BY_DRIVER'; v_actor := 'DRIVER';
  elsif v_role in ('ADMIN','SUPER_ADMIN') then v_to := 'CANCELLED'; v_actor := 'ADMIN';
  else raise exception 'No autorizado' using errcode = '42501';
  end if;
  perform public.assert_transition(t.status, v_to, v_actor);
  update public.trips set status = v_to, cancel_reason = left(p_reason, 300), cancelled_by = auth.uid(), cancelled_at = now()
  where id = t.id returning * into t;
  update public.trip_requests set status = 'CANCELLED', responded_at = now() where trip_id = t.id and status = 'PENDING';
  if t.driver_id is not null then
    update public.drivers set availability = 'ONLINE' where id = t.driver_id and availability = 'BUSY';
    if v_actor = 'DRIVER' then
      perform public.push_notification(t.passenger_id, 'TRIP_CANCELLED', 'El conductor canceló el viaje', 'Puedes solicitar otro conductor.', jsonb_build_object('trip_id', t.id));
    else
      perform public.push_notification(t.driver_id, 'TRIP_CANCELLED', 'El pasajero canceló el viaje', null, jsonb_build_object('trip_id', t.id));
    end if;
  end if;
  perform public.log_action('TRIP_CANCELLED', 'trips', t.id::text, jsonb_build_object('by', v_actor, 'reason', p_reason));
  return t;
end $$;

-- PaymentService · proveedor MOCK. Con un proveedor real, la confirmación vendrá de un webhook (Edge Function).
create or replace function public.pay_trip(p_trip_id uuid, p_method public.payment_method,
  p_card_brand text default null, p_card_last4 text default null, p_simulate_failure boolean default false)
returns public.payments language plpgsql security definer set search_path = public as $$
declare t public.trips; p public.payments;
begin
  if public.setting_text('PAYMENT_PROVIDER') is distinct from 'MOCK' then
    raise exception 'Pago simulado deshabilitado: el proveedor configurado requiere confirmación del servidor' using errcode = '42501';
  end if;
  select * into t from public.trips where id = p_trip_id for update;
  if not found or t.passenger_id is distinct from auth.uid() then raise exception 'Viaje no encontrado' using errcode = 'P0002'; end if;
  if p_method = 'CARD' then
    if p_card_last4 is null or p_card_last4 !~ '^[0-9]{4}$' then raise exception 'Tarjeta inválida' using errcode = '22023'; end if;
  else
    p_card_last4 := null; p_card_brand := null;
  end if;
  perform public.assert_transition(t.status, 'PAYMENT', 'PASSENGER');
  update public.trips set status = 'PAYMENT', payment_method = p_method where id = t.id;
  insert into public.payments(trip_id, passenger_id, amount, method, status, provider, card_brand, card_last4, attempts)
  values (t.id, t.passenger_id, t.final_fare, p_method, 'PROCESSING', 'MOCK', left(p_card_brand, 20), p_card_last4, 1)
  on conflict (trip_id) do update set method = excluded.method, status = 'PROCESSING', card_brand = excluded.card_brand,
    card_last4 = excluded.card_last4, attempts = public.payments.attempts + 1, failure_reason = null
  returning * into p;
  if p_simulate_failure then
    update public.payments set status = 'FAILED', failure_reason = 'Pago rechazado (simulado)' where id = p.id returning * into p;
    update public.trips set status = 'PAYMENT_FAILED' where id = t.id;
  else
    update public.payments set status = 'PAID', paid_at = now(), provider_ref = 'MOCK-' || substr(md5(random()::text), 1, 10) where id = p.id returning * into p;
    update public.trips set status = 'COMPLETED', completed_at = now() where id = t.id;
    update public.passengers set trips_count = trips_count + 1 where id = t.passenger_id;
    perform public.push_notification(t.driver_id, 'PAYMENT_PAID', 'Pago recibido', null, jsonb_build_object('trip_id', t.id, 'amount', p.amount));
  end if;
  perform public.log_action('PAYMENT_' || p.status, 'payments', p.id::text, jsonb_build_object('trip_id', t.id, 'method', p_method, 'provider', 'MOCK'));
  return p;
end $$;

create or replace function public.rate_trip(p_trip_id uuid, p_rating int, p_comment text default null)
returns public.ratings language plpgsql security definer set search_path = public as $$
declare t public.trips; r public.ratings;
begin
  if p_rating is null or p_rating not between 1 and 5 then raise exception 'La calificación debe ser de 1 a 5' using errcode = '22023'; end if;
  select * into t from public.trips where id = p_trip_id;
  if not found or t.passenger_id is distinct from auth.uid() then raise exception 'Viaje no encontrado' using errcode = 'P0002'; end if;
  if t.status <> 'COMPLETED' then raise exception 'Solo puedes calificar viajes completados' using errcode = 'FX409'; end if;
  insert into public.ratings(trip_id, passenger_id, driver_id, rating, comment)
  values (t.id, t.passenger_id, t.driver_id, p_rating, nullif(left(trim(p_comment), 500), ''))
  returning * into r;
  return r;
exception when unique_violation then
  raise exception 'Este viaje ya fue calificado' using errcode = '23505';
end $$;

-- ───────── RPC · Conductor ─────────
create or replace function public.set_driver_availability(p_online boolean, p_lat double precision default null, p_lng double precision default null)
returns public.drivers language plpgsql security definer set search_path = public as $$
declare d public.drivers;
begin
  if public.auth_role() is distinct from 'DRIVER' then raise exception 'Solo conductores' using errcode = '42501'; end if;
  select * into d from public.drivers where id = auth.uid() for update;
  if p_online then
    if d.status <> 'APPROVED' then raise exception 'Tu cuenta de conductor aún no está aprobada' using errcode = '42501'; end if;
    if not exists (select 1 from public.vehicles where id = d.current_vehicle_id and status = 'APPROVED') then
      raise exception 'No tienes un vehículo aprobado asignado' using errcode = '42501';
    end if;
    if p_lat is not null then perform public.assert_in_service_area(p_lat, p_lng); end if;
    if d.availability = 'BUSY' then return d; end if;
    update public.drivers set availability = 'ONLINE', last_lat = coalesce(p_lat, last_lat), last_lng = coalesce(p_lng, last_lng),
      last_location_at = case when p_lat is not null then now() else last_location_at end
    where id = d.id returning * into d;
    perform public.dispatch_for_driver(d.id);
  else
    if d.availability = 'BUSY' then raise exception 'No puedes desconectarte con un viaje en curso' using errcode = 'FX409'; end if;
    update public.drivers set availability = 'OFFLINE' where id = d.id returning * into d;
    update public.trip_requests set status = 'CANCELLED', responded_at = now() where driver_id = d.id and status = 'PENDING';
  end if;
  return d;
end $$;

create or replace function public.driver_pending_requests()
returns table(request_id uuid, trip_id uuid, trip_code text, expires_at timestamptz, distance_to_pickup_km numeric,
  origin_address text, dest_address text, distance_km numeric, duration_min numeric, estimated_fare numeric,
  estimated_earnings numeric, category public.vehicle_category, passenger_name text, passenger_rating numeric)
language plpgsql volatile security definer set search_path = public as $$
#variable_conflict use_column
begin
  if public.auth_role() is distinct from 'DRIVER' then raise exception 'Solo conductores' using errcode = '42501'; end if;
  perform public.expire_stale();
  perform public.dispatch_for_driver(auth.uid());
  return query
  select r.id, t.id, t.code, r.expires_at, r.distance_to_pickup_km, t.origin_address, t.dest_address, t.distance_km, t.duration_min,
         t.estimated_fare, (public.commission_split(t.estimated_fare, t.category)).driver_earnings, t.category, u.full_name, p.rating_avg
  from public.trip_requests r
  join public.trips t on t.id = r.trip_id
  join public.users u on u.id = t.passenger_id
  join public.passengers p on p.id = t.passenger_id
  where r.driver_id = auth.uid() and r.status = 'PENDING' and t.status = 'SEARCHING'
  order by r.offered_at;
end $$;

create or replace function public.accept_trip_request(p_request_id uuid)
returns public.trips language plpgsql security definer set search_path = public as $$
declare r public.trip_requests; d public.drivers; t public.trips;
begin
  if public.auth_role() is distinct from 'DRIVER' then raise exception 'Solo conductores' using errcode = '42501'; end if;
  select * into r from public.trip_requests where id = p_request_id and driver_id = auth.uid() for update;
  if not found then raise exception 'Solicitud no encontrada' using errcode = 'P0002'; end if;
  if r.status <> 'PENDING' or r.expires_at < now() then raise exception 'Esta solicitud ya no está disponible' using errcode = 'FX409'; end if;
  select * into d from public.drivers where id = auth.uid() for update;
  if d.availability <> 'ONLINE' then raise exception 'Debes estar disponible para aceptar viajes' using errcode = 'FX409'; end if;
  select * into t from public.trips where id = r.trip_id for update;
  if t.status <> 'SEARCHING' then raise exception 'Este viaje ya no está disponible' using errcode = 'FX409'; end if;
  perform public.assert_transition(t.status, 'ASSIGNED', 'DRIVER');
  update public.trips set status = 'ASSIGNED', driver_id = d.id, vehicle_id = d.current_vehicle_id, assigned_at = now()
  where id = t.id returning * into t;
  update public.trip_requests set status = 'ACCEPTED', responded_at = now() where id = r.id;
  update public.trip_requests set status = 'CANCELLED', responded_at = now() where trip_id = t.id and id <> r.id and status = 'PENDING';
  update public.drivers set availability = 'BUSY' where id = d.id;
  perform public.push_notification(t.passenger_id, 'TRIP_ASSIGNED', 'Tu conductor ha aceptado el viaje.', null, jsonb_build_object('trip_id', t.id));
  perform public.log_action('TRIP_ASSIGNED', 'trips', t.id::text, jsonb_build_object('driver_id', d.id));
  return t;
end $$;

create or replace function public.reject_trip_request(p_request_id uuid)
returns public.trip_requests language plpgsql security definer set search_path = public as $$
declare r public.trip_requests;
begin
  update public.trip_requests set status = 'REJECTED', responded_at = now()
  where id = p_request_id and driver_id = auth.uid() and status = 'PENDING' returning * into r;
  if not found then raise exception 'Solicitud no encontrada o ya respondida' using errcode = 'P0002'; end if;
  perform public.dispatch_trip(r.trip_id);
  return r;
end $$;

create or replace function public.driver_advance_trip(p_trip_id uuid, p_to public.trip_status)
returns public.trips language plpgsql security definer set search_path = public as $$
declare t public.trips; q record; c record; v_minutes numeric; v_msg text;
begin
  if public.auth_role() is distinct from 'DRIVER' then raise exception 'Solo conductores' using errcode = '42501'; end if;
  if p_to not in ('ENROUTE','ARRIVED','STARTED','ONTRIP','FINISHED') then raise exception 'Estado no permitido para el conductor' using errcode = 'FX409'; end if;
  select * into t from public.trips where id = p_trip_id for update;
  if not found or t.driver_id is distinct from auth.uid() then raise exception 'Viaje no encontrado' using errcode = 'P0002'; end if;
  perform public.assert_transition(t.status, p_to, 'DRIVER');
  if p_to = 'FINISHED' then
    v_minutes := greatest(t.duration_min, round((extract(epoch from now() - coalesce(t.started_at, now())) / 60.0)::numeric, 1));
    select * into q from public.quote_fare(t.category, t.distance_km, v_minutes);
    select * into c from public.commission_split(q.total, t.category);
    update public.trips set status = 'FINISHED', finished_at = now(), final_fare = q.total,
      commission_rate = c.rate, faxi_commission = c.faxi_commission, driver_earnings = c.driver_earnings
    where id = t.id returning * into t;
    update public.drivers set availability = 'ONLINE', trips_count = trips_count + 1 where id = t.driver_id;
  else
    update public.trips set status = p_to,
      arrived_at = case when p_to = 'ARRIVED' then now() else arrived_at end,
      started_at = case when p_to = 'STARTED' then now() else started_at end
    where id = t.id returning * into t;
  end if;
  v_msg := case p_to when 'ENROUTE' then 'Tu conductor va en camino.' when 'ARRIVED' then 'Tu conductor ha llegado.'
                     when 'STARTED' then 'Viaje iniciado.' when 'FINISHED' then 'Has llegado a tu destino.' end;
  if v_msg is not null then
    perform public.push_notification(t.passenger_id, 'TRIP_' || p_to, v_msg, null, jsonb_build_object('trip_id', t.id));
  end if;
  return t;
end $$;

-- LocationProvider (servidor). Solo guarda historial si hay viaje activo; si no, actualiza la última posición.
create or replace function public.update_location(p_lat double precision, p_lng double precision, p_heading real default null,
  p_speed_kmh real default null, p_accuracy_m real default null, p_source public.location_source default 'SIMULATED')
returns void language plpgsql security definer set search_path = public as $$
declare v_trip uuid; v_role public.user_role := public.auth_role();
begin
  if v_role is null then raise exception 'No autenticado' using errcode = '42501'; end if;
  perform public.assert_in_service_area(p_lat, p_lng);
  if v_role = 'DRIVER' then
    update public.drivers set last_lat = p_lat, last_lng = p_lng, last_heading = p_heading, last_location_at = now() where id = auth.uid();
    select id into v_trip from public.trips where driver_id = auth.uid() and status in ('ASSIGNED','ENROUTE','ARRIVED','STARTED','ONTRIP') limit 1;
  else
    select id into v_trip from public.trips where passenger_id = auth.uid() and status in ('ASSIGNED','ENROUTE','ARRIVED') limit 1;
  end if;
  if v_trip is not null then
    insert into public.locations(user_id, trip_id, lat, lng, heading, speed_kmh, accuracy_m, source)
    values (auth.uid(), v_trip, p_lat, p_lng, p_heading, p_speed_kmh, p_accuracy_m, p_source);
  end if;
end $$;

-- ───────── Lectura compuesta para la UI ─────────
create or replace function public.trip_details(p_trip_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare t public.trips; res jsonb;
begin
  select * into t from public.trips where id = p_trip_id;
  if not found or not (public.is_trip_party(t.id) or public.has_pending_request(t.id)) then
    raise exception 'Viaje no encontrado' using errcode = 'P0002';
  end if;
  select jsonb_build_object(
    'trip', to_jsonb(t),
    'passenger', (select jsonb_build_object('id', u.id, 'name', u.full_name, 'rating', p.rating_avg) from public.users u join public.passengers p on p.id = u.id where u.id = t.passenger_id),
    'driver', (select jsonb_build_object('id', u.id, 'name', u.full_name, 'phone', u.phone, 'rating', d.rating_avg, 'trips', d.trips_count,
                 'lat', d.last_lat, 'lng', d.last_lng, 'heading', d.last_heading)
               from public.users u join public.drivers d on d.id = u.id where u.id = t.driver_id),
    'vehicle', (select jsonb_build_object('make', v.make, 'model', v.model, 'year', v.year, 'color', v.color, 'plate', v.plate, 'category', v.category)
                from public.vehicles v where v.id = t.vehicle_id),
    'payment', (select jsonb_build_object('status', pm.status, 'method', pm.method, 'amount', pm.amount, 'card_brand', pm.card_brand, 'card_last4', pm.card_last4, 'paid_at', pm.paid_at)
                from public.payments pm where pm.trip_id = t.id),
    'rating', (select jsonb_build_object('rating', r.rating, 'comment', r.comment) from public.ratings r where r.trip_id = t.id)
  ) into res;
  return res;
end $$;

-- ───────── RPC · Admin ─────────
create or replace function public.admin_set_commission(p_rate numeric, p_category public.vehicle_category default null)
returns public.commissions language plpgsql security definer set search_path = public as $$
declare c public.commissions;
begin
  if not public.is_admin() then raise exception 'No autorizado' using errcode = '42501'; end if;
  if p_rate is null or p_rate < 0 or p_rate > 0.5 then raise exception 'La comisión debe estar entre 0 %% y 50 %%' using errcode = '22023'; end if;
  update public.commissions set is_active = false where is_active and category is not distinct from p_category;
  insert into public.commissions(category, rate, created_by) values (p_category, p_rate, auth.uid()) returning * into c;
  return c;
end $$;


-- ═════════════ supabase/migrations/20261003000003_security.sql ═════════════
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


-- ═════════════ supabase/seed.sql ═════════════
-- FAXI · Datos de demostración (ficticios). Contraseña de todas las cuentas: Faxi2026!
-- Cuentas clave:
--   pasajero@faxi.test      María Fernández (PASSENGER)
--   conductor@faxi.test     Carlos Rosario · Toyota Corolla 2005 gris · A000105 · ECONOMICO (DRIVER)
--   admin@faxi.test         (ADMIN)
--   superadmin@faxi.test    (SUPER_ADMIN)

create or replace function pg_temp.seed_user(p_id uuid, p_email text, p_name text, p_phone text, p_role text) returns void
language sql as $$
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
  values ('00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated', p_email,
    extensions.crypt('Faxi2026!', extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', jsonb_build_object('full_name', p_name, 'phone', p_phone, 'role', p_role),
    now(), now(), '', '', '', '');
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), p_id, p_id::text, jsonb_build_object('sub', p_id::text, 'email', p_email, 'email_verified', true), 'email', now(), now(), now());
$$;

-- 20 pasajeros
select pg_temp.seed_user(md5('faxi:p:' || i)::uuid,
  case when i = 1 then 'pasajero@faxi.test' else 'pasajero' || lpad(i::text, 2, '0') || '@faxi.test' end,
  (array['María Fernández','Ana Rodríguez','Lucía Santana','Gabriela Ortiz','Carmen Jiménez','Rosa Mejía','Paola Cabrera','Daniela Valdez',
         'Laura Núñez','Yesenia Batista','Pedro Almánzar','Juan Polanco','Andrés Peralta','Ricardo Tejada','Manuel Sosa',
         'Kelvin Marte','Esteban Lora','Julio Ventura','Ramón Familia','Víctor Abreu'])[i],
  '809 555 ' || lpad((100 + i)::text, 4, '0'), 'PASSENGER')
from generate_series(1, 20) i;

-- 20 conductores
select pg_temp.seed_user(md5('faxi:d:' || i)::uuid,
  case when i = 1 then 'conductor@faxi.test' else 'conductor' || lpad(i::text, 2, '0') || '@faxi.test' end,
  (array['Carlos Rosario','Rafael Peña','Carolina Méndez','Luis Almonte','José Taveras','Héctor Guzmán','Yokasta Ureña','Miguel Reyes',
         'Wilson Durán','Ramona Castillo','Francisco Brito','Elvis Encarnación','Domingo Paulino','Nelson Cruz','Félix Hernández',
         'Altagracia Pimentel','Robert Lantigua','Santo Morel','Pedro Marte','Wanda Del Rosario'])[i],
  '829 555 ' || lpad((200 + i)::text, 4, '0'), 'DRIVER')
from generate_series(1, 20) i;

-- Administración
select pg_temp.seed_user(md5('faxi:admin')::uuid, 'admin@faxi.test', 'Operaciones Faxi', '809 555 0900', 'PASSENGER');
select pg_temp.seed_user(md5('faxi:superadmin')::uuid, 'superadmin@faxi.test', 'Dirección Faxi', '809 555 0901', 'PASSENGER');
update public.users set role = 'ADMIN' where id = md5('faxi:admin')::uuid;
update public.users set role = 'SUPER_ADMIN' where id = md5('faxi:superadmin')::uuid;
delete from public.passengers where id in (md5('faxi:admin')::uuid, md5('faxi:superadmin')::uuid);

-- 20 vehículos (18–20 pendientes de revisión para probar aprobación en Admin)
insert into public.vehicles (id, driver_id, make, model, year, color, plate, category, capacity, status)
select md5('faxi:v:' || v.i)::uuid, md5('faxi:d:' || v.i)::uuid, v.make, v.model, v.year, v.color, v.plate, v.cat::public.vehicle_category, v.cap,
       (case when v.i >= 18 then 'PENDING' else 'APPROVED' end)::public.approval_status
from (values
  (1,'Toyota','Corolla',2005,'Gris','A000105','ECONOMICO',4),
  (2,'Toyota','Corolla',2021,'Blanco','A482915','ECONOMICO',4),
  (3,'Honda','Civic',2018,'Negro','A611208','ECONOMICO',4),
  (4,'Hyundai','Elantra',2020,'Plateado','A220871','ECONOMICO',4),
  (5,'Kia','Rio',2017,'Rojo','A330457','ECONOMICO',4),
  (6,'Nissan','Sentra',2019,'Azul','A773190','ECONOMICO',4),
  (7,'Toyota','Yaris',2016,'Blanco','A118340','ECONOMICO',4),
  (8,'Hyundai','Accent',2012,'Gris','A905374','ECONOMICO',4),
  (9,'Honda','Accord',2022,'Negro','A509213','CONFORT',4),
  (10,'Kia','K5',2023,'Blanco','A038162','CONFORT',4),
  (11,'Toyota','Camry',2020,'Gris','A277541','CONFORT',4),
  (12,'Mazda','6',2019,'Rojo','A640022','CONFORT',4),
  (13,'Mercedes-Benz','Clase E',2023,'Negro','A900113','PREMIUM',4),
  (14,'BMW','Serie 5',2022,'Azul','A900214','PREMIUM',4),
  (15,'Audi','A6',2021,'Gris','A900315','PREMIUM',4),
  (16,'Toyota','Highlander',2022,'Blanco','G277541','SUV',6),
  (17,'Honda','CR-V',2021,'Plateado','G509213','SUV',5),
  (18,'Hyundai','Santa Fe',2015,'Negro','G118802','SUV',6),
  (19,'Hyundai','H-1',2021,'Blanco','I038162','VAN',10),
  (20,'Toyota','Hiace',2010,'Gris','I220945','VAN',12)
) as v(i, make, model, year, color, plate, cat, cap);

-- Documentos (placeholders; los archivos reales irán a Storage)
insert into public.vehicle_documents (vehicle_id, type, file_path, status, expires_at)
select md5('faxi:v:' || i)::uuid, t::public.vehicle_document_type, 'seed/' || i || '/' || lower(t) || '.pdf',
       (case when i >= 18 then 'PENDING' else 'APPROVED' end)::public.approval_status, current_date + 300
from generate_series(1, 20) i cross join unnest(array['MATRICULA','SEGURO']) t;
insert into public.driver_documents (driver_id, type, file_path, status, expires_at)
select md5('faxi:d:' || i)::uuid, t::public.driver_document_type, 'seed/' || i || '/' || lower(t) || '.pdf',
       (case when i >= 18 then 'PENDING' else 'APPROVED' end)::public.approval_status, current_date + 500
from generate_series(1, 20) i cross join unnest(array['LICENCIA','CEDULA']) t;

-- Conductores 1–17 aprobados; todos desconectados (Carlos se conecta durante la prueba)
update public.drivers d set
  status = (case when n.i >= 18 then 'PENDING' else 'APPROVED' end)::public.approval_status,
  license_number = 'LIC-' || lpad((40000 + n.i)::text, 6, '0'),
  current_vehicle_id = md5('faxi:v:' || n.i)::uuid,
  last_lat = 18.4719 + ((n.i % 5) - 2) * 0.006, last_lng = -69.9406 + ((n.i % 7) - 3) * 0.007,
  last_location_at = now(), availability = 'OFFLINE'
from generate_series(1, 20) n(i) where d.id = md5('faxi:d:' || n.i)::uuid;

-- 50 viajes históricos
create temp table seed_places (i int primary key, name text, lat double precision, lng double precision);
insert into seed_places values
  (1,'Piantini',18.4719,-69.9406),(2,'Zona Colonial',18.4733,-69.8840),(3,'Naco',18.4796,-69.9315),(4,'Bella Vista',18.4553,-69.9461),
  (5,'Ágora Mall',18.4846,-69.9396),(6,'Malecón',18.4590,-69.9050),(7,'Aeropuerto Las Américas (SDQ)',18.4297,-69.6689),
  (8,'Gazcue',18.4650,-69.9050),(9,'Los Prados',18.4860,-69.9590),(10,'Mirador Sur',18.4460,-69.9560),
  (11,'Estadio Quisqueya',18.4882,-69.9168),(12,'Galería 360',18.4857,-69.9654);

create temp table seed_trips as
select k,
  1 + (k % 20) as pax,
  case when k <= 10 then 1 else 1 + (k % 17) end as drv,
  case when k = 1 then 1 else 1 + (k % 12) end as o,
  case when k = 1 then 2 else 1 + ((k * 5 + 3) % 12) end as d0,
  (k > 10 and k % 8 = 0) as cancelled,
  now() - make_interval(hours => k * 13, mins => (k * 17) % 60) as at
from generate_series(1, 50) k;
update seed_trips set d0 = 1 + (d0 % 12) where d0 = o;

insert into public.trips (id, passenger_id, driver_id, vehicle_id, category, status,
  origin_address, origin_lat, origin_lng, dest_address, dest_lat, dest_lng, distance_km, duration_min, pricing_rule_id,
  estimated_fare, final_fare, commission_rate, faxi_commission, driver_earnings, payment_method,
  cancel_reason, cancelled_by, requested_at, assigned_at, arrived_at, started_at, finished_at, completed_at, cancelled_at, created_at)
select md5('faxi:t:' || s.k)::uuid, md5('faxi:p:' || s.pax)::uuid,
  case when s.cancelled then null else md5('faxi:d:' || s.drv)::uuid end,
  case when s.cancelled then null else v.id end,
  v.category,
  (case when s.cancelled then 'CANCELLED_BY_PASSENGER' else 'COMPLETED' end)::public.trip_status,
  po.name, po.lat, po.lng, pd.name, pd.lat, pd.lng, e.distance_km, e.duration_min, q.pricing_rule_id,
  q.total,
  case when s.cancelled then null else q.total end,
  case when s.cancelled then null else c.rate end,
  case when s.cancelled then null else c.faxi_commission end,
  case when s.cancelled then null else c.driver_earnings end,
  (array['CASH','CARD','TRANSFER','WALLET'])[1 + s.k % 4]::public.payment_method,
  case when s.cancelled then 'Cambié de planes' end,
  case when s.cancelled then md5('faxi:p:' || s.pax)::uuid end,
  s.at,
  case when s.cancelled then null else s.at + interval '40 seconds' end,
  case when s.cancelled then null else s.at + interval '6 minutes' end,
  case when s.cancelled then null else s.at + interval '8 minutes' end,
  case when s.cancelled then null else s.at + make_interval(mins => 8 + e.duration_min::int) end,
  case when s.cancelled then null else s.at + make_interval(mins => 9 + e.duration_min::int) end,
  case when s.cancelled then s.at + interval '1 minute' end,
  s.at
from seed_trips s
join seed_places po on po.i = s.o
join seed_places pd on pd.i = s.d0
join public.vehicles v on v.id = md5('faxi:v:' || s.drv)::uuid
cross join lateral public.route_estimate(po.lat, po.lng, pd.lat, pd.lng) e
cross join lateral public.quote_fare(v.category, e.distance_km, e.duration_min) q
cross join lateral public.commission_split(q.total, v.category) c;

insert into public.payments (trip_id, passenger_id, amount, method, status, provider, provider_ref, card_brand, card_last4, attempts, paid_at, created_at)
select t.id, t.passenger_id, t.final_fare, t.payment_method, 'PAID', 'MOCK', 'MOCK-SEED-' || substr(t.id::text, 1, 8),
  case when t.payment_method = 'CARD' then 'Visa' end, case when t.payment_method = 'CARD' then '4242' end, 1, t.completed_at, t.completed_at
from public.trips t where t.status = 'COMPLETED';

-- Calificaciones: Carlos (viajes 1–10) promedia 4.9
insert into public.ratings (trip_id, passenger_id, driver_id, rating, comment, created_at)
select t.id, t.passenger_id, t.driver_id,
  case when s.k <= 10 then (case when s.k = 5 then 4 else 5 end) else (case when s.k % 3 = 0 then 4 else 5 end) end,
  case when s.k % 4 = 1 then 'Muy amable y puntual.' when s.k % 4 = 2 then 'Carro limpio, buena ruta.' end,
  t.completed_at + interval '2 minutes'
from public.trips t join seed_trips s on t.id = md5('faxi:t:' || s.k)::uuid
where t.status = 'COMPLETED';

update public.drivers d set trips_count = x.n from (select driver_id, count(*)::int n from public.trips where status = 'COMPLETED' group by driver_id) x where d.id = x.driver_id;
update public.passengers p set trips_count = x.n from (select passenger_id, count(*)::int n from public.trips where status = 'COMPLETED' group by passenger_id) x where p.id = x.passenger_id;

insert into public.support_tickets (user_id, trip_id, category, subject, body, priority)
values (md5('faxi:p:2')::uuid, md5('faxi:t:12')::uuid, 'COBRO', 'Cobro mayor al estimado', 'El precio final fue más alto que lo que vi al pedir.', 'MEDIUM'),
       (md5('faxi:d:5')::uuid, md5('faxi:t:21')::uuid, 'OBJETO_PERDIDO', 'Mochila olvidada', 'El pasajero dejó una mochila negra en el asiento trasero.', 'HIGH');

drop table seed_trips; drop table seed_places;

