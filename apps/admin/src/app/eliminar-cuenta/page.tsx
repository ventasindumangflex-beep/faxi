import type { Metadata } from 'next';
import { LegalPage } from '@/legal/Markdown';
import source from '@/legal/eliminar-cuenta.md';

export const metadata: Metadata = { title: 'faxi · Eliminar cuenta', robots: { index: true, follow: true } };

export default function Page() {
  return <LegalPage source={source} />;
}
