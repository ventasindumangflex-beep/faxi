# faxi · Subida a Google Play (prueba cerrada) · 2-nov-2026

Todo lo que se necesita para subir las dos apps, en el orden en que Play lo pide. Los textos largos están en `docs/tiendas/FICHAS.md`.

## 0. Antes de empezar
- Play Console debe tener la **verificación de identidad aprobada** (Panel → aviso de verificación). Sin eso no deja crear apps.
- Archivos (compilación 3, commit `df38c0a`, 1-nov-2026, producción): `faxi-pasajero.aab` (`com.faxi.app`) y `faxi-conductor.aab` (`com.faxi.conductor`).
  Si el enlace de Expo ya venció (30 días), se compilan de nuevo desde la rama `main` con el perfil `production`.
- Los **nombres de paquete no se pueden cambiar** una vez subidos.

## 1. Crear cada app (Play Console → Crear app)
| | faxi | faxi Conductor |
|---|---|---|
| Nombre | `faxi: viajes en Santo Domingo` | `faxi Conductor` |
| Idioma | Español (Latinoamérica) | igual |
| Tipo / precio | App · Gratis | igual |
| Correo de contacto | `soporte@faxird.com` | igual |
| Sitio web | `https://faxird.com` | igual |

## 2. Prueba cerrada (Pruebas → Pruebas cerradas → Crear pista `Piloto`)
1. Aceptar **Play App Signing** (Google guarda la llave de firma; la de subida la maneja Expo).
2. Subir el `.aab`. Notas de la versión: `Primera versión de prueba de faxi.`
3. Pestaña **Testers** → crear lista `Probadores` con los **12 correos de Gmail** (mínimo exigido en cuentas personales nuevas).
4. Copiar el **enlace de participación** y mandarlo a los probadores (mensaje abajo).
5. El conteo de **14 días seguidos** empieza cuando los 12 han aceptado. Tienen que quedarse dentro los 14 días.
6. Cumplido eso, se solicita el **acceso a producción** y Google revisa (suele tardar unos días).

## 3. Secciones que Play exige (Panel → "Configura tu app")
| Sección | Qué responder |
|---|---|
| Política de privacidad | `https://faxird.com/privacidad` |
| Acceso a la app | Hay inicio de sesión: dar la **cuenta de demostración** (sección 6 abajo) |
| Anuncios | No contiene anuncios |
| Clasificación de contenido (IARC) | Respuestas en `FICHAS.md` (18+) |
| Público objetivo | 18 años o más |
| Seguridad de los datos | Tabla de `FICHAS.md` sección 3 |
| Eliminar cuenta | `https://faxird.com/eliminar-cuenta` y en la app (Ajustes → Eliminar mi cuenta) |
| Permisos de ubicación en segundo plano (**solo conductor**) | Texto y video en `FICHAS.md` sección 2 |
| Servicio en primer plano, tipo Ubicación (**solo conductor**) | Igual |
| Aplicación de noticias / salud / finanzas | No aplica |

## 4. Ficha de la tienda
- Descripción corta y completa: `FICHAS.md` (están las dos apps).
- Ícono 512 × 512: exportar `apps/passenger/assets/icon.png` y `apps/driver/assets/icon.png`.
- Gráfico destacado 1024 × 500: `docs/tiendas/play-grafico-destacado.png` (hay que revisarlo con el logo definitivo).
- **Capturas** (mínimo 2, ideal 6 a 8 por app, teléfono 1080 × 1920 o más) con el APK de prueba y cuentas `@faxi.test`, nunca datos reales:

| # | Pasajero | Conductor |
|---|---|---|
| 1 | Inicio "¿A dónde vamos?" | Pantalla de registro de documentos |
| 2 | Cotización con las tarjetas y la ruta por las calles | Conectado esperando viajes |
| 3 | Buscando conductor | Oferta con cuenta regresiva |
| 4 | Conductor en camino (placa y cuenta regresiva) | Viaje en curso con ruta |
| 5 | Viaje en curso (compartir y SOS) | Cobro en efectivo con el total |
| 6 | Calificación | Ganancias |

## 5. Después de subir el primer .aab: el mapa
Play firma con **su propia llave**, distinta de la del APK de prueba. Hay que darla de alta o el mapa sale en blanco:
1. Play Console → app → **Configuración** → **Integridad de la aplicación** → **Firma de la aplicación**.
2. Copiar el **SHA-1** de "Certificado de firma de la aplicación" (no es secreto).
3. Google Cloud → **Credenciales** → clave `faxi-maps-android-2` → en *Restricciones de la aplicación* agregar una fila por paquete
   (`com.faxi.app` y `com.faxi.conductor`) con ese SHA-1. Guardar (tarda unos minutos en aplicar).

## 6. Cuenta de demostración para los revisores de Google
Google necesita entrar a la app. En producción el SMS aún depende de Twilio, así que se usa un **número de prueba con código fijo**:
1. Supabase → **faxi** (producción) → Authentication → Sign In / Providers → Phone → *Test Phone Numbers and OTPs* → agregar un número ficticio con su código (uno para pasajero y otro para conductor).
2. El pasajero se crea solo al entrar. El **conductor demo** necesita estar aprobado (6 documentos aprobados y vehículo aprobado): se prepara con un script de SQL aparte, en producción, **marcado como demo**.
3. Escribir el número y el código en Play (Acceso a la app) y, cuando Google termine la revisión, **borrar los números de prueba** y la cuenta demo.
Esto toca producción: se hace solo cuando el dueño lo apruebe.

## 7. Mensaje para los probadores (WhatsApp)
```
Hola, soy [NOMBRE] de faxi. Estamos probando una app de viajes en Santo Domingo y me ayudarías mucho siendo probador.

Necesito:
1) Tu correo de Gmail (el que usas en tu teléfono Android).
2) Que aceptes la invitación que te llega y descargues la app de Play Store.
3) Que la tengas instalada 14 días, sin desinstalarla. Si puedes, ábrela de vez en cuando y pide un viaje de prueba.

No cobramos nada ni te llega ningún cargo. Si algo falla, escríbeme y lo arreglo.
Gracias.
```
Pasos para ellos: abrir el enlace de participación → "Convertirme en probador" → "Descargar en Google Play". Solo funciona con **Android** y con la **misma cuenta de Gmail** que se registró.

## 8. Mientras Google verifica, no hay que esperar
- Tomar las capturas, juntar los 12 correos y preparar el video de ubicación en segundo plano (guion en `FICHAS.md`).
- Pedir la aprobación del perfil de Twilio y revisar el correo de Google cada día.
- Cambiar el nombre público del desarrollador a `faxi` y poner el correo de soporte.
