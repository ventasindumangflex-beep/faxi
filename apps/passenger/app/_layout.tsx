import '../src/faxi';
import React, { useEffect, useRef } from 'react';
import { Stack, router, useSegments } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import * as SplashScreen from 'expo-splash-screen';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { useFonts, PlusJakartaSans_500Medium, PlusJakartaSans_700Bold, PlusJakartaSans_800ExtraBold } from '@expo-google-fonts/plus-jakarta-sans';
import { isConfigured, missingConfig } from '@faxi/core';
import { ConfigMissing, Loading, SessionProvider, c, registerForPush, useSession } from '@faxi/ui';

SplashScreen.preventAutoHideAsync().catch(() => {});

export default function Root() {
  const [fonts] = useFonts({ PlusJakartaSans_500Medium, PlusJakartaSans_700Bold, PlusJakartaSans_800ExtraBold });
  useEffect(() => { if (fonts) SplashScreen.hideAsync().catch(() => {}); }, [fonts]);
  if (!fonts) return null;
  return (
    <SafeAreaProvider>
      <StatusBar style="dark" />
      {isConfigured() ? <SessionProvider><Gate /></SessionProvider> : <ConfigMissing missing={missingConfig()} />}
    </SafeAreaProvider>
  );
}

function Gate() {
  const { session, me, loading } = useSession();
  const seg = useSegments() as string[];
  const pushed = useRef<string | null>(null);

  useEffect(() => {
    if (loading) return;
    const area = seg[0];
    if (!session) { if (area !== '(auth)') router.replace('/login'); return; }
    if (me && me.role !== 'PASSENGER') { if (area !== 'wrong-role') router.replace('/wrong-role'); return; }
    if (me && me.full_name === 'Usuario') { if (area !== 'name') router.replace('/name'); return; }
    if (area === '(auth)' || area === 'name' || area === 'wrong-role') router.replace('/');
  }, [loading, session, me, seg[0]]);

  useEffect(() => {
    if (me?.role === 'PASSENGER' && pushed.current !== me.id) {
      pushed.current = me.id;
      registerForPush().catch(() => {});
    }
  }, [me?.id]);

  if (loading) return <Loading />;
  return <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: c.surface }, animation: 'slide_from_right' }} />;
}
