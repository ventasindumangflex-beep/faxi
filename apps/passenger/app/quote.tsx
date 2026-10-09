import React, { useEffect, useRef, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import MapView, { Marker, Polyline } from 'react-native-maps';
import { Redirect, router } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { km, mins, passenger, rd, type Category, type Quote } from '@faxi/core';
import {
  Banner, Button, DestPin, Icon, IconButton, Loading, MAP_PADDING, OriginPin, Row, Sheet, T, c, coord, mapProvider, region,
} from '@faxi/ui';
import { draft } from '../src/draft';

const ICON: Record<Category, 'directions-car' | 'local-taxi' | 'airport-shuttle'> = {
  ECONOMICO: 'directions-car', CONFORT: 'directions-car', PREMIUM: 'local-taxi', SUV: 'airport-shuttle', VAN: 'airport-shuttle',
};

export default function QuoteScreen() {
  const o = draft.origin, d = draft.dest;
  const map = useRef<MapView>(null);
  const [quotes, setQuotes] = useState<Quote[] | null>(null);
  const [sel, setSel] = useState<Category | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!o || !d) return;
    passenger.quote(o, d).then((q) => { setQuotes(q); setSel(q[0]?.category ?? null); }).catch((e) => setErr(e.message));
  }, []);

  if (!o || !d) return <Redirect href="/" />;
  const chosen = quotes?.find((q) => q.category === sel);

  async function request() {
    if (!sel || !o || !d) return;
    setBusy(true); setErr(null);
    try {
      const t = await passenger.request(sel, o, d);
      router.replace({ pathname: '/trip', params: { id: t.id } });
    } catch (e: any) {
      if (e.code === '23505') {
        const t = await passenger.activeTrip().catch(() => null);
        if (t) { router.replace({ pathname: '/trip', params: { id: t.id } }); return; }
      }
      setErr(e.message);
    } finally { setBusy(false); }
  }

  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      <MapView ref={map} style={StyleSheet.absoluteFill} provider={mapProvider} initialRegion={region(o, 0.06)}
        onMapReady={() => map.current?.fitToCoordinates([coord(o), coord(d)], { edgePadding: MAP_PADDING, animated: false })}>
        <Marker coordinate={coord(o)} anchor={{ x: 0.5, y: 0.5 }}><OriginPin /></Marker>
        <Marker coordinate={coord(d)} anchor={{ x: 0.5, y: 0.5 }}><DestPin /></Marker>
        <Polyline coordinates={[coord(o), coord(d)]} strokeColor={c.ink} strokeWidth={3} lineDashPattern={[8, 6]} />
      </MapView>
      <SafeAreaView edges={['top']} style={{ position: 'absolute', top: 8, left: 16 }}>
        <IconButton icon="arrow-back" label="Volver" onPress={() => router.back()} />
      </SafeAreaView>

      <Sheet>
        <View style={{ gap: 2 }}>
          <T v="title">Elige tu viaje</T>
          <T v="caption" numberOfLines={1}>{o.address.split(',')[0]} → {d.address.split(',')[0]}</T>
        </View>
        {!quotes && !err ? <View style={{ height: 160 }}><Loading label="Calculando precio…" /></View> : null}
        {quotes?.map((q) => {
          const on = q.category === sel;
          return (
            <Pressable key={q.category} onPress={() => setSel(q.category)} accessibilityRole="radio" accessibilityState={{ selected: on }}
              style={{ flexDirection: 'row', alignItems: 'center', gap: 14, padding: 12, borderRadius: 18, borderWidth: 2, borderColor: on ? c.primary : c.outlineSoft, backgroundColor: c.white }}>
              <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: on ? c.primarySoft : c.surface2, alignItems: 'center', justifyContent: 'center' }}>
                <Icon name={ICON[q.category]} color={on ? c.primaryDark : c.ink} />
              </View>
              <View style={{ flex: 1 }}>
                <T v="label">{q.display_name}</T>
                <Row gap={6}>
                  <Icon name="person" size={14} color={c.ink2} />
                  <T v="caption">{q.capacity} · {mins(q.duration_min)} · {km(q.distance_km)}</T>
                </Row>
              </View>
              <T v="h2">{rd(q.total)}</T>
            </Pressable>
          );
        })}
        <Row style={{ paddingHorizontal: 4 }}>
          <Icon name="payments" color={c.primaryDark} />
          <T v="label" style={{ flex: 1 }}>Efectivo</T>
          <T v="caption">Pagas al conductor al llegar</T>
        </Row>
        {err ? <Banner text={err} /> : null}
        <Button title={chosen ? `Solicitar ${chosen.display_name}` : 'Solicitar'} onPress={request} loading={busy} disabled={!chosen} />
      </Sheet>
    </View>
  );
}
