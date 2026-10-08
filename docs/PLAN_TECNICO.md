# FAXI · Plan técnico para lanzamiento real

**Objetivo:** apps nativas (Android + iPhone) para pasajeros y conductores, panel web de administración, en todo Santo Domingo.
**Escala inicial:** ~500 pasajeros (≈175 frecuentes) · ~800 conductores registrados · lanzamiento gradual.
**Constructor:** tú, con Claude Code. **Plazo deseado:** 1 mes.

> ⚠ Verifica la cifra: 800 conductores para 500 pasajeros es poco habitual (normalmente es al revés). No cambia la arquitectura, pero sí el plan de captación: con más conductores que viajes, muchos se irán por falta de ingresos. Recomiendo **activar conductores por tandas** (p. ej. 80–120 al inicio) y abrir más según la demanda.

---

## 1. Decisiones

| Tema | Decisión | Por qué |
|---|---|---|
| Apps móviles | **2 apps Expo (React Native)**: `faxi` (pasajero) y `faxi-conductor` | El conductor necesita ubicación en segundo plano; pedírsela a pasajeros provoca rechazos en las tiendas y desconfianza. |
| Admin | **Web (Next.js)** | Uso en escritorio; no va a tiendas. |
| Backend | **Supabase Pro** (lo ya escrito en `supabase/`) | Postgres + Auth + Realtime + Storage. 1000 usuarios es una carga muy baja. |
| Mapas | **Google Maps** (`react-native-maps` + Places Autocomplete + Routes API) | Mejor cobertura de direcciones y lugares en RD que Mapbox. El mapa móvil nativo no se cobra por carga; se pagan autocompletado y rutas. |
| Login | **Teléfono + código SMS (OTP)** vía Supabase Auth + Twilio Verify | Estándar en movilidad; evita contraseñas. |
| Notificaciones | **Expo Notifications** (FCM/APNs) | Gratis, integrado con Expo. |
| Pagos | **Lanzar solo con efectivo**; Azul y CardNET en fase 2 | La afiliación de comercio con Azul/CardNET toma semanas. **Inicia el trámite hoy.** |
| Builds y publicación | **EAS Build + EAS Submit** | Compila y sube a las tiendas sin Mac propio (iOS). |
| Errores | **Sentry** (plan gratis) | Saber qué falla en teléfonos reales. |

---

## 2. Arquitectura

```
faxi/                         (monorepo)
├─ apps/
│  ├─ passenger/              Expo · app pasajero
│  ├─ driver/                 Expo · app conductor (ubicación en segundo plano)
│  └─ admin/                  Next.js · panel web
├─ packages/
│  ├─ core/                   tipos, cliente Supabase, llamadas RPC, formato RD$, estados del viaje
│  └─ ui/                     tokens de diseño + componentes compartidos (botón, tarjeta, hoja inferior)
├─ supabase/                  migraciones, seed, tests  (ya existe)
└─ prototype/                 los .dc.html actuales como referencia visual
```

**Flujo de datos**
- Las apps **solo leen** tablas (protegidas por RLS) y **escriben únicamente vía RPC** (`request_trip`, `accept_trip_request`, `driver_advance_trip`, `cancel_trip`, `rate_trip`, `pay_trip`). Precio, comisión y estados se calculan en el servidor.
- **Tiempo real:** el pasajero se suscribe a su fila en `trips`; el conductor a sus `trip_requests`; el admin a `trips` y `drivers`.
- **Ubicación del conductor:** cada 5 s se transmite por **Realtime Broadcast** (canal `trip:<id>`, no toca la base) y cada 30 s se guarda con `update_location`. Así 200 conductores en línea generan ~7 escrituras/s: trivial.
- **Despacho:** SQL actual (los 5 más cercanos dentro de 8 km, oferta de 30 s). Suficiente para esta escala; la distancia en línea recta se reemplaza por Routes API más adelante si hace falta.
- **Vencimientos:** activar `pg_cron` cada 15 s (`expire_stale()`).
- **Pagos (fase 2):** Edge Function crea la orden en Azul/CardNET → la pasarela confirma por webhook → la función marca `PAID` con service_role. `pay_trip` simulado se desactiva (`PAYMENT_PROVIDER` ≠ `MOCK`).

