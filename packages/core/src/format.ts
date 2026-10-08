import type { Category, LatLng, TicketCategory, TripStatus } from './types';

export const rd = (n?: number | null) =>
  n == null ? '—' : 'RD$ ' + Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
export const km = (n?: number | null) => (n == null ? '—' : `${Number(n).toFixed(1)} km`);
export const mins = (n?: number | null) => (n == null ? '—' : `${Math.max(1, Math.round(n))} min`);

export function fmtDate(iso?: string | null) {
  if (!iso) return '';
  const d = new Date(iso);
  const day = d.toLocaleDateString('es-DO', { day: 'numeric', month: 'short' });
  const time = d.toLocaleTimeString('es-DO', { hour: 'numeric', minute: '2-digit' });
  return `${day} · ${time}`;
}

/** Normaliza un número dominicano a E.164 (+1809…). Devuelve null si no es válido. */
export function normalizePhoneDO(input: string): string | null {
  const digits = input.replace(/\D/g, '');
  if (digits.length === 10 && /^(809|829|849)/.test(digits)) return '+1' + digits;
  if (digits.length === 11 && /^1(809|829|849)/.test(digits)) return '+' + digits;
  if (input.trim().startsWith('+') && digits.length >= 10 && digits.length <= 15) return '+' + digits;
  return null;
}

export function distanceKm(a: LatLng, b: LatLng) {
  const R = 6371, toRad = (x: number) => (x * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat), dLng = toRad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}
/** Misma estimación que el servidor (route_estimate): calle ×1.35, 22 km/h. */
export const etaMin = (a: LatLng, b: LatLng) => Math.max(1, Math.round(((distanceKm(a, b) * 1.35) / 22) * 60));

export const PASSENGER_ACTIVE: TripStatus[] = ['REQUESTED', 'SEARCHING', 'ASSIGNED', 'ENROUTE', 'ARRIVED', 'STARTED', 'ONTRIP', 'FINISHED', 'PAYMENT', 'PAYMENT_FAILED', 'DRIVER_TIMEOUT'];
export const DRIVER_ACTIVE: TripStatus[] = ['ASSIGNED', 'ENROUTE', 'ARRIVED', 'STARTED', 'ONTRIP', 'FINISHED', 'PAYMENT'];
export const ENDED_UNSUCCESSFUL: TripStatus[] = ['CANCELLED', 'NO_DRIVER', 'REQUEST_TIMEOUT', 'CANCELLED_BY_PASSENGER', 'CANCELLED_BY_DRIVER'];
export const PASSENGER_CAN_CANCEL: TripStatus[] = ['REQUESTED', 'SEARCHING', 'ASSIGNED', 'ENROUTE', 'ARRIVED'];
export const DRIVER_CAN_CANCEL: TripStatus[] = ['ASSIGNED', 'ENROUTE', 'ARRIVED'];

export const DRIVER_NEXT: Partial<Record<TripStatus, { to: TripStatus; label: string }>> = {
  ASSIGNED: { to: 'ENROUTE', label: 'Voy en camino' },
  ENROUTE: { to: 'ARRIVED', label: 'Llegué al punto de recogida' },
  ARRIVED: { to: 'STARTED', label: 'Iniciar viaje' },
  STARTED: { to: 'ONTRIP', label: 'Continuar viaje' },
  ONTRIP: { to: 'FINISHED', label: 'Finalizar viaje' },
};

export const STATUS_LABEL: Record<TripStatus, string> = {
  REQUESTED: 'Solicitado', SEARCHING: 'Buscando conductor', ASSIGNED: 'Conductor asignado', ENROUTE: 'Conductor en camino',
  ARRIVED: 'Conductor llegó', STARTED: 'Iniciado', ONTRIP: 'En viaje', FINISHED: 'Por cobrar', PAYMENT: 'Cobrando',
  COMPLETED: 'Completado', CANCELLED: 'Cancelado por faxi', NO_DRIVER: 'Sin conductores', DRIVER_TIMEOUT: 'Reasignando',
  REQUEST_TIMEOUT: 'Vencido', PAYMENT_FAILED: 'Pago fallido', CANCELLED_BY_PASSENGER: 'Cancelado por pasajero',
  CANCELLED_BY_DRIVER: 'Cancelado por conductor',
};

export const CATEGORY_LABEL: Record<Category, string> = {
  ECONOMICO: 'Económico', CONFORT: 'Confort', PREMIUM: 'Premium', SUV: 'SUV', VAN: 'Van',
};
export const CATEGORY_CAPACITY: Record<Category, number> = { ECONOMICO: 4, CONFORT: 4, PREMIUM: 4, SUV: 6, VAN: 10 };

export const TICKET_LABEL: Record<TicketCategory, string> = {
  COBRO: 'Cobro', RUTA: 'Ruta', SEGURIDAD: 'Seguridad', OBJETO_PERDIDO: 'Objeto perdido',
  CONDUCTOR: 'Conductor', PASAJERO: 'Pasajero', OTRO: 'Otro',
};

export const DOC_LABEL: Record<string, string> = {
  LICENCIA: 'Licencia de conducir', CEDULA: 'Cédula', BUENA_CONDUCTA: 'Certificado de buena conducta', FOTO_PERFIL: 'Foto de perfil',
  MATRICULA: 'Matrícula del vehículo', SEGURO: 'Seguro vigente', INSPECCION: 'Inspección técnica',
  FOTO_EXTERIOR: 'Foto del vehículo (exterior)', FOTO_INTERIOR: 'Foto del vehículo (interior)',
};
