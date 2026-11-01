import React, { useEffect, useMemo, useRef } from 'react';
import { ActivityIndicator, Animated, Easing, Pressable, StyleProp, Switch, View, ViewStyle, useWindowDimensions } from 'react-native';
import type { Category } from '@faxi/core';
import { Icon, IconName, Row, T } from './components';
import { c, f, glow, r } from './tokens';
import { type Mode, MODE_LABEL, useTheme } from './theme';

// ───────── Carros: siluetas propias hechas con vistas (sin librerías de dibujo) ─────────
interface CarSpec { color: string; w: number; bodyH: number; cabinW: number; cabinH: number; boxy?: boolean }
const CAR: Record<Category, CarSpec> = {
  ECONOMICO: { color: '#E6EBE4', w: 60, bodyH: 17, cabinW: 32, cabinH: 13 },
  CONFORT: { color: '#05E072', w: 60, bodyH: 17, cabinW: 32, cabinH: 13 },
  PREMIUM: { color: '#F7FDF6', w: 66, bodyH: 17, cabinW: 37, cabinH: 13 },
  SUV: { color: '#9DB0A4', w: 70, bodyH: 20, cabinW: 48, cabinH: 17 },
  VAN: { color: '#D6EDE1', w: 76, bodyH: 20, cabinW: 62, cabinH: 22, boxy: true },
};

/** Silueta lateral de cada categoría (84×48). Es decorativa: el nombre y el precio ya van en el texto. */
export function CarArt({ category, style }: { category: Category; style?: StyleProp<ViewStyle> }) {
  const { scheme } = useTheme();
  const k = CAR[category] ?? CAR.ECONOMICO;
  const edge = 'rgba(0,0,0,0.22)';
  const left = (84 - k.w) / 2;
  const wheel = (x: number) => (
    <View key={x} style={{ position: 'absolute', left: x - 6, bottom: 6, width: 12, height: 12, borderRadius: 6, backgroundColor: '#0E1411', alignItems: 'center', justifyContent: 'center' }}>
      <View style={{ width: 5, height: 5, borderRadius: 3, backgroundColor: '#8A948D' }} />
    </View>
  );
  return (
    <View accessibilityElementsHidden importantForAccessibility="no-hide-descendants" style={[{ width: 84, height: 48 }, style]}>
      <View style={{ position: 'absolute', left: 42 - k.w * 0.45, bottom: 2, width: k.w * 0.9, height: 7, borderRadius: 4, backgroundColor: scheme === 'dark' ? 'rgba(0,0,0,0.55)' : 'rgba(0,0,0,0.16)' }} />
      <View style={{ position: 'absolute', left: 42 - k.cabinW / 2 - (k.boxy ? 0 : 2), bottom: 10 + k.bodyH - 4, width: k.cabinW, height: k.cabinH + 4,
        borderTopLeftRadius: k.boxy ? 8 : 11, borderTopRightRadius: k.boxy ? 6 : 13, backgroundColor: k.color, borderWidth: 1, borderColor: edge }}>
        <View style={{ position: 'absolute', left: 3, right: 3, top: 3, height: k.cabinH - 3, borderTopLeftRadius: 7, borderTopRightRadius: 8, backgroundColor: '#0E1411', opacity: 0.75 }} />
      </View>
      <View style={{ position: 'absolute', left, bottom: 10, width: k.w, height: k.bodyH, borderRadius: 9, backgroundColor: k.color, borderWidth: 1, borderColor: edge }} />
      {wheel(left + k.w * 0.22)}
      {wheel(left + k.w * 0.78)}
    </View>
  );
}

