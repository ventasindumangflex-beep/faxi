import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Linking, Pressable, StyleSheet, View } from 'react-native';
import MapView from 'react-native-maps';
import { router, useFocusEffect } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { passenger, type Place } from '@faxi/core';
import { Banner, Icon, IconButton, ListItem, Row, Sheet, StatusScrim, T, c, f, r, region, shadow, SD_CENTER, useSession, FaxiMap } from '@faxi/ui';
import type { IconName } from '@faxi/ui';
import { getHere, type Here } from '../src/location';
import { draft } from '../src/draft';

const PERKS: { icon: IconName; text: string }[] = [
  { icon: 'payments', text: 'Pagas en efectivo' },
  { icon: 'verified-user', text: 'Conductores verificados' },
  { icon: 'share', text: 'Comparte tu viaje' },
];

function greeting(name?: string) {
  const h = new Date().getHours();
  const g = h < 12 ? 'Buenos días' : h < 19 ? 'Buenas tardes' : 'Buenas noches';
  return name ? `${g}, ${name}` : g;
}

export default function Home() {
  const { me } = useSession();
  const map = useRef<MapView>(null);
  const [here, setHere] = useState<Here | null>(null);
  const [recents, setRecents] = useState<Place[]>([]);

  useEffect(() => { getHere().then(setHere).catch(() => setHere(null)); }, []);
  useEffect(() => { if (here) map.current?.animateToRegion(region(here.place, 0.012), 600); }, [here]);

  useFocusEffect(useCallback(() => {
    let alive = true;
    passenger.activeTrip().then((t) => { if (alive && t) router.replace({ pathname: '/trip', params: { id: t.id } }); }).catch(() => {});
    passenger.history(20).then((rows) => {
      const seen = new Set<string>();
      const list: Place[] = [];
      for (const r of rows) {
        if (r.status !== 'COMPLETED' || seen.has(r.dest_address)) continue;
        seen.add(r.dest_address);
        list.push({ address: r.dest_address, lat: r.dest_lat, lng: r.dest_lng });
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
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginTop: 8 }}>
          <IconButton icon="menu" label="Menú" onPress={() => router.push('/account')} />
          {here ? <IconButton icon="my-location" label="Centrar mapa" onPress={() => map.current?.animateToRegion(region(here.place, 0.012), 500)} /> : null}
        </View>
        {here?.denied ? (
          <Banner tone="warn" text="Ubicación desactivada. Usamos una ubicación aproximada." actionLabel="Activar" onAction={() => Linking.openSettings()} />
        ) : null}
      </SafeAreaView>

      <Sheet>
        <View style={{ gap: 2 }}>
          <T v="title" numberOfLines={1}>{greeting(me?.full_name.split(' ')[0])}</T>
          <T v="caption">Viajes por todo el Gran Santo Domingo</T>
        </View>
        <Pressable onPress={() => go()} accessibilityRole="button" accessibilityLabel="¿A dónde vas?"
          style={({ pressed }) => [{ minHeight: 64, borderRadius: r.pill, backgroundColor: c.white, borderWidth: 1, borderColor: c.outlineSoft, flexDirection: 'row', alignItems: 'center', gap: 12, paddingLeft: 8, paddingRight: 18, opacity: pressed ? 0.85 : 1 }, shadow]}>
          <View style={{ width: 48, height: 48, borderRadius: 24, backgroundColor: c.primary, alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="search" size={26} color={c.onPrimary} />
          </View>
          <T style={{ fontFamily: f.bold, fontSize: 18, flex: 1 }} numberOfLines={1}>¿A dónde vas?</T>
          <Icon name="arrow-forward" color={c.primaryDark} />
        </Pressable>
        {recents.length ? (
          <View>
            <T v="micro" style={{ marginTop: 4 }}>Viajes recientes</T>
            {recents.map((p) => (
              <ListItem key={p.address} icon="history" title={p.address.split(',')[0]} subtitle={p.address} onPress={() => go(p)} />
            ))}
          </View>
        ) : (
          <Row gap={10} style={{ alignItems: 'stretch' }}>
            {PERKS.map((p) => (
              <View key={p.icon} style={{ flex: 1, backgroundColor: c.primarySoft, borderRadius: r.md, paddingVertical: 12, paddingHorizontal: 8, alignItems: 'center', gap: 6 }}>
                <Icon name={p.icon} color={c.primaryDark} />
                <T v="caption" center color={c.primaryDark} style={{ fontSize: 12, lineHeight: 16 }}>{p.text}</T>
              </View>
            ))}
          </Row>
        )}
      </Sheet>
    </View>
  );
}
