import { Platform } from 'react-native';
import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';
import Constants from 'expo-constants';
import { push } from '@faxi/core';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true, shouldShowList: true, shouldPlaySound: true, shouldSetBadge: false,
  }),
});

/** Pide permiso, obtiene el token de Expo y lo guarda en push_tokens. Devuelve null si no es posible. */
export async function registerForPush(): Promise<string | null> {
  if (!Device.isDevice) return null;
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync('trips', {
      name: 'Viajes', importance: Notifications.AndroidImportance.HIGH, sound: 'default', vibrationPattern: [0, 250, 250, 250],
    });
  }
  let { status } = await Notifications.getPermissionsAsync();
  if (status !== 'granted') status = (await Notifications.requestPermissionsAsync()).status;
  if (status !== 'granted') return null;
  const projectId = (Constants.expoConfig?.extra as any)?.eas?.projectId ?? (Constants as any).easConfig?.projectId;
  if (!projectId) { console.warn('[faxi] falta EAS_PROJECT_ID: no se registran notificaciones'); return null; }
  const token = (await Notifications.getExpoPushTokenAsync({ projectId })).data;
  await push.register(token, Platform.OS === 'ios' ? 'ios' : 'android');
  return token;
}
