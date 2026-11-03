import { existsSync } from 'node:fs';
import type { ExpoConfig } from 'expo/config';

const DEV = process.env.APP_VARIANT === 'development';
const LOC = 'faxi usa tu ubicación solo mientras usas la app, para fijar el punto de recogida y mostrarte tu conductor en el mapa.';

// Clave de Google Maps para Android. Se quitan espacios y comillas pegados por error, y en los builds de EAS para
// Android se exige una clave con forma válida: mejor un build fallido con un mensaje claro que un mapa en blanco.
const MAPS_KEY = process.env.GOOGLE_MAPS_ANDROID_KEY?.trim().replace(/^['"]+|['"]+$/g, '') || undefined;
if (process.env.EAS_BUILD && process.env.EAS_BUILD_PLATFORM === 'android' && !/^AIza[\w-]{35}$/.test(MAPS_KEY ?? '')) {
  throw new Error('GOOGLE_MAPS_ANDROID_KEY falta o no es una clave de Google (empieza por "AIza" y tiene 39 caracteres). '
    + 'Revísala en expo.dev → Environment variables, en el entorno de este build (ver docs/MAPA_ANDROID.md).');
}

// Notificaciones push en Android: Firebase (FCM). Necesita el google-services.json de ESTA app (paquete com.faxi.app):
// o bien el archivo en apps/passenger/google-services.json (no es secreto), o bien la variable de archivo GOOGLE_SERVICES_JSON de EAS.
// Sin él la app funciona, pero el teléfono no puede registrarse para recibir avisos (ver docs/PENDIENTES_PRODUCCION.md).
const GOOGLE_SERVICES = process.env.GOOGLE_SERVICES_JSON || (existsSync('./google-services.json') ? './google-services.json' : undefined);
if (process.env.EAS_BUILD && process.env.EAS_BUILD_PLATFORM === 'android' && !GOOGLE_SERVICES) {
  console.warn('[faxi] Falta google-services.json: este build de Android NO recibirá notificaciones push.');
}

const config: ExpoConfig = {
  name: 'faxi',
  owner: 'faxi.app',
  slug: 'faxi',
  scheme: 'faxi',
  version: '1.0.0',
  orientation: 'portrait',
  userInterfaceStyle: 'automatic', // la app elige Claro/Oscuro/Automático (packages/ui/src/theme.tsx); lo nativo lo sigue
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
    ...(GOOGLE_SERVICES ? { googleServicesFile: GOOGLE_SERVICES } : {}),
    permissions: ['ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION'],
    // Solo lo que la app usa: sin ubicación en segundo plano, almacenamiento ni "mostrar sobre otras apps" (este último lo necesita el build de desarrollo).
    blockedPermissions: [
      'android.permission.ACCESS_BACKGROUND_LOCATION', 'android.permission.READ_EXTERNAL_STORAGE', 'android.permission.WRITE_EXTERNAL_STORAGE',
      ...(DEV ? [] : ['android.permission.SYSTEM_ALERT_WINDOW']),
    ],
    config: { googleMaps: { apiKey: MAPS_KEY } },
  },
  plugins: [
    './plugins/with-gradle-memory',
    'expo-router',
    'expo-font',
    // iOS exige los tres textos aunque la app nunca pida "Siempre"; sin ellos usa unos genéricos en inglés.
    ['expo-location', { locationWhenInUsePermission: LOC, locationAlwaysAndWhenInUsePermission: LOC, locationAlwaysPermission: LOC }],
    ['expo-notifications', { color: '#1B7A57', icon: './assets/notification-icon.png' }],
    // Color del centro del degradado de la marca; src/Intro.tsx sigue con el degradado completo (scripts/make_splash.py).
    ['expo-splash-screen', { image: './assets/splash-icon.png', imageWidth: 220, resizeMode: 'contain', backgroundColor: '#029A60' }],
  ],
  experiments: { typedRoutes: false },
  // ID público del proyecto en expo.dev (faxi.app/faxi); no es una credencial.
  extra: { eas: { projectId: process.env.EAS_PROJECT_ID || 'b52dc436-e073-4930-a2a1-cfc89b2b1f4c' } },
};

// Sube los mapas de código a Sentry en los builds de EAS si están SENTRY_ORG, SENTRY_PROJECT y SENTRY_AUTH_TOKEN.
if (process.env.SENTRY_ORG && process.env.SENTRY_PROJECT) {
  config.plugins!.push(['@sentry/react-native/expo', { organization: process.env.SENTRY_ORG, project: process.env.SENTRY_PROJECT }]);
}

export default config;
