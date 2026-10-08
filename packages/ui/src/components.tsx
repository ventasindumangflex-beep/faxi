import React from 'react';
import {
  ActivityIndicator, Pressable, ScrollView, StyleProp, StyleSheet, Text as RNText, TextInput, TextInputProps,
  TextStyle, View, ViewStyle,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { MaterialIcons } from '@expo/vector-icons';
import { c, f, r, shadow } from './tokens';

export type IconName = React.ComponentProps<typeof MaterialIcons>['name'];

type TV = 'display' | 'title' | 'h2' | 'body' | 'label' | 'caption' | 'micro';
const tv: Record<TV, TextStyle> = {
  display: { fontFamily: f.black, fontSize: 30, lineHeight: 36, letterSpacing: -0.8 },
  title: { fontFamily: f.black, fontSize: 24, lineHeight: 30, letterSpacing: -0.6 },
  h2: { fontFamily: f.bold, fontSize: 18, lineHeight: 24 },
  body: { fontFamily: f.regular, fontSize: 15, lineHeight: 21 },
  label: { fontFamily: f.bold, fontSize: 15, lineHeight: 20 },
  caption: { fontFamily: f.regular, fontSize: 13, lineHeight: 18, color: c.ink2 },
  micro: { fontFamily: f.bold, fontSize: 12, lineHeight: 16, letterSpacing: 0.4, textTransform: 'uppercase', color: c.ink2 },
};

export function T({ v = 'body', color, style, children, numberOfLines, center, onPress }: {
  v?: TV; color?: string; style?: StyleProp<TextStyle>; children?: React.ReactNode; numberOfLines?: number; center?: boolean; onPress?: () => void;
}) {
  return (
    <RNText numberOfLines={numberOfLines} onPress={onPress} suppressHighlighting style={[{ color: c.ink }, tv[v], color ? { color } : null, center ? { textAlign: 'center' } : null, style]}>
      {children}
    </RNText>
  );
}

export const Icon = ({ name, size = 22, color = c.ink }: { name: IconName; size?: number; color?: string }) => (
  <MaterialIcons name={name} size={size} color={color} />
);

export function Row({ children, gap = 12, style }: { children: React.ReactNode; gap?: number; style?: StyleProp<ViewStyle> }) {
  return <View style={[{ flexDirection: 'row', alignItems: 'center', gap }, style]}>{children}</View>;
}

type BtnVariant = 'filled' | 'dark' | 'tonal' | 'outline' | 'danger';
const BTN: Record<BtnVariant, { bg: string; fg: string; bd: string }> = {
  filled: { bg: c.primary, fg: c.onPrimary, bd: c.primary },
  dark: { bg: c.ink, fg: c.white, bd: c.ink },
  tonal: { bg: c.surface2, fg: c.ink, bd: c.surface2 },
  outline: { bg: 'transparent', fg: c.ink, bd: c.outline },
  danger: { bg: c.errorSoft, fg: c.error, bd: c.errorSoft },
};

export function Button({ title, onPress, variant = 'filled', icon, loading, disabled, style, compact }: {
  title: string; onPress?: () => void; variant?: BtnVariant; icon?: IconName; loading?: boolean; disabled?: boolean;
  style?: StyleProp<ViewStyle>; compact?: boolean;
}) {
  const p = BTN[variant];
  const off = disabled || loading;
  return (
    <Pressable
      accessibilityRole="button" accessibilityLabel={title} onPress={onPress} disabled={off}
      style={({ pressed }) => [s.btn, compact && { height: 44, paddingHorizontal: 16 }, { backgroundColor: p.bg, borderColor: p.bd, opacity: off ? 0.5 : pressed ? 0.85 : 1 }, style]}
    >
      {loading ? <ActivityIndicator color={p.fg} /> : (
        <>
          {icon ? <Icon name={icon} size={20} color={p.fg} /> : null}
          <T v="label" color={p.fg}>{title}</T>
        </>
      )}
    </Pressable>
  );
}

export function IconButton({ icon, onPress, label, style }: { icon: IconName; onPress?: () => void; label: string; style?: StyleProp<ViewStyle> }) {
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={label} onPress={onPress} hitSlop={6}
      style={({ pressed }) => [s.iconBtn, { opacity: pressed ? 0.8 : 1 }, style]}>
      <Icon name={icon} size={24} />
    </Pressable>
  );
}