// ───────── Tarjeta de vehículo ─────────
/** Tarjeta de categoría con el precio grande. Seleccionada = invertida con borde neón. El precio y los textos vienen del servidor. */
export function VehicleCard({ category, name, subtitle, price, selected, onPress, accessibilityLabel }: {
  category: Category; name: string; subtitle?: string; price: string; selected?: boolean; onPress?: () => void; accessibilityLabel?: string;
}) {
  const { scheme } = useTheme();
  const fg = selected ? c.cardSelFg : c.ink;
  const sub = selected ? (scheme === 'dark' ? '#5F6A63' : '#B9C4BC') : c.muted;
  return (
    <Pressable onPress={onPress} accessibilityRole="radio" accessibilityState={{ selected: !!selected }}
      accessibilityLabel={accessibilityLabel ?? `${name}, ${price}`}
      style={[{ flexDirection: 'row', alignItems: 'center', gap: 12, minHeight: 72, paddingVertical: 8, paddingLeft: 8, paddingRight: 16, borderRadius: 20, borderWidth: 2,
        backgroundColor: selected ? c.cardSel : c.card, borderColor: selected ? c.neon : 'transparent' }, selected && glow]}>
      <CarArt category={category} />
      <View style={{ flex: 1, minWidth: 0 }}>
        <T color={fg} numberOfLines={2} style={{ fontFamily: f.black, fontSize: 16, lineHeight: 21 }}>{name}</T>
        {subtitle ? <T v="caption" color={sub} numberOfLines={2} style={{ fontSize: 12.5 }}>{subtitle}</T> : null}
      </View>
      <T color={fg} numberOfLines={1} style={{ fontFamily: f.black, fontSize: 22, lineHeight: 28, letterSpacing: -0.7, fontVariant: ['tabular-nums'], flexShrink: 0 }}>{price}</T>
    </Pressable>
  );
}

// ───────── Placa, cuenta regresiva, progreso ─────────
export function Plate({ value }: { value: string }) {
  useTheme();
  return (
    <View accessibilityLabel={`Placa ${value}`} style={{ alignSelf: 'flex-start', paddingHorizontal: 14, paddingVertical: 6, borderRadius: 10, borderWidth: 2, borderColor: c.ink, backgroundColor: '#FFFFFF' }}>
      <T numberOfLines={1} style={{ fontFamily: f.black, fontSize: 20, lineHeight: 26, letterSpacing: 2.5, color: '#181C1A' }}>{value}</T>
    </View>
  );
}

/** Cuenta regresiva en segundos que baja de a uno y se reinicia cuando cambia `from` (p. ej. la hora estimada de llegada). */
export function useCountdown(from: number | null) {
  const [left, setLeft] = React.useState(from ?? 0);
  useEffect(() => {
    setLeft(from ?? 0);
    if (from == null) return;
    const h = setInterval(() => setLeft((s) => Math.max(0, s - 1)), 1000);
    return () => clearInterval(h);
  }, [from]);
  return left;
}

const mmss = (s: number) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;

/** Pastilla verde con la cuenta regresiva (mm:ss). Es solo la cuenta visual: la hora real de llegada la calcula la app con la ubicación del conductor. */
export function CountdownPill({ seconds, label, urgent }: { seconds: number; label?: string; urgent?: boolean }) {
  useTheme();
  const s = Math.max(0, Math.round(seconds));
  const bg = urgent ? c.errorSoft : c.neon, fg = urgent ? c.error : c.onPrimary;
  return (
    <View accessibilityLabel={label ?? `Faltan ${Math.ceil(s / 60)} minutos`} style={{ flexDirection: 'row', alignItems: 'center', gap: 8, minHeight: 40, paddingHorizontal: 16, borderRadius: r.pill, backgroundColor: bg, alignSelf: 'flex-start' }}>
      <Icon name="timer" size={18} color={fg} />
      <T color={fg} style={{ fontFamily: f.black, fontSize: 15, lineHeight: 20, fontVariant: ['tabular-nums'] }}>{mmss(s)}</T>
    </View>
  );
}

