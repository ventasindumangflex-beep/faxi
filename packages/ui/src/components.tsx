import React, { useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator, LayoutAnimation, PanResponder, Pressable, ScrollView, StyleProp, StyleSheet, Text as RNText, TextInput, TextInputProps,
  TextStyle, View, ViewStyle, useWindowDimensions,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { MaterialIcons } from '@expo/vector-icons';
import { c, f, glow, r, shadowOf } from './tokens';
import { useTheme } from './theme';

export type IconName = React.ComponentProps<typeof MaterialIcons>['name'];

type TV = 'price' | 'eta' | 'display' | 'title' | 'h2' | 'body' | 'label' | 'caption' | 'micro';
// Los estilos leen `c` en cada render (dependen del tema).
const tv = (v: TV): TextStyle => {
  switch (v) {
    case 'price': return { fontFamily: f.black, fontSize: 56, lineHeight: 62, letterSpacing: -2.6, fontVariant: ['tabular-nums'] };
    case 'eta': return { fontFamily: f.black, fontSize: 40, lineHeight: 44, letterSpacing: -1.8 };
    case 'display': return { fontFamily: f.black, fontSize: 32, lineHeight: 36, letterSpacing: -1.1 };
    case 'title': return { fontFamily: f.black, fontSize: 24, lineHeight: 30, letterSpacing: -0.7 };
    case 'h2': return { fontFamily: f.black, fontSize: 18, lineHeight: 24, letterSpacing: -0.3, fontVariant: ['tabular-nums'] };
    case 'body': return { fontFamily: f.regular, fontSize: 15, lineHeight: 21 };
    case 'label': return { fontFamily: f.bold, fontSize: 15, lineHeight: 20 };
    case 'caption': return { fontFamily: f.regular, fontSize: 13, lineHeight: 18, color: c.ink2 };
    case 'micro': return { fontFamily: f.bold, fontSize: 12, lineHeight: 16, letterSpacing: 0.8, textTransform: 'uppercase', color: c.muted };
  }
};

/** La letra grande del teléfono se respeta hasta 1.3×; más allá rompe tarjetas y botones. */
export const MAX_FONT_SCALE = 1.3;

export function T({ v = 'body', color, style, children, numberOfLines, center, onPress, fit }: {
  v?: TV; color?: string; style?: StyleProp<TextStyle>; children?: React.ReactNode; numberOfLines?: number; center?: boolean; onPress?: () => void;
  /** Achica la letra para que un precio o titular largo quepa en una línea en pantallas chicas. */
  fit?: boolean;
}) {
  useTheme();
  return (
    <RNText numberOfLines={fit ? 1 : numberOfLines} adjustsFontSizeToFit={fit} minimumFontScale={fit ? 0.6 : undefined} onPress={onPress} suppressHighlighting maxFontSizeMultiplier={MAX_FONT_SCALE}
      style={[{ color: c.ink }, tv(v), color ? { color } : null, center ? { textAlign: 'center' } : null, style]}>
      {children}
    </RNText>
  );
}

export const Icon = ({ name, size = 22, color }: { name: IconName; size?: number; color?: string }) => {
  useTheme();
  return <MaterialIcons name={name} size={size} color={color ?? c.ink} />;
};

export function Row({ children, gap = 12, style }: { children: React.ReactNode; gap?: number; style?: StyleProp<ViewStyle> }) {
  return <View style={[{ flexDirection: 'row', alignItems: 'center', gap }, style]}>{children}</View>;
}

type BtnVariant = 'filled' | 'dark' | 'tonal' | 'outline' | 'danger';
const btnColors = (v: BtnVariant): { bg: string; fg: string; bd: string } => {
  switch (v) {
    case 'filled': return { bg: c.primary, fg: c.onPrimary, bd: c.primary };
    case 'dark': return { bg: c.cardSel, fg: c.cardSelFg, bd: c.cardSel };
    case 'tonal': return { bg: c.btnBg, fg: c.ink, bd: c.btnBg };
    case 'outline': return { bg: 'transparent', fg: c.ink, bd: c.outline };
    case 'danger': return { bg: c.errorSoft, fg: c.error, bd: c.errorSoft };
  }
};

export function Button({ title, onPress, variant = 'filled', icon, loading, disabled, style, compact }: {
  title: string; onPress?: () => void; variant?: BtnVariant; icon?: IconName; loading?: boolean; disabled?: boolean;
  style?: StyleProp<ViewStyle>; compact?: boolean;
}) {
  useTheme();
  const p = btnColors(variant);
  const off = disabled || loading;
  return (
    <Pressable
      accessibilityRole="button" accessibilityLabel={title} accessibilityState={{ disabled: !!off }} onPress={onPress} disabled={off}
      style={({ pressed }) => [s.btn, compact && { height: 44, paddingHorizontal: 16 }, { backgroundColor: p.bg, borderColor: p.bd, opacity: off ? 0.5 : pressed ? 0.85 : 1 }, style]}
    >
      {loading ? <ActivityIndicator color={p.fg} /> : (
        <>
          {icon ? <Icon name={icon} size={20} color={p.fg} /> : null}
          <T v="label" color={p.fg} numberOfLines={1} style={{ flexShrink: 1, fontFamily: f.black }}>{title}</T>
        </>
      )}
    </Pressable>
  );
}

/**
 * El botón principal de cada pantalla: pastilla verde neón de 60 px con resplandor, título a la izquierda y el precio
 * (o una flecha) a la derecha. Texto siempre oscuro sobre el verde vivo.
 */
export function BigButton({ title, price, icon, onPress, loading, disabled, style }: {
  title: string; price?: string; icon?: IconName; onPress?: () => void; loading?: boolean; disabled?: boolean; style?: StyleProp<ViewStyle>;
}) {
  useTheme();
  const off = disabled || loading;
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={price ? `${title}, ${price}` : title} accessibilityState={{ disabled: !!off }}
      onPress={onPress} disabled={off}
      style={({ pressed }) => [s.big, !off && glow, { opacity: off ? 0.5 : 1, transform: [{ scale: pressed ? 0.98 : 1 }] }, style]}>
      {loading ? <ActivityIndicator color={c.onPrimary} style={{ flex: 1 }} /> : (
        <>
          <Row gap={10} style={{ flex: 1, minWidth: 0 }}>
            {icon ? <Icon name={icon} size={22} color={c.onPrimary} /> : null}
            <T color={c.onPrimary} numberOfLines={1} style={{ fontFamily: f.black, fontSize: 18, lineHeight: 24, flexShrink: 1 }}>{title}</T>
          </Row>
          {price ? <T color={c.onPrimary} numberOfLines={1} style={{ fontFamily: f.black, fontSize: 18, lineHeight: 24, fontVariant: ['tabular-nums'] }}>{price}</T> : null}
        </>
      )}
    </Pressable>
  );
}

