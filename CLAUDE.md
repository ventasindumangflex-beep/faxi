# FAXI — instrucciones para Claude Code

Plataforma de movilidad para Santo Domingo (RD). Idioma de la UI: español dominicano. Moneda: DOP (RD$). Zona horaria: America/Santo_Domingo.

## Estado
- `supabase/`: backend escrito (esquema, RPC, RLS, seed, test). **Aún no aplicado.** Fuente de verdad del dominio.
- `*.dc.html` + `faxi-core.js`: prototipo de referencia visual y de flujo (datos simulados). No es código de producción.
- Plan: `docs/PLAN_TECNICO.md`. Setup: `docs/SUPABASE_SETUP.md`. Arquitectura: `ARCHITECTURE.md`.

## Objetivo
Monorepo con `apps/passenger` (Expo), `apps/driver` (Expo), `apps/admin` (Next.js), `packages/core`, `packages/ui`, más `supabase/`.

## Reglas
- No rediseñar: replicar pantallas, textos y flujos del prototipo.
- Las apps nunca calculan precio, comisión ni estado: siempre RPC de Supabase.
- Nunca usar la service_role key en apps ni en el admin del navegador.
- Cada cambio de base de datos va en una nueva migración en `supabase/migrations/` con su test en `supabase/tests/`.
- No guardar números de tarjeta; solo marca y últimos 4.
- Una tarea a la vez; al terminar, explicar cómo probarla.
