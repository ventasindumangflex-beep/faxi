-- FAXI · Huella del esquema (SOLO LECTURA: únicamente SELECT; es seguro correrla en producción).
-- Uso: pegar en el SQL Editor de cada proyecto (faxi-pruebas y faxi) y comparar el resultado.
-- Referencia de faxi-pruebas (ref en .env → SUPABASE_TEST_PROJECT_REF), 29-oct-2026 (con las migraciones 001–015), con ESTA consulta:
--   Medido con 001–015: tablas 22 · funciones 73 · politicas 44 · triggers 37 · indices 55 · cron 2 · anon_puede_borrar_cuenta false · comision 0.1000 · limite_deuda 1000
--   Medido con 001–020 (30-oct-2026): tablas 23 · funciones 80 · politicas 44 · triggers 41 · indices 57 · cron 4 · anon_puede_borrar_cuenta false · comision 0.1000 · limite_deuda 1000
--   (antes: 15-oct con 009–012, funciones 64 · triggers 35 · cron 1; la 014 agrega 2 funciones y 1 trigger;
--    la 015 agrega 7 funciones, 1 trigger y la revisión diaria de documentos vencidos en cron)
-- Si faxi (producción) da otros números, falta algo por aplicar o sobra algo; NO se arregla a ciegas: avisar antes de tocar producción.
select
 (select count(*) from pg_tables where schemaname='public') as tablas,
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public') as funciones,
 (select count(*) from pg_policies where schemaname in ('public','storage')) as politicas,
 (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where not t.tgisinternal and n.nspname='public') as triggers,
 (select count(*) from pg_indexes where schemaname='public') as indices,
 (select count(*) from cron.job) as cron,
 has_function_privilege('anon','public.delete_my_account()','execute') as anon_puede_borrar_cuenta,
 (select rate from public.commissions where is_active and category is null) as comision,
 public.commission_debt_limit() as limite_deuda;
