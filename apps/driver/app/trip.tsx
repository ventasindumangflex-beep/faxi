import React, { useEffect, useRef, useState } from 'react';
import { Alert, Linking, Platform, StyleSheet, View } from 'react-native';
import MapView, { Marker } from 'react-native-maps';
import * as Location from 'expo-location';
import { router, useLocalSearchParams } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { createLocationBroadcaster, driver, DRIVER_CAN_CANCEL, DRIVER_NEXT, rd, trips, type TripStatus } from '@faxi/core';
import {
  Avatar, Banner, Button, DestPin, Icon, IconButton, Loading, MAP_PADDING, OriginPin, Row, Sheet, T, c, coord, f, mapProvider, region, useTripDetails,
} from '@faxi/ui';

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
  const { id } = useLocalSearchParams<{ id: string }>();
  const { details, error, reload } = useTripDetails(id);
  const map = useRef<MapView>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const t = details?.trip;
  const live = !!t && LIVE.includes(t.status);

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
      <View style={{ flex: 1, justifyContent: 'center', padding: 24, gap: 12, backgroundColor: c.surface }}>
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

  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      <MapView ref={map} style={StyleSheet.absoluteFill} provider={mapProvider} initialRegion={region({ lat: t.origin_lat, lng: t.origin_lng }, 0.03)} showsUserLocation toolbarEnabled={false}>
        <Marker coordinate={{ latitude: t.origin_lat, longitude: t.origin_lng }} anchor={{ x: 0.5, y: 0.5 }}><OriginPin /></Marker>
        <Marker coordinate={{ latitude: t.dest_lat, longitude: t.dest_lng }} anchor={{ x: 0.5, y: 0.5 }}><DestPin /></Marker>
      </MapView>
      {live ? (
        <SafeAreaView edges={['top']} style={{ position: 'absolute', top: 8, right: 16 }}>
          <IconButton icon="sos" label="Emergencia 911" onPress={() => Linking.openURL('tel:911')} />
        </SafeAreaView>
      ) : null}

      <Sheet>
        {live ? (
          <>
            <T v="micro">{t.code} · {toPickup ? 'Recoger en' : 'Llevar a'}</T>
            <T v="title" numberOfLines={2}>{target.label}</T>
            <Row>
              <Avatar name={pax?.name} size={44} />
              <View style={{ flex: 1 }}>
                <T v="label">{pax?.name}</T>
                <T v="caption">★ {pax?.rating?.toFixed(1) ?? 'Nuevo'} · Efectivo · {rd(t.estimated_fare)}</T>
              </View>
              <Button compact variant="tonal" icon="navigation" title="Navegar" onPress={() => openNavigation(target.lat, target.lng)} />
            </Row>
            {t.status === 'ARRIVED' ? <Banner tone="info" text="Avísale al pasajero que llegaste y espera en un lugar seguro." /> : null}
            {err ? <Banner text={err} /> : null}
            {next ? <Button title={next.label} onPress={advance} loading={busy} variant={next.to === 'FINISHED' ? 'dark' : 'filled'} /> : null}
            {DRIVER_CAN_CANCEL.includes(t.status) ? <Button title="Cancelar viaje" variant="danger" onPress={cancel} disabled={busy} /> : null}
          </>
        ) : t.status === 'FINISHED' || t.status === 'PAYMENT' ? (
          <>
            <T v="title">Cobra en efectivo</T>
            <View style={{ alignItems: 'center', gap: 4 }}>
              <T style={{ fontFamily: f.black, fontSize: 48, letterSpacing: -1.6 }}>{rd(t.final_fare)}</T>
              <T v="caption">Tu ganancia {rd(t.driver_earnings)} · comisión faxi {rd(t.faxi_commission)}</T>
            </View>
            {err ? <Banner text={err} /> : null}
            <Button title={`Recibí ${rd(t.final_fare)}`} icon="payments" onPress={() => run(() => driver.confirmCash(t.id))} loading={busy} />
          </>
        ) : (
          <>
            <Row><Icon name={t.status === 'COMPLETED' ? 'check-circle' : 'cancel'} size={28} color={t.status === 'COMPLETED' ? c.primary : c.error} />
              <T v="title" style={{ flex: 1 }}>{t.status === 'COMPLETED' ? 'Viaje completado' : t.status === 'CANCELLED_BY_PASSENGER' ? 'El pasajero canceló' : 'Viaje cancelado'}</T></Row>
            {t.status === 'COMPLETED' ? <T v="body">Ganaste {rd(t.driver_earnings)} en este viaje.</T> : null}
            <Button title="Buscar más viajes" onPress={() => router.replace('/')} />
          </>
        )}
      </Sheet>
    </View>
  );
}
