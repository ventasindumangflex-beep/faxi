import type { ExpoConfig } from 'expo/config';

const LOC = 'faxi Conductor usa tu ubicación para enviarte solicitudes de viaje cercanas y mostrar al pasajero dónde estás, también cuando la app está en segundo plano mientras estás conectado.';

const config: ExpoConfig = {
  name: 'faxi Conductor',
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
      NSCameraUsageDescription: 'faxi Conductor usa la cámara para fotografiar tu licencia, cédula y documentos del vehículo.',
      NSPhotoLibraryUsageDescription: 'faxi Conductor necesita acceso a tus fotos para subir tus documentos.',
      UIBackgroundModes: ['location', 'fetch', 'remote-notification'],
      ITSAppUsesNonExemptEncryption: false,
    },
  },
  android: {
    adaptiveIcon: { foregroundImage: './assets/adaptive-icon.png', backgroundColor: '#181C1A' },
    package: 'do.faxi.conductor',
    permissions: [
      'ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION', 'ACCESS_BACKGROUND_LOCATION',
      'FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_LOCATION', 'CAMERA', 'VIBRATE',
    ],
    config: { googleMaps: { apiKey: process.env.GOOGLE_MAPS_ANDROID_KEY } },
  },
  plugins: [
    'expo-router',
    'expo-font',
    ['expo-location', {
      locationAlwaysAndWhenInUsePermission: LOC,
      locationWhenInUsePermission: LOC,
      isAndroidBackgroundLocationEnabled: true,
      isAndroidForegroundServiceEnabled: true,
      isIosBackgroundLocationEnabled: true,
    }],
    ['expo-image-picker', {
      cameraPermission: 'faxi Conductor usa la cámara para fotografiar tus documentos.',
      photosPermission: 'faxi Conductor necesita acceso a tus fotos para subir tus documentos.',
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
