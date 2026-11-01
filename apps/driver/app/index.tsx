import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Linking, StyleSheet, Vibration, View } from 'react-native';
import MapView from 'react-native-maps';
import * as Haptics from 'expo-haptics';
import { router, useFocusEffect } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { driver, km, mins, rd, watchDriverRequests, type CommissionStatus, type PendingRequest } from '@faxi/core';
import {
  Banner, BigButton, Button, CountdownPill, HudChip, Icon, IconButton, OnlineToggle, Row, Sheet, StatusScrim, T, c, f, region, SD_CENTER, useSession, useTheme, FaxiMap,
} from '@faxi/ui';
import { useDriver } from '../src/driverCtx';
import { currentPos, ensureLocationPermission, startTracking, stopTracking } from '../src/tracking';

const startOfToday = () => { const d = new Date(); d.setHours(0, 0, 0, 0); return d.toISOString(); };

export default function Home() {
  useTheme();
  const { me } = useSession();
  const { profile, refresh } = useDriver();
  const map = useRef<MapView>(null);
  const [online, setOnline] = useState(profile?.availability !== 'OFFLINE');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [warn, setWarn] = useState<string | null>(null);
  const [offer, setOffer] = useState<PendingRequest | null>(null);
  const [today, setToday] = useState({ total: 0, count: 0 });
  const [debt, setDebt] = useState<CommissionStatus | null>(null);
  const seen = useRef(new Set<string>());

  useFocusEffect(useCallback(() => {
    driver.activeTrip().then((t) => { if (t) router.replace({ pathname: '/trip', params: { id: t.id } }); }).catch(() => {});
    driver.earnings(startOfToday()).then((rows) => setToday({ total: rows.reduce((s, r) => s + (r.driver_earnings ?? 0), 0), count: rows.length })).catch(() => {});
    driver.commission().then(setDebt).catch(() => {});
  }, []));

  // El servidor puede desconectarlo (p. ej. al pasar el límite de comisión): seguir su estado
  useEffect(() => {
    if (profile?.availability === 'OFFLINE' && online) { setOnline(false); setOffer(null); stopTracking().catch(() => {}); }
  }, [profile?.availability]);

  useEffect(() => {
    currentPos().then((p) => map.current?.animateToRegion(region(p, 0.015), 500)).catch(() => {});
    if (online) startTracking().catch(() => {}); // la app se reabrió estando conectado
  }, []);

  const poll = useCallback(async () => {
    try {
      const list = await driver.pending();
      const next = list.find((r) => new Date(r.expires_at).getTime() > Date.now());
      setOffer((cur) => (cur && list.some((r) => r.request_id === cur.request_id) ? cur : next ?? null));
      if (next && !seen.current.has(next.request_id)) {
        seen.current.add(next.request_id);
        Vibration.vibrate([0, 400, 200, 400]);
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      }
    } catch (e: any) { setErr(e.message); }
  }, []);

  // Mientras está conectado: Realtime + sondeo de respaldo cada 8 s
  useEffect(() => {
    if (!online || !me) return;
    poll();
    const off = watchDriverRequests(me.id, poll);
    const iv = setInterval(poll, 8000);
    return () => { off(); clearInterval(iv); };
  }, [online, me?.id, poll]);

  async function goOnline() {
    setBusy(true); setErr(null); setWarn(null);
    try {
      const perm = await ensureLocationPermission();
      if (perm === 'declined') return;
      if (perm === 'denied') { setErr('Activa la ubicación para recibir viajes.'); return; }
      const pos = await currentPos();
      await driver.setOnline(true, pos);
      try { await startTracking(); } catch { /* sin permiso en segundo plano */ }
      if (perm === 'foreground') setWarn('Sin ubicación "Siempre": mantén la app abierta para seguir recibiendo viajes.');
      setOnline(true);
      map.current?.animateToRegion(region(pos, 0.015), 500);
      refresh();
    } catch (e: any) { setErr(e.message); } finally { setBusy(false); }
  }

  async function goOffline() {
    setBusy(true); setErr(null);
    try { await driver.setOnline(false); await stopTracking(); setOnline(false); setOffer(null); refresh(); }
    catch (e: any) { setErr(e.message); } finally { setBusy(false); }
  }

  async function accept() {
    if (!offer) return;
    setBusy(true); setErr(null);
    try { const t = await driver.accept(offer.request_id); setOffer(null); router.replace({ pathname: '/trip', params: { id: t.id } }); }
    catch (e: any) { setErr(e.message); setOffer(null); poll(); } finally { setBusy(false); }
  }

  async function reject() {
    if (!offer) return;
    const id = offer.request_id;
    setOffer(null);
    driver.reject(id).catch(() => {}).finally(poll);
  }

  return (
    <View style={{ flex: 1, backgroundColor: c.bg }}>
      <FaxiMap ref={map} style={StyleSheet.absoluteFill} initialRegion={region(SD_CENTER, 0.05)} showsUserLocation showsMyLocationButton={false} toolbarEnabled={false} />
      <StatusScrim />
      <SafeAreaView edges={['top']} style={{ position: 'absolute', top: 8, left: 16, right: 16, gap: 10 }}>
        <Row style={{ justifyContent: 'space-between' }}>
          <IconButton icon="settings" label="Ajustes" onPress={() => router.push('/account')} />
          <HudChip dot={online} label={`Hoy ${rd(today.total)}`} onPress={() => router.push('/earnings')} accessibilityLabel={`Ganancias de hoy ${rd(today.total)}. Toca para ver más`} />
        </Row>
        {warn ? <Banner tone="warn" text={warn} actionLabel="Ajustes" onAction={() => Linking.openSettings()} /> : null}
      </SafeAreaView>

      <Sheet>
        {offer ? <Offer r={offer} busy={busy} onAccept={accept} onReject={reject} onExpire={() => { setOffer(null); poll(); }} /> : (
          <>
            <OnlineToggle online={online} loading={busy} onPress={online ? goOffline : goOnline} />
            <T v="caption" center>{online ? 'Buscando viajes cerca de ti… Te avisaremos con sonido y vibración.' : `${today.count} viaje(s) hoy. Conéctate para recibir solicitudes.`}</T>
            {debt?.blocked && !online ? (
              <Banner text={`Debes ${rd(debt.owed)} de comisión. Paga para volver a conectarte.`} actionLabel="Ver" onAction={() => router.push('/earnings')} />
            ) : null}
            {err ? <Banner text={err} /> : null}
          </>
        )}
      </Sheet>
    </View>
  );
}

