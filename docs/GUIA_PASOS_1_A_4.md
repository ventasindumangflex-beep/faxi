# faxi · Guía: de cero a la app abierta en tu teléfono Android

Tiempo total: unas 3 horas, casi todo esperando a Expo. Costo nuevo: $0.
Todo se hace en **tu MacBook** y en **tu teléfono**. Cada comando se copia y se pega en la app **Terminal**
(Cmd + Espacio, escribe "Terminal", Enter). Pega uno a la vez y espera a que termine.

> Regla de oro: **ninguna clave va en el chat con Claude**. Las claves de Google se escriben solo en la página de Expo.

---

## Antes de empezar: ten esto a mano
- [ ] Tu cuenta de Expo creada (expo.dev) y tu nombre de usuario.
- [ ] Las **2 claves de Google** en un bloc de notas:
  - `faxi-maps-android` (mapa)
  - `faxi-places` (buscar direcciones)
- [ ] Tu teléfono **Android**, con batería y en el mismo Wi-Fi que la Mac.
- [ ] Tu número de teléfono **verificado en Twilio** (con la cuenta de prueba solo envía códigos a números verificados).
- [ ] Estos dos datos de Supabase (son públicos, no son secretos), del proyecto **faxi-pruebas**:
  - URL: `https://hwypoksdxrfffvaaludj.supabase.co`
  - Clave pública (publishable): en Supabase → faxi-pruebas → Project Settings → API Keys → la que empieza con `sb_publishable_`.

---

## PASO 1 · Instalar lo necesario en la Mac (una sola vez, 20 min)

1. **Node.js**: entra a **nodejs.org**, descarga el botón **LTS** y ábrelo para instalarlo (siguiente, siguiente, instalar).
2. Abre **Terminal** y comprueba:
   ```
   node -v
   ```
   Debe salir algo como `v22.x.x` o `v20.x.x`.
3. **Git** (opcional; solo si prefieres no descargar el ZIP):
   ```
   git --version
   ```
   Si el Mac ofrece instalar herramientas de desarrollo, acepta.

## PASO 2 · Descargar el proyecto (10 min)

Forma fácil (sin Git):
1. Entra a `https://github.com/ventasindumangflex-beep/faxi/tree/claude/empty-session-8tsfph` con tu cuenta de GitHub.
2. Pulsa el botón verde **Code → Download ZIP**.
3. Abre el ZIP en **Descargas**; se crea una carpeta tipo `faxi-claude-empty-session-8tsfph`.

Instalar las piezas del proyecto (tarda unos minutos):
```
cd ~/Downloads/faxi-claude-empty-session-8tsfph
npm install
```
Al terminar no debe decir `error` en rojo (los avisos `warn` se ignoran).

## PASO 3 · Crear el build de las apps con Expo (1 a 2 horas, esperando)

### 3.1 Iniciar sesión en Expo
```
npx eas-cli@latest login
```
Escribe tu correo/usuario y contraseña de Expo.

### 3.2 Guardar las claves en Expo (una sola vez, en el navegador)
1. Entra a **expo.dev** → arriba a la derecha tu nombre → **Account settings** → **Environment variables**.
2. Crea estas variables (**Create variable**), todas con ambiente **development** (y **preview** si te lo deja marcar):

| Nombre | Valor | Visibilidad |
|---|---|---|
| `EXPO_PUBLIC_SUPABASE_URL` | `https://hwypoksdxrfffvaaludj.supabase.co` | Plain text |
| `EXPO_PUBLIC_SUPABASE_ANON_KEY` | tu clave `sb_publishable_…` | Plain text |
| `GOOGLE_MAPS_ANDROID_KEY` | la clave `faxi-maps-android` | Sensitive |
| `EXPO_PUBLIC_GOOGLE_PLACES_KEY` | la clave `faxi-places` | Plain text (las `EXPO_PUBLIC_` no pueden ser secretas) |
| `EXPO_PUBLIC_SUPPORT_WHATSAPP` | tu WhatsApp, ej. `18095550000` | Plain text |

### 3.3 Crear el proyecto de la app del **pasajero**
```
cd ~/Downloads/faxi-claude-empty-session-8tsfph/apps/passenger
npx eas-cli@latest init
```
- Responde **Yes** a crear el proyecto.
- Si dice que no puede escribir el ID automáticamente, **copia el `projectId`** que te muestra.
- Guarda ese valor como variable **del proyecto** (no de la cuenta, porque cada app tiene el suyo):
  en **expo.dev → tu proyecto "faxi" → Environment variables → Create variable**, nombre `EAS_PROJECT_ID`, ambiente **development**, Plain text.

### 3.4 Compilar
```
npx eas-cli@latest build --profile development --platform android
```
- Si pregunta por **Android keystore / Generate new**: responde **Yes**.
- Espera. Al final te da un **enlace y un código QR** para instalar. Guárdalo.

### 3.5 Repetir para el **conductor**
```
cd ~/Downloads/faxi-claude-empty-session-8tsfph/apps/driver
npx eas-cli@latest init
npx eas-cli@latest build --profile development --platform android
```
(Crea su proyecto "faxi-conductor" y guarda su propio `EAS_PROJECT_ID` en las variables de ese proyecto, igual que en 3.3.)

## PASO 4 · Instalar y probar (30 min)

1. En el teléfono Android abre el **enlace del build** (o escanea el QR con la cámara).
2. Descarga el archivo e **instálalo**. Si Android dice "instalar apps desconocidas", permítelo para Chrome.
3. En la Mac, arranca el servidor de desarrollo:
   ```
   cd ~/Downloads/faxi-claude-empty-session-8tsfph
   npm run passenger
   ```
4. Abre la app **faxi** en el teléfono; se conecta sola al servidor (misma Wi-Fi) o escanea el QR de la Terminal.
5. **Prueba el login**: escribe **tu número** (el verificado en Twilio), recibe el código por SMS, entra.

### Cómo sé que salió bien
- Te llega el código SMS y la app te deja entrar.
- Se ve el mapa de Santo Domingo.
- Al escribir un destino, aparecen sugerencias de direcciones.

---

## Si algo falla (dime la pantalla o el texto del error)
| Síntoma | Causa probable |
|---|---|
| `command not found: node` | Node no quedó instalado; ciérralo y abre Terminal de nuevo. |
| El build falla al inicio | Falta alguna variable en Expo (revisa la tabla 3.2). |
| El mapa sale gris | La clave de Maps está mal escrita o falta habilitar facturación en Google. |
| No llega el SMS | Tu número no está verificado en Twilio, o falta saldo. |
| No salen sugerencias de direcciones | La clave `faxi-places` no está o no tiene habilitada **Places API (New)**. |

## Después de este paso (otro día)
1. Restringir la clave del mapa a la app (paquete `do.faxi.app` + huella SHA-1 que da `eas credentials`).
2. Notificaciones push (`send-push`).
3. Usuario admin y panel web.
4. Prueba completa con 2 teléfonos.
