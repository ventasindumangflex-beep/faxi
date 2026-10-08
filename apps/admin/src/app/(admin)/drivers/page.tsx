'use client';
import { useCallback, useEffect, useState } from 'react';
import { CATEGORY_LABEL, DOC_LABEL, fmtDate, type Approval, type Category } from '@faxi/core';
import { sb } from '@/lib/faxi';
import { StatusPill } from '@/lib/shared';

interface Vehicle { id: string; make: string; model: string; year: number; color: string; plate: string; category: Category; status: Approval; rejection_reason: string | null }
interface Doc { id: string; type: string; file_path: string; status: Approval; expires_at: string | null; rejection_reason: string | null; created_at: string; vehicle_id?: string }
interface DriverRow {
  id: string; status: Approval; availability: string; license_number: string | null; rating_avg: number | null; trips_count: number;
  rejection_reason: string | null; created_at: string; current_vehicle_id: string | null;
  user: { full_name: string; phone: string | null; email: string | null; is_active: boolean };
  vehicle: Vehicle | null;
  docs: Doc[];
}

const TABS: { k: Approval; label: string }[] = [
  { k: 'PENDING', label: 'Por revisar' }, { k: 'APPROVED', label: 'Aprobados' }, { k: 'REJECTED', label: 'Rechazados' }, { k: 'SUSPENDED', label: 'Suspendidos' },
];
const APPROVAL_LABEL: Record<Approval, string> = { PENDING: 'Pendiente', APPROVED: 'Aprobado', REJECTED: 'Rechazado', SUSPENDED: 'Suspendido' };
const EXPIRING = ['LICENCIA', 'SEGURO', 'MATRICULA', 'BUENA_CONDUCTA', 'INSPECCION'];

async function uid() { return (await sb().auth.getSession()).data.session?.user.id ?? null; }

