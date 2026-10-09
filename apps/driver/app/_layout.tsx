import '../src/faxi';
import '../src/tracking';
import React, { useEffect, useRef } from 'react';
import { Stack, router, useSegments } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import * as SplashScreen from 'expo-splash-screen';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { useFonts, PlusJakartaSans_500Medium, PlusJakartaSans_700Bold, PlusJakartaSans_800ExtraBold } from '@expo-google-fonts/plus-jakarta-sans';
import { isConfigured, missingConfig } from '@faxi/core';
import { ConfigMissing, Loading, SessionProvider, c, registerForPush, useSession } from '@faxi/ui';
import { DriverProvider, useDriver } from '../src/driverCtx';

SplashScreen.preventAutoHideAsync().catch(() => {});

export default function Root() {
  const [fonts] = useFonts({ PlusJakartaSans_500Medium, PlusJakartaSans_700Bold, PlusJakartaSans_800ExtraBold });
  useEffect(() => { if (fonts) SplashScreen.hideAsync().catch(() => {}); }, [fonts]);
  if (!fonts) return null;
  return (
    <SafeAreaProvider>
      <StatusBar style="dark" />
      {isConfigured() ? (
        <SessionProvider><DriverProvider><Gate /></DriverProvider></SessionProvider>
      ) : <ConfigMissing missing={missingConfig()} />}
    </SafeAreaProvider>
  );
}

function Gate() {
  const { session, me, loading } = useSession();
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

  if (busy) return <Loading />;
  return <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: c.surface }, animation: 'slide_from_right' }} />;
}
