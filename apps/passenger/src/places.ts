import type { LatLng, Place } from '@faxi/core';
import { cfg } from './faxi';

// Google Places API (New). La clave debe estar restringida a "Places API (New)" en Google Cloud.
export interface Suggestion { id: string; main: string; secondary: string }

const newToken = () => Math.random().toString(36).slice(2) + Date.now().toString(36);
let session = newToken(); // agrupa autocompletado + detalle en una sola sesión facturable

export async function autocomplete(input: string, near: LatLng): Promise<Suggestion[]> {
  if (input.trim().length < 2) return [];
  if (!cfg.placesKey) throw new Error('Falta EXPO_PUBLIC_GOOGLE_PLACES_KEY');
  const res = await fetch('https://places.googleapis.com/v1/places:autocomplete', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': cfg.placesKey },
    body: JSON.stringify({
      input, sessionToken: session, languageCode: 'es', includedRegionCodes: ['do'],
      locationBias: { circle: { center: { latitude: near.lat, longitude: near.lng }, radius: 25000 } },
    }),
  });
  const j = await res.json();
  if (!res.ok) throw new Error(j?.error?.message ?? 'No se pudo buscar la dirección');
  return (j.suggestions ?? [])
    .filter((s: any) => s.placePrediction)
    .map((s: any) => ({
      id: s.placePrediction.placeId,
      main: s.placePrediction.structuredFormat?.mainText?.text ?? s.placePrediction.text?.text ?? '',
      secondary: s.placePrediction.structuredFormat?.secondaryText?.text ?? '',
    }));
}

export async function placeDetails(id: string): Promise<Place> {
  const res = await fetch(`https://places.googleapis.com/v1/places/${id}?sessionToken=${session}&languageCode=es`, {
    headers: { 'X-Goog-Api-Key': cfg.placesKey, 'X-Goog-FieldMask': 'displayName,formattedAddress,location' },
  });
  const j = await res.json();
  if (!res.ok) throw new Error(j?.error?.message ?? 'No se pudo cargar el lugar');
  session = newToken();
  const name: string | undefined = j.displayName?.text;
  const formatted: string = (j.formattedAddress ?? '').replace(/, (República Dominicana|Dominican Republic)$/i, '');
  const address = name && !formatted.startsWith(name) ? `${name}, ${formatted}` : formatted || name || 'Lugar seleccionado';
  return { name, address: address.slice(0, 190), lat: j.location.latitude, lng: j.location.longitude };
}
