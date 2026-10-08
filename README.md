# faxi · monorepo

Apps reales de faxi para Santo Domingo:

| Carpeta | Qué es | Tecnología |
|---|---|---|
| `apps/passenger` | App del pasajero (`do.faxi.app`) | Expo SDK 54 · React Native · Expo Router |
| `apps/driver` | App del conductor (`do.faxi.conductor`), con ubicación en segundo plano | Expo SDK 54 |
| `apps/admin` | Panel web de operaciones | Next.js 15 |
| `packages/core` | Tipos, cliente Supabase, RPC, formato RD$, estados del viaje, Realtime | TypeScript |
| `packages/ui` | Diseño (tokens del prototipo), componentes, login OTP, push, mapas | React Native |
| `supabase/` | Migraciones 001–004, seed, tests, Edge Function `send-push` | Postgres |
| `prototype/` | Prototipos `.dc.html`: referencia visual, no se publican | — |

Pago: **solo efectivo**. El conductor confirma el cobro (`driver_confirm_cash`). Azul/CardNET entran en la fase 2.

---

## 1. Base de datos (una sola vez)

Con Claude Code y el MCP de Supabase conectado, pídele:

> Aplica en orden `supabase/migrations/*.sql` (001 → 004), luego `supabase/seed.sql` **solo en un proyecto de pruebas**, y corre `supabase/tests/001_trip_flow.sql` y `002_mobile.sql`. Deben salir `FAXI OK` y `FAXI MÓVIL OK`.

Después, en el Dashboard de Supabase:

1. **Auth → Providers → Phone**: actívalo con **Twilio Verify** (Account SID, Auth Token, Verify Service SID). En *Rate limits* deja ~30 SMS/hora por IP.
2. **Database → Extensions**: confirma que `pg_cron` está activo (la 004 programa `expire_stale()` cada 15 s).
3. **Edge Function de notificaciones**
   ```bash
   supabase functions deploy send-push --no-verify-jwt
   supabase secrets set PUSH_WEBHOOK_SECRET=<cadena-larga-aleatoria>
   ```
   **Database → Webhooks → Create**: tabla `notifications`, evento `INSERT`, tipo *Supabase Edge Function* → `send-push`, cabecera `x-faxi-secret: <la misma cadena>`.
4. **Primer admin**: crea un usuario con correo y contraseña en *Auth → Users*, y en el SQL Editor:
   `update public.users set role = 'SUPER_ADMIN' where email = 'tu@correo.com';`

> Producción: **no** corras `seed.sql` (crea usuarios de prueba).

## 2. Variables de entorno

Copia `.env.example` a `apps/passenger/.env`, `apps/driver/.env` y `apps/admin/.env.local` y rellena cada uno.

Claves de Google Cloud (proyecto con facturación):
- **Maps SDK for Android** → `GOOGLE_MAPS_ANDROID_KEY`, restringida por paquete + SHA-1 (`eas credentials` muestra el SHA-1). En iOS se usa Apple Maps: no necesita clave.
- **Places API (New)** → `EXPO_PUBLIC_GOOGLE_PLACES_KEY` (solo pasajero), restringida **por API** a Places. Pon una alerta de presupuesto.

## 3. Correr en tu teléfono

```bash
npm install                     # en la raíz (instala las 3 apps)
cd apps/passenger
npx expo install --fix          # alinea versiones con el SDK instalado
npm i -g eas-cli && eas login
eas init                        # crea el proyecto y te da EAS_PROJECT_ID → ponlo en .env
eas build --profile development --platform android   # instala el APK que te da
npm start                       # abre el dev build y escanea el QR
```
Repite en `apps/driver`. Los mapas, la ubicación en segundo plano y las notificaciones **no funcionan en Expo Go**: usa el *development build*.

Admin: `npm run admin` → http://localhost:3001. Publicar: importa `apps/admin` en Vercel con las dos variables `NEXT_PUBLIC_*`.

## 4. Publicar

```bash
eas build --profile production --platform all
eas submit --profile production --platform android   # sube a la pista "internal"
eas submit --profile production --platform ios
```
Antes de enviar: iconos (`assets/icon.png` 1024×1024, descomentado en `app.config.ts`), capturas, política de privacidad pública, y para el conductor el **video de uso de ubicación en segundo plano** que pide Google Play.

## 5. Flujo de un viaje

1. Pasajero: `quote_trip` → `request_trip` (estado `SEARCHING`; el servidor despacha a los 5 conductores más cercanos).
2. Conductor: recibe la oferta por Realtime + sondeo cada 8 s → `accept_trip_request`.
3. Conductor: `driver_advance_trip` ENROUTE → ARRIVED → STARTED → ONTRIP → FINISHED (el servidor calcula tarifa final y comisión).
4. Conductor cobra en efectivo → `driver_confirm_cash` → `COMPLETED`.
5. Pasajero califica → `rate_trip`.

Ubicación: el conductor emite por **Broadcast** (`trip:<id>`) cada ~5 s durante el viaje y guarda en la base cada ~15 s con `update_location` (tarea en segundo plano).

## 6. Qué falta para fase 2
- Pagos con tarjeta (Edge Function + webhook Azul/CardNET; `PAYMENT_PROVIDER` ≠ `MOCK`).
- Rutas reales con Routes API (hoy: línea recta × 1.35).
- Chat pasajero-conductor (tabla `messages` ya existe).
- Canales Realtime privados para la ubicación (hoy cualquiera con el id del viaje podría escuchar el canal).
- Sentry (`npx expo install @sentry/react-native` + `npx @sentry/wizard -i reactNative`).
