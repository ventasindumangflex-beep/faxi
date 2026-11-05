import React, { useState } from 'react';
import { Alert, Linking, View } from 'react-native';
import { router } from 'expo-router';
import { auth, CATEGORY_LABEL, driver } from '@faxi/core';
import { AppearancePicker, describePushStatus, registerForPush, Avatar, Banner, Card, Header, Row, Screen, SettingsGroup, SettingsRow, T, useSession, useTheme } from '@faxi/ui';
import { useDriver } from '../src/driverCtx';
import { cfg } from '../src/faxi';
import { stopTracking } from '../src/tracking';

/** Ajustes del conductor: apariencia (solo en este teléfono), cuenta, ayuda y legal. */
export default function Account() {
  useTheme();
  const { me } = useSession();
  const { profile } = useDriver();
  const [err, setErr] = useState<string | null>(null);
  const [pushMsg, setPushMsg] = useState(describePushStatus());
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
      <Header title="Ajustes" onBack={() => router.back()} />
      <Row>
        <Avatar name={me?.full_name} size={60} />
        <View style={{ flex: 1, minWidth: 0 }}>
          <T v="h2" numberOfLines={1}>{me?.full_name}</T>
          <T v="caption" numberOfLines={2}>{me?.phone} · ★ {profile?.rating_avg?.toFixed(1) ?? 'Nuevo'} · {profile?.trips_count ?? 0} viajes</T>
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

      <SettingsGroup title="Apariencia">
        <AppearancePicker />
      </SettingsGroup>

      <SettingsGroup title="Cuenta">
        <SettingsRow title="Ganancias" onPress={() => router.push('/earnings')} />
        <SettingsRow title="Cobro" value="Efectivo" />
        <SettingsRow title="Avisos de viajes" value="Ajustes del teléfono" onPress={() => Linking.openSettings()} />
        <SettingsRow title="Probar avisos" value={pushMsg} onPress={async () => { setPushMsg('Probando…'); await registerForPush(); setPushMsg(describePushStatus()); }} />
        <SettingsRow title="Idioma" value="Español" />
      </SettingsGroup>

      <SettingsGroup title="Ayuda">
        {cfg.supportWhatsApp ? <SettingsRow title="Soporte por WhatsApp" onPress={() => Linking.openURL(`https://wa.me/${cfg.supportWhatsApp}`)} /> : null}
        <SettingsRow title="Reportar un problema" onPress={() => router.push('/support')} />
        <SettingsRow title="Términos para conductores" onPress={() => Linking.openURL(cfg.termsUrl)} />
        <SettingsRow title="Política de privacidad" onPress={() => Linking.openURL(cfg.privacyUrl)} />
      </SettingsGroup>

      <SettingsGroup title="Sesión">
        <SettingsRow title="Cerrar sesión" onPress={signOut} />
        <SettingsRow title="Eliminar mi cuenta" danger onPress={confirmDelete} />
      </SettingsGroup>
    </Screen>
  );
}