**Qué se reutiliza del prototipo:** pantallas, textos, flujos y máquinas de estado (se reescriben como componentes React Native siguiendo los `.dc.html`), y todo `supabase/`.
**Qué no se reutiliza:** `faxi-core.js` (simulación), el mapa SVG, `support.js` y el marco del teléfono.

---

## 3. Cambios necesarios en el backend ya escrito
1. Login por teléfono: activar el proveedor Phone en Supabase Auth y ajustar `handle_new_auth_user` para usar el teléfono como identificador.
2. RPC `delete_my_account()`: **Apple y Google exigen borrar la cuenta desde la app.**
3. Tabla `push_tokens(user_id, token, platform)` + trigger que envíe la notificación al insertar en `notifications` (Edge Function → Expo Push API).
4. RPC de alta del conductor: datos personales + vehículo + subida de documentos a Storage → queda `PENDING` para el admin.
5. Zonas de servicio: reemplazar el rectángulo de RD en `assert_in_service_area` por un polígono del Gran Santo Domingo (PostGIS).
6. Activar `pg_cron`.

---

## 4. Cronograma (4 semanas, a tiempo completo)

**Semana 1 · Cimientos**
- Crear Supabase Pro, correr migraciones + `tests/001_trip_flow.sql` (debe salir `FAXI OK`).
- Cambios de backend 1–3 de la sección 3.
- Monorepo, dos apps Expo con login OTP, `packages/core`.
- Abrir cuentas: Apple Developer, Google Play (ver sección 6), Google Cloud (Maps), Twilio, Sentry.
- **Solicitar afiliación a Azul y CardNET.**

**Semana 2 · App pasajero**
- Mapa, búsqueda de origen y destino (Places), cotización (`quote_trip`), solicitud, búsqueda de conductor, seguimiento en vivo, cancelación, calificación, historial.
- Notificaciones push.

**Semana 3 · App conductor + Admin**
- Alta con documentos, conectarse/desconectarse, ubicación en segundo plano, recibir/aceptar/rechazar, navegación (abrir Google Maps/Waze), avanzar estados, cobro en efectivo, ganancias.
- Admin: aprobar conductores/vehículos/documentos, viajes en vivo, tarifas y comisión, reclamaciones.

**Semana 4 · Prueba real y publicación**
- Piloto cerrado: 10–20 conductores y 30–50 pasajeros de confianza, viajes reales con efectivo.
- Corregir fallos (Sentry), política de privacidad, términos, borrado de cuenta.
- Enviar a revisión de App Store y Google Play.

**Semanas 5–8 · Fase 2**
- Pagos con tarjeta (Azul/CardNET), activar conductores por tandas, ajustes de despacho, recibos por correo.

**Realismo:** 1 mes es suficiente para un **piloto cerrado funcionando**. La publicación abierta en ambas tiendas probablemente caerá en la semana 5–6 por los tiempos de revisión y de cuentas (sección 6).

---

## 5. Costos mensuales estimados (verificar precios vigentes al contratar)

| Servicio | Costo |
|---|---|
| Supabase Pro | ~US$25/mes |
| Google Maps (Places + Routes) | US$0–60/mes a esta escala (hay cuota gratuita mensual) |
| Twilio Verify (SMS a RD) | Variable por SMS; estimar US$20–60/mes con ~1000 usuarios |
| Vercel (admin, uso comercial) | ~US$20/mes |
| EAS (Expo) | Gratis al inicio; ~US$19/mes si necesitas más builds |
| Sentry | Gratis |
| Apple Developer | US$99/año |
| Google Play | US$25 pago único |
| Dominio + correo | ~US$15/año + correo |
| **Total aproximado** | **US$70–200/mes** + US$124 iniciales |

