import React, { useEffect, useState } from 'react';
import { FlatList, RefreshControl, View } from 'react-native';
import { router } from 'expo-router';
import { fmtDate, passenger, rd, STATUS_LABEL, type Trip } from '@faxi/core';
import { Banner, Card, Header, Row, Screen, StatusPill, T, c } from '@faxi/ui';

export default function History() {
  const [rows, setRows] = useState<Trip[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  async function load() {
    try { setRows(await passenger.history(50)); setErr(null); } catch (e: any) { setErr(e.message); }
  }
  useEffect(() => { load(); }, []);

  return (
    <Screen>
      <Header title="Tus viajes" onBack={() => router.back()} />
      {err ? <Banner text={err} /> : null}
      <FlatList
        data={rows ?? []}
        keyExtractor={(t) => t.id}
        contentContainerStyle={{ gap: 10, paddingBottom: 24 }}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={async () => { setRefreshing(true); await load(); setRefreshing(false); }} />}
        ListEmptyComponent={rows ? <T v="caption">Aún no tienes viajes.</T> : null}
        renderItem={({ item: t }) => (
          <Card>
            <Row style={{ justifyContent: 'space-between' }}>
              <T v="caption">{fmtDate(t.requested_at)} · {t.code}</T>
              <StatusPill label={STATUS_LABEL[t.status]} tone={t.status === 'COMPLETED' ? 'ok' : t.status.startsWith('CANCELLED') || t.status === 'NO_DRIVER' ? 'error' : 'neutral'} />
            </Row>
            <View style={{ gap: 2 }}>
              <T v="caption" numberOfLines={1}>De {t.origin_address}</T>
              <T v="label" numberOfLines={1}>{t.dest_address}</T>
            </View>
            <T v="h2" color={t.status === 'COMPLETED' ? c.ink : c.muted}>{rd(t.final_fare ?? t.estimated_fare)}</T>
          </Card>
        )}
      />
    </Screen>
  );
}
