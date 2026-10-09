import 'react-native-url-polyfill/auto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { initFaxi } from '@faxi/core';

initFaxi({
  url: process.env.EXPO_PUBLIC_SUPABASE_URL,
  anonKey: process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY,
  storage: AsyncStorage,
});

export const cfg = {
  placesKey: process.env.EXPO_PUBLIC_GOOGLE_PLACES_KEY ?? '',
  termsUrl: process.env.EXPO_PUBLIC_TERMS_URL ?? 'https://faxi.do/terminos',
  privacyUrl: process.env.EXPO_PUBLIC_PRIVACY_URL ?? 'https://faxi.do/privacidad',
  supportWhatsApp: process.env.EXPO_PUBLIC_SUPPORT_WHATSAPP ?? '',
};
