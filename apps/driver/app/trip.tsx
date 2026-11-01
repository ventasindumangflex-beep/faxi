import React, { useEffect, useRef, useState } from 'react';
import { Alert, Linking, Platform, ScrollView, StyleSheet, View } from 'react-native';
import MapView from 'react-native-maps';
import * as Location from 'expo-location';
import { router, useLocalSearchParams } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { airportLine, createLocationBroadcaster, driver, DRIVER_CAN_CANCEL, DRIVER_NEXT, rd, routes, trips, waitLine, type LatLng, type TripStatus } from '@faxi/core';
import {
  Avatar, Banner, BigButton, Button, DestPin, HudChip, Icon, IconButton, Loading, MAP_PADDING, OriginPin, RouteGlow, Row, Sheet, StatusScrim, T, c, coord, region,
  useTheme, useTripDetails, FaxiMap, PinMarker } from '@faxi/ui';

const LIVE: TripStatus[] = ['ASSIGNED', 'ENROUTE', 'ARRIVED', 'STARTED', 'ONTRIP'];

function openNavigation(lat: number, lng: number) {
  const google = Platform.OS === 'ios'
    ? `comgooglemaps://?daddr=${lat},${lng}&directionsmode=driving`
    : `google.navigation:q=${lat},${lng}`;
  Alert.alert('Navegar con', undefined, [
    { text: 'Waze', onPress: () => Linking.openURL(`https://waze.com/ul?ll=${lat},${lng}&navigate=yes`) },
    { text: 'Google Maps', onPress: () => Linking.openURL(google).catch(() => Linking.openURL(`https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}&travelmode=driving`)) },
    { text: 'Cancelar', style: 'cancel' },
  ]);
}

