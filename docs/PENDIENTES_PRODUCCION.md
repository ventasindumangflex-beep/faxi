# Pendientes antes de publicar faxi

Estado al 9-oct-2026. Lo marcado [x] está hecho y probado; lo demás sigue pendiente.

## Hecho la noche del 8 al 9 de octubre
- [x] Código unido a `main` (PR #1).
- [x] **Ubicación en vivo privada:** canales `trip:<id>` privados con políticas en `realtime.messages`. Solo escuchan el pasajero y el conductor del viaje (y admins), solo transmite el conductor, y solo mientras el viaje está en curso (migración 005, test 003).
- [x] **Datos del conductor solo durante el viaje:** antes, un pasajero con un viaje viejo podía seguir leyendo la ubicación y el teléfono del conductor. Cerrado en `trip_details` y `can_view_user` (migración 007, test 005).
- [x] **Zona de servicio real:** Distrito Nacional + provincia Santo Domingo (geoBoundaries) con ~1 km de margen. Santiago, Juan Dolio, San Cristóbal y Monte Plata quedan fuera (migración 005).
- [x] **Push automático:** trigger `notifications_push` (pg_net + Vault) llama a `send-push`; ya no hace falta el webhook manual. Desplegado y probado en faxi-pruebas: respuesta 200.
- [x] **Solo efectivo en producción:** con `PAYMENT_PROVIDER = CASH` el pasajero no puede marcarse pagos y no se crean viajes con tarjeta (migración 006, test 004).
- [x] **Endurecimiento** según el asesor de seguridad de Supabase (migración 008).
- [x] **Sentry** en las dos apps (se activa al poner `EXPO_PUBLIC_SENTRY_DSN`).
- [x] **Íconos, ícono adaptativo, pantalla de inicio e ícono de notificación** (`scripts/make_icons.py`).
- [x] **Borradores legales** publicados como páginas del panel: `/privacidad`, `/terminos`, `/terminos-conductores`, `/eliminar-cuenta` (fuente en `apps/admin/src/legal/`).
- [x] **Fichas de tienda** en `docs/tiendas/FICHAS.md`.
- [x] Verificación: tipos sin errores en las 3 apps; las 2 apps móviles empaquetan (Android e iOS); el panel compila; pruebas 001, 002, 003, 004 y 005 pasan en faxi-pruebas sin dejar datos.

## Lo que tiene que hacer el dueño (ver `docs/PASOS_DEL_DUENO.md`)
- [ ] **Rotar la clave `sb_secret_…` de faxi-pruebas** que se pegó en el chat.
- [ ] **Producción:** pegar `supabase/PRODUCCION_PEGAR.sql` en el SQL Editor de faxi y comparar la huella. Claude no tiene acceso a faxi (producción).
- [ ] **Desplegar `send-push` en producción** (Edge Functions → Deploy, sin verificación JWT).
- [ ] **Primer admin:** crear el usuario en Authentication y correr `supabase/PRODUCCION_PRIMER_ADMIN.sql`.
- [ ] **Realtime:** en faxi y faxi-pruebas → Realtime → Settings, desactivar *Allow public access* (así solo existen canales privados).
- [ ] **Probar en el teléfono** con la guía `docs/GUIA_PASOS_1_A_4.md`.
- [ ] Twilio Verify en Supabase Auth (Phone) y límite de SMS; número de prueba para los revisores de Apple/Google.
- [ ] Crear el proyecto en Sentry y poner el DSN en EAS.
- [ ] Publicar el panel (Vercel) para que las páginas legales tengan URL, y poner esas URL en `EXPO_PUBLIC_TERMS_URL` / `EXPO_PUBLIC_PRIVACY_URL`.
- [ ] Completar los datos entre corchetes de los textos legales y **revisión de un abogado** (Ley 172-13, Ley 358-05, INTRANT).

## Producto
- [ ] **INTRANT:** confirmar requisitos vigentes para plataformas (registro, seguro de responsabilidad civil, carnet de conductores, antigüedad máxima del vehículo; en 2021 se anunciaron 15 años). Hoy `MIN_VEHICLE_YEAR = 2000`: ajustar en `app_settings` cuando se confirme.
- [ ] **Comisión en efectivo:** definir cómo y cuándo el conductor paga a faxi el 20 % de los viajes en efectivo (los términos de conductores lo dejan en blanco).
- [ ] Haina y otros destinos cercanos fuera de la zona: decidir si se amplía el polígono (`app_settings.SERVICE_AREA`).
- [ ] Capturas de pantalla para las tiendas (lista en `docs/tiendas/FICHAS.md`).

## Tiendas
- [ ] Builds de producción (`eas build --profile production`) y fichas (textos listos en `docs/tiendas/FICHAS.md`).
- [ ] **Google Play:** declaración y video de ubicación en segundo plano (guion listo); cuenta de organización (D-U-N-S) o prueba cerrada de 12 testers por 14 días.
- [ ] **Apple:** cuenta de organización; notas de revisión listas.

## Operación
- [ ] Piloto cerrado con 10–20 conductores y 30–50 pasajeros; proceso de aprobación de conductores definido.
- [ ] `seed.sql` y los tests **nunca** en producción.

## Notas técnicas
- `apply_migration`/`execute_sql` de la herramienta de Supabase piden confirmación con `DROP`/`DELETE`; las migraciones nuevas usan bloques `if not exists` para evitarlos.
- `delete_my_account` deja la bandera `faxi.self_delete` activa hasta el final de la transacción. En la app cada llamada es su propia transacción; en tests, no hacer otras comprobaciones del guard después de llamarla.