/** Barra de progreso del viaje con brillo (0 a 1). */
export function ProgressBar({ value, label }: { value: number; label?: string }) {
  const { reduceMotion } = useTheme();
  const v = Math.min(1, Math.max(0.04, value || 0));
  const w = useRef(new Animated.Value(v)).current;
  useEffect(() => {
    if (reduceMotion) { w.setValue(v); return; }
    Animated.timing(w, { toValue: v, duration: 700, easing: Easing.out(Easing.quad), useNativeDriver: false }).start();
  }, [v, reduceMotion]);
  return (
    <View accessible accessibilityRole="progressbar" accessibilityLabel={label ?? 'Progreso del viaje'} accessibilityValue={{ min: 0, max: 100, now: Math.round(v * 100) }}
      style={{ height: 8, borderRadius: 9, backgroundColor: c.btnBg, overflow: 'hidden' }}>
      <Animated.View style={{ height: '100%', borderRadius: 9, backgroundColor: c.neon, width: w.interpolate({ inputRange: [0, 1], outputRange: ['0%', '100%'] }),
        shadowColor: c.neon, shadowOpacity: 0.9, shadowRadius: 8, shadowOffset: { width: 0, height: 0 } }} />
    </View>
  );
}

// ───────── Radar (buscando conductor) ─────────
export function Radar({ size = 220 }: { size?: number }) {
  const { reduceMotion } = useTheme();
  const rings = useRef([0, 1, 2].map(() => new Animated.Value(0))).current;
  useEffect(() => {
    if (reduceMotion) return;
    const loops: Animated.CompositeAnimation[] = [];
    const timers = rings.map((v, i) => setTimeout(() => {
      const l = Animated.loop(Animated.timing(v, { toValue: 1, duration: 2400, easing: Easing.out(Easing.quad), useNativeDriver: true }));
      loops.push(l); l.start();
    }, i * 800));
    return () => { timers.forEach(clearTimeout); loops.forEach((l) => l.stop()); };
  }, [reduceMotion]);
  return (
    <View accessibilityElementsHidden importantForAccessibility="no-hide-descendants" style={{ width: size, height: size, alignItems: 'center', justifyContent: 'center' }}>
      {rings.map((v, i) => (
        <Animated.View key={i} style={{ position: 'absolute', width: size, height: size, borderRadius: size / 2, borderWidth: 2, borderColor: c.neon,
          opacity: reduceMotion ? 0.35 - i * 0.1 : v.interpolate({ inputRange: [0, 1], outputRange: [0.9, 0] }),
          transform: [{ scale: reduceMotion ? 1 - i * 0.2 : v.interpolate({ inputRange: [0, 1], outputRange: [0.35, 1.2] }) }] }} />
      ))}
      <View style={{ width: 76, height: 76, borderRadius: 38, backgroundColor: c.deep, borderWidth: 2, borderColor: c.neon, alignItems: 'center', justifyContent: 'center',
        shadowColor: c.neon, shadowOpacity: 0.6, shadowRadius: 22, shadowOffset: { width: 0, height: 0 }, elevation: 10 }}>
        <T style={{ fontFamily: f.black, fontSize: 32, lineHeight: 40, color: '#F7FDF6' }}>f</T>
      </View>
    </View>
  );
}

// ───────── Confeti suave (pantalla "Llegaste") ─────────
export function Confetti({ count = 30 }: { count?: number }) {
  const { reduceMotion } = useTheme();
  const { width, height } = useWindowDimensions();
  const pieces = useMemo(() => Array.from({ length: count }, (_, i) => ({
    x: Math.random() * width, color: [c.neon, '#F7FDF6', c.brand, '#E0A100'][i % 4],
    dur: 3200 + Math.random() * 3000, delay: Math.random() * 2200, spin: 360 + Math.random() * 360, v: new Animated.Value(0),
  })), [count, width]);
  useEffect(() => {
    if (reduceMotion) return;
    const loops = pieces.map((p) => {
      const l = Animated.loop(Animated.sequence([
        Animated.delay(p.delay), Animated.timing(p.v, { toValue: 1, duration: p.dur, easing: Easing.linear, useNativeDriver: true }),
      ]));
      l.start(); return l;
    });
    return () => loops.forEach((l) => l.stop());
  }, [pieces, reduceMotion]);
  if (reduceMotion) return null;
  return (
    <View pointerEvents="none" accessibilityElementsHidden importantForAccessibility="no-hide-descendants" style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, overflow: 'hidden' }}>
      {pieces.map((p, i) => (
        <Animated.View key={i} style={{ position: 'absolute', top: -16, left: p.x, width: 8, height: 14, borderRadius: 2, backgroundColor: p.color,
          opacity: p.v.interpolate({ inputRange: [0, 0.05, 0.85, 1], outputRange: [0, 1, 1, 0] }),
          transform: [{ translateY: p.v.interpolate({ inputRange: [0, 1], outputRange: [0, height + 32] }) }, { rotate: p.v.interpolate({ inputRange: [0, 1], outputRange: ['0deg', `${p.spin}deg`] }) }] }} />
      ))}
    </View>
  );
}

