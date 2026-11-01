import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { AccessibilityInfo, useColorScheme } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { applyScheme, c, type Palette, type Scheme } from './tokens';

export type Mode = 'light' | 'dark' | 'auto';
export const MODE_LABEL: Record<Mode, string> = { light: 'Claro', dark: 'Oscuro', auto: 'Automático' };

// La apariencia se guarda solo en este teléfono (nunca en el servidor).
const KEY = 'faxi-mode';

interface Ctx { mode: Mode; scheme: Scheme; setMode: (m: Mode) => void; c: Palette; reduceMotion: boolean }
const ThemeCtx = createContext<Ctx>({ mode: 'dark', scheme: 'dark', setMode: () => {}, c, reduceMotion: false });

const isMode = (v: unknown): v is Mode => v === 'light' || v === 'dark' || v === 'auto';

/**
 * Modo Claro / Oscuro / Automático. `defaultMode` solo cuenta la primera vez (la app del conductor arranca en oscuro).
 * Automático sigue el tema del teléfono; si el teléfono no lo informa, usa el oscuro.
 */
export function ThemeProvider({ defaultMode = 'auto', children }: { defaultMode?: Mode; children: React.ReactNode }) {
  const system = useColorScheme();
  const [stored, setStored] = useState<Mode | null>(null);
  const [reduceMotion, setReduceMotion] = useState(false);

  useEffect(() => {
    AsyncStorage.getItem(KEY).then((v) => setStored(isMode(v) ? v : defaultMode)).catch(() => setStored(defaultMode));
    AccessibilityInfo.isReduceMotionEnabled().then(setReduceMotion).catch(() => {});
    const sub = AccessibilityInfo.addEventListener('reduceMotionChanged', setReduceMotion);
    return () => sub.remove();
  }, []);

  const mode = stored ?? defaultMode;
  const scheme: Scheme = mode === 'auto' ? (system === 'light' ? 'light' : 'dark') : mode;
  applyScheme(scheme); // antes de dibujar los hijos: así `c` ya trae los colores del tema

  const setMode = useCallback((m: Mode) => {
    setStored(m);
    AsyncStorage.setItem(KEY, m).catch(() => {});
  }, []);

  const value = useMemo(() => ({ mode, scheme, setMode, c, reduceMotion }), [mode, scheme, setMode, reduceMotion]);
  if (stored === null) return null; // un instante: se lee la preferencia guardada para no parpadear con otro tema
  return <ThemeCtx.Provider value={value}>{children}</ThemeCtx.Provider>;
}

/** Todo componente que use colores de `c` debe llamar a este hook: así se vuelve a dibujar al cambiar el tema. */
export const useTheme = () => useContext(ThemeCtx);
