-- FAXI · Huella del esquema (SOLO LECTURA: únicamente SELECT; es seguro correrla en producción).
-- Uso: pegar en el SQL Editor de cada proyecto (faxi-pruebas y faxi) y comparar el resultado.
-- Referencia de faxi-pruebas (ref en .env → SUPABASE_TEST_PROJECT_REF), 15-oct-2026 (con las migraciones 009–012), con ESTA consulta:
--   tablas 22 · funciones 64 · politicas 44 · triggers 35 · indices 55 · cron 1 · anon_puede_borrar_cuenta false
-- Si faxi (producción) da otros números, falta algo por aplicar o sobra algo; NO se arregla a ciegas: avisar antes de tocar producción.
select
 (select count(*) from pg_tables where schemaname='public') as tablas,
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public') as funciones,
 (select count(*) from pg_policies where schemaname in ('public','storage')) as politicas,
 (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where not t.tgisinternal and n.nspname='public') as triggers,
 (select count(*) from pg_indexes where schemaname='public') as indices,
 (select count(*) from cron.job) as cron,
 has_function_privilege('anon','public.delete_my_account()','execute') as anon_puede_borrar_cuenta;
