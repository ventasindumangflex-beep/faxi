# faxi · Ideas para futuras actualizaciones

Cosas que el dueño quiere hacer **después** del lanzamiento. No bloquean la prueba cerrada ni el piloto. Cada una, cuando se haga, sigue las reglas del proyecto: migración nueva + prueba, primero en faxi-pruebas y a producción solo con el visto bueno del dueño.

## 1. Saldo prepagado del conductor (idea del dueño, 2-nov-2026)
**Idea:** el conductor paga **RD$200 por adelantado** para empezar a recibir viajes. Ese dinero es **saldo a su favor**: se le va descontando la comisión (10 %) de cada viaje en efectivo. Cuando se acaba, no recibe viajes hasta recargar.

**Por qué:** hoy el conductor trabaja primero y paga después (bloqueo al deber más de RD$1,000), y faxi corre el riesgo de no cobrar. Con saldo prepagado ese riesgo desaparece. Con RD$200 y ~RD$48 de comisión por viaje (RD$480 × 10 %) alcanza para unos 4 viajes.

**Plantearlo como saldo, no como cuota de entrada.** "No pierdes nada: es tu saldo y se usa en tus comisiones" se vende mejor que "pagas para trabajar".

**Se puede probar hoy sin programar** (solo configuración):
1. El conductor transfiere o deposita RD$200.
2. Un admin lo registra en el panel → Comisiones como un pago (queda con deuda negativa = saldo a favor).
3. Un SUPER_ADMIN pone `COMMISSION_DEBT_LIMIT` en `0` (hoy 1000). `guard_driver_debt` y `check_driver_debt_after_trip` ya bloquean cuando `owed > límite`.
Limitaciones sin código: la app solo dice "Debes RD$X" (no muestra el saldo a favor) y cada recarga se registra a mano.

**Lo que falta construir en la versión completa:**
- Mostrar en la app del conductor el **saldo a favor** y un aviso de **saldo bajo**.
- Recarga con comprobante (foto del depósito) y registro más rápido en el panel.
- Cambiar los términos de conductores (v1.5: prepago, reembolso) y que cada conductor los acepte otra vez (`accept_driver_terms`).
- Reglas nuevas: monto mínimo, qué pasa con el saldo si el conductor se va (reembolso), y saldo inicial de regalo para los primeros conductores.

**Decidir antes:** monto (RD$200 alcanza para ~4 viajes; RD$500 para una semana), política de reembolso, comprobante fiscal del adelanto (contador) y si los primeros ~20 conductores reciben el saldo inicial gratis.

## 2. Códigos de invitación y de descuento
Invitar a otro conductor o pasajero y ganar algo (p. ej. comisión en cero en los primeros viajes). Hoy `quote_fare` ya acepta un descuento por dentro, pero no hay códigos, créditos ni pantalla. Un descuento lo paga faxi, no el conductor: dar solo en el primer viaje y con tope.

## 3. Otras
Cargar hoteles y zonas de taxis turísticos (regla de 200 m del INTRANT) · pago con tarjeta · tarifa dinámica en horas pico (`surge_multiplier` ya existe) · viajes programados · versión iOS · definir el recargo del aeropuerto (hoy RD$0).
