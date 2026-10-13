# Fichas de tienda · faxi y faxi Conductor

Textos listos para copiar en Google Play Console y App Store Connect. Lo que está entre **[corchetes]** lo completa el dueño.
Revisar que lo dicho aquí coincida con la [política de privacidad](../../apps/admin/src/legal/privacidad.md): las tiendas rechazan fichas que contradicen la política.

URLs que piden las tiendas (se sirven desde el panel web, `apps/admin`, una vez publicado en Vercel o en el dominio):
- Política de privacidad: `https://[DOMINIO]/privacidad`
- Términos pasajeros: `https://[DOMINIO]/terminos` · Términos conductores: `https://[DOMINIO]/terminos-conductores`
- Eliminar cuenta (Google lo exige como enlace web): `https://[DOMINIO]/eliminar-cuenta`
- Soporte: `https://wa.me/[NÚMERO]` o `mailto:[CORREO DE SOPORTE]`

Recursos gráficos (generados con `scripts/make_icons.py`):
- Ícono 512×512 para Play: exportar `apps/passenger/assets/icon.png` / `apps/driver/assets/icon.png` a 512 px (o subir el de 1024; Play lo acepta y lo reduce).
- Gráfico destacado Play 1024×500: `docs/tiendas/play-grafico-destacado.png`.
- Capturas: **pendiente** — se toman del teléfono durante el piloto (ver lista al final).

---

## 1. faxi (pasajeros) · `do.faxi.app`

**Nombre (30):** `faxi: viajes en Santo Domingo`

**Subtítulo App Store (30):** `Pide tu viaje en segundos`

**Descripción corta Play (80):** `Pide un viaje seguro en el Gran Santo Domingo. Ve la tarifa antes y paga en efectivo.`

**Descripción completa:**

```
faxi es la forma fácil de moverte por el Gran Santo Domingo.

Pide tu viaje en segundos, ve cuánto cuesta antes de confirmarlo y paga en efectivo al llegar. Sin sorpresas, sin regateo.

CÓMO FUNCIONA
• Escribe a dónde vas. Tu punto de recogida se fija con tu ubicación.
• Elige la categoría: Económico, Confort, Premium, SUV o Van, cada una con su tarifa estimada.
• Un conductor cercano acepta tu viaje y lo ves llegar en el mapa en tiempo real.
• Al terminar, pagas en efectivo y calificas a tu conductor.

VIAJA SEGURO
• Todos los conductores son verificados: cédula, licencia, buena conducta y documentos del vehículo.
• Antes de subir, confirma que la placa y el vehículo coinciden con los de la app.
• Comparte tu viaje con familiares o amigos con un toque.
• Botón de emergencia para llamar al 911 durante el viaje.

TARIFAS CLARAS
• Ves la tarifa estimada antes de pedir el viaje.
• Pagas en pesos dominicanos, en efectivo, directamente al conductor.

DÓNDE FUNCIONA
Distrito Nacional y provincia Santo Domingo: Santo Domingo Este, Norte y Oeste, Boca Chica, Los Alcarrizos, Pedro Brand, el Aeropuerto Las Américas y más.

¿Dudas o algo salió mal? Escríbenos desde Soporte en la app o por WhatsApp.
```

**Palabras clave App Store (100):** `taxi,viaje,transporte,Santo Domingo,RD,conductor,carro,aeropuerto,efectivo,movilidad,dominicana`

**Categoría:** Play: *Mapas y navegación* · App Store: principal *Viajes*, secundaria *Navegación*.

**Clasificación de contenido (cuestionario IARC):** sin violencia, sexo, lenguaje, drogas ni apuestas. Responder **Sí** a "los usuarios pueden interactuar" (pasajero–conductor) y a "comparte la ubicación del usuario con otros usuarios". Resultado esperado: *Todo público / 4+* con la nota de ubicación compartida. Edad objetivo en Play: **18+**.

---

## 2. faxi Conductor · `do.faxi.conductor`

**Nombre (30):** `faxi Conductor`

**Subtítulo App Store (30):** `Gana dinero conduciendo`

**Descripción corta Play (80):** `Conduce con faxi en el Gran Santo Domingo. Tú decides cuándo conectarte.`

**Descripción completa:**

```
faxi Conductor es la app para quienes manejan con faxi en el Gran Santo Domingo.

TÚ DECIDES CUÁNDO
• Conéctate cuando quieras y recibe solicitudes de viaje cercanas.
• Ve el origen, el destino y la tarifa antes de aceptar.

TODO EN LA APP
• Navega al punto de recogida con Google Maps o Waze.
• Avisa tu llegada, inicia y termina el viaje con un toque.
• Cobra en efectivo y confirma el pago en la app.
• Consulta tus ganancias de hoy y de los últimos 7 días, viaje por viaje.

REGÍSTRATE FÁCIL
• Completa tus datos y los de tu vehículo.
• Sube fotos de tu licencia, cédula, certificado de buena conducta, matrícula y seguro.
• El equipo de faxi revisa tus documentos y te avisa cuando estés aprobado.

SEGURIDAD
• Pasajeros con cuenta verificada por teléfono y calificaciones.
• Botón de emergencia para llamar al 911.

Para recibir viajes, faxi Conductor usa tu ubicación mientras estás conectado, también con la app en segundo plano. Al desconectarte deja de usarla.
```