export function IconButton({ icon, onPress, label, style }: { icon: IconName; onPress?: () => void; label: string; style?: StyleProp<ViewStyle> }) {
  useTheme();
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={label} onPress={onPress} hitSlop={6}
      style={({ pressed }) => [s.iconBtn, shadowOf(), { opacity: pressed ? 0.8 : 1 }, style]}>
      <Icon name={icon} size={24} />
    </Pressable>
  );
}

export function Field({ label, error, style, ...p }: TextInputProps & { label?: string; error?: string | null }) {
  useTheme();
  return (
    <View style={{ gap: 6 }}>
      {label ? <T v="caption">{label}</T> : null}
      <TextInput placeholderTextColor={c.muted} selectionColor={c.primary} maxFontSizeMultiplier={MAX_FONT_SCALE} {...p}
        style={[s.input, error ? { borderColor: c.error } : null, style]} />
      {error ? <T v="caption" color={c.error}>{error}</T> : null}
    </View>
  );
}

export const Card = ({ children, style }: { children: React.ReactNode; style?: StyleProp<ViewStyle> }) => {
  useTheme();
  return <View style={[s.card, style]}>{children}</View>;
};

export function Screen({ children, scroll, style, pad = true }: { children: React.ReactNode; scroll?: boolean; style?: StyleProp<ViewStyle>; pad?: boolean }) {
  useTheme();
  const inner: StyleProp<ViewStyle> = [{ padding: pad ? 20 : 0, gap: 16 }, style];
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.bg }} edges={['top', 'bottom']}>
      {scroll ? (
        <ScrollView contentContainerStyle={[{ flexGrow: 1 }, inner]} keyboardShouldPersistTaps="handled">{children}</ScrollView>
      ) : <View style={[{ flex: 1 }, inner]}>{children}</View>}
    </SafeAreaView>
  );
}

