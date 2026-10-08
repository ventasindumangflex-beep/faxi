# Instrucciones para Claude Code — Faxi

Eres el ingeniero responsable de llevar el monorepo `faxi-app/` hasta una app funcionando en teléfonos reales. Trabaja en orden, fase por fase. **No avances a la siguiente fase hasta que la actual pase su verificación.** Al terminar cada fase, resume lo que hiciste y qué falta.

Antes de empezar, lee completos: `README.md`, `docs/PLAN_TECNICO.md`, `ARCHITECTURE.md` y todas las migraciones en `supabase/migrations/`.

## Reglas
- Si algo falla, arregla la causa en el código o en la migración. **Nunca debilites una prueba para que pase.**
- No pongas claves ni secretos en el código. Todo va en `.env`, que está en `.gitignore`.
- Si necesitas una credencial que no tienes (Supabase, Twilio, Google Maps, Expo), **detente y pídemela** con instrucciones exactas de dónde sacarla.
- Haz un commit de git al terminar cada fase, con un mensaje claro: `fase N: ...`.
- Respeta las versiones fijadas de Expo SDK 54. No actualices el SDK.

---

## Fase 1: Base de datos
1. Pídeme la URL del proyecto de Supabase, la anon key, la service role key y la contraseña de la base de datos. Si no tengo proyecto, guíame para crearlo.
2. Instala y vincula la CLI: `npx supabase link --project-ref <ref>`.
3. Aplica las migraciones `001` a `004` en orden: `npx supabase db push`.
4. Corre `supabase/tests/001_trip_flow.sql` y `supabase/tests/002_mobile.sql` contra la base de datos.

**Verificación:** las dos pruebas imprimen `FAXI OK`.

## Fase 2: Dependencias y tipos
1. En `apps/passenger` y `apps/driver`: `npx expo install --fix`.
2. En `apps/admin`: `npm install`.
3. Corre `npx tsc --noEmit` en las tres apps y corrige todos los errores.
4. Corre `npx expo-doctor` en las dos apps móviles y corrige lo que reporte.

**Verificación:** cero errores de TypeScript y `expo-doctor` sin problemas.

## Fase 3: Variables de entorno
1. Crea el `.env` de cada app a partir de su `.env.example`.
2. Pídeme la API key de Google Maps (con Maps SDK for Android, Maps SDK for iOS y Places API activados).
3. Busca en todo el repo claves o URLs escritas a mano y muévelas al `.env`.

**Verificación:** `grep` no encuentra claves en el código, y cada app lee correctamente sus variables.

## Fase 4: Login por SMS y notificaciones push
1. Guíame paso a paso para configurar Twilio en Supabase (Authentication → Providers → Phone). Pídeme el Account SID, el Auth Token y el Message Service SID.
2. Despliega la función de push: `npx supabase functions deploy send-push`, y configura sus secretos.
3. Configura el webhook o trigger que la llama, según el `README.md`.

**Verificación:** puedo recibir un código SMS en mi número real, y una llamada de prueba a la función responde 200.

## Fase 5: Panel admin
1. En `apps/admin`: `npm run dev`.
2. Crea mi usuario administrador (pídeme el teléfono o email) y asígnale el rol `admin` con SQL.
3. Prueba: inicio sesión, veo el dashboard, edito una tarifa, edito la comisión, veo la zona de servicio en el mapa.

**Verificación:** todo lo anterior funciona sin errores en la consola.

## Fase 6: Builds de desarrollo (Android)
1. Pídeme que inicie sesión en Expo: `npx eas login`.
2. En cada app móvil: `npx eas init` y revisa `eas.json` y `app.config` (package name, permisos de ubicación en segundo plano, API key de Maps).
3. Configura las credenciales de FCM para las notificaciones push en Android.
4. Construye: `npx eas build --profile development --platform android` para la app de pasajero y la de conductor.
5. Dame los enlaces de instalación y explícame cómo correr `npx expo start --dev-client`.

**Verificación:** las dos apps se instalan y abren en un teléfono Android.

## Fase 7: Prueba de punta a punta
Guíame en esta prueba con dos teléfonos, paso a paso, y arregla cualquier error que aparezca:
1. **Conductor:** se registra con teléfono, sube los datos del vehículo y las fotos de los documentos.
2. **Admin:** aprueba al conductor, el vehículo y los documentos.
3. **Conductor:** se pone en línea y le aparece el aviso de ubicación en segundo plano.
4. **Pasajero:** se registra, busca un destino, ve el precio por categoría y pide un viaje.
5. **Conductor:** recibe la oferta con su cuenta regresiva de 15 segundos y la acepta.
6. **Pasajero:** ve al conductor moverse en el mapa en tiempo real y recibe las notificaciones push.
7. **Conductor:** marca "llegué", inicia el viaje, lo completa y confirma el pago en efectivo.
8. **Pasajero:** califica el viaje y lo ve en su historial.
9. **Admin:** ve el viaje terminado y las estadísticas actualizadas.
10. Prueba también: cancelación por los dos lados, que una oferta expire, compartir el viaje, el botón 911, reportar un problema y eliminar la cuenta.

**Verificación:** todo el flujo funciona sin errores. Escribe los resultados en `docs/PRUEBA_E2E.md`.

## Fase 8: Pendientes antes de publicar (solo haz la lista, no lo implementes todavía)
Crea `docs/PENDIENTES_PRODUCCION.md` con:
- Ajuste del polígono de la zona de servicio con los límites reales de Gran Santo Domingo
- Íconos y splash screens de las apps
- Seguridad de los canales Realtime de ubicación (fase 2)
- Builds de producción y fichas de Play Store y App Store
- Política de privacidad y términos (lo exigen las tiendas)
- Cualquier problema que hayas encontrado en las fases 1 a 7

---

**Empieza ahora por la Fase 1.**
