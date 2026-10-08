import { currentUid, sb } from './client';
import { FaxiError, toFaxiError } from './errors';
import { DRIVER_ACTIVE, PASSENGER_ACTIVE } from './format';
import type {
  AppUser, Category, DocRow, DriverApplication, DriverDocType, DriverProfile, LatLng, PendingRequest, Place, Quote,
  TicketCategory, Trip, TripDetails, TripStatus, VehicleDocType,
} from './types';

async function rpc<T = unknown>(name: string, args?: Record<string, unknown>): Promise<T> {
  const { data, error } = await sb().rpc(name, args ?? {});
  if (error) throw toFaxiError(error);
  return data as T;
}
async function q<T>(p: PromiseLike<{ data: any; error: any }>): Promise<T> {
  const { data, error } = await p;
  if (error) throw toFaxiError(error);
  return data as T;
}

const DOC_BUCKETS = ['driver-documents', 'vehicle-documents'] as const;

// ───────── Auth y cuenta ─────────
export const auth = {
  async sendOtp(phone: string, role: 'PASSENGER' | 'DRIVER') {
    const { error } = await sb().auth.signInWithOtp({ phone, options: { data: { role, phone } } });
    if (error) throw toFaxiError(error);
  },
  async verifyOtp(phone: string, token: string) {
    const { data, error } = await sb().auth.verifyOtp({ phone, token, type: 'sms' });
    if (error) throw toFaxiError(error);
    return data.session;
  },
  async signInWithPassword(email: string, password: string) {
    const { error } = await sb().auth.signInWithPassword({ email, password });
    if (error) throw toFaxiError(error);
  },
  signOut: () => sb().auth.signOut(),
  async me(): Promise<AppUser | null> {
    const { data } = await sb().auth.getSession();
    const id = data.session?.user.id;
    if (!id) return null;
    return q<AppUser>(sb().from('users').select('id, role, full_name, email, phone, is_active').eq('id', id).single());
  },
  async setName(name: string) {
    const clean = name.trim().replace(/\s+/g, ' ');
    if (clean.length < 2) throw new FaxiError('Escribe tu nombre');
    await q(sb().from('users').update({ full_name: clean }).eq('id', await currentUid()));
  },
  /** Borra documentos propios, anonimiza la cuenta y cierra sesión. */
  async deleteAccount() {
    const uid = await currentUid();
    for (const bucket of DOC_BUCKETS) {
      const { data } = await sb().storage.from(bucket).list(uid, { limit: 100 });
      if (data?.length) await sb().storage.from(bucket).remove(data.map((f) => `${uid}/${f.name}`));
    }
    await rpc('delete_my_account');
    await sb().auth.signOut();
  },
};

export const push = {
  register: (token: string, platform: 'ios' | 'android') => rpc('register_push_token', { p_token: token, p_platform: platform }),
};

export const trips = {
  details: (id: string) => rpc<TripDetails>('trip_details', { p_trip_id: id }),
  cancel: (id: string, reason?: string) => rpc<Trip>('cancel_trip', { p_trip_id: id, p_reason: reason ?? null }),
};

// ───────── Pasajero ─────────
export const passenger = {
  quote: (o: LatLng, d: LatLng) =>
    rpc<Quote[]>('quote_trip', { p_origin_lat: o.lat, p_origin_lng: o.lng, p_dest_lat: d.lat, p_dest_lng: d.lng }),
  request: (category: Category, o: Place, d: Place) =>
    rpc<Trip>('request_trip', {
      p_category: category,
      p_origin_address: o.address.slice(0, 200), p_origin_lat: o.lat, p_origin_lng: o.lng,
      p_dest_address: d.address.slice(0, 200), p_dest_lat: d.lat, p_dest_lng: d.lng,
      p_payment_method: 'CASH',
    }),
  rate: (id: string, rating: number, comment?: string) => rpc('rate_trip', { p_trip_id: id, p_rating: rating, p_comment: comment ?? null }),
  async activeTrip(): Promise<Trip | null> {
    const rows = await q<Trip[]>(sb().from('trips').select('*').eq('passenger_id', await currentUid())
      .in('status', PASSENGER_ACTIVE).order('requested_at', { ascending: false }).limit(1));
    return rows[0] ?? null;
  },
  async history(limit = 30): Promise<Trip[]> {
    return q<Trip[]>(sb().from('trips').select('*').eq('passenger_id', await currentUid())
      .order('requested_at', { ascending: false }).limit(limit));
  },
};

