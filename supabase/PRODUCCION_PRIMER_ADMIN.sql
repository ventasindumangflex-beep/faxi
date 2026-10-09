-- SOLO PRODUCCIÓN (faxi, ref opehqsltrzhtsqqlctdg). Crea el primer SUPER_ADMIN del panel.
-- Paso 1: Supabase → faxi → Authentication → Users → "Add user" → "Create new user":
--         correo + contraseña fuerte, marcar "Auto Confirm User".
-- Paso 2: cambiar el correo de abajo si usaste otro, pegar esto en el SQL Editor y Run.
do $$
declare v_email text := 'ventasindumangflex@gmail.com';   -- ← el correo del paso 1
begin
  update public.users set role = 'SUPER_ADMIN', full_name = case when full_name = 'Usuario' then 'Administrador faxi' else full_name end
  where lower(email) = lower(v_email);
  if not found then
    raise exception 'No existe un usuario con el correo %. Créalo primero en Authentication → Users.', v_email;
  end if;
  -- Un SUPER_ADMIN no debe tener ficha de pasajero
  delete from public.passengers where id = (select id from public.users where lower(email) = lower(v_email));
  raise notice 'Listo: % es SUPER_ADMIN. Entra al panel con ese correo y contraseña.', v_email;
end $$;