export function Header({ title, onBack, right }: { title?: string; onBack?: () => void; right?: React.ReactNode }) {
  useTheme();
  return (
    <Row style={{ minHeight: 48 }}>
      {onBack ? (
        <Pressable accessibilityRole="button" accessibilityLabel="Volver" onPress={onBack} hitSlop={8} style={s.back}>
          <Icon name="arrow-back" size={24} />
        </Pressable>
      ) : null}
      <T v="title" style={{ flex: 1, fontSize: 22 }} numberOfLines={1}>{title}</T>
      {right}
    </Row>
  );
}

/**
 * Hoja inferior sobre el mapa (esquinas de 28). Nunca más alta que la pantalla: si el contenido no cabe, se desplaza.
 * - `footer` queda siempre visible debajo (p. ej. el botón principal), aunque el contenido se desplace.
 * - `collapsible` muestra la rayita de arriba: arrastrarla hacia abajo (o tocarla) recoge la hoja para ver el mapa;
 *   recogida solo se ven `peek` y `footer`. Sin `collapsible` no hay rayita, para no prometer algo que no hace.
 */
export function Sheet({ children, style, footer, peek, collapsible }: {
  children: React.ReactNode; style?: StyleProp<ViewStyle>; footer?: React.ReactNode; peek?: React.ReactNode; collapsible?: boolean;
}) {
  useTheme();
  const ins = useSafeAreaInsets();
  const { height } = useWindowDimensions();
  const [open, setOpen] = useState(true);
  const openRef = useRef(true);
  const toggle = (next: boolean) => {
    if (next === openRef.current) return;
    openRef.current = next;
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setOpen(next);
  };
  const pan = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder: () => true,
    onMoveShouldSetPanResponder: (_e, g) => Math.abs(g.dy) > 6,
    onPanResponderRelease: (_e, g) => {
      if (g.dy > 24) toggle(false);
      else if (g.dy < -24) toggle(true);
      else if (Math.abs(g.dx) < 10) toggle(!openRef.current);
    },
  }), []);

  return (
    <View style={[s.sheet, { paddingBottom: ins.bottom + 16, maxHeight: height - ins.top - 72 }, collapsible && { paddingTop: 0 }, style]}>
      {collapsible ? (
        <View {...pan.panHandlers} accessible accessibilityRole="button"
          accessibilityLabel={open ? 'Ocultar opciones y ver el mapa' : 'Mostrar opciones'} onAccessibilityTap={() => toggle(!openRef.current)}
          style={{ marginHorizontal: -20, paddingHorizontal: 20, paddingTop: 10, paddingBottom: open ? 4 : 0, gap: 12 }}>
          <View style={[s.handle, { width: 44, height: 5, marginBottom: 0 }]} />
          {open ? null : peek}
        </View>
      ) : null}
      {open ? (
        <ScrollView style={{ flexGrow: 0, flexShrink: 1 }} contentContainerStyle={{ gap: 14 }} bounces={false}
          keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
          {children}
        </ScrollView>
      ) : null}
      {footer}
    </View>
  );
}

/** Franja detrás de la barra de estado para que la hora y la batería se lean sobre el mapa. */
export function StatusScrim() {
  useTheme();
  const ins = useSafeAreaInsets();
  return <View pointerEvents="none" style={{ position: 'absolute', top: 0, left: 0, right: 0, height: ins.top, backgroundColor: c.scrim }} />;
}

export function Banner({ text, tone = 'error', actionLabel, onAction, style }: {
  text: string; tone?: 'error' | 'warn' | 'info'; actionLabel?: string; onAction?: () => void; style?: StyleProp<ViewStyle>;
}) {
  useTheme();
  const p = tone === 'error' ? { bg: c.errorSoft, fg: c.error, icon: 'error-outline' as IconName }
    : tone === 'warn' ? { bg: c.warnSoft, fg: c.warn, icon: 'warning-amber' as IconName }
    : { bg: c.primarySoft, fg: c.primaryDark, icon: 'info-outline' as IconName };
  return (
    <Row style={[{ backgroundColor: p.bg, borderRadius: r.md, padding: 12, paddingLeft: 14 }, style]}>
      <Icon name={p.icon} color={p.fg} />
      <T v="caption" color={c.ink} style={{ flex: 1 }}>{text}</T>
      {actionLabel ? <Button title={actionLabel} onPress={onAction} variant="dark" compact /> : null}
    </Row>
  );
}