export function Field({ label, error, style, ...p }: TextInputProps & { label?: string; error?: string | null }) {
  return (
    <View style={{ gap: 6 }}>
      {label ? <T v="caption">{label}</T> : null}
      <TextInput placeholderTextColor={c.muted} {...p} style={[s.input, error ? { borderColor: c.error } : null, style]} />
      {error ? <T v="caption" color={c.error}>{error}</T> : null}
    </View>
  );
}

export const Card = ({ children, style }: { children: React.ReactNode; style?: StyleProp<ViewStyle> }) => (
  <View style={[s.card, style]}>{children}</View>
);

export function Screen({ children, scroll, style, pad = true }: { children: React.ReactNode; scroll?: boolean; style?: StyleProp<ViewStyle>; pad?: boolean }) {
  const inner: StyleProp<ViewStyle> = [{ padding: pad ? 20 : 0, gap: 16 }, style];
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.surface }} edges={['top', 'bottom']}>
      {scroll ? (
        <ScrollView contentContainerStyle={[{ flexGrow: 1 }, inner]} keyboardShouldPersistTaps="handled">{children}</ScrollView>
      ) : <View style={[{ flex: 1 }, inner]}>{children}</View>}
    </SafeAreaView>
  );
}

export function Header({ title, onBack, right }: { title?: string; onBack?: () => void; right?: React.ReactNode }) {
  return (
    <Row style={{ minHeight: 48 }}>
      {onBack ? (
        <Pressable accessibilityRole="button" accessibilityLabel="Volver" onPress={onBack} hitSlop={8} style={s.back}>
          <Icon name="arrow-back" size={24} />
        </Pressable>
      ) : null}
      <T v="h2" style={{ flex: 1 }} numberOfLines={1}>{title}</T>
      {right}
    </Row>
  );
}

export function Sheet({ children, style }: { children: React.ReactNode; style?: StyleProp<ViewStyle> }) {
  const ins = useSafeAreaInsets();
  return (
    <View style={[s.sheet, { paddingBottom: ins.bottom + 16 }, style]}>
      <View style={s.handle} />
      {children}
    </View>
  );
}

export function Banner({ text, tone = 'error', actionLabel, onAction, style }: {
  text: string; tone?: 'error' | 'warn' | 'info'; actionLabel?: string; onAction?: () => void; style?: StyleProp<ViewStyle>;
}) {
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
  return (
    <Pressable onPress={onPress} disabled={!onPress} accessibilityRole={onPress ? 'button' : undefined}
      style={({ pressed }) => [{ flexDirection: 'row', alignItems: 'center', gap: 14, paddingVertical: 12, minHeight: 56, opacity: pressed ? 0.7 : 1 }]}>
      {icon ? (
        <View style={[s.listIcon, danger && { backgroundColor: c.errorSoft }]}><Icon name={icon} size={20} color={danger ? c.error : c.ink} /></View>
      ) : null}
      <View style={{ flex: 1, minWidth: 0 }}>
        <T v="label" color={danger ? c.error : c.ink} numberOfLines={1}>{title}</T>
        {subtitle ? <T v="caption" numberOfLines={2}>{subtitle}</T> : null}
      </View>
      {right ?? (onPress ? <Icon name="chevron-right" color={c.muted} /> : null)}
    </Pressable>
  );
}

export function Chip({ label, selected, onPress, icon }: { label: string; selected?: boolean; onPress?: () => void; icon?: IconName }) {
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityState={{ selected }}
      style={[s.chip, selected && { backgroundColor: c.ink, borderColor: c.ink }]}>
      {icon ? <Icon name={icon} size={18} color={selected ? c.white : c.ink} /> : null}
      <T v="label" color={selected ? c.white : c.ink} style={{ fontSize: 14 }}>{label}</T>
    </Pressable>
  );
}

