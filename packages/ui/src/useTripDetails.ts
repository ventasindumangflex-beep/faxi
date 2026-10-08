import { useCallback, useEffect, useRef, useState } from 'react';
import { AppState } from 'react-native';
import { listenDriverLocation, trips, watchTrip, type LatLng, type TripDetails } from '@faxi/core';

/** Detalle del viaje en vivo: Realtime (cambios de estado + ubicación) con sondeo de respaldo cada 15 s. */
export function useTripDetails(tripId: string | null | undefined, opts: { listenLocation?: boolean } = {}) {
  const [details, setDetails] = useState<TripDetails | null>(null);
  const [driverPos, setDriverPos] = useState<LatLng | null>(null);
  const [error, setError] = useState<string | null>(null);
  const lastLive = useRef(0);

  const load = useCallback(async () => {
    if (!tripId) return;
    try {
      const d = await trips.details(tripId);
      setDetails(d);
      // Usa la posición guardada solo si no llegó una en vivo en los últimos 20 s
      if (d.driver?.lat != null && d.driver?.lng != null && Date.now() - lastLive.current > 20000) {
        setDriverPos({ lat: d.driver.lat, lng: d.driver.lng });
      }
      setError(null);
    } catch (e: any) { setError(e.message); }
  }, [tripId]);

  useEffect(() => {
    if (!tripId) return;
    load();
    const offTrip = watchTrip(tripId, () => load());
    const offLoc = opts.listenLocation
      ? listenDriverLocation(tripId, (p) => { lastLive.current = Date.now(); setDriverPos({ lat: p.lat, lng: p.lng }); })
      : () => {};
    const iv = setInterval(load, 15000);
    const app = AppState.addEventListener('change', (s) => { if (s === 'active') load(); });
    return () => { offTrip(); offLoc(); clearInterval(iv); app.remove(); };
  }, [tripId, load, opts.listenLocation]);

  return { details, driverPos, error, reload: load };
}
