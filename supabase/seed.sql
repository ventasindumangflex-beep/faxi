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
