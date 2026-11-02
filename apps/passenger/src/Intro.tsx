import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, Image, InteractionManager, StyleSheet, View, useWindowDimensions } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import * as SplashScreen from 'expo-splash-screen';

const BG = require('../assets/intro-bg.png');
const LOGO = require('../assets/intro-logo.png');
const LOGO_RATIO = 760 / 305;
// Tamaño del logo en la pantalla nativa (imageWidth 220 en app.config.ts, el logo ocupa 637/1024 del lienzo).
const NATIVE_W = 220 * (637 / 1024);
// Mismo color liso que la pantalla nativa (app.config.ts): así no hay salto al quitarla.
const NATIVE_BG = '#029A60';
// El degradado se queda al menos este tiempo a la vista, aunque la app ya esté lista.
const MIN_VISIBLE_MS = 900;

/**
 * Pantalla de entrada con el degradado de la marca (diseño en docs/marca/faxi-inicio.png).
 * Android solo permite un color liso en la pantalla nativa: esta la continúa con el degradado, agranda el logo
 * y se desvanece cuando la app está lista (`ready`). Generada con scripts/make_splash.py.
 */
export function Intro({ ready }: { ready: boolean }) {
  const { width } = useWindowDimensions();
  const [gone, setGone] = useState(false);
  const bg = useRef(new Animated.Value(0)).current;   // el degradado entra suave sobre el color liso
  const grow = useRef(new Animated.Value(0)).current;
  const fade = useRef(new Animated.Value(1)).current;
  const shownAt = useRef<number | null>(null);
  const started = useRef(false);

  function onShown() {
    if (started.current) return;
    started.current = true;
    // Dos cuadros de espera: el degradado ya está pintado cuando se quita la pantalla nativa (sin destello).
    requestAnimationFrame(() => requestAnimationFrame(() => {
      shownAt.current = Date.now();
      SplashScreen.hideAsync().catch(() => {});
      Animated.parallel([
        Animated.timing(bg, { toValue: 1, duration: 350, easing: Easing.out(Easing.quad), useNativeDriver: true }),
        Animated.timing(grow, { toValue: 1, duration: 700, delay: 80, easing: Easing.out(Easing.cubic), useNativeDriver: true }),
      ]).start();
    }));
  }

  // Si la imagen tarda en avisar, no dejar la pantalla nativa puesta.
  useEffect(() => { const t = setTimeout(onShown, 800); return () => clearTimeout(t); }, []);

  useEffect(() => {
    if (!ready) return;
    let alive = true;
    const left = Math.max(0, MIN_VISIBLE_MS - (shownAt.current ? Date.now() - shownAt.current : 0));
    const t = setTimeout(() => {
      // Se desvanece cuando la primera pantalla ya terminó de dibujarse, no en medio del trabajo.
      InteractionManager.runAfterInteractions(() => {
        if (!alive) return;
        Animated.timing(fade, { toValue: 0, duration: 450, easing: Easing.inOut(Easing.quad), useNativeDriver: true }).start(() => setGone(true));
      });
    }, left);
    return () => { alive = false; clearTimeout(t); };
  }, [ready]);

  if (gone) return null;
  const big = Math.min(width * 0.62, 320);
  const scale = grow.interpolate({ inputRange: [0, 1], outputRange: [NATIVE_W / big, 1] });
  return (
    <Animated.View pointerEvents={ready ? 'none' : 'auto'} style={[StyleSheet.absoluteFill, { opacity: fade, alignItems: 'center', justifyContent: 'center' }]}>
      <StatusBar style="light" />
      <View style={[StyleSheet.absoluteFill, { backgroundColor: NATIVE_BG }]} />
      <Animated.Image source={BG} style={[StyleSheet.absoluteFill, { opacity: bg }]} resizeMode="cover" onLoadEnd={onShown} fadeDuration={0} />
      <Animated.Image source={LOGO} accessibilityLabel="faxi" fadeDuration={0}
        style={{ width: big, height: big / LOGO_RATIO, transform: [{ scale }] }} />
    </Animated.View>
  );
}
