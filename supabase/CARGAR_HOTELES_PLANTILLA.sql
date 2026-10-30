-- FAXI · PLANTILLA para cargar hoteles y zonas de taxis turísticos en Zonas (tabla restricted_zones).
-- NO se ejecuta tal cual: tiene marcadores PON_AQUI_ y, mientras queden, se detiene sin guardar nada.
-- La corre solo el dueño (o Claude con su permiso), primero en faxi-pruebas y después, con visto bueno, en producción.
-- Alternativa sin SQL: cada lugar se agrega a mano desde el panel → Zonas (ver docs/HOTELES_ZONAS.md).
--
-- Cómo llenarla: una línea por lugar, con nombre, tipo y las coordenadas de la PUERTA PRINCIPAL sacadas de Google Maps.
--   tipo: 'HOTEL' (hotel) · 'TAXI_TURISTICO' (zona de taxis turísticos) · 'OTRA'.
--   latitud y longitud con punto decimal, por ejemplo 18.47190 y -69.94060 (la longitud lleva signo menos).
-- El radio es de 200 m (regla del INTRANT). No lo cambies sin avisar al dueño.
-- Los lugares con el mismo nombre que ya existan se saltan: se puede correr más de una vez.
-- Las zonas de AEROPUERTO no van aquí: no prohíben recoger y su recargo lo cambia solo un SUPER_ADMIN desde el panel.

insert into public.restricted_zones(name, kind, lat, lng, radius_m)
select v.name, v.kind, v.lat, v.lng, 200
from (values
  ('PON_AQUI_NOMBRE_DEL_HOTEL', 'HOTEL', 0.0, 0.0)
  -- , ('PON_AQUI_OTRO_HOTEL', 'HOTEL', 0.0, 0.0)
  -- , ('PON_AQUI_ZONA_DE_TAXIS_TURISTICOS', 'TAXI_TURISTICO', 0.0, 0.0)
) as v(name, kind, lat, lng)
where v.name not like 'PON\_AQUI\_%'
  and not exists (select 1 from public.restricted_zones z where lower(z.name) = lower(v.name));

-- Si ves "0 rows" es porque todavía quedan marcadores PON_AQUI_ o los lugares ya estaban cargados.
-- Para comprobar: select name, kind, lat, lng, radius_m, is_active from public.restricted_zones order by name;
