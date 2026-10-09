import { createClient, SupabaseClient } from '@supabase/supabase-js';

let client: SupabaseClient | null = null;
let missing: string[] = [];

export interface FaxiInit { url?: string; anonKey?: string; storage?: any; web?: boolean }

/** Llamar una sola vez al arrancar cada app. No lanza: si faltan variables, `isConfigured()` devuelve false. */
export function initFaxi({ url, anonKey, storage, web }: FaxiInit) {
  missing = [!url && 'SUPABASE_URL', !anonKey && 'SUPABASE_ANON_KEY'].filter(Boolean) as string[];
  if (missing.length) return null;
  client = createClient(url!, anonKey!, {
    auth: { storage, persistSession: true, autoRefreshToken: true, detectSessionInUrl: !!web },
    realtime: { params: { eventsPerSecond: 10 } },
  });
  return client;
}

export const isConfigured = () => !!client;
export const missingConfig = () => missing;

export function sb(): SupabaseClient {
  if (!client) throw new Error('faxi no está configurado: faltan ' + (missing.join(', ') || 'initFaxi()'));
  return client;
}

export async function currentUid(): Promise<string> {
  const { data } = await sb().auth.getSession();
  const id = data.session?.user.id;
  if (!id) throw new Error('Tu sesión expiró. Vuelve a entrar.');
  return id;
}
