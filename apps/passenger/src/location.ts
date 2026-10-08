import * as Location from 'expo-location';
import type { Place } from '@faxi/core';
import { SD_CENTER } from '@faxi/ui';

export interface Here { place: Place; denied: boolean }

/** Ubicación actual con dirección legible. Si se niega el permiso, usa el centro de Santo Domingo. */
export async function getHere(): Promise<Here> {
  const { status } = await Location.requestForegroundPermissionsAsync();
  if (status !== 'granted') return { place: { ...SD_CENTER, address: 'Ubicación aproximada · Santo Domingo' }, denied: true };
  const pos = (await Location.getLastKnownPositionAsync({ maxAge: 60000 })) ?? (await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced }));
  const lat = pos.coords.latitude, lng = pos.coords.longitude;
  let address = 'Mi ubicación';
  try {
    const [g] = await Location.reverseGeocodeAsync({ latitude: lat, longitude: lng });
    if (g) {
      const street = [g.street ?? g.name, g.streetNumber].filter(Boolean).join(' ');
      const area = g.district ?? g.subregion ?? g.city;
      address = [street, area].filter(Boolean).join(', ') || address;
    }
  } catch { /* sin geocodificación: queda "Mi ubicación" */ }
  return { place: { lat, lng, address }, denied: false };
}
