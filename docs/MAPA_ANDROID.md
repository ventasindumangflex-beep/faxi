# Arreglar el mapa en blanco (Android)

> ✅ **Resuelto el 15-oct-2026:** con la clave nueva `faxi-maps-android-2` el mapa carga en la app de prueba (perfil *preview*). Falta borrar la clave vieja `faxi-maps-android` y, más adelante, agregar la SHA-1 de la app del conductor y la de Google Play.

## Qué sabemos
- El código del mapa está bien: Google Maps en Android, versión recomendada para Expo SDK 54.
- La app **no se cierra** al abrir el mapa. Eso quiere decir que el build sí lleva una clave; lo que pasa es que **Google la rechaza**.
- Quitar temporalmente la restricción de apps ("Ninguno") no cambió nada. Entonces el problema más probable **no es la huella SHA-1**, sino la clave que tiene Expo. Puede ser otra clave (por ejemplo, la de Places), una clave con espacios o comillas pegados, o una clave sin permiso para *Maps SDK for Android*.
- Esa clave además se pegó en un chat, así que hay que cambiarla de todas formas. **Solución: una clave nueva, bien configurada.**

## Lo que ya hace la app (desde el 13-oct-2026)
- Quita espacios y comillas pegados por error a la clave.
- Si en EAS falta la clave o no tiene forma de clave de Google (`AIza…`, 39 caracteres), **el build de Android falla con un mensaje claro** en vez de instalar un mapa en blanco.
- Si el mapa no carga en 15 segundos, sale un **aviso amarillo** sobre el mapa. En el build de desarrollo, el aviso dice que Google está rechazando la clave.

## Pasos (unos 15 minutos más el build)

### 1. Copia la huella SHA-1 de Expo
expo.dev → cuenta **faxi.app** → proyecto **faxi** → menú izquierdo **Credentials** → **Android** → `com.faxi.app` → en el almacén de claves (Keystore) copia **SHA-1 Fingerprint**.

### 2. Crea la clave nueva en Google Cloud
console.cloud.google.com → proyecto **faxi-511103**:
1. ☰ → **APIs y servicios** → **Credenciales** → **+ Crear credenciales** → **Clave de API**.
2. En la ventana que sale, toca **Editar clave de API**.
3. Nombre: `faxi-maps-android-2`.
4. **Restricciones de aplicación** → **Apps para Android** → **Agregar**:
   - Nombre del paquete: `com.faxi.app` (todo en minúsculas)
   - Huella SHA-1: la del paso 1 → **Listo**.
5. **Restricciones de API** → **Restringir clave** → marca **solo "Maps SDK for Android"**. No marques *Maps JavaScript API* ni *Places*.
6. **Guardar**. Luego **Mostrar clave** → copiar. No la pegues en ningún chat.

### 3. Ponla en Expo
expo.dev → **faxi.app** → **faxi** → **Environment variables** → `GOOGLE_MAPS_ANDROID_KEY` → editar:
- Valor: pega la clave nueva, sin espacios ni comillas.
- Entornos: **Development**, **Preview** y **Production**.
- Visibilidad: **Sensitive** → **Save**.

### 4. Nuevo build e instalación
La clave va dentro de la app, así que hace falta un build nuevo. Usa el código nuevo (ver "Actualizar el código en la Mac" en `docs/LANZAMIENTO.md`):
```
cd apps/passenger
npx eas-cli@latest build --profile development --platform android
```
Si el build se detiene con el mensaje `GOOGLE_MAPS_ANDROID_KEY falta o no es una clave de Google`, el paso 3 no quedó bien: revisa el valor y que esté marcado **Development**.

Instala el enlace en el teléfono y abre la app. Google puede tardar hasta 5 minutos en aplicar una clave nueva: si el mapa no sale, cierra la app del todo y ábrela otra vez.

### 5. Resultado
- **Sale el mapa:** listo. Borra en Google Cloud la clave vieja `faxi-maps-android`.
- **Sigue en blanco y aparece el aviso amarillo:** Google sigue rechazando la clave. Manda fotos de:
  1. Google Cloud → APIs y servicios → **Maps SDK for Android** → **Métricas** (gráfico de errores por credencial).
  2. La pantalla de la clave `faxi-maps-android-2` (restricciones; tapa la clave).
  3. Expo → Credentials → Android → SHA-1 (no es secreta).

## Después
- **App del conductor:** cuando exista su build, agrega a esta misma clave otra app Android con `com.faxi.conductor` y la SHA-1 de su proyecto en Expo.
- **Google Play:** tras la primera subida, agrega la SHA-1 de *Integridad de la app → Clave de firma de apps* (Play vuelve a firmar la app con otra clave).
