# faxi · Lo que te toca a ti (cuando tengas un rato)

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

## C. Notificaciones push (Supabase, faxi-pruebas) — 10 min
La función `send-push` **ya está desplegada** en faxi-pruebas. Falta lo que solo tú puedes poner:
1. Supabase → faxi-pruebas → **Edge Functions → Secrets** → crea `PUSH_WEBHOOK_SECRET` con una cadena larga aleatoria (guárdala en tu bloc de notas, no en el chat).
2. Supabase → **Database → Webhooks → Create**:
   - Tabla `notifications`, evento **Insert**.
   - Tipo **Supabase Edge Functions** → `send-push`.
   - Cabecera HTTP: `x-faxi-secret` = el mismo valor del paso 1.
3. Aún no se puede probar de punta a punta: hace falta el teléfono con la app instalada (sección A).

## D. Seguridad (5 min, importante)
- **Rota la clave `sb_secret_…`** que se pegó en el chat: Supabase → faxi-pruebas → Settings → API Keys.
- **Google Cloud**: borra la clave de API sin restricción que se vio en una foto y crea otra restringida (Maps: app Android `do.faxi.app`; Places: solo Places API).

## E. Producción (faxi, `opehqsltrzhtsqqlctdg`) — solo con tu visto bueno
- Comparar la huella con faxi-pruebas ejecutando en el **SQL Editor de faxi** (solo lectura) la consulta de huella: debe dar 20 tablas, 45 funciones, 41 políticas, 27 triggers, 52 índices, 1 job de cron.
- `seed.sql` y los tests **nunca** en faxi.

## F. Conductor
- Repetir A con `apps/driver` (`eas init`, su propio `EAS_PROJECT_ID` como variable del proyecto en Expo, y el build).
