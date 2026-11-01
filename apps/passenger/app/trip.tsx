import React, { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, KeyboardAvoidingView, Linking, Platform, ScrollView, Share, StyleSheet, View } from 'react-native';
import MapView from 'react-native-maps';
import { router, useLocalSearchParams } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import {
  ENDED_UNSUCCESSFUL, PASSENGER_CAN_CANCEL, airportLine, distanceKm, etaMin, passenger, rd, trips, waitLine, type TripDetails, type TripStatus,
} from '@faxi/core';
import {
  ActionPill, Avatar, Banner, BigButton, Button, CarPin, Confetti, CountdownPill, DestPin, Field, HudChip, Icon, Loading, MAP_PADDING, OriginPin,
  Plate, ProgressBar, Radar, RouteGlow, Row, Sheet, Stars, T, c, coord, f, region, useCountdown, useTheme, useTripDetails, FaxiMap, PinMarker } from '@faxi/ui';
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

const STAR_MSG = ['¿Cómo estuvo el viaje?', 'Lamentamos eso. Cuéntanos qué pasó.', 'Podemos mejorar.', 'Buen viaje.', '¡Muy bien! Gracias.', '¡Excelente! Gracias por viajar con faxi.'];

export default function TripScreen() {
  const { scheme } = useTheme();
  const { id } = useLocalSearchParams<{ id: string }>();
  // La pantalla se arma siempre desde el servidor (trip_details): al reabrir la app vuelve a este viaje (activeTrip en Inicio)
  const { details, driverPos, error } = useTripDetails(id, { listenLocation: true });
  const map = useRef<MapView>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [stars, setStars] = useState(0);
  const [comment, setComment] = useState('');

  const t = details?.trip;
  const phase = t ? phaseOf(t.status, !!details?.rating) : null;
  const o = t ? { lat: t.origin_lat, lng: t.origin_lng } : null;
  const d = t ? { lat: t.dest_lat, lng: t.dest_lng } : null;
  const eta = t && o && driverPos ? etaMin(driverPos, o) : null;
  const arrivalSecs = useCountdown(phase === 'pickup' && t?.status === 'ENROUTE' && eta ? eta * 60 : null);

  // Encuadre del mapa según la fase
  useEffect(() => {
    if (!t || !o || !d) return;
    const pts = phase === 'pickup' && driverPos ? [o, driverPos] : phase === 'ride' && driverPos ? [driverPos, d] : [o, d];
    map.current?.fitToCoordinates(pts.map(coord), { edgePadding: MAP_PADDING, animated: true });
  }, [phase, t?.id, !!driverPos]);

  if (!details || !t || !phase || !o || !d) {
    return error ? (
      <View style={{ flex: 1, justifyContent: 'center', padding: 24, gap: 12, backgroundColor: c.bg }}>
        <Banner text={error} />
        <Button title="Volver al inicio" onPress={() => router.replace('/')} />
      </View>
    ) : <Loading />;
  }

  const dv = details.driver, veh = details.vehicle;
  const firstName = dv?.name.split(' ')[0] ?? 'tu conductor';

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

  const sos = () => Linking.openURL('tel:911');
  const route = phase === 'pickup' ? (driverPos ? [driverPos, o] : null) : phase === 'ride' ? [driverPos ?? o, d] : null;
  const minsLeft = phase === 'ride' ? (driverPos ? etaMin(driverPos, d) : Math.max(1, Math.round(t.duration_min))) : 0;
  const total = distanceKm(o, d);
  const progress = driverPos && total > 0 ? 1 - distanceKm(driverPos, d) / total : 0.08;
  const arriving = t.status === 'ARRIVED';

  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      <FaxiMap ref={map} style={StyleSheet.absoluteFill} initialRegion={region(o, 0.04)} toolbarEnabled={false}>
        {route ? <RouteGlow coordinates={route.map(coord)} /> : null}
        <PinMarker coordinate={coord(o)} anchor={{ x: 0.5, y: 0.5 }}><OriginPin /></PinMarker>
        <PinMarker coordinate={coord(d)} anchor={{ x: 0.5, y: 0.5 }}><DestPin /></PinMarker>
        {driverPos && (phase === 'pickup' || phase === 'ride') ? (
          <PinMarker coordinate={coord(driverPos)} anchor={{ x: 0.5, y: 0.5 }}><CarPin /></PinMarker>
        ) : null}
      </FaxiMap>

      {phase === 'pickup' || phase === 'ride' ? (
        <SafeAreaView edges={['top']} pointerEvents="none" style={{ position: 'absolute', top: 8, left: 16, right: 16 }}>
          <Row style={{ justifyContent: 'space-between' }}>
            <HudChip dot label={phase === 'ride' ? 'En viaje' : arriving ? 'Tu conductor llegó' : 'Tu conductor viene'} />
            {phase === 'ride' ? <HudChip label="Efectivo" /> : null}
          </Row>
        </SafeAreaView>
      ) : null}

      {phase === 'search' ? (
        <View style={[StyleSheet.absoluteFill, { backgroundColor: c.scrim, alignItems: 'center', justifyContent: 'center', gap: 16, padding: 24, paddingBottom: 220 }]}>
          <Radar />
          <T v="display" center>Buscando tu conductor</T>
          <T v="body" center color={c.muted} style={{ maxWidth: 300 }}>Avisamos a los conductores más cercanos. Suele tardar menos de un minuto.</T>
          <T v="caption" center numberOfLines={2}>Destino: {t.dest_address}</T>
          <T v="label" center>Estimado {rd(t.estimated_fare)} · efectivo</T>
          {airportLine(t) ? <T v="caption" center>{airportLine(t)} (incluido)</T> : null}
        </View>
      ) : null}

      {phase === 'pay' || phase === 'rate' ? (
        <View style={[StyleSheet.absoluteFill, { backgroundColor: c.bg }]}>
          <View style={{ position: 'absolute', top: 0, left: -60, right: -60, height: 360, borderBottomLeftRadius: 400, borderBottomRightRadius: 400, backgroundColor: c.endTop, opacity: scheme === 'dark' ? 0.55 : 0.8 }} />
          <Confetti />
          <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1 }}>
            <SafeAreaView style={{ flex: 1 }}>
              <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', alignItems: 'center', gap: 14, padding: 24 }} keyboardShouldPersistTaps="handled">
                <T v="micro" color={c.accent}>Llegaste</T>
                <T v="price" fit center style={{ fontSize: 60, lineHeight: 66 }}>{rd(t.final_fare)}</T>
                {waitLine(t) ? <T v="caption">{waitLine(t)}</T> : null}
                {airportLine(t) ? <T v="caption">{airportLine(t)}</T> : null}
                <T v="body" center>{phase === 'pay' ? `Paga en efectivo a ${firstName}` : `Pagaste en efectivo a ${firstName}`}</T>
                {phase === 'pay' ? (
                  <Row style={{ justifyContent: 'center' }}><ActivityIndicator color={c.primary} /><T v="caption">Esperando que el conductor confirme el cobro…</T></Row>
                ) : (
                  <View style={{ alignSelf: 'stretch', alignItems: 'center', gap: 10 }}>
                    <Stars value={stars} onChange={setStars} />
                    <T v="body" center color={c.muted} style={{ minHeight: 22 }}>{STAR_MSG[stars]}</T>
                    <View style={{ alignSelf: 'stretch' }}>
                      <Field value={comment} onChangeText={setComment} placeholder="Comentario (opcional)" maxLength={500} />
                    </View>
                    {err ? <View style={{ alignSelf: 'stretch' }}><Banner text={err} /></View> : null}
                    <BigButton title="Enviar calificación" icon="check" onPress={rate} loading={busy} disabled={!stars} style={{ alignSelf: 'stretch' }} />
                    <Button title="Ahora no" variant="outline" onPress={() => router.replace('/')} style={{ alignSelf: 'stretch' }} />
                  </View>
                )}
                {phase === 'pay' && err ? <Banner text={err} /> : null}
              </ScrollView>
            </SafeAreaView>
          </KeyboardAvoidingView>
        </View>
      ) : null}

      {phase !== 'pay' && phase !== 'rate' ? (
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ position: 'absolute', left: 0, right: 0, bottom: 0, top: 0 }} pointerEvents="box-none">
          <Sheet collapsible={phase === 'pickup' || phase === 'ride'}
            peek={phase === 'ride' ? <T v="label" numberOfLines={1}>{minsLeft} min · {t.dest_address.split(',')[0]}</T> : <T v="label">{arriving ? 'Tu conductor llegó' : eta ? `Llega en ~${eta} min` : 'Tu conductor viene'}</T>}>
            {phase === 'search' && (
              <Button title="Cancelar búsqueda" variant="outline" onPress={cancel} loading={busy} />
            )}

            {phase === 'pickup' && (
              <>
                {t.status === 'ENROUTE' && eta ? (
                  <T v="eta">Llega en <T v="eta" color={c.accent}>{Math.max(1, Math.ceil(arrivalSecs / 60))}</T> min</T>
                ) : (
                  <T v="eta" style={{ fontSize: 32, lineHeight: 36 }}>{arriving ? 'Tu conductor llegó' : 'Tu conductor aceptó el viaje'}</T>
                )}
                <Row style={{ justifyContent: 'space-between', alignItems: 'center' }}>
                  {t.status === 'ENROUTE' && eta ? <CountdownPill seconds={arrivalSecs} /> : <View />}
                  {veh ? <Plate value={veh.plate} /> : null}
                </Row>
                {dv ? <DriverRow d={details} /> : null}
                <Row gap={8}>
                  <ActionPill label="Llamar" icon="call" disabled={!dv?.phone} onPress={() => dv?.phone && Linking.openURL(`tel:${dv.phone}`)} />
                  <ActionPill label="Mensaje" icon="sms" disabled={!dv?.phone} onPress={() => dv?.phone && Linking.openURL(`sms:${dv.phone}`)} />
                  <ActionPill label="SOS" icon="sos" tone="sos" onPress={sos} />
                </Row>
                {PASSENGER_CAN_CANCEL.includes(t.status) ? <Button title="Cancelar viaje" variant="danger" onPress={cancel} loading={busy} /> : null}
              </>
            )}

            {phase === 'ride' && (
              <>
                <Row style={{ justifyContent: 'space-between', alignItems: 'baseline' }}>
                  <T v="eta"><T v="eta" color={c.accent}>{minsLeft}</T> min</T>
                  <T v="label" color={c.muted} numberOfLines={1} style={{ flex: 1, textAlign: 'right' }}>{t.dest_address.split(',')[0]}</T>
                </Row>
                <ProgressBar value={progress} />
                <Row style={{ justifyContent: 'space-between' }}>
                  <T v="caption" numberOfLines={1} style={{ flexShrink: 1 }}>{firstName}{veh ? ` · ${veh.plate}` : ''}</T>
                  <T v="caption" numberOfLines={1}>Total al llegar: {rd(t.estimated_fare)}</T>
                </Row>
                {airportLine(t) ? <T v="caption">{airportLine(t)} (incluido)</T> : null}
                <Row gap={8}>
                  <ActionPill label="Compartir viaje" icon="ios-share" onPress={share} />
                  <ActionPill label="SOS" icon="sos" tone="sos" onPress={sos} />
                </Row>
              </>
            )}

            {phase === 'ended' && <Ended status={t.status} onRetry={retry} />}

            {err && phase !== 'ended' ? <Banner text={err} /> : null}
          </Sheet>
        </KeyboardAvoidingView>
      ) : null}
    </View>
  );
}

function DriverRow({ d }: { d: TripDetails }) {
  useTheme();
  const dv = d.driver!, v = d.vehicle;
  return (
    <Row gap={14}>
      <Avatar name={dv.name} size={56} />
      <View style={{ flex: 1, minWidth: 0 }}>
        <T numberOfLines={1} style={{ fontFamily: f.black, fontSize: 17, lineHeight: 22 }}>{dv.name}</T>
        <Row gap={4}>
          <Icon name="star" size={15} color={c.star} />
          <T v="caption" color={c.muted} numberOfLines={2} style={{ flexShrink: 1 }}>{dv.rating?.toFixed(1) ?? 'Nuevo'} · {dv.trips} viajes{v ? ` · ${v.make} ${v.model} ${v.color}` : ''}</T>
        </Row>
      </View>
    </Row>
  );
}

function Ended({ status, onRetry }: { status: TripStatus; onRetry: () => void }) {
  useTheme();
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
      {canRetry ? <BigButton title="Pedir otro faxi" onPress={onRetry} /> : null}
      <Button title="Volver al inicio" variant={canRetry ? 'outline' : 'filled'} onPress={() => router.replace('/')} />
    </>
  );
}