export function ListItem({ icon, title, subtitle, right, onPress, danger }: {
  icon?: IconName; title: string; subtitle?: string; right?: React.ReactNode; onPress?: () => void; danger?: boolean;
}) {
  useTheme();
  return (
    <Pressable onPress={onPress} disabled={!onPress} accessibilityRole={onPress ? 'button' : undefined}
      style={({ pressed }) => [{ flexDirection: 'row', alignItems: 'center', gap: 14, paddingVertical: 8, minHeight: 56, opacity: pressed ? 0.7 : 1 }]}>
      {icon ? (
        <View style={[s.listIcon, danger && { backgroundColor: c.errorSoft }]}><Icon name={icon} size={20} color={danger ? c.error : c.primaryDark} /></View>
      ) : null}
      <View style={{ flex: 1, minWidth: 0 }}>
        <T v="label" color={danger ? c.error : c.ink} numberOfLines={1}>{title}</T>
        {subtitle ? <T v="caption" color={c.muted} numberOfLines={2}>{subtitle}</T> : null}
      </View>
      {right ?? (onPress ? <Icon name="chevron-right" color={c.muted} /> : null)}
    </Pressable>
  );
}

/** Pastilla de selección (tipos de reporte, filtros). Seleccionada = invertida, como las tarjetas. */
export function Chip({ label, selected, onPress, icon }: { label: string; selected?: boolean; onPress?: () => void; icon?: IconName }) {
  useTheme();
  const fg = selected ? c.cardSelFg : c.ink;
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityState={{ selected }}
      style={[s.chip, selected && { backgroundColor: c.cardSel, borderColor: c.neon }]}>
      {icon ? <Icon name={icon} size={18} color={fg} /> : null}
      <T v="label" color={fg} style={{ fontSize: 14 }}>{label}</T>
    </Pressable>
  );
}

/** Pastilla flotante sobre el mapa (HUD): "4 carros cerca de ti", "5 km · 12 min", "Ajustes". Mínimo 44 px. */
export function HudChip({ label, icon, dot, onPress, accessibilityLabel }: {
  label?: string; icon?: IconName; dot?: boolean; onPress?: () => void; accessibilityLabel?: string;
}) {
  useTheme();
  const body = (
    <>
      {dot ? <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: c.neon, shadowColor: c.neon, shadowOpacity: 0.9, shadowRadius: 6, shadowOffset: { width: 0, height: 0 } }} /> : null}
      {icon ? <Icon name={icon} size={20} /> : null}
      {label ? <T v="label" numberOfLines={1} style={{ flexShrink: 1, fontSize: 14 }}>{label}</T> : null}
    </>
  );
  const st = [s.hud, shadowOf()];
  return onPress ? (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={accessibilityLabel ?? label} style={({ pressed }) => [...st, { opacity: pressed ? 0.8 : 1 }]}>{body}</Pressable>
  ) : <View accessibilityLabel={accessibilityLabel} style={st}>{body}</View>;
}

export function StatusPill({ label, tone = 'neutral' }: { label: string; tone?: 'ok' | 'warn' | 'error' | 'neutral' }) {
  useTheme();
  const bg = tone === 'ok' ? c.primarySoft : tone === 'warn' ? c.warnSoft : tone === 'error' ? c.errorSoft : c.card;
  const fg = tone === 'ok' ? c.primaryDark : tone === 'warn' ? c.warn : tone === 'error' ? c.error : c.ink2;
  return <View style={{ backgroundColor: bg, borderRadius: r.pill, paddingHorizontal: 10, paddingVertical: 4, alignSelf: 'flex-start' }}><T v="micro" color={fg}>{label}</T></View>;
}

export function Stars({ value, onChange, size = 40 }: { value: number; onChange?: (n: number) => void; size?: number }) {
  useTheme();
  return (
    <Row gap={2} style={{ justifyContent: 'center' }}>
      {[1, 2, 3, 4, 5].map((n) => (
        <Pressable key={n} onPress={() => onChange?.(n)} disabled={!onChange} hitSlop={6} accessibilityLabel={`${n} estrellas`}
          style={{ width: 48, height: 48, alignItems: 'center', justifyContent: 'center' }}>
          <Icon name={n <= value ? 'star' : 'star-border'} size={size} color={n <= value ? c.star : c.outline} />
        </Pressable>
      ))}
    </Row>
  );
}

