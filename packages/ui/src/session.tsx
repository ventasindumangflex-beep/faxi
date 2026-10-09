import React, { createContext, useCallback, useContext, useEffect, useState } from 'react';
import type { Session } from '@supabase/supabase-js';
import { AppState } from 'react-native';
import { auth, sb, type AppUser } from '@faxi/core';

interface Ctx { session: Session | null; me: AppUser | null; loading: boolean; refresh: () => Promise<void> }
const SessionCtx = createContext<Ctx>({ session: null, me: null, loading: true, refresh: async () => {} });

export function SessionProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [me, setMe] = useState<AppUser | null>(null);
  const [ready, setReady] = useState(false);
  const [loadedFor, setLoadedFor] = useState<string | null>(null);

  useEffect(() => {
    sb().auth.getSession().then(({ data }) => { setSession(data.session); setReady(true); });
    const { data: sub } = sb().auth.onAuthStateChange((_e, s) => setSession(s));
    // Refresca el token solo con la app en primer plano (recomendación de Supabase para React Native)
    const app = AppState.addEventListener('change', (st) => (st === 'active' ? sb().auth.startAutoRefresh() : sb().auth.stopAutoRefresh()));
    return () => { sub.subscription.unsubscribe(); app.remove(); };
  }, []);

  const refresh = useCallback(async () => {
    const uid = session?.user.id ?? null;
    if (!uid) { setMe(null); setLoadedFor(null); return; }
    try {
      const u = await auth.me();
      if (u && !u.is_active) { await auth.signOut(); setMe(null); return; }
      setMe(u);
    } catch { setMe(null); } finally { setLoadedFor(uid); }
  }, [session?.user.id]);

  useEffect(() => { refresh(); }, [refresh]);

  const loading = !ready || (!!session && loadedFor !== session.user.id);
  return <SessionCtx.Provider value={{ session, me, loading, refresh }}>{children}</SessionCtx.Provider>;
}

export const useSession = () => useContext(SessionCtx);