Azul/CardNET cobran comisión por transacción según contrato.

---

## 6. Riesgos de calendario (atender en la semana 1)

1. **Google Play, cuenta personal nueva:** exige una prueba cerrada con al menos 12 testers durante 14 días antes de publicar. **Solución:** cuenta de **organización**, que requiere número **D-U-N-S** (gratis, puede tardar días o semanas). Solicítalo ya.
2. **Apple:** la cuenta de organización también usa D-U-N-S. La revisión de cada versión suele tardar 1–3 días; las apps de movilidad suelen recibir preguntas sobre la ubicación en segundo plano.
3. **Ubicación en segundo plano (Android):** Google exige un aviso visible en la app, una justificación y un video del uso. Prepararlo en la semana 3.
4. **Afiliación de pagos:** Azul y CardNET piden documentos de empresa (RNC, cuenta bancaria). Por eso se lanza con efectivo.
5. **Legal:** política de privacidad conforme a la Ley 172-13 de protección de datos personales de RD; términos para pasajeros y conductores; revisar requisitos de INTRANT para plataformas de transporte. **Consultar con un abogado local.**

---

## 7. Checklist de lanzamiento

**Cuentas y legal**
- [ ] Empresa / RNC · D-U-N-S
- [ ] Apple Developer (organización) · Google Play (organización)
- [ ] Google Cloud con facturación y claves restringidas por app
- [ ] Twilio · Sentry · dominio · correo de soporte
- [ ] Política de privacidad y términos publicados en una URL
- [ ] Solicitud a Azul / CardNET enviada

**Backend**
- [ ] Migraciones aplicadas · `FAXI OK` en el test
- [ ] Login por teléfono activo · rate limit de SMS configurado
- [ ] `pg_cron` activo · backups diarios (incluidos en Pro)
- [ ] Polígono de zona de servicio
- [ ] `PAYMENT_PROVIDER = MOCK` solo hasta activar la pasarela

**Apps**
- [ ] Borrado de cuenta dentro de la app
- [ ] Permisos con textos claros en español (ubicación, notificaciones, cámara para documentos)
- [ ] Funciona con mala conexión: reintentos, estado "sin conexión", el viaje se recupera al reabrir la app
- [ ] Botón de emergencia / compartir viaje
- [ ] Iconos, capturas de pantalla y descripción para las tiendas
- [ ] Sentry recibiendo errores desde builds de producción

**Operación**
- [ ] Proceso de aprobación de conductores (quién revisa, en cuánto tiempo)
- [ ] WhatsApp o canal de soporte atendido durante el piloto
- [ ] Primera tanda de conductores capacitada (10–20)
- [ ] Tarifas finales cargadas en el admin

---

## 8. Cómo trabajar con Claude Code
Abre la carpeta del proyecto en Claude Code. `CLAUDE.md` le da el contexto. Pídele **una tarea a la vez**, en este orden:

1. "Lee `docs/PLAN_TECNICO.md` y `docs/SUPABASE_SETUP.md`. Ayúdame a aplicar las migraciones en mi proyecto Supabase y a correr el test."
2. "Implementa los cambios de backend 1–3 de la sección 3 como una nueva migración, con test."
3. "Crea el monorepo de la sección 2 con las apps Expo y el login por OTP."
4. "Implementa la app pasajero siguiendo `prototype/faxi-standalone-src.dc.html` pantalla por pantalla."
5. "Implementa la app conductor siguiendo `prototype/faxi-driver.dc.html`."
6. "Implementa el admin siguiendo `prototype/faxi-admin.dc.html`."

Después de cada paso: probar en tu teléfono (Expo dev build), confirmar y pasar al siguiente.
