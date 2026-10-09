import type { Metadata } from 'next';
import { LegalPage } from '@/legal/Markdown';
import source from '@/legal/privacidad.md';

export const metadata: Metadata = { title: 'faxi · Política de privacidad', robots: { index: true, follow: true } };

export default function Page() {
  return <LegalPage source={source} />;
}
