import React, { useState } from 'react';
import { Linking, RefreshControl, ScrollView, View } from 'react-native';
import { router } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { auth, DOC_LABEL } from '@faxi/core';
import { Banner, Brand, Button, Card, Icon, Row, StatusPill, T, c } from '@faxi/ui';
import { useDriver } from '../src/driverCtx';
import { cfg } from '../src/faxi';

const TONE = { APPROVED: 'ok', PENDING: 'warn', REJECTED: 'error', SUSPENDED: 'error' } as const;
const LABEL = { APPROVED: 'Aprobado', PENDING: 'En revisión', REJECTED: 'Rechazado', SUSPENDED: 'Suspendido' } as const;

export default function Pending() {
  const { profile, docs, refresh } = useDriver();
  const [refreshing, setRefreshing] = useState(false);
  if (!profile) return null;
  const v = profile.vehicle;
  const suspended = profile.status === 'SUSPENDED';
  const rejected = profile.status === 'REJECTED' || v?.status === 'REJECTED';
  const vdocs = docs.vehicle.filter((d: any) => d.vehicle_id === profile.current_vehicle_id);
  const latest = [...docs.driver, ...vdocs].filter((d, i, all) => all.findIndex((x) => x.type === d.type) === i);

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.surface }}>
      <ScrollView contentContainerStyle={{ padding: 20, gap: 16 }}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={async () => { setRefreshing(true); await refresh(); setRefreshing(false); }} />}>
        <Brand suffix="Conductor" />
        <T v="display">{suspended ? 'Cuenta suspendida' : rejected ? 'Necesitamos correcciones' : 'Estamos revisando tu solicitud'}</T>
        <T v="body" color={c.ink2}>
          {suspended ? 'No puedes recibir viajes por ahora. Escríbenos para más información.'
            : rejected ? 'Revisa los motivos y corrige tus datos o documentos.'
            : 'Suele tardar 1–2 días hábiles. Te avisaremos con una notificación.'}
        </T>
        {profile.rejection_reason ? <Banner text={profile.rejection_reason} /> : null}
        <Card>
          <Row style={{ justifyContent: 'space-between' }}><T v="label">Cuenta</T><StatusPill label={LABEL[profile.status]} tone={TONE[profile.status]} /></Row>
          {v ? (
            <Row style={{ justifyContent: 'space-between' }}>
              <T v="label" style={{ flex: 1 }}>{v.make} {v.model} · {v.plate}</T>
              <StatusPill label={LABEL[v.status]} tone={TONE[v.status]} />
            </Row>
          ) : null}
          {v?.rejection_reason ? <T v="caption" color={c.error}>{v.rejection_reason}</T> : null}
        </Card>
        <Card>
          <T v="micro">Documentos</T>
          {latest.map((d) => (
            <Row key={d.id}>
              <Icon name="description" color={c.ink2} />
              <View style={{ flex: 1 }}>
                <T v="label">{DOC_LABEL[d.type]}</T>
                {d.status === 'REJECTED' && d.rejection_reason ? <T v="caption" color={c.error}>{d.rejection_reason}</T> : null}
              </View>
              <StatusPill label={LABEL[d.status]} tone={TONE[d.status]} />
            </Row>
          ))}
        </Card>
        {rejected && !suspended ? <Button title="Corregir mis datos" onPress={() => router.push('/onboarding')} /> : null}
        {cfg.supportWhatsApp ? <Button title="Escribir a soporte" icon="chat" variant="tonal" onPress={() => Linking.openURL(`https://wa.me/${cfg.supportWhatsApp}`)} /> : null}
        <Button title="Cerrar sesión" variant="outline" onPress={() => auth.signOut()} />
      </ScrollView>
    </SafeAreaView>
  );
}