export function Avatar({ name, size = 52 }: { name?: string | null; size?: number }) {
  useTheme();
  const initial = (name ?? '?').trim().charAt(0).toUpperCase();
  return (
    <View style={{ width: size, height: size, borderRadius: size / 2, backgroundColor: c.deep, alignItems: 'center', justifyContent: 'center' }}>
      <T style={{ fontFamily: f.black, fontSize: size * 0.4, color: '#F7FDF6' }}>{initial}</T>
    </View>
  );
}

export const Divider = () => {
  useTheme();
  return <View style={{ height: 1, backgroundColor: c.outlineSoft }} />;
};

export function Loading({ label }: { label?: string }) {
  useTheme();
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', gap: 12, backgroundColor: c.bg }}>
      <ActivityIndicator size="large" color={c.primary} />
      {label ? <T v="caption">{label}</T> : null}
    </View>
  );
}

export function Brand({ suffix, size = 34 }: { suffix?: string; size?: number }) {
  useTheme();
  return (
    <Row gap={3} style={{ alignItems: 'baseline' }}>
      <T style={{ fontFamily: f.black, fontSize: size, lineHeight: size * 1.15, letterSpacing: -size * 0.05 }}>faxi</T>
      <View style={{ width: size * 0.26, height: size * 0.26, borderRadius: size, backgroundColor: c.brand }} />
      {suffix ? <T v="label" color={c.ink2} style={{ marginLeft: 6 }}>{suffix}</T> : null}
    </Row>
  );
}

// Estilos que dependen del tema: se leen de `c` en cada render (s es un objeto con getters).
const s = {
  get btn(): ViewStyle { return { height: 56, borderRadius: r.pill, paddingHorizontal: 22, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, borderWidth: 1 }; },
  get big(): ViewStyle { return { minHeight: 60, borderRadius: r.pill, paddingHorizontal: 22, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 12, backgroundColor: c.neon }; },
  get iconBtn(): ViewStyle { return { width: 48, height: 48, borderRadius: 24, backgroundColor: c.surface, borderWidth: 1, borderColor: c.outline, alignItems: 'center', justifyContent: 'center' }; },
  get input(): TextStyle { return { minHeight: 56, borderRadius: r.md, borderWidth: 1, borderColor: c.outline, backgroundColor: c.input, paddingHorizontal: 16, fontFamily: f.regular, fontSize: 16, color: c.ink }; },
  get card(): ViewStyle { return { backgroundColor: c.card, borderRadius: 20, borderWidth: 1, borderColor: c.outlineSoft, padding: 16, gap: 10 }; },
  get back(): ViewStyle { return { width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center', marginLeft: -8 }; },
  get sheet(): ViewStyle {
    return {
      position: 'absolute', left: 0, right: 0, bottom: 0, backgroundColor: c.surface, borderTopLeftRadius: r.lg, borderTopRightRadius: r.lg,
      borderTopWidth: StyleSheet.hairlineWidth * 2, borderColor: c.outline, paddingHorizontal: 20, paddingTop: 22, gap: 14,
      shadowColor: '#000', shadowOpacity: 0.4, shadowRadius: 28, shadowOffset: { width: 0, height: -10 }, elevation: 16,
    };
  },
  get handle(): ViewStyle { return { width: 32, height: 4, borderRadius: 2, backgroundColor: c.outline, alignSelf: 'center', marginBottom: 4 }; },
  get listIcon(): ViewStyle { return { width: 44, height: 44, borderRadius: 14, backgroundColor: c.card, alignItems: 'center', justifyContent: 'center' }; },
  get chip(): ViewStyle { return { height: 44, paddingHorizontal: 16, borderRadius: r.pill, borderWidth: 1, borderColor: c.outline, backgroundColor: c.card, flexDirection: 'row', alignItems: 'center', gap: 6 }; },
  get hud(): ViewStyle { return { minHeight: 44, paddingHorizontal: 16, borderRadius: r.pill, borderWidth: 1, borderColor: c.outline, backgroundColor: c.chipBg, flexDirection: 'row', alignItems: 'center', gap: 8, alignSelf: 'flex-start', flexShrink: 1, maxWidth: '100%' }; },
};
