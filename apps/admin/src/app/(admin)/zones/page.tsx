'use client';
import { useCallback, useEffect, useState } from 'react';
import { rd } from '@faxi/core';
import { sb } from '@/lib/faxi';

interface Zone { id: string; name: string; kind: string; lat: number; lng: number; radius_m: number; is_active: boolean; surcharge: number }
const KINDS: Record<string, string> = { HOTEL: 'Hotel', TAXI_TURISTICO: 'Zona de taxis turísticos', OTRA: 'Otra', AEROPUERTO: 'Aeropuerto (sí se recoge; recargo opcional)' };

/** Acepta lo que copia Google Maps: "18.4719, -69.9406". */
function parseCoords(text: string): { lat: number; lng: number } | null {
  const m = text.trim().match(/^(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)$/);
  if (!m) return null;
  const lat = Number(m[1]), lng = Number(m[2]);
  return lat >= 17.3 && lat <= 20.1 && lng >= -72.1 && lng <= -68.2 ? { lat, lng } : null;
}

export default function Zones() {
  const [rows, setRows] = useState<Zone[]>([]);
  const [name, setName] = useState('');
  const [kind, setKind] = useState('HOTEL');
  const [coords, setCoords] = useState('');
  const [radius, setRadius] = useState('200');
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [isSuper, setIsSuper] = useState(false);
  const [drafts, setDrafts] = useState<Record<string, string>>({});

  const load = useCallback(async () => {
    const [{ data, error }, su] = await Promise.all([
      sb().from('restricted_zones').select('id, name, kind, lat, lng, radius_m, is_active, surcharge').order('name'),
      sb().rpc('is_super_admin'),
    ]);
    if (error) setMsg({ ok: false, text: error.message }); else setRows(data as Zone[]);
    setIsSuper(su.data === true);
  }, []);
  useEffect(() => { load(); }, [load]);

  async function add() {
    const c = parseCoords(coords);
    if (name.trim().length < 2) { setMsg({ ok: false, text: 'Escribe el nombre del lugar.' }); return; }
    if (!c) { setMsg({ ok: false, text: 'Pega las coordenadas como las copia Google Maps, por ejemplo: 18.4719, -69.9406' }); return; }
    const r = Number(radius);
    if (!(r >= 50 && r <= 2000)) { setMsg({ ok: false, text: 'El radio debe estar entre 50 y 2,000 metros.' }); return; }
    const { error } = await sb().from('restricted_zones').insert({ name: name.trim(), kind, lat: c.lat, lng: c.lng, radius_m: r });
    if (error) { setMsg({ ok: false, text: error.message }); return; }
    setMsg({ ok: true, text: kind === 'AEROPUERTO'
      ? `${name.trim()} agregado. El recargo empieza apagado (RD$0); solo el SUPER_ADMIN lo cambia.`
      : `${name.trim()} agregado. Ya no se puede pedir un viaje desde menos de ${r} m.` });
    setName(''); setCoords(''); setRadius('200');
    load();
  }

  // Recargo fijo del aeropuerto (migración 017): solo SUPER_ADMIN; el servidor también lo exige
  async function saveSurcharge(z: Zone) {
    const n = Number(drafts[z.id] ?? z.surcharge);
    if (!(n >= 0)) { setMsg({ ok: false, text: 'El recargo debe ser 0 o más. 0 = apagado.' }); return; }
    const { error } = await sb().from('restricted_zones').update({ surcharge: n }).eq('id', z.id);
    if (error) { setMsg({ ok: false, text: error.message }); return; }
    setMsg({ ok: true, text: n > 0 ? `Recargo de ${z.name}: ${rd(n)}.` : `Recargo de ${z.name} apagado.` });
    load();
  }

  async function toggle(z: Zone) {
    const { error } = await sb().from('restricted_zones').update({ is_active: !z.is_active }).eq('id', z.id);
    if (error) setMsg({ ok: false, text: error.message }); else load();
  }

  return (
    <>
      <div className="head"><h1>Zonas sin recogida</h1></div>
      <p className="muted small" style={{ margin: 0 }}>
        El INTRANT no permite recoger pasajeros a menos de 200 m de la puerta principal de los hoteles del Gran Santo Domingo ni en las
        zonas de taxis turísticos. Si un pasajero pide un viaje desde aquí, la app le pide mover el punto de recogida.
        Las zonas de <b>aeropuerto</b> no prohíben recoger: solo sirven para un recargo fijo opcional (apagado si es RD$0).
      </p>
      {msg ? <div className={'banner' + (msg.ok ? ' info' : '')}>{msg.text}</div> : null}

      <div className="card">
        <h2>Agregar un lugar</h2>
        <p className="muted small" style={{ margin: 0 }}>
          En Google Maps, mantén presionada la <b>puerta principal</b> del hotel: arriba salen las coordenadas. Tócalas para copiarlas y pégalas aquí.
        </p>
        <div className="row">
          <input className="input" placeholder="Nombre (ej. Hotel …)" maxLength={120} value={name} onChange={(e) => setName(e.target.value)} />
          <select className="input" value={kind} onChange={(e) => setKind(e.target.value)} aria-label="Tipo">
            {Object.entries(KINDS).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
          </select>
          <input className="input" placeholder="18.4719, -69.9406" value={coords} onChange={(e) => setCoords(e.target.value)} aria-label="Coordenadas" />
          <input className="input num" type="number" min={50} max={2000} step={10} value={radius} onChange={(e) => setRadius(e.target.value)} aria-label="Radio en metros" /> <span>m</span>
          <button className="btn primary" onClick={add}>Agregar</button>
        </div>
      </div>

      <div className="card">
        <div className="table-wrap">
          <table>
            <thead><tr><th>Lugar</th><th>Tipo</th><th>Coordenadas</th><th>Radio</th><th>Recargo</th><th>Estado</th><th></th></tr></thead>
            <tbody>
              {rows.map((z) => (
                <tr key={z.id}>
                  <td><b>{z.name}</b></td>
                  <td>{KINDS[z.kind] ?? z.kind}</td>
                  <td><a href={`https://www.google.com/maps?q=${z.lat},${z.lng}`} target="_blank" rel="noreferrer">{z.lat.toFixed(5)}, {z.lng.toFixed(5)}</a></td>
                  <td>{z.radius_m} m</td>
                  <td>{z.kind !== 'AEROPUERTO' ? '—' : isSuper ? (
                    <div className="row">
                      <input className="input num" type="number" min={0} step={1} aria-label="Recargo en pesos"
                        value={drafts[z.id] ?? String(z.surcharge)} onChange={(e) => setDrafts((d) => ({ ...d, [z.id]: e.target.value }))} />
                      <button className="btn" onClick={() => saveSurcharge(z)}>Guardar</button>
                    </div>
                  ) : z.surcharge > 0 ? rd(z.surcharge) : 'Apagado'}</td>
                  <td>{z.is_active ? <span className="pill ok">Activa</span> : <span className="pill">Pausada</span>}</td>
                  <td><button className="btn" onClick={() => toggle(z)}>{z.is_active ? 'Pausar' : 'Activar'}</button></td>
                </tr>
              ))}
              {rows.length === 0 ? <tr><td colSpan={7} className="muted">Todavía no hay lugares. Agrega los hoteles donde operas.</td></tr> : null}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}
