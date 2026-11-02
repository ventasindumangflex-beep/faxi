// Tokens del rediseño (maqueta aprobada por el dueño, oct-2026). Modo oscuro = "noche", modo claro = "día".
// `c` es una paleta VIVA: se llena con la del tema activo (ver theme.tsx). Los componentes llaman a useTheme() para
// volver a dibujarse cuando cambia el tema, y leen los colores de `c` en cada render (nunca a nivel de módulo).

export type Scheme = 'dark' | 'light';

const base = {
  white: '#FFFFFF',     // blanco fijo (texto sobre fondos oscuros o de color)
  neon: '#05E072',      // verde marca vivo
  brand: '#00BE63',     // verde marca
  deep: '#00544F',      // verde profundo
  onPrimary: '#04170D', // texto SOBRE el verde vivo: siempre oscuro
  star: '#E0A100',
};

const dark = {
  ...base,
  primary: '#05E072',
  primaryDark: '#7CF0B0',   // verde para TEXTO e íconos sobre las superficies oscuras
  accent: '#05E072',        // verde de acento para titulares y números (neón de noche; verde oscuro de día)
  primarySoft: '#12301F',   // fondo suave verde (aviso de efectivo)
  ink: '#F7FDF6',           // texto
  ink2: '#B9C4BC',          // texto secundario
  muted: '#8A948D',         // texto apagado (5,4:1 sobre la hoja)
  outline: '#2E3832',
  outlineSoft: '#232A26',
  bg: '#0E1411',            // fondo noche
  surface: '#181C1A',       // hojas y superficies
  surface2: '#232A26',      // tarjetas
  card: '#232A26',
  input: '#232A26',
  cardSel: '#F7FDF6',       // tarjeta seleccionada = invertida
  cardSelFg: '#181C1A',
  btnBg: '#232A26',
  chipBg: 'rgba(24,28,26,0.88)',
  scrim: 'rgba(14,20,17,0.88)',
  warn: '#F0C54D',
  warnSoft: '#2E2608',
  error: '#FF6B5E',
  errorSoft: '#3A1E1B',
  endTop: '#0B6B47',        // degradado de la pantalla "Llegaste"
};

const light: typeof dark = {
  ...base,
  primary: '#05E072',
  primaryDark: '#0B5A36',
  accent: '#0B5A36',
  primarySoft: '#E3F6EA',
  ink: '#181C1A',
  ink2: '#414943',
  muted: '#5F6A63',
  outline: '#D5DDD6',
  outlineSoft: '#E6EBE4',
  bg: '#F1F5F0',
  surface: '#FFFFFF',
  surface2: '#EEF3EE',
  card: '#EEF3EE',
  input: '#FFFFFF',
  cardSel: '#181C1A',
  cardSelFg: '#F7FDF6',
  btnBg: '#E4EBE4',
  chipBg: 'rgba(255,255,255,0.92)',
  scrim: 'rgba(241,245,240,0.92)',
  warn: '#7A5900',
  warnSoft: '#FFF1CC',
  error: '#BA1A1A',
  errorSoft: '#FFDAD6',
  endTop: '#BFEFD3',
};

export type Palette = typeof dark;
export const palettes: Record<Scheme, Palette> = { dark, light };

/** Paleta activa. Se modifica solo con applyScheme() (lo llama ThemeProvider antes de dibujar los hijos). */
export const c: Palette = { ...dark };
export const applyScheme = (s: Scheme) => { Object.assign(c, palettes[s]); };

// Plus Jakarta Sans: 500 normal, 700 negrita, 800 para precios y titulares.
export const f = {
  regular: 'PlusJakartaSans_500Medium',
  bold: 'PlusJakartaSans_700Bold',
  black: 'PlusJakartaSans_800ExtraBold',
};

// Radios: 12 · 16 · 28 · pastilla. La hoja inferior usa 28 arriba.
export const r = { sm: 12, md: 16, lg: 28, pill: 999 };

/** Sombra de elevación (la lee en cada render: depende del tema). */
export const shadowOf = () => ({
  shadowColor: '#000000',
  shadowOpacity: c.bg === palettes.dark.bg ? 0.45 : 0.14,
  shadowRadius: 14,
  shadowOffset: { width: 0, height: 4 },
  elevation: 6,
});
/** Resplandor verde del botón principal. */
export const glow = {
  shadowColor: '#05E072',
  shadowOpacity: 0.35,
  shadowRadius: 18,
  shadowOffset: { width: 0, height: 8 },
  elevation: 8,
};
/** Compatibilidad: sombra fija usada por las pantallas. */
export const shadow = {
  shadowColor: '#000000',
  shadowOpacity: 0.3,
  shadowRadius: 14,
  shadowOffset: { width: 0, height: 4 },
  elevation: 6,
};

// Duración de las animaciones (se desactivan si el teléfono pide "reducir movimiento").
export const MOTION_MS = 400;
