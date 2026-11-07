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

/** Estado del último intento de registrar el teléfono para recibir avisos (se muestra en Ajustes para poder diagnosticar). */
export type PushStatus = { state: 'pendiente' | 'ok' | 'sin-permiso' | 'sin-proyecto' | 'simulador' | 'error'; detail?: string };
let lastStatus: PushStatus = { state: 'pendiente' };
export const getPushStatus = (): PushStatus => lastStatus;
export function describePushStatus(st: PushStatus = lastStatus): string {
  switch (st.state) {
    case 'ok': return 'Activados';
    case 'sin-permiso': return 'Sin permiso: actívalos en los ajustes del teléfono';
    case 'sin-proyecto': return 'Falta el ID del proyecto';
    case 'simulador': return 'No disponible en este equipo';
    case 'error': return `Error: ${st.detail ?? 'desconocido'}`;
    default: return 'Sin registrar todavía';
  }
}

/** Pide permiso, obtiene el token de Expo y lo guarda en push_tokens. Devuelve null si no es posible (y deja el motivo en getPushStatus). */
export async function registerForPush(): Promise<string | null> {
  try {
    if (!Device.isDevice) { lastStatus = { state: 'simulador' }; return null; }
    if (Platform.OS === 'android') {
      await Notifications.setNotificationChannelAsync('trips', {
        name: 'Viajes', importance: Notifications.AndroidImportance.HIGH, sound: 'default', vibrationPattern: [0, 250, 250, 250],
      });
    }
    let { status } = await Notifications.getPermissionsAsync();
    if (status !== 'granted') status = (await Notifications.requestPermissionsAsync()).status;
    if (status !== 'granted') { lastStatus = { state: 'sin-permiso' }; return null; }
    const projectId = (Constants.expoConfig?.extra as any)?.eas?.projectId ?? (Constants as any).easConfig?.projectId;
    if (!projectId) { console.warn('[faxi] falta EAS_PROJECT_ID: no se registran notificaciones'); lastStatus = { state: 'sin-proyecto' }; return null; }
    const token = (await Notifications.getExpoPushTokenAsync({ projectId })).data;
    await push.register(token, Platform.OS === 'ios' ? 'ios' : 'android');
    lastStatus = { state: 'ok' };
    return token;
  } catch (e: any) {
    const detail = String(e?.message ?? e).replace(/\s+/g, ' ').slice(0, 220);
    console.warn('[faxi] no se pudo registrar para avisos:', detail);
    lastStatus = { state: 'error', detail };
    return null;
  }
}
