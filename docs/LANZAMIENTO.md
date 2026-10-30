# faxi · Lista para lanzar

Revisión completa del 13-oct-2026. Leyenda: **[x]** hecho · **🤖** lo hace Claude · **👤** lo haces tú · **⛔** espera la empresa (RNC).

## ▶ Lo primero mañana (15-oct): conectar faxird.com (unos 5 minutos)
Ya hecho: en Netlify se quitó `faxi.com` y se agregó `faxird.com` (principal) y `www.faxird.com`. Sale "Pending DNS verification", que es normal hasta hacer esto:

**A · Entrar a los DNS** (perfil de Chrome del **trabajo**)
1. Abre **admin.google.com** (no admin.faxird.com) y entra con **admin@faxird.com**.
2. Menú ☰ → **Cuenta** → **Dominios** → **Administrar dominios**.
3. En `faxird.com` → **Ver detalles** → **Configuración de DNS avanzada** → **Iniciar sesión en la consola de DNS**. Se abre Squarespace.

**B · Quitar lo de Squarespace (solo si aparece)**
4. Si hay un grupo **"Squarespace Defaults"** (o "Valores predeterminados de Squarespace"): 🗑 → **Eliminar**.
5. ⚠️ **No borres** el grupo **Google Workspace** ni registros **MX** o **TXT** (son del correo).

**C · Agregar 2 registros** en **Custom records / Registros personalizados** → **Add record**:

| Host | Tipo | Datos |
|---|---|---|
| `@` | `A` | `75.2.60.5` |
| `www` | `CNAME` | `faxi.netlify.app` |

Lo demás como está → **Guardar**. Si dice que `www` ya existe, borra el `www` viejo y vuelve a agregarlo.

**D · Esperar y comprobar**
6. Netlify → **faxi** → **Domain management** → **Verify DNS configuration**. Si sigue amarillo, espera (10 minutos a unas horas).
7. Abre **https://faxird.com/privacidad**: debe salir la página con candado 🔒.

**No toques** en Netlify "Set up Netlify DNS" (rompe el correo). El aviso sobre el "CDN" se puede ignorar.

📸 Si algo no se ve igual, foto a Claude antes de tocar.

## Dónde estamos

| Parte | Estado |
|---|---|
| Base de datos (faxi-pruebas) | Migraciones 001–016 aplicadas; las 13 pruebas dan OK (hasta `FAXI 016 OK`). **Escritas y pendientes de aplicar y probar por el dueño:** 017 (recargo del aeropuerto, apagado) y 018 (retención de datos). Huella en `supabase/HUELLA_ESQUEMA.sql`. |
| App de pasajeros | ✅ Instalada en Android; entra por SMS y busca direcciones. ❌ El mapa sale en blanco: falta la clave nueva (`docs/MAPA_ANDROID.md`). |
| App de conductores | ⚠️ Código listo; aún sin build ni prueba en teléfono. |
| Panel admin | ✅ Funciona en la Mac (aprobar y rechazar conductores probado). |
| Página web | ✅ Publicada en **faxi.netlify.app**. Dominio **faxird.com** comprado y agregado en Netlify (14-oct); faltan los 2 registros DNS en Squarespace (arriba). |
| Producción (Supabase faxi) | ⛔ El proyecto no aparece en tu cuenta. Se crea o se localiza cuando exista la empresa. |
| Tiendas | ⛔ Cuentas de organización (Google Play y Apple) esperan RNC y D-U-N-S. |

## Lo que revisé y corregí hoy
- [x] **Pruebas de la base** 001–005 en faxi-pruebas: todas pasan, sin restos.
- [x] **Seguridad (asesor de Supabase):** 31 avisos "funciones ejecutables por usuarios con sesión" son las RPC que usan las apps (así está diseñado); las de administración rechazan a quien no es admin (`42501`). El aviso de "contraseñas filtradas" solo afecta al panel: activarlo en producción si el plan lo permite.
- [x] **Permisos de las apps** (motivo frecuente de rechazo en las tiendas):
  - Conductor: se quitó el **micrófono** que añadía `expo-image-picker` sin usarse.
  - Las dos apps: los textos de permiso de iPhone que quedaban **en inglés** ahora están en español.
  - Pasajero: se quitaron almacenamiento y "mostrar sobre otras apps", que no usa.
