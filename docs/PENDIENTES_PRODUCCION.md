# Pendientes antes de publicar faxi

> Lista ordenada por etapas (prueba interna → piloto → público) en `docs/LANZAMIENTO.md`.

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
- [ ] Publicar `sitio/` en faxi.com con Netlify (pasos en `docs/LANZAMIENTO.md`). Las apps ya abren `https://faxi.com/...` por defecto; el panel se queda en la Mac durante el piloto.
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
- [x] Función `send-push` en faxi-pruebas: desplegada (v2, `verify_jwt=false`, se autentica con `x-faxi-secret`) y llamada por el trigger de la migración 005 con el Vault (`faxi_push_url`, `faxi_push_secret`); respuesta 200. **No** hace falta webhook ni `PUSH_WEBHOOK_SECRET` (un webhook duplicaría los avisos). En producción falta desplegarla (paso 3 de `PASOS_DEL_DUENO.md`).
- [ ] Piloto cerrado con 10–20 conductores y 30–50 pasajeros; proceso de aprobación de conductores definido.
- [ ] `seed.sql` y los tests **nunca** en producción.

## Problemas encontrados en las fases 1–7
- **Corregido:** migración 001, índice `commissions_one_active` usaba `category::text` (no inmutable) y fallaba. Ahora son dos índices parciales con la misma garantía.
- **Limitación de la herramienta:** `apply_migration`/`execute_sql` agotan 60 s con SQL que contiene `DELETE`. Aplicar esas piezas desde el SQL Editor o con CLI/API con acceso de red.
- **Pendiente de revisar:** el test `002_mobile.sql` depende de `delete_my_account` y de un `SUPER_ADMIN` del seed; solo puede correr en faxi-pruebas.
- **Corregido (11-oct-2026):** el primer build de Android fallaba con `Namespace 'do.faxi.app' is not a valid Java package name as 'do' is a Java keyword`. El paquete de Android ahora es `com.faxi.app` / `com.faxi.conductor` (iOS conserva `do.faxi.*`, que es válido). **El paquete de Android es permanente una vez publicado en Google Play**: confirmarlo antes de la primera publicación.

## Estado de la prueba en teléfono (11-oct-2026)
- **Funciona:** build de desarrollo del pasajero (Android `com.faxi.app`), login por SMS con número verificado en Twilio, sugerencias de direcciones (Places API New activada).
- **Pendiente: mapa en blanco** en la pantalla principal. El código usa `PROVIDER_GOOGLE` correctamente; Google no entrega los mapas. Revisar, en orden: (1) que `faxi-maps-android` tenga guardado el paquete `com.faxi.app` en minúsculas y la SHA-1 del keystore de `faxi.app/projects/faxi` (idéntica a la de Expo → Credentials → Android); (2) métricas de *Maps SDK for Android* (¿403? ¿0 solicitudes?); (3) que `GOOGLE_MAPS_ANDROID_KEY` en Expo tenga el valor de esa clave y que el build instalado sea posterior al cambio. La restricción de la clave se dejó en "Apps para Android" tras una prueba temporal con "Ninguno"; confirmar que quedó guardada.
- **13-oct-2026:** como quitar la restricción de apps no cambió nada, lo más probable es que la clave guardada en Expo sea otra o tenga espacios o comillas. Solución: clave nueva (`docs/MAPA_ANDROID.md`). La app ahora limpia la clave, el build de EAS para Android falla si falta o está mal formada, y `FaxiMap` (`packages/ui/src/maps.tsx`) avisa si el mapa no carga en 15 s.
- **Twilio:** el SMS solo llega a números verificados como Caller ID (error 21608). Para pasajeros reales hace falta el Perfil de Cumplimiento Primario aprobado.
- **Seguridad:** la clave de Maps se pegó por error en un cuadro de chat; regenerarla antes de producción.

