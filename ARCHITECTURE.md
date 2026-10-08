# faxi — Arquitectura del prototipo

Plataforma de movilidad para Santo Domingo con tres apps (Pasajero, Conductor, Admin) en un solo prototipo, seleccionables desde la barra superior. Datos simulados; cada capa se sustituye por servicios reales sin tocar la UI.

## Archivos
- `faxi-standalone-src.dc.html` — fuente principal: selector de rol + app Pasajero; monta `faxi-driver` y `faxi-admin` vía `<dc-import>`.
- `faxi-driver.dc.html` — app Conductor (turno, solicitudes, navegación, espera facturable, ganancias día/semana, cuenta).
- `faxi-admin.dc.html` — panel Admin (KPIs, mapa en vivo, conductores, pasajeros, viajes, pagos, tarifas/promos, reclamaciones, actividad).
- `faxi-core.js` — capa de dominio compartida (`window.FaxiCore`). Única fuente de verdad.
- `android-frame.jsx` — marco del dispositivo.
- `faxi.html` / `faxi.dc.html` — builds autocontenidos (offline). Regenerar desde la fuente tras cada cambio.

## FaxiCore (capa compartida)
- **Bus en tiempo real** — `subscribe(fn)` / `version()`; cada mutación emite y las tres apps re-renderizan al instante.
- **Config / precios** — `config()`, `setFare`, `setPromo`, `setCat`, `setSurge`, `reset`, `quote(cat, km, min, {surge, promo})` → base + distancia + tiempo + mínimo + recargo − descuento, con comisión y neto del conductor. → mover al backend.
- **Persistencia** — config en `localStorage` (`faxi.config.v1`); sobrevive recargas y se sincroniza entre pestañas (evento `storage`). Un navegador/archivo nuevo arranca con valores por defecto (esperado). → tabla de tarifas en BD.
- **Estado en vivo** — `live.passenger` / `live.driver` vía `setLive(app, {phase, …})`; alimenta el mapa en vivo del Admin y genera eventos por cambio de fase.
- **Registros** — `trips()/logTrip`, `drivers()/setDriver`, `passengers()/setPassenger`, `claims()/setClaim`, `events()/event` (últimos 30). → REST/GraphQL + WebSocket.
- **Geo / mapa** — `geo.{pointAt, nav, camera, baseLayer, carShape, lpath…}`: mapa SVG abstracto con calles reales de SD, instrucciones giro a giro y cámara `fit`. Interfaz a mantener al integrar Google Maps / Mapbox: `setCamera(bounds, padding)`, `drawRoute(points)`, `setMarker(id, pos, heading)`.

## Servicios por app (en la lógica de cada componente)
- **trips** — máquina de estados del viaje. → backend de despacho.
- **payments** — autorización simulada (aprobado/rechazado). → Azul, CardNET, Stripe.
- **notifications** — `toast()` heads-up. → FCM / APNs.
- **auth** — validación local. → OTP por SMS + JWT.

## Máquinas de estado
**Pasajero:** splash → onboarding → auth → permission → home → search → pickup → routing → options → confirming → searching (15 s) → assigned → enroute → arrived → started → ontrip → atDest → finished → payment → rating → receipt → history
Ramas: sin conductores · pago rechazado · cancelación (con cargo desde enroute/arrived) · offline global.

**Conductor:** offline → online → request → toPickup → arrived (espera facturable) → onTrip → summary → online
Ramas: rechazar/expirar solicitud · sin conexión · cancelación del pasajero.

## Sincronización entre apps
Admin cambia tarifa/promo/recargo → `FaxiCore.emit` → Pasajero recotiza y Conductor actualiza ganancia estimada al instante. Pasajero/Conductor avanzan de fase → evento en Actividad + posición en Mapa en vivo. Viaje finalizado → `logTrip` → tabla de Viajes y KPIs.

## Transición a MVP (Supabase) — estado
| Fase | Estado |
|---|---|
| 1 Análisis | Hecho |
| 2 Preparar Supabase (`config/faxi.config.js`, `services/supabaseClient.js`, `env.example.js`, `.env.example`) | Hecho · falta credencial |
| 3 Base de datos (`supabase/migrations/*`, `seed.sql`, `tests/001_trip_flow.sql`) | Escrito · pendiente de ejecutar en tu proyecto |
| 4–12 Auth, Pasajero, Conductor, Realtime, Pago, Calificación, Admin, Tests JS | Pendiente |

Fuente de verdad en el servidor: `quote_fare` (PricingService), `commission_split` (CommissionService), `trip_status_transitions` + trigger (TripStateMachine), `validate_vehicle` (MIN_VEHICLE_YEAR), `pay_trip` (PaymentService MOCK). Los clientes solo leen bajo RLS y mutan vía RPC. Ver `docs/SUPABASE_SETUP.md`.

## Pendiente para producción
1. Sustituir FaxiCore por API + WebSocket manteniendo la misma interfaz.
2. Mapa real (Mapbox / Google Maps) detrás de `geo`.
3. Pasarela de pago y OTP reales.
