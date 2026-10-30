-- FAXI · 019 · Los ajustes del sistema no se leen por RPC (30-oct-2026)
-- Hallazgo: setting_text() y setting_num() son SECURITY DEFINER y estaban abiertas a cualquier usuario con sesión.
-- Un pasajero podía llamar setting_text('COMMISSION_PAY_INFO') y leer la cuenta de pago de las comisiones, saltándose la
-- regla de la 010 (solo admins y conductores aprobados). Las apps no las llaman; solo las usan otras funciones SECURITY DEFINER,
-- que corren con los permisos del dueño y no necesitan que el usuario tenga EXECUTE.
-- Se puede correr más de una vez.

revoke all on function public.setting_text(text) from public, anon, authenticated;
revoke all on function public.setting_num(text) from public, anon, authenticated;
