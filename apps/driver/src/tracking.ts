import * as Location from 'expo-location';
import * as TaskManager from 'expo-task-manager';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Alert } from 'react-native';
import { driver, type LatLng } from '@faxi/core';

// Debe definirse en el ámbito del módulo (se importa desde app/_layout.tsx) para que funcione con la app cerrada.
export const LOCATION_TASK = 'faxi-driver-location';
let lastSent = 0;

TaskManager.defineTask(LOCATION_TASK, async ({ data, error }) => {
  if (error) return;
  const locs = (data as { locations?: Location.LocationObject[] })?.locations;
  const l = locs?.[locs.length - 1];
  if (!l || Date.now() - lastSent < 12000) return;
  lastSent = Date.now();
  try {
    await driver.updateLocation({
      lat: l.coords.latitude, lng: l.coords.longitude, heading: l.coords.heading, speed: l.coords.speed, accuracy: l.coords.accuracy,
    });
  } catch { /* sin conexión: se reintenta en la siguiente lectura */ }
});

const DISCLOSURE_KEY = 'faxi.bgDisclosureAccepted';

/** Aviso destacado que exige Google Play antes de pedir ubicación en segundo plano. */
async function prominentDisclosure(): Promise<boolean> {
  if ((await AsyncStorage.getItem(DISCLOSURE_KEY)) === '1') return true;
  const ok = await new Promise<boolean>((resolve) =>
    Alert.alert(
      'Uso de tu ubicación',
      'faxi Conductor recopila tu ubicación para enviarte solicitudes de viaje cercanas y mostrar al pasajero dónde estás, incluso cuando la app está cerrada o no se está usando, mientras estés conectado. Al desconectarte dejamos de recopilarla.',
      [{ text: 'No ahora', style: 'cancel', onPress: () => resolve(false) }, { text: 'Entendido', onPress: () => resolve(true) }],
    ),
  );
  if (ok) await AsyncStorage.setItem(DISCLOSURE_KEY, '1');
  return ok;
}

export type PermissionResult = 'background' | 'foreground' | 'denied' | 'declined';

export async function ensureLocationPermission(): Promise<PermissionResult> {
  if (!(await prominentDisclosure())) return 'declined';
  const fg = await Location.requestForegroundPermissionsAsync();
  if (fg.status !== 'granted') return 'denied';
  const bg = await Location.requestBackgroundPermissionsAsync().catch(() => ({ status: 'denied' as const }));
  return bg.status === 'granted' ? 'background' : 'foreground';
}

export async function startTracking() {
  if (await Location.hasStartedLocationUpdatesAsync(LOCATION_TASK).catch(() => false)) return;
  await Location.startLocationUpdatesAsync(LOCATION_TASK, {
    accuracy: Location.Accuracy.High,
    timeInterval: 15000,
    distanceInterval: 25,
    pausesUpdatesAutomatically: false,
    activityType: Location.ActivityType.AutomotiveNavigation,
    showsBackgroundLocationIndicator: true,
    foregroundService: {
      notificationTitle: 'faxi Conductor · Conectado',
      notificationBody: 'Compartiendo tu ubicación para recibir viajes.',
      notificationColor: '#1B7A57',
    },
  });
}

export async function stopTracking() {
  if (await Location.hasStartedLocationUpdatesAsync(LOCATION_TASK).catch(() => false)) {
    await Location.stopLocationUpdatesAsync(LOCATION_TASK);
  }
}

export async function currentPos(): Promise<LatLng> {
  const p = (await Location.getLastKnownPositionAsync({ maxAge: 30000 })) ?? (await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.High }));
  return { lat: p.coords.latitude, lng: p.coords.longitude };
}
