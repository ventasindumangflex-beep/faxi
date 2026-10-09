'use client';
import { useCallback, useEffect, useState } from 'react';
import { CATEGORY_LABEL, fmtDate, km, rd, type TripStatus } from '@faxi/core';
import { sb } from '@/lib/faxi';
import { StatusPill, TRIP_SELECT, type TripRow } from '@/lib/shared';

const GROUPS: Record<string, { label: string; statuses: TripStatus[] | null }> = {
  active: { label: 'Activos', statuses: ['REQUESTED', 'SEARCHING', 'ASSIGNED', 'ENROUTE', 'ARRIVED', 'STARTED', 'ONTRIP', 'FINISHED', 'PAYMENT', 'PAYMENT_FAILED', 'DRIVER_TIMEOUT'] },
  done: { label: 'Completados', statuses: ['COMPLETED'] },
  cancelled: { label: 'Cancelados', statuses: ['CANCELLED', 'CANCELLED_BY_PASSENGER', 'CANCELLED_BY_DRIVER', 'NO_DRIVER', 'REQUEST_TIMEOUT'] },
  all: { label: 'Todos', statuses: null },
};
const ADMIN_CANCELLABLE: TripStatus[] = ['REQUESTED', 'SEARCHING', 'ASSIGNED', 'ENROUTE', 'ARRIVED', 'STARTED', 'ONTRIP', 'DRIVER_TIMEOUT'];

export default function Trips() {
  const [group, setGroup] = useState('active');
  const [code, setCode] = useState('');
  const [rows, setRows] = useState<TripRow[]>([]);
  const [err, setErr] = useState<string | null>(null);

  const load = useCallback(async () => {
    let query = sb().from('trips').select(TRIP_SELECT).order('requested_at', { ascending: false }).limit(200);
    const st = GROUPS[group].statuses;
    if (st) query = query.in('status', st);
    if (code.trim()) query = query.ilike('code', `%${code.trim()}%`);
    const { data, error } = await query;
    if (error) setErr(error.message); else { setRows(data as TripRow[]); setErr(null); }
  }, [group, code]);
  useEffect(() => { const h = setTimeout(load, 250); return () => clearTimeout(h); }, [load]);

  async function cancel(t: TripRow) {
    const reason = window.prompt(`Cancelar ${t.code}. Motivo:`);
    if (!reason) return;
    const { error } = await sb().rpc('cancel_trip', { p_trip_id: t.id, p_reason: reason });
    if (error) setErr(error.message); else load();
  }

  const total = rows.reduce((s, t) => s + (t.status === 'COMPLETED' ? t.final_fare ?? 0 : 0), 0);
  const commission = rows.reduce((s, t) => s + (t.status === 'COMPLETED' ? t.faxi_commission ?? 0 : 0), 0);

  return (
    <>
      <div className="head">
        <h1>Viajes</h1>
        <input className="input" placeholder="Código FX-…" value={code} onChange={(e) => setCode(e.target.value)} style={{ width: 200 }} />
      </div>
      <div className="row">
        <div className="tabs">{Object.entries(GROUPS).map(([k, g]) => <button key={k} className={group === k ? 'on' : ''} onClick={() => setGroup(k)}>{g.label}</button>)}</div>
        {group === 'done' ? <span className="muted small">{rows.length} viajes · {rd(total)} cobrado · {rd(commission)} comisión</span> : null}
      </div>
      {err ? <div className="banner">{err}</div> : null}
      <div className="card table-wrap">
        <table>
          <thead><tr><th>Código</th><th>Fecha</th><th>Estado</th><th>Pasajero</th><th>Conductor</th><th>Ruta</th><th>Tarifa</th><th>Comisión</th><th></th></tr></thead>
          <tbody>
            {rows.map((t) => (
              <tr key={t.id}>
                <td><b>{t.code}</b><div className="muted small">{CATEGORY_LABEL[t.category]}</div></td>
                <td className="small muted">{fmtDate(t.requested_at)}</td>
                <td><StatusPill s={t.status} />{t.cancel_reason ? <div className="muted small">{t.cancel_reason}</div> : null}</td>
                <td>{t.passenger?.user.full_name}</td>
                <td>{t.driver?.user.full_name ?? '—'}</td>
                <td className="small">{t.origin_address}<div className="muted">→ {t.dest_address} · {km(t.distance_km)}</div></td>
                <td>{rd(t.final_fare ?? t.estimated_fare)}</td>
                <td>{rd(t.faxi_commission)}</td>
                <td>{ADMIN_CANCELLABLE.includes(t.status) ? <button className="btn danger" onClick={() => cancel(t)}>Cancelar</button> : null}</td>
              </tr>
            ))}
            {!rows.length ? <tr><td colSpan={9} className="muted">Sin viajes.</td></tr> : null}
          </tbody>
        </table>
      </div>
    </>
  );
}
