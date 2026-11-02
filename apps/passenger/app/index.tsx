import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Linking, Pressable, StyleSheet, View } from 'react-native';
import MapView from 'react-native-maps';
import { router, useFocusEffect } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { passenger, type Place } from '@faxi/core';
import {
  Banner, CashNote, HudChip, IconButton, ListItem, Sheet, StatusScrim, T, c, f, glow, r, region, SD_CENTER, useSession, useTheme, FaxiMap,
} from '@faxi/ui';
import { getHere, type Here } from '../src/location';
import { draft } from '../src/draft';

function greeting(name?: string) {
  const h = new Date().getHours();
  const g = h < 12 ? 'Buenos días' : h < 19 ? 'Buenas tardes' : 'Buenas noches';
  return name ? `${g}, ${name}` : g;
}

export default function Home() {
  useTheme();
  const { me } = useSession();
  const map = useRef<MapView>(null);
  const [here, setHere] = useState<Here | null>(null);
  const [recents, setRecents] = useState<Place[]>([]);

  useEffect(() => { getHere().then(setHere).catch(() => setHere(null)); }, []);
  useEffect(() => { if (here) map.current?.animateToRegion(region(here.place, 0.012), 600); }, [here]);

  useFocusEffect(useCallback(() => {
    let alive = true;
    // Recuperación al reabrir la app: si hay un viaje activo, se vuelve a él
    passenger.activeTrip().then((t) => { if (alive && t) router.replace({ pathname: '/trip', params: { id: t.id } }); }).catch(() => {});
    passenger.history(20).then((rows) => {
      const seen = new Set<string>();
      const list: Place[] = [];
      for (const row of rows) {
        if (row.status !== 'COMPLETED' || seen.has(row.dest_address)) continue;
        seen.add(row.dest_address);
        list.push({ address: row.dest_address, lat: row.dest_lat, lng: row.dest_lng });
        if (list.length === 3) break;
      }
      if (alive) setRecents(list);
    }).catch(() => {});
    return () => { alive = false; };
  }, []));

  function go(dest?: Place) {
    draft.origin = here?.place ?? null;
    draft.dest = dest ?? null;
    router.push(dest && here ? '/quote' : '/search');
  }

  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      <FaxiMap ref={map} style={StyleSheet.absoluteFill} initialRegion={region(SD_CENTER, 0.05)}
        showsUserLocation={!!here && !here.denied} showsMyLocationButton={false} toolbarEnabled={false} />
      <StatusScrim />
      <SafeAreaView edges={['top']} style={{ position: 'absolute', top: 0, left: 16, right: 16, gap: 10 }}>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: 8 }}>
          {here ? <HudChip dot label={here.denied ? 'Ubicación aproximada' : 'Tu ubicación'} /> : <View />}
          <HudChip icon="settings" label="Ajustes" onPress={() => router.push('/account')} accessibilityLabel="Ajustes" />
        </View>
        {here ? (
          <View style={{ alignItems: 'flex-end' }}>
            <IconButton icon="my-location" label="Centrar mapa" onPress={() => map.current?.animateToRegion(region(here.place, 0.012), 500)} />
          </View>
        ) : null}
        {here?.denied ? (
          <Banner tone="warn" text="Ubicación desactivada. Usamos una ubicación aproximada." actionLabel="Activar" onAction={() => Linking.openSettings()} />
        ) : null}
      </SafeAreaView>

      <Sheet>
        <View style={{ gap: 2 }}>
          <T v="label" color={c.muted} numberOfLines={1}>{greeting(me?.full_name.split(' ')[0])}</T>
          <T v="display" style={{ fontSize: 34, lineHeight: 38 }}>¿A dónde vamos?</T>
        </View>
        <Pressable onPress={() => go()} accessibilityRole="button" accessibilityLabel="Busca tu destino"
          style={({ pressed }) => [{ minHeight: 60, borderRadius: r.pill, backgroundColor: c.cardSel, flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 18, opacity: pressed ? 0.88 : 1 }, glow]}>
          <View style={{ width: 14, height: 14, borderRadius: 4, backgroundColor: c.neon }} />
          <T color={c.cardSelFg} numberOfLines={1} style={{ fontFamily: f.black, fontSize: 18, lineHeight: 24, flex: 1 }}>Busca tu destino</T>
        </Pressable>
        {recents.length ? (
          <View>
            <T v="micro" style={{ marginBottom: 2 }}>Lugares recientes</T>
            {recents.map((p) => (
              <ListItem key={p.address} icon="history" title={p.address.split(',')[0]} subtitle={p.address} onPress={() => go(p)} />
            ))}
          </View>
        ) : null}
        <CashNote text="Pagas en efectivo al conductor, al final del viaje." />
      </Sheet>
    </View>
  );
}
