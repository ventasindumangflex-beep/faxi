import React, { useEffect, useState } from 'react';
import { router } from 'expo-router';
import { passenger } from '@faxi/core';
import { SupportForm } from '@faxi/ui';

export default function Support() {
  const [tripId, setTripId] = useState<string | null>(null);
  useEffect(() => { passenger.history(1).then((r) => setTripId(r[0]?.id ?? null)).catch(() => {}); }, []);
  return (
    <SupportForm
      categories={['COBRO', 'CONDUCTOR', 'SEGURIDAD', 'OBJETO_PERDIDO', 'RUTA', 'OTRO']}
      tripId={tripId}
      onBack={() => router.back()}
      onDone={() => router.replace('/')}
    />
  );
}
