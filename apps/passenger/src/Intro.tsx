import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, Image, StyleSheet, useWindowDimensions } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import * as SplashScreen from 'expo-splash-screen';

const BG = require('../assets/intro-bg.png');
const LOGO = require('../assets/intro-logo.png');
const LOGO_RATIO = 760 / 305;
// Tamaño del logo en la pantalla nativa (imageWidth 220 en app.config.ts, el logo ocupa 637/1024 del lienzo).
const NATIVE_W = 220 * (637 / 1024);

/**
 * Pantalla de entrada con el degradado de la marca (diseño en docs/marca/faxi-inicio.png).
 * Android solo permite un color liso en la pantalla nativa: esta la continúa con el degradado, agranda el logo
 * y se desvanece cuando la app está lista (`ready`). Generada con scripts/make_splash.py.
 */
export function Intro({ ready }: { ready: boolean }) {
  const { width } = useWindowDimensions();
  const [gone, setGone] = useState(false);
  const grow = useRef(new Animated.Value(0)).current;
  const fade = useRef(new Animated.Value(1)).current;
  const shown = useRef(false);

  function onShown() {
    if (shown.current) return;
    shown.current = true;
    SplashScreen.hideAsync().catch(() => {});
    Animated.timing(grow, { toValue: 1, duration: 450, easing: Easing.out(Easing.cubic), useNativeDriver: true }).start();
  }

  // Si la imagen tarda en avisar, no dejar la pantalla nativa puesta.
  useEffect(() => { const t = setTimeout(onShown, 800); return () => clearTimeout(t); }, []);

  useEffect(() => {
    if (!ready) return;
    const t = setTimeout(() => {
      Animated.timing(fade, { toValue: 0, duration: 300, useNativeDriver: true }).start(() => setGone(true));
    }, 500);
    return () => clearTimeout(t);
  }, [ready]);

  if (gone) return null;
  const big = Math.min(width * 0.62, 320);
  const scale = grow.interpolate({ inputRange: [0, 1], outputRange: [NATIVE_W / big, 1] });
  return (
    <Animated.View pointerEvents={ready ? 'none' : 'auto'} style={[StyleSheet.absoluteFill, { opacity: fade, alignItems: 'center', justifyContent: 'center' }]}>
      <StatusBar style="light" />
      <Image source={BG} style={StyleSheet.absoluteFill} resizeMode="stretch" onLoadEnd={onShown} fadeDuration={0} />
      <Animated.Image source={LOGO} accessibilityLabel="faxi" fadeDuration={0}
        style={{ width: big, height: big / LOGO_RATIO, transform: [{ scale }] }} />
    </Animated.View>
  );
}