- [x] **Android 16 (API 36):** cumple el requisito de Google Play de 2026.
- [x] **Seguridad del pasajero:** botón de 911, compartir viaje, eliminar cuenta (en la app y en la web), reportar un problema.
- [x] **EAS:** cada perfil usa su grupo de variables (`development`, `preview`, `production`) y el de producción genera el `.aab` para Google Play. La app de pasajeros ya no necesita `EAS_PROJECT_ID=…` delante del comando.
- [x] **Sitio web** generado desde los mismos textos legales del panel (`node scripts/build_sitio.mjs`) y publicado en Netlify (14-oct).
- [x] Notificaciones push en faxi-pruebas: **completas** (Vault + trigger, respuesta 200). **No crees un webhook** en Supabase: duplicaría cada notificación.

---

## Etapa 1 · Prueba interna con 2 teléfonos (faxi-pruebas, sin gastar)

1. [x] **Mapa en blanco: resuelto el 15-oct** (clave nueva; ver `docs/MAPA_ANDROID.md`). Falta borrar la clave vieja. Detalle original: (la app ya limpia la clave, el build falla con mensaje claro si falta y avisa si Google la rechaza).
2. 👤 **Números de prueba sin SMS** (sirve para el segundo teléfono, sin otro número de Twilio):
   Supabase → **faxi-pruebas** → Authentication → Sign In / Providers → **Phone** → *Test Phone Numbers and OTPs*:
   ```
   18095550301=CODIGO,18295550302=CODIGO
   ```
   Cambia `CODIGO` por un número de 6 cifras que solo tú sepas (no lo mandes por chat). Con `809 555 0301` entras como pasajero y con `829 555 0302` como conductor nuevo; luego lo apruebas en el panel. **No llega SMS**: escribe el código que elegiste. Hazlo **solo en faxi-pruebas**.
3. 👤 **Variables para el APK de prueba:** expo.dev → **faxi.app** → proyecto **faxi** → *Environment variables*. Abre cada variable que ya existe y marca también **Preview** (mismos valores de faxi-pruebas). Deben estar:

   | Variable | Visibilidad | Pasajero | Conductor |
   |---|---|---|---|
   | `EXPO_PUBLIC_SUPABASE_URL` | Plain text | ✓ | ✓ |
   | `EXPO_PUBLIC_SUPABASE_ANON_KEY` | Sensitive | ✓ | ✓ |
   | `EXPO_PUBLIC_GOOGLE_PLACES_KEY` | Sensitive | ✓ | — |
   | `GOOGLE_MAPS_ANDROID_KEY` | Sensitive | ✓ | ✓ |
   | `EXPO_PUBLIC_SUPPORT_WHATSAPP` (opcional) | Plain text | ✓ | ✓ |
   | `EXPO_PUBLIC_SENTRY_DSN` (opcional) | Plain text | ✓ | ✓ |

4. ✅ **App del conductor en Expo** (16-oct): proyecto `faxi.app/faxi-conductor`, ID fijo en `apps/driver/app.config.ts`.
   Sus variables "Preview" se copian de las de la app de pasajeros (en la Mac, con el código al día):
   ```
   cd ~/Downloads/faxi-main/apps/passenger && npx eas-cli@latest env:pull --environment preview --path /tmp/faxi-preview.env
   cd ../driver && npx eas-cli@latest env:push --environment preview --path /tmp/faxi-preview.env && rm /tmp/faxi-preview.env
   npx eas-cli@latest env:delete --variable-name EAS_PROJECT_ID --variable-environment preview
   ```
   ⚠️ El último comando es obligatorio: `EAS_PROJECT_ID` es el de la app de pasajeros y, si se queda, el build del conductor falla con "Slug … does not match". (Hecho el 16-oct; primer APK del conductor: build `d96163e6`.)
5. 👤 **APK de prueba (se instala sin la Mac encendida):**
   ```
   cd apps/passenger && npx eas-cli@latest build --profile preview --platform android
   cd ../driver   && npx eas-cli@latest build --profile preview --platform android
   ```
   Cada uno da un enlace: ábrelo en el teléfono e instala. Recuerda añadir a la clave de Maps la SHA-1 de la app del conductor (`com.faxi.conductor`).
