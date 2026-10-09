# Lo que te toca a ti (en orden)

Todo se hace desde el navegador, menos el paso 6. Tiempo total: ~1 hora más la prueba en el teléfono.

## 1. Cambiar la clave secreta expuesta (2 min)
Supabase → **faxi-pruebas** → Project Settings → **API Keys** → en la clave `sb_secret_…` que se pegó en el chat, **Revoke** (o "Roll") y crea una nueva. No la pegues en ningún chat.

## 2. Actualizar producción (10 min)
1. Supabase → **faxi** (producción) → **SQL Editor** → New query.
2. Abre en GitHub `supabase/PRODUCCION_PEGAR.sql`, copia **todo**, pégalo y pulsa **Run**.
3. Al final sale una tabla. Debe decir: tablas **20** · funciones **51** · politicas **43** · triggers **29** · indices **52** · cron **1** · h_funciones **d0c010** · h_politicas **c306e3** · h_triggers **179f6c** · vault **2** · proveedor **CASH**.
   Si algo no coincide, mándame una captura de esa tabla.

## 3. Notificaciones push en producción (5 min)
Supabase → **faxi** → **Edge Functions** → Deploy a new function → *Via Editor* → nombre `send-push` → pega el contenido de `supabase/functions/send-push/index.ts` → en ajustes **desactiva "Verify JWT"** → Deploy.
(En faxi-pruebas ya está hecho y probado.)

## 4. Cerrar los canales públicos (1 min por proyecto)
Supabase → faxi → **Realtime** → **Settings** → desactiva **Allow public access** → Save. Repite en faxi-pruebas.

## 5. Tu usuario administrador (3 min)
1. Supabase → faxi → **Authentication** → Users → **Add user** → *Create new user* → tu correo + una contraseña fuerte → marca **Auto Confirm User**.
2. SQL Editor → pega `supabase/PRODUCCION_PRIMER_ADMIN.sql` (si usaste otro correo distinto de ventasindumangflex@gmail.com, cámbialo en la línea marcada) → **Run**.

## 6. Probar en tu teléfono Android (~3 h, casi todo esperando)
Sigue `docs/GUIA_PASOS_1_A_4.md`. Usa **faxi-pruebas** (no producción). Lo que falle, mándamelo con una captura y lo arreglo.

## 7. Cuando puedas (no bloquea la prueba)
- Pide el **D-U-N-S** (gratis) para las cuentas de empresa de Apple y Google.
- Crea un proyecto en **sentry.io** (React Native) y pásame el DSN, o ponlo tú en EAS como `EXPO_PUBLIC_SENTRY_DSN`.
- Completa lo que está entre **[corchetes]** en los textos legales (`apps/admin/src/legal/`) y pásaselos a un abogado.
- Decide cómo te pagan los conductores la comisión de los viajes en efectivo.
