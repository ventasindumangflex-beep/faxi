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
-- Una activa por categoría y una por defecto (category null). Dos índices parciales: el cast enum::text no es IMMUTABLE.
create unique index commissions_one_active on public.commissions(category) where is_active and category is not null;
create unique index commissions_one_active_default on public.commissions((true)) where is_active and category is null;

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
