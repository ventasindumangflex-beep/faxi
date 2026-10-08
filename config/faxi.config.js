// FAXI · configuración central. Los valores sensibles llegan desde window.FAXI_ENV (env.js, NO versionado).
// Sin SUPABASE_URL / SUPABASE_ANON_KEY la app arranca en modo MOCK y lo indica en consola.
(function () {
  const env = window.FAXI_ENV || {};
  const base = {
    APP_NAME: 'FAXI',
    COUNTRY: 'DO',
    CITY: 'SANTO_DOMINGO',
    CURRENCY: 'DOP',
    LOCALE: 'es-DO',
    TIMEZONE: 'America/Santo_Domingo',
    SUPABASE_URL: env.SUPABASE_URL || '',
    SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY || '',
    API_URL: env.API_URL || '',
    MAP_PROVIDER: env.MAP_PROVIDER || 'SIMULATED',          // SIMULATED | MAPBOX | GOOGLE
    PAYMENT_PROVIDER: env.PAYMENT_PROVIDER || 'MOCK',        // MOCK | AZUL | CARDNET | STRIPE
    LOCATION_PROVIDER: env.LOCATION_PROVIDER || 'SIMULATED', // SIMULATED | GPS
    // Solo se usan en modo MOCK. En modo SUPABASE la fuente de verdad es app_settings / commissions / pricing_rules.
    MOCK_DEFAULTS: { MIN_VEHICLE_YEAR: 2000, DEFAULT_COMMISSION: 0.20 },
  };
  const missing = ['SUPABASE_URL', 'SUPABASE_ANON_KEY'].filter(k => !base[k]);
  window.FAXI_CONFIG = Object.freeze(Object.assign(base, { BACKEND: missing.length ? 'MOCK' : 'SUPABASE', MISSING: missing }));
  if (missing.length) console.info('[FAXI] Modo MOCK — faltan ' + missing.join(', ') + '. Ver docs/SUPABASE_SETUP.md');
})();
