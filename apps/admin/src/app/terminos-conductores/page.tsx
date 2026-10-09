import type { Metadata } from 'next';
import { LegalPage } from '@/legal/Markdown';
import source from '@/legal/terminos-conductores.md';

export const metadata: Metadata = { title: 'faxi · Términos para conductores', robots: { index: true, follow: true } };

export default function Page() {
  return <LegalPage source={source} />;
}
