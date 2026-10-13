import { sb } from './client';
import type { Trip } from './types';

type Off = () => void;
export interface LivePosition { lat: number; lng: number; heading?: number | null; at: number }

/** Cambios de la fila del viaje (RLS: solo pasajero, conductor o admin). */
export function watchTrip(tripId: string, onChange: (t: Trip) => void): Off {
  const ch = sb().channel(`db-trip-${tripId}`)
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'trips', filter: `id=eq.${tripId}` }, (p) => onChange(p.new as Trip))
    .subscribe();
  return () => { sb().removeChannel(ch); };
}

/** Nuevas ofertas para el conductor. */
export function watchDriverRequests(driverId: string, onAny: () => void): Off {
  const ch = sb().channel(`db-req-${driverId}`)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'trip_requests', filter: `driver_id=eq.${driverId}` }, () => onAny())
    .subscribe();
  return () => { sb().removeChannel(ch); };
}

/** Cambios del propio registro de conductor (aprobación, disponibilidad). */
export function watchDriverRow(driverId: string, onAny: () => void): Off {
  const ch = sb().channel(`db-drv-${driverId}`)
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'drivers', filter: `id=eq.${driverId}` }, () => onAny())
    .subscribe();
  return () => { sb().removeChannel(ch); };
}

/**
 * Ubicación en vivo del conductor por Realtime Broadcast (no toca la base).
 * Canal privado: Supabase solo deja entrar al pasajero y al conductor del viaje (y admins), y solo
 * el conductor puede transmitir (políticas en realtime.messages, migración 005).
 */
const tripChannelConfig = { config: { private: true, broadcast: { self: false } } } as const;

export function listenDriverLocation(tripId: string, cb: (p: LivePosition) => void): Off {
  const ch = sb().channel(`trip:${tripId}`, tripChannelConfig)
    .on('broadcast', { event: 'loc' }, ({ payload }) => cb({ ...(payload as LivePosition), at: Date.now() }))
    .subscribe();
  return () => { sb().removeChannel(ch); };
}

export function createLocationBroadcaster(tripId: string) {
  let ready = false;
  const ch = sb().channel(`trip:${tripId}`, tripChannelConfig);
  ch.subscribe((status) => { ready = status === 'SUBSCRIBED'; });
  return {
    send(p: { lat: number; lng: number; heading?: number | null }) {
      if (ready) ch.send({ type: 'broadcast', event: 'loc', payload: p });
    },
    close() { sb().removeChannel(ch); },
  };
}
