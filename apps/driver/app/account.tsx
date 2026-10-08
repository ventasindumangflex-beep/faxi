import React, { useState } from 'react';
import { Alert, Linking, View } from 'react-native';
import { router } from 'expo-router';
import { auth, CATEGORY_LABEL, driver } from '@faxi/core';
import { Avatar, Banner, Card, Divider, Header, ListItem, Row, Screen, T, useSession } from '@faxi/ui';
import { useDriver } from '../src/driverCtx';
import { cfg } from '../src/faxi';
import { stopTracking } from '../src/tracking';

export default function Account() {
  const { me } = useSession();
  const { profile } = useDriver();
  const [err, setErr] = useState<string | null>(null);
  const v = profile?.vehicle;

  async function signOut() {
    try { if (profile?.availability === 'ONLINE') await driver.setOnline(false); } catch { /* ignora */ }
    await stopTracking().catch(() => {});
    await auth.signOut();
  }

  function confirmDelete() {
    Alert.alert('Eliminar tu cuenta', 'Se borrarán tus datos personales y documentos. No podrás volver a recibir viajes con esta cuenta.', [
      { text: 'Cancelar', style: 'cancel' },
      { text: 'Eliminar', style: 'destructive', onPress: async () => {
        try { await stopTracking().catch(() => {}); await auth.deleteAccount(); } catch (e: any) { setErr(e.message); }
      } },
    ]);
  }

  return (
    <Screen scroll>
      <Header title="Tu cuenta" onBack={() => router.back()} />
      <Row>
        <Avatar name={me?.full_name} size={60} />
        <View style={{ flex: 1 }}>
          <T v="h2">{me?.full_name}</T>
          <T v="caption">{me?.phone} · ★ {profile?.rating_avg?.toFixed(1) ?? 'Nuevo'} · {profile?.trips_count ?? 0} viajes</T>
        </View>
      </Row>
      {v ? (
        <Card>
          <T v="micro">Vehículo</T>
          <T v="label">{v.make} {v.model} {v.year} · {v.color}</T>
          <T v="caption">Placa {v.plate} · {CATEGORY_LABEL[v.category]}</T>
        </Card>
      ) : null}
      {err ? <Banner text={err} /> : null}
      <View>
        <ListItem icon="account-balance-wallet" title="Ganancias" onPress={() => router.push('/earnings')} />
        <ListItem icon="support-agent" title="Reportar un problema" onPress={() => router.push('/support')} />
        {cfg.supportWhatsApp ? <ListItem icon="chat" title="Soporte por WhatsApp" onPress={() => Linking.openURL(`https://wa.me/${cfg.supportWhatsApp}`)} /> : null}
        <ListItem icon="description" title="Términos para conductores" onPress={() => Linking.openURL(cfg.termsUrl)} />
        <ListItem icon="privacy-tip" title="Política de privacidad" onPress={() => Linking.openURL(cfg.privacyUrl)} />
      </View>
      <Divider />
      <View>
        <ListItem icon="logout" title="Cerrar sesión" onPress={signOut} right={<View />} />
        <ListItem icon="delete-forever" title="Eliminar cuenta" danger onPress={confirmDelete} right={<View />} />
      </View>
    </Screen>
  );
}
