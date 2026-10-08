import React, { useEffect, useState } from 'react';
import { FlatList, View } from 'react-native';
import { router } from 'expo-router';
import { driver, fmtDate, rd, type Trip } from '@faxi/core';
import { Banner, Card, Chip, Header, Row, Screen, T, c, f } from '@faxi/ui';

type Range = 'today' | 'week';
const since = (r: Range) => { const d = new Date(); d.setHours(0, 0, 0, 0); if (r === 'week') d.setDate(d.getDate() - 6); return d.toISOString(); };

export default function Earnings() {
  const [range, setRange] = useState<Range>('today');
  const [rows, setRows] = useState<Trip[] | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => { setRows(null); driver.earnings(since(range)).then(setRows).catch((e) => setErr(e.message)); }, [range]);

  const total = rows?.reduce((s, t) => s + (t.driver_earnings ?? 0), 0) ?? 0;
  const gross = rows?.reduce((s, t) => s + (t.final_fare ?? 0), 0) ?? 0;
  const commission = rows?.reduce((s, t) => s + (t.faxi_commission ?? 0), 0) ?? 0;

  return (
    <Screen>
      <Header title="Ganancias" onBack={() => router.back()} />
      <Row gap={8}>
        <Chip label="Hoy" selected={range === 'today'} onPress={() => setRange('today')} />
        <Chip label="Últimos 7 días" selected={range === 'week'} onPress={() => setRange('week')} />
      </Row>
      <Card>
        <T v="caption">Tu ganancia</T>
        <T style={{ fontFamily: f.black, fontSize: 40, letterSpacing: -1.4 }}>{rd(total)}</T>
        <T v="caption">{rows?.length ?? 0} viajes · cobrado {rd(gross)} · comisión faxi {rd(commission)}</T>
      </Card>
      <T v="caption">La comisión de los viajes en efectivo se liquida con faxi según tu acuerdo de conductor.</T>
      {err ? <Banner text={err} /> : null}
      <FlatList
        data={rows ?? []}
        keyExtractor={(t) => t.id}
        contentContainerStyle={{ paddingBottom: 24 }}
        ListEmptyComponent={rows ? <T v="caption">Sin viajes en este período.</T> : null}
        renderItem={({ item: t }) => (
          <Row style={{ paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: c.outlineSoft }}>
            <View style={{ flex: 1 }}>
              <T v="label" numberOfLines={1}>{t.dest_address}</T>
              <T v="caption">{fmtDate(t.completed_at)} · {t.code}</T>
            </View>
            <T v="label">{rd(t.driver_earnings)}</T>
          </Row>
        )}
      />
    </Screen>
  );
}
