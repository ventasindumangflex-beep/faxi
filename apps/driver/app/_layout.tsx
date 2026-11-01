import { Sentry } from '../src/faxi';
import '../src/tracking';
import React, { useEffect, useRef } from 'react';
import { Stack, router, useSegments } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import * as SplashScreen from 'expo-splash-screen';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { useFonts, PlusJakartaSans_500Medium, PlusJakartaSans_700Bold, PlusJakartaSans_800ExtraBold } from '@expo-google-fonts/plus-jakarta-sans';
import { isConfigured, missingConfig } from '@faxi/core';
import { ConfigMissing, Loading, SessionProvider, ThemeProvider, c, registerForPush, useSession, useTheme } from '@faxi/ui';
import { DriverProvider, useDriver } from '../src/driverCtx';

SplashScreen.preventAutoHideAsync().catch(() => {});
try { SplashScreen.setOptions({ duration: 400, fade: true }); } catch { /* versión sin soporte */ }

export default Sentry.wrap(Root);

function Root() {
  const [fonts] = useFonts({ PlusJakartaSans_500Medium, PlusJakartaSans_700Bold, PlusJakartaSans_800ExtraBold });
  // Con la app configurada, la pantalla nativa se quita en Gate cuando ya se sabe a qué pantalla ir.
  useEffect(() => { if (fonts && !isConfigured()) SplashScreen.hideAsync().catch(() => {}); }, [fonts]);
  if (!fonts) return null;
  return (
    <SafeAreaProvider>
      {/* La app del conductor arranca en modo oscuro (de noche se maneja mejor); cada quien lo cambia en Ajustes */}
      <ThemeProvider defaultMode="dark">
        <ThemedStatusBar />
        {isConfigured() ? (
          <SessionProvider><DriverProvider><Gate /></DriverProvider></SessionProvider>
        ) : <ConfigMissing missing={missingConfig()} />}
      </ThemeProvider>
    </SafeAreaProvider>
  );
}

/** Íconos claros de la barra de estado en el tema oscuro y oscuros en el claro. */
function ThemedStatusBar() {
  const { scheme } = useTheme();
  return <StatusBar style={scheme === 'dark' ? 'light' : 'dark'} />;
}

function Gate() {
  useTheme(); // vuelve a dibujar al cambiar el tema
  const { session, me, loading } = useSession();
  useEffect(() => { Sentry.setUser(me ? { id: me.id } : null); }, [me?.id]);
  const { profile, missingDocs, loading: loadingDriver } = useDriver();
  const seg = useSegments() as string[];
  const pushed = useRef<string | null>(null);
  const busy = loading || (!!session && me?.role === 'DRIVER' && loadingDriver);

  useEffect(() => {
    if (busy) return;
    const area = seg[0] ?? '';
    if (!session) { if (area !== '(auth)') router.replace('/login'); return; }
    if (me && me.role !== 'DRIVER') { if (area !== 'wrong-role') router.replace('/wrong-role'); return; }
    if (!profile) return;
    const needsApplication = !profile.current_vehicle_id || !profile.license_number || missingDocs.length > 0;
    if (profile.status !== 'APPROVED') {
      const target = needsApplication && profile.status !== 'SUSPENDED' ? 'onboarding' : 'pending';
      const allowed = [target, 'support', 'account', ...(profile.status === 'REJECTED' ? ['onboarding'] : [])];
      if (!allowed.includes(area)) router.replace(`/${target}`);
      return;
    }
    if (area === '(auth)' || area === 'wrong-role' || area === 'onboarding' || area === 'pending') router.replace('/');
  }, [busy, session, me, profile, missingDocs.length, seg[0]]);

  useEffect(() => {
    if (me?.role === 'DRIVER' && pushed.current !== me.id) {
      pushed.current = me.id;
      registerForPush().catch(() => {});
    }
  }, [me?.id]);

  // La pantalla nativa se queda hasta que la sesión y el perfil están listos: nada de salto al indicador de carga. Tope de 6 s por si no hay internet.
  useEffect(() => {
    if (!busy) { SplashScreen.hideAsync().catch(() => {}); return; }
    const h = setTimeout(() => SplashScreen.hideAsync().catch(() => {}), 6000);
    return () => clearTimeout(h);
  }, [busy]);

  if (busy) return <Loading />;
  return <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: c.bg }, animation: 'slide_from_right' }} />;
}