6. 👤 **Viaje completo:** el conductor se registra con documentos → lo apruebas en el panel → se conecta → el pasajero pide → aceptar → llegar → iniciar → terminar → cobrar efectivo → calificar. Prueba también: cancelar, cerrar la app a mitad de viaje y reabrir, y la notificación al aceptar.

## Etapa 2 · Piloto cerrado con personas reales (10–20 conductores, 30–50 pasajeros)

Todo esto necesita la empresa:
- ⛔ **Empresa y RNC** → datos para todo lo demás.
- ⛔ **Twilio:** perfil de cumplimiento (Trust Hub) para enviar SMS a cualquier número. Además, en Verify → *Geo permissions*, deja **solo República Dominicana** (evita fraude por SMS y gastos inesperados).
- ⛔👤 **Supabase de producción** en plan **Pro** (copias de seguridad diarias, no se pausa). Luego, con tu visto bueno y en orden: migraciones 001–004 + cron → `PRODUCCION_PEGAR.sql` (cambiando el ref si el proyecto es nuevo) → `send-push` → Realtime sin acceso público → tu admin (`docs/PASOS_DEL_DUENO.md`). Comprobar con `supabase/HUELLA_ESQUEMA.sql`.
- 👤 **Variables de EAS en "Production"** con los valores del Supabase de producción (misma tabla de arriba).
- 👤 **Clave de Maps nueva** (la actual se pegó en un chat): crearla, restringirla a `com.faxi.app` y `com.faxi.conductor` con sus SHA-1, y borrar la vieja.
- 👤 **Dominio propio** y correo de soporte (abajo). Después cambio las direcciones en las apps, los textos legales y las fichas.
- 👤 **Textos legales:** rellenar lo que sigue entre [corchetes] (razón social, RNC, dirección, WhatsApp, fechas, plazos, comisión en efectivo, seguro) y revisión de un **abogado dominicano**. Después: `node scripts/build_sitio.mjs` (o pídemelo).
- 👤 **Decisiones del 22 y 29-oct (dueño y Virgilio):**
  - **Comisión 10 %**, tarifas nuevas y límite de deuda de RD$1,000 → migración 013 (hecha en faxi-pruebas; el 20 % de más abajo ya no vale).
  - **Tiempo de espera:** 5 minutos gratis entre "Llegué" e "Iniciar"; después, la tarifa por minuto de la categoría → migración 016 (hecha en faxi-pruebas). Los términos de conductores ya están en la 1.3; falta mencionar la espera cuando el abogado los revise.
  - **Peajes:** no se cobran aparte, salvo un **recargo fijo opcional del aeropuerto** (apagado en RD$0; solo el SUPER_ADMIN lo cambia en Zonas) → migración 017 (escrita; falta aplicarla y probarla). **El monto lo define el dueño.**
  - **Hoteles:** la regla de 200 m del INTRANT se queda. Falta la lista de Virgilio: `docs/HOTELES_ZONAS.md` y `supabase/CARGAR_HOTELES_PLANTILLA.sql`.
  - **Datos:** ubicaciones y avisos 90 días, documentos rechazados 1 año, viajes 10 años (se anonimizan; no se borran) → migración 018 (escrita; falta aplicarla y probarla). **La contadora debe confirmar los 10 años.** Los plazos están en la política de privacidad como [PLAZO] hasta que se aprueben. Faltan por quitar los archivos de documentos borrados en Storage, y los códigos OTP los maneja Supabase Auth.
  - **Usuario ADMIN de Virgilio:** `supabase/CREAR_ADMIN_VIRGILIO.sql` está preparado; solo lo corre el dueño.
