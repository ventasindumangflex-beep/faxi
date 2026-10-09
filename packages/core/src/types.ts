export type Role = 'PASSENGER' | 'DRIVER' | 'ADMIN' | 'SUPER_ADMIN';
export type TripStatus =
  | 'REQUESTED' | 'SEARCHING' | 'ASSIGNED' | 'ENROUTE' | 'ARRIVED' | 'STARTED' | 'ONTRIP' | 'FINISHED' | 'PAYMENT' | 'COMPLETED'
  | 'CANCELLED' | 'NO_DRIVER' | 'DRIVER_TIMEOUT' | 'REQUEST_TIMEOUT' | 'PAYMENT_FAILED' | 'CANCELLED_BY_PASSENGER' | 'CANCELLED_BY_DRIVER';
export type Category = 'ECONOMICO' | 'CONFORT' | 'PREMIUM' | 'SUV' | 'VAN';
export type Approval = 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPENDED';
export type Availability = 'OFFLINE' | 'ONLINE' | 'BUSY';
export type PaymentMethod = 'CASH' | 'CARD' | 'TRANSFER' | 'WALLET';
export type DriverDocType = 'LICENCIA' | 'CEDULA' | 'BUENA_CONDUCTA' | 'FOTO_PERFIL';
export type VehicleDocType = 'MATRICULA' | 'SEGURO' | 'INSPECCION' | 'FOTO_EXTERIOR' | 'FOTO_INTERIOR';
export type TicketCategory = 'COBRO' | 'RUTA' | 'SEGURIDAD' | 'OBJETO_PERDIDO' | 'CONDUCTOR' | 'PASAJERO' | 'OTRO';

export interface LatLng { lat: number; lng: number }
export interface Place extends LatLng { address: string; name?: string }

export interface AppUser {
  id: string; role: Role; full_name: string; email: string | null; phone: string | null; is_active: boolean;
}

export interface Trip {
  id: string; code: string; passenger_id: string; driver_id: string | null; vehicle_id: string | null;
  category: Category; status: TripStatus;
  origin_address: string; origin_lat: number; origin_lng: number;
  dest_address: string; dest_lat: number; dest_lng: number;
  distance_km: number; duration_min: number;
  estimated_fare: number; final_fare: number | null; commission_rate: number | null;
  faxi_commission: number | null; driver_earnings: number | null;
  payment_method: PaymentMethod; cancel_reason: string | null;
  requested_at: string; assigned_at: string | null; arrived_at: string | null; started_at: string | null;
  finished_at: string | null; completed_at: string | null; cancelled_at: string | null;
}

export interface Quote {
  category: Category; display_name: string; capacity: number; distance_km: number; duration_min: number;
  total: number; minimum_fare: number; surcharge: number;
}

export interface TripDetails {
  trip: Trip;
  passenger: { id: string; name: string; rating: number | null } | null;
  driver: { id: string; name: string; phone: string | null; rating: number | null; trips: number; lat: number | null; lng: number | null; heading: number | null } | null;
  vehicle: { make: string; model: string; year: number; color: string; plate: string; category: Category } | null;
  payment: { status: string; method: PaymentMethod; amount: number; paid_at: string | null } | null;
  rating: { rating: number; comment: string | null } | null;
}

export interface PendingRequest {
  request_id: string; trip_id: string; trip_code: string; expires_at: string; distance_to_pickup_km: number;
  origin_address: string; dest_address: string; distance_km: number; duration_min: number;
  estimated_fare: number; estimated_earnings: number; category: Category; passenger_name: string; passenger_rating: number | null;
}

export interface Vehicle {
  id: string; driver_id: string; make: string; model: string; year: number; color: string; plate: string;
  category: Category; capacity: number; status: Approval; rejection_reason: string | null;
}

export interface DriverProfile {
  id: string; license_number: string | null; status: Approval; availability: Availability;
  current_vehicle_id: string | null; rating_avg: number | null; rating_count: number; trips_count: number;
  rejection_reason: string | null; vehicle: Vehicle | null;
}

export interface DocRow {
  id: string; type: DriverDocType | VehicleDocType; file_path: string; status: Approval;
  expires_at: string | null; rejection_reason: string | null; created_at: string;
}

export interface DriverApplication {
  fullName: string; licenseNumber: string; make: string; model: string; year: number; color: string;
  plate: string; category: Category; capacity: number;
}
