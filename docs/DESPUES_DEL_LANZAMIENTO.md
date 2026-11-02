# faxi · Lo que falta para operar después de que la app esté lista (2-nov-2026)

La app ya está construida. Esto es lo que hace falta para **operar** el negocio. Lo marcado ⚖️ necesita abogado o contador; 👤 lo hace el dueño; 🤖 lo puede preparar Claude.

## 1. Legal, fiscal y permisos
- ⚖️ **Empresa constituida**: razón social y **RNC**. Llenar `[RAZÓN SOCIAL]`, `[RNC]` y la fecha en los términos y la privacidad (`apps/admin/src/legal/`, luego `node scripts/build_sitio.mjs`).
- ⚖️ **Comprobantes fiscales (NCF / e-CF)**: faxi cobra comisión del 10 % y debe emitir comprobante. Definir si el ITBIS va incluido o aparte (campo `[ITBIS INCLUIDO / MÁS ITBIS]` en los términos de conductores).
- ⚖️ **Contabilidad**: los viajes se guardan 10 años (anonimizados, no borrados). Confirmar el plazo con el contador.
- ⚖️ **INTRANT y operación de la plataforma**: confirmar qué permiso o registro necesita faxi como plataforma, y que cada conductor cumpla (carnet INTRANT, antidoping, vehículo de máximo 15 años; la app ya lo exige).
- ⚖️ **Seguro**: qué cubre a pasajeros y conductores durante el viaje (sección 9 de los términos). Sin esto no se debe operar con público.
- ⚖️ **Hoteles y zonas de taxis turísticos (regla de 200 m del INTRANT)**: por decisión del dueño no se cargan por ahora (panel → Zonas vacío). Eso significa que la regla **no se aplica**: confirmar con el abogado el riesgo antes del público.
- 👤 **Marca "faxi" en ONAPI** (nombre y logo). El dominio es `faxird.com` (no `faxi.com`).
- ⚖️ Revisión final de **términos y privacidad** (Ley 172-13 de protección de datos).

## 2. Dinero
- 👤 **Cuenta bancaria de faxi** para que los conductores paguen la comisión (va en el ajuste `COMMISSION_PAY_INFO`, solo la ven admins y conductores aprobados). Se cambia en el panel → Ajustes (solo SUPER_ADMIN).
- 👤 **Rutina de los lunes**: ver Comisiones en el panel, registrar los pagos recibidos. Con deuda mayor de **RD$1,000** el conductor no se conecta.
- 👤 Definir qué se hace si un conductor no paga (suspensión) y cómo se atienden las disputas (15 días, ya en los términos).
- 👤 **Recargo del aeropuerto**: hoy en RD$0 (apagado). Definir el monto con el SUPER_ADMIN en panel → Zonas.
- 👤 **Costos mensuales** (revisar cada mes): Supabase (hoy plan Micro), Twilio (cada SMS cuesta), Google (mapas y Routes; hoy tope de 100 rutas al día), Expo/EAS, dominio y Google Workspace, Apple Developer si se hace iOS.

## 3. Operación diaria
- 👤 **Soporte**: quién atiende el WhatsApp y el correo `soporte@faxird.com`, en qué horario y con qué respuestas tipo.
- 👤 **Aprobación de conductores** (panel → Conductores): quién revisa los 6 documentos y el vehículo, y en cuánto tiempo. La app avisa de documentos que vencen.
- 👤 **Seguridad**: qué se hace ante un accidente, una agresión o un viaje cancelado por emergencia; a quién llamar (911) y cómo se registra.
- 👤 **Pasajeros y conductores iniciales**: abrir con pocos y crecer. Los primeros conductores se invitan uno a uno; sin conductores conectados el viaje termina en "no hay conductores".
- 🤖 Mensajes y respuestas tipo para soporte, avisos a conductores y preguntas frecuentes.

## 4. Técnico (vigilancia)
- 🤖/👤 **Errores**: Sentry (activar alertas por correo). **Base**: revisar los avisos de seguridad de Supabase cada mes.
- 👤 **Respaldos**: el plan Micro guarda copias diarias; para más historial (recuperar a una hora exacta) hay que subir de plan.
- 👤 **Límites**: subir la cuota de Routes API cuando crezca el uso; Places y Maps tienen su propio tope. Poner **alerta de presupuesto** en Google Cloud.
- 👤 **Twilio**: saldo para SMS y alerta de saldo bajo.
- 🤖 **Actualizaciones de las apps**: cada cambio nuevo se compila, se sube a Play y se despliega gradual. Los cambios de base de datos van primero a faxi-pruebas, con prueba, y a producción solo con el visto bueno del dueño.
- 👤 **Seguridad de cuentas**: 2FA en Google, Supabase, Expo, GitHub y Squarespace; repositorio de GitHub **privado**; claves nunca en el repositorio ni en el chat.
- 🤖 Cuenta de demostración para revisores de Play (se borra después).

## 5. Después de la prueba cerrada (Google Play)
1. 14 días seguidos con los 12 probadores dentro; arreglar lo que reporten (se puede subir una versión nueva sin reiniciar el conteo).
2. Pedir **acceso a producción** en Play Console y esperar la revisión.
3. Lanzamiento **gradual** (por ejemplo 10 % → 50 % → 100 %) mirando errores y calificación.
4. Responder las reseñas y mantener la calificación arriba de 4.0.
5. iOS: cuenta de Apple Developer, ficha de App Store y revisión (los textos están en `docs/tiendas/FICHAS.md`); se puede dejar para después de Android.

## 6. Qué medir las primeras semanas
Viajes por día · tiempo hasta que un conductor acepta · viajes sin conductor · cancelaciones · calificación promedio · comisión cobrada y deuda pendiente · conductores aprobados y conectados por hora · costo de SMS y de rutas por viaje.

## 7. Siguientes mejoras (no bloquean el lanzamiento)
Pago con tarjeta · cargar los hoteles · tarifa dinámica en horas pico (el campo `surge_multiplier` ya existe) · viajes programados · idiomas · versión iOS.
