# faxi · Lo que te toca a ti (cuando tengas un rato)

> La lista completa y ordenada para lanzar está en `docs/LANZAMIENTO.md`.

Estado a 10-oct-2026. Lo de Claude ya está hecho; esto solo lo puedes hacer tú porque necesita tu Mac, tu teléfono o tus cuentas.

## A. Primer build del pasajero (Mac, ~30 min, casi todo esperando)
1. Que la Mac tenga **Wi-Fi** (el build falló antes por falta de internet, no por la app).
2. Terminal:
   ```
   cd ~/Downloads/faxi-main/apps/passenger
   ping -c 3 api.expo.dev
   npx eas-cli@latest build --profile development --platform android
   ```
3. Si pregunta "Generate a new Android Keystore?" → `y`.
4. Al terminar da un **enlace / QR**: ábrelo en el teléfono Android e instala.
5. Manda una foto de la Terminal (sin claves).

## B. Probar el login por SMS (teléfono)
- Usa **tu número verificado en Twilio**.
- Desde la raíz: `npm run passenger` y abre la app en el teléfono.

## C. Notificaciones push (faxi-pruebas) — ya no hace falta nada
Revisado el 13-oct-2026: el aviso automático de la migración 005 (trigger + Vault `faxi_push_url` / `faxi_push_secret`) ya funciona en faxi-pruebas (respuesta 200).
**No crees un Database Webhook ni el secreto `PUSH_WEBHOOK_SECRET`**: el webhook duplicaría cada notificación.

## D. Seguridad (5 min, importante)
- **Rota la clave `sb_secret_…`** que se pegó en el chat: Supabase → faxi-pruebas → Settings → API Keys.
- **Google Cloud**: borra la clave de API sin restricción que se vio en una foto y crea otra restringida (Maps: app Android `com.faxi.app`; Places: solo Places API).

## E. Producción (faxi, `opehqsltrzhtsqqlctdg`) — solo con tu visto bueno
- Comparar la huella con faxi-pruebas ejecutando en el **SQL Editor de faxi** (solo lectura) `supabase/HUELLA_ESQUEMA.sql`: debe dar 20 tablas, 51 funciones, 41 políticas, 29 triggers, 52 índices, 1 job de cron, `false`.
- `seed.sql` y los tests **nunca** en faxi.

## F. Conductor
- Repetir A con `apps/driver` (`eas init`, su propio `EAS_PROJECT_ID` como variable del proyecto en Expo, y el build).