export default function Drivers() {
  const [tab, setTab] = useState<Approval>('PENDING');
  const [rows, setRows] = useState<DriverRow[]>([]);
  const [open, setOpen] = useState<DriverRow | null>(null);
  const [vdocs, setVdocs] = useState<Doc[]>([]);
  const [err, setErr] = useState<string | null>(null);
  const [q, setQ] = useState('');

  const load = useCallback(async () => {
    const { data, error } = await sb().from('drivers')
      .select('*, user:users!drivers_id_fkey(full_name, phone, email, is_active), vehicle:vehicles!drivers_current_vehicle_fk(*), docs:driver_documents(*)')
      .eq('status', tab).order('created_at', { ascending: tab !== 'PENDING' ? false : true }).limit(300);
    if (error) setErr(error.message); else { setRows(data as DriverRow[]); setErr(null); }
  }, [tab]);
  useEffect(() => { load(); }, [load]);

  async function openDriver(d: DriverRow) {
    setOpen(d);
    if (d.current_vehicle_id) {
      const { data } = await sb().from('vehicle_documents').select('*').eq('vehicle_id', d.current_vehicle_id).order('created_at', { ascending: false });
      setVdocs((data as Doc[]) ?? []);
    } else setVdocs([]);
  }

  async function refreshOpen() {
    if (!open) return;
    await load();
    const { data } = await sb().from('drivers')
      .select('*, user:users!drivers_id_fkey(full_name, phone, email, is_active), vehicle:vehicles!drivers_current_vehicle_fk(*), docs:driver_documents(*)')
      .eq('id', open.id).single();
    if (data) await openDriver(data as DriverRow);
  }

  async function act(fn: () => PromiseLike<{ error: any }>) {
    setErr(null);
    const { error } = await fn();
    if (error) setErr(error.message); else await refreshOpen();
  }

  const review = async (table: 'drivers' | 'vehicles' | 'driver_documents' | 'vehicle_documents', id: string, status: Approval, extra: Record<string, unknown> = {}) => {
    let reason: string | null = null;
    if (status === 'REJECTED' || status === 'SUSPENDED') {
      reason = window.prompt('Motivo (lo verá el conductor):') ?? null;
      if (!reason) return;
    }
    const patch: Record<string, unknown> = { status, rejection_reason: reason, reviewed_by: await uid(), reviewed_at: new Date().toISOString(), ...extra };
    if (table === 'drivers' && status !== 'APPROVED') patch.availability = 'OFFLINE';
    if (table === 'vehicles') { delete patch.reviewed_by; delete patch.reviewed_at; } // los rellena el trigger
    await act(() => sb().from(table).update(patch).eq('id', id));
  };

  async function approveDoc(table: 'driver_documents' | 'vehicle_documents', d: Doc) {
    let expires: string | null = null;
    if (EXPIRING.includes(d.type)) {
      expires = window.prompt('Fecha de vencimiento (AAAA-MM-DD), vacío si no aplica:', d.expires_at ?? '') || null;
      if (expires && !/^\d{4}-\d{2}-\d{2}$/.test(expires)) { setErr('Fecha inválida'); return; }
    }
    await review(table, d.id, 'APPROVED', { expires_at: expires });
  }

  async function view(bucket: string, path: string) {
    const { data, error } = await sb().storage.from(bucket).createSignedUrl(path, 120);
    if (error) setErr(error.message); else window.open(data.signedUrl, '_blank', 'noopener');
  }

  const filtered = rows.filter((d) => !q || [d.user.full_name, d.user.phone, d.vehicle?.plate, d.license_number].join(' ').toLowerCase().includes(q.toLowerCase()));
  const latest = (docs: Doc[]) => docs.filter((d, i, all) => all.findIndex((x) => x.type === d.type) === i);

  return (
    <>
      <div className="head">
        <h1>Conductores</h1>
        <input className="input" placeholder="Buscar nombre, teléfono, placa…" value={q} onChange={(e) => setQ(e.target.value)} style={{ width: 280 }} />
      </div>
      <div className="tabs">{TABS.map((t) => <button key={t.k} className={tab === t.k ? 'on' : ''} onClick={() => setTab(t.k)}>{t.label}</button>)}</div>
      {err ? <div className="banner">{err}</div> : null}
      <div className="card table-wrap">
        <table>
          <thead><tr><th>Conductor</th><th>Vehículo</th><th>Documentos</th><th>Estado</th><th>Registro</th></tr></thead>
          <tbody>
            {filtered.map((d) => (
              <tr key={d.id} className="click" onClick={() => openDriver(d)}>
                <td><b>{d.user.full_name}</b><div className="muted small">{d.user.phone} · Lic. {d.license_number ?? '—'}</div></td>
                <td>{d.vehicle ? <>{d.vehicle.make} {d.vehicle.model} {d.vehicle.year}<div className="muted small">{d.vehicle.plate} · {CATEGORY_LABEL[d.vehicle.category]}</div></> : <span className="muted">Sin vehículo</span>}</td>
                <td className="small">{latest(d.docs).filter((x) => x.status === 'APPROVED').length}/{latest(d.docs).length} aprobados</td>
                <td><div className="row"><StatusPill s={d.status} label={APPROVAL_LABEL[d.status]} />{d.vehicle ? <StatusPill s={d.vehicle.status} label={'Veh. ' + APPROVAL_LABEL[d.vehicle.status]} /> : null}</div></td>
                <td className="small muted">{fmtDate(d.created_at)}</td>
              </tr>
            ))}
            {!filtered.length ? <tr><td colSpan={5} className="muted">Nada por aquí.</td></tr> : null}
          </tbody>
        </table>
      </div>

      {open ? (
        <>
          <div className="drawer-bg" onClick={() => setOpen(null)} />
          <aside className="drawer">
            <div className="head"><h1>{open.user.full_name}</h1><button className="btn" onClick={() => setOpen(null)}>Cerrar</button></div>
            <div className="muted">{open.user.phone} · Licencia {open.license_number ?? '—'} · ★ {open.rating_avg ?? 'Nuevo'} · {open.trips_count} viajes</div>
            {err ? <div className="banner">{err}</div> : null}

            <div className="card">
              <div className="head"><h2>Cuenta</h2><StatusPill s={open.status} label={APPROVAL_LABEL[open.status]} /></div>
              {open.rejection_reason ? <div className="muted small">Motivo: {open.rejection_reason}</div> : null}
              {open.vehicle?.status !== 'APPROVED' ? <div className="banner info small">El vehículo debe estar aprobado para que el conductor pueda conectarse.</div> : null}
              <div className="row">
                {open.status !== 'APPROVED' ? <button className="btn primary" onClick={() => review('drivers', open.id, 'APPROVED')}>Aprobar conductor</button> : null}
                {open.status === 'PENDING' ? <button className="btn danger" onClick={() => review('drivers', open.id, 'REJECTED')}>Rechazar</button> : null}
                {open.status === 'APPROVED' ? <button className="btn danger" onClick={() => review('drivers', open.id, 'SUSPENDED')}>Suspender</button> : null}
              </div>
            </div>

            {open.vehicle ? (
              <div className="card">
                <div className="head"><h2>{open.vehicle.make} {open.vehicle.model} {open.vehicle.year} · {open.vehicle.color}</h2><StatusPill s={open.vehicle.status} label={APPROVAL_LABEL[open.vehicle.status]} /></div>
                <div className="muted small">Placa {open.vehicle.plate} · {CATEGORY_LABEL[open.vehicle.category]}{open.vehicle.rejection_reason ? ` · Motivo: ${open.vehicle.rejection_reason}` : ''}</div>
                <div className="row">
                  {open.vehicle.status !== 'APPROVED' ? <button className="btn primary" onClick={() => review('vehicles', open.vehicle!.id, 'APPROVED')}>Aprobar vehículo</button> : null}
                  {open.vehicle.status !== 'REJECTED' ? <button className="btn danger" onClick={() => review('vehicles', open.vehicle!.id, 'REJECTED')}>Rechazar vehículo</button> : null}
                </div>
                <div className="muted small">Para aprobar se requieren matrícula y seguro aprobados y vigentes.</div>
              </div>
            ) : null}

            {([['driver_documents', 'driver-documents', open.docs, 'Documentos del conductor'], ['vehicle_documents', 'vehicle-documents', vdocs, 'Documentos del vehículo']] as const).map(([table, bucket, list, title]) => (
              <div className="card" key={table}>
                <h2>{title}</h2>
                {latest(list as Doc[]).map((d) => (
                  <div key={d.id} className="stack" style={{ borderTop: '1px solid var(--outline-soft)', paddingTop: 10 }}>
                    <div className="head">
                      <b>{DOC_LABEL[d.type] ?? d.type}</b>
                      <StatusPill s={d.status} label={APPROVAL_LABEL[d.status]} />
                    </div>
                    <div className="muted small">Subido {fmtDate(d.created_at)}{d.expires_at ? ` · vence ${d.expires_at}` : ''}{d.rejection_reason ? ` · ${d.rejection_reason}` : ''}</div>
                    <div className="row">
                      <button className="btn" onClick={() => view(bucket, d.file_path)}>Ver</button>
                      {d.status !== 'APPROVED' ? <button className="btn primary" onClick={() => approveDoc(table, d)}>Aprobar</button> : null}
                      {d.status !== 'REJECTED' ? <button className="btn danger" onClick={() => review(table, d.id, 'REJECTED')}>Rechazar</button> : null}
                    </div>
                  </div>
                ))}
                {!(list as Doc[]).length ? <div className="muted small">Sin documentos.</div> : null}
              </div>
            ))}
          </aside>
        </>
      ) : null}
    </>
  );
}