// ───────── Acciones y avisos ─────────
/** Botón pastilla de acción rápida (Llamar, Mensaje, Compartir, SOS). 52 px de alto. */
export function ActionPill({ label, icon, onPress, tone = 'normal', disabled }: {
  label: string; icon?: IconName; onPress?: () => void; tone?: 'normal' | 'sos'; disabled?: boolean;
}) {
  useTheme();
  const sos = tone === 'sos';
  const fg = sos ? c.error : c.ink;
  return (
    <Pressable onPress={onPress} disabled={disabled} accessibilityRole="button" accessibilityLabel={label} accessibilityState={{ disabled: !!disabled }}
      style={({ pressed }) => ({ flex: 1, minHeight: 52, borderRadius: r.pill, paddingHorizontal: 10, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6,
        backgroundColor: sos ? c.errorSoft : c.btnBg, opacity: disabled ? 0.45 : pressed ? 0.8 : 1 })}>
      {icon ? <Icon name={icon} size={18} color={fg} /> : null}
      <T color={fg} numberOfLines={1} style={{ fontFamily: f.black, fontSize: 15, lineHeight: 20, flexShrink: 1 }}>{label}</T>
    </Pressable>
  );
}

/** Aviso verde de efectivo. */
export function CashNote({ text }: { text: string }) {
  useTheme();
  return (
    <Row gap={10} style={{ padding: 12, borderRadius: r.md, backgroundColor: c.primarySoft }}>
      <Icon name="payments" size={22} color={c.primaryDark} />
      <T color={c.primaryDark} style={{ flex: 1, fontFamily: f.bold, fontSize: 13.5, lineHeight: 18 }}>{text}</T>
    </Row>
  );
}

// ───────── Ajustes ─────────
/** Selector de tres opciones tipo pastilla (Claro / Oscuro / Automático). */
export function Segmented<V extends string>({ options, value, onChange, label }: {
  options: { value: V; label: string; icon?: IconName }[]; value: V; onChange: (v: V) => void; label: string;
}) {
  useTheme();
  return (
    <View accessibilityRole="radiogroup" accessibilityLabel={label} style={{ flexDirection: 'row', gap: 6, padding: 6, borderRadius: r.pill, backgroundColor: c.card }}>
      {options.map((o) => {
        const on = o.value === value;
        return (
          <Pressable key={o.value} onPress={() => onChange(o.value)} accessibilityRole="radio" accessibilityState={{ selected: on }} accessibilityLabel={o.label}
            style={{ flex: 1, minHeight: 48, borderRadius: r.pill, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 4, backgroundColor: on ? c.neon : 'transparent' }}>
            {o.icon ? <Icon name={o.icon} size={16} color={on ? c.onPrimary : c.muted} /> : null}
            <T numberOfLines={1} color={on ? c.onPrimary : c.muted} style={{ fontFamily: f.black, fontSize: 13.5, lineHeight: 18, flexShrink: 1 }}>{o.label}</T>
          </Pressable>
        );
      })}
    </View>
  );
}

/** Apariencia: Claro / Oscuro / Automático. Se guarda solo en este teléfono. */
export function AppearancePicker() {
  const { mode, setMode } = useTheme();
  const opts: { value: Mode; label: string; icon: IconName }[] = [
    { value: 'light', label: MODE_LABEL.light, icon: 'light-mode' },
    { value: 'dark', label: MODE_LABEL.dark, icon: 'dark-mode' },
    { value: 'auto', label: MODE_LABEL.auto, icon: 'brightness-auto' },
  ];
  return <Segmented label="Apariencia" options={opts} value={mode} onChange={setMode} />;
}

