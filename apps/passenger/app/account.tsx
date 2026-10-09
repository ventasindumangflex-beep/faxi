import React, { useState } from 'react';
import { Alert, Linking, View } from 'react-native';
import { router } from 'expo-router';
import { auth } from '@faxi/core';
import { Avatar, Banner, Divider, Header, ListItem, Row, Screen, T, useSession } from '@faxi/ui';
import { cfg } from '../src/faxi';

export default function Account() {
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
      <Header title="Tu cuenta" onBack={() => router.back()} />
      <Row>
        <Avatar name={me?.full_name} size={60} />
        <View style={{ flex: 1 }}>
          <T v="h2">{me?.full_name}</T>
          <T v="caption">{me?.phone}</T>
        </View>
      </Row>
      {err ? <Banner text={err} /> : null}
      <View>
        <ListItem icon="receipt-long" title="Tus viajes" onPress={() => router.push('/history')} />
        <ListItem icon="support-agent" title="Reportar un problema" onPress={() => router.push('/support')} />
        {cfg.supportWhatsApp ? (
          <ListItem icon="chat" title="Ayuda por WhatsApp" onPress={() => Linking.openURL(`https://wa.me/${cfg.supportWhatsApp}`)} />
        ) : null}
        <ListItem icon="description" title="Términos y condiciones" onPress={() => Linking.openURL(cfg.termsUrl)} />
        <ListItem icon="privacy-tip" title="Política de privacidad" onPress={() => Linking.openURL(cfg.privacyUrl)} />
      </View>
      <Divider />
      <View>
        <ListItem icon="logout" title="Cerrar sesión" onPress={() => auth.signOut()} right={<View />} />
        <ListItem icon="delete-forever" title="Eliminar cuenta" danger onPress={confirmDelete} right={<View />} />
      </View>
    </Screen>
  );
}
