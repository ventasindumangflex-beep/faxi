-- FAXI · Crea el usuario ADMIN de Virgilio (NO SUPER_ADMIN). PREPARADO, NO EJECUTADO.
-- Lo corre SOLO el dueño (o Claude con su permiso expreso), cuando Virgilio ya creó su cuenta.
-- Primero en faxi-pruebas; en producción, solo con el visto bueno del dueño.
--
-- Paso 1 (el dueño): Supabase → Authentication → Users → "Add user" → "Create new user" con el correo de Virgilio.
--   Virgilio escribe su propia contraseña. Marcar "Auto Confirm User". La contraseña NO se escribe en ningún archivo.
-- Paso 2: cambiar PON_AQUI_CORREO_DE_VIRGILIO (abajo) por ese correo, pegar en el SQL Editor y Run.
--   El teléfono de Virgilio no se necesita para el panel: no lo pongas aquí.
-- Un ADMIN ve conductores, viajes y comisiones y puede aprobar conductores y registrar pagos. No cambia ajustes, tarifas
-- ni recargos, ni anula pagos, ni toca a otros admins (eso es solo del SUPER_ADMIN; migración 014).
do $$
declare v_email text := 'PON_AQUI_CORREO_DE_VIRGILIO';   -- ← el correo del paso 1
        v_id uuid; v_role public.user_role;
begin
  if v_email like 'PON\_AQUI\_%' then
    raise exception 'ABORTADO: escribe el correo de Virgilio en la línea marcada (PON_AQUI_CORREO_DE_VIRGILIO).';
  end if;
  select id, role into v_id, v_role from public.users where lower(email) = lower(v_email);
  if v_id is null then
    raise exception 'No existe un usuario con el correo %. Créalo primero en Authentication → Users.', v_email;
  end if;
  if v_role = 'SUPER_ADMIN' then
    raise exception 'Ese correo ya es SUPER_ADMIN. No se baja de rango desde este archivo.';
  end if;
  update public.users set role = 'ADMIN', full_name = case when full_name = 'Usuario' then 'Virgilio' else full_name end where id = v_id;
  -- Un admin no necesita ficha de pasajero (solo se borra si nunca ha pedido viajes)
  delete from public.passengers p where p.id = v_id and not exists (select 1 from public.trips t where t.passenger_id = p.id);
  raise notice 'Listo: % ahora es ADMIN. Entra al panel con ese correo y su contraseña.', v_email;
end $$;
