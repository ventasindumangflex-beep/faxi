import React from 'react';
import { router, useLocalSearchParams } from 'expo-router';
import { OtpVerify } from '@faxi/ui';

export default function Verify() {
  const { phone } = useLocalSearchParams<{ phone: string }>();
  return <OtpVerify phone={phone ?? ''} role="DRIVER" onBack={() => router.back()} />;
}
