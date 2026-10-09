import type { Metadata } from 'next';
import { LegalPage } from '@/legal/Markdown';
import source from '@/legal/terminos.md';

export const metadata: Metadata = { title: 'faxi · Términos para pasajeros', robots: { index: true, follow: true } };

export default function Page() {
  return <LegalPage source={source} />;
}
