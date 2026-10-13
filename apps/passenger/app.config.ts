import type { ExpoConfig } from 'expo/config';

const DEV = process.env.APP_VARIANT === 'development';
const LOC = 'faxi usa tu ubicación solo mientras usas la app, para fijar el punto de recogida y mostrarte tu conductor en el mapa.';

const config: ExpoConfig = {
  name: 'faxi',
  owner: 'faxi.app',
  slug: 'faxi',
  scheme: 'faxi',
  version: '1.0.0',
  orientation: 'portrait',
  userInterfaceStyle: 'light',
  newArchEnabled: true,
  icon: './assets/icon.png',                 // generado con scripts/make_icons.py
  ios: {
    bundleIdentifier: 'do.faxi.app',
    supportsTablet: false,
    infoPlist: {
      NSLocationWhenInUseUsageDescription: LOC,
      ITSAppUsesNonExemptEncryption: false,
    },
  },
  android: {
    adaptiveIcon: { foregroundImage: './assets/adaptive-icon.png', backgroundColor: '#1B7A57' },
    package: 'com.faxi.app',
    permissions: ['ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION'],
    // Solo lo que la app usa: sin ubicación en segundo plano, almacenamiento ni "mostrar sobre otras apps" (este último lo necesita el build de desarrollo).
    blockedPermissions: [
      'android.permission.ACCESS_BACKGROUND_LOCATION', 'android.permission.READ_EXTERNAL_STORAGE', 'android.permission.WRITE_EXTERNAL_STORAGE',
      ...(DEV ? [] : ['android.permission.SYSTEM_ALERT_WINDOW']),
    ],
    config: { googleMaps: { apiKey: process.env.GOOGLE_MAPS_ANDROID_KEY } },
  },
  plugins: [
    './plugins/with-gradle-memory',
    'expo-router',
    'expo-font',
    // iOS exige los tres textos aunque la app nunca pida "Siempre"; sin ellos usa unos genéricos en inglés.
    ['expo-location', { locationWhenInUsePermission: LOC, locationAlwaysAndWhenInUsePermission: LOC, locationAlwaysPermission: LOC }],
    ['expo-notifications', { color: '#1B7A57', icon: './assets/notification-icon.png' }],
    ['expo-splash-screen', { image: './assets/splash-icon.png', imageWidth: 220, resizeMode: 'contain', backgroundColor: '#1B7A57' }],
  ],
  experiments: { typedRoutes: false },
  // ID público del proyecto en expo.dev (faxi.app/faxi); no es una credencial.
  extra: { eas: { projectId: process.env.EAS_PROJECT_ID ?? 'b52dc436-e073-4930-a2a1-cfc89b2b1f4c' } },
};

// Sube los mapas de código a Sentry en los builds de EAS si están SENTRY_ORG, SENTRY_PROJECT y SENTRY_AUTH_TOKEN.
if (process.env.SENTRY_ORG && process.env.SENTRY_PROJECT) {
  config.plugins!.push(['@sentry/react-native/expo', { organization: process.env.SENTRY_ORG, project: process.env.SENTRY_PROJECT }]);
}

export default config;
