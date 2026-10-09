'use client';
import { useCallback, useEffect, useState } from 'react';
import { fmtDate, TICKET_LABEL, type TicketCategory } from '@faxi/core';
import { sb } from '@/lib/faxi';
import { StatusPill } from '@/lib/shared';

interface Ticket {
  id: string; category: TicketCategory; subject: string; body: string; status: string; priority: string; created_at: string;
  user: { full_name: string; phone: string | null; role: string } | null; trip: { code: string } | null;
}
const STATUS = ['OPEN', 'IN_REVIEW', 'RESOLVED', 'CLOSED'];
const STATUS_LABEL: Record<string, string> = { OPEN: 'Abierto', IN_REVIEW: 'En revisión', RESOLVED: 'Resuelto', CLOSED: 'Cerrado' };
const PRIORITY_LABEL: Record<string, string> = { LOW: 'Baja', MEDIUM: 'Media', HIGH: 'Alta' };

export default function Tickets() {
  const [filter, setFilter] = useState<'open' | 'all'>('open');
  const [rows, setRows] = useState<Ticket[]>([]);
  const [err, setErr] = useState<string | null>(null);

  const load = useCallback(async () => {
    let q = sb().from('support_tickets')
      .select('*, user:users!support_tickets_user_id_fkey(full_name, phone, role), trip:trips(code)')
      .order('created_at', { ascending: false }).limit(200);
    if (filter === 'open') q = q.in('status', ['OPEN', 'IN_REVIEW']);
    const { data, error } = await q;
    if (error) setErr(error.message); else { setRows(data as Ticket[]); setErr(null); }
  }, [filter]);
  useEffect(() => { load(); }, [load]);

  async function update(id: string, patch: Record<string, unknown>) {
    if (patch.status === 'RESOLVED') patch.resolved_at = new Date().toISOString();
    const { error } = await sb().from('support_tickets').update(patch).eq('id', id);
    if (error) setErr(error.message); else load();
  }

  return (
    <>
      <div className="head"><h1>Soporte</h1></div>
      <div className="tabs">
        <button className={filter === 'open' ? 'on' : ''} onClick={() => setFilter('open')}>Abiertos</button>
        <button className={filter === 'all' ? 'on' : ''} onClick={() => setFilter('all')}>Todos</button>
      </div>
      {err ? <div className="banner">{err}</div> : null}
      <div className="stack">
        {rows.map((t) => (
          <div key={t.id} className="card">
            <div className="head">
              <div className="row"><b>{t.subject}</b><StatusPill s={t.status} label={STATUS_LABEL[t.status]} /><span className="pill">{TICKET_LABEL[t.category]}</span></div>
              <span className="muted small">{fmtDate(t.created_at)}</span>
            </div>
            <div style={{ whiteSpace: 'pre-wrap' }}>{t.body}</div>
            <div className="muted small">
              {t.user?.full_name} · {t.user?.role === 'DRIVER' ? 'Conductor' : 'Pasajero'} · {t.user?.phone ?? 'sin teléfono'}{t.trip ? ` · Viaje ${t.trip.code}` : ''}
            </div>
            <div className="row">
              <select className="input" value={t.status} onChange={(e) => update(t.id, { status: e.target.value })}>
                {STATUS.map((s) => <option key={s} value={s}>{STATUS_LABEL[s]}</option>)}
              </select>
              <select className="input" value={t.priority} onChange={(e) => update(t.id, { priority: e.target.value })}>
                {Object.entries(PRIORITY_LABEL).map(([k, v]) => <option key={k} value={k}>Prioridad {v}</option>)}
              </select>
              {t.user?.phone ? <a className="btn" href={`https://wa.me/${t.user.phone.replace(/\D/g, '')}`} target="_blank" rel="noreferrer">WhatsApp</a> : null}
            </div>
          </div>
        ))}
        {!rows.length ? <div className="muted">Sin tickets.</div> : null}
      </div>
    </>
  );
}
