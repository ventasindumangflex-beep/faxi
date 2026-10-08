import React, { createContext, useCallback, useContext, useEffect, useState } from 'react';
import { driver, watchDriverRow, type DocRow, type DriverDocType, type DriverProfile, type VehicleDocType } from '@faxi/core';
import { useSession } from '@faxi/ui';

export const REQUIRED_DRIVER_DOCS: DriverDocType[] = ['FOTO_PERFIL', 'LICENCIA', 'CEDULA', 'BUENA_CONDUCTA'];
export const REQUIRED_VEHICLE_DOCS: VehicleDocType[] = ['MATRICULA', 'SEGURO', 'FOTO_EXTERIOR'];

interface Ctx {
  profile: DriverProfile | null;
  docs: { driver: DocRow[]; vehicle: DocRow[] };
  missingDocs: string[];
  loading: boolean;
  refresh: () => Promise<void>;
}
const DriverCtx = createContext<Ctx>({ profile: null, docs: { driver: [], vehicle: [] }, missingDocs: [], loading: true, refresh: async () => {} });

/** El documento más reciente de cada tipo cuenta; RECHAZADO = falta. */
function missing(docs: { driver: DocRow[]; vehicle: DocRow[] }, vehicleId: string | null) {
  const ok = (rows: DocRow[], t: string) => rows.find((d) => d.type === t && (d.status === 'PENDING' || d.status === 'APPROVED'));
  const vrows = docs.vehicle.filter((d: any) => !vehicleId || d.vehicle_id === vehicleId);
  return [
    ...REQUIRED_DRIVER_DOCS.filter((t) => !ok(docs.driver, t)),
    ...REQUIRED_VEHICLE_DOCS.filter((t) => !ok(vrows, t)),
  ];
}

export function DriverProvider({ children }: { children: React.ReactNode }) {
  const { me } = useSession();
  const [profile, setProfile] = useState<DriverProfile | null>(null);
  const [docs, setDocs] = useState<{ driver: DocRow[]; vehicle: DocRow[] }>({ driver: [], vehicle: [] });
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    if (me?.role !== 'DRIVER') { setProfile(null); setLoading(false); return; }
    try {
      const [p, d] = await Promise.all([driver.me(), driver.documents()]);
      setProfile(p); setDocs(d);
    } catch { /* se reintenta en el siguiente refresh */ } finally { setLoading(false); }
  }, [me?.id, me?.role]);

  useEffect(() => { setLoading(true); refresh(); }, [refresh]);
  useEffect(() => (me?.role === 'DRIVER' ? watchDriverRow(me.id, refresh) : undefined), [me?.id, refresh]);

  return (
    <DriverCtx.Provider value={{ profile, docs, missingDocs: missing(docs, profile?.current_vehicle_id ?? null), loading, refresh }}>
      {children}
    </DriverCtx.Provider>
  );
}

export const useDriver = () => useContext(DriverCtx);
