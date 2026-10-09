'use client';
import { useCallback, useEffect, useState } from 'react';
import { sb } from '@/lib/faxi';

interface Rule { id: string; category: string; display_name: string; base_fare: number; per_km: number; per_min: number; minimum_fare: number; surge_multiplier: number; is_active: boolean }
interface Setting { key: string; value: unknown; description: string | null }
const NUM_FIELDS: { k: keyof Rule; label: string; step: string }[] = [
  { k: 'base_fare', label: 'Base', step: '1' }, { k: 'per_km', label: 'Por km', step: '0.5' }, { k: 'per_min', label: 'Por min', step: '0.5' },
  { k: 'minimum_fare', label: 'Mínimo', step: '1' }, { k: 'surge_multiplier', label: 'Multiplicador', step: '0.05' },
];

export default function Pricing() {
  const [rules, setRules] = useState<Rule[]>([]);
  const [rate, setRate] = useState('');
  const [settings, setSettings] = useState<(Setting & { draft: string })[]>([]);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  const load = useCallback(async () => {
    const [r, c, s] = await Promise.all([
      sb().from('pricing_rules').select('*').order('sort_order'),
      sb().from('commissions').select('rate').eq('is_active', true).is('category', null).maybeSingle(),
      sb().from('app_settings').select('key, value, description').order('key'),
    ]);
    setRules((r.data as Rule[]) ?? []);
    setRate(c.data ? String(Math.round(Number(c.data.rate) * 1000) / 10) : '');
    setSettings(((s.data as Setting[]) ?? []).map((x) => ({ ...x, draft: JSON.stringify(x.value) })));
  }, []);
  useEffect(() => { load(); }, [load]);

  const done = (error: any, ok: string) => { setMsg(error ? { ok: false, text: error.message } : { ok: true, text: ok }); if (!error) load(); };

  async function saveRule(r: Rule) {
    const { id, category, display_name, ...rest } = r;
    const { error } = await sb().from('pricing_rules').update({ ...rest, display_name }).eq('id', id);
    done(error, `${display_name} guardado.`);
  }

  async function saveRate() {
    const n = Number(rate);
    if (!(n >= 0 && n <= 50)) { setMsg({ ok: false, text: 'La comisión debe estar entre 0 y 50 %.' }); return; }
    const { error } = await sb().rpc('admin_set_commission', { p_rate: n / 100, p_category: null });
    done(error, `Comisión actualizada a ${n} %.`);
  }

  async function saveSetting(s: Setting & { draft: string }) {
    let value: unknown;
    try { value = JSON.parse(s.draft); } catch { setMsg({ ok: false, text: `${s.key}: JSON inválido.` }); return; }
    const { error } = await sb().from('app_settings').update({ value }).eq('key', s.key);
    done(error, `${s.key} guardado.`);
  }

  const setField = (id: string, k: keyof Rule, v: string | boolean) =>
    setRules((rs) => rs.map((r) => (r.id === id ? { ...r, [k]: typeof v === 'boolean' ? v : Number(v) } : r)));

  return (
    <>
      <div className="head"><h1>Tarifas y ajustes</h1></div>
      {msg ? <div className={'banner' + (msg.ok ? ' info' : '')}>{msg.text}</div> : null}

      <div className="card">
        <h2>Tarifas por categoría (RD$)</h2>
        <p className="muted small" style={{ margin: 0 }}>precio = base + km × por km + min × por min, × multiplicador, nunca menor que el mínimo. Los cambios aplican a viajes nuevos.</p>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Categoría</th>{NUM_FIELDS.map((f) => <th key={f.k}>{f.label}</th>)}<th>Activa</th><th></th></tr></thead>
            <tbody>
              {rules.map((r) => (
                <tr key={r.id}>
                  <td><b>{r.display_name}</b></td>
                  {NUM_FIELDS.map((f) => (
                    <td key={f.k}><input className="input num" type="number" step={f.step} value={String(r[f.k])} onChange={(e) => setField(r.id, f.k, e.target.value)} /></td>
                  ))}
                  <td><input type="checkbox" checked={r.is_active} onChange={(e) => setField(r.id, 'is_active', e.target.checked)} /></td>
                  <td><button className="btn primary" onClick={() => saveRule(r)}>Guardar</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="card">
        <h2>Comisión faxi</h2>
        <div className="row">
          <input className="input num" type="number" step="0.5" value={rate} onChange={(e) => setRate(e.target.value)} /> <span>%</span>
          <button className="btn primary" onClick={saveRate}>Guardar comisión</button>
        </div>
        <p className="muted small" style={{ margin: 0 }}>Aplica a viajes que terminen desde ahora. Queda registrado en la auditoría.</p>
      </div>

      <div className="card">
        <h2>Ajustes del sistema</h2>
        {settings.map((s) => (
          <div key={s.key} className="stack" style={{ borderTop: '1px solid var(--outline-soft)', paddingTop: 10 }}>
            <div className="head"><b>{s.key}</b><button className="btn" onClick={() => saveSetting(s)}>Guardar</button></div>
            {s.description ? <div className="muted small">{s.description}</div> : null}
            <textarea className="input" rows={s.key === 'SERVICE_AREA' ? 4 : 1} value={s.draft}
              onChange={(e) => setSettings((all) => all.map((x) => (x.key === s.key ? { ...x, draft: e.target.value } : x)))} />
          </div>
        ))}
      </div>
    </>
  );
}
