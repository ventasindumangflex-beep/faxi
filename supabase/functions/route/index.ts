// FAXI · Edge Function: ruta real por las calles (migración 022).
// La llaman las apps con la sesión del usuario (verify_jwt activo). Consulta la Routes API de Google con una clave que SOLO vive
// aquí (secreto GOOGLE_ROUTES_KEY), guarda distancia, tiempo y línea de la ruta en route_cache (solo escribe la llave de servicio)
// y la devuelve. Si ya hay una ruta de las últimas 6 horas, la devuelve sin gastar una consulta a Google.
// route_estimate() en la base usa esa ruta guardada para cotizar: el precio sale de la distancia real y no se puede falsear desde la app.
// Si Google falla o no hay clave, responde 502 { fallback: true } y las apps siguen con la estimación de siempre.
// Deploy:  supabase functions deploy route        (con "Verify JWT" ENCENDIDO)
// Secreto: supabase secrets set GOOGLE_ROUTES_KEY=...   (clave de Google Cloud restringida a "Routes API")
import { createClient } from 'jsr:@supabase/supabase-js@2';

type P = { lat: number; lng: number };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const ok = (p: unknown): p is P => !!p && typeof (p as P).lat === 'number' && typeof (p as P).lng === 'number'
  && (p as P).lat >= 17.3 && (p as P).lat <= 20.1 && (p as P).lng >= -72.1 && (p as P).lng <= -68.2;
const r4 = (n: number) => Math.round(n * 1e4) / 1e4;
const straightKm = (a: P, b: P) => {
  const x = Math.sin(((b.lat - a.lat) * Math.PI) / 360) ** 2
    + Math.cos((a.lat * Math.PI) / 180) * Math.cos((b.lat * Math.PI) / 180) * Math.sin(((b.lng - a.lng) * Math.PI) / 360) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(x));
};

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Método no permitido' }, 405);
  let body: { o?: unknown; d?: unknown };
  try { body = await req.json(); } catch { return json({ error: 'Datos inválidos' }, 400); }
  if (!ok(body.o) || !ok(body.d)) return json({ error: 'Origen o destino fuera del área' }, 400);
  const o = body.o, d = body.d;
  const crow = straightKm(o, d);
  if (crow < 0.05) return json({ error: 'El destino debe ser distinto del origen' }, 400);

  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const key = { o_lat: r4(o.lat), o_lng: r4(o.lng), d_lat: r4(d.lat), d_lng: r4(d.lng) };

  const { data: hit } = await sb.from('route_cache').select('distance_km, duration_min, polyline, created_at').match(key).maybeSingle();
  if (hit && Date.now() - new Date(hit.created_at).getTime() < 6 * 3600 * 1000) {
    return json({ distance_km: Number(hit.distance_km), duration_min: Number(hit.duration_min), polyline: hit.polyline, source: 'cache' });
  }

  const apiKey = Deno.env.get('GOOGLE_ROUTES_KEY');
  if (!apiKey) return json({ error: 'Ruta no disponible', fallback: true }, 502);
  let res: Response;
  try {
    res = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'X-Goog-Api-Key': apiKey, 'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline' },
      body: JSON.stringify({
        origin: { location: { latLng: { latitude: o.lat, longitude: o.lng } } },
        destination: { location: { latLng: { latitude: d.lat, longitude: d.lng } } },
        travelMode: 'DRIVE', routingPreference: 'TRAFFIC_AWARE', languageCode: 'es-419', units: 'METRIC',
      }),
      signal: AbortSignal.timeout(8000),
    });
  } catch { return json({ error: 'Ruta no disponible', fallback: true }, 502); }
  if (!res.ok) return json({ error: 'Ruta no disponible', fallback: true }, 502);

  const route = (await res.json())?.routes?.[0];
  const meters = Number(route?.distanceMeters), secs = parseFloat(String(route?.duration ?? '').replace('s', ''));
  const polyline = route?.polyline?.encodedPolyline;
  const km = Math.round((meters / 1000) * 100) / 100, min = Math.round((secs / 60) * 10) / 10;
  // Respuesta con sentido: ni menor que la línea recta ni absurdamente larga
  if (!Number.isFinite(km) || !Number.isFinite(min) || typeof polyline !== 'string' || km < Math.max(0.1, crow * 0.9) || km > crow * 4 + 2) {
    return json({ error: 'Ruta no disponible', fallback: true }, 502);
  }
  const { error } = await sb.from('route_cache').upsert({ ...key, distance_km: km, duration_min: Math.max(min, 1), polyline, created_at: new Date().toISOString() }, { onConflict: 'o_lat,o_lng,d_lat,d_lng' });
  if (error) return json({ error: 'Ruta no disponible', fallback: true }, 502);
  return json({ distance_km: km, duration_min: Math.max(min, 1), polyline, source: 'google' });
});