**Palabras clave App Store (100):** `conductor,chofer,manejar,ganar dinero,viajes,taxi,Santo Domingo,RD,transporte,faxi`

**Categoría:** Play: *Mapas y navegación* · App Store: principal *Navegación*, secundaria *Negocios*.

**Clasificación de contenido:** igual que la de pasajeros. Edad objetivo en Play: **18+**.

### Declaración de ubicación en segundo plano (Google Play → Contenido de la app → Permisos de ubicación)

**Función principal que requiere ubicación en segundo plano:**
```
Los conductores de faxi reciben solicitudes de viaje según su cercanía al pasajero. Mientras el conductor está "Conectado", la app envía su ubicación para (1) asignarle solicitudes de pasajeros cercanos y (2) mostrar al pasajero, durante el viaje, dónde está el conductor y cuánto falta para que llegue. Los conductores suelen tener abierta la app de navegación (Google Maps o Waze), por lo que faxi Conductor queda en segundo plano durante la mayor parte del viaje; sin ubicación en segundo plano el pasajero dejaría de ver al conductor y el conductor dejaría de recibir viajes. La recopilación empieza cuando el conductor toca "Conectarse" y se detiene cuando toca "Desconectarse". Se muestra una notificación permanente "faxi Conductor · Conectado" mientras está activa.
```

**Guion del video (30–60 s, grabar la pantalla del teléfono, subir a YouTube como "no listado"):**
1. Abrir faxi Conductor ya aprobado. Tocar **Conectarse**.
2. Se muestra el aviso "Uso de tu ubicación" → tocar **Entendido** → aceptar el permiso del sistema **"Permitir todo el tiempo"**.
3. Mostrar la notificación "faxi Conductor · Conectado" en la barra.
4. Llega una solicitud → **Aceptar** → tocar **Navegar** (se abre Google Maps, faxi pasa a segundo plano).
5. En otro teléfono (pasajero) mostrar el carro moviéndose en el mapa.
6. Volver a faxi Conductor → **Desconectarse** → la notificación desaparece.

### Notas para la revisión de Apple (App Review Information)
```
faxi Conductor is a driver app for a ride-hailing service in Santo Domingo, Dominican Republic.
Background location ("Always") is used only while the driver is Online, to dispatch nearby ride requests and show the driver's live position to the passenger during an active trip. It stops when the driver goes Offline. A blue location indicator is shown while active.
Demo account: phone [+1 809 TEST NUMBER] – SMS code [123456] (Supabase test number, no real SMS is sent). The demo driver is already approved.
Account deletion: Account → Delete account.
```
Configurar antes ese número de prueba en Supabase → Authentication → Providers → Phone → *Test phone numbers and OTPs*, tanto para pasajero como para conductor (los revisores de Apple y de Google entran con él).

---

## 3. Seguridad de los datos (Google Play) y Privacidad (App Store)

Mismas respuestas para ambas apps, salvo donde dice *solo conductor*.

| Dato | ¿Se recopila? | ¿Se comparte con terceros?* | Para qué | ¿Opcional? |
|---|---|---|---|---|
| Ubicación precisa | Sí | No | Funcionalidad de la app | No |
| Ubicación aproximada | Sí | No | Funcionalidad de la app | No |
| Nombre | Sí | No | Funcionalidad, gestión de la cuenta | No |
| Número de teléfono | Sí | No | Gestión de la cuenta, funcionalidad | No |
| Otra información personal (cédula, licencia, buena conducta) · *solo conductor* | Sí | No | Gestión de la cuenta, prevención de fraude y seguridad | No |
| Fotos (documentos y vehículo) · *solo conductor* | Sí | No | Gestión de la cuenta, seguridad | No |
| Historial de compras (viajes y montos) | Sí | No | Funcionalidad de la app | No |
| Mensajes a soporte | Sí | No | Atención al cliente | Sí |
| Registros de fallos y diagnósticos | Sí | No | Estadísticas, corrección de errores | No |
| ID del dispositivo (token de notificaciones) | Sí | No | Funcionalidad (notificaciones) | Sí |

\* Los proveedores que procesan datos por cuenta de faxi (Supabase, Twilio, Google Maps, Expo, Sentry) **no** cuentan como "compartir" en la definición de Google ni de Apple.

- ¿Los datos se cifran en tránsito? **Sí**.
- ¿El usuario puede pedir que se borren sus datos? **Sí**: en la app (Cuenta → Eliminar cuenta) y en `https://[DOMINIO]/eliminar-cuenta`.
- ¿Se usan para publicidad o seguimiento (Apple "Tracking")? **No**.
- Apple: marcar todos los datos como **vinculados al usuario**, **no** usados para tracking.

---

## 4. Capturas de pantalla que faltan (tomar en el piloto)

Teléfono Android 1080×1920 o mayor; para iPhone, 6,7" (1290×2796) y 6,5" (1242×2688).

**Pasajero (5–8):** inicio con mapa · búsqueda de destino · cotización con categorías · buscando conductor · conductor en camino (placa visible) · viaje en curso con botones Compartir y 911 · calificación · historial.

**Conductor (5–8):** registro de documentos · en revisión · conectado esperando · solicitud entrante · navegando / viaje en curso · confirmar cobro en efectivo · ganancias.

Consejo: usar datos de faxi-pruebas (cuentas @faxi.test), nunca datos de personas reales.
