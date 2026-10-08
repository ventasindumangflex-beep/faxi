// FAXI · adaptador Supabase. Solo se carga si hay credenciales (FAXI_CONFIG.BACKEND === 'SUPABASE').
// Nunca usar la service_role key en el cliente.
(function () {
  let clientPromise = null;
  const C = () => window.FAXI_CONFIG || { BACKEND: 'MOCK', MISSING: ['FAXI_CONFIG'] };

  function getClient() {
    const cfg = C();
    if (cfg.BACKEND !== 'SUPABASE') return Promise.reject(new Error('Supabase no configurado: faltan ' + cfg.MISSING.join(', ')));
    if (!clientPromise) {
      clientPromise = import('https://esm.sh/@supabase/supabase-js@2').then(m => m.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, {
        auth: { persistSession: true, autoRefreshToken: true, storageKey: 'faxi.auth' },
        realtime: { params: { eventsPerSecond: 10 } },
      }));
    }
    return clientPromise;
  }

  // Traduce errores de Postgres a mensajes de UI sin exponer detalles internos.
  function friendlyError(err) {
    if (!err) return null;
    const code = err.code || '';
    if (code === '42501') return 'No tienes permiso para esta acción.';
    if (code === 'FX409') return err.message || 'Esta acción ya no es posible en el estado actual del viaje.';
    if (code === '23505') return err.message || 'Ya existe un registro igual.';
    if (code === '22023' || code === '23514' || code === 'P0002') return err.message;
    if (/fetch|network/i.test(err.message || '')) return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
    console.error('[FAXI] error no controlado', err);
    return 'Algo salió mal. Inténtalo de nuevo.';
  }

  async function rpc(name, args) {
    const sb = await getClient();
    const { data, error } = await sb.rpc(name, args || {});
    if (error) { const e = new Error(friendlyError(error)); e.code = error.code; e.cause = error; throw e; }
    return data;
  }

  async function healthCheck() {
    try { return { ok: true, backend: 'SUPABASE', info: await rpc('faxi_health') }; }
    catch (e) { return { ok: false, backend: C().BACKEND, error: e.message }; }
  }

  window.FaxiSupabase = { getClient, rpc, healthCheck, friendlyError };
})();