export default function TripScreen() {
  const { scheme } = useTheme();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { details, error, reload } = useTripDetails(id);
  const map = useRef<MapView>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [road, setRoad] = useState<LatLng[] | null>(null);   // origen → destino por las calles; sin ella, línea recta
  const t = details?.trip;
  const live = !!t && LIVE.includes(t.status);
  const tid = t?.id;
  useEffect(() => {
    if (!t) return;
    routes.between({ lat: t.origin_lat, lng: t.origin_lng }, { lat: t.dest_lat, lng: t.dest_lng }).then((r) => { if (r) setRoad(r.points); });
  }, [tid]);

  // Ubicación en vivo para el pasajero: Broadcast cada ~5 s mientras el viaje está activo
  useEffect(() => {
    if (!id || !live) return;
    const bc = createLocationBroadcaster(id);
    let sub: Location.LocationSubscription | null = null;
    Location.watchPositionAsync({ accuracy: Location.Accuracy.High, timeInterval: 5000, distanceInterval: 10 }, (p) =>
      bc.send({ lat: p.coords.latitude, lng: p.coords.longitude, heading: p.coords.heading }),
    ).then((s) => { sub = s; }).catch(() => {});
    return () => { sub?.remove(); bc.close(); };
  }, [id, live]);

  const toPickup = t && ['ASSIGNED', 'ENROUTE', 'ARRIVED'].includes(t.status);
  useEffect(() => {
    if (!t) return;
    const target = toPickup ? { lat: t.origin_lat, lng: t.origin_lng } : { lat: t.dest_lat, lng: t.dest_lng };
    Location.getLastKnownPositionAsync().then((p) => {
      const pts = p ? [{ latitude: p.coords.latitude, longitude: p.coords.longitude }, coord(target)] : [coord(target)];
      map.current?.fitToCoordinates(pts, { edgePadding: MAP_PADDING, animated: true });
    }).catch(() => {});
  }, [t?.id, toPickup]);

  if (!t || !details) {
    return error ? (
      <View style={{ flex: 1, justifyContent: 'center', padding: 24, gap: 12, backgroundColor: c.bg }}>
        <Banner text={error} />
        <Button title="Volver" onPress={() => router.replace('/')} />
      </View>
    ) : <Loading />;
  }

  async function run(fn: () => Promise<unknown>) {
    setBusy(true); setErr(null);
    try { await fn(); await reload(); } catch (e: any) { setErr(e.message); } finally { setBusy(false); }
  }

  const next = DRIVER_NEXT[t.status];
  function advance() {
    if (!next) return;
    run(async () => {
      await driver.advance(t!.id, next.to);
      if (next.to === 'STARTED') await driver.advance(t!.id, 'ONTRIP');
    });
  }

  function cancel() {
    Alert.alert('¿Cancelar este viaje?', 'Las cancelaciones frecuentes afectan tu cuenta.', [
      { text: 'No', style: 'cancel' },
      { text: 'Sí, cancelar', style: 'destructive', onPress: () => run(() => trips.cancel(t!.id, 'Cancelado por el conductor')) },
    ]);
  }

  const target = toPickup ? { lat: t.origin_lat, lng: t.origin_lng, label: t.origin_address } : { lat: t.dest_lat, lng: t.dest_lng, label: t.dest_address };
  const pax = details.passenger;
  const isCash = t.status === 'FINISHED' || t.status === 'PAYMENT';

  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      <FaxiMap ref={map} style={StyleSheet.absoluteFill} initialRegion={region({ lat: t.origin_lat, lng: t.origin_lng }, 0.03)} showsUserLocation toolbarEnabled={false}>
        {live && !toPickup ? <RouteGlow coordinates={road ? road.map(coord) : [coord({ lat: t.origin_lat, lng: t.origin_lng }), coord({ lat: t.dest_lat, lng: t.dest_lng })]} /> : null}
        <PinMarker coordinate={{ latitude: t.origin_lat, longitude: t.origin_lng }} anchor={{ x: 0.5, y: 0.5 }}><OriginPin /></PinMarker>
        <PinMarker coordinate={{ latitude: t.dest_lat, longitude: t.dest_lng }} anchor={{ x: 0.5, y: 0.5 }}><DestPin /></PinMarker>
      </FaxiMap>
      <StatusScrim />
      {live ? (
        <SafeAreaView edges={['top']} style={{ position: 'absolute', top: 8, left: 16, right: 16 }}>
          <Row style={{ justifyContent: 'space-between' }}>
            <HudChip dot label={toPickup ? 'Recogiendo' : 'En viaje'} />
            <IconButton icon="sos" label="Emergencia 911" onPress={() => Linking.openURL('tel:911')} />
          </Row>
        </SafeAreaView>
      ) : null}

      {isCash ? (
        // Cobro en efectivo: el servidor ya calculó el total, la espera, el recargo y la comisión (driver_advance_trip)
        <View style={[StyleSheet.absoluteFill, { backgroundColor: c.bg }]}>
          <View style={{ position: 'absolute', top: 0, left: -60, right: -60, height: 360, borderBottomLeftRadius: 400, borderBottomRightRadius: 400, backgroundColor: c.endTop, opacity: scheme === 'dark' ? 0.55 : 0.8 }} />
          <SafeAreaView style={{ flex: 1 }}>
            <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', alignItems: 'center', gap: 14, padding: 24 }}>
              <T v="micro" color={c.accent}>Cobra en efectivo</T>
              <T v="price" fit center style={{ fontSize: 60, lineHeight: 66 }}>{rd(t.final_fare)}</T>
              {waitLine(t) ? <T v="caption">{waitLine(t)}</T> : null}
              {airportLine(t) ? <T v="caption">{airportLine(t)}</T> : null}
              <View style={{ alignSelf: 'stretch', gap: 6, padding: 14, borderRadius: 16, backgroundColor: c.card }}>
                <Row style={{ justifyContent: 'space-between' }}><T v="caption">Tu ganancia</T><T v="label">{rd(t.driver_earnings)}</T></Row>
                <Row style={{ justifyContent: 'space-between' }}><T v="caption">Comisión faxi</T><T v="label">{rd(t.faxi_commission)}</T></Row>
              </View>
              {err ? <View style={{ alignSelf: 'stretch' }}><Banner text={err} /></View> : null}
              <BigButton title="Recibí el efectivo" price={rd(t.final_fare)} icon="payments" onPress={() => run(() => driver.confirmCash(t.id))} loading={busy} style={{ alignSelf: 'stretch' }} />
            </ScrollView>
          </SafeAreaView>
        </View>
      ) : (
        <Sheet>
          {live ? (
            <>
              <T v="micro">{t.code} · {toPickup ? 'Recoger en' : 'Llevar a'}</T>
              <T v="title" numberOfLines={2}>{target.label}</T>
              <Row>
                <Avatar name={pax?.name} size={44} />
                <View style={{ flex: 1, minWidth: 0 }}>
                  <T v="label" numberOfLines={1}>{pax?.name}</T>
                  <T v="caption" numberOfLines={1}>★ {pax?.rating?.toFixed(1) ?? 'Nuevo'} · Efectivo · {rd(t.estimated_fare)}</T>
                </View>
                <Button compact variant="tonal" icon="navigation" title="Navegar" onPress={() => openNavigation(target.lat, target.lng)} />
              </Row>
              {airportLine(t) ? <T v="caption">{airportLine(t)} (incluido en el precio)</T> : null}
              {t.status === 'ARRIVED' ? <Banner tone="info" text="Avísale al pasajero que llegaste y espera en un lugar seguro." /> : null}
              {err ? <Banner text={err} /> : null}
              {next ? <BigButton title={next.label} onPress={advance} loading={busy} /> : null}
              {DRIVER_CAN_CANCEL.includes(t.status) ? <Button title="Cancelar viaje" variant="danger" onPress={cancel} disabled={busy} /> : null}
            </>
          ) : (
            <>
              <Row><Icon name={t.status === 'COMPLETED' ? 'check-circle' : 'cancel'} size={28} color={t.status === 'COMPLETED' ? c.accent : c.error} />
                <T v="title" style={{ flex: 1 }}>{t.status === 'COMPLETED' ? 'Viaje completado' : t.status === 'CANCELLED_BY_PASSENGER' ? 'El pasajero canceló' : 'Viaje cancelado'}</T></Row>
              {t.status === 'COMPLETED' ? <T v="body">Ganaste {rd(t.driver_earnings)} en este viaje.</T> : null}
              <BigButton title="Buscar más viajes" onPress={() => router.replace('/')} />
            </>
          )}
        </Sheet>
      )}
    </View>
  );
}
