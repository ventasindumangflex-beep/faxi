# FAXI · Configurar Supabase

## Lo que falta (no lo tengo)
- `SUPABASE_URL` y `SUPABASE_ANON_KEY` de tu proyecto. Sin ellas la app sigue en **modo MOCK**.

## Opción A · Proyecto en la nube
1. Crea un proyecto en supabase.com (región más cercana: `us-east-1`).
2. SQL Editor → ejecuta en orden:
   - `supabase/migrations/20261003000001_schema.sql`
   - `supabase/migrations/20261003000002_domain.sql`
   - `supabase/migrations/20261003000003_security.sql`
   - `supabase/seed.sql`
3. Ejecuta `supabase/tests/001_trip_flow.sql`. Debe mostrar `FAXI OK …` y no deja datos.
4. Settings → API: copia URL y anon key a `env.js` (a partir de `env.example.js`).
5. Authentication → Providers → Email: activo. Para el MVP puedes desactivar "Confirm email".
6. Opcional: Database → Extensions → `pg_cron` y descomenta el bloque final de `003_security.sql` (vencimientos automáticos). Sin cron, los clientes llaman `expire_stale()` mientras esperan.

## Opción B · Local (Supabase CLI + Docker)
```
supabase init        # si no existe supabase/config.toml
supabase start
supabase db reset    # aplica migraciones + seed.sql
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/tests/001_trip_flow.sql
```

## Cuentas demo (contraseña `Faxi2026!`)
| Rol | Correo |
|---|---|
| Pasajero | pasajero@faxi.test |
| Conductor (Carlos · Corolla 2005 · A000105 · Económico) | conductor@faxi.test |
| Admin | admin@faxi.test |
| Super admin | superadmin@faxi.test |

Para la prueba E2E, el pasajero debe pedir **Faxi Económico** (categoría de Carlos) dentro de ~8 km de Piantini.

## Seguridad
- Los clientes **no** pueden escribir en `trips`, `payments`, `ratings`, `trip_requests`: solo vía RPC (`request_trip`, `accept_trip_request`, `driver_advance_trip`, `pay_trip`, `rate_trip`, `cancel_trip`).
- Cada RPC valida rol (`auth_role()`), propiedad del viaje y la transición (`trip_status_transitions`). Un trigger vuelve a validar cualquier cambio de estado.
- Rol solo lo cambia un SUPER_ADMIN (trigger `users_guard`). El registro público solo crea PASSENGER o DRIVER.
- `pay_trip` funciona únicamente con `app_settings.PAYMENT_PROVIDER = "MOCK"`. Al integrar una pasarela, la confirmación debe venir de un webhook en Edge Function con la service_role key.
- Nunca se guarda el número de tarjeta: solo marca y últimos 4.
