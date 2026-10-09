import React from 'react';
import { router } from 'expo-router';
import { PhoneLogin } from '@faxi/ui';
import { cfg } from '../../src/faxi';

export default function Login() {
  return (
    <PhoneLogin
      role="DRIVER"
      brandSuffix="Conductor"
      title="Maneja con faxi"
      subtitle="Entra o regístrate con tu número. Te pediremos tus documentos y los del vehículo."
      termsUrl={cfg.termsUrl}
      privacyUrl={cfg.privacyUrl}
      onSent={(phone) => router.push({ pathname: '/verify', params: { phone } })}
    />
  );
}
