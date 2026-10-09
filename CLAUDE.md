# CLAUDE.md · contexto para Claude Code

Proyecto: **faxi**, plataforma de viajes en Santo Domingo (RD). Moneda DOP, idioma español dominicano, pago solo en efectivo por ahora.
Lee `README.md` y `docs/PLAN_TECNICO.md` antes de cambiar algo.

## Reglas
- **El servidor manda.** Precio, comisión, estados y despacho se calculan en Postgres. Las apps solo leen tablas (RLS) y escriben con RPC. No dupliques lógica de negocio en el cliente.
- Nuevas reglas de negocio = **nueva migración** `supabase/migrations/AAAAMMDDHHMMSS_nombre.sql` + test en `supabase/tests/` que termine en `ROLLBACK` y emita un `NOTICE ... OK`. Nunca edites migraciones ya aplicadas.
- Toda función nueva: `security definer set search_path = public`, `revoke ... from public, anon` y `grant ... to authenticated` explícitos.
- Errores para el usuario con `errcode`: `42501` permiso, `FX409` estado inválido, `22023` dato inválido, `23505` duplicado, `P0002` no encontrado. El mensaje debe estar en español y ser mostrable.
- Llamadas a Supabase solo desde `packages/core/src/api.ts` (y realtime.ts). Las pantallas no llaman `sb()` directamente (excepción: admin).
- UI móvil: usa `@faxi/ui` (tokens en `packages/ui/src/tokens.ts`). Objetivos táctiles ≥ 44 px. Textos de permisos claros.
- Nunca pongas la `service_role` key en una app. Solo en Edge Functions.
- Viajes con mala conexión: toda pantalla de viaje debe recuperarse al reabrir la app (`activeTrip()`).

## Comandos
- `npm install` en la raíz · `npm run passenger` · `npm run driver` · `npm run admin`
- `cd apps/<app> && npx expo install --fix` tras actualizar el SDK
- `npx tsc --noEmit -p apps/<app>` para revisar tipos
- Tests SQL: con el MCP de Supabase, ejecuta `supabase/tests/*.sql`

## Estado (octubre 2026)
Hecho: migraciones 001–008 (005 ubicación privada + zona real + push automático, 006 solo efectivo, 007 datos del conductor solo durante el viaje, 008 endurecimiento), login OTP, alta de conductor con documentos, despacho, viaje completo, cobro en efectivo, calificación, push, borrado de cuenta, panel admin, Sentry, íconos, borradores legales (`apps/admin/src/legal/`, servidos en /privacidad, /terminos, /terminos-conductores, /eliminar-cuenta), fichas de tienda (`docs/tiendas/FICHAS.md`).
Producción (faxi) va por detrás: se pone al día pegando `supabase/PRODUCCION_PEGAR.sql` (ver `docs/PASOS_DEL_DUENO.md`).
Siguiente: probar en teléfonos reales con un piloto cerrado. Lista completa: `docs/PENDIENTES_PRODUCCION.md`.

## Reglas fijas de base de datos (no negociables)
Proyectos Supabase: **faxi** = producción (ref `opehqsltrzhtsqqlctdg`) · **faxi-pruebas** = solo pruebas (ref en `.env` → `SUPABASE_TEST_PROJECT_REF`).
1. `supabase/seed.sql` y todos los `supabase/tests/*.sql` corren SOLO en faxi-pruebas. Nunca en faxi.
2. Antes de cualquier comando contra la base de datos, confirmar en voz alta a qué proyecto (ref) se está conectado.
3. Todo cambio de esquema va primero en faxi-pruebas. Solo cuando las dos pruebas den `FAXI OK` y `FAXI MÓVIL OK` se aplica en faxi, y solo con el visto bueno explícito del dueño.
4. Credenciales (refs de prueba, contraseñas, tokens) solo en `.env`; nunca en un commit.
5. Si una prueba falla, se arregla la migración, nunca la prueba.
