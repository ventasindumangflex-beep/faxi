'use client';
import { useCallback, useEffect, useState } from 'react';
import { fmtDate, rd } from '@faxi/core';
import { sb } from '@/lib/faxi';
import { StatusPill, TRIP_SELECT, type TripRow } from '@/lib/shared';

type Stats = Record<'active_trips' | 'searching' | 'drivers_online' | 'drivers_busy' | 'drivers_pending' | 'today_completed' | 'today_gross' | 'today_commission' | 'today_cancelled' | 'open_tickets', number>;
const LIVE = ['SEARCHING', 'ASSIGNED', 'ENROUTE', 'ARRIVED', 'STARTED', 'ONTRIP', 'FINISHED', 'PAYMENT'];

export default function Dashboard() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [live, setLive] = useState<TripRow[]>([]);
  const [err, setErr] = useState<string | null>(null);

  const load = useCallback(async () => {
    const [s, t] = await Promise.all([
      sb().rpc('admin_dashboard_stats'),
      sb().from('trips').select(TRIP_SELECT).in('status', LIVE).order('requested_at', { ascending: false }).limit(100),
    ]);
    if (s.error || t.error) setErr((s.error ?? t.error)!.message);
    else { setStats(s.data as Stats); setLive(t.data as TripRow[]); setErr(null); }
  }, []);

  useEffect(() => {
    load();
    const ch = sb().channel('admin-trips')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'trips' }, () => load())
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'drivers' }, () => load())
      .subscribe();
    const iv = setInterval(load, 30000);
    return () => { sb().removeChannel(ch); clearInterval(iv); };
  }, [load]);

  const kpis: [string, string][] = stats ? [
    ['Viajes en curso', String(stats.active_trips)],
    ['Buscando conductor', String(stats.searching)],
    ['Conductores disponibles', String(stats.drivers_online)],
    ['Conductores ocupados', String(stats.drivers_busy)],
    ['Completados hoy', String(stats.today_completed)],
    ['Cobrado hoy', rd(stats.today_gross)],
    ['Comisión faxi hoy', rd(stats.today_commission)],
    ['Cancelados hoy', String(stats.today_cancelled)],
    ['Solicitudes por revisar', String(stats.drivers_pending)],
    ['Tickets abiertos', String(stats.open_tickets)],
  ] : [];

  return (
    <>
      <div className="head"><h1>Panel</h1><span className="muted small">Se actualiza en tiempo real</span></div>
      {err ? <div className="banner">{err}</div> : null}
      <div className="kpis">{kpis.map(([k, v]) => <div key={k} className="kpi"><b>{v}</b><span>{k}</span></div>)}</div>
      <div className="card">
        <h2>Viajes activos</h2>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Código</th><th>Estado</th><th>Pasajero</th><th>Conductor</th><th>Ruta</th><th>Tarifa</th><th>Solicitado</th></tr></thead>
            <tbody>
              {live.map((t) => (
                <tr key={t.id}>
                  <td><b>{t.code}</b></td>
                  <td><StatusPill s={t.status} /></td>
                  <td>{t.passenger?.user.full_name}<div className="muted small">{t.passenger?.user.phone}</div></td>
                  <td>{t.driver?.user.full_name ?? '—'}<div className="muted small">{t.driver?.user.phone}</div></td>
                  <td className="small">{t.origin_address}<div className="muted">→ {t.dest_address}</div></td>
                  <td>{rd(t.final_fare ?? t.estimated_fare)}</td>
                  <td className="small muted">{fmtDate(t.requested_at)}</td>
                </tr>
              ))}
              {!live.length ? <tr><td colSpan={7} className="muted">No hay viajes activos.</td></tr> : null}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}
