import React from 'react';
import { router } from 'expo-router';
import { PhoneLogin } from '@faxi/ui';
import { cfg } from '../../src/faxi';

export default function Login() {
  return (
    <PhoneLogin
      role="PASSENGER"
      title="Muévete por Santo Domingo"
      subtitle="Entra con tu número de teléfono. Sin contraseñas."
      termsUrl={cfg.termsUrl}
      privacyUrl={cfg.privacyUrl}
      onSent={(phone) => router.push({ pathname: '/verify', params: { phone } })}
    />
  );
}
