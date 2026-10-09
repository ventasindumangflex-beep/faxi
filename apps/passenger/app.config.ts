import type { ExpoConfig } from 'expo/config';

const config: ExpoConfig = {
  name: 'faxi',
  slug: 'faxi',
  scheme: 'faxi',
  version: '1.0.0',
  orientation: 'portrait',
  userInterfaceStyle: 'light',
  newArchEnabled: true,
  // icon: './assets/icon.png',            // 1024×1024 — añadir antes de publicar
  // splash: { image: './assets/splash.png', backgroundColor: '#1B7A57' },
  ios: {
    bundleIdentifier: 'do.faxi.app',
    supportsTablet: false,
    infoPlist: {
      NSLocationWhenInUseUsageDescription: 'faxi usa tu ubicación para fijar el punto de recogida y mostrarte tu conductor en el mapa.',
      ITSAppUsesNonExemptEncryption: false,
    },
  },
  android: {
    package: 'do.faxi.app',
    permissions: ['ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION'],
    blockedPermissions: ['android.permission.ACCESS_BACKGROUND_LOCATION'],
    config: { googleMaps: { apiKey: process.env.GOOGLE_MAPS_ANDROID_KEY } },
  },
  plugins: [
    'expo-router',
    'expo-font',
    ['expo-location', { locationWhenInUsePermission: 'faxi usa tu ubicación para fijar el punto de recogida y mostrarte tu conductor en el mapa.' }],
    ['expo-notifications', { color: '#1B7A57' }],
    ['expo-splash-screen', { backgroundColor: '#1B7A57' }],
  ],
  experiments: { typedRoutes: false },
  extra: { eas: { projectId: process.env.EAS_PROJECT_ID } },
};

export default config;
