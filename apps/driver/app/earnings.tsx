import React, { useEffect, useState } from 'react';
import { FlatList, View } from 'react-native';
import { router } from 'expo-router';
import { driver, fmtDate, rd, type CommissionStatus, type Trip } from '@faxi/core';
import { Banner, Card, Chip, Header, Row, Screen, T, c, f } from '@faxi/ui';

type Range = 'today' | 'week';
const since = (r: Range) => { const d = new Date(); d.setHours(0, 0, 0, 0); if (r === 'week') d.setDate(d.getDate() - 6); return d.toISOString(); };

export default function Earnings() {
  const [range, setRange] = useState<Range>('today');
  const [rows, setRows] = useState<Trip[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [debt, setDebt] = useState<CommissionStatus | null>(null);

  useEffect(() => { setRows(null); driver.earnings(since(range)).then(setRows).catch((e) => setErr(e.message)); }, [range]);
  useEffect(() => { driver.commission().then(setDebt).catch((e) => setErr(e.message)); }, []);

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
      {debt ? (
        <Card>
          <T v="caption">Comisión por pagar a faxi</T>
          <T style={{ fontFamily: f.black, fontSize: 28, letterSpacing: -1 }} color={debt.blocked ? c.error : c.ink}>{rd(Math.max(debt.owed, 0))}</T>
          <T v="caption">Paga cada {debt.pay_day} la comisión de tus viajes en efectivo. Si debes más de {rd(debt.limit)}, no podrás conectarte hasta pagar.</T>
          {debt.pay_info ? <T v="label">Dónde pagar: {debt.pay_info}</T> : null}
          {debt.last_payment_at ? <T v="caption">Último pago: {rd(debt.last_payment_amount)} · {fmtDate(debt.last_payment_at)}</T> : null}
          {debt.blocked ? <Banner text={`Debes más de ${rd(debt.limit)}. Paga tu comisión para volver a conectarte.`} /> : null}
        </Card>
      ) : null}
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
