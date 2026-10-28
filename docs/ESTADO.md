# faxi · Estado del proyecto (15-oct-2026)

Resumen simple de lo hecho y lo que falta. Detalle técnico en `docs/LANZAMIENTO.md`, `docs/PENDIENTES_PRODUCCION.md` y `docs/REVISION_LEGAL.md`.

## ✅ Lo que ya está hecho

### Las apps
- **App de pasajeros:**
  - Entra con SMS, busca direcciones, cotiza y pide viajes.
  - Muestra al conductor en el mapa.
  - Pago en efectivo, calificación, compartir viaje, botón 911, soporte y eliminar cuenta.
  - Pantalla de entrada con el degradado de la marca (`docs/marca/faxi-inicio.png`). En la pantalla de precios, la rayita sube y baja la lista y el botón **Solicitar** siempre se ve.
- **App de conductores:**
  - Registro con documentos: licencia, cédula, no antecedentes, foto, **carnet del INTRANT**, **antidoping**, matrícula, seguro y fotos del carro.
  - Casilla para aceptar los términos.
  - Conectarse, recibir viajes con sonido y vibración, llevar el viaje paso a paso y cobrar en efectivo.
  - Ganancias, con **lo que debe de comisión y dónde pagar**.
- **Panel de administración (en la Mac):**
  - Aprobar conductores y documentos.
  - Ver viajes, tarifas y ajustes, soporte.
  - **Comisiones**: deudas y registrar pagos.
  - **Zonas**: hoteles donde no se recoge.
- Avisos (push), informes de errores (Sentry) e íconos.

### Reglas del negocio (en el servidor)
- Precios, comisión del **20 %**, estados del viaje y búsqueda de conductor.
- Zona: **Gran Santo Domingo** (Distrito Nacional + provincia Santo Domingo). **Haina fuera** en el piloto.
- **Solo efectivo.**
- **Comisión semanal:**
  - El conductor paga **cada lunes**.
  - Si debe más de **RD$2,000** no puede conectarse.
  - Al registrar su pago, vuelve a poder conectarse.
- **Cuentas para pagar la comisión** (Banreservas, Popular, BHD): solo las ven los conductores aprobados. Están cargadas en faxi-pruebas.
- **Carros de máximo 15 años** (hoy 2011 o más nuevo). El año mínimo sube solo cada año.
- **No se recoge a menos de 200 m de hoteles** de la lista (regla del INTRANT).
- Privacidad:
  - El pasajero solo ve la ubicación y el teléfono del conductor durante el viaje.
  - La ubicación en vivo es privada.
  - La seguridad se revisó.

### Base de datos
- **faxi-pruebas** tiene las migraciones 001–012. Pasan todas las pruebas: FAXI OK, FAXI MÓVIL OK, 005, 006, 007, 009, 010, 011 y 012.
- **Producción no se ha tocado.** Todo lo que necesita está listo en `supabase/PRODUCCION_PEGAR.sql`.

### Mapa
- El código del mapa ya está arreglado:
  - limpia la clave;
  - el build falla con un mensaje claro si falta la clave;
  - si el mapa no carga, sale un aviso amarillo.
- Clave nueva de Google Maps creada y cargada en Expo (Development y Preview).
- ✅ **Mapa funcionando en Android (15-oct)** con la app de prueba (APK, perfil *preview*): calles de Santo Domingo, ubicación y búsqueda.

### Web, dominio y correo
- Página web publicada en **faxi.netlify.app**: privacidad, términos, términos de conductores, eliminar cuenta y soporte.
- Dominio **faxird.com** comprado y agregado en Netlify.
- Google Workspace: admin@faxird.com con el alias **soporte@faxird.com**.
- Recordatorio en tu Google Calendar: **25-oct, pagar Google Workspace** (la prueba gratis vence alrededor del 28-oct).

### Legal (borradores, falta abogado)
- **Términos para conductores v1.1, términos de pasajeros v1.1 y privacidad v1.1**, ajustados con la revisión legal previa.
- Lista de lo que falta, en `docs/REVISION_LEGAL.md`.

### Decisiones tomadas
- Comisión: 20 %, pago los lunes, límite de RD$2,000.
- Carros de máximo 15 años (como Uber).
- Haina fuera.
- Durante el piloto cerrado se cobra a tu cuenta personal. Luego se cambia a la de la empresa.
- **(16-oct) Sin registro en el INTRANT por ahora** (decisión del dueño, conociendo el riesgo de multas y retenciones). Sí se hacen la empresa con RNC y la póliza de responsabilidad civil. Los términos v1.2 ya no dicen que faxi esté registrada, y la publicidad tampoco puede decirlo.

## ⏳ Lo que falta