function Offer({ r, busy, onAccept, onReject, onExpire }: { r: PendingRequest; busy: boolean; onAccept: () => void; onReject: () => void; onExpire: () => void }) {
  useTheme();
  const left = () => Math.max(0, Math.round((new Date(r.expires_at).getTime() - Date.now()) / 1000));
  const [secs, setSecs] = useState(left());
  useEffect(() => {
    const iv = setInterval(() => { const s = left(); setSecs(s); if (s <= 0) { clearInterval(iv); onExpire(); } }, 500);
    return () => clearInterval(iv);
  }, [r.request_id]);

  return (
    <>
      <Row style={{ justifyContent: 'space-between' }}>
        <T v="micro">Nueva solicitud · {r.trip_code}</T>
        <CountdownPill seconds={secs} urgent={secs <= 10} label={`Te quedan ${secs} segundos para aceptar`} />
      </Row>
      <View>
        <T v="price" fit>{rd(r.estimated_earnings)}</T>
        <T v="caption">Tu ganancia estimada · tarifa {rd(r.estimated_fare)} en efectivo</T>
      </View>
      <View style={{ gap: 8 }}>
        <Row gap={10}><View style={{ width: 12, height: 12, borderRadius: 6, borderWidth: 3.5, borderColor: c.ink }} /><T v="label" style={{ flex: 1 }} numberOfLines={1}>{r.origin_address}</T><T v="caption">a {km(r.distance_to_pickup_km)}</T></Row>
        <Row gap={10}><View style={{ width: 12, height: 12, borderRadius: 3, backgroundColor: c.neon }} /><T v="label" style={{ flex: 1 }} numberOfLines={1}>{r.dest_address}</T><T v="caption">{km(r.distance_km)} · {mins(r.duration_min)}</T></Row>
      </View>
      <Row gap={6}><Icon name="person" size={18} color={c.ink2} /><T v="caption">{r.passenger_name} · ★ {r.passenger_rating?.toFixed(1) ?? 'Nuevo'}</T></Row>
      <Row gap={10}>
        <Button title="Rechazar" variant="outline" style={{ flex: 1 }} onPress={onReject} disabled={busy} />
        <BigButton title="Aceptar" icon="check" style={{ flex: 2 }} onPress={onAccept} loading={busy} />
      </Row>
    </>
  );
}
