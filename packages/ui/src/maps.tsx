import React, { forwardRef, useEffect, useState } from 'react';
import { Platform, View } from 'react-native';
import MapView, { PROVIDER_DEFAULT, PROVIDER_GOOGLE, Polyline, type MapViewProps, type Region } from 'react-native-maps';
import type { LatLng } from '@faxi/core';
import { Banner, Icon } from './components';
import { useTheme } from './theme';
import { MAP_STYLE } from './mapStyle';

export const SD_CENTER: LatLng = { lat: 18.4719, lng: -69.9406 }; // Piantini
// Android: Google Maps (requiere GOOGLE_MAPS_ANDROID_KEY). iOS: Apple Maps (sin clave ni costo).
export const mapProvider = Platform.OS === 'android' ? PROVIDER_GOOGLE : PROVIDER_DEFAULT;
export const region = (p: LatLng, delta = 0.02): Region => ({ latitude: p.lat, longitude: p.lng, latitudeDelta: delta, longitudeDelta: delta });
export const coord = (p: LatLng) => ({ latitude: p.lat, longitude: p.lng });

// Los pines no cambian con el tema: se leen igual sobre el mapa oscuro y el claro.
export const OriginPin = () => (
  <View style={{ width: 30, height: 30, borderRadius: 15, backgroundColor: 'rgba(5,224,114,0.22)', alignItems: 'center', justifyContent: 'center' }}>
    <View style={{ width: 16, height: 16, borderRadius: 8, backgroundColor: '#05E072', borderWidth: 3, borderColor: '#0E1411' }} />
  </View>
);
export const DestPin = () => (
  <View style={{ width: 22, height: 22, borderRadius: 7, backgroundColor: '#F7FDF6', borderWidth: 3, borderColor: '#0E1411' }} />
);
export const CarPin = () => (
  <View style={{ width: 40, height: 40, borderRadius: 20, backgroundColor: '#05E072', borderWidth: 3, borderColor: '#0E1411', alignItems: 'center', justifyContent: 'center' }}>
    <Icon name="local-taxi" size={20} color="#04170D" />
  </View>
);

/** Ruta en verde neón con brillo: una línea ancha y translúcida debajo y una fina y sólida encima. Úsala dentro de <FaxiMap>. */
export function RouteGlow({ coordinates, dashed }: { coordinates: { latitude: number; longitude: number }[]; dashed?: boolean }) {
  const dash = dashed ? [10, 8] : undefined;
  return (
    <>
      <Polyline coordinates={coordinates} strokeColor="rgba(5,224,114,0.28)" strokeWidth={14} lineCap="round" lineJoin="round" />
      <Polyline coordinates={coordinates} strokeColor="#05E072" strokeWidth={5} lineCap="round" lineJoin="round" lineDashPattern={dash} />
    </>
  );
}

export const MAP_PADDING = { top: 80, right: 48, bottom: 360, left: 48 };

const MAP_LOAD_TIMEOUT_MS = 15000;

/** MapView con el proveedor de faxi. En Android avisa si Google no entrega el mapa (sin internet o clave rechazada). */
export const FaxiMap = forwardRef<MapView, MapViewProps>(function FaxiMap({ onMapLoaded, children, ...props }, ref) {
  const { scheme } = useTheme();
  const [loaded, setLoaded] = useState(false);
  const [late, setLate] = useState(false);
  useEffect(() => {
    if (Platform.OS !== 'android' || loaded) return;
    const h = setTimeout(() => setLate(true), MAP_LOAD_TIMEOUT_MS);
    return () => clearTimeout(h);
  }, [loaded]);
  return (
    <>
      <MapView ref={ref} provider={mapProvider} customMapStyle={MAP_STYLE[scheme] as any} userInterfaceStyle={scheme} {...props} onMapLoaded={(e) => { setLoaded(true); onMapLoaded?.(e); }}>
        {children}
      </MapView>
      {late && !loaded ? (
        <View pointerEvents="box-none" style={{ position: 'absolute', top: '30%', left: 16, right: 16 }}>
          <Banner tone="warn" text={__DEV__
            ? 'El mapa no cargó. Si hay internet, Google está rechazando la clave GOOGLE_MAPS_ANDROID_KEY (ver docs/MAPA_ANDROID.md).'
            : 'No pudimos cargar el mapa. Revisa tu conexión a internet.'} />
        </View>
      ) : null}
    </>
  );
});
