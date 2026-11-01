import React, { useState } from 'react';
import { Alert, Linking, View } from 'react-native';
import { router } from 'expo-router';
import { auth } from '@faxi/core';
import { AppearancePicker, Avatar, Banner, Header, Row, Screen, SettingsGroup, SettingsRow, T, useSession, useTheme } from '@faxi/ui';
import { cfg } from '../src/faxi';

/** Ajustes: apariencia (solo en este teléfono), cuenta, ayuda y legal. */
export default function Account() {
  useTheme();
  const { me } = useSession();
  const [err, setErr] = useState<string | null>(null);

  function confirmDelete() {
    Alert.alert('Eliminar tu cuenta', 'Se borrarán tus datos personales y no podrás recuperar la cuenta. Tu historial de viajes se conserva de forma anónima por obligaciones legales.', [
      { text: 'Cancelar', style: 'cancel' },
      { text: 'Eliminar', style: 'destructive', onPress: async () => {
        try { await auth.deleteAccount(); } catch (e: any) { setErr(e.message); }
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
          <T v="caption" numberOfLines={1}>{me?.phone}</T>
        </View>
      </Row>
      {err ? <Banner text={err} /> : null}

      <SettingsGroup title="Apariencia">
        <AppearancePicker />
      </SettingsGroup>

      <SettingsGroup title="Cuenta">
        <SettingsRow title="Forma de pago" value="Efectivo" />
        <SettingsRow title="Avisos del viaje" value="En los ajustes del teléfono" onPress={() => Linking.openSettings()} />
        <SettingsRow title="Idioma" value="Español" />
        <SettingsRow title="Tus viajes" onPress={() => router.push('/history')} />
      </SettingsGroup>

      <SettingsGroup title="Ayuda">
        {cfg.supportWhatsApp ? (
          <SettingsRow title="Soporte por WhatsApp" onPress={() => Linking.openURL(`https://wa.me/${cfg.supportWhatsApp}`)} />
        ) : null}
        <SettingsRow title="Reportar un problema" onPress={() => router.push('/support')} />
        <SettingsRow title="Términos y condiciones" onPress={() => Linking.openURL(cfg.termsUrl)} />
        <SettingsRow title="Política de privacidad" onPress={() => Linking.openURL(cfg.privacyUrl)} />
      </SettingsGroup>

      <SettingsGroup title="Sesión">
        <SettingsRow title="Cerrar sesión" onPress={() => auth.signOut()} />
        <SettingsRow title="Eliminar mi cuenta" danger onPress={confirmDelete} />
      </SettingsGroup>
    </Screen>
  );
}
