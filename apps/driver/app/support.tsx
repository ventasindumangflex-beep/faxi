import React from 'react';
import { router } from 'expo-router';
import { SupportForm } from '@faxi/ui';

export default function Support() {
  return (
    <SupportForm
      categories={['PASAJERO', 'COBRO', 'SEGURIDAD', 'OBJETO_PERDIDO', 'RUTA', 'OTRO']}
      onBack={() => router.back()}
      onDone={() => router.back()}
    />
  );
}
