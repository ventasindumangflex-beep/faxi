import React, { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, KeyboardAvoidingView, Linking, Platform, Share, StyleSheet, View } from 'react-native';
import MapView, { Marker } from 'react-native-maps';
import { router, useLocalSearchParams } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import {
  ENDED_UNSUCCESSFUL, PASSENGER_CAN_CANCEL, etaMin, passenger, rd, trips, type TripDetails, type TripStatus,
} from '@faxi/core';
import {
  Avatar, Banner, Button, CarPin, DestPin, Field, Icon, IconButton, Loading, MAP_PADDING, OriginPin, Row, Sheet, Stars, T,
  c, coord, f, mapProvider, region, useTripDetails,
} from '@faxi/ui';
import { draft } from '../src/draft';

type Phase = 'search' | 'pickup' | 'ride' | 'pay' | 'rate' | 'ended';
function phaseOf(s: TripStatus, rated: boolean): Phase {
  if (s === 'REQUESTED' || s === 'SEARCHING' || s === 'DRIVER_TIMEOUT') return 'search';
  if (s === 'ASSIGNED' || s === 'ENROUTE' || s === 'ARRIVED') return 'pickup';
  if (s === 'STARTED' || s === 'ONTRIP') return 'ride';
  if (s === 'FINISHED' || s === 'PAYMENT' || s === 'PAYMENT_FAILED') return 'pay';
  if (s === 'COMPLETED') return rated ? 'ended' : 'rate';
  return 'ended';
}

export default function TripScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { details, driverPos, error } = useTripDetails(id, { listenLocation: true });
  const map = useRef<MapView>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [stars, setStars] = useState(0);
  const [comment, setComment] = useState('');

  const t = details?.trip;
  const phase = t ? phaseOf(t.status, !!details?.rating) : null;

  // Encuadre del mapa según la fase
  useEffect(() => {
    if (!t) return;
    const o = { lat: t.origin_lat, lng: t.origin_lng }, d = { lat: t.dest_lat, lng: t.dest_lng };
    const pts = phase === 'pickup' && driverPos ? [o, driverPos] : phase === 'ride' && driverPos ? [driverPos, d] : [o, d];
    map.current?.fitToCoordinates(pts.map(coord), { edgePadding: MAP_PADDING, animated: true });
  }, [phase, t?.id, !!driverPos]);

  if (!details || !t || !phase) {
    return error ? (
      <View style={{ flex: 1, justifyContent: 'center', padding: 24, gap: 12, backgroundColor: c.surface }}>
        <Banner text={error} />
        <Button title="Volver al inicio" onPress={() => router.replace('/')} />
      </View>
    ) : <Loading />;
  }

  const o = { lat: t.origin_lat, lng: t.origin_lng };
  const dv = details.driver, veh = details.vehicle;

  async function cancel() {
    Alert.alert('¿Cancelar el viaje?', phase === 'pickup' ? 'Tu conductor ya va en camino.' : undefined, [
      { text: 'No', style: 'cancel' },
      { text: 'Sí, cancelar', style: 'destructive', onPress: async () => {
        setBusy(true); setErr(null);
        try { await trips.cancel(t!.id, 'Cancelado por el pasajero'); } catch (e: any) { setErr(e.message); } finally { setBusy(false); }
      } },
    ]);
  }

  async function rate() {
    setBusy(true); setErr(null);
    try { await passenger.rate(t!.id, stars, comment); router.replace('/'); } catch (e: any) { setErr(e.message); setBusy(false); }
  }

  function share() {
    const who = dv ? `${dv.name} · ${veh?.make ?? ''} ${veh?.model ?? ''} ${veh?.color ?? ''} · placa ${veh?.plate ?? ''}` : '';
    Share.share({ message: `Voy en faxi (${t!.code}) hacia ${t!.dest_address}. ${who}` });
  }

  function retry() {
    draft.origin = { address: t!.origin_address, lat: t!.origin_lat, lng: t!.origin_lng };
    draft.dest = { address: t!.dest_address, lat: t!.dest_lat, lng: t!.dest_lng };
    router.replace('/quote');
  }

  const eta = driverPos ? etaMin(driverPos, o) : null;
  const pickupTitle = t.status === 'ARRIVED' ? 'Tu conductor llegó' : t.status === 'ENROUTE' && eta ? `Llega en ~${eta} min` : 'Tu conductor aceptó el viaje';

  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      <MapView ref={map} style={StyleSheet.absoluteFill} provider={mapProvider} initialRegion={region(o, 0.04)} toolbarEnabled={false}>
        <Marker coordinate={coord(o)} anchor={{ x: 0.5, y: 0.5 }}><OriginPin /></Marker>
        <Marker coordinate={{ latitude: t.dest_lat, longitude: t.dest_lng }} anchor={{ x: 0.5, y: 0.5 }}><DestPin /></Marker>
        {driverPos && (phase === 'pickup' || phase === 'ride') ? (
          <Marker coordinate={coord(driverPos)} anchor={{ x: 0.5, y: 0.5 }}><CarPin /></Marker>
        ) : null}
      </MapView>
      {phase === 'ride' ? (
        <SafeAreaView edges={['top']} style={{ position: 'absolute', top: 8, right: 16 }}>
          <IconButton icon="sos" label="Emergencia 911" onPress={() => Linking.openURL('tel:911')} />
        </SafeAreaView>
      ) : null}

      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ position: 'absolute', left: 0, right: 0, bottom: 0, top: 0 }} pointerEvents="box-none">
        <Sheet>
          {phase === 'search' && (
            <>
              <Row><ActivityIndicator color={c.primary} /><T v="title" style={{ flex: 1 }}>Buscando tu conductor…</T></Row>
              <T v="caption">Te avisaremos en cuanto alguien acepte. Destino: {t.dest_address}</T>
              <T v="label">Estimado {rd(t.estimated_fare)} · efectivo</T>
              <Button title="Cancelar búsqueda" variant="outline" onPress={cancel} loading={busy} />
            </>
          )}

          {(phase === 'pickup' || phase === 'ride') && (
            <>
              <T v="title">{phase === 'ride' ? `Rumbo a ${t.dest_address.split(',')[0]}` : pickupTitle}</T>
              {dv ? <DriverCard d={details} /> : null}
              <Row gap={10}>
                {phase === 'pickup' && dv?.phone ? (
                  <Button title="Llamar" icon="call" variant="tonal" style={{ flex: 1 }} onPress={() => Linking.openURL(`tel:${dv.phone}`)} />
                ) : null}
                <Button title="Compartir viaje" icon="ios-share" variant="tonal" style={{ flex: 1 }} onPress={share} />
              </Row>
              {PASSENGER_CAN_CANCEL.includes(t.status) ? <Button title="Cancelar viaje" variant="danger" onPress={cancel} loading={busy} /> : null}
            </>
          )}

          {phase === 'pay' && (
            <>
              <T v="title">Llegaste a tu destino</T>
              <View style={{ alignItems: 'center', gap: 4, paddingVertical: 8 }}>
                <T v="caption">Paga en efectivo a {dv?.name.split(' ')[0] ?? 'tu conductor'}</T>
                <T style={{ fontFamily: f.black, fontSize: 44, letterSpacing: -1.5 }}>{rd(t.final_fare)}</T>
              </View>
              <Row style={{ justifyContent: 'center' }}><ActivityIndicator color={c.primary} /><T v="caption">Esperando que el conductor confirme el cobro…</T></Row>
            </>
          )}

          {phase === 'rate' && (
            <>
              <T v="title" center>¿Cómo estuvo tu viaje{dv ? ` con ${dv.name.split(' ')[0]}` : ''}?</T>
              <T v="caption" center>Pagaste {rd(t.final_fare)} en efectivo</T>
              <Stars value={stars} onChange={setStars} />
              <Field value={comment} onChangeText={setComment} placeholder="Comentario (opcional)" maxLength={500} />
              <Button title="Enviar calificación" onPress={rate} loading={busy} disabled={!stars} />
              <Button title="Ahora no" variant="outline" onPress={() => router.replace('/')} />
            </>
          )}

          {phase === 'ended' && <Ended status={t.status} onRetry={retry} />}

          {err ? <Banner text={err} /> : null}
        </Sheet>
      </KeyboardAvoidingView>
    </View>
  );
}

