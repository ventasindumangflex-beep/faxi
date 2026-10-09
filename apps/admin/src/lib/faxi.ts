import { initFaxi } from '@faxi/core';

initFaxi({
  url: process.env.NEXT_PUBLIC_SUPABASE_URL,
  anonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  storage: typeof window !== 'undefined' ? window.localStorage : undefined,
  web: true,
});

export { sb } from '@faxi/core';