### 🟢 Se puede hacer ya (sin la empresa)
1. ~~Instalar la app de prueba y ver el mapa~~ ✅ hecho el 15-oct. ~~Borrar la clave vieja `faxi-maps-android`~~ ✅ 26-oct. Queda una "Copia de faxi-maps-android-2" sin uso conocido: revisar y borrar si no se usa.
2. **faxird.com:** los 2 registros DNS en Squarespace (`docs/LANZAMIENTO.md`, arriba) y confirmar el correo de contacto del dominio ("Acción requerida", para que no lo suspendan).
3. **Correo:** completar la configuración que pide Google Workspace ("Acción necesaria"), para que los correos no lleguen a spam.
4. **Hacer privado el repositorio** en GitHub.
5. **Cargar los hoteles** en el panel → *Zonas*.
6. **Números de prueba sin SMS** en Supabase (faxi-pruebas), para usar 2 teléfonos.
7. **App del conductor** (27-oct): conductor de prueba registrado con sus 6 documentos y aprobado en el panel; se conecta y ya completó un viaje de prueba (cobro y calificación bien).
   - **Mapa:** la clave de Maps que tenía `faxi-conductor` en Expo era distinta a la del pasajero. Se corrigió el 27-oct y se hizo el build `b9c25fae` (APK preview). El paquete `com.faxi.conductor` y su SHA-1 ya están en `faxi-maps-android-2`. **Confirmado el 28-oct en un teléfono: el mapa del conductor carga** con ese build (Santo Domingo, estado "En línea"). No hace falta tocar nada más en Google para el mapa.
   - **Twilio sin aprobar:** solo manda SMS a números verificados (error 21608). Antes del piloto hay que completar el **Primary Customer Profile** en Twilio → Trust Hub. Mientras tanto: verificar cada número en *Verified Caller IDs*, o usar números de prueba con código fijo en Supabase (solo faxi-pruebas).
   - **Pendiente de limpieza:** al terminar las pruebas, borrar los números de prueba con código fijo en Supabase (faxi-pruebas → Authentication → Sign In / Providers → Phone).
8. **Viaje completo con 2 teléfonos** (pasajero y conductor).
10. **Pagar Google Workspace** antes del 28-oct.
11. **Piloto cerrado** con amigos y conductores que ya trabajan en Uber o inDrive (ya tienen carnet y antidoping).
12. Decidir:
    - si los **peajes y el tiempo de espera** se suman a la tarifa;
    - el **plazo de conservación de datos** (sugerido: 10 años para viajes, 90 días para ubicaciones);
    - el **WhatsApp de soporte**.

### 🔴 Necesita la empresa (RNC)
13. **Empresa con RNC.** Es lo primero, porque desbloquea todo lo demás.
14. **Registro de faxi en el INTRANT.**
15. **Póliza de responsabilidad civil** a nombre de faxi.
16. **Cuenta de banco de la empresa** para las comisiones (cambiar `COMMISSION_PAY_INFO`).
17. **Twilio**, para SMS a cualquier número.
18. **Supabase de producción**, en plan Pro. Se pega `PRODUCCION_PEGAR.sql` con tu visto bueno y se cargan las variables "Production" en Expo.
19. **Google Play** (cuenta de empresa): prueba cerrada, ficha y capturas.
20. **Apple Developer** (cuenta de empresa): app de iPhone y App Store.

### 🟡 Personas que ayudan
- **Contador:** ITBIS de la comisión ("20 % incluido" o "20 % + ITBIS") y comprobantes fiscales.
- **Abogado dominicano:** revisar los términos y la privacidad antes de publicar.
- **Gestor o abogado:** registro en el INTRANT.
- **Corredor de seguros:** la póliza.

### 🔧 Técnico, más adelante
- Actualizar faxi a la versión 57 de Expo (para probar en iPhone con Expo Go).
- Sentry: crear el proyecto y poner su clave en Expo.

## 📝 Decisiones de la reunión con Virgilio (22-oct) · pendientes de aplicar
- **Comisión: 10 %** (antes 20 %). Falta decidir cómo tratar la prueba FAXI OK, que tiene el 20 % escrito (regla 5): ajustarla para que lea la comisión configurada, o dejar el 20 % solo en faxi-pruebas.
- **Tarifas más atractivas**, sobre todo Premium, SUV y Van. Propuesta para 5 km / 12 min: Económico RD$290 (igual, mínimo RD$150), Confort RD$335, Premium RD$437, SUV RD$484, Van RD$536.
- **Gastos 50/50** entre los socios hasta que faxi sea rentable (agregar al acuerdo de socios).
- **Números de prueba sin SMS** (faxi-pruebas → Auth → Phone → Test numbers): 18094093887 y 18296332695.
- **Hoteles (regla de 200 m):** falta decidir si se quedan, con la lista que dé Virgilio, o si se quita la regla.
- **Prueba de viaje completo** con 2 teléfonos el sábado o domingo, con Virgilio. Ese día: enseñarle el panel y crearle su usuario admin.
- **Producción (Supabase faxi):** el dueño la aprobó. Se hace después de aplicar tarifas y comisión en pruebas y con las 2 pruebas OK.
- **Google Play:** cuenta personal (US$25, verificación de 1 a 3 días). Exige una prueba cerrada con 12 personas durante 14 días, que sirve como piloto.
- **SRL:** cuando la app esté lista. **Cuenta de banco:** unos 2 meses después de arrancar. **Contador:** la mamá del dueño.
- **Hecho:** Google Workspace pagado, clave vieja de Maps borrada.
- **Por decidir:** peajes, tiempo de espera y WhatsApp de soporte.