function DriverCard({ d }: { d: TripDetails }) {
  const dv = d.driver!, v = d.vehicle;
  return (
    <Row style={{ backgroundColor: c.white, borderRadius: 20, borderWidth: 1, borderColor: c.outlineSoft, padding: 14 }}>
      <Avatar name={dv.name} />
      <View style={{ flex: 1 }}>
        <T v="label">{dv.name}</T>
        <Row gap={4}><Icon name="star" size={16} color={c.star} /><T v="caption">{dv.rating?.toFixed(1) ?? 'Nuevo'} · {dv.trips} viajes</T></Row>
        {v ? <T v="caption">{v.make} {v.model} · {v.color}</T> : null}
      </View>
      {v ? (
        <View style={{ backgroundColor: c.surface2, borderRadius: 10, paddingHorizontal: 10, paddingVertical: 6 }}>
          <T style={{ fontFamily: f.black, fontSize: 16, letterSpacing: 1 }}>{v.plate}</T>
        </View>
      ) : null}
    </Row>
  );
}

function Ended({ status, onRetry }: { status: TripStatus; onRetry: () => void }) {
  const msg: Partial<Record<TripStatus, string>> = {
    NO_DRIVER: 'No encontramos conductores disponibles',
    REQUEST_TIMEOUT: 'La solicitud venció',
    CANCELLED_BY_DRIVER: 'El conductor canceló el viaje',
    CANCELLED_BY_PASSENGER: 'Cancelaste el viaje',
    CANCELLED: 'faxi canceló este viaje',
    COMPLETED: '¡Gracias por viajar con faxi!',
  };
  const canRetry = ENDED_UNSUCCESSFUL.includes(status) && status !== 'CANCELLED_BY_PASSENGER';
  return (
    <>
      <T v="title">{msg[status] ?? 'Viaje terminado'}</T>
      {canRetry ? <Button title="Pedir otro faxi" onPress={onRetry} /> : null}
      <Button title="Volver al inicio" variant={canRetry ? 'outline' : 'filled'} onPress={() => router.replace('/')} />
    </>
  );
}