## Producción (12-oct-2026)
- **El proyecto de producción `faxi` (ref `opehqsltrzhtsqqlctdg`) NO aparece** en la cuenta de Supabase `ventasindumangflex@gmail.com` (login GitHub `ventasindumangflex-beep`): su única organización `faxi` solo contiene `faxi-pruebas`. Puede estar en otra cuenta, pausado o eliminado. Aún no hay usuarios ni viajes reales, así que no se pierde nada.
- **Decisión pendiente del dueño:** (a) localizarlo en otra cuenta, o (b) crear un proyecto de producción nuevo en plan de pago antes del piloto y aplicarle las migraciones 001–004 + cron (primero verificado en pruebas, con visto bueno explícito). Hasta decidir, no se toca ningún proyecto de producción.
- Mientras tanto `supabase/HUELLA_ESQUEMA.sql` sirve para verificar cualquier proyecto nuevo contra la referencia de faxi-pruebas.

## Dependencia: constituir la empresa de faxi (decisión del dueño, 12-oct-2026)
No se registran cuentas de producción a nombre personal. Primero se crea la entidad y su RNC; después se usan sus datos en:
- **Twilio**: Primary Business Profile en Trust Hub (necesario para enviar SMS a números no verificados).
- **Google Play** (cuenta de organización, D-U-N-S) y **Apple Developer** (organización).
- **Supabase de producción** (organización y facturación), **Google Cloud** (facturación de Maps/Places) y **Expo/EAS** (cuenta/equipo del negocio).
- Términos y política de privacidad con razón social y datos de contacto reales.
Mientras tanto: pruebas con números verificados como Caller ID en Twilio.

## iPhone / iOS (decisión 11-oct-2026)
- **Expo Go no sirve en iPhone para este proyecto**: la App Store solo ofrece Expo Go de SDK 57 y faxi usa SDK 54 (el error aparece al abrir el QR). Subir a SDK 57 se descartó por riesgo y esfuerzo.
- **Camino elegido:** probar y arrancar el piloto en Android; para iPhone, hacer un build de desarrollo/TestFlight con cuenta **Apple Developer de organización** (99 USD/año, requiere D-U-N-S y datos de la empresa de faxi). iOS usa Apple Maps (`PROVIDER_DEFAULT`), así que no depende de la clave de Google Maps.
- La app **no se ha probado en iOS**: esperar posibles errores propios de la plataforma en el primer build.

## Notas técnicas
- `apply_migration`/`execute_sql` de la herramienta de Supabase piden confirmación con `DROP`/`DELETE`; las migraciones nuevas usan bloques `if not exists` para evitarlos.
- `delete_my_account` deja la bandera `faxi.self_delete` activa hasta el final de la transacción. En la app cada llamada es su propia transacción; en tests, no hacer otras comprobaciones del guard después de llamarla.

## Dominio (decisión del dueño, 13-oct-2026)
- **Dominio definitivo: `faxi.com`.** Las apps abren `https://faxi.com/terminos`, `/terminos-conductores` y `/privacidad` por defecto (cambiables con `EXPO_PUBLIC_TERMS_URL` / `EXPO_PUBLIC_PRIVACY_URL`).
- Falta: confirmar en la Consola del administrador de Google Workspace que `faxi.com` esté **verificado** y con registros MX; crear `soporte@faxi.com`; publicar las 4 páginas legales (`/privacidad`, `/terminos`, `/terminos-conductores`, `/eliminar-cuenta`) en esa dirección; rellenar los campos entre corchetes de los borradores (razón social, RNC, dirección, correos, WhatsApp, fechas) y pasarlos por revisión legal.

## Revisión de lanzamiento (13-oct-2026)
- Pruebas 001–005 pasan en faxi-pruebas sin dejar datos; huella 20 · 51 · 41 · 29 · 52 · 1 · false.
- Asesor de seguridad: solo avisos esperados (RPC de las apps; las de admin verifican `is_admin`) y "contraseñas filtradas" (panel; activar en producción).
- **Corregido:** permisos de más en las apps (micrófono en conductor; almacenamiento y superposición en pasajero; textos de permiso de iOS en inglés). Comprobado con `expo config --type introspect` en modo producción y desarrollo.
- **Agregado:** perfiles de EAS con su grupo de variables y `.aab` en producción; `owner` y ID de proyecto fijos en la app de pasajeros; sitio estático `sitio/` para faxi.com (`scripts/build_sitio.mjs` + `netlify.toml`); `docs/LANZAMIENTO.md`.
- **Pendiente nuevo:** tras la primera subida a Google Play, añadir la SHA-1 de la clave de firma de Play a la clave de Maps; declaración de servicio en primer plano (conductor); geo-permisos de Twilio solo RD.