export function StatusPill({ label, tone = 'neutral' }: { label: string; tone?: 'ok' | 'warn' | 'error' | 'neutral' }) {
  const bg = tone === 'ok' ? c.primarySoft : tone === 'warn' ? c.warnSoft : tone === 'error' ? c.errorSoft : c.surface2;
  const fg = tone === 'ok' ? c.primaryDark : tone === 'warn' ? c.warn : tone === 'error' ? c.error : c.ink2;
  return <View style={{ backgroundColor: bg, borderRadius: r.pill, paddingHorizontal: 10, paddingVertical: 4, alignSelf: 'flex-start' }}><T v="micro" color={fg}>{label}</T></View>;
}

export function Stars({ value, onChange, size = 40 }: { value: number; onChange?: (n: number) => void; size?: number }) {
  return (
    <Row gap={6} style={{ justifyContent: 'center' }}>
      {[1, 2, 3, 4, 5].map((n) => (
        <Pressable key={n} onPress={() => onChange?.(n)} disabled={!onChange} hitSlop={6} accessibilityLabel={`${n} estrellas`}>
          <Icon name={n <= value ? 'star' : 'star-border'} size={size} color={n <= value ? c.star : c.outline} />
        </Pressable>
      ))}
    </Row>
  );
}

export function Avatar({ name, size = 52 }: { name?: string | null; size?: number }) {
  const initial = (name ?? '?').trim().charAt(0).toUpperCase();
  return (
    <View style={{ width: size, height: size, borderRadius: size / 2, backgroundColor: c.primarySoft, alignItems: 'center', justifyContent: 'center' }}>
      <T style={{ fontFamily: f.black, fontSize: size * 0.42, color: c.primaryDark }}>{initial}</T>
    </View>
  );
}

export const Divider = () => <View style={{ height: 1, backgroundColor: c.outlineSoft }} />;

export function Loading({ label }: { label?: string }) {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', gap: 12, backgroundColor: c.surface }}>
      <ActivityIndicator size="large" color={c.primary} />
      {label ? <T v="caption">{label}</T> : null}
    </View>
  );
}

export function Brand({ suffix, size = 34 }: { suffix?: string; size?: number }) {
  return (
    <Row gap={3} style={{ alignItems: 'baseline' }}>
      <T style={{ fontFamily: f.black, fontSize: size, lineHeight: size * 1.15, letterSpacing: -size * 0.05 }}>faxi</T>
      <View style={{ width: size * 0.26, height: size * 0.26, borderRadius: size, backgroundColor: c.primary }} />
      {suffix ? <T v="label" color={c.ink2} style={{ marginLeft: 6 }}>{suffix}</T> : null}
    </Row>
  );
}

const s = StyleSheet.create({
  btn: { height: 56, borderRadius: r.pill, paddingHorizontal: 22, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, borderWidth: 1 },
  iconBtn: { width: 48, height: 48, borderRadius: 24, backgroundColor: c.white, alignItems: 'center', justifyContent: 'center', ...shadow },
  input: { height: 56, borderRadius: r.md, borderWidth: 1, borderColor: c.outline, backgroundColor: c.white, paddingHorizontal: 16, fontFamily: f.regular, fontSize: 16, color: c.ink },
  card: { backgroundColor: c.white, borderRadius: 20, borderWidth: 1, borderColor: c.outlineSoft, padding: 16, gap: 10 },
  back: { width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center', marginLeft: -8 },
  sheet: {
    position: 'absolute', left: 0, right: 0, bottom: 0, backgroundColor: c.surface, borderTopLeftRadius: r.lg, borderTopRightRadius: r.lg,
    paddingHorizontal: 20, paddingTop: 10, gap: 14, shadowColor: c.ink, shadowOpacity: 0.14, shadowRadius: 28, shadowOffset: { width: 0, height: -6 }, elevation: 16,
  },
  handle: { width: 32, height: 4, borderRadius: 2, backgroundColor: c.outline, alignSelf: 'center', marginBottom: 4 },
  listIcon: { width: 40, height: 40, borderRadius: 20, backgroundColor: c.surface2, alignItems: 'center', justifyContent: 'center' },
  chip: { height: 44, paddingHorizontal: 16, borderRadius: r.pill, borderWidth: 1, borderColor: c.outline, backgroundColor: c.white, flexDirection: 'row', alignItems: 'center', gap: 6 },
});