- [x] **Decisiones de negocio (15-oct):** comisión del 20 % pagada **cada lunes**, bloqueo al deber más de **RD$2,000** (ya en la app y el panel → *Comisiones*); vehículos de **máximo 15 años** (regla del INTRANT, hoy 2011+; cambiado el 15-oct tras la revisión legal); **Haina fuera** durante el piloto.
- 👤 **Revisión legal previa (15-oct):** lo que falta está en `docs/REVISION_LEGAL.md` (registro en el INTRANT, póliza de responsabilidad civil, ITBIS de la comisión, cuenta a nombre de la empresa).
- 👤 Admin → *Tarifas y ajustes* → `COMMISSION_PAY_INFO`: banco, tipo y número de cuenta y titular (piloto: tu cuenta personal; luego la de la empresa). Solo la ven los conductores aprobados, en *Ganancias*. **Nunca en el código.**
- 👤 Confirmar con el INTRANT el año mínimo y el seguro de responsabilidad civil.
- ⛔👤 **Google Play** (cuenta de organización): prueba cerrada, ficha (`docs/tiendas/FICHAS.md`), seguridad de los datos, declaración de ubicación en segundo plano y de **servicio en primer plano** (mismo texto y video de la ubicación en segundo plano).
- 👤 **Tras la primera subida a Play:** Play Console → *Integridad de la app* → copia la **SHA-1 de la clave de firma de apps** y añádela a la clave de Maps. Sin esto, el mapa sale en blanco en las apps instaladas desde Play.
- 👤 Recomendado: **Sentry** (errores en teléfonos reales). Crea el proyecto y pon el DSN en EAS.

## Etapa 3 · Lanzamiento público
- Pasar Play de prueba cerrada a **producción**.
- iPhone: cuenta **Apple Developer de organización** → build de iOS (primera vez, esperar ajustes) → TestFlight → App Store con las notas de `FICHAS.md`. Número de prueba para los revisores en el Supabase de producción; quitarlo al aprobarse.
- Capturas de pantalla para las tiendas (lista en `FICHAS.md`).

---

## Página web y dominio
- **Publicada (14-oct-2026)** en **https://faxi.netlify.app** desde `main` (Netlify, equipo *indumangflex*, plan gratis). Cada push a `main` la vuelve a publicar.
- **Dominio propio: `faxird.com`** (comprado el 14-oct-2026 con Google Workspace Starter; registrador Squarespace). `faxi.com` **no es nuestro** (otro dueño desde 2000).
- Apps, textos legales, fichas y sitio ya usan `https://faxird.com/...` y **soporte@faxird.com** (alias gratis del usuario de Workspace).

**Conectar faxird.com a Netlify** (pasos 1 y 2 hechos el 14-oct; pasos 3–5 detallados arriba en "Lo primero mañana"):
1. [x] Netlify → **faxi** → **Domain management** → quitar `faxi.com` y `www.faxi.com` (*Options → Remove domain*).
2. [x] **Add a domain you already own** → `faxird.com` → **Verify** → **Add domain**. **No uses "Set up Netlify DNS"** (el correo está en Google Workspace).
3. admin.google.com → **Cuenta → Dominios → Administrar dominios** → `faxird.com` → **Ver detalles → Configuración de DNS avanzada → Iniciar sesión en la consola de DNS** (Squarespace).
4. Ahí: registro **A** de `@` a `75.2.60.5` y **CNAME** de `www` a `faxi.netlify.app`. Quitar solo los registros *Squarespace Defaults* de `@`/`www` si existen. **No borres los MX ni los TXT** de Google Workspace.
5. Espera (minutos u horas). Netlify activa HTTPS solo. Prueba `https://faxird.com/privacidad`.

## Actualizar el código en la Mac
La carpeta `~/Downloads/faxi-main` es una copia vieja (no tiene estos arreglos). Para la etapa 1:
1. GitHub → repositorio **faxi** → arriba a la izquierda, el selector de rama: elige **`claude/empty-session-8tsfph`** (o `main` cuando ya esté unida) → botón **Code → Download ZIP**. Descomprime en Descargas y renombra la carpeta como `faxi-nuevo`.
2. Copia tus archivos de claves de la carpeta vieja a la nueva (son ocultos; en Terminal):
   ```
   cp ~/Downloads/faxi-main/apps/passenger/.env ~/Downloads/faxi-nuevo/apps/passenger/.env
   cp ~/Downloads/faxi-main/apps/admin/.env.local ~/Downloads/faxi-nuevo/apps/admin/.env.local
   cp ~/Downloads/faxi-main/apps/passenger/.env ~/Downloads/faxi-nuevo/apps/driver/.env
   ```
3. Terminal:
   ```
   cd ~/Downloads/faxi-nuevo
   npm install
   git init && git add -A && git commit -m "codigo"
   ```
   (Los `.env` no se incluyen en el commit; están excluidos a propósito.)
