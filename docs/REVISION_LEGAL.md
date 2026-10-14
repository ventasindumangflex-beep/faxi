# Revisión legal previa · Términos para conductores (15-oct-2026)

Revisión hecha **sin abogado**, contra la Normativa Técnica del INTRANT para taxis (NT 001-2021), la Ley 63-17, el Código de Trabajo, la Ley 172-13 y la Ley 126-02. Las citas deben confirmarse con un **abogado dominicano** antes de publicar.

## Ya aplicado (migración 011 + términos v1.1)
- [x] Vehículo de **máximo 15 años** (`MAX_VEHICLE_AGE_YEARS = 15` en producción; el año mínimo sube solo cada año).
- [x] El registro del conductor pide **carnet del INTRANT** y **antidoping**, además de licencia, cédula y no antecedentes penales.
- [x] Casilla **sin marcar** para aceptar los términos; se guardan la versión (`drivers.terms_version`) y la fecha (`terms_accepted_at`).
- [x] Términos v1.1:
  - rechazar ofertas no tiene consecuencias;
  - "desactivación" en vez de "suspensión" y "solicitud de revisión" en vez de "descargo";
  - el conductor aporta el vehículo, no tiene horario y puede usar otras apps;
  - deuda exigible aunque cierre la cuenta, con 15 días para reclamar el monto;
  - "faxi nunca pide pagos por otro medio ni a otra cuenta";
  - consentimiento para antidoping y antecedentes;
  - reportes al INTRANT;
  - regla de 200 m de los hoteles;
  - indemnidad, licencia de uso, aviso de 15 días antes de cambios, nulidad parcial y notificaciones;
  - tribunales del Distrito Nacional.

## Falta: necesita la empresa (RNC)
- [ ] **Registro de faxi ante el INTRANT** (oficina, representante legal con poder, documentos constitutivos, RNC y listado de conductores). Es el riesgo más grande.
- [ ] **Póliza de responsabilidad civil** a nombre de faxi (muerte o lesiones, incapacidad, gastos médicos). Completar aseguradora y número en la sección 9.
- [ ] **Cuenta bancaria a nombre de la empresa** para la comisión. Durante el piloto cerrado se usa la del dueño. Antes de abrir al público, cambiar `COMMISSION_PAY_INFO`.
- [ ] **ITBIS de la comisión** (con el contador): "20 % ITBIS incluido" o "20 % + ITBIS", y emitir comprobante fiscal.

## Falta: decisiones o desarrollo
- [ ] Peajes y tiempo de espera: ¿se suman a la tarifa? (sección 6).
- [ ] Plazo de conservación de datos (sección 10; sugerido 10 años por normas fiscales).
- [ ] Geocerca de 200 m alrededor de los hoteles del Gran Santo Domingo (bloquear recogidas). Necesita la lista de hoteles.
- [ ] "Cédula" incluye a extranjeros residentes con cédula: confirmar que es lo deseado.
- [ ] Revisar los **términos de pasajeros** y la **política de privacidad** con el mismo criterio.
- [ ] Seguir la **reforma laboral** (aprobada en primera lectura en mayo de 2026) y la reforma de protección de datos.
