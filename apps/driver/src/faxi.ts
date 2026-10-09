import 'react-native-url-polyfill/auto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Sentry from '@sentry/react-native';
import { initFaxi } from '@faxi/core';

// Errores en teléfonos reales → Sentry. Sin EXPO_PUBLIC_SENTRY_DSN no se envía nada.
const sentryDsn = process.env.EXPO_PUBLIC_SENTRY_DSN;
if (sentryDsn) {
  Sentry.init({
    dsn: sentryDsn,
    enabled: !__DEV__,
    environment: process.env.EXPO_PUBLIC_APP_ENV ?? (__DEV__ ? 'development' : 'production'),
    tracesSampleRate: 0.1,
    sendDefaultPii: false,
  });
}
export { Sentry };

initFaxi({
  url: process.env.EXPO_PUBLIC_SUPABASE_URL,
  anonKey: process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY,
  storage: AsyncStorage,
});

export const cfg = {
  termsUrl: process.env.EXPO_PUBLIC_TERMS_URL ?? 'https://faxi.do/terminos-conductores',
  privacyUrl: process.env.EXPO_PUBLIC_PRIVACY_URL ?? 'https://faxi.do/privacidad',
  supportWhatsApp: process.env.EXPO_PUBLIC_SUPPORT_WHATSAPP ?? '',
};
