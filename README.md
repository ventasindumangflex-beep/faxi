# FAXI · MVP source

## Ejecutar el prototipo
Servir la carpeta con cualquier servidor estático (los módulos se cargan por ruta relativa; no abrir con file://):
```
npx serve .        # o: python3 -m http.server 8080
```
Abrir `faxi-standalone-src.dc.html` (selector de rol Pasajero / Conductor / Admin).
Requiere internet para React, fuentes y Babel (CDN).

## Estructura
- `faxi-standalone-src.dc.html` — entrada + app Pasajero; importa `faxi-driver` y `faxi-admin`
- `faxi-driver.dc.html`, `faxi-admin.dc.html` — apps Conductor y Admin
- `faxi-core.js` — capa de dominio compartida (modo MOCK)
- `android-frame.jsx` — marco de dispositivo
- `support.js` — runtime de los Design Components (requerido)
- `config/faxi.config.js`, `services/supabaseClient.js`, `env.example.js`, `.env.example` — fase 2
- `supabase/migrations/*`, `supabase/seed.sql`, `supabase/tests/001_trip_flow.sql` — fase 3
- `docs/SUPABASE_SETUP.md`, `ARCHITECTURE.md`

Fases 2–3 escritas, sin ejecutar. Fases 4+ (cableado de la UI a Supabase) pendientes.