// ───────── Conductor ─────────
export const driver = {
  async me(): Promise<DriverProfile> {
    return q<DriverProfile>(sb().from('drivers')
      .select('id, license_number, status, availability, current_vehicle_id, rating_avg, rating_count, trips_count, rejection_reason, vehicle:vehicles!drivers_current_vehicle_fk(*)')
      .eq('id', await currentUid()).single());
  },
  async documents(): Promise<{ driver: DocRow[]; vehicle: DocRow[] }> {
    const uid = await currentUid();
    const [d, v] = await Promise.all([
      q<DocRow[]>(sb().from('driver_documents').select('*').eq('driver_id', uid).order('created_at', { ascending: false })),
      q<DocRow[]>(sb().from('vehicle_documents').select('*').order('created_at', { ascending: false })),
    ]);
    return { driver: d, vehicle: v };
  },
  submitApplication: (a: DriverApplication) =>
    rpc<string>('driver_submit_application', {
      p_full_name: a.fullName, p_license_number: a.licenseNumber, p_make: a.make, p_model: a.model, p_year: a.year,
      p_color: a.color, p_plate: a.plate.toUpperCase().replace(/[^A-Z0-9]/g, ''), p_category: a.category, p_capacity: a.capacity,
    }),
  /** Sube una foto a Storage (<uid>/<tipo>-<ts>.jpg) y registra el documento como PENDING. */
  async uploadDocument(kind: 'driver' | 'vehicle', type: DriverDocType | VehicleDocType, fileUri: string, vehicleId?: string) {
    const uid = await currentUid();
    const ext = /\.png$/i.test(fileUri) ? 'png' : 'jpg';
    const path = `${uid}/${type}-${Date.now()}.${ext}`;
    const bytes = await (await fetch(fileUri)).arrayBuffer();
    const bucket = kind === 'driver' ? 'driver-documents' : 'vehicle-documents';
    const { error } = await sb().storage.from(bucket).upload(path, bytes, { contentType: ext === 'png' ? 'image/png' : 'image/jpeg' });
    if (error) throw toFaxiError(error);
    if (kind === 'driver') await q(sb().from('driver_documents').insert({ driver_id: uid, type, file_path: path }));
    else {
      if (!vehicleId) throw new FaxiError('Primero registra tu vehículo');
      await q(sb().from('vehicle_documents').insert({ vehicle_id: vehicleId, type, file_path: path }));
    }
  },
  setOnline: (online: boolean, pos?: LatLng | null) =>
    rpc('set_driver_availability', { p_online: online, p_lat: pos?.lat ?? null, p_lng: pos?.lng ?? null }),
  pending: () => rpc<PendingRequest[]>('driver_pending_requests'),
  accept: (requestId: string) => rpc<Trip>('accept_trip_request', { p_request_id: requestId }),
  reject: (requestId: string) => rpc('reject_trip_request', { p_request_id: requestId }),
  advance: (tripId: string, to: TripStatus) => rpc<Trip>('driver_advance_trip', { p_trip_id: tripId, p_to: to }),
  confirmCash: (tripId: string) => rpc('driver_confirm_cash', { p_trip_id: tripId }),
  updateLocation: (p: { lat: number; lng: number; heading?: number | null; speed?: number | null; accuracy?: number | null }) =>
    rpc('update_location', {
      p_lat: p.lat, p_lng: p.lng, p_heading: p.heading ?? null,
      p_speed_kmh: p.speed != null && p.speed >= 0 ? p.speed * 3.6 : null, p_accuracy_m: p.accuracy ?? null, p_source: 'GPS',
    }),
  async activeTrip(): Promise<Trip | null> {
    const rows = await q<Trip[]>(sb().from('trips').select('*').eq('driver_id', await currentUid())
      .in('status', DRIVER_ACTIVE).order('assigned_at', { ascending: false }).limit(1));
    return rows[0] ?? null;
  },
  async earnings(sinceISO: string): Promise<Trip[]> {
    return q<Trip[]>(sb().from('trips').select('*').eq('driver_id', await currentUid())
      .eq('status', 'COMPLETED').gte('completed_at', sinceISO).order('completed_at', { ascending: false }));
  },
};

// ───────── Soporte ─────────
export const support = {
  async create(t: { category: TicketCategory; subject: string; body: string; tripId?: string | null }) {
    await q(sb().from('support_tickets').insert({
      user_id: await currentUid(), category: t.category, subject: t.subject.trim(), body: t.body.trim(), trip_id: t.tripId ?? null,
    }));
  },
};
