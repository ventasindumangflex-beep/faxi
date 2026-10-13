import type { ExpoConfig } from 'expo/config';

const DEV = process.env.APP_VARIANT === 'development';
const LOC = 'faxi Conductor usa tu ubicación para enviarte solicitudes de viaje cercanas y mostrar al pasajero dónde estás, también cuando la app está en segundo plano mientras estás conectado.';

// Clave de Google Maps para Android. Se quitan espacios y comillas pegados por error, y en los builds de EAS para
// Android se exige una clave con forma válida: mejor un build fallido con un mensaje claro que un mapa en blanco.
const MAPS_KEY = process.env.GOOGLE_MAPS_ANDROID_KEY?.trim().replace(/^['"]+|['"]+$/g, '') || undefined;
if (process.env.EAS_BUILD && process.env.EAS_BUILD_PLATFORM === 'android' && !/^AIza[\w-]{35}$/.test(MAPS_KEY ?? '')) {
  throw new Error('GOOGLE_MAPS_ANDROID_KEY falta o no es una clave de Google (empieza por "AIza" y tiene 39 caracteres). '
    + 'Revísala en expo.dev → Environment variables, en el entorno de este build (ver docs/MAPA_ANDROID.md).');
}

const config: ExpoConfig = {
  name: 'faxi Conductor',
  owner: 'faxi.app',
  slug: 'faxi-conductor',
  scheme: 'faxi-conductor',
  version: '1.0.0',
  orientation: 'portrait',
  userInterfaceStyle: 'light',
  newArchEnabled: true,
  icon: './assets/icon.png',                 // generado con scripts/make_icons.py
  ios: {
    bundleIdentifier: 'do.faxi.conductor',
    supportsTablet: false,
    infoPlist: {
      NSLocationWhenInUseUsageDescription: LOC,
      NSLocationAlwaysAndWhenInUseUsageDescription: LOC,
      NSLocationAlwaysUsageDescription: LOC,
      NSCameraUsageDescription: 'faxi Conductor usa la cámara para fotografiar tu licencia, cédula y documentos del vehículo.',
      NSPhotoLibraryUsageDescription: 'faxi Conductor necesita acceso a tus fotos para subir tus documentos.',
      UIBackgroundModes: ['location', 'fetch', 'remote-notification'],
      ITSAppUsesNonExemptEncryption: false,
    },
  },
  android: {
    adaptiveIcon: { foregroundImage: './assets/adaptive-icon.png', backgroundColor: '#181C1A' },
    package: 'com.faxi.conductor',
    permissions: [
      'ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION', 'ACCESS_BACKGROUND_LOCATION',
      'FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_LOCATION', 'CAMERA', 'VIBRATE',
    ],
    // expo-image-picker añade el micrófono (para video), que la app no usa; "mostrar sobre otras apps" solo hace falta en desarrollo.
    blockedPermissions: ['android.permission.RECORD_AUDIO', ...(DEV ? [] : ['android.permission.SYSTEM_ALERT_WINDOW'])],
    config: { googleMaps: { apiKey: MAPS_KEY } },
  },
  plugins: [
    './plugins/with-gradle-memory',
    'expo-router',
    'expo-font',
    ['expo-location', {
      locationAlwaysAndWhenInUsePermission: LOC,
      locationWhenInUsePermission: LOC,
      locationAlwaysPermission: LOC,
      isAndroidBackgroundLocationEnabled: true,
      isAndroidForegroundServiceEnabled: true,
      isIosBackgroundLocationEnabled: true,
    }],
    ['expo-image-picker', {
      cameraPermission: 'faxi Conductor usa la cámara para fotografiar tus documentos.',
      photosPermission: 'faxi Conductor necesita acceso a tus fotos para subir tus documentos.',
      // iOS exige el texto aunque la app solo tome fotos; en Android el permiso queda bloqueado arriba.
      microphonePermission: 'faxi Conductor no usa el micrófono: solo toma fotos de tus documentos.',
    }],
    ['expo-notifications', { color: '#1B7A57', icon: './assets/notification-icon.png' }],
    ['expo-splash-screen', { image: './assets/splash-icon.png', imageWidth: 220, resizeMode: 'contain', backgroundColor: '#181C1A' }],
  ],
  extra: { eas: { projectId: process.env.EAS_PROJECT_ID } },
};

// Sube los mapas de código a Sentry en los builds de EAS si están SENTRY_ORG, SENTRY_PROJECT y SENTRY_AUTH_TOKEN.
if (process.env.SENTRY_ORG && process.env.SENTRY_PROJECT) {
  config.plugins!.push(['@sentry/react-native/expo', { organization: process.env.SENTRY_ORG, project: process.env.SENTRY_PROJECT }]);
}

export default config;
