# Pendientes antes de publicar faxi

Estado a 8-oct-2026. Solo es una lista; nada de esto está implementado todavía.

## Bloqueos actuales (Fase 1 sin cerrar)
- [ ] **Pruebas SQL sin correr.** `001_trip_flow.sql` y `002_mobile.sql` deben dar `FAXI OK` y `FAXI MÓVIL OK` en **faxi-pruebas** (`hwypoksdxrfffvaaludj`) antes de dar por buena la base. Faltan en faxi-pruebas: `delete_my_account`, la política `docs_owner_delete` y el seed (`supabase/PEGAR_EN_PRUEBAS.sql`). Motivo: la herramienta de Supabase de la sesión se cuelga con SQL que contiene `DELETE`, y la red de la sesión bloquea la API y la base directa.
- [ ] **Verificar producción (faxi, `opehqsltrzhtsqqlctdg`).** Migraciones 001–003, 004 (sin `delete_my_account`) y cron aplicados desde la sesión; `delete_my_account` y `docs_owner_delete` pegados a mano por el dueño. Falta confirmar con las pruebas en faxi-pruebas que el esquema es idéntico.
- [ ] **Expo:** correr `npx expo install --fix` y `npx expo-doctor` en `apps/passenger` y `apps/driver` con acceso a `api.expo.dev` (en la sesión dio 16/18 por bloqueo de red; los 2 fallos eran de red, no de código).
- [ ] **Seguridad:** una clave `sb_secret_…` de faxi-pruebas se pegó en el chat. Rotarla (Settings → API Keys). Mantener la regla: credenciales solo en `.env`.

## Producto
- [ ] **Zona de servicio:** reemplazar el polígono aproximado (`app_settings.SERVICE_AREA`) por los límites reales del Gran Santo Domingo; valorar PostGIS.
- [ ] **Íconos y splash** de pasajero y conductor (`assets/icon.png` 1024×1024, descomentar en `app.config.ts`).
- [ ] **Realtime de ubicación (fase 2):** los canales `trip:<id>` deben ser privados y autorizados por RLS; hoy cualquiera suscrito a un id podría escuchar.
- [ ] **Sentry** en builds de producción.

## Tiendas
- [ ] Builds de producción (`eas build --profile production`) y fichas de Play Store / App Store (capturas, descripción, categoría).
- [ ] **Google Play:** declaración y video del uso de ubicación en segundo plano (conductor); cuenta de organización (D-U-N-S) o prueba cerrada de 12 testers por 14 días.
- [ ] **Apple:** cuenta de organización; justificar ubicación en segundo plano.
- [ ] **Política de privacidad y términos** publicados en una URL (Ley 172-13 de RD); revisión legal local y requisitos de INTRANT.

## Operación
- [ ] Twilio Verify configurado en Supabase Auth (Phone) y límites de SMS.
- [ ] Función `send-push` desplegada, con su secreto y el webhook sobre `notifications`.
- [ ] Primer admin creado con SQL (`role = 'SUPER_ADMIN'`).
- [ ] Piloto cerrado con 10–20 conductores y 30–50 pasajeros; proceso de aprobación de conductores definido.
- [ ] `seed.sql` **nunca** en producción.

## Problemas encontrados en las fases 1–7
- **Corregido:** migración 001, índice `commissions_one_active` usaba `category::text` (no inmutable) y fallaba. Ahora son dos índices parciales con la misma garantía.
- **Limitación de la herramienta:** `apply_migration`/`execute_sql` agotan 60 s con SQL que contiene `DELETE`. Aplicar esas piezas desde el SQL Editor o con CLI/API con acceso de red.
- **Pendiente de revisar:** el test `002_mobile.sql` depende de `delete_my_account` y de un `SUPER_ADMIN` del seed; solo puede correr en faxi-pruebas.
