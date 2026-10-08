import type { Trip } from '@faxi/core';
import { STATUS_LABEL } from '@faxi/core';

export type TripRow = Trip & {
  passenger: { user: { full_name: string; phone: string | null } } | null;
  driver: { user: { full_name: string; phone: string | null } } | null;
};

export const TRIP_SELECT =
  '*, passenger:passengers!trips_passenger_id_fkey(user:users!passengers_id_fkey(full_name, phone)), driver:drivers!trips_driver_id_fkey(user:users!drivers_id_fkey(full_name, phone))';

export function tone(status: string) {
  if (['COMPLETED', 'APPROVED', 'RESOLVED', 'PAID', 'ONLINE'].includes(status)) return 'ok';
  if (['PENDING', 'SEARCHING', 'OPEN', 'IN_REVIEW', 'FINISHED', 'PAYMENT', 'BUSY'].includes(status)) return 'warn';
  if (status.startsWith('CANCELLED') || ['REJECTED', 'SUSPENDED', 'NO_DRIVER', 'PAYMENT_FAILED', 'FAILED'].includes(status)) return 'error';
  return '';
}

export function StatusPill({ s, label }: { s: string; label?: string }) {
  return <span className={'pill ' + tone(s)}>{label ?? (STATUS_LABEL as Record<string, string>)[s] ?? s}</span>;
}
