import React from 'react';
import { Platform, View } from 'react-native';
import { PROVIDER_DEFAULT, PROVIDER_GOOGLE, type Region } from 'react-native-maps';
import type { LatLng } from '@faxi/core';
import { Icon } from './components';
import { c } from './tokens';

export const SD_CENTER: LatLng = { lat: 18.4719, lng: -69.9406 }; // Piantini
// Android: Google Maps (requiere GOOGLE_MAPS_ANDROID_KEY). iOS: Apple Maps (sin clave ni costo).
export const mapProvider = Platform.OS === 'android' ? PROVIDER_GOOGLE : PROVIDER_DEFAULT;
export const region = (p: LatLng, delta = 0.02): Region => ({ latitude: p.lat, longitude: p.lng, latitudeDelta: delta, longitudeDelta: delta });
export const coord = (p: LatLng) => ({ latitude: p.lat, longitude: p.lng });

export const OriginPin = () => (
  <View style={{ width: 20, height: 20, borderRadius: 10, borderWidth: 5, borderColor: c.ink, backgroundColor: c.white }} />
);
export const DestPin = () => (
  <View style={{ width: 20, height: 20, borderRadius: 4, backgroundColor: c.primary, borderWidth: 3, borderColor: c.white }} />
);
export const CarPin = () => (
  <View style={{ width: 38, height: 38, borderRadius: 19, backgroundColor: c.ink, borderWidth: 3, borderColor: c.white, alignItems: 'center', justifyContent: 'center' }}>
    <Icon name="local-taxi" size={18} color={c.white} />
  </View>
);

export const MAP_PADDING = { top: 80, right: 48, bottom: 360, left: 48 };
