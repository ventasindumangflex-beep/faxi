import type { Metadata } from 'next';
import localFont from 'next/font/local';
import './globals.css';

// Plus Jakarta Sans (licencia OFL) incluida en el repo: el build no depende de Google Fonts.
const font = localFont({
  src: [
    { path: './fonts/PlusJakartaSans_500Medium.ttf', weight: '500' },
    { path: './fonts/PlusJakartaSans_600SemiBold.ttf', weight: '600' },
    { path: './fonts/PlusJakartaSans_700Bold.ttf', weight: '700' },
    { path: './fonts/PlusJakartaSans_800ExtraBold.ttf', weight: '800' },
  ],
  display: 'swap',
});

export const metadata: Metadata = { title: 'faxi · Admin', robots: { index: false, follow: false } };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <body className={font.className}>{children}</body>
    </html>
  );
}