export function SettingsGroup({ title, children }: { title: string; children: React.ReactNode }) {
  return <View style={{ gap: 10 }}><T v="micro">{title}</T>{children}</View>;
}

/** Fila de ajuste: tarjeta de 56 px mínimo con título a la izquierda y valor, interruptor o flecha a la derecha. */
export function SettingsRow({ title, value, onPress, danger, switchValue, onSwitch }: {
  title: string; value?: string; onPress?: () => void; danger?: boolean; switchValue?: boolean; onSwitch?: (v: boolean) => void;
}) {
  useTheme();
  const isSwitch = onSwitch !== undefined;
  const body = (
    <>
      <T color={danger ? c.error : c.ink} style={{ flex: 1, fontFamily: f.bold, fontSize: 15, lineHeight: 20 }}>{title}</T>
      {isSwitch ? <Switch value={!!switchValue} onValueChange={onSwitch} accessibilityLabel={title} trackColor={{ false: c.outline, true: c.neon }} thumbColor="#FFFFFF" /> : null}
      {value ? <T v="caption" color={c.muted} numberOfLines={1} style={{ flexShrink: 1, maxWidth: '55%', textAlign: 'right' }}>{value}</T> : null}
      {!isSwitch && onPress ? <Icon name="chevron-right" color={c.muted} /> : null}
    </>
  );
  const st: ViewStyle = { minHeight: 56, paddingHorizontal: 16, paddingVertical: 6, borderRadius: r.md, backgroundColor: c.card, flexDirection: 'row', alignItems: 'center', gap: 10 };
  return onPress ? (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={value ? `${title}, ${value}` : title} style={({ pressed }) => [st, { opacity: pressed ? 0.8 : 1 }]}>{body}</Pressable>
  ) : <View style={st}>{body}</View>;
}

// ───────── Conductor: el botón de conectarse ─────────
/** Botón muy grande En línea / Fuera de línea (80 px). Verde neón cuando está en línea; tarjeta oscura cuando no. */
export function OnlineToggle({ online, loading, onPress }: { online: boolean; loading?: boolean; onPress: () => void }) {
  useTheme();
  const fg = online ? c.onPrimary : c.ink;
  return (
    <Pressable onPress={onPress} disabled={loading} accessibilityRole="switch" accessibilityState={{ checked: online, disabled: !!loading }}
      accessibilityLabel={online ? 'En línea. Toca para desconectarte' : 'Fuera de línea. Toca para conectarte'}
      style={({ pressed }) => [{ minHeight: 80, borderRadius: r.pill, paddingLeft: 26, paddingRight: 14, flexDirection: 'row', alignItems: 'center', gap: 12,
        backgroundColor: online ? c.neon : c.card, borderWidth: 1, borderColor: online ? c.neon : c.outline, opacity: loading ? 0.6 : pressed ? 0.9 : 1 }, online && glow]}>
      <View style={{ flex: 1, minWidth: 0 }}>
        <T color={fg} fit style={{ fontFamily: f.black, fontSize: 26, lineHeight: 32, letterSpacing: -0.8 }}>{online ? 'En línea' : 'Fuera de línea'}</T>
        <T color={online ? c.onPrimary : c.muted} numberOfLines={1} style={{ fontFamily: f.bold, fontSize: 13, lineHeight: 18 }}>{online ? 'Toca para desconectarte' : 'Toca para conectarte'}</T>
      </View>
      <View style={{ width: 56, height: 56, borderRadius: 28, alignItems: 'center', justifyContent: 'center', backgroundColor: online ? c.onPrimary : c.neon }}>
        {loading ? <ActivityIndicator color={online ? c.neon : c.onPrimary} /> : <Icon name="power-settings-new" size={28} color={online ? c.neon : c.onPrimary} />}
      </View>
    </Pressable>
  );
}
