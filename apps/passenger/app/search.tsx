import React, { useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, View } from 'react-native';
import { router } from 'expo-router';
import type { Place } from '@faxi/core';
import { Banner, Field, Header, ListItem, Row, Screen, T, c, SD_CENTER } from '@faxi/ui';
import { autocomplete, placeDetails, type Suggestion } from '../src/places';
import { getHere } from '../src/location';
import { draft } from '../src/draft';

type Target = 'origin' | 'dest';

export default function Search() {
  const [origin, setOrigin] = useState<Place | null>(draft.origin);
  const [text, setText] = useState({ origin: draft.origin?.address ?? '', dest: '' });
  const [focus, setFocus] = useState<Target>('dest');
  const [list, setList] = useState<Suggestion[]>([]);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const q = text[focus];
    if (focus === 'origin' && origin && q === origin.address) { setList([]); return; }
    const h = setTimeout(() => {
      autocomplete(q, origin ?? SD_CENTER).then((l) => { setList(l); setErr(null); }).catch((e) => setErr(e.message));
    }, 300);
    return () => clearTimeout(h);
  }, [text, focus]);

  async function pick(s: Suggestion) {
    setBusy(true); setErr(null);
    try {
      const p = await placeDetails(s.id);
      if (focus === 'origin') { setOrigin(p); setText((t) => ({ ...t, origin: p.address })); setFocus('dest'); setList([]); return; }
      if (!origin) { setErr('Elige primero el punto de recogida.'); setFocus('origin'); return; }
      draft.origin = origin; draft.dest = p;
      router.push('/quote');
    } catch (e: any) { setErr(e.message); } finally { setBusy(false); }
  }

  async function useMyLocation() {
    setBusy(true);
    try {
      const h = await getHere();
      if (h.denied) { setErr('Activa la ubicación o escribe tu punto de recogida.'); return; }
      setOrigin(h.place); setText((t) => ({ ...t, origin: h.place.address })); setFocus('dest');
    } finally { setBusy(false); }
  }

  return (
    <Screen>
      <Header title="Planifica tu viaje" onBack={() => router.back()} />
      <View style={{ gap: 10 }}>
        <Row>
          <View style={{ width: 12, height: 12, borderRadius: 6, borderWidth: 3.5, borderColor: c.ink }} />
          <View style={{ flex: 1 }}>
            <Field value={text.origin} onFocus={() => setFocus('origin')} placeholder="Punto de recogida" selectTextOnFocus
              onChangeText={(v) => { setText((t) => ({ ...t, origin: v })); setOrigin(null); }} accessibilityLabel="Punto de recogida" />
          </View>
        </Row>
        <Row>
          <View style={{ width: 12, height: 12, borderRadius: 3, backgroundColor: c.primary }} />
          <View style={{ flex: 1 }}>
            <Field value={text.dest} onFocus={() => setFocus('dest')} autoFocus placeholder="¿A dónde vas?"
              onChangeText={(v) => setText((t) => ({ ...t, dest: v }))} accessibilityLabel="Destino" />
          </View>
        </Row>
      </View>
      {err ? <Banner text={err} /> : null}
      {busy ? <ActivityIndicator color={c.primary} /> : null}
      <FlatList
        data={list}
        keyExtractor={(s) => s.id}
        keyboardShouldPersistTaps="handled"
        ListHeaderComponent={focus === 'origin' ? <ListItem icon="my-location" title="Usar mi ubicación actual" onPress={useMyLocation} /> : null}
        ListEmptyComponent={text[focus].trim().length >= 2 && !busy ? <T v="caption" style={{ paddingVertical: 12 }}>Sin resultados. Prueba con otro nombre o calle.</T> : null}
        renderItem={({ item }) => <ListItem icon="place" title={item.main} subtitle={item.secondary} onPress={() => pick(item)} />}
      />
    </Screen>
  );
}
