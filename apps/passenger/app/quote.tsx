import React, { useEffect, useRef, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import MapView from 'react-native-maps';
import { Redirect, router } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { airportLine, km, mins, passenger, rd, routes, type Category, type LatLng, type Quote } from '@faxi/core';
import {
  Banner, BigButton, DestPin, HudChip, IconButton, Loading, MAP_PADDING, OriginPin, RouteGlow, Row, Sheet, StatusScrim, T, VehicleCard, c, coord,
  region, useTheme, FaxiMap, PinMarker } from '@faxi/ui';
import { draft } from '../src/draft';

export default function QuoteScreen() {
  useTheme();
  const o = draft.origin, d = draft.dest;
  const map = useRef<MapView>(null);
  const [quotes, setQuotes] = useState<Quote[] | null>(null);
  const [sel, setSel] = useState<Category | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [road, setRoad] = useState<LatLng[] | null>(null);   // ruta real por las calles; sin ella, línea recta

  useEffect(() => {
    if (!o || !d) return;
    // Primero la ruta real: el servidor la guarda y el precio sale de esa distancia. Si no hay ruta, cotiza con la estimación de siempre.
    // Los precios los calcula el servidor (quote_trip): aquí solo se muestran
    routes.between(o, d)
      .then((r) => { setRoad(r?.points ?? null); return passenger.quote(o, d); })
      .then((q) => { setQuotes(q); setSel(q[0]?.category ?? null); })
      .catch((e) => setErr(e.message));
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
      <FaxiMap ref={map} style={StyleSheet.absoluteFill} initialRegion={region(o, 0.06)}
        onMapReady={() => map.current?.fitToCoordinates([coord(o), coord(d)], { edgePadding: MAP_PADDING, animated: false })}>
        <RouteGlow coordinates={road ? road.map(coord) : [coord(o), coord(d)]} />
        <PinMarker coordinate={coord(o)} anchor={{ x: 0.5, y: 0.5 }}><OriginPin /></PinMarker>
        <PinMarker coordinate={coord(d)} anchor={{ x: 0.5, y: 0.5 }}><DestPin /></PinMarker>
      </FaxiMap>
      <StatusScrim />
      <SafeAreaView edges={['top']} style={{ position: 'absolute', top: 8, left: 16, right: 16 }}>
        <Row style={{ justifyContent: 'space-between' }}>
          <IconButton icon="arrow-back" label="Volver" onPress={() => router.back()} />
          {quotes?.[0] ? <HudChip label={`${km(quotes[0].distance_km)} · ${mins(quotes[0].duration_min)}`} /> : null}
        </Row>
      </SafeAreaView>

      <Sheet collapsible
        peek={chosen ? (
          <View style={{ gap: 2 }}>
            <Row>
              <T numberOfLines={1} style={{ flex: 1 }} v="label">{chosen.display_name}</T>
              <T v="h2">{rd(chosen.total)}</T>
            </Row>
            {airportLine(chosen) ? <T v="caption">{airportLine(chosen)} (incluido)</T> : null}
          </View>
        ) : null}
        footer={(
          <View style={{ gap: 10 }}>
            {err ? <Banner text={err} /> : null}
            <BigButton title={chosen ? `Pedir ${chosen.display_name}` : 'Pedir'} price={chosen ? rd(chosen.total) : undefined}
              onPress={request} loading={busy} disabled={!chosen} />
            <T v="caption" center style={{ fontSize: 12.5 }}>Efectivo · Sin sorpresas: el precio se calcula antes de pedir.</T>
          </View>
        )}>
        <View style={{ gap: 2 }}>
          <T v="title">Elige tu viaje</T>
          <T v="caption" numberOfLines={1}>{o.address.split(',')[0]} → {d.address.split(',')[0]}</T>
        </View>
        {!quotes && !err ? <View style={{ height: 160 }}><Loading label="Calculando precio…" /></View> : null}
        <View style={{ gap: 8 }} accessibilityRole="radiogroup">
          {quotes?.map((q) => (
            <VehicleCard key={q.category} category={q.category} name={q.display_name} subtitle={`${q.capacity} personas`}
              price={rd(q.total)} selected={q.category === sel} onPress={() => setSel(q.category)}
              accessibilityLabel={`${q.display_name}, ${q.capacity} personas, ${rd(q.total)}`} />
          ))}
        </View>
        {chosen && airportLine(chosen) ? <T v="caption">{airportLine(chosen)} (ya incluido en el precio)</T> : null}
      </Sheet>
    </View>
  );
}
