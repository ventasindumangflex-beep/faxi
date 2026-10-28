'use client';
import { useCallback, useEffect, useState } from 'react';
import { fmtDate, rd } from '@faxi/core';
import { sb } from '@/lib/faxi';

interface Balance { driver_id: string; full_name: string; phone: string | null; owed: number; last_payment_at: string | null; blocked: boolean }
const METHODS = [{ v: 'TRANSFERENCIA', l: 'Transferencia' }, { v: 'DEPOSITO', l: 'Depósito' }, { v: 'EFECTIVO', l: 'Efectivo' }];

export default function Commissions() {
  const [rows, setRows] = useState<Balance[]>([]);
  const [limit, setLimit] = useState<number | null>(null);
  const [payDay, setPayDay] = useState('lunes');
  const [paying, setPaying] = useState<Balance | null>(null);
  const [amount, setAmount] = useState('');
  const [method, setMethod] = useState('TRANSFERENCIA');
  const [reference, setReference] = useState('');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  const load = useCallback(async () => {
    const [b, s] = await Promise.all([
      sb().rpc('admin_commission_balances'),
      sb().from('app_settings').select('key, value').in('key', ['COMMISSION_DEBT_LIMIT', 'COMMISSION_PAY_DAY']),
    ]);
    if (b.error) setMsg({ ok: false, text: b.error.message });
    else setRows(((b.data as Balance[]) ?? []).map((r) => ({ ...r, owed: Number(r.owed) })));
    for (const x of (s.data as { key: string; value: unknown }[]) ?? []) {
      if (x.key === 'COMMISSION_DEBT_LIMIT') setLimit(Number(x.value));
      if (x.key === 'COMMISSION_PAY_DAY') setPayDay(String(x.value));
    }
  }, []);
  useEffect(() => { load(); }, [load]);

  function open(r: Balance) {
    setPaying(r); setAmount(r.owed > 0 ? r.owed.toFixed(2) : ''); setMethod('TRANSFERENCIA'); setReference(''); setMsg(null);
  }

  async function save() {
    if (!paying) return;
    const n = Number(amount);
    if (!(n > 0)) { setMsg({ ok: false, text: 'Escribe un monto mayor que 0.' }); return; }
    setBusy(true);
    const { error } = await sb().rpc('admin_record_commission_payment', {
      p_driver_id: paying.driver_id, p_amount: n, p_method: method, p_reference: reference.trim() || null,
    });
    setBusy(false);
    if (error) { setMsg({ ok: false, text: error.message }); return; }
    setMsg({ ok: true, text: `Pago de ${rd(n)} registrado para ${paying.full_name}.` });
    setPaying(null);
    load();
  }

  const owedTotal = rows.reduce((s, r) => s + Math.max(r.owed, 0), 0);
  const blocked = rows.filter((r) => r.blocked).length;

  return (
    <>
      <div className="head"><h1>Comisiones</h1></div>
      <p className="muted small" style={{ margin: 0 }}>
        Los conductores pagan cada {payDay} la comisión de sus viajes en efectivo. Si alguno debe más de {limit != null ? rd(limit) : '…'}, no puede
        conectarse hasta que registres su pago aquí. El límite y el día solo los cambia el SUPER_ADMIN (Tarifas y ajustes).
      </p>
      {msg ? <div className={'banner' + (msg.ok ? ' info' : '')}>{msg.text}</div> : null}

      <div className="card">
        <div className="row"><b>Por cobrar: {rd(owedTotal)}</b><span className="muted small">{blocked} conductor(es) bloqueado(s)</span></div>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Conductor</th><th>Teléfono</th><th>Debe</th><th>Último pago</th><th>Estado</th><th></th></tr></thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.driver_id}>
                  <td><b>{r.full_name}</b></td>
                  <td>{r.phone ?? '—'}</td>
                  <td>{rd(r.owed)}</td>
                  <td>{r.last_payment_at ? fmtDate(r.last_payment_at) : '—'}</td>
                  <td>{r.blocked ? <span className="pill error">Bloqueado</span> : <span className="pill ok">Al día</span>}</td>
                  <td><button className="btn primary" onClick={() => open(r)}>Registrar pago</button></td>
                </tr>
              ))}
              {rows.length === 0 ? <tr><td colSpan={6} className="muted">No hay conductores con viajes todavía.</td></tr> : null}
            </tbody>
          </table>
        </div>
      </div>

      {paying ? (
        <div className="card">
          <h2>Registrar pago de {paying.full_name}</h2>
          <p className="muted small" style={{ margin: 0 }}>Debe {rd(paying.owed)}. Registra solo dinero que ya recibiste: el conductor recibe un aviso.</p>
          <div className="row">
            <input className="input num" type="number" step="0.01" min="0" value={amount} onChange={(e) => setAmount(e.target.value)} aria-label="Monto" />
            <select className="input" value={method} onChange={(e) => setMethod(e.target.value)} aria-label="Forma de pago">
              {METHODS.map((m) => <option key={m.v} value={m.v}>{m.l}</option>)}
            </select>
            <input className="input" placeholder="Referencia (opcional)" maxLength={100} value={reference} onChange={(e) => setReference(e.target.value)} />
            <button className="btn primary" onClick={save} disabled={busy}>{busy ? 'Guardando…' : 'Guardar pago'}</button>
            <button className="btn" onClick={() => setPaying(null)} disabled={busy}>Cancelar</button>
          </div>
        </div>
      ) : null}
    </>
  );
}
